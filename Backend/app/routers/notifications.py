"""
Notifications router for FCM token registration.
"""

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel

from app.database import get_db
from app.utils.dependencies import get_current_user

router = APIRouter(prefix="/notifications", tags=["notifications"])


class RegisterTokenRequest(BaseModel):
    token: str


class RegisterTokenResponse(BaseModel):
    registered: bool


@router.post("/register-token", response_model=RegisterTokenResponse)
async def register_fcm_token(
    request: RegisterTokenRequest,
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """
    Register user's FCM push notification token.
    
    Auth required. The token is stored in user_preferences collection.
    """
    user_id = str(current_user["_id"])
    fcm_token = request.token
    
    if not fcm_token:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Token is required"
        )
    
    # Upsert user preferences with FCM token
    await db.user_preferences.update_one(
        {"user_id": user_id},
        {
            "$set": {
                "notification_token": fcm_token,
                "updated_at": datetime.now(),
            }
        },
        upsert=True
    )
    
    return RegisterTokenResponse(registered=True)


from datetime import datetime