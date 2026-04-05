"""
Background scheduler for scheduled posting tasks.
- Nightly notification job (runs at 21:00 IST to notify for next day's posts)
- Posting job (runs every 5 minutes to check for due posts)
"""

import logging
from datetime import datetime, timedelta
from zoneinfo import ZoneInfo

from apscheduler.schedulers.asyncio import AsyncIOScheduler

logger = logging.getLogger(__name__)

# Global scheduler instance
scheduler: AsyncIOScheduler = None


def create_scheduler() -> AsyncIOScheduler:
    """Create and configure the APScheduler."""
    scheduler = AsyncIOScheduler()
    
    # Add nightly notification job - runs daily at 21:00 IST
    scheduler.add_job(
        nightly_notification_job,
        trigger="cron",
        hour=21,
        minute=0,
        timezone=ZoneInfo("Asia/Kolkata"),
        id="nightly_notification",
        name="Send notifications for next day's posts",
        replace_existing=True,
    )
    
    # Add posting job - runs every 5 minutes
    scheduler.add_job(
        posting_job,
        trigger="interval",
        minutes=5,
        id="posting_job",
        name="Check and post scheduled content",
        replace_existing=True,
    )
    
    logger.info("Scheduler configured with jobs: nightly_notification (21:00 IST), posting_job (every 5 min)")
    
    return scheduler


async def nightly_notification_job():
    """
    Job that runs nightly to send push notifications for next day's pending posts.
    
    Logic:
    1. Calculate tomorrow's date in Asia/Kolkata timezone
    2. Find all calendar entries where:
       - scheduled_date == tomorrow
       - status == "pending"
       - notification_sent == False
    3. For each entry:
       - Get user's FCM token from user_preferences
       - Send push notification
       - Update entry: notification_sent = True, notified_at = now()
    """
    from app.database import get_db
    from app.services.notifications import send_push_notification
    from bson import ObjectId
    
    logger.info("Starting nightly notification job")
    
    try:
        # Get DB from app state - we'll need to get it from the FastAPI app
        # For now, import directly (will be refactored)
        from app.main import app
        
        db = app.state.db if hasattr(app.state, 'db') else None
        if db is None:
            logger.error("Database not available")
            return
        
        # Calculate tomorrow's date
        tomorrow = datetime.now(ZoneInfo("Asia/Kolkata")) + timedelta(days=1)
        tomorrow_date = tomorrow.strftime("%Y-%m-%d")
        
        logger.info(f"Looking for entries on {tomorrow_date}")
        
        # Find pending entries for tomorrow
        pending_entries = await db.calendar_entries.find({
            "scheduled_date": tomorrow_date,
            "status": "pending",
            "notification_sent": False,
        }).to_list(None)
        
        logger.info(f"Found {len(pending_entries)} pending entries to notify about")
        
        for entry in pending_entries:
            try:
                user_id = entry["user_id"]
                
                # Get user's FCM token
                user_prefs = await db.user_preferences.find_one({"user_id": user_id})
                fcm_token = user_prefs.get("notification_token") if user_prefs else None
                
                if not fcm_token:
                    logger.warning(f"No FCM token for user {user_id}, skipping notification")
                    continue
                
                # Send notification
                platform_name = entry["platform"].capitalize()
                title = "Ready to post tomorrow?"
                body = f"Topic: {entry['topic']} on {platform_name} at {entry['scheduled_time']}"
                data = {
                    "entry_id": str(entry["_id"]),
                    "action": "schedule_approval",
                }
                
                success = send_push_notification(fcm_token, title, body, data)
                
                if success:
                    # Update entry
                    await db.calendar_entries.update_one(
                        {"_id": entry["_id"]},
                        {"$set": {
                            "notification_sent": True,
                            "notified_at": datetime.now(ZoneInfo("Asia/Kolkata")),
                        }}
                    )
                    logger.info(f"Notified user for entry {entry['_id']}")
                else:
                    logger.warning(f"Failed to send notification for entry {entry['_id']}")
                    
            except Exception as e:
                logger.error(f"Error processing notification for entry {entry.get('_id')}: {e}")
                
    except Exception as e:
        logger.error(f"Nightly notification job failed: {e}")


async def posting_job():
    """
    Job that runs every 5 minutes to check and post scheduled content.
    
    Logic:
    1. Get current time in Asia/Kolkata timezone
    2. Find entries where:
       - scheduled_date == today
       - scheduled_time is within 5-minute window (now - 5min to now + 5min)
       - status IN ["approved", "pending"]
    3. For each entry:
       - Check parent calendar's auto_post flag
       - If auto_post is True OR entry.status == "approved":
         * Post to platform
         * Update status to "posted" or "failed"
    """
    from app.database import get_db
    from app.services.platform_poster import post_to_linkedin, post_to_pinterest, post_to_youtube
    from bson import ObjectId
    
    logger.info("Starting posting job")
    
    try:
        from app.main import app
        
        db = app.state.db if hasattr(app.state, 'db') else None
        if db is None:
            logger.error("Database not available")
            return
        
        # Get current time
        now = datetime.now(ZoneInfo("Asia/Kolkata"))
        today = now.strftime("%Y-%m-%d")
        
        # Calculate time window (5 minutes before and after)
        time_window_start = (now - timedelta(minutes=5)).strftime("%H:%M")
        time_window_end = (now + timedelta(minutes=5)).strftime("%H:%M")
        
        logger.info(f"Checking for posts due between {time_window_start} and {time_window_end} on {today}")
        
        # Find entries due for posting (status: approved OR pending)
        due_entries = await db.calendar_entries.find({
            "scheduled_date": today,
            "scheduled_time": {"$gte": time_window_start, "$lte": time_window_end},
            "status": {"$in": ["approved", "pending"]},
        }).to_list(None)
        
        logger.info(f"Found {len(due_entries)} entries due for posting")
        
        for entry in due_entries:
            try:
                user_id = entry["user_id"]
                platform = entry["platform"]
                topic = entry["topic"]
                
                # Get parent calendar to check auto_post flag
                calendar = await db.scheduled_calendars.find_one({
                    "_id": ObjectId(entry["calendar_id"])
                })
                
                auto_post = calendar.get("auto_post", False) if calendar else False
                entry_status = entry["status"]
                
                # Only post if auto_post is enabled OR entry is approved
                if auto_post or entry_status == "approved":
                    # Generate content
                    content = f"🔥 Trending today: {topic}\n\n[Auto-posted by your scheduler]\n\n#trending #{platform}"
                    
                    # Post to platform
                    success = False
                    if platform == "linkedin":
                        success = await post_to_linkedin(user_id, content)
                    elif platform == "pinterest":
                        success = await post_to_pinterest(user_id, content, None)
                    elif platform == "youtube":
                        success = await post_to_youtube(user_id, content)
                    else:
                        logger.warning(f"Unknown platform: {platform}")
                        success = False
                    
                    # Update entry status
                    if success:
                        await db.calendar_entries.update_one(
                            {"_id": entry["_id"]},
                            {"$set": {
                                "status": "posted",
                                "posted_at": datetime.now(ZoneInfo("Asia/Kolkata")),
                            }}
                        )
                        logger.info(f"Successfully posted entry {entry['_id']}")
                    else:
                        await db.calendar_entries.update_one(
                            {"_id": entry["_id"]},
                            {"$set": {
                                "status": "failed",
                            }}
                        )
                        logger.warning(f"Failed to post entry {entry['_id']}")
                else:
                    logger.info(f"Skipping entry {entry['_id']} - not auto_post and not approved")
                    
            except Exception as e:
                logger.error(f"Error processing entry {entry.get('_id')}: {e}")
                
    except Exception as e:
        logger.error(f"Posting job failed: {e}")


def start_scheduler():
    """Start the background scheduler."""
    global scheduler
    if scheduler is None:
        scheduler = create_scheduler()
    scheduler.start()
    logger.info("Background scheduler started")


def stop_scheduler():
    """Stop the background scheduler."""
    global scheduler
    if scheduler is not None:
        scheduler.shutdown()
        logger.info("Background scheduler stopped")