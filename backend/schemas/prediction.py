"""Request/response models for symptom analysis."""
from typing import List, Optional

from pydantic import BaseModel, Field, field_validator


class AnalyzeRequest(BaseModel):
    symptoms: List[str] = Field(min_length=1, max_length=40)
    language: str = "en"
    save_to_history: bool = True

    @field_validator("symptoms")
    @classmethod
    def not_blank(cls, value: List[str]) -> List[str]:
        cleaned = [s.strip() for s in value if s and s.strip()]
        if not cleaned:
            raise ValueError("Select at least one symptom before analysing.")
        return list(dict.fromkeys(cleaned))     # de-duplicate, keep order


class PredictionItem(BaseModel):
    disease: str
    slug: str
    model_confidence: float
    symptom_match: float
    matched_symptoms: List[str]
    unmatched_symptoms: List[str]
    explanation: str
    rank: int


class AnalyzeResponse(BaseModel):
    results: List[PredictionItem]
    recognised_symptoms: List[str]
    unrecognised_symptoms: List[str]
    urgency: dict
    disclaimer: str
    language: str
    message: Optional[str] = None
    history_id: Optional[str] = None
    translation_note: Optional[str] = None


class MedicalQueryRequest(BaseModel):
    question: str = Field(min_length=3, max_length=1000)
    language: Optional[str] = None


class SymptomExtractRequest(BaseModel):
    text: str = Field(min_length=2, max_length=2000)
    language: Optional[str] = None
