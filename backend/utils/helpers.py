"""Small shared helpers."""
from datetime import datetime, timezone
from typing import Any, Dict

from bson import ObjectId

from utils.text import slugify


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


# Re-exported so callers have one import site; defined in utils.text, which has
# no third-party imports.
__all__ = ["utcnow", "slugify", "serialize", "is_valid_object_id"]


def serialize(doc: Dict[str, Any] | None) -> Dict[str, Any] | None:
    """Convert Mongo document to a JSON-safe dict (ObjectId -> str, drop secrets)."""
    if doc is None:
        return None
    out: Dict[str, Any] = {}
    for key, value in doc.items():
        if key in {"password_hash", "reset_token_hash", "reset_token_expires"}:
            continue
        if key == "_id":
            out["id"] = str(value)
        elif isinstance(value, ObjectId):
            out[key] = str(value)
        elif isinstance(value, datetime):
            out[key] = value.isoformat()
        elif isinstance(value, list):
            out[key] = [serialize(v) if isinstance(v, dict) else v for v in value]
        elif isinstance(value, dict):
            out[key] = serialize(value)
        else:
            out[key] = value
    return out


def is_valid_object_id(value: str) -> bool:
    return ObjectId.is_valid(value)
