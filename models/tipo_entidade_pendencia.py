from sqlalchemy import func
from db import db

class TipoEntidadePendencia(db.Model):
    __tablename__ = "tipo_entidade_pendencia"
    __table_args__ = {"schema": "eventual"}  # matches your table's schema

    # Primary key
    tipo = db.Column(db.Text, primary_key=True)

    # Description of the entity type
    descricao = db.Column(db.Text, nullable=False)

    def to_dict(self):
        return {c.name: getattr(self, c.name) for c in self.__table__.columns}

    def __repr__(self):
        return f"<TipoEntidadePendencia {self.tipo}>"
