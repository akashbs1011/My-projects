"""Authentication endpoints. Passwords are hashed with bcrypt, never stored raw."""
import logging
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from motor.motor_asyncio import AsyncIOMotorDatabase
from pymongo.errors import DuplicateKeyError

from config import get_settings
from models import user as user_model
from routes.deps import current_user, db_dependency
from schemas.auth import (
    ForgotPasswordRequest,
    LoginRequest,
    RegisterRequest,
    ResetPasswordRequest,
    TokenResponse,
)
from utils.helpers import serialize
from utils.security import (
    create_access_token,
    generate_reset_token,
    hash_password,
    hash_reset_token,
    verify_password,
)

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/register", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
async def register(payload: RegisterRequest, db: AsyncIOMotorDatabase = Depends(db_dependency)):
    document = user_model.new_user_document(
        name=payload.name,
        email=payload.email,
        password_hash=hash_password(payload.password),
        preferred_language=payload.preferred_language,
    )
    try:
        created = await user_model.create(db, document)
    except DuplicateKeyError:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="An account already exists with this email. Sign in instead.",
        )
    token = create_access_token(str(created["_id"]))
    return {"access_token": token, "token_type": "bearer", "user": serialize(created)}


@router.post("/login", response_model=TokenResponse)
async def login(payload: LoginRequest, db: AsyncIOMotorDatabase = Depends(db_dependency)):
    user = await user_model.get_by_email(db, payload.email)
    # Identical response for unknown email and wrong password - no account enumeration.
    if user is None or not verify_password(payload.password, user["password_hash"]):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="That email and password combination doesn't match an account.",
        )
    token = create_access_token(str(user["_id"]))
    return {"access_token": token, "token_type": "bearer", "user": serialize(user)}


@router.get("/me")
async def me(user: dict = Depends(current_user)):
    return serialize(user)


@router.post("/logout")
async def logout(user: dict = Depends(current_user)):
    """
    Tokens are stateless, so logout is completed client-side by discarding the
    token. This endpoint exists so the client has a single place to call and
    so a token denylist can be added later without changing the contract.
    """
    return {"message": "Signed out."}


@router.post("/forgot-password")
async def forgot_password(
    payload: ForgotPasswordRequest, db: AsyncIOMotorDatabase = Depends(db_dependency)
):
    settings = get_settings()
    user = await user_model.get_by_email(db, payload.email)
    response = {
        "message": "If an account exists for that email, a reset link has been sent."
    }

    if user is None:
        return response

    raw, digest, expires = generate_reset_token()
    await user_model.set_reset_token(db, user["_id"], digest, expires)

    # Wire an email provider here. Until then the token is only exposed in
    # DEBUG so local development can complete the flow.
    logger.info("Password reset requested for user %s", user["_id"])
    if settings.DEBUG:
        response["debug_reset_token"] = raw
    return response


@router.post("/reset-password")
async def reset_password(
    payload: ResetPasswordRequest, db: AsyncIOMotorDatabase = Depends(db_dependency)
):
    digest = hash_reset_token(payload.token)
    user = await db.users.find_one({"reset_token_hash": digest})

    if user is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="This reset link is not valid. Request a new one.",
        )

    expires = user.get("reset_token_expires")
    if expires is None or expires.replace(tzinfo=timezone.utc) < datetime.now(timezone.utc):
        await user_model.clear_reset_token(db, user["_id"])
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="This reset link has expired. Request a new one.",
        )

    await db.users.update_one(
        {"_id": user["_id"]}, {"$set": {"password_hash": hash_password(payload.password)}}
    )
    await user_model.clear_reset_token(db, user["_id"])
    return {"message": "Password updated. You can sign in now."}
