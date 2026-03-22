import hmac
import hashlib
import base64
from passlib.context import CryptContext
from jose import JWTError, jwt
from datetime import datetime, timedelta, timezone
from typing import Optional

from app.config import settings

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def hash_password(password: str) -> str:
    """Hash a password using bcrypt."""
    return pwd_context.hash(password)


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify a password against its hash."""
    return pwd_context.verify(plain_password, hashed_password)


def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    """Create a JWT access token."""
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.now(timezone.utc) + expires_delta
    else:
        expire = datetime.now(timezone.utc) + timedelta(
            minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES
        )
    to_encode.update({"exp": expire, "type": "access"})
    return jwt.encode(
        to_encode,
        settings.JWT_SECRET_KEY,
        algorithm=settings.JWT_ALGORITHM
    )


def create_refresh_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    """Create a JWT refresh token."""
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.now(timezone.utc) + expires_delta
    else:
        expire = datetime.now(timezone.utc) + timedelta(
            days=settings.REFRESH_TOKEN_EXPIRE_DAYS
        )
    to_encode.update({"exp": expire, "type": "refresh"})
    return jwt.encode(
        to_encode,
        settings.JWT_SECRET_KEY,
        algorithm=settings.JWT_ALGORITHM
    )


def decode_token(token: str) -> Optional[dict]:
    """Decode and validate a JWT token."""
    try:
        payload = jwt.decode(
            token,
            settings.JWT_SECRET_KEY,
            algorithms=[settings.JWT_ALGORITHM]
        )
        return payload
    except JWTError:
        return None


def validate_password_strength(password: str) -> tuple[bool, str]:
    """
    Validate password strength.
    Returns (is_valid, error_message)
    """
    if len(password) < 8:
        return False, "Password must be at least 8 characters long"
    if not any(c.isupper() for c in password):
        return False, "Password must contain at least one uppercase letter"
    if not any(c.isdigit() for c in password):
        return False, "Password must contain at least one number"
    return True, ""


def create_oauth_state(user_id: str) -> str:
    """
    Create a signed OAuth state parameter.
    Format: base64(user_id.signature)
    """
    signature = hmac.new(
        settings.JWT_SECRET_KEY.encode(),
        user_id.encode(),
        hashlib.sha256
    ).hexdigest()
    return base64.urlsafe_b64encode(f"{user_id}.{signature}".encode()).decode()


def verify_oauth_state(state: str) -> Optional[str]:
    """
    Verify an OAuth state parameter and return the user_id if valid.
    Returns None if state is invalid, tampered, or malformed.
    """
    try:
        decoded = base64.urlsafe_b64decode(state).decode()
        parts = decoded.rsplit(".", 1)
        if len(parts) != 2:
            return None
        user_id, signature = parts
        expected_signature = hmac.new(
            settings.JWT_SECRET_KEY.encode(),
            user_id.encode(),
            hashlib.sha256
        ).hexdigest()
        if hmac.compare_digest(signature, expected_signature):
            return user_id
        return None
    except Exception:
        return None
