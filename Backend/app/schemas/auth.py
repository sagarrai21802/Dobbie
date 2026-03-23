from pydantic import BaseModel, Field, EmailStr
from typing import Optional
from datetime import datetime


class UserRegister(BaseModel):
    email: EmailStr = Field(..., description="User email address")
    password: str = Field(
        ...,
        min_length=8,
        max_length=100,
        description="Password (min 8 chars, at least 1 uppercase, 1 number)"
    )
    full_name: str = Field(
        ...,
        min_length=2,
        max_length=100,
        description="User full name"
    )


class UserLogin(BaseModel):
    email: EmailStr = Field(..., description="User email address")
    password: str = Field(..., description="User password")


class GoogleLogin(BaseModel):
    id_token: str = Field(..., description="Google ID token from flutter_signin_google")


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int


class TokenRefresh(BaseModel):
    refresh_token: str


class UserResponse(BaseModel):
    id: str
    email: str
    full_name: str
    is_active: bool
    profile: Optional[dict] = None
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class UserUpdate(BaseModel):
    full_name: Optional[str] = Field(None, min_length=2, max_length=100)


class MessageResponse(BaseModel):
    message: str
