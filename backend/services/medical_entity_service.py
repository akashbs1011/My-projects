"""
Extracts symptom mentions from free text (typed or dictated).

Matching is restricted to the symptom vocabulary derived from Training.csv
plus the reviewed alias map, so this can only ever return symptoms the model
was actually trained on. Fuzzy matching is bounded by a high similarity
threshold and reported with its score so the interface can ask the user to
confirm rather than assuming.
"""
from __future__ import annotations

import logging
import re
from dataclasses import dataclass
from typing import List, Optional

from services.preprocessing import normalize_symptom
from services.translation_service import to_english

logger = logging.getLogger(__name__)

FUZZY_THRESHOLD = 88          # rapidfuzz score out of 100
MAX_NGRAM = 4                 # longest phrase length considered

_STOPWORDS = {
    "i", "have", "has", "am", "is", "are", "a", "an", "the", "my", "me", "and",
    "with", "of", "feel", "feeling", "some", "got", "been", "having", "also",
    "for", "from", "since", "days", "day", "very", "really", "bit", "lot",
}


@dataclass
class ExtractedSymptom:
    symptom: str            # canonical dataset symptom
    matched_text: str       # the span of user text it came from
    score: float            # 100 = exact match
    exact: bool


def _tokenise(text: str) -> List[str]:
    return [t for t in re.split(r"[^\w]+", text.lower()) if t and t not in _STOPWORDS]


def extract_symptoms(
    text: str,
    vocabulary: List[str],
    alias_map: Optional[dict] = None,
    translate: bool = True,
) -> dict:
    """
    Free text -> canonical symptoms.

    Returns exact matches and suggestions separately; suggestions are meant to
    be confirmed by the user before they are used for a prediction.
    """
    alias_map = alias_map or {}
    source_language = "en"

    if translate:
        text, source_language = to_english(text)

    vocab_set = set(vocabulary)
    lookup = dict(alias_map)
    for symptom in vocabulary:
        lookup[symptom] = symptom

    tokens = _tokenise(text)
    exact: List[ExtractedSymptom] = []
    consumed: set[int] = set()

    # Longest phrase first so "high fever" wins over "fever".
    for size in range(MAX_NGRAM, 0, -1):
        for start in range(len(tokens) - size + 1):
            if any(i in consumed for i in range(start, start + size)):
                continue
            phrase = normalize_symptom(" ".join(tokens[start:start + size]))
            canonical = lookup.get(phrase)
            if canonical and canonical in vocab_set:
                if all(e.symptom != canonical for e in exact):
                    exact.append(ExtractedSymptom(canonical, phrase, 100.0, True))
                consumed.update(range(start, start + size))

    suggestions = _fuzzy_suggestions(tokens, consumed, vocabulary, exact)

    return {
        "source_language": source_language,
        "normalised_text": text,
        "symptoms": [e.symptom for e in exact],
        "matches": [e.__dict__ for e in exact],
        "suggestions": [s.__dict__ for s in suggestions],
    }


def _fuzzy_suggestions(
    tokens: List[str],
    consumed: set[int],
    vocabulary: List[str],
    exact: List[ExtractedSymptom],
) -> List[ExtractedSymptom]:
    try:
        from rapidfuzz import fuzz, process
    except ImportError:
        logger.debug("rapidfuzz not installed; skipping fuzzy suggestions.")
        return []

    found: List[ExtractedSymptom] = []
    already = {e.symptom for e in exact}

    for size in range(min(MAX_NGRAM, len(tokens)), 0, -1):
        for start in range(len(tokens) - size + 1):
            if any(i in consumed for i in range(start, start + size)):
                continue
            phrase = " ".join(tokens[start:start + size])
            if len(phrase) < 4:
                continue
            best = process.extractOne(phrase, vocabulary, scorer=fuzz.token_set_ratio)
            if best and best[1] >= FUZZY_THRESHOLD and best[0] not in already:
                found.append(ExtractedSymptom(best[0], phrase, float(best[1]), False))
                already.add(best[0])
                consumed.update(range(start, start + size))
    return found
