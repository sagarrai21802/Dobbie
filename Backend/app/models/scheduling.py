from datetime import datetime
from typing import Optional, List
from pydantic import BaseModel


# ============================================
# Pydantic Schemas (Request/Response Models)
# ============================================

class ScheduledCalendarCreate(BaseModel):
    platform: str  # "linkedin" | "pinterest" | "youtube" | "twitter"
    duration_days: int  # 7 or 30
    topics: List[str]
    auto_post: bool = False


class CalendarEntryCreate(BaseModel):
    calendar_id: str
    user_id: str
    scheduled_date: str  # "YYYY-MM-DD"
    scheduled_time: str  # "HH:MM"
    topic: str
    platform: str
    status: str = "pending"  # "pending" | "approved" | "denied" | "posted" | "failed"
    notification_sent: bool = False
    notified_at: Optional[datetime] = None
    posted_at: Optional[datetime] = None
    content_draft: Optional[str] = None
    image_url: Optional[str] = None


class UserPreferencesUpdate(BaseModel):
    preferred_topics: Optional[List[str]] = None
    preferred_platforms: Optional[List[str]] = None
    timezone: Optional[str] = "Asia/Kolkata"
    notification_token: Optional[str] = None


# ============================================
# Response Schemas
# ============================================

class ScheduledCalendarResponse(BaseModel):
    id: str
    user_id: str
    platform: str
    created_at: datetime
    duration_days: int
    auto_post: bool
    status: str  # "active" | "paused" | "completed"
    posting_times: List[str]


class CalendarEntryResponse(BaseModel):
    id: str
    calendar_id: str
    user_id: str
    scheduled_date: str
    scheduled_time: str
    topic: str
    platform: str
    status: str
    notification_sent: bool
    notified_at: Optional[datetime] = None
    posted_at: Optional[datetime] = None
    content_draft: Optional[str] = None
    image_url: Optional[str] = None


class UserPreferencesResponse(BaseModel):
    user_id: str
    preferred_topics: List[str]
    preferred_platforms: List[str]
    timezone: str
    notification_token: Optional[str] = None


# ============================================
# MongoDB Document Helpers
# ============================================

def create_calendar_document(
    user_id: str,
    platform: str,
    duration_days: int,
    auto_post: bool,
    posting_times: List[str]
) -> dict:
    """Create a scheduled_calendars document."""
    now = datetime.utcnow()
    return {
        "user_id": user_id,
        "platform": platform,
        "created_at": now,
        "duration_days": duration_days,
        "auto_post": auto_post,
        "status": "active",
        "posting_times": posting_times,
    }


def create_calendar_entry_document(
    calendar_id: str,
    user_id: str,
    scheduled_date: str,
    scheduled_time: str,
    topic: str,
    platform: str,
) -> dict:
    """Create a calendar_entries document."""
    return {
        "calendar_id": calendar_id,
        "user_id": user_id,
        "scheduled_date": scheduled_date,
        "scheduled_time": scheduled_time,
        "topic": topic,
        "platform": platform,
        "status": "pending",
        "notification_sent": False,
        "notified_at": None,
        "posted_at": None,
        "content_draft": None,
        "image_url": None,
    }


def create_user_preferences_document(user_id: str) -> dict:
    """Create a user_preferences document with defaults."""
    return {
        "user_id": user_id,
        "preferred_topics": [],
        "preferred_platforms": [],
        "timezone": "Asia/Kolkata",
        "notification_token": None,
    }


# ============================================
# Best Posting Times Configuration
# ============================================

BEST_POSTING_TIMES = {
    "linkedin": ["08:00", "12:00", "17:00", "18:00"],
    "pinterest": ["20:00", "21:00", "14:00", "15:00"],
    "youtube": ["15:00", "16:00", "20:00"],
    "twitter": ["09:00", "12:00", "15:00", "18:00"],
}


def get_platform_best_times(platform: str) -> List[str]:
    """Get best posting times for a platform."""
    return BEST_POSTING_TIMES.get(platform, ["12:00"])