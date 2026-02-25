from sqlalchemy import func, ForeignKey
from db import db


class Veiculo(db.Model):
    __tablename__ = "veiculo"
    __table_args__ = {"schema": "geral"}

    placa = db.Column(db.Text, primary_key=True, nullable=False)
    chassi_numero = db.Column(db.Text)
    renavan = db.Column(db.Text)
    modelo = db.Column(db.Text)
    fretamento_veiculo_tipo_nome = db.Column(db.Text)
    potencia_motor = db.Column(db.Integer)
    cor_principal_nome = db.Column(db.Text)
    numero_lugares = db.Column(db.Integer)
    empresa_cnpj = db.Column(db.Text, ForeignKey("geral.empresa.cnpj"))  # <-- foreign key
    ano_fabricacao = db.Column(db.Integer)
    modelo_ano = db.Column(db.Integer)
    veiculo_combustivel_nome = db.Column(db.Text)
    data_inclusao_eventual = db.Column(db.Date, server_default=func.current_date())

    # Optional: relationship if you want SQLAlchemy object linking
    empresa = db.relationship("Empresa", backref="veiculos", lazy=True)

    def __repr__(self):
        return f"<Veiculo {self.placa}>"
