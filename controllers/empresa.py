import os
from flask import Blueprint, jsonify, request, session, send_file
from werkzeug.security import generate_password_hash
from app import handle_500
from controllers.autenticacao import empresa_autorizada, cria_token, envia_email_validacao
from db import db
from models.empresa import Empresa
from sqlalchemy import text
from sqlalchemy.exc import IntegrityError
from models.usuario import Usuario
from util.documento_manager import processar_documentos
from util.pendencia_manager import PendenciaManager


empresa_bp = Blueprint("empresa", __name__)


# --- LIST ALL EMPRESAS ---

@empresa_bp.route("", methods=["GET"])
def list_empresas():
    empresas = Empresa.query.all()
    result = [
        {
            "cnpj": e.cnpj,
            "nome_fantasia": e.nome_fantasia,
            "bairro": e.bairro,
            "cidade": e.cidade,
            "estado": e.estado,
            "telefone": e.telefone,
        }
        for e in empresas
    ]
    return jsonify(result)


# --- GET ONE EMPRESA ---
@empresa_bp.route("/<cnpj>", methods=["GET"])
@empresa_autorizada(Empresa)
def get_empresa(cnpj):
    empresa = Empresa.query.get(cnpj)
    if not empresa:
        return jsonify({"error": "Empresa not found"}), 404

    # --- Check which documentos exist ---
    documentos_existentes = (
        db.session.query(Documento.documento_tipo_nome)
        .join(DocumentoEmpresa)
        .filter(DocumentoEmpresa.empresa_cnpj == cnpj)
        .all()
    )
    # Convert to a simple object for easy frontend use
    documentos_status = {tipo[0]: True for tipo in documentos_existentes}

    return jsonify({
        "cnpj": empresa.cnpj,
        "nome": empresa.nome,
        "nome_fantasia": empresa.nome_fantasia,
        "endereco": empresa.endereco,
        "endereco_numero": empresa.endereco_numero,
        "bairro": empresa.bairro,
        "cidade": empresa.cidade,
        "estado": empresa.estado,
        "telefone": empresa.telefone,
        "cep": empresa.cep,
        "email": empresa.email,
        "endereco_complemento": empresa.endereco_complemento,
        "data_inclusao_eventual": empresa.data_inclusao_eventual.isoformat() if empresa.data_inclusao_eventual else None,
        "documentos": documentos_status  # <-- new field
    })


# --- CREATE NEW EMPRESA ---
@empresa_bp.route("", methods=["POST"])
def create_empresa():
    import documento_storage as storage
    from models.documento import Documento, DocumentoEmpresa

    # --- Get form fields ---
    cnpj = request.form.get("cnpj")
    email = request.form.get("email").lower()
    nome = request.form.get("nome").upper()
    # senha = request.form.get("senha")

    # --- Validate required fields ---
    if not cnpj:
        return jsonify({"error": "CNPJ is required"}), 400

    empresa_existente = Empresa.query.get(cnpj)
    usuario_existente = Usuario.query.filter_by(email=email).first()

    if empresa_existente:
        # --- The empresa already exists in geral.empresa ---

        # 1) Check if the email matches the existing empresa record
        if empresa_existente.email and empresa_existente.email.lower() != email:
            return jsonify({
                "error": "CNPJ já cadastrado com outro email."
            }), 409

        # 2) Email matches → now check if there is already a user for it
        if usuario_existente:
            return jsonify({
                "error": "Usuário já cadastrado. Tente se logar ou resetar senha."
            }), 409

    try:
        if not empresa_existente:
            empresa = Empresa(
                email=email,
                cnpj=cnpj,
                nome=nome,
            )
            db.session.add(empresa)

        if not usuario_existente:
            usuario = Usuario(
                email=email,
                empresa_cnpj=cnpj,
                nome=nome,
                # senha=generate_password_hash(senha),
                senha=None,
                papel_nome="EMPRESA",
                ativo=True
            )
            db.session.add(usuario)
            db.session.flush()
            token = cria_token(usuario)
            if not envia_email_validacao(usuario, token):
                db.session.rollback()
                return jsonify({"error": "Empresa não pôde ser cadastrada", "cnpj": cnpj}), 500

            # -------------------------------------------------
            # Create session immediately (email still unvalidated)
            # -------------------------------------------------
            # session["usuario_id"] = usuario.id
            # session["empresa_cnpj"] = usuario.empresa_cnpj
            # session["email"] = usuario.email
            # session["papel"] = usuario.papel_nome

        db.session.flush()

        PendenciaManager.avancar_entidade("EMPRESA", cnpj)

        db.session.commit()
        return jsonify({"message": "Empresa created", "cnpj": cnpj}), 201

    except IntegrityError as e:
        db.session.rollback()
        print("DB error:", e.orig)  # e.orig is the underlying database error
        return jsonify({"error": str(e.orig)}), 409
    except Exception as e:
        db.session.rollback()
        return handle_500(e)



# --- UPDATE EXISTING EMPRESA ---
from documento_storage import save_document
from models.documento import Documento, DocumentoEmpresa

@empresa_bp.route("/<cnpj>", methods=["PUT"])
@empresa_autorizada(Empresa)
def update_empresa(cnpj):
    empresa = Empresa.query.get(cnpj)
    if not empresa:
        return jsonify({"error": "Empresa not found"}), 404

    # --- Get JSON fields and uploaded files ---
    data = request.form or {}
    identidade_responsavel = request.files.get("identidade_responsavel")
    contrato_social = request.files.get("contrato_social")
    procuracao = request.files.get("procuracao")

    try:
        # --- Update regular fields ---
        campos = ["nome", "nome_fantasia", "bairro", "cidade", "estado", "telefone", "eventual",
                  "endereco_complemento", "endereco_numero"]

        for field in campos:
            if field in data:
                setattr(empresa, field, data[field])

        #  TODO: isso deveria ir pro create?
        if empresa.data_inclusao_eventual is None:
            empresa.data_inclusao_eventual = db.session.execute(text("SELECT CURRENT_DATE")).scalar()

        # --- Handle documents ---
        uploaded_files = {
            "IDENTIDADE_RESPONSAVEL": identidade_responsavel,
            "CONTRATO_SOCIAL": contrato_social,
            "PROCURACAO": procuracao
        }

        processar_documentos("empresa", cnpj, uploaded_files, cnpj)

        # --- Defensive check: if a pendência is currently under analysis, return a clear error ---
        atual = PendenciaManager.pendencia_atual("EMPRESA", cnpj)
        if atual and atual.get("status") == "EM_ANALISE":
            # 409 Conflict: client's request cannot be processed because entity is under analysis
            return jsonify({
                "error": "Empresa está em análise. Atualização não permitida.",
                "pendencia_status": "EM_ANALISE"
            }), 409

        PendenciaManager.avancar_entidade("EMPRESA", cnpj)

        db.session.commit()
        return jsonify({"message": f"Empresa {cnpj} updated successfully"})

    except Exception as e:
        db.session.rollback()
        return handle_500(e)



# --- DELETE EMPRESA ---
@empresa_bp.route("/<cnpj>", methods=["DELETE"])
def delete_empresa(cnpj):
    empresa = Empresa.query.get(cnpj)
    if not empresa:
        return jsonify({"error": "Empresa not found"}), 404

    try:
        db.session.delete(empresa)
        db.session.commit()
        return jsonify({"message": f"Empresa {cnpj} deleted successfully"})
    except Exception as e:
        db.session.rollback()
        return handle_500(e)


# --- LIST USUARIOS OF A SPECIFIC EMPRESA ---
@empresa_bp.route("/<cnpj>/usuarios", methods=["GET"])
@empresa_autorizada(Empresa)
def list_usuarios_of_empresa(cnpj):
    # --- Authentication ---
    if "usuario_id" not in session:
        return jsonify({"error": "Authentication required"}), 401

    empresa = Empresa.query.get(cnpj)
    if not empresa:
        return jsonify({"error": "Empresa not found"}), 404

    usuarios = [u for u in empresa.usuarios if u.ativo]  # type: ignore[attr-defined]

    # --- Serialize users ---
    result = [
        {
            "id": u.id,
            "email": u.email,
            "nome": u.nome,
            "cpf": u.cpf,
            "data_nascimento": u.data_nascimento.isoformat() if u.data_nascimento else None,
            "telefone": u.telefone
        }
        for u in usuarios
    ]

    return jsonify(result)


# --- LIST VEICULOS OF A SPECIFIC EMPRESA ---
@empresa_bp.route("/<cnpj>/veiculos", methods=["GET"])
@empresa_autorizada(Empresa)
def list_veiculos_of_empresa(cnpj):
    # --- Authentication ---

    empresa = Empresa.query.get(cnpj)
    if not empresa:
        return jsonify({"error": "Empresa not found"}), 404

    # --- Query veiculos ---
    veiculos = empresa.veiculos  # thanks to the relationship in models.veiculo

    # --- Serialize veiculos ---
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
            "data_inclusao_eventual": v.data_inclusao_eventual.isoformat() if v.data_inclusao_eventual else None,
        }
        for v in veiculos
    ]

    return jsonify(result)

@empresa_bp.route("/<cnpj>/documento/<tipo_nome>", methods=["GET"])
@empresa_autorizada(Empresa)
def download_documento(cnpj, tipo_nome):
    from models.documento import Documento, DocumentoEmpresa
    from documento_storage import get_absolute_path

    # Find the document linked to this empresa and tipo_nome
    link = (
        db.session.query(DocumentoEmpresa)
        .join(Documento)
        .filter(DocumentoEmpresa.empresa_cnpj == cnpj)
        .filter(Documento.documento_tipo_nome == tipo_nome.upper())
        .first()
    )

    if not link:
        return jsonify({"error": f"Documento '{tipo_nome}' not found for empresa {cnpj}"}), 404

    doc = link.documento
    file_path = get_absolute_path(doc.caminho)  # use helper to get absolute path

    if not os.path.exists(file_path):
        return jsonify({"error": "File not found on server"}), 404

    return send_file(file_path, as_attachment=True)
