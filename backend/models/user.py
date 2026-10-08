"""User document shape and data-access helpers."""
from __future__ import annotations

from datetime import datetime
from typing import Any, Dict, Optional

from bson import ObjectId
from motor.motor_asyncio import AsyncIOMotorDatabase

from utils.helpers import utcnow

COLLECTION = "users"


def new_user_document(
    name: str, email: str, password_hash: str, preferred_language: str = "en"
) -> Dict[str, Any]:
    now = utcnow()
    return {
        "name": name.strip(),
        "email": email.strip().lower(),
        "password_hash": password_hash,     # bcrypt hash - never the plain password
        "preferred_language": preferred_language,
        "created_at": now,
        "updated_at": now,
    }


async def get_by_email(db: AsyncIOMotorDatabase, email: str) -> Optional[Dict[str, Any]]:
    return await db[COLLECTION].find_one({"email": email.strip().lower()})


async def get_by_id(db: AsyncIOMotorDatabase, user_id: str) -> Optional[Dict[str, Any]]:
    if not ObjectId.is_valid(user_id):
        return None
    return await db[COLLECTION].find_one({"_id": ObjectId(user_id)})


async def create(db: AsyncIOMotorDatabase, document: Dict[str, Any]) -> Dict[str, Any]:
    result = await db[COLLECTION].insert_one(document)
    document["_id"] = result.inserted_id
    return document


async def update(db: AsyncIOMotorDatabase, user_id: str, changes: Dict[str, Any]) -> Optional[Dict]:
    changes["updated_at"] = utcnow()
    return await db[COLLECTION].find_one_and_update(
        {"_id": ObjectId(user_id)}, {"$set": changes}, return_document=True
    )


async def set_reset_token(
    db: AsyncIOMotorDatabase, user_id: ObjectId, token_hash: str, expires: datetime
) -> None:
    await db[COLLECTION].update_one(
        {"_id": user_id},
        {"$set": {"reset_token_hash": token_hash, "reset_token_expires": expires}},
    )


async def clear_reset_token(db: AsyncIOMotorDatabase, user_id: ObjectId) -> None:
    await db[COLLECTION].update_one(
        {"_id": user_id}, {"$unset": {"reset_token_hash": "", "reset_token_expires": ""}}
    )
