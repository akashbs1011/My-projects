"""Prediction history document shape and data-access helpers."""
from __future__ import annotations

from typing import Any, Dict, List, Optional

from bson import ObjectId
from motor.motor_asyncio import AsyncIOMotorDatabase

from utils.helpers import utcnow

COLLECTION = "prediction_history"


def new_history_document(
    user_id: str,
    symptoms: List[str],
    predictions: List[Dict[str, Any]],
    selected_language: str,
) -> Dict[str, Any]:
    top = predictions[0] if predictions else None
    return {
        "user_id": ObjectId(user_id),
        "symptoms": symptoms,
        "predictions": predictions,
        "top_prediction": (
            {
                "disease": top["disease"],
                "slug": top.get("slug"),
                "model_confidence": top["model_confidence"],
                "symptom_match": top["symptom_match"],
            }
            if top
            else None
        ),
        "selected_language": selected_language,
        "created_at": utcnow(),
    }


async def create(db: AsyncIOMotorDatabase, document: Dict[str, Any]) -> Dict[str, Any]:
    result = await db[COLLECTION].insert_one(document)
    document["_id"] = result.inserted_id
    return document


async def list_for_user(
    db: AsyncIOMotorDatabase, user_id: str, limit: int = 50, skip: int = 0
) -> List[Dict[str, Any]]:
    cursor = (
        db[COLLECTION]
        .find({"user_id": ObjectId(user_id)})
        .sort("created_at", -1)
        .skip(skip)
        .limit(limit)
    )
    return await cursor.to_list(length=limit)


async def count_for_user(db: AsyncIOMotorDatabase, user_id: str) -> int:
    return await db[COLLECTION].count_documents({"user_id": ObjectId(user_id)})


async def get_owned(
    db: AsyncIOMotorDatabase, item_id: str, user_id: str
) -> Optional[Dict[str, Any]]:
    if not ObjectId.is_valid(item_id):
        return None
    return await db[COLLECTION].find_one(
        {"_id": ObjectId(item_id), "user_id": ObjectId(user_id)}
    )


async def delete_owned(db: AsyncIOMotorDatabase, item_id: str, user_id: str) -> bool:
    if not ObjectId.is_valid(item_id):
        return False
    result = await db[COLLECTION].delete_one(
        {"_id": ObjectId(item_id), "user_id": ObjectId(user_id)}
    )
    return result.deleted_count > 0


async def clear_for_user(db: AsyncIOMotorDatabase, user_id: str) -> int:
    result = await db[COLLECTION].delete_many({"user_id": ObjectId(user_id)})
    return result.deleted_count
