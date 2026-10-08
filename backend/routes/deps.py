"""Shared FastAPI dependencies."""
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from motor.motor_asyncio import AsyncIOMotorDatabase

from database import get_database
from models import user as user_model
from utils.security import decode_token

bearer = HTTPBearer(auto_error=False)

CREDENTIALS_ERROR = HTTPException(
    status_code=status.HTTP_401_UNAUTHORIZED,
    detail="Your session is not valid. Please sign in again.",
    headers={"WWW-Authenticate": "Bearer"},
)


def db_dependency() -> AsyncIOMotorDatabase:
    try:
        return get_database()
    except RuntimeError:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="The database is unavailable. Try again shortly.",
        )


async def current_user(
    credentials: HTTPAuthorizationCredentials = Depends(bearer),
    db: AsyncIOMotorDatabase = Depends(db_dependency),
) -> dict:
    if credentials is None:
        raise CREDENTIALS_ERROR
    payload = decode_token(credentials.credentials)
    if not payload or payload.get("type") != "access":
        raise CREDENTIALS_ERROR
    user = await user_model.get_by_id(db, payload.get("sub", ""))
    if user is None:
        raise CREDENTIALS_ERROR
    return user
