from db import db
from datetime import datetime
from sqlalchemy import ForeignKey


class Viagem(db.Model):
    __tablename__ = "viagem"
    __table_args__ = {"schema": "eventual"}

    id = db.Column(db.Integer, primary_key=True)
    nome_contratante = db.Column(db.Text, nullable=False)
    cpf_cnpj_contratante = db.Column(db.Text, nullable=False)
    regiao = db.Column(db.Text, db.ForeignKey("geral.regiao.nome"), nullable=False)
    municipio_origem = db.Column(db.Text, db.ForeignKey("geral.municipio.nome"), nullable=False)
    municipio_destino = db.Column(db.Text, db.ForeignKey("geral.municipio.nome"), nullable=False)
    ida_em = db.Column(db.DateTime, nullable=False)
    volta_em = db.Column(db.DateTime, nullable=False)
    viagem_tipo = db.Column(db.Text, db.ForeignKey("eventual.viagem_tipo.nome"), nullable=False)
    veiculo_placa = db.Column(db.Text, db.ForeignKey("geral.veiculo.placa"), nullable=False)
    motorista_id = db.Column(db.Integer, db.ForeignKey("eventual.motorista.id"), nullable=False)
    motorista_aux_id = db.Column(db.Integer, db.ForeignKey("eventual.motorista.id"))
    descricao = db.Column(db.Text)

    # --- Relationships ---
    veiculo = db.relationship("Veiculo", backref=db.backref("viagens", lazy="dynamic"))
    motorista = db.relationship("Motorista", foreign_keys=[motorista_id], backref=db.backref("viagens", lazy="dynamic"))
    motorista_aux = db.relationship("Motorista", foreign_keys=[motorista_aux_id], backref=db.backref("viagens_aux", lazy="dynamic"))

    # optional: you can add relationships to regiao/municipio/viagem_tipo later if you have their models

    def __repr__(self):
        return f"<Viagem(id={self.id}, regiao={self.regiao}, origem={self.municipio_origem}, destino={self.municipio_destino})>"
