# services/document_sync.py
import os

import psycopg2
from datetime import datetime
from typing import Dict, Tuple, Optional

from sqlalchemy.orm import Session
from sqlalchemy import text
from sqlalchemy.orm import sessionmaker

from db import db

# SyncSession = sessionmaker(bind=db.engine)

from models.documento import (
    Documento,
    DocumentoEmpresa,
    DocumentoVeiculo,
)
from documento_storage import save_document


# ---------------------------------------------------------
# Mapping: 3rd-party documentoid -> eventual.documento_tipo
# ---------------------------------------------------------

DOCUMENTOID_TO_TIPO = {
    2: "CONTRATO_SOCIAL",
    17: "IDENTIDADE_RESPONSAVEL",
    19: "CRLV",
    20: "CRLV",
    23: "CRLV",
    26: "CRLV",
    4: "PROCURACAO",
}


class DocumentSyncError(Exception):
    pass


# =========================================================
# Public entrypoint
# =========================================================

def sync_documents_for_empresa(*, cnpj: str) -> dict:
    """
    Runs document synchronization for an empresa during login.
    Blocking, synchronous, backend-only.
    """
    from flask import current_app
    sync_session = sessionmaker(bind=db.engine)
    third_party_dsn = current_app.config["THIRD_PARTY_DSN"]

    session = sync_session()
    try:
        third_conn = psycopg2.connect(third_party_dsn)
    except Exception:
        return {
            "ok": False,
            "reason": "third_party_unavailable",
        }

    try:
        eventual_docs = _load_eventual_documents(session, cnpj)
        third_docs = _load_third_party_documents(third_conn, cnpj)

        plan = _build_sync_plan(eventual_docs, third_docs)

        downloaded = _execute_plan(
            db_session=session,
            cnpj=cnpj,
            plan=plan,
        )

        session.commit()

        return {
            "ok": True,
            "downloaded": downloaded,
        }

    except Exception:
        session.rollback()
        return {
            "ok": False,
            "reason": "exceção checando documentos remotos",
        }

    finally:
        third_conn.close()


# =========================================================
# Eventual side
# =========================================================

def _load_eventual_documents(db: Session, cnpj: str) -> Dict[Tuple, dict]:
    """
    Loads existing Eventual documents for empresa and its vehicles.
    Keyed by logical identity:
      - ("CONTRATO_SOCIAL",)
      - ("IDENTIDADE_RESPONSAVEL",)
      - ("PROCURACAO",)
      - ("CRLV", placa)
    """

    sql = text("""
        SELECT
            d.id                  AS documento_id,
            d.documento_tipo_nome,
            d.hash,
            d.aprovado_em,
            de.empresa_cnpj,
            dv.veiculo_placa
        FROM eventual.documento d
        LEFT JOIN eventual.documento_empresa de
            ON de.id = d.id
        LEFT JOIN eventual.documento_veiculo dv
            ON dv.id = d.id
        WHERE
            de.empresa_cnpj = :cnpj
            OR dv.veiculo_placa IN (
                SELECT placa FROM geral.veiculo WHERE empresa_cnpj = :cnpj
            )
    """)

    rows = db.execute(sql, {"cnpj": cnpj}).mappings().all()

    docs: Dict[Tuple, dict] = {}

    for r in rows:
        tipo = r["documento_tipo_nome"]

        if tipo == "CRLV":
            if not r["veiculo_placa"]:
                continue
            key = ("CRLV", r["veiculo_placa"])
        else:
            key = (tipo,)

        docs[key] = {
            "documento_id": r["documento_id"],
            "hash": r["hash"],
            "aprovado_em": r["aprovado_em"],
        }

    return docs


# =========================================================
# Third-party side
# =========================================================

def _load_third_party_documents(conn, cnpj: str) -> Dict[Tuple, dict]:
    """
    Executes the three authoritative third-party queries and normalizes output.
    """

    cur = conn.cursor()
    docs: Dict[Tuple, dict] = {}

    # --- Empresa docs ---
    cnpj_int = int(cnpj)
    cur.execute(_QUERY_EMPRESA_DOCS, {"cnpj": cnpj_int})
    for r in cur.fetchall():
        documentoid = r[3]
        tipo = DOCUMENTOID_TO_TIPO[documentoid]
        key = (tipo,)

        docs[key] = {
            "tipo": tipo,
            "hash": r[8],
            "data_aprovacao": r[1],
            "pdf_bytes": r[7],
            "filename": r[6],
        }

    # --- CRLV ---
    cur.execute(_QUERY_CRLV, {"cnpj": cnpj_int})
    for r in cur.fetchall():
        placa = r[2]
        key = ("CRLV", placa)

        existing = docs.get(key)

        if not existing or (
                existing["data_aprovacao"] is None
                or r[1] > existing["data_aprovacao"]
        ):
            docs[key] = {
                "tipo": "CRLV",
                "placa": placa,
                "hash": r[8],
                "data_aprovacao": r[1],
                "pdf_bytes": r[7],
                "filename": r[6],
            }

    # --- Procuração ---
    cur.execute(_QUERY_PROCURACAO, {"cnpj": cnpj_int})
    for r in cur.fetchall():
        key = ("PROCURACAO",)

        docs[key] = {
            "tipo": "PROCURACAO",
            "hash": None,
            "data_aprovacao": None,
            "pdf_bytes": r[7],
            "filename": r[6],
        }

    return docs


# =========================================================
# Comparison logic
# =========================================================

def _build_sync_plan(eventual: dict, third: dict) -> Dict[Tuple, dict]:
    plan = {}

    for key, tdoc in third.items():
        edoc = eventual.get(key)
        tipo = tdoc["tipo"]

        # Procuração: only care if missing
        if tipo == "PROCURACAO":
            if edoc is None:
                plan[key] = tdoc
            continue

        if edoc is None:
            plan[key] = tdoc
            continue

        if edoc["hash"] == tdoc["hash"]:
            continue

        if edoc["aprovado_em"] is None:
            plan[key] = tdoc
            continue

        if tdoc["data_aprovacao"] is None:
            continue

        if tdoc["data_aprovacao"] > edoc["aprovado_em"]:
            plan[key] = tdoc

    return plan


# =========================================================
# Execution
# =========================================================

def _execute_plan(
    *,
    db_session: Session,
    cnpj: str,
    plan: dict,
) -> int:
    downloaded = 0

    for key, doc in plan.items():
        tipo = doc["tipo"]
        placa = doc.get("placa")

        # Skip CRLV if vehicle does not exist (for now)
        if tipo == "CRLV":
            exists = db_session.execute(
                text("SELECT 1 FROM geral.veiculo WHERE placa = :placa"),
                {"placa": placa},
            ).first()
            if not exists:
                continue

        _persist_document(
            db_session=db_session,
            cnpj=cnpj,
            tipo=tipo,
            placa=placa,
            pdf_bytes=doc["pdf_bytes"],
            filename=doc["filename"],
            aprovado_em=doc["data_aprovacao"],
        )

        downloaded += 1

    return downloaded


def _persist_document(
    *,
    db_session: Session,
    cnpj: str,
    tipo: str,
    placa: Optional[str],
    pdf_bytes: bytes,
    filename: str,
    aprovado_em: Optional[datetime],
):
    """
    Saves or replaces a document using the official storage pipeline.
    """

    # Convert bytes -> file-like object
    from io import BytesIO
    from werkzeug.datastructures import FileStorage

    file_obj = FileStorage(
        stream=BytesIO(pdf_bytes),
        filename=filename,
        content_type="application/pdf",
    )

    meta = save_document(
        file=file_obj,
        entity_type="veiculo" if tipo == "CRLV" else "empresa",
        entity_id=placa if tipo == "CRLV" else cnpj,
        empresa_cnpj=cnpj,
        tipo_nome=tipo,
    )

    # Find existing document
    if tipo == "CRLV":
        link = (
            db_session.query(DocumentoVeiculo)
            .join(Documento)
            .filter(DocumentoVeiculo.veiculo_placa == placa)
            .filter(Documento.documento_tipo_nome == "CRLV")
            .first()
        )
    else:
        link = (
            db_session.query(DocumentoEmpresa)
            .join(Documento)
            .filter(DocumentoEmpresa.empresa_cnpj == cnpj)
            .filter(Documento.documento_tipo_nome == tipo)
            .first()
        )

    if link:
        doc = link.documento
        doc.caminho = meta["caminho"]
        doc.tamanho = meta["tamanho"]
        doc.hash = meta["hash"]
        doc.data_upload = meta["data_upload"]
        doc.aprovado_em = aprovado_em
    else:
        doc = Documento(
            documento_tipo_nome=tipo,
            caminho=meta["caminho"],
            tamanho=meta["tamanho"],
            hash=meta["hash"],
            data_upload=meta["data_upload"],
            aprovado_em=aprovado_em,
        )
        db_session.add(doc)
        db_session.flush()

        if tipo == "CRLV":
            db_session.add(DocumentoVeiculo(id=doc.id, veiculo_placa=placa))
        else:
            db_session.add(DocumentoEmpresa(id=doc.id, empresa_cnpj=cnpj))

# ---------------------------------------------------------------------
# Third-party queries (verbatim, parameterized)
# ---------------------------------------------------------------------
_QUERY_EMPRESA_DOCS = """
WITH empresa_alvo AS (
    SELECT empresaid
    FROM empresa
    WHERE empresacnpj = %(cnpj)s
),
ultimo_aprovado AS (
    SELECT
        re.reqempempid,
        re.reqempid,
        re.reqempgrureqid,
        re.reqempgrureqver,
        re.reqempreqid,
        re.reqempreqver,
        re.reqempdhauto
    FROM requerimentoempresa re
    JOIN empresa_alvo ea
      ON ea.empresaid = re.reqempempid
    WHERE re.reqempstatus = 7
      AND re.reqempdhauto IS NOT NULL
      AND re.reqempdhauto <> TIMESTAMP '0001-01-01 00:00:00'
    ORDER BY re.reqempdhauto DESC
    LIMIT 1
)
SELECT
    ua.reqempempid          AS empresa_id,
    ua.reqempdhauto         AS data_aprovacao,
    NULL::varchar           AS placa,
    red.documentoid         AS documentoid,
    red.reqempdocdatenv     AS data_envio_documento,
    red.reqempdocdatemi     AS data_emissao_documento,
    red.documentodoc_gxi    AS filename,
    red.documentodoc        AS pdf_bytes,
    md5(red.documentodoc)   AS hash
FROM ultimo_aprovado ua
JOIN requerimentoempresadocumento red
  ON red.reqempid        = ua.reqempid
 AND red.reqempempid     = ua.reqempempid
 AND red.reqempgrureqid  = ua.reqempgrureqid
 AND red.reqempgrureqver = ua.reqempgrureqver
 AND red.reqempreqid    = ua.reqempreqid
 AND red.reqempreqver   = ua.reqempreqver
WHERE red.documentoid IN (2, 17)
ORDER BY red.documentoid;
"""
_QUERY_CRLV = """
WITH empresa_alvo AS (
    SELECT empresaid
    FROM empresa
    WHERE empresacnpj = %(cnpj)s
),
ultimo_aprovado AS (
    SELECT
        re.reqempempid,
        re.reqempid,
        re.reqempgrureqid,
        re.reqempgrureqver,
        re.reqempreqid,
        re.reqempreqver,
        re.reqempdhauto
    FROM requerimentoempresa re
    JOIN empresa_alvo ea
      ON ea.empresaid = re.reqempempid
    WHERE re.reqempstatus = 7
      AND re.reqempdhauto IS NOT NULL
      AND re.reqempdhauto <> TIMESTAMP '0001-01-01 00:00:00'
    ORDER BY re.reqempdhauto DESC
    LIMIT 1
),
veiculos_do_requerimento AS (
    SELECT rev.reqempveipla AS placa
    FROM requerimentoempresaveiculo rev
    JOIN ultimo_aprovado ua
      ON rev.reqempid        = ua.reqempid
     AND rev.reqempempid     = ua.reqempempid
     AND rev.reqempgrureqid  = ua.reqempgrureqid
     AND rev.reqempgrureqver = ua.reqempgrureqver
     AND rev.reqempreqid    = ua.reqempreqid
     AND rev.reqempreqver   = ua.reqempreqver
),
crlv_ranked AS (
    SELECT
        d.veidocveipla,
        d.veidocdocid,
        d.veidocdthenv,
        d.veidocdthemi,
        d.veidocfile_gxi,
        d.veidocfile,
        ROW_NUMBER() OVER (
            PARTITION BY d.veidocveipla, d.veidocdocid
            ORDER BY d.veidocdthenv DESC
        ) AS rn
    FROM veidoc d
    WHERE d.veidocdocid IN (19, 20, 23, 26)
      AND d.veidocdthapr IS NOT NULL
      AND d.veidocfile IS NOT NULL
)
SELECT
    ua.reqempempid          AS empresa_id,
    ua.reqempdhauto         AS data_aprovacao,
    v.placa                 AS placa,
    c.veidocdocid           AS documentoid,
    c.veidocdthenv          AS data_envio_documento,
    c.veidocdthemi          AS data_emissao_documento,
    c.veidocfile_gxi        AS filename,
    c.veidocfile            AS pdf_bytes,
    md5(c.veidocfile)       AS hash
FROM ultimo_aprovado ua
JOIN veiculos_do_requerimento v ON TRUE
JOIN crlv_ranked c
  ON c.veidocveipla = v.placa
 AND c.rn = 1
ORDER BY v.placa, c.veidocdocid;
"""
_QUERY_PROCURACAO = """
SELECT
    e.empresaid              AS empresa_id,
    NULL::timestamp          AS data_aprovacao,
    NULL::varchar            AS placa,
    4                         AS documentoid,
    NULL::timestamp          AS data_envio_documento,
    NULL::timestamp          AS data_emissao_documento,
    e.empresaprocuracao_gxi  AS filename,
    e.empresaprocuracao      AS pdf_bytes,
    md5(e.empresaprocuracao) AS hash
FROM empresa e
WHERE e.empresacnpj = %(cnpj)s
  AND e.empresaprocuracao IS NOT NULL;
"""
