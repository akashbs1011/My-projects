"""Symptom analysis and prediction history."""
import logging
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from motor.motor_asyncio import AsyncIOMotorDatabase

from models import prediction_history as history_model
from routes.deps import current_user, db_dependency
from schemas.prediction import AnalyzeRequest, SymptomExtractRequest
from services.medical_entity_service import extract_symptoms
from services.prediction_engine import get_engine
from services.safety import GENERAL_DISCLAIMER, check_urgency
from services.translation_service import from_english
from utils.helpers import serialize

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/predictions", tags=["predictions"])


@router.post("/analyze")
async def analyze(
    payload: AnalyzeRequest,
    user: dict = Depends(current_user),
    db: AsyncIOMotorDatabase = Depends(db_dependency),
):
    engine = get_engine()
    if not engine.is_ready:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="The prediction model isn't loaded. Run `python train_model.py` on the server.",
        )

    try:
        outcome = engine.predict(payload.symptoms)
    except Exception:
        logger.exception("Prediction failed for symptoms=%s", payload.symptoms)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="The analysis couldn't be completed. Try again.",
        )

    urgency = check_urgency(outcome["recognised_symptoms"])
    results = outcome["results"]
    language = payload.language
    translation_note: Optional[str] = None

    if language != "en":
        for item in results:
            name = from_english(item["disease"], language)
            explanation = from_english(item["explanation"], language)
            item["disease_translated"] = name.text
            item["explanation_translated"] = explanation.text
            translation_note = translation_note or name.note
        if urgency["notice"]:
            urgency["notice_translated"] = from_english(urgency["notice"], language).text

    history_id = None
    if payload.save_to_history and results:
        try:
            document = history_model.new_history_document(
                user_id=str(user["_id"]),
                symptoms=outcome["recognised_symptoms"],
                predictions=results,
                selected_language=language,
            )
            saved = await history_model.create(db, document)
            history_id = str(saved["_id"])
        except Exception:
            logger.exception("Could not save prediction to history")

    return {
        "results": results,
        "recognised_symptoms": outcome["recognised_symptoms"],
        "unrecognised_symptoms": outcome["unrecognised_symptoms"],
        "urgency": urgency,
        "disclaimer": GENERAL_DISCLAIMER,
        "language": language,
        "message": outcome["message"],
        "history_id": history_id,
        "translation_note": translation_note,
    }


@router.post("/extract-symptoms")
async def extract(payload: SymptomExtractRequest, user: dict = Depends(current_user)):
    """Turn dictated or typed free text into canonical symptoms."""
    engine = get_engine()
    if not engine.is_ready:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="The prediction model isn't loaded.",
        )
    return extract_symptoms(payload.text, engine.symptom_vocabulary(), engine.alias_map)


@router.get("/history")
async def list_history(
    limit: int = Query(20, ge=1, le=100),
    skip: int = Query(0, ge=0),
    user: dict = Depends(current_user),
    db: AsyncIOMotorDatabase = Depends(db_dependency),
):
    items = await history_model.list_for_user(db, str(user["_id"]), limit=limit, skip=skip)
    total = await history_model.count_for_user(db, str(user["_id"]))
    return {"total": total, "limit": limit, "skip": skip, "items": [serialize(i) for i in items]}


@router.get("/history/{item_id}")
async def get_history_item(
    item_id: str,
    user: dict = Depends(current_user),
    db: AsyncIOMotorDatabase = Depends(db_dependency),
):
    item = await history_model.get_owned(db, item_id, str(user["_id"]))
    if item is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="That saved analysis wasn't found."
        )
    return serialize(item)


@router.delete("/history/{item_id}")
async def delete_history_item(
    item_id: str,
    user: dict = Depends(current_user),
    db: AsyncIOMotorDatabase = Depends(db_dependency),
):
    if not await history_model.delete_owned(db, item_id, str(user["_id"])):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="That saved analysis wasn't found."
        )
    return {"message": "Analysis deleted."}


@router.delete("/history")
async def clear_history(
    user: dict = Depends(current_user), db: AsyncIOMotorDatabase = Depends(db_dependency)
):
    deleted = await history_model.clear_for_user(db, str(user["_id"]))
    return {"message": f"Cleared {deleted} saved {'analysis' if deleted == 1 else 'analyses'}."}
