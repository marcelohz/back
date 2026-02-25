from db import db
from datetime import datetime

class TokenValidacaoEmail(db.Model):
    __tablename__ = "token_validacao_email"
    __table_args__ = {"schema": "web"}

    id = db.Column(db.Integer, primary_key=True)

    usuario_id = db.Column(
        db.Integer,
        db.ForeignKey("web.usuario.id", ondelete="CASCADE"),
        nullable=False
    )

    token = db.Column(db.Text, unique=True, nullable=False)

    criado_em = db.Column(
        db.DateTime,
        default=datetime.utcnow,
        nullable=False
    )

    expira_em = db.Column(
        db.DateTime,
        nullable=False
    )

    # --- Relationships ---
    usuario = db.relationship(
        "Usuario",
        backref=db.backref("tokens_validacao_email", lazy="dynamic")
    )

    def __repr__(self):
        return f"<TokenValidacaoEmail id={self.id} usuario_id={self.usuario_id}>"
