"""Application configuration. All secrets come from environment variables."""
from functools import lru_cache
from pathlib import Path
from typing import List

from pydantic import Field
from pydantic_settings import BaseSettings

BASE_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = BASE_DIR.parent


class Settings(BaseSettings):
    # --- App ---
    APP_NAME: str = "Clinical-AI"
    DEBUG: bool = False
    API_PREFIX: str = "/api"
    CORS_ORIGINS: List[str] = ["http://localhost:8080", "http://127.0.0.1:8080"]

    # --- Database ---
    DATABASE_URL: str = "mongodb://localhost:27017"
    DATABASE_NAME: str = "clinical_ai"

    # --- Auth ---
    JWT_SECRET: str = ""
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24
    RESET_TOKEN_EXPIRE_MINUTES: int = 30

    # --- Datasets / artifacts ---
    TRAINING_CSV: Path = PROJECT_ROOT / "datasets" / "Training.csv"
    TESTING_CSV: Path = PROJECT_ROOT / "datasets" / "Testing.csv"
    DESCRIPTION_CSV: Path = PROJECT_ROOT / "datasets" / "symptom_Description.csv"
    PRECAUTION_CSV: Path = PROJECT_ROOT / "datasets" / "symptom_precaution.csv"
    SEVERITY_CSV: Path = PROJECT_ROOT / "datasets" / "Symptom-severity.csv"

    MODEL_DIR: Path = PROJECT_ROOT / "models"
    MODEL_PATH: Path = PROJECT_ROOT / "models" / "disease_model.joblib"
    PROCESSED_DIR: Path = BASE_DIR / "data" / "processed"
    VECTOR_DB_PATH: Path = BASE_DIR / "data" / "vectorstore"
    EVAL_DIR: Path = PROJECT_ROOT / "docs" / "model_evaluation"

    # --- ML ---
    RANDOM_STATE: int = 42
    TEST_SIZE: float = 0.2
    N_ESTIMATORS: int = 300
    TOP_K_PREDICTIONS: int = 3
    MIN_CONFIDENCE_TO_SHOW: float = 0.01

    # --- Translation ---
    TRANSLATION_PROVIDER: str = "none"   # none | indictrans2 | google | azure
    TRANSLATION_API_KEY: str = ""
    TRANSLATION_REGION: str = ""
    SUPPORTED_LANGUAGES: List[str] = ["en", "hi", "kn", "te", "ta", "ml"]

    class Config:
        env_file = str(PROJECT_ROOT / ".env")
        case_sensitive = True
        extra = "ignore"


@lru_cache
def get_settings() -> Settings:
    s = Settings()
    if not s.JWT_SECRET:
        raise RuntimeError(
            "JWT_SECRET is not set. Copy .env.example to .env and set a strong secret "
            "(e.g. `python -c \"import secrets;print(secrets.token_urlsafe(48))\"`)."
        )
    for p in (s.MODEL_DIR, s.PROCESSED_DIR, s.VECTOR_DB_PATH, s.EVAL_DIR):
        p.mkdir(parents=True, exist_ok=True)
    return s


settings = get_settings() if __name__ != "__main__" else None
