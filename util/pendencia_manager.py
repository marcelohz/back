# util/pendencia_manager.py
from datetime import datetime
from typing import Optional, Dict, List
from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError
from db import db

class PendenciaError(Exception):
    """Raised when DB rejects a pendência operation or on SQL errors."""


class PendenciaManager:
    @staticmethod
    def avancar_entidade(entidade_tipo: str, entidade_id: str) -> Dict:
        """
        Ensure an entity has a pendência in AGUARDANDO_ANALISE.
        Behavior:
          - If no pendência exists -> create one (AGUARDANDO_ANALISE).
          - If status == AGUARDANDO_ANALISE -> no-op, return current.
          - If status in (APROVADO, REJEITADO) -> create AGUARDANDO_ANALISE.
        Uses only the ID-based DB function internally.
        """
        atual = PendenciaManager.pendencia_atual(entidade_tipo, entidade_id)

        # No pendência yet -> create one (AGUARDANDO_ANALISE)
        if atual is None:
            pid = PendenciaManager._create_pendencia(entidade_tipo, entidade_id, "AGUARDANDO_ANALISE")
            return PendenciaManager.pendencia_atual(entidade_tipo, entidade_id)

        status = atual.get("status")

        if status == "AGUARDANDO_ANALISE":
            # nothing to do; entidade may update its own data and keep status
            return atual

        if status in ("APROVADO", "REJEITADO"):
            # restart the pendência flow: create a new AGUARDANDO_ANALISE row
            pid = PendenciaManager._create_pendencia(entidade_tipo, entidade_id, "AGUARDANDO_ANALISE")
            return PendenciaManager.pendencia_atual(entidade_tipo, entidade_id)

        raise PendenciaError(f"Unexpected pendência status: {status}")

    @staticmethod
    def get_by_id(pendencia_id: int) -> Optional[Dict]:
        row = db.session.execute(
            text("""
                SELECT id, entidade_tipo, entidade_id, status, analista, criado_em, motivo
                FROM eventual.fluxo_pendencia
                WHERE id = :id
            """),
            {"id": pendencia_id}
        ).first()
        return dict(row._mapping) if row else None

    @staticmethod
    def pendencia_atual(entidade_tipo: str, entidade_id: str) -> Optional[Dict]:
        row = db.session.execute(
            text("""
                SELECT id, entidade_tipo, entidade_id, status, analista, criado_em, motivo
                FROM eventual.v_pendencia_atual
                WHERE entidade_tipo = :entidade_tipo
                  AND entidade_id   = :entidade_id
            """),
            {"entidade_tipo": entidade_tipo, "entidade_id": entidade_id}
        ).first()
        return dict(row._mapping) if row else None

    # -----------------------
    # ID-first public helpers
    # -----------------------
    @staticmethod
    def avancar_por_id(
            pendencia_id: int,
            novo_status: str,
            analista: Optional[str],
            motivo: Optional[str],
            document_validities: Optional[List[Dict]] = None
    ) -> Dict:
        """
        Advance a pendência (by fluxo_pendencia.id). Returns current latest pendência for that entity.
        Optionally applies document validities (list of { "documento_id": int, "validade": "YYYY-MM-DD" }).
        Raises PendenciaError on DB errors or invalid novo_status.
        """
        if novo_status not in ("EM_ANALISE", "APROVADO", "REJEITADO", "AGUARDANDO_ANALISE"):
            raise PendenciaError(f"Invalid status: {novo_status}")

        pend = PendenciaManager.get_by_id(pendencia_id)
        if not pend:
            raise PendenciaError("Pendência not found")

        # Call DB function which inserts the new fluxo_pendencia row and syncs entity status.
        # The DB function does not return the new id, so we'll fetch latest after calling it.
        PendenciaManager._call_avancar_by_id(pendencia_id, novo_status, analista, motivo)

        # After calling the DB function, get the latest fluxo row for this entity (the newly created one).
        latest = PendenciaManager.pendencia_atual(pend["entidade_tipo"], pend["entidade_id"])
        if not latest:
            raise PendenciaError("Failed to fetch latest pendência after advancing")

        new_fluxo_id = latest["id"]

        # If document_validities provided, validate and update documents to point to this fluxo row.
        if document_validities:
            # document_validities must be a list of objects
            if not isinstance(document_validities, list):
                raise PendenciaError("document_validities must be a list")

            # Parse and validate structure, collect doc_ids and map doc_id -> validade_str
            doc_map = {}  # doc_id -> validade_str
            try:
                for dv in document_validities:
                    if not isinstance(dv, dict):
                        raise PendenciaError("Each document_validity must be an object with documento_id and validade")
                    if "documento_id" not in dv or "validade" not in dv:
                        raise PendenciaError("Each document_validity must include documento_id and validade")

                    try:
                        doc_id = int(dv["documento_id"])
                    except Exception:
                        raise PendenciaError(f"Invalid documento_id: {dv.get('documento_id')}")

                    validade_str = dv["validade"]
                    # validate date format (YYYY-MM-DD)
                    try:
                        datetime.strptime(validade_str, "%Y-%m-%d").date()
                    except ValueError:
                        raise PendenciaError(
                            f"Invalid date format for documento {doc_id}: {validade_str}. Use YYYY-MM-DD.")

                    # avoid duplicates
                    doc_map[doc_id] = validade_str
            except PendenciaError:
                raise
            except Exception as exc:
                msg = PendenciaManager._extract_error_message(exc) if hasattr(PendenciaManager,
                                                                              "_extract_error_message") else str(exc)
                raise PendenciaError(msg) from exc

            if not doc_map:
                # nothing to do
                return PendenciaManager.pendencia_atual(pend["entidade_tipo"], pend["entidade_id"])

            # Batch-validate ownership: get allowed document ids for this pendência's entity in one query.
            entidade_tipo = pend["entidade_tipo"].upper()
            entidade_id = pend["entidade_id"]

            # Build parameterized IN list for safety
            doc_ids = list(doc_map.keys())
            param_names = {}
            in_clause_parts = []
            for idx, did in enumerate(doc_ids):
                key = f"did_{idx}"
                param_names[key] = did
                in_clause_parts.append(f":{key}")
            in_clause = ",".join(in_clause_parts)

            try:
                if entidade_tipo == "EMPRESA":
                    sql = text(f"""
                        SELECT de.id AS id
                        FROM eventual.documento_empresa de
                        WHERE de.id IN ({in_clause}) AND de.empresa_cnpj::text = :entidade_id
                    """)
                    params = {**param_names, "entidade_id": entidade_id}
                    rows = db.session.execute(sql, params).fetchall()
                elif entidade_tipo == "VEICULO":
                    sql = text(f"""
                        SELECT dv.id AS id
                        FROM eventual.documento_veiculo dv
                        WHERE dv.id IN ({in_clause}) AND dv.veiculo_placa = :entidade_id
                    """)
                    params = {**param_names, "entidade_id": entidade_id}
                    rows = db.session.execute(sql, params).fetchall()
                elif entidade_tipo == "MOTORISTA":
                    sql = text(f"""
                        SELECT dm.id AS id
                        FROM eventual.documento_motorista dm
                        WHERE dm.id IN ({in_clause}) AND dm.motorista_id::text = :entidade_id
                    """)
                    params = {**param_names, "entidade_id": entidade_id}
                    rows = db.session.execute(sql, params).fetchall()
                elif entidade_tipo == "VIAGEM":
                    sql = text(f"""
                        SELECT dv.id AS id
                        FROM eventual.documento_viagem dv
                        WHERE dv.id IN ({in_clause}) AND dv.viagem_id::text = :entidade_id
                    """)
                    params = {**param_names, "entidade_id": entidade_id}
                    rows = db.session.execute(sql, params).fetchall()
                else:
                    raise PendenciaError(f"Unsupported entidade_tipo for document validation: {entidade_tipo}")

                allowed_ids = {r["id"] if hasattr(r, "_mapping") == False else r._mapping.get("id") or r[0] for r in
                               rows}
                # The above construct handles different cursor row types robustly.

                # Validate all provided doc_ids are allowed
                invalid = [d for d in doc_ids if d not in allowed_ids]
                if invalid:
                    raise PendenciaError(f"Documentos inválidos ou não pertencem à entidade da pendência: {invalid}")

                # Now update each document with the correct validade and fluxo_pendencia_id
                for doc_id, validade_str in doc_map.items():
                    db.session.execute(
                        text("""
                             UPDATE eventual.documento
                             SET validade           = :validade,
                                 fluxo_pendencia_id = :fluxo_id
                             WHERE id = :doc_id
                             """),
                        {"validade": validade_str, "fluxo_id": new_fluxo_id, "doc_id": doc_id}
                    )
                    if novo_status == "APROVADO":
                        db.session.execute(
                            text("""
                                 UPDATE eventual.documento
                                 SET aprovado_em = NOW()
                                 WHERE fluxo_pendencia_id = :fluxo_id
                                 """),
                            {"fluxo_id": new_fluxo_id}
                        )

            except SQLAlchemyError as exc:
                msg = PendenciaManager._extract_error_message(exc)
                raise PendenciaError(msg) from exc

        # Return the latest pendência for the entity (reflects the new status)
        return PendenciaManager.pendencia_atual(pend["entidade_tipo"], pend["entidade_id"])

    # -----------------------
    # Internal helpers
    # -----------------------
    @staticmethod
    def _call_avancar_by_id(pendencia_id: int, novo_status: str, analista: Optional[str], motivo: Optional[str]) -> None:
        try:
            db.session.execute(
                text("""
                    SELECT eventual.avancar_pendencia(:fluxo_id, :novo_status, :analista, :motivo)
                """),
                {
                    "fluxo_id": pendencia_id,
                    "novo_status": novo_status,
                    "analista": analista,
                    "motivo": motivo,
                }
            )
        except SQLAlchemyError as exc:
            msg = PendenciaManager._extract_error_message(exc)
            raise PendenciaError(msg) from exc

    @staticmethod
    def _create_pendencia(entidade_tipo: str, entidade_id: str, status: str) -> int:
        """
        Insert a new fluxo_pendencia row and return its id.
        This is used when an entidade must create the initial AGUARDANDO_ANALISE
        or restart the flow. We insert directly (triggers will validate).
        """
        try:
            res = db.session.execute(
                text("""
                    INSERT INTO eventual.fluxo_pendencia (
                        entidade_tipo, entidade_id, status, analista, motivo
                    )
                    VALUES (:entidade_tipo, :entidade_id, :status, NULL, NULL)
                    RETURNING id
                """),
                {"entidade_tipo": entidade_tipo, "entidade_id": entidade_id, "status": status}
            )
            row = res.first()
            if not row:
                raise PendenciaError("Failed to create pendência")
            return int(row[0])
        except SQLAlchemyError as exc:
            msg = PendenciaManager._extract_error_message(exc)
            raise PendenciaError(msg) from exc

    @staticmethod
    def _extract_error_message(exc: Exception) -> str:
        try:
            orig = getattr(exc, "orig", None)
            if orig is not None:
                return str(orig).strip()
            return str(exc).strip()
        except Exception:
            return "Database error while processing pendência."
