def empty_to_none(data):
    """
    Recursively replace all empty strings ('') in a dict (or nested structures)
    with None.
    """
    if isinstance(data, dict):
        return {k: empty_to_none(v) for k, v in data.items()}
    elif isinstance(data, list):
        return [empty_to_none(v) for v in data]
    elif isinstance(data, str) and data.strip() == "":
        return None
    else:
        return data
