from db import db

class PendenciaAtual(db.Model):
    __tablename__ = "v_pendencia_atual"
    __table_args__ = {"schema": "eventual"}

    id = db.Column(db.Integer, primary_key=True)
    entidade_tipo = db.Column(db.Text)
    entidade_id = db.Column(db.Text)
    status = db.Column(db.Text)
    analista = db.Column(db.Text)
    criado_em = db.Column(db.DateTime)
    motivo = db.Column(db.Text)

    def to_dict(self):
        return {c.name: getattr(self, c.name) for c in self.__table__.columns}
