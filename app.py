# app.py
import logging
import os
from flask import Flask, session
from flask_cors import CORS
from werkzeug.exceptions import HTTPException

from config import load_config
from db import db
from sqlalchemy import text

FRONTEND_ORIGINS = [
    "http://localhost:3000",
    "http://127.0.0.1:3000",
    "https://tavullia.metroplan.rs.gov.br"
]

import traceback
from flask import jsonify

SECRET_KEY = os.environ.get("SECRET_KEY", "dev-secret-key-for-tests")

def get_secret_key():
    """
    Returns the app's SECRET_KEY.
    Can be used safely from other modules.
    """
    return SECRET_KEY


def handle_500(e):
    """
    Call this inside an `except Exception as e:` block.

    - Prints the full stack trace to the console
    - Returns a JSON response to the client with HTTP 500
    """
    traceback.print_exc()  # prints full stack trace
    # return jsonify({"error": str(e)}), 500
    return jsonify({"error": "Erro não tratado no servidor. Tente novamente mais tarde."}), 500


def create_app():

    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(name)s: %(message)s"
    )

    app = Flask(__name__)
    load_config(app)

    app.url_map.strict_slashes = False

    # Choose config class based on environment
    # if os.environ.get("FLASK_ENV") == "development":
    #     app.config.from_object(DevelopmentConfig)
    # else:
    #     app.config.from_object(ProductionConfig)




    app.config['SECRET_KEY'] = SECRET_KEY
    # app.config['SECRET_KEY'] = os.environ.get("SECRET_KEY", "dev-secret-key-for-tests")

    is_prod = os.environ.get("FLASK_ENV") != "development"
    app.config.update({
        "SESSION_COOKIE_NAME": "session_eventual",
        "SESSION_COOKIE_HTTPONLY": True,
        "SESSION_COOKIE_SECURE": is_prod,
        "SESSION_COOKIE_PATH": "/",
        "SESSION_COOKIE_SAMESITE": "Lax" if is_prod else None
    })
    # app.config.update({
    #     "SESSION_COOKIE_NAME": "session_eventual",
    #     "SESSION_COOKIE_HTTPONLY": True,  # keep JS from touching it
    #     "SESSION_COOKIE_SECURE": False,  # localhost HTTP
    #     "SESSION_COOKIE_PATH": "/",
    #     "SESSION_COOKIE_SAMESITE": None
    # })

    # if os.environ.get("FLASK_ENV") == "development":
    #     app.config["SQLALCHEMY_DATABASE_URI"] = os.environ.get(
    #         "DATABASE_URL",
    #         "postgresql://postgres:master@localhost:5432/metroplan"
    #     )
    # else:
    #     db_url = os.environ.get("DATABASE_URL")
    #     if not db_url:
    #         raise RuntimeError("DATABASE_URL must be set in production or FLASK_ENV in development")
    #     app.config["SQLALCHEMY_DATABASE_URI"] = db_url
    #
    # app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

    db.init_app(app)

    # with app.app_context():
    #     db.create_all()  # Create tables

    CORS(
        app,
        origins=FRONTEND_ORIGINS,
        supports_credentials=True,
        methods=["GET", "POST", "PUT", "DELETE"],
        allow_headers=["Content-Type", "Authorization"],
    )

    # Register blueprints (imports happen after init_app)
    from controllers.front import front_bp
    from controllers.autenticacao import autenticacao_bp
    from controllers.empresa import empresa_bp
    from controllers.usuario import usuario_bp
    from controllers.veiculo import veiculo_bp
    from controllers.motorista import motorista_bp
    from controllers.analista import analista_bp
    from controllers.viagem import viagem_bp

    app.register_blueprint(front_bp)
    app.register_blueprint(autenticacao_bp, url_prefix="/api/autenticacao")
    app.register_blueprint(empresa_bp, url_prefix="/api/empresa")
    app.register_blueprint(usuario_bp, url_prefix="/api/usuario")
    app.register_blueprint(veiculo_bp, url_prefix="/api/veiculo")
    app.register_blueprint(motorista_bp, url_prefix="/api/motorista")
    app.register_blueprint(analista_bp, url_prefix="/api/analista")
    app.register_blueprint(viagem_bp, url_prefix="/api/viagem")

    @app.errorhandler(HTTPException)
    def handle_http_exception(e):
        return jsonify({"error": e.description}), e.code

    # @app.errorhandler(Exception)
    # def handle_exception(e):
    #     return jsonify({"error": "Erro interno no servidor"}), 500

    @app.route("/debug-session")
    def debug_session():
        return jsonify(dict(session))

    @app.route("/test-db")
    def test_db():
        try:
            with app.app_context():
                result = db.session.execute(text("SELECT 1")).scalar()
                return jsonify({"message": "Database connection successful", "result": result})
        except Exception as e:
            return handle_500(e)

    return app


if __name__ == "__main__":
    appx = create_app()
    appx.run(debug=True)
