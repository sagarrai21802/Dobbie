"""
Firebase Cloud Messaging (FCM) notification service.
"""

import logging
from typing import Optional

logger = logging.getLogger(__name__)

# Firebase admin SDK - initialized lazily
_firebase_app = None


def _initialize_firebase():
    """Initialize Firebase Admin SDK if credentials are available."""
    global _firebase_app
    
    if _firebase_app is not None:
        return _firebase_app
    
    from app.config import settings
    
    cred_path = settings.FIREBASE_CREDENTIALS_PATH or settings.GOOGLE_APPLICATION_CREDENTIALS
    
    if not cred_path:
        logger.warning("Firebase credentials not configured. Push notifications disabled.")
        return None
    
    try:
        import firebase_admin
        from firebase_admin import credentials
        
        # Try to load from path
        try:
            cred = credentials.Certificate(cred_path)
            _firebase_app = firebase_admin.initialize_app(cred)
            logger.info("Firebase Admin SDK initialized successfully")
            return _firebase_app
        except Exception as e:
            # If file doesn't exist, maybe it's JSON content in env var
            logger.warning(f"Failed to load Firebase credentials from {cred_path}: {e}")
            return None
            
    except ImportError:
        logger.warning("firebase-admin package not installed. Push notifications disabled.")
        return None
    except Exception as e:
        logger.error(f"Failed to initialize Firebase: {e}")
        return None


def send_push_notification(
    token: str,
    title: str,
    body: str,
    data: Optional[dict] = None
) -> bool:
    """
    Send a push notification to a specific device.
    
    Args:
        token: FCM device token
        title: Notification title
        body: Notification body
        data: Optional data payload
    
    Returns:
        True if sent successfully, False otherwise
    """
    if not token:
        logger.warning("No FCM token provided")
        return False
    
    # Initialize Firebase if not already done
    app = _initialize_firebase()
    
    if app is None:
        logger.warning("Firebase not initialized. Notification not sent.")
        return False
    
    try:
        from firebase_admin import messaging
        
        # Build message
        message = messaging.Message(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            data=data or {},
            token=token,
        )
        
        # Send
        response = messaging.send(message)
        logger.info(f"Push notification sent successfully: {response}")
        return True
        
    except Exception as e:
        logger.error(f"Failed to send push notification: {e}")
        return False


def send_multicast_notification(
    tokens: list[str],
    title: str,
    body: str,
    data: Optional[dict] = None
) -> int:
    """
    Send a push notification to multiple devices.
    
    Args:
        tokens: List of FCM device tokens
        title: Notification title
        body: Notification body
        data: Optional data payload
    
    Returns:
        Number of successful deliveries
    """
    if not tokens:
        return 0
    
    app = _initialize_firebase()
    
    if app is None:
        return 0
    
    try:
        from firebase_admin import messaging
        
        message = messaging.MulticastMessage(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            data=data or {},
            tokens=tokens,
        )
        
        response = messaging.send_multicast(message)
        logger.info(f"Multicast: {response.success_count} successful, {response.failure_count} failed")
        return response.success_count
        
    except Exception as e:
        logger.error(f"Failed to send multicast notification: {e}")
        return 0