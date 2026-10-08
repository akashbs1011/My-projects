"""
Disease information endpoints.

Every field is either read from a supplementary dataset file or reported as
unavailable. Nothing about a disease is written by the application.
"""
import logging
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from motor.motor_asyncio import AsyncIOMotorDatabase

from routes.deps import db_dependency
from services.prediction_engine import SUPPORT_THRESHOLD, get_engine
from services.safety import GENERAL_DISCLAIMER, NOT_IN_KNOWLEDGE_BASE
from services.translation_service import from_english
from utils.helpers import serialize

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/diseases", tags=["diseases"])


@router.get("")
async def list_diseases(
    q: Optional[str] = Query(None),
    limit: int = Query(100, ge=1, le=500),
    db: AsyncIOMotorDatabase = Depends(db_dependency),
):
    query = {"name": {"$regex": q, "$options": "i"}} if q else {}
    cursor = db.diseases.find(query).sort("name", 1).limit(limit)
    items = await cursor.to_list(length=limit)

    if not items:
        engine = get_engine()
        if engine.is_ready:
            names = engine.bundle.disease_names
            filtered = [n for n in names if not q or q.lower() in n.lower()]
            from utils.helpers import slugify

            return {
                "count": len(filtered[:limit]),
                "source": "prediction dataset",
                "items": [
                    {"name": n, "slug": slugify(n), "details_available": False}
                    for n in filtered[:limit]
                ],
            }
    return {"count": len(items), "source": "database", "items": [serialize(i) for i in items]}


@router.get("/{slug}")
async def get_disease(
    slug: str,
    language: str = Query("en"),
    db: AsyncIOMotorDatabase = Depends(db_dependency),
):
    record = await db.diseases.find_one({"slug": slug})
    engine = get_engine()

    name = record["name"] if record else None
    if name is None and engine.is_ready:
        from utils.helpers import slugify

        name = next((d for d in engine.bundle.disease_names if slugify(d) == slug), None)

    if name is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="That condition wasn't found."
        )

    # Symptoms recorded for this condition in the prediction dataset.
    common_symptoms = []
    if engine.is_ready:
        supports = engine.bundle.disease_symptom_map.get(name, {})
        common_symptoms = [
            {"name": s, "support": v}
            for s, v in sorted(supports.items(), key=lambda kv: kv[1], reverse=True)
            if v >= SUPPORT_THRESHOLD
        ]

    payload = {
        "name": name,
        "slug": slug,
        "overview": (record or {}).get("overview") or NOT_IN_KNOWLEDGE_BASE,
        "precautions": (record or {}).get("precautions") or [],
        "severity": (record or {}).get("severity"),
        "common_symptoms": common_symptoms,
        "symptom_source": "Kaggle symptom-disease dataset (Training.csv)",
        "when_to_seek_care": (
            "Contact a qualified healthcare professional if symptoms are severe, "
            "worsening, or persistent, or if you are unsure. Seek emergency care "
            "immediately for chest pain, difficulty breathing, confusion, or "
            "uncontrolled bleeding."
        ),
        "disclaimer": GENERAL_DISCLAIMER,
        "notes": [],
    }

    if not (record or {}).get("overview"):
        payload["notes"].append(
            "No overview is present in the supplementary dataset files for this condition."
        )
    if not payload["precautions"]:
        payload["precautions_message"] = NOT_IN_KNOWLEDGE_BASE


    if language != "en":
        payload["name_translated"] = from_english(name, language).text
        if payload["overview"] != NOT_IN_KNOWLEDGE_BASE:
            payload["overview_translated"] = from_english(payload["overview"], language).text
        payload["when_to_seek_care_translated"] = from_english(
            payload["when_to_seek_care"], language
        ).text

    return payload
