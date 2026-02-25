from sqlalchemy import func
from db import db
from sqlalchemy.orm import relationship  # import for explicit relationship

class Empresa(db.Model):
    __tablename__ = "empresa"
    __table_args__ = {"schema": "geral"}  # existing schema

    # Primary key
    cnpj = db.Column(db.Text, primary_key=True)

    nome = db.Column(db.Text, nullable=False)
    telefone = db.Column(db.Text)
    email = db.Column(db.Text)
    endereco = db.Column(db.Text)
    cep = db.Column(db.Text)
    nome_fantasia = db.Column(db.Text)
    endereco_numero = db.Column(db.Text)
    endereco_complemento = db.Column(db.Text)
    bairro = db.Column(db.Text)
    cidade = db.Column(db.Text)
    estado = db.Column(db.Text)
    data_inclusao_eventual = db.Column(db.Date, server_default=func.current_date())

    # Relationship to Usuario
    usuarios = relationship(
        "Usuario",
        back_populates="empresa",
        lazy="dynamic"  # optional: allows filtering directly in the query
    )

    def to_dict(self):
        return {c.name: getattr(self, c.name) for c in self.__table__.columns}

    def __repr__(self):
        return f"<Empresa {self.nome}>"
