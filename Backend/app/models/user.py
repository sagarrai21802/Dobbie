from datetime import datetime, timezone
from typing import Optional
from bson import ObjectId


def _default_profile_document() -> dict:
    return {
        "name": "",
        "headline": "",
        "location": "",
        "current_role": "",
        "industry": "",
        "skills": [],
        "years_experience": None,
        "preferred_tone": "conversational",
        "is_complete": False,
        "updated_at": datetime.now(timezone.utc),
    }


def create_user_document(email: str, password_hash: str, full_name: str, auth_provider: str = "email") -> dict:
    """Create a new user document for MongoDB."""
    now = datetime.now(timezone.utc)
    return {
        "email": email.lower().strip(),
        "password_hash": password_hash,
        "full_name": full_name.strip(),
        "auth_provider": auth_provider,  # 'email', 'google', 'linkedin', etc.
        "is_active": True,
        "profile": _default_profile_document(),
        "created_at": now,
        "updated_at": now,
    }


def user_to_response(user: dict) -> dict:
    """Convert MongoDB user document to API response."""
    return {
        "id": str(user["_id"]),
        "email": user["email"],
        "full_name": user["full_name"],
        "is_active": user["is_active"],
        "profile": user.get("profile") or _default_profile_document(),
        "created_at": user["created_at"],
        "updated_at": user["updated_at"],
    }


def serialize_id(user: dict) -> dict:
    """Ensure _id is serialized as string."""
    if user and "_id" in user:
        user["id"] = str(user["_id"])
    return user
