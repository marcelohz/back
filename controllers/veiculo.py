from flask import Blueprint, jsonify, request, session
from sqlalchemy import text
from app import handle_500
from controllers.autenticacao import empresa_autorizada
from db import db
from models.veiculo import Veiculo
from util.documento_manager import processar_documentos
from util.helpers import empty_to_none
from util.pendencia_manager import PendenciaManager

veiculo_bp = Blueprint("veiculo", __name__)

def parse_int(value):
    try:
        return int(value)
    except (TypeError, ValueError):
        return None

# --- LIST ALL VEICULOS ---
@veiculo_bp.route("", methods=["GET"])
@empresa_autorizada(Veiculo)
def list_veiculos():
    empresa_cnpj = session.get("empresa_cnpj")
    if not empresa_cnpj:
        return jsonify({"error": "No empresa_cnpj in session"}), 401

    veiculos = Veiculo.query.filter_by(empresa_cnpj=empresa_cnpj).order_by(Veiculo.placa).all()
    result = [
        {
            "placa": v.placa,
            "chassi_numero": v.chassi_numero,
            "renavan": v.renavan,
            "modelo": v.modelo,
            "fretamento_veiculo_tipo_nome": v.fretamento_veiculo_tipo_nome,
            "potencia_motor": v.potencia_motor,
            "cor_principal_nome": v.cor_principal_nome,
            "numero_lugares": v.numero_lugares,
            "empresa_cnpj": v.empresa_cnpj,
            "ano_fabricacao": v.ano_fabricacao,
            "modelo_ano": v.modelo_ano,
            "veiculo_combustivel_nome":v.veiculo_combustivel_nome,
            "data_inclusao_eventual": v.data_inclusao_eventual.isoformat() if v.data_inclusao_eventual else None,
        }
        for v in veiculos
    ]
    return jsonify(result)


@veiculo_bp.route("/<placa>", methods=["GET"])
@empresa_autorizada(Veiculo)
def get_veiculo(placa):
    v = Veiculo.query.get(placa)
    if not v:
        return jsonify({"error": "Veiculo not found"}), 404

    # --- Check which documentos exist ---
    documentos_existentes = (
        db.session.query(Documento.documento_tipo_nome)
        .join(DocumentoVeiculo)
        .filter(DocumentoVeiculo.veiculo_placa == placa)
        .all()
    )
    documentos_status = {tipo[0]: True for tipo in documentos_existentes}

    return jsonify({
        "placa": v.placa,
        "chassi_numero": v.chassi_numero,
        "renavan": v.renavan,
        "modelo": v.modelo,
        "fretamento_veiculo_tipo_nome": v.fretamento_veiculo_tipo_nome,
        "potencia_motor": v.potencia_motor,
        "cor_principal_nome": v.cor_principal_nome,
        "numero_lugares": v.numero_lugares,
        "empresa_cnpj": v.empresa_cnpj,
        "ano_fabricacao": v.ano_fabricacao,
        "modelo_ano": v.modelo_ano,
        "veiculo_combustivel_nome": v.veiculo_combustivel_nome,
        "data_inclusao_eventual": v.data_inclusao_eventual.isoformat() if v.data_inclusao_eventual else None,
        "documentos": documentos_status  # <-- new field
    })


# --- DELETE VEICULO ---
@veiculo_bp.route("/<placa>", methods=["DELETE"])
@empresa_autorizada(Veiculo)
def delete_veiculo(placa):
    v = Veiculo.query.get(placa)
    if not v:
        return jsonify({"error": "Veiculo not found"}), 404

    try:
        db.session.delete(v)
        db.session.commit()
        return jsonify({"message": f"Veiculo {placa} deleted successfully"})
    except Exception as e:
        db.session.rollback()
        return handle_500(e)


from models.documento import Documento, DocumentoVeiculo
from documento_storage import save_document, get_absolute_path
import os
from flask import send_file

# --- CREATE NEW VEICULO with CRLV upload ---
@veiculo_bp.route("", methods=["POST"])
@empresa_autorizada(Veiculo)
def create_veiculo():
    data = request.form or {}
    data = empty_to_none(data)
    crlv_file = request.files.get("crlv")

    required_fields = ["placa"]
    missing = [f for f in required_fields if not data.get(f)]
    if missing:
        return jsonify({"error": f"Missing required fields: {', '.join(missing)}"}), 400

    try:
        placa = data["placa"].upper()
        existing = Veiculo.query.get(placa)
        if existing:
            return jsonify({"error": f"Veículo {placa} já cadastrado."}), 400

        novo = Veiculo(
            empresa_cnpj=session.get("empresa_cnpj"),
            placa=placa,
            chassi_numero=data.get("chassi_numero"),
            renavan=data.get("renavan"),
            modelo=data.get("modelo"),
            fretamento_veiculo_tipo_nome=data.get("fretamento_veiculo_tipo_nome"),
            potencia_motor=parse_int(data.get("potencia_motor")),
            cor_principal_nome=data.get("cor_principal_nome"),
            numero_lugares=parse_int(data.get("numero_lugares")),
            ano_fabricacao=parse_int(data.get("ano_fabricacao")),
            modelo_ano=parse_int(data.get("modelo_ano")),
            veiculo_combustivel_nome=data.get("veiculo_combustivel_nome"),
        )

        db.session.add(novo)
        db.session.flush()  # ensure novo.placa is available
        PendenciaManager.avancar_entidade("VEICULO", placa)

        if crlv_file:
            processar_documentos(
                "veiculo",
                placa,
                {"CRLV": crlv_file},
                session.get("empresa_cnpj"),
            )

        db.session.commit()
        return jsonify({"message": "Veículo criado, aguarde aprovação"}), 201

    except Exception as e:
        db.session.rollback()
        return handle_500(e)


# --- UPDATE VEICULO with CRLV upload ---
@veiculo_bp.route("/<placa>", methods=["PUT"])
@empresa_autorizada(Veiculo)
def update_veiculo(placa):
    placa = placa.upper()
    v = Veiculo.query.get(placa)
    if not v:
        return jsonify({"error": "Veiculo not found"}), 404

    data = request.form or {}
    data = empty_to_none(data)

    crlv_file = request.files.get("crlv")
    print("[DEBUG] crlv_file:", crlv_file)
    print("[DEBUG] crlv_file.filename:", getattr(crlv_file, "filename", None))
    try:
        int_fields = {"potencia_motor", "numero_lugares", "ano_fabricacao", "modelo_ano"}
        for field in [
            "chassi_numero", "renavan", "modelo", "fretamento_veiculo_tipo_nome",
            "potencia_motor", "cor_principal_nome", "numero_lugares",
            "ano_fabricacao", "modelo_ano", "veiculo_combustivel_nome",
        ]:
            if field in data:
                value = parse_int(data[field]) if field in int_fields else data[field]
                setattr(v, field, value)

        if v.data_inclusao_eventual is None:
            v.data_inclusao_eventual = db.session.execute(text("SELECT CURRENT_DATE")).scalar()

        atual = PendenciaManager.pendencia_atual("VEICULO", placa)
        if atual and atual.get("status") == "EM_ANALISE":
            current_status = atual.get("status")
            print(f"[INFO] Update blocked for veículo {placa}: pendência status {current_status}")
            return jsonify({
                "error": "Veículo está em análise. Atualização não permitida enquanto o status for EM_ANALISE.",
                "pendencia_status": current_status
            }), 409

        # --- Handle CRLV upload ---
        if crlv_file:
            meta = save_document(
                file=crlv_file,
                entity_type="veiculo",
                entity_id=placa,
                empresa_cnpj=session.get("empresa_cnpj"),
                tipo_nome="CRLV"
            )

            existing_link = (
                db.session.query(DocumentoVeiculo)
                .join(Documento)
                .filter(DocumentoVeiculo.veiculo_placa == placa)
                .filter(Documento.documento_tipo_nome == "CRLV")
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
                    documento_tipo_nome="CRLV",
                    caminho=meta["caminho"],
                    tamanho=meta["tamanho"],
                    hash=meta["hash"],
                    data_upload=meta["data_upload"],
                )
                db.session.add(doc)
                db.session.flush()
                link = DocumentoVeiculo(id=doc.id, veiculo_placa=placa)
                db.session.add(link)

        PendenciaManager.avancar_entidade("VEICULO", placa)

        db.session.commit()
        return jsonify({"message": f"Veículo {placa} updated successfully"})

    except Exception as e:
        db.session.rollback()
        return handle_500(e)


# --- DOWNLOAD CRLV ---
@veiculo_bp.route("/<placa>/documento/<tipo_nome>", methods=["GET"])
@empresa_autorizada(Veiculo)
def download_veiculo_documento(placa, tipo_nome):
    link = (
        db.session.query(DocumentoVeiculo)
        .join(Documento)
        .filter(DocumentoVeiculo.veiculo_placa == placa)
        .filter(Documento.documento_tipo_nome == tipo_nome.upper())
        .first()
    )

    if not link:
        return jsonify({"error": f"Documento '{tipo_nome}' not found for veículo {placa}"}), 404

    doc = link.documento
    file_path = get_absolute_path(doc.caminho)
    if not os.path.exists(file_path):
        return jsonify({"error": "File not found on server"}), 404

    return send_file(file_path, as_attachment=True)
