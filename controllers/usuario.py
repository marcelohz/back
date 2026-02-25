from flask import Blueprint, request, session, jsonify
from werkzeug.security import generate_password_hash

from app import handle_500
from controllers.autenticacao import empresa_autorizada
from db import db
from models.usuario import Usuario

usuario_bp = Blueprint("usuario", __name__)

# --- LIST USERS FOR LOGGED-IN EMPRESA ---
@usuario_bp.route("", methods=["GET"])
@empresa_autorizada(Usuario)
def list_usuarios():
    if "usuario_id" not in session:
        return jsonify({"error": "Authentication required"}), 401

    # only empresa users can list their company's users
    # if not session.get("eh_empresa", False):
    #     return jsonify({"error": "Access restricted to empresa users"}), 403

    empresa_cnpj = session["empresa_cnpj"]
    # usuarios = Usuario.query.filter_by(empresa_cnpj=empresa_cnpj, papel_nome="USUARIO_EMPRESA").all()
    usuarios = Usuario.query.filter_by(empresa_cnpj=empresa_cnpj, papel_nome="USUARIO_EMPRESA").all()

    result = [
        {
            "id": u.id,
            "email": u.email,
            "nome": u.nome,
            "cpf": u.cpf,
            "data_nascimento": u.data_nascimento.isoformat() if u.data_nascimento else None,
            "telefone": u.telefone,
            "ativo": u.ativo
        }
        for u in usuarios
    ]
    return jsonify(result)


# --- GET SINGLE USER ---
@usuario_bp.route("/<int:usuario_id>", methods=["GET"])
@empresa_autorizada(Usuario)
def get_usuario(usuario_id):
    if "usuario_id" not in session:
        return jsonify({"error": "Authentication required"}), 401

    # usuario = Usuario.query.get(usuario_id)
    usuario = Usuario.query.filter_by(id=usuario_id).first()
    if not usuario:
        return jsonify({"error": "Usuario not found"}), 404

    return jsonify({
        "id": usuario.id,
        "email": usuario.email,
        "nome": usuario.nome,
        "cpf": usuario.cpf,
        "data_nascimento": usuario.data_nascimento.isoformat() if usuario.data_nascimento else None,
        "telefone": usuario.telefone,
        "ativo": usuario.ativo
    })


# --- CREATE NEW USER (empresa only) ---
@usuario_bp.route("", methods=["POST"])
@empresa_autorizada(Usuario)
def create_usuario():
    # decorator deve fazer isso
    # if "usuario_id" not in session or not session.get("eh_empresa", False):
    #     return jsonify({"error": "Access restricted to empresa users"}), 403

    data = request.json or {}

    # --- Validate required fields ---
    required_fields = ["email", "nome", "senha"]
    missing = [f for f in required_fields if not data.get(f)]
    if missing:
        return jsonify({"error": f"Missing required fields: {', '.join(missing)}"}), 400

    # --- Check for duplicate email ---
    # existing = Usuario.query.filter_by(email=data["email"]).first()
    existing = Usuario.query.filter_by(email=data["email"]).first()

    if existing:
        return jsonify({"error": "Email already exists"}), 409

    # existing = Usuario.query.filter_by(cpf=data["cpf"]).first()
    existing = Usuario.query.filter_by(cpf=data["cpf"]).first()

    if existing:
        return jsonify({"error": "CPF already exists"}), 409


    papel_atual = session.get('papel')
    if papel_atual == 'EMPRESA':
        novo_papel = 'USUARIO_EMPRESA'
    elif papel_atual == 'ANALISTA':
        novo_papel = 'ANALISTA'
    else:
        return jsonify({"error": "Papel não definido ou inválido"}), 500

    try:
        novo = Usuario(
            email=data["email"],
            empresa_cnpj=session.get("empresa_cnpj"),
            nome=data["nome"],
            cpf=data.get("cpf"),
            data_nascimento=data.get("data_nascimento"),
            telefone=data.get("telefone"),
            senha=generate_password_hash(data["senha"]),
            papel_nome=novo_papel,
        )
        db.session.add(novo)
        db.session.commit()
        return jsonify({"message": "Usuario created", "id": novo.id}), 201
    except Exception as e:
        db.session.rollback()
        return handle_500(e)


# --- UPDATE EXISTING USER (empresa only, their own users) ---
@usuario_bp.route("/<int:usuario_id>", methods=["PUT"])
@empresa_autorizada(Usuario)
def update_usuario(usuario_id):
    usuario = Usuario.query.filter_by(id=usuario_id).first()

    data = request.json or {}
    try:
        for field in ["email", "nome", "cpf", "data_nascimento", "telefone", "celular"]:
            if field in data:
                setattr(usuario, field, data[field])
        # handle password update separately
        if "senha" in data:
            usuario.senha = generate_password_hash(data["senha"])

        db.session.commit()
        return jsonify({"message": f"Usuario {usuario_id} updated successfully"})
    except Exception as e:
        db.session.rollback()
        return handle_500(e)


# --- DELETE USER (empresa only, their own users) ---
@empresa_autorizada(Usuario)
@usuario_bp.route("/<int:usuario_id>", methods=["DELETE"])
def delete_usuario(usuario_id):

    if "usuario_id" not in session:
        return jsonify({"error": "Access restricted to empresa users"}), 403

    # usuario = Usuario.query.get(usuario_id)
    usuario = Usuario.query.filter_by(id=usuario_id).first()
    if not usuario:
        return jsonify({"error": "Usuario not found"}), 404

    if usuario.empresa_cnpj != session["empresa_cnpj"]:
        return jsonify({"error": "Access restricted"}), 403

    try:
        db.session.delete(usuario)
        db.session.commit()
        return jsonify({"message": f"Usuario {usuario_id} deleted successfully"})
    except Exception as e:
        db.session.rollback()
        return handle_500(e)


# --- TOGGLE ATIVO / INATIVO ---
@usuario_bp.route("/<int:usuario_id>/toggle-ativo", methods=["PUT"])
@empresa_autorizada(Usuario)
def toggle_usuario_ativo(usuario_id):

    empresa_cnpj = session.get("empresa_cnpj")
    usuario = Usuario.query.filter_by(id=usuario_id).first()

    if not usuario:
        return jsonify({"error": "Usuário não encontrado"}), 404

    # Ensure the user belongs to the same empresa
    if usuario.empresa_cnpj != empresa_cnpj:
        return jsonify({"error": "Acesso restrito"}), 403

    try:
        usuario.ativo = not usuario.ativo
        db.session.commit()
        status = "ativado" if usuario.ativo else "inativado"
        return jsonify({"message": f"Usuário {status} com sucesso.", "ativo": usuario.ativo})
    except Exception as e:
        db.session.rollback()
        return handle_500(e)

