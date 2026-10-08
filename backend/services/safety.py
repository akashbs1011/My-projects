"""
Safety layer: urgency flagging and the disclaimers attached to every response.

The red-flag list is data, not code, and lives in data/red_flag_symptoms.json
so a clinician can review and amend it without touching application logic.
Matching is done against the canonical symptom vocabulary produced by the
preprocessing step, so a flag can only fire on a symptom the dataset defines.
"""
from __future__ import annotations

import json
import logging
from pathlib import Path
from typing import Dict, List

from services.preprocessing import normalize_symptom

logger = logging.getLogger(__name__)

DATA_PATH = Path(__file__).parent.parent / "data" / "red_flag_symptoms.json"

GENERAL_DISCLAIMER = (
    "This tool provides general information and clinical decision support. "
    "It does not provide a definitive diagnosis."
)

URGENCY_NOTICE = (
    "Some selected symptoms may require prompt medical attention. "
    "Please consult a qualified healthcare professional."
)

NOT_IN_KNOWLEDGE_BASE = "Information is not available in the current knowledge base."

_cache: Dict[str, List[str]] | None = None


def _load() -> Dict[str, List[str]]:
    global _cache
    if _cache is None:
        if DATA_PATH.exists():
            raw = json.loads(DATA_PATH.read_text(encoding="utf-8"))
            _cache = {
                "urgent": [normalize_symptom(s) for s in raw.get("urgent", [])],
                "keywords": [normalize_symptom(s) for s in raw.get("keywords", [])],
            }
        else:
            logger.warning("Red-flag file missing at %s; urgency flagging disabled.", DATA_PATH)
            _cache = {"urgent": [], "keywords": []}
    return _cache


def check_urgency(symptoms: List[str]) -> dict:
    """Return {urgent: bool, triggered: [...], notice: str|None}."""
    data = _load()
    normalised = [normalize_symptom(s) for s in symptoms]
    triggered = [s for s in normalised if s in data["urgent"]]

    for symptom in normalised:
        if symptom in triggered:
            continue
        if any(keyword and keyword in symptom for keyword in data["keywords"]):
            triggered.append(symptom)

    return {
        "urgent": bool(triggered),
        "triggered_symptoms": triggered,
        "notice": URGENCY_NOTICE if triggered else None,
    }
