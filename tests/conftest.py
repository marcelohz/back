import os
import pytest
from app import create_app; from db import db
from sqlalchemy.orm import sessionmaker

from models.usuario import Papel

# Use in-memory SQLite for tests
os.environ["DATABASE_URL"] = "sqlite:///:memory:"
os.environ["FLASK_ENV"] = "development"

@pytest.fixture(scope="function")
def app():
    """Create a fresh Flask app for each test with in-memory DB."""
    app = create_app()
    app.config.update({
        "TESTING": True,
        "SQLALCHEMY_ECHO": False,
        "SQLALCHEMY_DATABASE_URI": "sqlite:///:memory:"
    })

    # Remove schemas for SQLite compatibility
    # TODO: no loop mais abaxio estamos tirando as schemas de maneiras mais future-proof, remover isto
    from models.empresa import Empresa
    from models.usuario import Usuario
    from models.veiculo import Veiculo
    Empresa.__table__.schema = None
    Usuario.__table__.schema = None
    Veiculo.__table__.schema = None


    with app.app_context():
        # ✅ Remove schemas for all tables (SQLite can't handle them)
        if db.engine.url.drivername.startswith("sqlite"):
            for table in db.metadata.tables.values():
                table.schema = None
        db.create_all()
        db.session.add_all([
            Papel(nome="ADMIN"),
            Papel(nome="EMPRESA"),
            Papel(nome="USUARIO")
        ])
        yield app
        db.session.remove()
        db.drop_all()

@pytest.fixture
def client(app):
    return app.test_client()

@pytest.fixture
def db_session(app):
    """Provide a SQLAlchemy session bound to the fresh in-memory DB."""
    session_factory = sessionmaker(bind=db.engine)
    session = session_factory()
    yield session
    session.close()

@pytest.fixture
def create_empresa(db_session):
    from models.empresa import Empresa
    def _create(cnpj="11111111000100", nome="Test Ltda", nome_fantasia=None):
        e = Empresa(cnpj=cnpj, nome=nome, nome_fantasia=nome_fantasia or nome)
        db_session.add(e)
        db_session.commit()
        return e
    return _create

@pytest.fixture
def create_usuario(db_session):
    from models.usuario import Usuario
    from werkzeug.security import generate_password_hash
    def _create(email="user@example.com", senha="secret", empresa=None):
        usuario = Usuario(
            email=email,
            nome="Test User",
            senha=generate_password_hash(senha),
            papel_nome="EMPRESA",
            empresa=empresa
        )
        db_session.add(usuario)
        db_session.commit()
        return usuario
    return _create

@pytest.fixture
def create_veiculo():
    from models.veiculo import Veiculo
    def _create(placa="AAA0000", empresa_cnpj=None):
        v = Veiculo(
            placa=placa,
            chassi_numero="CH123456",
            renavan="RN123456",
            modelo="Modelo X",
            fretamento_veiculo_tipo_nome="Van",
            potencia_motor=150,
            cor_principal_nome="Azul",
            numero_lugares=12,
            empresa_cnpj=empresa_cnpj,
            ano_fabricacao=2020,
            modelo_ano=2020
        )
        from db import db
        db.session.add(v)
        db.session.commit()
        return v
    return _create



@pytest.fixture
def login_empresa(client, create_empresa):
    """Log in as an empresa user and return session info."""
    empresa = create_empresa()
    with client.session_transaction() as sess:
        sess["usuario_id"] = 1
        sess["eh_empresa"] = True
        sess["empresa_cnpj"] = empresa.cnpj
    return empresa

@pytest.fixture
def login_usuario(client, create_usuario):
    """Log in as a regular user and return session info."""
    usuario = create_usuario(eh_empresa=False)
    with client.session_transaction() as sess:
        sess["usuario_id"] = usuario.id
        sess["eh_empresa"] = False
    return usuario