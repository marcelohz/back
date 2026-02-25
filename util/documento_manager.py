# util/documento_manager.py

from db import db
from models.documento import Documento, DocumentoEmpresa, DocumentoVeiculo, DocumentoMotorista, DocumentoViagem
from documento_storage import save_document

# Define mapping for each entity type
LINK_MAP = {
    "empresa": DocumentoEmpresa,
    "veiculo": DocumentoVeiculo,
    "motorista": DocumentoMotorista,
    "viagem": DocumentoViagem,
}

def processar_documentos(entity_type, entity_id, uploaded_files, empresa_cnpj):
    """
    Saves uploaded documents and links them to the given entity.

    Args:
        entity_type (str): One of 'empresa', 'veiculo', 'motorista', or 'viagem'.
        entity_id (str or int): Entity identifier (CNPJ, placa, motorista_id, or viagem_id).
        uploaded_files (dict): e.g. {"CRLV": file_obj, "CONTRATO_SOCIAL": file_obj}
        empresa_cnpj (str): Used to determine storage location.

    Returns:
        list of Documento: The documents processed/created.
    """
    if entity_type not in LINK_MAP:
        raise ValueError(f"Unsupported entity_type '{entity_type}'")

    link_model = LINK_MAP[entity_type]
    created_docs = []

    for tipo_nome, file in uploaded_files.items():
        if not file:
            continue

        # Save file to storage

        meta = save_document(
            file=file,
            entity_type=entity_type,
            entity_id=entity_id,
            empresa_cnpj=empresa_cnpj,
            tipo_nome=tipo_nome
        )

        # Create Documento
        doc = Documento(
            documento_tipo_nome=tipo_nome,
            caminho=meta["caminho"],
            tamanho=meta["tamanho"],
            hash=meta["hash"],
            data_upload=meta["data_upload"],
        )
        db.session.add(doc)
        db.session.flush()

        # Link document to entity
        # link = link_model(id=doc.id, **{f"{entity_type}_cnpj" if entity_type == "empresa" else f"{entity_type}_placa": entity_id})
        if entity_type == "empresa":
            link_field = "empresa_cnpj"
        elif entity_type == "veiculo":
            link_field = "veiculo_placa"
        elif entity_type == "motorista":
            link_field = "motorista_id"
        elif entity_type == "viagem":
            link_field = "viagem_id"
        else:
            raise ValueError(f"Unsupported entity_type '{entity_type}'")

        link = link_model(id=doc.id, **{link_field: entity_id})
        db.session.add(link)

        created_docs.append(doc)

    return created_docs
