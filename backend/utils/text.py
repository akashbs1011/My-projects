"""Text helpers with no third-party dependencies, so the ML layer stays
independent of the database driver."""
import re
import unicodedata


def slugify(value: str) -> str:
    value = unicodedata.normalize("NFKD", str(value)).encode("ascii", "ignore").decode()
    value = re.sub(r"[^\w\s-]", "", value).strip().lower()
    return re.sub(r"[-\s]+", "-", value) or "unknown"
