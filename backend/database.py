"""MongoDB connection and index management."""
import logging
from typing import Optional

from motor.motor_asyncio import AsyncIOMotorClient, AsyncIOMotorDatabase

from config import get_settings

logger = logging.getLogger(__name__)

_client: Optional[AsyncIOMotorClient] = None
_db: Optional[AsyncIOMotorDatabase] = None


async def connect_to_database() -> None:
    global _client, _db
    settings = get_settings()
    _client = AsyncIOMotorClient(settings.DATABASE_URL, serverSelectionTimeoutMS=5000)
    await _client.admin.command("ping")
    _db = _client[settings.DATABASE_NAME]
    await _create_indexes(_db)
    logger.info("Connected to MongoDB database '%s'", settings.DATABASE_NAME)


async def close_database_connection() -> None:
    global _client
    if _client is not None:
        _client.close()
        _client = None
        logger.info("Closed MongoDB connection")


async def _create_indexes(db: AsyncIOMotorDatabase) -> None:
    await db.users.create_index("email", unique=True)
    await db.users.create_index("reset_token_hash", sparse=True)
    await db.prediction_history.create_index([("user_id", 1), ("created_at", -1)])
    await db.diseases.create_index("slug", unique=True)
    await db.symptoms.create_index("name", unique=True)
    await db.medical_documents.create_index("doc_id", unique=True)


def get_database() -> AsyncIOMotorDatabase:
    if _db is None:
        raise RuntimeError("Database is not connected.")
    return _db


async def database_is_healthy() -> bool:
    try:
        if _client is None:
            return False
        await _client.admin.command("ping")
        return True
    except Exception:
        return False
