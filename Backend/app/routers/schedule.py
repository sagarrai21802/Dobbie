from datetime import datetime, timedelta
from bson import ObjectId
from fastapi import APIRouter, Depends, HTTPException, status
from typing import List

from app.database import get_db
from app.utils.dependencies import get_current_user, check_subscription
from app.models.scheduling import (
    create_calendar_document,
    create_calendar_entry_document,
    get_platform_best_times,
)

router = APIRouter(prefix="/schedule", tags=["schedule"])


def _get_tomorrow_date() -> str:
    """Get tomorrow's date in YYYY-MM-DD format."""
    tomorrow = datetime.now() + timedelta(days=1)
    return tomorrow.strftime("%Y-%m-%d")


@router.post("/create")
async def create_schedule(
    platform: str = "linkedin",
    duration_days: int = 7,
    topics: List[str] = [],
    auto_post: bool = False,
    current_user: dict = Depends(check_subscription),
    db=Depends(get_db)
):
    """
    Create a new schedule with calendar entries.
    
    Auth required + subscription required.
    """
    if not topics:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="At least one topic is required"
        )
    
    if duration_days not in [7, 30]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Duration must be 7 or 30 days"
        )
    
    if platform not in ["linkedin", "pinterest", "youtube", "twitter"]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid platform"
        )
    
    user_id = str(current_user["_id"])
    
    # Get best posting times for platform
    posting_times = get_platform_best_times(platform)
    
    # Create scheduled calendar document
    calendar_doc = create_calendar_document(
        user_id=user_id,
        platform=platform,
        duration_days=duration_days,
        auto_post=auto_post,
        posting_times=posting_times
    )
    
    # Insert calendar and get ID
    calendar_result = await db.scheduled_calendars.insert_one(calendar_doc)
    calendar_id = str(calendar_result.inserted_id)
    
    # Generate entries for each day
    entries = []
    tomorrow = datetime.now() + timedelta(days=1)
    
    for day_offset in range(duration_days):
        # Calculate scheduled date
        scheduled_date = (tomorrow + timedelta(days=day_offset)).strftime("%Y-%m-%d")
        
        # Rotate through posting times
        scheduled_time = posting_times[day_offset % len(posting_times)]
        
        # Rotate through topics
        topic = topics[day_offset % len(topics)]
        
        # Create entry document
        entry_doc = create_calendar_entry_document(
            calendar_id=calendar_id,
            user_id=user_id,
            scheduled_date=scheduled_date,
            scheduled_time=scheduled_time,
            topic=topic,
            platform=platform
        )
        
        # Insert entry
        entry_result = await db.calendar_entries.insert_one(entry_doc)
        
        entries.append({
            "id": str(entry_result.inserted_id),
            "calendar_id": calendar_id,
            "user_id": user_id,
            "scheduled_date": scheduled_date,
            "scheduled_time": scheduled_time,
            "topic": topic,
            "platform": platform,
            "status": "pending",
            "notification_sent": False,
        })
    
    return {
        "calendar_id": calendar_id,
        "entries": entries,
    }


@router.get("/calendar")
async def get_calendar(
    current_user: dict = Depends(check_subscription),
    db=Depends(get_db)
):
    """
    Get all calendar entries for the current user.
    
    Auth required + subscription required.
    """
    user_id = str(current_user["_id"])
    
    # Get all calendars for user
    calendars = await db.scheduled_calendars.find({"user_id": user_id}).to_list(None)
    
    # Get all entries for user
    entries = await db.calendar_entries.find(
        {"user_id": user_id}
    ).sort("scheduled_date", 1).to_list(None)
    
    # Format calendars
    calendar_list = []
    for cal in calendars:
        calendar_list.append({
            "id": str(cal["_id"]),
            "platform": cal["platform"],
            "duration_days": cal["duration_days"],
            "auto_post": cal.get("auto_post", False),
            "status": cal.get("status", "active"),
            "created_at": cal["created_at"].isoformat() if cal.get("created_at") else None,
        })
    
    # Format entries
    entry_list = []
    for entry in entries:
        entry_list.append({
            "id": str(entry["_id"]),
            "calendar_id": entry["calendar_id"],
            "user_id": entry["user_id"],
            "scheduled_date": entry["scheduled_date"],
            "scheduled_time": entry["scheduled_time"],
            "topic": entry["topic"],
            "platform": entry["platform"],
            "status": entry["status"],
            "notification_sent": entry.get("notification_sent", False),
            "notified_at": entry["notified_at"].isoformat() if entry.get("notified_at") else None,
            "posted_at": entry["posted_at"].isoformat() if entry.get("posted_at") else None,
            "content_draft": entry.get("content_draft"),
            "image_url": entry.get("image_url"),
        })
    
    return {
        "calendars": calendar_list,
        "entries": entry_list,
    }


@router.get("/calendar/{entry_id}/approve")
async def approve_entry(
    entry_id: str,
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """
    Approve a calendar entry for posting.
    
    Auth required (any user, not just pro).
    """
    user_id = str(current_user["_id"])
    
    try:
        entry_object_id = ObjectId(entry_id)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid entry ID"
        )
    
    # Find and update entry
    result = await db.calendar_entries.update_one(
        {"_id": entry_object_id, "user_id": user_id},
        {"$set": {"status": "approved"}}
    )
    
    if result.modified_count == 0:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Entry not found"
        )
    
    return {"status": "approved"}


@router.get("/calendar/{entry_id}/deny")
async def deny_entry(
    entry_id: str,
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """
    Deny a calendar entry.
    
    Auth required (any user, not just pro).
    """
    user_id = str(current_user["_id"])
    
    try:
        entry_object_id = ObjectId(entry_id)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid entry ID"
        )
    
    # Find and update entry
    result = await db.calendar_entries.update_one(
        {"_id": entry_object_id, "user_id": user_id},
        {"$set": {"status": "denied"}}
    )
    
    if result.modified_count == 0:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Entry not found"
        )
    
    return {"status": "denied"}