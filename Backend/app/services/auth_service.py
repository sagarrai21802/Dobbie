from datetime import datetime, timezone, timedelta
from typing import Optional
from bson import ObjectId
from pymongo.errors import DuplicateKeyError
from google.auth.transport import requests
from google.oauth2 import id_token
import httpx
import urllib.parse
import secrets
import hashlib

from app.models.user import create_user_document, user_to_response, _default_profile_document
from app.utils.security import (
    hash_password,
    verify_password,
    create_access_token,
    create_refresh_token,
    decode_token,
    validate_password_strength,
)
from app.config import settings


async def create_refresh_token_db(db, user_id: str) -> str:
    """
    Create a secure refresh token stored in MongoDB (not JWT).
    Returns the raw token that will be sent to the client in HttpOnly cookie.
    """
    raw_token = secrets.token_urlsafe(64)
    token_hash = hashlib.sha256(raw_token.encode()).hexdigest()
    
    now = datetime.now(timezone.utc)
    expires_at = now + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)
    
    await db.refresh_tokens.insert_one({
        "token_hash": token_hash,
        "user_id": user_id,
        "expires_at": expires_at,
        "created_at": now,
        "used": False,
        "replaced_by": None,
    })
    
    return raw_token


async def rotate_refresh_token(db, old_token_hash: str, user_id: str) -> tuple[str, str]:
    """
    Rotate a refresh token: mark old as used, create new one.
    Returns (new_access_token, new_raw_refresh_token).
    """
    now = datetime.now(timezone.utc)
    expires_at = now + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)
    
    new_raw_token = secrets.token_urlsafe(64)
    new_token_hash = hashlib.sha256(new_raw_token.encode()).hexdigest()
    
    await db.refresh_tokens.update_one(
        {"token_hash": old_token_hash},
        {"$set": {"used": True, "replaced_by": new_token_hash}}
    )
    
    await db.refresh_tokens.insert_one({
        "token_hash": new_token_hash,
        "user_id": user_id,
        "expires_at": expires_at,
        "created_at": now,
        "used": False,
        "replaced_by": None,
    })
    
    new_access_token = create_access_token(data={"sub": user_id})
    return new_access_token, new_raw_token


async def cleanup_expired_tokens(db) -> int:
    """
    Delete all refresh tokens that are expired or already used.
    Returns count of deleted tokens.
    """
    now = datetime.now(timezone.utc)
    result = await db.refresh_tokens.delete_many({
        "$or": [
            {"expires_at": {"$lt": now}},
            {"used": True},
        ]
    })
    return result.deleted_count


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
        refresh_token = await create_refresh_token_db(db, str(user["_id"]))
        
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
    async def google_login(db, id_token_str: str) -> tuple[Optional[dict], Optional[str]]:
        """
        Authenticate user via Google ID token and return JWT tokens.
        Verifies token and upserts user by email.
        Also fetches profile picture and additional user info.
        Returns (token_response, error_message)
        """
        try:
            # Verify the ID token using google-auth library
            # This validates signature, audience, and expiration
            client_ids = [
                settings.GOOGLE_ANDROID_CLIENT_ID,
                settings.GOOGLE_IOS_CLIENT_ID,
                settings.GOOGLE_WEB_CLIENT_ID,
            ]
            
            # Try to verify with either client ID
            payload = None
            for client_id in client_ids:
                try:
                    payload = id_token.verify_oauth2_token(
                        id_token_str,
                        requests.Request(),
                        audience=client_id
                    )
                    break  # Successfully verified
                except ValueError:
                    continue
            
            if payload is None:
                return None, "Invalid or expired Google ID token"
            
            # Extract essential user info from the verified token
            email = payload.get("email", "").lower().strip()
            full_name = payload.get("name", "Unknown User")
            google_id = payload.get("sub")
            
            # Get additional profile info from Google
            profile_picture = payload.get("picture", "")
            locale = payload.get("locale", "")
            
            if not email or not google_id:
                return None, "Invalid Google token: missing email or ID"
            
            # Check if user already exists by email
            existing_user = await db.users.find_one({"email": email})
            
            if existing_user:
                # User exists - update profile info if new data available
                if not existing_user.get("is_active", True):
                    return None, "Account is deactivated"
                
                update_data = {
                    "updated_at": datetime.now(timezone.utc),
                    "auth_provider": "google",
                }
                
                # Update profile picture if available
                if profile_picture:
                    existing_profile = existing_user.get("profile") or {}
                    if not existing_profile.get("profile_picture"):
                        update_data["profile.profile_picture"] = profile_picture
                        update_data["profile.name"] = full_name
                        update_data["profile.locale"] = locale
                
                await db.users.update_one(
                    {"_id": existing_user["_id"]},
                    {"$set": update_data}
                )
                
                # Fetch fresh user data
                user = await db.users.find_one({"_id": existing_user["_id"]})
            else:
                # Create new user from Google login (no password needed)
                profile = _default_profile_document()
                profile["name"] = full_name
                profile["profile_picture"] = profile_picture
                profile["locale"] = locale
                
                user_doc = create_user_document(
                    email=email,
                    password_hash="",
                    full_name=full_name,
                    auth_provider="google"
                )
                user_doc["profile"] = profile
                
                result = await db.users.insert_one(user_doc)
                user_doc["_id"] = result.inserted_id
                user = user_doc
            
            # Generate JWT tokens
            access_token = create_access_token(data={"sub": str(user["_id"])})
            refresh_token = await create_refresh_token_db(db, str(user["_id"]))
            
            return {
                "access_token": access_token,
                "refresh_token": refresh_token,
                "token_type": "bearer",
                "expires_in": settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
            }, None
            
        except ValueError as e:
            return None, f"Google token verification failed: {str(e)}"
        except Exception as e:
            return None, f"Google login error: {str(e)}"

    @staticmethod
    async def refresh_token(db, refresh_token: str) -> tuple[Optional[dict], Optional[str]]:
        """
        Refresh access token using refresh token from cookie.
        Returns (token_response, error_message)
        """
        token_hash = hashlib.sha256(refresh_token.encode()).hexdigest()
        
        db_token = await db.refresh_tokens.find_one({"token_hash": token_hash})
        
        if not db_token:
            return None, "invalid_token"
        
        if db_token.get("used", False):
            await db.refresh_tokens.delete_many({"user_id": db_token["user_id"]})
            return None, "token_reuse_detected"
        
        if db_token.get("expires_at") < datetime.now(timezone.utc):
            return None, "refresh_token_expired"
        
        user_id = db_token["user_id"]
        
        new_access_token, new_refresh_token = await rotate_refresh_token(db, token_hash, user_id)
        
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
        Logout user by invalidating refresh token in DB.
        """
        try:
            token_hash = hashlib.sha256(refresh_token.encode()).hexdigest()
            await db.refresh_tokens.update_one(
                {"token_hash": token_hash},
                {"$set": {"used": True}}
            )
            return True
        except Exception:
            return True

    @staticmethod
    async def google_oauth_exchange(db, authorization_code: str) -> tuple[Optional[dict], Optional[str]]:
        """
        Exchange authorization code for tokens and authenticate user.
        Uses the OAuth 2.0 token exchange flow.
        Returns (token_response, error_message)
        """
        try:
            # Exchange authorization code for tokens
            token_data = {
                "code": authorization_code,
                "client_id": settings.GOOGLE_WEB_CLIENT_ID,
                "client_secret": settings.GOOGLE_CLIENT_SECRET,
                "redirect_uri": settings.GOOGLE_REDIRECT_URI,
                "grant_type": "authorization_code",
            }
            
            async with httpx.AsyncClient() as client:
                response = await client.post(
                    settings.GOOGLE_TOKEN_URL,
                    data=token_data,
                    headers={"Content-Type": "application/x-www-form-urlencoded"}
                )
            
            if response.status_code != 200:
                return None, f"Token exchange failed: {response.text}"
            
            tokens_data = response.json()
            id_token_str = tokens_data.get("id_token")
            access_token = tokens_data.get("access_token")  # Get access token for userinfo call
            
            if not id_token_str:
                return None, "No ID token in response"
            
            # Verify the ID token
            client_ids = [
                settings.GOOGLE_ANDROID_CLIENT_ID,
                settings.GOOGLE_IOS_CLIENT_ID,
                settings.GOOGLE_WEB_CLIENT_ID,
            ]
            
            payload = None
            for client_id in client_ids:
                try:
                    payload = id_token.verify_oauth2_token(
                        id_token_str,
                        requests.Request(),
                        audience=client_id
                    )
                    break
                except ValueError:
                    continue
            
            if payload is None:
                return None, "Invalid or expired Google ID token"
            
            # Extract user info from ID token
            email = payload.get("email", "").lower().strip()
            full_name = payload.get("name", "Unknown User")
            google_id = payload.get("sub")
            
            # Get additional profile info from userinfo endpoint using access token
            profile_picture = ""
            locale = ""
            
            if access_token:
                try:
                    async with httpx.AsyncClient() as client:
                        userinfo_response = await client.get(
                            settings.GOOGLE_USERINFO_URL,
                            headers={"Authorization": f"Bearer {access_token}"}
                        )
                        if userinfo_response.status_code == 200:
                            userinfo = userinfo_response.json()
                            profile_picture = userinfo.get("picture", "")
                            locale = userinfo.get("locale", "")
                except Exception:
                    pass  # If userinfo fails, continue without picture
            
            if not email or not google_id:
                return None, "Invalid Google token: missing email or ID"
            
            # Check if user exists
            existing_user = await db.users.find_one({"email": email})
            
            if existing_user:
                if not existing_user.get("is_active", True):
                    return None, "Account is deactivated"
                
                update_data = {
                    "updated_at": datetime.now(timezone.utc),
                    "auth_provider": "google",
                }
                
                if profile_picture:
                    existing_profile = existing_user.get("profile") or {}
                    if not existing_profile.get("profile_picture"):
                        update_data["profile.profile_picture"] = profile_picture
                        update_data["profile.name"] = full_name
                        update_data["profile.locale"] = locale
                
                await db.users.update_one(
                    {"_id": existing_user["_id"]},
                    {"$set": update_data}
                )
                
                user = await db.users.find_one({"_id": existing_user["_id"]})
            else:
                # Create new user
                profile = _default_profile_document()
                profile["name"] = full_name
                profile["profile_picture"] = profile_picture
                profile["locale"] = locale
                
                user_doc = create_user_document(
                    email=email,
                    password_hash="",
                    full_name=full_name,
                    auth_provider="google"
                )
                user_doc["profile"] = profile
                
                result = await db.users.insert_one(user_doc)
                user_doc["_id"] = result.inserted_id
                user = user_doc
            
            # Generate JWT tokens
            access_token = create_access_token(data={"sub": str(user["_id"])})
            refresh_token = await create_refresh_token_db(db, str(user["_id"]))
            
            return {
                "access_token": access_token,
                "refresh_token": refresh_token,
                "token_type": "bearer",
                "expires_in": settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
            }, None
            
        except Exception as e:
            return None, f"Google OAuth error: {str(e)}"

