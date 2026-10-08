"""
Loads the trained model and turns a set of selected symptoms into ranked,
explainable candidate conditions.

Two distinct numbers are reported and they are never conflated:

  model_confidence - the classifier's output probability for that class.
  symptom_match    - the share of symptoms recorded for that condition in the
                     training data that the user actually selected.

Neither is a medically validated probability, and the API surfaces both with
that wording attached.
"""
from __future__ import annotations

import json
import logging
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List, Optional

import joblib
import numpy as np
import pandas as pd

from config import get_settings
from services.preprocessing import apply_aliases, load_alias_map, normalize_symptom
from utils.text import slugify

logger = logging.getLogger(__name__)

# Must match AppConstants.maxSelectedSymptoms in the Flutter client. The score
# is normalised against this, so a mismatch would make the two disagree about
# what a full match means.
MAX_SELECTED_SYMPTOMS = 6

# A symptom is treated as characteristic of a condition when it appears in at
# least this fraction of that condition's training records.
SUPPORT_THRESHOLD = 0.30


@dataclass
class PredictionResult:
    disease: str
    slug: str
    model_confidence: float
    symptom_match: float
    matched_symptoms: List[str]
    unmatched_symptoms: List[str]
    explanation: str
    rank: int


@dataclass
class ModelBundle:
    model: object
    feature_names: List[str]
    disease_names: List[str]
    disease_symptom_map: Dict[str, Dict[str, float]]
    metadata: Dict = field(default_factory=dict)


class PredictionEngine:
    """Holds the loaded artifacts. One instance is created at app startup."""

    def __init__(self) -> None:
        self.bundle: Optional[ModelBundle] = None
        self.alias_map: Dict[str, str] = {}
        self._vocabulary: set[str] = set()

    # ---------------------------------------------------------------- load --
    def load(self) -> bool:
        settings = get_settings()
        path = settings.MODEL_PATH
        if not path.exists():
            logger.error(
                "Trained model not found at %s. Run `python train_model.py` first.", path
            )
            return False
        try:
            raw = joblib.load(path)
            self.bundle = ModelBundle(
                model=raw["model"],
                feature_names=raw["feature_names"],
                disease_names=raw["disease_names"],
                disease_symptom_map=raw["disease_symptom_map"],
                metadata=raw.get("metadata", {}),
            )
            self._vocabulary = set(self.bundle.feature_names)
            self.alias_map = load_alias_map(Path(__file__).parent.parent / "data" / "symptom_aliases.json")
            logger.info(
                "Loaded model: %d features, %d classes",
                len(self.bundle.feature_names),
                len(self.bundle.disease_names),
            )
            return True
        except Exception:
            logger.exception("Failed to load model bundle from %s", path)
            self.bundle = None
            return False

    @property
    def is_ready(self) -> bool:
        return self.bundle is not None

    # ------------------------------------------------------------ symptoms --
    def symptom_vocabulary(self) -> List[str]:
        return list(self.bundle.feature_names) if self.bundle else []

    def resolve_symptoms(self, symptoms: List[str]) -> tuple[List[str], List[str]]:
        """Normalise + alias user input. Returns (recognised, unrecognised)."""
        recognised: List[str] = []
        unrecognised: List[str] = []
        for raw in symptoms:
            canon = apply_aliases(normalize_symptom(raw), self.alias_map, self._vocabulary)
            if canon in self._vocabulary:
                if canon not in recognised:
                    recognised.append(canon)
            elif raw.strip():
                unrecognised.append(raw.strip())
        return recognised, unrecognised

    # ------------------------------------------------------------- predict --
    def predict(self, symptoms: List[str], top_k: Optional[int] = None) -> Dict:
        if not self.is_ready:
            raise RuntimeError("Prediction model is not loaded.")

        settings = get_settings()
        top_k = top_k or settings.TOP_K_PREDICTIONS
        recognised, unrecognised = self.resolve_symptoms(symptoms)

        if not recognised:
            return {
                "results": [],
                "recognised_symptoms": [],
                "unrecognised_symptoms": unrecognised,
                "message": (
                    "None of the selected symptoms are present in the prediction "
                    "dataset, so no candidate conditions can be ranked."
                ),
            }

        # Built as a named frame: the model was fitted on a DataFrame, so passing
        # a bare array would drop the feature names and warn on every call.
        row = {name: 0 for name in self.bundle.feature_names}
        for symptom in recognised:
            row[symptom] = 1
        vector = pd.DataFrame([row], columns=self.bundle.feature_names, dtype="int8")

        probabilities = self.bundle.model.predict_proba(vector)[0]
        classes = list(self.bundle.model.classes_)
        order = np.argsort(probabilities)[::-1][:top_k]

        results: List[PredictionResult] = []
        for rank, idx in enumerate(order, start=1):
            disease = str(classes[idx])
            confidence = float(probabilities[idx])
            if confidence < settings.MIN_CONFIDENCE_TO_SHOW and rank > 1:
                continue
            results.append(self._build_result(disease, confidence, recognised, rank))

        return {
            "results": [r.__dict__ for r in results],
            "recognised_symptoms": recognised,
            "unrecognised_symptoms": unrecognised,
            "message": None,
        }


    def suggest_symptoms(self, selected: List[str], limit: int = 6) -> List[str]:
        """
        Symptoms that commonly occur alongside the current selection.

        Each condition is weighted by the share of the selection it accounts
        for, squared so that a condition explaining most of the selection
        contributes far more than one explaining a single symptom. Its
        remaining characteristic symptoms are then scored by that weight times
        their measured support.

        This is a co-occurrence statistic computed from the training data. It
        is not a clinical recommendation and asserts nothing about the person;
        the interface presents it as a prompt, never as a prediction.
        """
        if not self.is_ready or not selected:
            return []

        chosen = set(selected)
        scores: Dict[str, float] = {}

        for disease, supports in self.bundle.disease_symptom_map.items():
            characteristic = {
                s for s, v in supports.items()
                if v >= SUPPORT_THRESHOLD and s in self._vocabulary
            }
            if not characteristic:
                continue
            overlap = len(characteristic & chosen)
            if overlap == 0:
                continue
            weight = (overlap / len(chosen)) ** 2
            for symptom in characteristic - chosen:
                scores[symptom] = scores.get(symptom, 0.0) + weight * supports[symptom]

        ranked = sorted(scores.items(), key=lambda kv: -kv[1])
        return [s for s, _ in ranked[:limit]]

    # --------------------------------------------------------------- build --
    def _build_result(
        self, disease: str, confidence: float, selected: List[str], rank: int
    ) -> PredictionResult:
        supports = self.bundle.disease_symptom_map.get(disease, {})
        characteristic = {s for s, v in supports.items() if v >= SUPPORT_THRESHOLD}

        matched = [s for s in selected if s in characteristic]
        unmatched = [s for s in selected if s not in characteristic]

        # The score is normalised against what a user could actually have
        # selected, not against the full profile of the condition.
        #
        # The interface caps selection at MAX_SELECTED_SYMPTOMS. Conditions
        # recorded with more symptoms than that could otherwise never score
        # highly however well the user described their complaint: Common Cold
        # carries 17 characteristic symptoms, so against the full profile its
        # ceiling was 6/17 = 35%, and a user who named four of them correctly
        # saw 24%. That penalised the condition for being broadly described in
        # the dataset rather than for fitting the report poorly.
        #
        # Dividing by min(|characteristic|, cap) asks the answerable question:
        # of the symptoms you could have named for this condition, how many did
        # you? Conditions with six or fewer characteristic symptoms are
        # unaffected, so this changes nothing where the previous denominator
        # was already reachable. The full profile size is still reported in the
        # explanation, so no information is concealed.
        reachable = min(len(characteristic), MAX_SELECTED_SYMPTOMS)
        symptom_match = (len(matched) / reachable) if reachable else 0.0
        symptom_match = min(symptom_match, 1.0)

        return PredictionResult(
            disease=disease,
            slug=slugify(disease),
            model_confidence=round(confidence, 4),
            symptom_match=round(symptom_match, 4),
            matched_symptoms=matched,
            unmatched_symptoms=unmatched,
            explanation=self._explain(len(matched), len(selected), len(characteristic)),
            rank=rank,
        )

    @staticmethod
    def _explain(n_matched: int, n_selected: int, n_characteristic: int) -> str:
        """
        Template-based explanation grounded in counts only.

        No clinical reasoning is asserted and no chain-of-thought is exposed -
        the sentence describes what overlap was observed in the dataset.
        """
        if n_characteristic == 0:
            return (
                "This condition was ranked by the model, but the dataset does not "
                "record a consistent set of symptoms for it, so no symptom overlap "
                "can be shown."
            )
        if n_matched == 0:
            return (
                "None of the selected symptoms are among the symptoms recorded for "
                "this condition in the prediction dataset. It appears only because "
                "the model still assigns it some probability."
            )
        word = "symptom" if n_matched == 1 else "symptoms"
        return (
            f"{n_matched} of your {n_selected} selected {word} "
            f"{'matches' if n_matched == 1 else 'match'} symptoms associated with this "
            f"condition in the prediction dataset, out of {n_characteristic} symptoms "
            "commonly recorded for it."
        )


engine = PredictionEngine()


def get_engine() -> PredictionEngine:
    return engine


def load_processed_json(name: str) -> Optional[object]:
    """Read a file written by the preprocessing step, if present."""
    path = get_settings().PROCESSED_DIR / name
    if not path.exists():
        return None
    return json.loads(path.read_text(encoding="utf-8"))
