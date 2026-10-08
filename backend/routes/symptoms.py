"""Symptom vocabulary endpoints. The list comes from the processed dataset."""
from typing import Optional

from fastapi import APIRouter, HTTPException, Query, status

from services.prediction_engine import get_engine
from services.translation_service import LANGUAGE_NAMES, from_english, to_roman

router = APIRouter(prefix="/symptoms", tags=["symptoms"])


def _require_engine():
    engine = get_engine()
    if not engine.is_ready:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="The prediction model isn't loaded. Run `python train_model.py` on the server.",
        )
    return engine


def _display(name: str) -> str:
    return name[:1].upper() + name[1:] if name else name


@router.get("")
async def list_symptoms(language: str = Query("en"), romanise: bool = Query(False)):
    engine = _require_engine()
    vocabulary = engine.symptom_vocabulary()

    items = []
    for name in vocabulary:
        entry = {"id": name, "name": name, "label": _display(name)}
        if language != "en" and language in LANGUAGE_NAMES:
            translated = from_english(_display(name), language)
            entry["label"] = translated.text
            entry["translated"] = translated.translated
            if romanise and translated.translated:
                entry["roman"] = to_roman(translated.text, language)
        items.append(entry)

    return {"count": len(items), "language": language, "symptoms": items}


@router.get("/search")
async def search_symptoms(
    q: str = Query(min_length=1, max_length=100),
    limit: int = Query(20, ge=1, le=100),
    language: Optional[str] = Query("en"),
):
    engine = _require_engine()
    vocabulary = engine.symptom_vocabulary()
    needle = q.strip().lower().replace("_", " ")

    starts = [s for s in vocabulary if s.startswith(needle)]
    contains = [s for s in vocabulary if needle in s and s not in starts]
    ranked = starts + contains

    if len(ranked) < limit:
        try:
            from rapidfuzz import fuzz, process

            fuzzy = process.extract(
                needle, vocabulary, scorer=fuzz.partial_ratio, limit=limit
            )
            for name, score, _ in fuzzy:
                if score >= 75 and name not in ranked:
                    ranked.append(name)
        except ImportError:
            pass

    results = []
    for name in ranked[:limit]:
        entry = {"id": name, "name": name, "label": _display(name)}
        if language and language != "en":
            translated = from_english(_display(name), language)
            entry["label"] = translated.text
        results.append(entry)

    return {"query": q, "count": len(results), "symptoms": results}


@router.get("/suggest")
async def suggest_symptoms(
    selected: str = Query(
        min_length=1,
        max_length=400,
        description="Comma-separated canonical symptom names already chosen.",
    ),
    limit: int = Query(6, ge=1, le=12),
    language: Optional[str] = Query("en"),
    romanise: bool = Query(False),
):
    """
    Symptoms that commonly occur alongside those already selected.

    Intended to help a person reach a usable number of symptoms when they are
    unsure what else to report. The response is a co-occurrence statistic drawn
    from the training data, not a clinical suggestion, and the interface labels
    it as such.
    """
    engine = _require_engine()

    chosen = [s.strip().lower().replace("_", " ") for s in selected.split(",")]
    chosen = [s for s in chosen if s]
    if not chosen:
        return {"suggestions": [], "language": language}

    # Only known symptoms contribute; unknown text is ignored rather than
    # causing an error, since this endpoint is advisory.
    recognised, _ = engine.resolve_symptoms(chosen)
    names = engine.suggest_symptoms(recognised, limit=limit)

    suggestions = []
    for name in names:
        label = _display(name)
        roman = None
        if language and language != "en" and language in LANGUAGE_NAMES:
            # from_english returns a TranslationResult, not a string; the other
            # endpoints in this module unwrap .text and this must match, or the
            # client receives an object where it expects a label.
            translated = from_english(label, language)
            label = translated.text
            if romanise and translated.translated:
                roman = to_roman(label, language)
        entry = {"name": name, "label": label}
        if roman:
            entry["roman"] = roman
        suggestions.append(entry)

    return {
        "suggestions": suggestions,
        "based_on": recognised,
        "language": language,
        "note": (
            "Symptoms frequently recorded alongside your selection in the "
            "prediction dataset. This is not a clinical suggestion."
        ),
    }
