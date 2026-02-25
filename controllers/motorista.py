import os
from flask import Blueprint, jsonify, request, session, send_file
from app import handle_500
from controllers.autenticacao import empresa_autorizada
from db import db
from models.motorista import Motorista
from models.documento import Documento, DocumentoMotorista
from documento_storage import save_document, get_absolute_path
from util.documento_manager import processar_documentos
from util.pendencia_manager import PendenciaManager

motorista_bp = Blueprint("motorista", __name__)


# --- LIST ALL MOTORISTAS ---
@motorista_bp.route("", methods=["GET"])
@empresa_autorizada(Motorista)
def list_motoristas():
    empresa_cnpj = session.get("empresa_cnpj")
    if not empresa_cnpj:
        return jsonify({"error": "No empresa_cnpj in session"}), 401

    motoristas = Motorista.query.filter_by(empresa_cnpj=empresa_cnpj).all()
    result = [
        {
            "id": m.id,
            "nome": m.nome,
            "cpf": m.cpf,
            "cnh": m.cnh,
            "email": m.email,
            "empresa_cnpj": m.empresa_cnpj,
            "data_cadastro": m.data_cadastro.isoformat() if m.data_cadastro else None,
        }
        for m in motoristas
    ]
    return jsonify(result)


# --- GET ONE MOTORISTA ---
@motorista_bp.route("/<int:motorista_id>", methods=["GET"])
@empresa_autorizada(Motorista)
def get_motorista(motorista_id):
    m = Motorista.query.get(motorista_id)
    if not m:
        return jsonify({"error": "Motorista not found"}), 404

    # --- Check existing documentos ---
    # documentos_existentes = (
    #     db.session.query(Documento.documento_tipo_nome)
    #     .join(DocumentoMotorista)
    #     .filter(DocumentoMotorista.motorista_id == motorista_id)
    #     .all()
    # )
    documentos_existentes = (
        db.session.query(Documento.documento_tipo_nome)
        .join(DocumentoMotorista, DocumentoMotorista.id == Documento.id)
        .filter(DocumentoMotorista.motorista_id == motorista_id)
        .all()
    )
    documentos_status = {tipo[0]: True for tipo in documentos_existentes}

    return jsonify({
        "id": m.id,
        "nome": m.nome,
        "cpf": m.cpf,
        "cnh": m.cnh,
        "email": m.email,
        "empresa_cnpj": m.empresa_cnpj,
        "data_cadastro": m.data_cadastro.isoformat() if m.data_cadastro else None,
        "documentos": documentos_status
    })


# --- CREATE NEW MOTORISTA ---
@motorista_bp.route("", methods=["POST"])
@empresa_autorizada(Motorista)
def create_motorista():
    data = request.form or {}
    cnh_file = request.files.get("cnh_file")
    required_fields = ["cpf", "cnh", "nome"]
    missing = [f for f in required_fields if not data.get(f)]
    if missing:
        return jsonify({"error": f"Missing required fields: {', '.join(missing)}"}), 400

    try:
        cpf = data["cpf"]
        existing = Motorista.query.filter_by(cpf=cpf).first()
        if existing:
            return jsonify({"error": f"Motorista com CPF {cpf} já cadastrado."}), 400

        novo = Motorista(
            empresa_cnpj=session.get("empresa_cnpj"),
            cpf=cpf,
            cnh=data.get("cnh"),
            email=data.get("email"),
            nome=data.get("nome"),
        )
        db.session.add(novo)
        db.session.flush()  # ensures novo.id exists

        uploaded_files = {"CNH": cnh_file}
        processar_documentos("motorista", novo.id, uploaded_files, session.get("empresa_cnpj"))

        PendenciaManager.avancar_entidade("MOTORISTA", novo.id)

        db.session.commit()
        return jsonify({"message": "Motorista criado com sucesso, aguarde aprovação"}), 201

    except Exception as e:
        db.session.rollback()
        return handle_500(e)


# --- UPDATE EXISTING MOTORISTA ---
@motorista_bp.route("/<int:motorista_id>", methods=["PUT"])
@empresa_autorizada(Motorista)
def update_motorista(motorista_id):
    m = Motorista.query.get(motorista_id)
    if not m:
        return jsonify({"error": "Motorista not found"}), 404

    data = request.form or {}
    cnh_file = request.files.get("cnh_file")

    # --- Defensive: block updates if motorista has a pendência currently under analysis ---
    atual = PendenciaManager.pendencia_atual("MOTORISTA", str(motorista_id))
    if atual and atual.get("status") == "EM_ANALISE":
        current_status = atual.get("status")
        print(f"[INFO] Update blocked for motorista {motorista_id}: pendência status {current_status}")
        return jsonify({
            "error": "Motorista está em análise. Atualização não permitida enquanto o status for EM_ANALISE.",
            "pendencia_status": current_status
        }), 409

    try:
        for field in ["cpf", "cnh", "email", "nome"]:
            if field in data and data[field] is not None:
                setattr(m, field, data[field])

        # --- Handle optional document upload ---
        if cnh_file:
            meta = save_document(
                file=cnh_file,
                entity_type="motorista",
                entity_id=str(motorista_id),
                empresa_cnpj=session.get("empresa_cnpj"),
                tipo_nome="CNH"
            )

            existing_link = (
                db.session.query(DocumentoMotorista)
                .join(Documento)
                .filter(DocumentoMotorista.motorista_id == motorista_id)
                .filter(Documento.documento_tipo_nome == "CNH")
                .first()
            )

            if existing_link:
                doc = existing_link.documento
                doc.caminho = meta["caminho"]
                doc.tamanho = meta["tamanho"]
                doc.hash = meta["hash"]
                doc.data_upload = meta["data_upload"]
            else:
                doc = Documento(
                    documento_tipo_nome="CNH",
                    caminho=meta["caminho"],
                    tamanho=meta["tamanho"],
                    hash=meta["hash"],
                    data_upload=meta["data_upload"],
                )
                db.session.add(doc)
                db.session.flush()
                link = DocumentoMotorista(id=doc.id, motorista_id=motorista_id)
                db.session.add(link)

        PendenciaManager.avancar_entidade("MOTORISTA", str(motorista_id))

        db.session.commit()
        return jsonify({"message": f"Motorista {motorista_id} atualizado com sucesso"})

    except Exception as e:
        db.session.rollback()
        return handle_500(e)


# --- DELETE MOTORISTA ---
@motorista_bp.route("/<int:motorista_id>", methods=["DELETE"])
@empresa_autorizada(Motorista)
def delete_motorista(motorista_id):
    m = Motorista.query.get(motorista_id)
    if not m:
        return jsonify({"error": "Motorista not found"}), 404

    try:
        db.session.delete(m)
        db.session.commit()
        return jsonify({"message": f"Motorista {motorista_id} excluído com sucesso"})
    except Exception as e:
        db.session.rollback()
        return handle_500(e)


# --- DOWNLOAD DOCUMENTO (CNH, ETC) ---
@motorista_bp.route("/<int:motorista_id>/documento/<tipo_nome>", methods=["GET"])
@empresa_autorizada(Motorista)
def download_motorista_documento(motorista_id, tipo_nome):
    link = (
        db.session.query(DocumentoMotorista)
        .join(Documento)
        .filter(DocumentoMotorista.motorista_id == motorista_id)
        .filter(Documento.documento_tipo_nome == tipo_nome.upper())
        .first()
    )

    if not link:
        return jsonify({"error": f"Documento '{tipo_nome}' not found for motorista {motorista_id}"}), 404

    doc = link.documento
    file_path = get_absolute_path(doc.caminho)
    if not os.path.exists(file_path):
        return jsonify({"error": "File not found on server"}), 404

    return send_file(file_path, as_attachment=True)
