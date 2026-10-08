"""Request models for profile management."""
from typing import Optional

from pydantic import BaseModel, Field, field_validator

from schemas.auth import SUPPORTED


class UpdateProfileRequest(BaseModel):
    name: Optional[str] = Field(default=None, min_length=2, max_length=80)
    preferred_language: Optional[str] = None

    @field_validator("preferred_language")
    @classmethod
    def supported_language(cls, value):
        if value is not None and value not in SUPPORTED:
            raise ValueError(f"Language must be one of: {', '.join(sorted(SUPPORTED))}")
        return value


class ChangePasswordRequest(BaseModel):
    current_password: str
    new_password: str = Field(min_length=8, max_length=128)
