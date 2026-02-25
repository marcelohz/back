import os

from flask import Blueprint, request, jsonify, session, send_file
from sqlalchemy.exc import DatabaseError

from controllers.autenticacao import analista_logado
from documento_storage import get_absolute_path
from models.empresa import Empresa
from models.motorista import Motorista
from models.pendencia_atual import PendenciaAtual
from models.veiculo import Veiculo
from models.viagem import Viagem
from util.pendencia_manager import PendenciaManager, PendenciaError
from sqlalchemy import text
from db import db

analista_bp = Blueprint("analista_bp", __name__)


# -----------------------
# List pendências
# -----------------------
@analista_bp.route("/pendencias", methods=["GET"])
@analista_logado
def list_pendencias():
    entidade_tipo = request.args.get("entidade_tipo")
    status = request.args.get("status")
    analista = request.args.get("analista")
    # optional flag: full history (all rows) instead of latest-per-entity
    history = request.args.get("history", "false").lower() in ("1", "true", "t", "yes", "y")

    if history:
        # history=true → return all fluxo_pendencia rows
        query = """
            SELECT id, entidade_tipo, entidade_id, status, analista, criado_em, motivo
            FROM eventual.fluxo_pendencia
            WHERE (:entidade_tipo IS NULL OR entidade_tipo = :entidade_tipo)
              AND (:status IS NULL OR status = :status)
              AND (:analista IS NULL OR analista = :analista)
            ORDER BY criado_em DESC
        """
    else:
        # history=false → return only the latest row per entity
        query = """
            SELECT id, entidade_tipo, entidade_id, status, analista, criado_em, motivo
            FROM eventual.v_pendencia_atual
            WHERE (:entidade_tipo IS NULL OR entidade_tipo = :entidade_tipo)
              AND (:status IS NULL OR status = :status)
              AND (:analista IS NULL OR analista = :analista)
            ORDER BY criado_em DESC
        """

    rows = db.session.execute(
        text(query),
        {"entidade_tipo": entidade_tipo, "status": status, "analista": analista}
    ).fetchall()

    pendencias = [dict(r._mapping) for r in rows]
    return jsonify(pendencias)


@analista_bp.route("/pendencias/<int:pendencia_id>/avanca", methods=["POST"])
@analista_logado
def avanca_pendencia_por_id(pendencia_id):
    data = request.get_json()
    if not data:
        return jsonify({"error": "JSON body is required"}), 400

    novo_status = data.get("novo_status")
    motivo = data.get("motivo")
    analista_email = session.get("email")

    if not novo_status:
        return jsonify({"error": "novo_status is required"}), 400
    # motivo can be validated by DB (your trigger enforces it for non-AGUARDANDO states)

    pend = PendenciaManager.get_by_id(pendencia_id)
    if not pend:
        return jsonify({"error": "Pendência not found"}), 404

    # Fetch latest pendência for the same entity directly from DB
    latest = PendenciaManager.pendencia_atual(pend["entidade_tipo"], pend["entidade_id"])
    # Prevent another analista from touching an EM_ANALISE pendência
    if latest["status"] == "EM_ANALISE" and latest["analista"] != analista_email:
        return jsonify({
            "error": f"Pendência já está em análise por: {latest['analista']}"
        }), 409

    # try:
    #     updated = PendenciaManager.avancar_por_id(
    #         pendencia_id=pendencia_id,
    #         novo_status=novo_status,
    #         analista=analista_email,
    #         motivo=motivo
    #     )
    #     db.session.commit()
    #     return jsonify(updated)
    try:
        # Accept optional document_validities array from the request body.
        # Expected shape: [{ "documento_id": 123, "validade": "YYYY-MM-DD" }, ...]
        document_validities = data.get("document_validities")

        updated = PendenciaManager.avancar_por_id(
            pendencia_id=pendencia_id,
            novo_status=novo_status,
            analista=analista_email,
            motivo=motivo,
            document_validities=document_validities
        )
        db.session.commit()
        return jsonify(updated)

    except PendenciaError as e:
        db.session.rollback()
        return jsonify({"error": str(e)}), 400
    except Exception as e:
        db.session.rollback()
        return jsonify({"error": "Unexpected error: " + str(e)}), 500

# -----------------------
# Get pendência by ID (enhanced) -- no fallbacks, DB must have validade and fluxo_pendencia_id
# -----------------------
@analista_bp.route("/pendencias/<int:pendencia_id>", methods=["GET"])
@analista_logado
def get_pendencia(pendencia_id):
    pend = PendenciaManager.get_by_id(pendencia_id)
    if not pend:
        return jsonify({"error": "Pendência not found"}), 404

    entidade_tipo = pend["entidade_tipo"]
    entidade_id = pend["entidade_id"]

    response = {
        "id": pend["id"],
        "entidade_tipo": entidade_tipo,
        "entidade_id": entidade_id,
        "status": pend["status"],
        "analista": pend["analista"],
        "criado_em": pend["criado_em"].isoformat() if getattr(pend["criado_em"], "isoformat", None) else pend["criado_em"],
        "motivo": pend["motivo"],
        "entity": None,
        "documentos": []
    }

    try:
        t = entidade_tipo.upper()
        if t == "EMPRESA":
            e = Empresa.query.get(entidade_id)
            if e:
                response["entity"] = {
                    "cnpj": e.cnpj,
                    "nome": e.nome,
                    "nome_fantasia": getattr(e, "nome_fantasia", None)
                }

            docs = db.session.execute(
                text("""
                    SELECT d.id, d.documento_tipo_nome, d.caminho, d.tamanho, d.hash,
                           d.data_upload, d.validade::text AS validade, d.fluxo_pendencia_id
                    FROM eventual.documento d
                    JOIN eventual.documento_empresa de ON de.id = d.id
                    WHERE de.empresa_cnpj = :entidade_id
                    ORDER BY d.data_upload DESC
                """),
                {"entidade_id": entidade_id}
            ).fetchall()

        elif t == "VEICULO":
            v = Veiculo.query.get(entidade_id)
            if v:
                response["entity"] = {
                    "placa": v.placa,
                    "modelo": v.modelo,
                    "empresa_cnpj": v.empresa_cnpj
                }

            docs = db.session.execute(
                text("""
                    SELECT d.id, d.documento_tipo_nome, d.caminho, d.tamanho, d.hash,
                           d.data_upload, d.validade::text AS validade, d.fluxo_pendencia_id
                    FROM eventual.documento d
                    JOIN eventual.documento_veiculo dv ON dv.id = d.id
                    WHERE dv.veiculo_placa = :entidade_id
                    ORDER BY d.data_upload DESC
                """),
                {"entidade_id": entidade_id}
            ).fetchall()

        elif t == "MOTORISTA":
            motorista = Motorista.query.get(int(entidade_id))
            if motorista:
                response["entity"] = {
                    "id": motorista.id,
                    "nome": motorista.nome,
                    "cpf": motorista.cpf
                }

            docs = db.session.execute(
                text("""
                    SELECT d.id, d.documento_tipo_nome, d.caminho, d.tamanho, d.hash,
                           d.data_upload, d.validade::text AS validade, d.fluxo_pendencia_id
                    FROM eventual.documento d
                    JOIN eventual.documento_motorista dm ON dm.id = d.id
                    WHERE dm.motorista_id::text = :entidade_id
                    ORDER BY d.data_upload DESC
                """),
                {"entidade_id": entidade_id}
            ).fetchall()

        elif t == "VIAGEM":
            v = Viagem.query.get(int(entidade_id))
            if v:
                response["entity"] = {
                    "id": v.id,
                    "origem": getattr(v, "origem", None),
                    "destino": getattr(v, "destino", None)
                }

            docs = db.session.execute(
                text("""
                    SELECT d.id, d.documento_tipo_nome, d.caminho, d.tamanho, d.hash,
                           d.data_upload, d.validade::text AS validade, d.fluxo_pendencia_id
                    FROM eventual.documento d
                    JOIN eventual.documento_viagem dv ON dv.id = d.id
                    WHERE dv.viagem_id::text = :entidade_id
                    ORDER BY d.data_upload DESC
                """),
                {"entidade_id": entidade_id}
            ).fetchall()

        else:
            docs = []

        documentos = []
        for row in docs:
            # use RowMapping where available
            try:
                mapping = dict(row._mapping)
            except Exception:
                # fallback if driver returns tuples (shouldn't happen with modern drivers)
                mapping = {
                    "id": row[0],
                    "documento_tipo_nome": row[1],
                    "caminho": row[2],
                    "tamanho": row[3],
                    "hash": row[4],
                    "data_upload": row[5],
                    "validade": row[6] if len(row) > 6 else None,
                    "fluxo_pendencia_id": row[7] if len(row) > 7 else None
                }

            if mapping.get("data_upload") is not None and getattr(mapping["data_upload"], "isoformat", None):
                mapping["data_upload"] = mapping["data_upload"].isoformat()

            mapping["download_url"] = f"{request.host_url.rstrip('/')}/api/analista/documento/{mapping['id']}/download"
            documentos.append(mapping)

        response["documentos"] = documentos

    except Exception as e:
        return jsonify({"error": "Failed to fetch entity or documents: " + str(e)}), 500

    return jsonify(response)

# -----------------------
# Claim pendência ("assumir")
# -----------------------
@analista_bp.route("/pendencias/<int:pendencia_id>/assumir", methods=["POST"])
@analista_logado
def assumir_pendencia(pendencia_id):
    analista_email = session.get("email")

    # Load pendência by its unique ID
    pend = PendenciaManager.get_by_id(pendencia_id)
    if not pend:
        return jsonify({"error": "Pendência not found"}), 404

    # Only pendências waiting for analysis can be claimed
    if pend["status"] != "AGUARDANDO_ANALISE":
        return jsonify({
            "error": f"Pendência is not available for claiming (status = {pend['status']})"
        }), 409

    # Fetch latest pendência for the same entity directly from DB
    latest = PendenciaManager.pendencia_atual(pend["entidade_tipo"], pend["entidade_id"])
    # Prevent another analista from touching an EM_ANALISE pendência
    if latest["status"] == "EM_ANALISE" and latest["analista"] != analista_email:
        return jsonify({
            "error": f"Pendência já está em análise por: {latest['analista']}"
        }), 409

    try:
        updated = PendenciaManager.avancar_por_id(
            pendencia_id,
            novo_status="EM_ANALISE",
            analista=analista_email,
            motivo=None
        )

        db.session.commit()
        return jsonify(updated)

    except PendenciaError as e:
        db.session.rollback()
        return jsonify({"error": str(e)}), 400

    except Exception as e:
        db.session.rollback()
        return jsonify({"error": "Unexpected error: " + str(e)}), 500

# -----------------------
# Download documento as analista (no fallbacks)
# -----------------------
@analista_bp.route("/documento/<int:documento_id>/download", methods=["GET"])
@analista_logado
def analista_download_documento(documento_id):
    doc_link = db.session.execute(
        text("""
            SELECT 'EMPRESA' AS kind, de.empresa_cnpj::text as entidade_id
            FROM eventual.documento_empresa de WHERE de.id = :doc_id
            UNION ALL
            SELECT 'VEICULO' AS kind, dv.veiculo_placa::text as entidade_id
            FROM eventual.documento_veiculo dv WHERE dv.id = :doc_id
            UNION ALL
            SELECT 'MOTORISTA' AS kind, dm.motorista_id::text as entidade_id
            FROM eventual.documento_motorista dm WHERE dm.id = :doc_id
            UNION ALL
            SELECT 'VIAGEM' AS kind, dv2.viagem_id::text as entidade_id
            FROM eventual.documento_viagem dv2 WHERE dv2.id = :doc_id
            LIMIT 1
        """),
        {"doc_id": documento_id}
    ).first()

    if not doc_link:
        return jsonify({"error": "Documento não encontrado ou não vinculado a nenhuma entidade"}), 404

    d = db.session.execute(
        text("SELECT id, caminho FROM eventual.documento WHERE id = :id"),
        {"id": documento_id}
    ).first()

    if not d:
        return jsonify({"error": "Documento metadata not found"}), 404

    caminho = d[1]
    file_path = get_absolute_path(caminho)
    if not os.path.exists(file_path):
        return jsonify({"error": "File not found on server"}), 404

    return send_file(file_path, as_attachment=True)