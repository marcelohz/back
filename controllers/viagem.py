import os
from flask import Blueprint, jsonify, request, session, send_file
from app import handle_500
from controllers.autenticacao import empresa_autorizada
from db import db
from models.viagem import Viagem
from models.documento import Documento, DocumentoViagem
from documento_storage import save_document, get_absolute_path
from util.documento_manager import processar_documentos

viagem_bp = Blueprint("viagem", __name__)


# --- LIST ALL VIAGENS ---
@viagem_bp.route("", methods=["GET"])
@empresa_autorizada(Viagem)
def list_viagens():
    empresa_cnpj = session.get("empresa_cnpj")
    if not empresa_cnpj:
        return jsonify({"error": "No empresa_cnpj in session"}), 401

    viagens = Viagem.query.filter_by(empresa_cnpj=empresa_cnpj).all()
    result = [
        {
            "id": v.id,
            "origem": v.origem,
            "destino": v.destino,
            "data_saida": v.data_saida.isoformat() if v.data_saida else None,
            "data_chegada": v.data_chegada.isoformat() if v.data_chegada else None,
            "motorista_id": v.motorista_id,
            "veiculo_placa": v.veiculo_placa,
            "empresa_cnpj": v.empresa_cnpj,
            "data_cadastro": v.data_cadastro.isoformat() if v.data_cadastro else None,
        }
        for v in viagens
    ]
    return jsonify(result)


# --- GET ONE VIAGEM ---
@viagem_bp.route("/<int:viagem_id>", methods=["GET"])
@empresa_autorizada(Viagem)
def get_viagem(viagem_id):
    v = Viagem.query.get(viagem_id)
    if not v:
        return jsonify({"error": "Viagem not found"}), 404

    # Check existing documents
    documentos_existentes = (
        db.session.query(Documento.documento_tipo_nome)
        .join(DocumentoViagem, DocumentoViagem.id == Documento.id)
        .filter(DocumentoViagem.viagem_id == viagem_id)
        .all()
    )
    documentos_status = {tipo[0]: True for tipo in documentos_existentes}

    return jsonify({
        "id": v.id,
        "origem": v.origem,
        "destino": v.destino,
        "data_saida": v.data_saida.isoformat() if v.data_saida else None,
        "data_chegada": v.data_chegada.isoformat() if v.data_chegada else None,
        "motorista_id": v.motorista_id,
        "veiculo_placa": v.veiculo_placa,
        "empresa_cnpj": v.empresa_cnpj,
        "data_cadastro": v.data_cadastro.isoformat() if v.data_cadastro else None,
        "documentos": documentos_status
    })


# --- CREATE NEW VIAGEM ---
@viagem_bp.route("", methods=["POST"])
@empresa_autorizada(Viagem)
def create_viagem():
    data = request.form or {}
    nota_fiscal_file = request.files.get("nota_fiscal_file")
    required_fields = ["origem", "destino", "motorista_id", "veiculo_placa", "data_saida"]
    missing = [f for f in required_fields if not data.get(f)]
    if missing:
        return jsonify({"error": f"Missing required fields: {', '.join(missing)}"}), 400

    try:
        nova = Viagem(
            empresa_cnpj=session.get("empresa_cnpj"),
            origem=data.get("origem"),
            destino=data.get("destino"),
            data_saida=data.get("data_saida"),
            data_chegada=data.get("data_chegada"),
            motorista_id=data.get("motorista_id"),
            veiculo_placa=data.get("veiculo_placa"),
        )
        db.session.add(nova)
        db.session.flush()  # ensure nova.id exists for linking

        # Optional nota fiscal upload
        uploaded_files = {"NOTA_FISCAL": nota_fiscal_file}
        processar_documentos("viagem", nova.id, uploaded_files, session.get("empresa_cnpj"))

        db.session.commit()
        return jsonify({"message": "Viagem criada com sucesso"}), 201

    except Exception as e:
        db.session.rollback()
        return handle_500(e)


# --- UPDATE VIAGEM ---
@viagem_bp.route("/<int:viagem_id>", methods=["PUT"])
@empresa_autorizada(Viagem)
def update_viagem(viagem_id):
    v = Viagem.query.get(viagem_id)
    if not v:
        return jsonify({"error": "Viagem not found"}), 404

    data = request.form or {}
    nota_fiscal_file = request.files.get("nota_fiscal_file")

    try:
        for field in ["origem", "destino", "data_saida", "data_chegada", "motorista_id", "veiculo_placa"]:
            if field in data and data[field] is not None:
                setattr(v, field, data[field])

        if nota_fiscal_file:
            meta = save_document(
                file=nota_fiscal_file,
                entity_type="viagem",
                entity_id=str(viagem_id),
                empresa_cnpj=session.get("empresa_cnpj"),
                tipo_nome="NOTA_FISCAL"
            )

            existing_link = (
                db.session.query(DocumentoViagem)
                .join(Documento)
                .filter(DocumentoViagem.viagem_id == viagem_id)
                .filter(Documento.documento_tipo_nome == "NOTA_FISCAL")
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
                    documento_tipo_nome="NOTA_FISCAL",
                    caminho=meta["caminho"],
                    tamanho=meta["tamanho"],
                    hash=meta["hash"],
                    data_upload=meta["data_upload"],
                )
                db.session.add(doc)
                db.session.flush()
                link = DocumentoViagem(id=doc.id, viagem_id=viagem_id)
                db.session.add(link)

        db.session.commit()
        return jsonify({"message": f"Viagem {viagem_id} atualizada com sucesso"})

    except Exception as e:
        db.session.rollback()
        return handle_500(e)


# --- DELETE VIAGEM ---
@viagem_bp.route("/<int:viagem_id>", methods=["DELETE"])
@empresa_autorizada(Viagem)
def delete_viagem(viagem_id):
    v = Viagem.query.get(viagem_id)
    if not v:
        return jsonify({"error": "Viagem not found"}), 404

    try:
        db.session.delete(v)
        db.session.commit()
        return jsonify({"message": f"Viagem {viagem_id} excluída com sucesso"})
    except Exception as e:
        db.session.rollback()
        return handle_500(e)


# --- DOWNLOAD NOTA FISCAL ---
@viagem_bp.route("/<int:viagem_id>/documento/<tipo_nome>", methods=["GET"])
@empresa_autorizada(Viagem)
def download_viagem_documento(viagem_id, tipo_nome):
    link = (
        db.session.query(DocumentoViagem)
        .join(Documento)
        .filter(DocumentoViagem.viagem_id == viagem_id)
        .filter(Documento.documento_tipo_nome == tipo_nome.upper())
        .first()
    )

    if not link:
        return jsonify({"error": f"Documento '{tipo_nome}' not found for viagem {viagem_id}"}), 404

    doc = link.documento
    file_path = get_absolute_path(doc.caminho)
    if not os.path.exists(file_path):
        return jsonify({"error": "File not found on server"}), 404

    return send_file(file_path, as_attachment=True)
