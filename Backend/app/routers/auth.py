from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from typing import List

from app.database import get_db
from app.schemas.auth import (
    UserRegister,
    UserLogin,
    GoogleLogin,
    TokenResponse,
    TokenRefresh,
    UserResponse,
    UserUpdate,
    MessageResponse,
)
from app.services.auth_service import AuthService
from app.utils.dependencies import get_current_user

router = APIRouter(prefix="/auth", tags=["authentication"])


@router.post("/register", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
async def register(user_data: UserRegister, db=Depends(get_db)):
    """
    Register a new user account.
    
    - **email**: Valid email address (must be unique)
    - **password**: Min 8 chars, 1 uppercase, 1 number
    - **full_name**: User's full name (2-100 chars)
    """
    user, error = await AuthService.register(
        db,
        email=user_data.email,
        password=user_data.password,
        full_name=user_data.full_name
    )
    
    if error:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=error
        )
    
    return user


@router.post("/login", response_model=TokenResponse)
async def login(user_data: UserLogin, db=Depends(get_db)):
    """
    Authenticate user and return JWT tokens.
    
    - **email**: User's email address
    - **password**: User's password
    """
    tokens, error = await AuthService.login(
        db,
        email=user_data.email,
        password=user_data.password
    )
    
    if error:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=error
        )
    
    return tokens


@router.post("/google", response_model=TokenResponse)
async def google_login(google_data: GoogleLogin, db=Depends(get_db)):
    """
    Authenticate user via Google ID token and return JWT tokens.
    
    - **id_token**: Google ID token from flutter_signin_google
    
    The token is verified server-side and the user is created or updated
    in the database. Returns standard JWT tokens for subsequent requests.
    """
    tokens, error = await AuthService.google_login(
        db,
        id_token_str=google_data.id_token
    )
    
    if error:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=error
        )
    
    return tokens


@router.post("/login/form", response_model=TokenResponse)
async def login_form(form_data: OAuth2PasswordRequestForm = Depends(), db=Depends(get_db)):
    """
    OAuth2 compatible login endpoint (for Swagger UI).
    
    - **username**: Email address (OAuth2 standard uses username field)
    - **password**: User's password
    """
    tokens, error = await AuthService.login(
        db,
        email=form_data.username,
        password=form_data.password
    )
    
    if error:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=error
        )
    
    return tokens


@router.post("/refresh", response_model=TokenResponse)
async def refresh_token(token_data: TokenRefresh, db=Depends(get_db)):
    """
    Refresh access token using refresh token.
    
    - **refresh_token**: Valid refresh token from login
    """
    tokens, error = await AuthService.refresh_token(
        db,
        refresh_token=token_data.refresh_token
    )
    
    if error:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=error
        )
    
    return tokens


@router.post("/logout", response_model=MessageResponse)
async def logout(
    token_data: TokenRefresh,
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """
    Logout user (invalidate session).
    
    Requires valid access token in header.
    """
    await AuthService.logout(db, token_data.refresh_token)
    return MessageResponse(message="Successfully logged out")


@router.get("/me", response_model=UserResponse)
async def get_current_user_profile(current_user: dict = Depends(get_current_user)):
    """
    Get current authenticated user's profile.
    
    Requires valid access token in header.
    """
    return {
        "id": str(current_user["_id"]),
        "email": current_user["email"],
        "full_name": current_user["full_name"],
        "is_active": current_user["is_active"],
        "profile": current_user.get("profile"),
        "created_at": current_user["created_at"],
        "updated_at": current_user["updated_at"],
    }


@router.put("/me", response_model=UserResponse)
async def update_current_user_profile(
    user_update: UserUpdate,
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """
    Update current user's profile.
    
    Requires valid access token in header.
    """
    updated_user = await AuthService.update_user(
        db,
        user_id=str(current_user["_id"]),
        full_name=user_update.full_name
    )
    
    if not updated_user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Failed to update user profile"
        )
    
    return updated_user


@router.post("/change-password", response_model=MessageResponse)
async def change_password(
    current_password: str,
    new_password: str,
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """
    Change current user's password.
    
    Requires valid access token in header.
    """
    from app.utils.security import verify_password, validate_password_strength
    
    if not verify_password(current_password, current_user["password_hash"]):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Current password is incorrect"
        )
    
    is_valid, error_msg = validate_password_strength(new_password)
    if not is_valid:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=error_msg
        )
    
    from app.utils.security import hash_password
    from datetime import datetime, timezone
    
    await db.users.update_one(
        {"_id": current_user["_id"]},
        {
            "$set": {
                "password_hash": hash_password(new_password),
                "updated_at": datetime.now(timezone.utc)
            }
        }
    )
    
    return MessageResponse(message="Password changed successfully")
