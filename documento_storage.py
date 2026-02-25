import os
import hashlib
from datetime import datetime
from werkzeug.datastructures import FileStorage

# Base directory for all document storage
BASE_DIR = os.path.join(os.path.dirname(__file__), "documentos")
os.makedirs(BASE_DIR, exist_ok=True)

# Subfolders for each entity type
SUBFOLDERS = {
    "empresa": "empresa",
    "veiculo": "veiculo",
    "usuario": "usuario",
    "motorista": "motorista",
}


def _ensure_subfolder(entity_type: str):
    """Ensure subfolder exists for the given entity type."""
    if entity_type not in SUBFOLDERS:
        raise ValueError(f"Invalid entity type: {entity_type}")
    subdir = os.path.join(BASE_DIR, SUBFOLDERS[entity_type])
    os.makedirs(subdir, exist_ok=True)
    return subdir


def _compute_md5(file_path: str) -> str:
    """Compute MD5 hash of a file."""
    md5 = hashlib.md5()
    with open(file_path, "rb") as f:
        for chunk in iter(lambda: f.read(4096), b""):
            md5.update(chunk)
    return md5.hexdigest()


def save_document(
        file: FileStorage,
        entity_type: str,
        entity_id: str,
        empresa_cnpj: str,
        tipo_nome: str
) -> dict:
    """
    Save an uploaded document to disk.

    :param file: Flask FileStorage object
    :param entity_type: 'empresa', 'veiculo', or 'usuario'
    :param entity_id: primary identifier (CNPJ, placa, or user id)
    :param empresa_cnpj: owning empresa's CNPJ
    :param tipo_nome: document type (e.g. 'CNH', 'CONTRATO_SOCIAL')
    :return: dict with path, size, hash
    """
    subdir = _ensure_subfolder(entity_type)

    # Compose file name: entityId_empresaCNPJ_tipo.ext
    ext = os.path.splitext(file.filename)[1]
    filename = f"{empresa_cnpj}_{entity_id}_{tipo_nome.upper()}{ext}"
    file_path = os.path.join(subdir, filename)

    # Save file
    file.save(file_path)

    # Collect metadata
    file_size = os.path.getsize(file_path)
    file_hash = _compute_md5(file_path)
    rel_path = os.path.relpath(file_path, BASE_DIR)

    return {
        "caminho": rel_path.replace("\\", "/"),
        "tamanho": file_size,
        "hash": file_hash,
        "data_upload": datetime.now(),
    }


def delete_document(caminho: str):
    """Delete document from disk given its relative path."""
    file_path = os.path.join(BASE_DIR, caminho)
    if os.path.exists(file_path):
        os.remove(file_path)


def get_absolute_path(caminho: str) -> str:
    """Convert relative DB path to absolute filesystem path."""
    return os.path.join(BASE_DIR, caminho)
