from db import db
from datetime import datetime

class Motorista(db.Model):
    __tablename__ = "motorista"
    __table_args__ = {"schema": "eventual"}

    id = db.Column(db.Integer, primary_key=True)
    empresa_cnpj = db.Column(
        db.Text,
        db.ForeignKey("geral.empresa.cnpj"),
        nullable=False
    )
    cpf = db.Column(db.Text, nullable=False)
    cnh = db.Column(db.Text, nullable=False)
    email = db.Column(db.Text)
    nome = db.Column(db.Text)
    data_cadastro = db.Column(db.DateTime, default=datetime.utcnow)

    # --- Relationships ---
    empresa = db.relationship(
        "Empresa",
        backref=db.backref("motoristas", lazy="dynamic")
    )

    def __repr__(self):
        return (
            f"<Motorista(id={self.id}, nome={self.nome}, "
            f"cpf={self.cpf}, empresa_cnpj={self.empresa_cnpj})>"
        )
