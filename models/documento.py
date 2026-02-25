from db import db
from datetime import datetime


# ========================================================
# Master: Documento Tipo
# ========================================================
class DocumentoTipo(db.Model):
    __tablename__ = "documento_tipo"
    __table_args__ = {"schema": "eventual"}

    nome = db.Column(db.Text, primary_key=True)  # e.g. 'ALVARA', 'CNH', etc.
    descricao = db.Column(db.Text)

    # optional helper repr
    def __repr__(self):
        return f"<DocumentoTipo(nome={self.nome})>"


# ========================================================
# Documento base table
# ========================================================
class Documento(db.Model):
    __tablename__ = "documento"
    __table_args__ = {"schema": "eventual"}

    id = db.Column(db.Integer, primary_key=True)
    documento_tipo_nome = db.Column(
        db.Text,
        db.ForeignKey("eventual.documento_tipo.nome"),
        nullable=False
    )
    caminho = db.Column(db.Text, nullable=False)      # relative path on disk
    tamanho = db.Column(db.BigInteger)
    hash = db.Column(db.String(32))                   # MD5 or similar
    data_upload = db.Column(db.DateTime, default=datetime.utcnow)

    tipo = db.relationship("DocumentoTipo", backref="documentos")

    aprovado_em = db.Column(db.DateTime, nullable=True)

    def __repr__(self):
        return f"<Documento(id={self.id}, tipo={self.documento_tipo_nome})>"


# ========================================================
# Link: Documento → Empresa
# ========================================================
class DocumentoEmpresa(db.Model):
    __tablename__ = "documento_empresa"
    __table_args__ = {"schema": "eventual"}

    id = db.Column(
        db.Integer,
        db.ForeignKey("eventual.documento.id", ondelete="CASCADE"),
        primary_key=True
    )
    empresa_cnpj = db.Column(
        db.Text,
        db.ForeignKey("geral.empresa.cnpj"),
        nullable=False
    )

    documento = db.relationship("Documento", backref=db.backref("empresa_link", uselist=False))

    def __repr__(self):
        return f"<DocumentoEmpresa(id={self.id}, empresa_cnpj={self.empresa_cnpj})>"


# ========================================================
# Link: Documento → Usuario
# ========================================================
class DocumentoUsuario(db.Model):
    __tablename__ = "documento_usuario"
    __table_args__ = {"schema": "eventual"}

    id = db.Column(
        db.Integer,
        db.ForeignKey("eventual.documento.id", ondelete="CASCADE"),
        primary_key=True
    )
    usuario_id = db.Column(
        db.Integer,
        db.ForeignKey("web.usuario.id"),
        nullable=False
    )

    documento = db.relationship("Documento", backref=db.backref("usuario_link", uselist=False))

    def __repr__(self):
        return f"<DocumentoUsuario(id={self.id}, usuario_id={self.usuario_id})>"


# ========================================================
# Link: Documento → Veiculo
# ========================================================
class DocumentoVeiculo(db.Model):
    __tablename__ = "documento_veiculo"
    __table_args__ = {"schema": "eventual"}

    id = db.Column(
        db.Integer,
        db.ForeignKey("eventual.documento.id", ondelete="CASCADE"),
        primary_key=True
    )
    veiculo_placa = db.Column(
        db.Text,
        db.ForeignKey("geral.veiculo.placa"),
        nullable=False
    )

    documento = db.relationship("Documento", backref=db.backref("veiculo_link", uselist=False))

    def __repr__(self):
        return f"<DocumentoVeiculo(id={self.id}, veiculo_placa={self.veiculo_placa})>"


# ========================================================
# Link: Documento → Motorista
# ========================================================
class DocumentoMotorista(db.Model):
    __tablename__ = "documento_motorista"
    __table_args__ = {"schema": "eventual"}

    id = db.Column(
        db.Integer,
        db.ForeignKey("eventual.documento.id", ondelete="CASCADE"),
        primary_key=True
    )
    motorista_id = db.Column(
        db.Integer,
        db.ForeignKey("eventual.motorista.id"),
        nullable=False
    )

    documento = db.relationship(
        "Documento",
        backref=db.backref("motorista_link", uselist=False)
    )
    # motorista = db.relationship(
    #     "Motorista",
    #     backref=db.backref("documentos", cascade="all, delete-orphan")
    # )

    def __repr__(self):
        return f"<DocumentoMotorista(id={self.id}, motorista_id={self.motorista_id})>"


# ========================================================
# Link: Documento → Viagem
# ========================================================
class DocumentoViagem(db.Model):
    __tablename__ = "documento_viagem"
    __table_args__ = {"schema": "eventual"}

    id = db.Column(
        db.Integer,
        db.ForeignKey("eventual.documento.id", ondelete="CASCADE"),
        primary_key=True
    )
    viagem_id = db.Column(
        db.Integer,
        db.ForeignKey("eventual.viagem.id"),
        nullable=False
    )

    documento = db.relationship(
        "Documento",
        backref=db.backref("viagem_link", uselist=False)
    )

    def __repr__(self):
        return f"<DocumentoViagem(id={self.id}, viagem_id={self.viagem_id})>"


# ========================================================
# Optional: allowed document types per entity
# ========================================================
class DocumentoTipoPermissao(db.Model):
    __tablename__ = "documento_tipo_permissao"
    __table_args__ = {"schema": "eventual"}

    tipo_nome = db.Column(
        db.Text,
        db.ForeignKey("eventual.documento_tipo.nome"),
        primary_key=True
    )
    entidade_tipo = db.Column(
        db.Text,
        primary_key=True
    )

    def __repr__(self):
        return f"<DocumentoTipoPermissao(tipo_nome={self.tipo_nome}, entidade_tipo={self.entidade_tipo})>"
