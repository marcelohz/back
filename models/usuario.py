from db import db
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship

class Papel(db.Model):
    __tablename__ = "papel"
    __table_args__ = {"schema": "web"}

    nome = db.Column(db.Text, primary_key=True)

    def __repr__(self):
        return f"<Papel {self.nome}>"


class Usuario(db.Model):
    __tablename__ = "usuario"
    __table_args__ = {"schema": "web"}

    id = db.Column(db.Integer, primary_key=True)
    papel_nome = db.Column(db.Text, db.ForeignKey("web.papel.nome"), nullable=False)

    email = db.Column(db.Text, unique=True, nullable=False)       # login/username
    nome = db.Column(db.Text, nullable=False)
    cpf = db.Column(db.Text, unique=True)
    data_nascimento = db.Column(db.Date)
    telefone = db.Column(db.Text)
    senha = db.Column(db.Text, nullable=True)
    empresa_cnpj = db.Column(db.Text, db.ForeignKey("geral.empresa.cnpj"))
    criado_em = db.Column(db.DateTime(), server_default=func.now())
    atualizado_em = db.Column(db.DateTime(), server_default=func.now(), onupdate=func.now())
    ativo = db.Column(db.Boolean, nullable=False, default=True)
    email_validado = db.Column(db.Boolean, nullable=False, default=False)

    # Relationships
    empresa = relationship(
        "Empresa",
        back_populates="usuarios"
    )
    papel = relationship("Papel", backref=db.backref("usuarios", lazy=True))

    def __repr__(self):
        return f"<Usuario {self.email}>"
