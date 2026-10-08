"""Profile endpoints."""
from fastapi import APIRouter, Depends, HTTPException, status
from motor.motor_asyncio import AsyncIOMotorDatabase

from models import user as user_model
from routes.deps import current_user, db_dependency
from schemas.user import ChangePasswordRequest, UpdateProfileRequest
from utils.helpers import serialize
from utils.security import hash_password, verify_password

router = APIRouter(prefix="/users", tags=["users"])


@router.get("/profile")
async def get_profile(user: dict = Depends(current_user)):
    return serialize(user)


@router.patch("/profile")
async def update_profile(
    payload: UpdateProfileRequest,
    user: dict = Depends(current_user),
    db: AsyncIOMotorDatabase = Depends(db_dependency),
):
    changes = {k: v for k, v in payload.model_dump(exclude_none=True).items()}
    if not changes:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="No changes were provided."
        )
    updated = await user_model.update(db, str(user["_id"]), changes)
    return serialize(updated)


@router.post("/change-password")
async def change_password(
    payload: ChangePasswordRequest,
    user: dict = Depends(current_user),
    db: AsyncIOMotorDatabase = Depends(db_dependency),
):
    if not verify_password(payload.current_password, user["password_hash"]):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="Your current password is incorrect."
        )
    await user_model.update(
        db, str(user["_id"]), {"password_hash": hash_password(payload.new_password)}
    )
    return {"message": "Password updated."}
