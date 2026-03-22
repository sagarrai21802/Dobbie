from datetime import datetime, timezone
from typing import Optional
from bson import ObjectId
from pymongo.errors import DuplicateKeyError

from app.models.user import create_user_document, user_to_response
from app.utils.security import (
    hash_password,
    verify_password,
    create_access_token,
    create_refresh_token,
    decode_token,
    validate_password_strength,
)
from app.config import settings


class AuthService:
    @staticmethod
    async def register(db, email: str, password: str, full_name: str) -> tuple[Optional[dict], Optional[str]]:
        """
        Register a new user.
        Returns (user_response, error_message)
        """
        is_valid, error_msg = validate_password_strength(password)
        if not is_valid:
            return None, error_msg
        
        existing_user = await db.users.find_one({"email": email.lower().strip()})
        if existing_user:
            return None, "Email already registered"
        
        password_hash = hash_password(password)
        user_doc = create_user_document(email, password_hash, full_name)
        
        try:
            result = await db.users.insert_one(user_doc)
            user_doc["_id"] = result.inserted_id
            return user_to_response(user_doc), None
        except DuplicateKeyError:
            return None, "Email already registered"
        except Exception as e:
            return None, f"Failed to create user: {str(e)}"

    @staticmethod
    async def login(db, email: str, password: str) -> tuple[Optional[dict], Optional[str]]:
        """
        Authenticate user and return tokens.
        Returns (token_response, error_message)
        """
        user = await db.users.find_one({"email": email.lower().strip()})
        
        if not user:
            return None, "Invalid email or password"
        
        if not verify_password(password, user["password_hash"]):
            return None, "Invalid email or password"
        
        if not user.get("is_active", True):
            return None, "Account is deactivated"
        
        access_token = create_access_token(data={"sub": str(user["_id"])})
        refresh_token = create_refresh_token(data={"sub": str(user["_id"])})
        
        await db.users.update_one(
            {"_id": user["_id"]},
            {"$set": {"updated_at": datetime.now(timezone.utc)}}
        )
        
        return {
            "access_token": access_token,
            "refresh_token": refresh_token,
            "token_type": "bearer",
            "expires_in": settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
        }, None

    @staticmethod
    async def refresh_token(db, refresh_token: str) -> tuple[Optional[dict], Optional[str]]:
        """
        Refresh access token using refresh token.
        Returns (token_response, error_message)
        """
        payload = decode_token(refresh_token)
        
        if payload is None:
            return None, "Invalid or expired refresh token"
        
        if payload.get("type") != "refresh":
            return None, "Invalid token type"
        
        user_id = payload.get("sub")
        if not user_id:
            return None, "Invalid token payload"
        
        try:
            user = await db.users.find_one({"_id": ObjectId(user_id)})
        except Exception:
            return None, "Invalid user ID"
        
        if not user:
            return None, "User not found"
        
        if not user.get("is_active", True):
            return None, "Account is deactivated"
        
        new_access_token = create_access_token(data={"sub": str(user["_id"])})
        new_refresh_token = create_refresh_token(data={"sub": str(user["_id"])})
        
        return {
            "access_token": new_access_token,
            "refresh_token": new_refresh_token,
            "token_type": "bearer",
            "expires_in": settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
        }, None

    @staticmethod
    async def get_user_by_id(db, user_id: str) -> Optional[dict]:
        """Get user by ID."""
        try:
            user = await db.users.find_one({"_id": ObjectId(user_id)})
            return user_to_response(user) if user else None
        except Exception:
            return None

    @staticmethod
    async def update_user(db, user_id: str, full_name: Optional[str] = None) -> Optional[dict]:
        """Update user profile."""
        update_data = {"updated_at": datetime.now(timezone.utc)}
        if full_name:
            update_data["full_name"] = full_name.strip()
        
        try:
            result = await db.users.find_one_and_update(
                {"_id": ObjectId(user_id)},
                {"$set": update_data},
                return_document=True
            )
            return user_to_response(result) if result else None
        except Exception:
            return None

    @staticmethod
    async def logout(db, refresh_token: str) -> bool:
        """
        Logout user by invalidating refresh token.
        For now, this is a placeholder - token invalidation would require a blacklist.
        """
        return True
