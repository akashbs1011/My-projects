"""Request/response models for authentication."""
from typing import Optional

from pydantic import BaseModel, EmailStr, Field, field_validator

SUPPORTED = {"en", "hi", "kn", "te", "ta", "ml"}


class RegisterRequest(BaseModel):
    name: str = Field(min_length=2, max_length=80)
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)
    confirm_password: str
    preferred_language: str = "en"

    @field_validator("password")
    @classmethod
    def strong_enough(cls, value: str) -> str:
        if value.isdigit() or value.isalpha():
            raise ValueError("Password must include both letters and numbers.")
        return value

    @field_validator("confirm_password")
    @classmethod
    def passwords_match(cls, value: str, info) -> str:
        if info.data.get("password") and value != info.data["password"]:
            raise ValueError("Passwords do not match.")
        return value

    @field_validator("preferred_language")
    @classmethod
    def supported_language(cls, value: str) -> str:
        if value not in SUPPORTED:
            raise ValueError(f"Language must be one of: {', '.join(sorted(SUPPORTED))}")
        return value


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class ForgotPasswordRequest(BaseModel):
    email: EmailStr


class ResetPasswordRequest(BaseModel):
    token: str
    password: str = Field(min_length=8, max_length=128)
    confirm_password: str

    @field_validator("confirm_password")
    @classmethod
    def passwords_match(cls, value: str, info) -> str:
        if info.data.get("password") and value != info.data["password"]:
            raise ValueError("Passwords do not match.")
        return value


class UserPublic(BaseModel):
    id: str
    name: str
    email: EmailStr
    preferred_language: str
    created_at: Optional[str] = None


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserPublic
