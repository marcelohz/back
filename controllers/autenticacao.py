# controllers/autenticacao.py
from flask import Blueprint, request, redirect
from itsdangerous import URLSafeTimedSerializer, SignatureExpired, BadSignature
from werkzeug.security import check_password_hash, generate_password_hash
import app
from config import frontend_url
from db import db
import secrets
from datetime import datetime, timedelta
from models.token_validacao_email import TokenValidacaoEmail
import os
from util.email_service import envia_email
from util.doc_sync import sync_documents_for_empresa

autenticacao_bp = Blueprint("autenticacao", __name__)

SALT = 'ekyHvGq28FC-Qb6a0bFgtFAClg7MhOXgO6H0ZNEsfE0'

# login
@autenticacao_bp.route("/login", methods=["POST"])
def login():
    data = request.json or {}
    email = data.get("email")
    senha = data.get("senha")
    if not email or not senha:
        return jsonify({"error": "Email and password required"}), 400

    usuario = Usuario.query.filter_by(email=email).first()

    if not usuario:
        return jsonify({"error": "INVALID_CREDENTIALS"}), 401

    if usuario.senha is None:
        return jsonify({"error": "PASSWORD_NOT_SET"}), 403

    if not check_password_hash(usuario.senha, senha):
        return jsonify({"error": "INVALID_CREDENTIALS"}), 401

    if not usuario.email_validado:
        return jsonify({"error": "EMAIL_NAO_VALIDADO"}), 403

    if not usuario.ativo:
        return jsonify({"error": "USUARIO_INATIVO"}), 403

    session["usuario_id"] = usuario.id
    session["empresa_cnpj"] = usuario.empresa_cnpj
    session["email"] = usuario.email
    session["papel"] = usuario.papel_nome
    sync_warning = None

    if usuario.empresa_cnpj:
        try:
            result = sync_documents_for_empresa(cnpj=usuario.empresa_cnpj)

            if not result.get("ok"):
                sync_warning = "Falha ao sincronizar documentos externos"

        except Exception:
            # defensive: sync must never break login
            sync_warning = "Erro inesperado ao sincronizar documentos externos"

    if sync_warning:
        return jsonify({
            "message": "Logged in successfully",
            "warning": sync_warning
        })

    return jsonify({"message": "Logged in successfully"})


@autenticacao_bp.route("/troca-senha", methods=["POST"])
def troca_senha():
    if "usuario_id" not in session:
        return jsonify({"error": "Authentication required"}), 401

    data = request.json or {}
    senha_atual = data.get("senha_atual")
    nova_senha = data.get("nova_senha")

    if not senha_atual or not nova_senha:
        return jsonify({"error": "Both current and new passwords are required"}), 400

    # usuario = Usuario.query.filter_by(id=session["usuario_id"], ativo=True).first()
    usuario = Usuario.query.filter_by(
        id=session["usuario_id"],
        ativo=True,
        email_validado=True
    ).first()

    if not usuario:
        return jsonify({"error": "Usuário inativo"}), 403

    from werkzeug.security import check_password_hash
    if not check_password_hash(usuario.senha, senha_atual):
        return jsonify({"error": "Current password is incorrect"}), 401

    usuario.senha = generate_password_hash(nova_senha)
    db.session.commit()
    return jsonify({"message": "Password changed successfully"})


# logout
@autenticacao_bp.route("/logout", methods=["POST"])
def logout():
    session.clear()
    response = redirect("/login")
    return response


@autenticacao_bp.route("/me", methods=["GET"])
def me():
    user_id = session.get("usuario_id")
    if not user_id:
        # still OK to return 401 if there is NO session at all
        return jsonify({"error": "Usuário não autenticado"}), 401

    usuario = Usuario.query.get(user_id)
    if not usuario:
        session.clear()
        return jsonify({"error": "Usuário não encontrado"}), 200  # IMPORTANT: still 200

    # ALWAYS return identity with 200
    return jsonify({
        "usuario_id": usuario.id,
        "empresa_cnpj": usuario.empresa_cnpj,
        "email": usuario.email,
        "papel": usuario.papel_nome,
        "email_validado": usuario.email_validado,
        "ativo": usuario.ativo,
    }), 200



from flask import session, jsonify
from models.usuario import Usuario
def analista_logado(f):
    """
    Protects endpoints so only logged-in users with papel = 'ANALISTA'
    and a validated, active account can access.
    """
    @wraps(f)
    def decorated(*args, **kwargs):
        # Must be logged in
        user_id = session.get("usuario_id")
        if not user_id:
            return jsonify({"error": "Authentication required"}), 401

        # Must have papel = 'ANALISTA'
        if session.get("papel") != "ANALISTA":
            return jsonify({"error": "Access restricted to analista users"}), 403

        usuario = Usuario.query.get(user_id)
        if not usuario:
            session.clear()
            return jsonify({"error": "Usuário não encontrado"}), 401

        if not usuario.ativo:
            return jsonify({"error": "USUARIO_INATIVO"}), 403

        if not usuario.email_validado:
            return jsonify({"error": "EMAIL_NAO_VALIDADO"}), 403

        return f(*args, **kwargs)
    return decorated



# decorator for protected endpoints
from functools import wraps
from flask import session, jsonify
from models.usuario import Usuario
def logado(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        user_id = session.get("usuario_id")
        if not user_id:
            return jsonify({"error": "Authentication required"}), 401

        usuario = Usuario.query.get(user_id)
        if not usuario:
            session.clear()
            return jsonify({"error": "Usuário não encontrado"}), 401

        # identity only — no ativo / email_validado checks here
        return f(*args, **kwargs)

    return decorated



def empresa_autorizada(recurso):
    from functools import wraps
    from flask import request, jsonify, session

    # Map resource_type to its id field and CNPJ field
    id_field_map = {
        'Empresa': 'cnpj',
        'Veiculo': 'placa',
        'Usuario': 'id',
        'Motorista': 'id',
        'Viagem': 'id',
    }

    cnpj_field_map = {
        'Empresa': 'cnpj',
        'Veiculo': 'empresa_cnpj',
        'Usuario': 'empresa_cnpj',
        'Motorista': 'empresa_cnpj',
        'Viagem': 'empresa_cnpj',
    }

    id_field = id_field_map.get(recurso.__name__)
    cnpj_field = cnpj_field_map.get(recurso.__name__)

    def decorator(f):
        @wraps(f)
        @logado  # assumes session is set
        def decorated_function(*args, **kwargs):
            user_papel = session.get('papel')
            user_cnpj = session.get('empresa_cnpj')
            user_id = session.get("usuario_id")

            # Ensure user is empresa
            if user_papel != 'EMPRESA':
                return jsonify({"error": "Access restricted to empresa users"}), 403
            if not user_cnpj:
                return jsonify({"error": "User not associated with any empresa"}), 403

            # -------------------------------------------------
            # NEW: require validated email
            # -------------------------------------------------
            usuario = Usuario.query.get(user_id)
            if not usuario:
                session.clear()
                return jsonify({"error": "Usuário não encontrado"}), 401

            if not usuario.email_validado:
                return jsonify({"error": "EMAIL_NAO_VALIDADO"}), 403

            # Extract empresa_cnpj from request for POST/PUT
            if request.method in ['POST', 'PUT']:
                # data = request.json or {}
                if request.is_json:
                    data = request.get_json(silent=True) or {}
                else:
                    data = request.form.to_dict() or {}
                target_cnpj = data.get(cnpj_field)
                if target_cnpj and target_cnpj != user_cnpj:
                    return jsonify({"error": "Cannot modify resources for another empresa"}), 403

            # Check resource's empresa_cnpj for GET/PUT using id_field
            if id_field and id_field in kwargs:
                resource = recurso.query.get(kwargs[id_field])
                if not resource:
                    return jsonify({"error": f"{recurso.__name__} not found"}), 404
                target_cnpj = getattr(resource, cnpj_field)
                if target_cnpj != user_cnpj:
                    return jsonify({"error": "Access restricted to your own empresa's resources"}), 403

            return f(*args, **kwargs)
        return decorated_function
    return decorator


# --- Create email validation token ---
def cria_token(usuario: Usuario):
    token_str = secrets.token_urlsafe(32)

    # Remove any existing tokens for this user
    TokenValidacaoEmail.query.filter_by(usuario_id=usuario.id).delete()

    token_row = TokenValidacaoEmail(
        usuario_id=usuario.id,
        token=token_str,
        criado_em=datetime.utcnow(),
        expira_em=datetime.utcnow() + timedelta(hours=24)
    )

    db.session.add(token_row)
    return token_str


@autenticacao_bp.route("/validar-email/<token>", methods=["GET"])
def validar_email(token):
    # 1 — Find token
    t = TokenValidacaoEmail.query.filter_by(token=token).first()
    if not t:
        return "Token inválido", 400

    # 2 — Check expiration
    now = datetime.utcnow()
    if t.expira_em < now:
        return "Token expirado", 400

    # 3 — Mark email as validated
    usuario = t.usuario
    usuario.email_validado = True

    # 4 — Remove the validation token
    db.session.delete(t)
    db.session.commit()

    # 5 — Create a password setup token (reuse reset-password mechanism)
    password_token = serializer.dumps(usuario.email, salt=SALT)

    session.clear()

    # 6 — Redirect to frontend password setup page

    url = frontend_url(f"/reseta-senha?token={password_token}")
    return redirect(url)


SMTP_SERVER = "smtp-mail.outlook.com"
SMTP_PORT = 587
SMTP_USERNAME = "xxxxxxxxxxxxxxxxxx@metroplan.rs.gov.br"  # change later
SMTP_PASSWORD = "xxxxxxxxxxxxxxx"  # change later


def envia_email_validacao(usuario: Usuario, token: str) -> bool:
    """
    Sends the email validation link to the user.
    """
    base_url = (
        "http://localhost:3000"
        if os.environ.get("FLASK_ENV") == "development"
        else "https://tavullia.metroplan.rs.gov.br"
    )
    validation_url = f"{base_url}/validar-email?token={token}"

    corpo = (
        f"Olá {usuario.nome},\n\n"
        f"Por favor valide seu email clicando no link abaixo:\n\n"
        f"{validation_url}\n\n"
        f"Obrigado."
    )

    if os.environ.get("SEM_EMAIL") == "true":
        print(validation_url)
        return True

    return envia_email(usuario.email, "Validação de Email", corpo)

serializer = URLSafeTimedSerializer(app.get_secret_key())

@autenticacao_bp.route("/esqueci-senha", methods=["POST"])
def envia_link_redefinir_senha():
    """
    Sends a password reset link to the user.
    Expects JSON: { "email": "user@example.com" }
    """
    data = request.get_json() or {}
    email = data.get("email")
    if not email:
        return jsonify({"error": "Email is required"}), 400

    # usuario = Usuario.query.filter_by(email=email, ativo=True).first()
    usuario = Usuario.query.filter_by(
        email=email,
        ativo=True,
        email_validado=True
    ).first()

    # Never reveal if email exists
    if not usuario:
        return jsonify({"message": "If the email exists, a reset link has been sent"}), 200

    # Generate token
    token = serializer.dumps(usuario.email, salt=SALT)

    reset_url = frontend_url(f"/reseta-senha?token={token}")

    # Compose email
    corpo = (
        f"Olá {usuario.nome},\n\n"
        f"Use o link para criar uma nova senha:\n\n"
        f"{reset_url}\n\n"
        f"Obrigado."
    )

    envia_email(usuario.email, "Redefinição de Senha", corpo)

    return jsonify({"message": "If the email exists, a reset link has been sent"}), 200


@autenticacao_bp.route("/reseta-senha", methods=["POST"])
def reseta_senha():
    """
    Resets a user's password given a valid token.
    Expects JSON:
    {
        "token": "<token from email>",
        "nova_senha": "<new password>"
    }
    """
    data = request.get_json() or {}
    token = data.get("token")
    nova_senha = data.get("nova_senha")

    if not token or not nova_senha:
        return jsonify({"error": "Token and new password are required"}), 400

    try:
        # Validate token, max age 24 hours (86400 seconds)
        email = serializer.loads(token, salt=SALT, max_age=86400)
    except SignatureExpired:
        return jsonify({"error": "Token expired"}), 400
    except BadSignature:
        return jsonify({"error": "Invalid token"}), 400

    # Find user
    # usuario = Usuario.query.filter_by(email=email, ativo=True).first()
    usuario = Usuario.query.filter_by(
        email=email,
        ativo=True,
        email_validado=True
    ).first()

    if not usuario:
        return jsonify({"error": "User not found or inactive"}), 404

    # Update password
    usuario.senha = generate_password_hash(nova_senha)
    db.session.commit()

    return jsonify({"message": "Password has been reset successfully"}), 200


@autenticacao_bp.route("/reenvia-validacao", methods=["POST"])
def reenvia_validacao():
    data = request.get_json(silent=True) or {}
    email = data.get("email")

    # Always return 200 to avoid leaking user existence
    if not email:
        return jsonify({"message": "If the email exists, a new validation link was sent"}), 200

    usuario = Usuario.query.filter_by(email=email).first()
    if not usuario:
        return jsonify({"message": "If the email exists, a new validation link was sent"}), 200

    # If already validated, do nothing (idempotent)
    if usuario.email_validado:
        return jsonify({"message": "Email already validated"}), 200

    # Generate a new token (old ones are deleted inside cria_token)
    token = cria_token(usuario)
    db.session.commit()

    # Send validation email
    envia_email_validacao(usuario, token)

    return jsonify({"message": "Validation email resent"}), 200
