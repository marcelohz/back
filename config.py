# config.py
import os

EMAIL_QUEUE = 'eventual:emails'

def load_config(app):
    """Load configuration into the Flask app with clean dev/prod branches."""

    flask_env = os.environ.get("FLASK_ENV", "development").lower()

    # ---------------------------
    # DEVELOPMENT CONFIG
    # ---------------------------
    if flask_env == "development":
        print(">>> Loading DEVELOPMENT config")

        app.config["SECRET_KEY"] = "dev-secret-key"

        # Frontend
        app.config["FRONTEND_BASE_URL"] = os.environ.get(
            "FRONTEND_BASE_URL",
            "http://localhost:3000"
        )

        #  banco da terceirizada
        third_party_host = os.environ.get("THIRD_PARTY_DB_HOST", "")
        third_party_dbname = os.environ.get("THIRD_PARTY_DB_NAME", "")
        third_party_user = os.environ.get("THIRD_PARTY_DB_USER", "")
        third_party_password = os.environ.get("THIRD_PARTY_DB_PASSWORD", "")

        app.config["THIRD_PARTY_DSN"] = (
            f"host={third_party_host} "
            f"dbname={third_party_dbname} "
            f"user={third_party_user} "
            f"password={third_party_password}"
        )

        # Dev Email
        app.config["OUTLOOK_EMAIL"] = os.environ.get("OUTLOOK_EMAIL")
        app.config["OUTLOOK_APP_PASSWORD"] = os.environ.get("OUTLOOK_APP_PASSWORD", "")

        # Dev DB fallback
        app.config["SQLALCHEMY_DATABASE_URI"] = os.environ.get(
            "DATABASE_URL"
        )

        app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False
        return


    # --------------------------
    # PRODUCTION CONFIG
    # --------------------------
    print(">>> Loading PRODUCTION config")

    app.config["SECRET_KEY"] = os.environ["SECRET_KEY"]

    # Frontend (must exist in prod)
    app.config["FRONTEND_BASE_URL"] = os.environ["FRONTEND_BASE_URL"]

    # Email (must exist)
    app.config["OUTLOOK_EMAIL"] = os.environ["OUTLOOK_EMAIL"]
    app.config["OUTLOOK_APP_PASSWORD"] = os.environ["OUTLOOK_APP_PASSWORD"]

    # DB (must exist)
    app.config["SQLALCHEMY_DATABASE_URI"] = os.environ["DATABASE_URL"]

    app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False

    # Third-party DB (prod, must exist)

    third_party_host = os.environ.get("THIRD_PARTY_DB_HOST", "")
    third_party_dbname = os.environ.get("THIRD_PARTY_DB_NAME", "")
    third_party_user = os.environ.get("THIRD_PARTY_DB_USER", "")
    third_party_password = os.environ.get("THIRD_PARTY_DB_PASSWORD", "")

    app.config["THIRD_PARTY_DSN"] = (
        f"host={third_party_host} "
        f"dbname={third_party_dbname} "
        f"user={third_party_user} "
        f"password={third_party_password}"
    )


def frontend_url(path: str) -> str:
    """
    Build a frontend URL using the configured FRONTEND_BASE_URL.

    Examples:
      frontend_url("/login")
      frontend_url("/empresa/minha-empresa")
    """
    base = os.environ.get("FRONTEND_BASE_URL", "")
    if not path.startswith("/"):
        path = "/" + path
    return f"{base}{path}"
