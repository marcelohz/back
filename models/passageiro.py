from db import db
from sqlalchemy import ForeignKey


class Passageiro(db.Model):
    __tablename__ = "passageiro"
    __table_args__ = (
        db.UniqueConstraint("viagem_id", "cpf", name="passageiro_unique_viagem_cpf"),
        {"schema": "eventual"},
    )

    id = db.Column(db.Integer, primary_key=True)
    viagem_id = db.Column(db.Integer, db.ForeignKey("eventual.viagem.id", ondelete="CASCADE"), nullable=False)
    nome = db.Column(db.Text, nullable=False)
    cpf = db.Column(db.Text, nullable=False)

    # --- Relationships ---
    viagem = db.relationship(
        "Viagem",
        backref=db.backref("passageiros", cascade="all, delete-orphan", lazy="dynamic")
    )

    def __repr__(self):
        return f"<Passageiro(id={self.id}, nome={self.nome}, cpf={self.cpf}, viagem_id={self.viagem_id})>"
