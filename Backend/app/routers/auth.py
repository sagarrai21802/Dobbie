from fastapi import APIRouter, Depends, HTTPException, status, Response, Request
from fastapi.security import OAuth2PasswordRequestForm
from fastapi.responses import RedirectResponse, JSONResponse
from typing import List, Optional
import secrets
import urllib.parse
from datetime import datetime, timezone, timedelta

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
from app.config import settings

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


@router.post("/login")
async def login(user_data: UserLogin, db=Depends(get_db)):
    """
    Authenticate user and return JWT tokens.
    
    - **email**: User's email address
    - **password**: User's password
    
    Returns access_token in body, refresh_token in HttpOnly cookie.
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
    
    from fastapi.responses import JSONResponse
    response = JSONResponse(content={
        "access_token": tokens["access_token"],
        "token_type": "bearer",
    })
    
    refresh_cookie_max_age = 60 * 60 * 24 * settings.REFRESH_TOKEN_EXPIRE_DAYS
    
    is_local = settings.DEBUG or "localhost" in settings.FRONTEND_URL
    
    response.set_cookie(
        key="refresh_token",
        value=tokens["refresh_token"],
        httponly=True,
        secure=not is_local,
        samesite="lax",
        max_age=refresh_cookie_max_age,
        path="/api/v1/auth",
    )
    
    return response


@router.post("/google")
async def google_login(google_data: GoogleLogin, db=Depends(get_db)):
    """
    Authenticate user via Google ID token and return JWT tokens.
    
    - **id_token**: Google ID token from flutter_signin_google
    
    The token is verified server-side and the user is created or updated
    in the database. Returns access_token in body, refresh_token in HttpOnly cookie.
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
    
    from fastapi.responses import JSONResponse
    response = JSONResponse(content={
        "access_token": tokens["access_token"],
        "token_type": "bearer",
    })
    
    refresh_cookie_max_age = 60 * 60 * 24 * settings.REFRESH_TOKEN_EXPIRE_DAYS
    
    is_local = settings.DEBUG or "localhost" in settings.FRONTEND_URL
    
    response.set_cookie(
        key="refresh_token",
        value=tokens["refresh_token"],
        httponly=True,
        secure=not is_local,
        samesite="lax",
        max_age=refresh_cookie_max_age,
        path="/api/v1/auth",
    )
    
    return response


@router.get("/google/authorize")
async def google_authorize():
    """
    Initiate Google OAuth flow - redirect user to Google consent screen.
    
    The backend handles the OAuth redirect, state generation, and callback.
    After successful authentication, user is redirected to frontend with tokens.
    """
    # Generate state for CSRF protection
    state = secrets.token_urlsafe(32)
    
    # Store state in query params for the callback (simplified - production should use sessions/cookies)
    params = {
        "client_id": settings.GOOGLE_WEB_CLIENT_ID,
        "redirect_uri": settings.GOOGLE_REDIRECT_URI,
        "response_type": "code",
        "scope": settings.GOOGLE_SCOPE,
        "access_type": "offline",
        "prompt": "consent",
        "state": state,
    }
    
    auth_url = f"{settings.GOOGLE_AUTH_URL}?{urllib.parse.urlencode(params)}"
    
    return RedirectResponse(url=auth_url)


@router.get("/google/callback")
async def google_callback(
    code: Optional[str] = None,
    state: Optional[str] = None,
    error: Optional[str] = None,
    db=Depends(get_db)
):
    """
    OAuth callback - exchange authorization code for tokens and redirect to frontend.
    
    - **code**: Authorization code from Google
    - **state**: State parameter for CSRF verification
    - **error**: Error from Google if authentication failed
    
    After successful token exchange, redirects to frontend with JWT tokens.
    """
    if error:
        frontend_url = f"{settings.FRONTEND_URL}/auth/signin?error={urllib.parse.quote(error)}"
        return RedirectResponse(url=frontend_url)
    
    if not code:
        frontend_url = f"{settings.FRONTEND_URL}/auth/signin?error=missing_code"
        return RedirectResponse(url=frontend_url)
    
    if not state:
        frontend_url = f"{settings.FRONTEND_URL}/auth/signin?error=missing_state"
        return RedirectResponse(url=frontend_url)
    
    # Exchange authorization code for tokens
    tokens, auth_error = await AuthService.google_oauth_exchange(
        db,
        authorization_code=code
    )
    
    if auth_error:
        frontend_url = f"{settings.FRONTEND_URL}/auth/signin?error={urllib.parse.quote(auth_error)}"
        return RedirectResponse(url=frontend_url)
    
    # Redirect to frontend with tokens in query params
    frontend_url = f"{settings.FRONTEND_URL}/auth/google/callback?token={urllib.parse.quote(tokens['access_token'])}&refresh={urllib.parse.quote(tokens['refresh_token'])}"
    
    return RedirectResponse(url=frontend_url)


@router.post("/login/form")
async def login_form(form_data: OAuth2PasswordRequestForm = Depends(), db=Depends(get_db)):
    """
    OAuth2 compatible login endpoint (for Swagger UI).
    
    - **username**: Email address (OAuth2 standard uses username field)
    - **password**: User's password
    
    Returns access_token in body, refresh_token in HttpOnly cookie.
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
    
    from fastapi.responses import JSONResponse
    response = JSONResponse(content={
        "access_token": tokens["access_token"],
        "token_type": "bearer",
    })
    
    refresh_cookie_max_age = 60 * 60 * 24 * settings.REFRESH_TOKEN_EXPIRE_DAYS
    
    is_local = settings.DEBUG or "localhost" in settings.FRONTEND_URL
    
    response.set_cookie(
        key="refresh_token",
        value=tokens["refresh_token"],
        httponly=True,
        secure=not is_local,
        samesite="lax",
        max_age=refresh_cookie_max_age,
        path="/api/v1/auth",
    )
    
    return response


@router.post("/refresh")
async def refresh_token(request: Request, db=Depends(get_db)):
    """
    Refresh access token using refresh token from HttpOnly cookie.
    """
    refresh_token = request.cookies.get("refresh_token")
    
    if not refresh_token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="no_refresh_token"
        )
    
    tokens, error = await AuthService.refresh_token(db, refresh_token)
    
    if error:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=error
        )
    
    from fastapi.responses import JSONResponse
    response = JSONResponse(content={
        "access_token": tokens["access_token"],
        "token_type": "bearer",
    })
    
    refresh_cookie_max_age = 60 * 60 * 24 * settings.REFRESH_TOKEN_EXPIRE_DAYS
    
    is_local = settings.DEBUG or "localhost" in settings.FRONTEND_URL
    
    response.set_cookie(
        key="refresh_token",
        value=tokens["refresh_token"],
        httponly=True,
        secure=not is_local,
        samesite="lax",
        max_age=refresh_cookie_max_age,
        path="/api/v1/auth",
    )
    
    return response


@router.post("/logout")
async def logout(
    request: Request,
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """
    Logout user (invalidate session).
    
    Requires valid access token in header.
    Clears the refresh token cookie.
    """
    refresh_token = request.cookies.get("refresh_token")
    
    if refresh_token:
        await AuthService.logout(db, refresh_token)
    
    from fastapi.responses import JSONResponse
    response = JSONResponse(content={"logged_out": True})
    response.delete_cookie("refresh_token", path="/api/v1/auth")
    
    return response


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
