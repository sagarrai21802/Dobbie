from datetime import datetime, timedelta, timezone
from fastapi import APIRouter, Depends, HTTPException, status
from bson import ObjectId

from app.database import get_db
from app.utils.dependencies import get_current_user

router = APIRouter(prefix="/subscription", tags=["subscription"])


async def check_subscription(current_user: dict = Depends(get_current_user)) -> dict:
    """
    Dependency to check if user has an active pro subscription.
    Raises 403 if subscription is not active.
    """
    subscription = current_user.get("subscription", {})
    sub_status = subscription.get("status", "free")
    expires_at = subscription.get("expires_at")
    
    # Check if user has pro status
    if sub_status != "pro":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="subscription_required"
        )
    
    # Check if subscription has expired
    if expires_at is not None:
        if isinstance(expires_at, str):
            expires_at = datetime.fromisoformat(expires_at.replace("Z", "+00:00"))
        
        if expires_at.tzinfo is None:
            expires_at = expires_at.replace(tzinfo=timezone.utc)
        
        if expires_at < datetime.now(timezone.utc):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="subscription_expired"
            )
    
    return current_user


@router.post("/activate")
async def activate_subscription(
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """
    Activate a pro subscription for the current user.
    Default: 30-day pro plan.
    """
    # Calculate expiry date (30 days from now)
    now = datetime.now(timezone.utc)
    expires_at = now + timedelta(days=30)
    
    # Update user subscription
    result = await db.users.update_one(
        {"_id": current_user["_id"]},
        {
            "$set": {
                "subscription": {
                    "status": "pro",
                    "started_at": now,
                    "expires_at": expires_at,
                },
                "updated_at": now,
            }
        }
    )
    
    if result.modified_count == 0:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to activate subscription"
        )
    
    return {
        "status": "activated",
        "started_at": now.isoformat(),
        "expires_at": expires_at.isoformat(),
    }


@router.get("/status")
async def get_subscription_status(
    current_user: dict = Depends(get_current_user)
):
    """
    Get the current user's subscription status.
    """
    subscription = current_user.get("subscription", {})
    sub_status = subscription.get("status", "free")
    started_at = subscription.get("started_at")
    expires_at = subscription.get("expires_at")
    
    # Convert datetime to ISO string
    started_at_iso = None
    expires_at_iso = None
    
    if started_at:
        if isinstance(started_at, datetime):
            started_at_iso = started_at.isoformat()
        else:
            started_at_iso = str(started_at)
    
    if expires_at:
        if isinstance(expires_at, datetime):
            expires_at_iso = expires_at.isoformat()
        else:
            expires_at_iso = str(expires_at)
    
    return {
        "subscription_status": sub_status,
        "started_at": started_at_iso,
        "expires_at": expires_at_iso,
    }
