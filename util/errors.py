class PendenciaExistenteError(Exception):
    """Raised when trying to create a new pendência but one is already open."""
    def __init__(self, message, entity_type, entity_id):
        super().__init__(message)
        self.entity_type = entity_type
        self.entity_id = entity_id
        self.message = message
