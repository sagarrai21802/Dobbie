import logging
from datetime import datetime, timedelta, timezone
from fastapi import APIRouter, HTTPException, Depends, Query
from fastapi.responses import JSONResponse, RedirectResponse
from pydantic import BaseModel
from typing import Optional
from bson import ObjectId
from urllib.parse import quote

from app.database import get_db
from app.config import settings
from app.services.linkedin_service import linkedin_service, LinkedInAPIError
from app.services.freepik_service import (
    freepik_service,
    FreepikConfigurationError,
    FreepikRateLimitError,
    FreepikTimeoutError,
    FreepikTaskFailedError,
    FreepikServiceError,
)
from app.utils.dependencies import get_current_user
from app.utils.security import create_oauth_state, verify_oauth_state

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/auth/linkedin", tags=["LinkedIn"])


class PostLinkedInRequest(BaseModel):
    content: str
    image_url: Optional[str] = None
    image_status: Optional[str] = None


class GenerateLinkedInImageRequest(BaseModel):
    content: str


class GenerateLinkedInImageResponse(BaseModel):
    image_url: Optional[str] = None
    image_status: str


class PostLinkedInResponse(BaseModel):
    success: bool
    post_id: Optional[str] = None
    image_url: Optional[str] = None
    image_status: str


class AuthorizeResponse(BaseModel):
    authorization_url: str


class StatusResponse(BaseModel):
    connected: bool
    linkedin_user_id: Optional[str] = None


class CallbackResponse(BaseModel):
    message: str
    connected: bool


LINKEDIN_EXPIRY_BUFFER_SECONDS = 120


def _build_profile_image_context(profile: Optional[dict]) -> str:
    if not isinstance(profile, dict):
        return ""

    chunks = []
    role = str(profile.get("current_role", "")).strip()
    industry = str(profile.get("industry", "")).strip()
    tone = str(profile.get("preferred_tone", "")).strip()
    headline = str(profile.get("headline", "")).strip()
    skills = profile.get("skills") or []

    if role:
        chunks.append(f"- Role: {role}")
    if industry:
        chunks.append(f"- Industry: {industry}")
    if headline:
        chunks.append(f"- Headline: {headline}")
    if tone:
        chunks.append(f"- Tone: {tone}")
    if isinstance(skills, list):
        clean_skills = [str(item).strip() for item in skills if str(item).strip()]
        if clean_skills:
            chunks.append(f"- Skills: {', '.join(clean_skills[:8])}")

    if not chunks:
        return ""

    return "\n".join([
        "Personalization context for visual direction:",
        *chunks,
        "Use this context only to improve relevance.",
    ])


def _build_app_redirect_url(status: str, message: Optional[str] = None) -> str:
    url = f"{settings.LINKEDIN_APP_REDIRECT_URL}?status={quote(status)}"
    if message:
        url = f"{url}&message={quote(message)}"
    return url


def _is_token_expired(expires_at: Optional[datetime]) -> bool:
    if expires_at is None:
        return True
    if expires_at.tzinfo is None:
        expires_at = expires_at.replace(tzinfo=timezone.utc)
    now = datetime.now(timezone.utc)
    return now >= (expires_at - timedelta(seconds=LINKEDIN_EXPIRY_BUFFER_SECONDS))


async def _disconnect_linkedin_account(db, user_id: ObjectId) -> None:
    await db.users.update_one(
        {"_id": user_id},
        {
            "$set": {"linkedin_connected": False},
            "$unset": {
                "linkedin_access_token": "",
                "linkedin_refresh_token": "",
                "linkedin_access_token_expires_at": "",
                "linkedin_refresh_token_expires_at": "",
                "linkedin_user_id": "",
                "linkedin_person_urn": "",
                "linkedin_profile": "",
            },
        },
    )


async def _ensure_valid_linkedin_access_token(current_user: dict, db) -> str:
    access_token = current_user.get("linkedin_access_token")
    refresh_token = current_user.get("linkedin_refresh_token")
    expires_at = current_user.get("linkedin_access_token_expires_at")
    refresh_token_expires_at = current_user.get("linkedin_refresh_token_expires_at")
    user_id = current_user["_id"]

    if access_token and not _is_token_expired(expires_at):
        return access_token

    if not refresh_token:
        await _disconnect_linkedin_account(db, user_id)
        raise HTTPException(
            status_code=401,
            detail="LinkedIn authorization expired. Please reconnect LinkedIn.",
        )

    if refresh_token_expires_at and _is_token_expired(refresh_token_expires_at):
        await _disconnect_linkedin_account(db, user_id)
        raise HTTPException(
            status_code=401,
            detail="LinkedIn refresh token expired. Please reconnect LinkedIn.",
        )

    try:
        token_data = await linkedin_service.refresh_access_token(refresh_token)
    except LinkedInAPIError as e:
        await _disconnect_linkedin_account(db, user_id)
        raise HTTPException(
            status_code=401,
            detail=f"LinkedIn authorization refresh failed: {str(e)}",
        )

    new_access_token = token_data.get("access_token")
    if not new_access_token:
        await _disconnect_linkedin_account(db, user_id)
        raise HTTPException(
            status_code=401,
            detail="LinkedIn refresh returned no access token. Please reconnect LinkedIn.",
        )

    expires_in = int(token_data.get("expires_in", 0) or 0)
    now = datetime.now(timezone.utc)
    new_expires_at = (
        now + timedelta(seconds=expires_in)
        if expires_in > 0
        else now + timedelta(minutes=55)
    )
    new_refresh_token = token_data.get("refresh_token") or refresh_token
    refresh_expires_in = int(token_data.get("refresh_token_expires_in", 0) or 0)
    new_refresh_expires_at = (
        now + timedelta(seconds=refresh_expires_in)
        if refresh_expires_in > 0
        else refresh_token_expires_at
    )

    await db.users.update_one(
        {"_id": user_id},
        {
            "$set": {
                "linkedin_access_token": new_access_token,
                "linkedin_refresh_token": new_refresh_token,
                "linkedin_access_token_expires_at": new_expires_at,
                "linkedin_refresh_token_expires_at": new_refresh_expires_at,
                "linkedin_connected": True,
            }
        },
    )

    current_user["linkedin_access_token"] = new_access_token
    current_user["linkedin_refresh_token"] = new_refresh_token
    current_user["linkedin_access_token_expires_at"] = new_expires_at
    current_user["linkedin_refresh_token_expires_at"] = new_refresh_expires_at
    current_user["linkedin_connected"] = True
    return new_access_token


@router.get("/authorize", response_model=AuthorizeResponse)
async def authorize_linkedin(current_user: dict = Depends(get_current_user)):
    try:
        user_id = str(current_user["_id"])
        state = create_oauth_state(user_id)
        auth_url = linkedin_service.get_authorization_url(state=state)
        return AuthorizeResponse(authorization_url=auth_url)
    except Exception as e:
        logger.error(f"Failed to get authorization URL: {str(e)}")
        raise HTTPException(status_code=500, detail="Failed to get authorization URL")


@router.get("/callback")
async def linkedin_callback(
    code: Optional[str] = Query(None),
    state: Optional[str] = Query(None),
    error: Optional[str] = Query(None),
    error_description: Optional[str] = Query(None),
    db=Depends(get_db)
):
    if error:
        message = error_description or error
        logger.warning(f"LinkedIn callback error: {error} ({message})")
        return RedirectResponse(url=_build_app_redirect_url("error", message))

    if not code:
        logger.warning("LinkedIn callback missing authorization code")
        return JSONResponse(status_code=400, content={"detail": "Missing authorization code"})

    if not state:
        logger.warning("LinkedIn callback missing state parameter")
        raise HTTPException(status_code=400, detail="Missing state parameter")

    user_id = verify_oauth_state(state)
    if not user_id:
        logger.warning(f"LinkedIn callback invalid or tampered state: {state[:20]}...")
        raise HTTPException(status_code=401, detail="Invalid or tampered state")

    try:
        token_data = await linkedin_service.exchange_code_for_token(code)
    except Exception as e:
        logger.error(f"LinkedIn token exchange failed: {str(e)}")
        raise HTTPException(status_code=502, detail="LinkedIn token exchange failed")

    access_token = token_data.get("access_token")
    if not access_token:
        logger.error("No access token in LinkedIn response")
        raise HTTPException(status_code=502, detail="No access token received from LinkedIn")

    try:
        profile = await linkedin_service.get_user_profile(access_token)
    except Exception as e:
        logger.error(f"Failed to get LinkedIn profile: {str(e)}")
        raise HTTPException(status_code=502, detail="Failed to get LinkedIn profile")

    linkedin_user_id = profile.get("sub")
    if not linkedin_user_id:
        logger.error("No LinkedIn user ID in profile response")
        raise HTTPException(status_code=502, detail="No LinkedIn user ID in profile")

    try:
        expires_in = int(token_data.get("expires_in", 0) or 0)
        result = await db.users.update_one(
            {"_id": ObjectId(user_id)},
            {
                "$set": {
                    "linkedin_access_token": access_token,
                    "linkedin_refresh_token": token_data.get("refresh_token"),
                    "linkedin_access_token_expires_at": (
                        datetime.now(timezone.utc) + timedelta(seconds=expires_in)
                        if expires_in > 0
                        else None
                    ),
                    "linkedin_refresh_token_expires_at": (
                        datetime.now(timezone.utc) + timedelta(
                            seconds=int(token_data.get("refresh_token_expires_in", 0) or 0)
                        )
                        if int(token_data.get("refresh_token_expires_in", 0) or 0) > 0
                        else None
                    ),
                    "linkedin_user_id": linkedin_user_id,
                    "linkedin_person_urn": linkedin_service.build_person_urn(linkedin_user_id),
                    "linkedin_connected": True,
                    "linkedin_profile": profile,
                }
            }
        )
        if result.matched_count == 0:
            logger.error(f"User not found for LinkedIn binding: {user_id}")
            raise HTTPException(status_code=404, detail="User not found")
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to save LinkedIn credentials: {str(e)}")
        raise HTTPException(status_code=500, detail="Failed to save LinkedIn credentials")

    logger.info(f"LinkedIn connected successfully for user: {user_id}")
    return RedirectResponse(url=_build_app_redirect_url("success"))


@router.get("/status", response_model=StatusResponse)
async def get_linkedin_status(current_user: dict = Depends(get_current_user)):
    linkedin_connected = current_user.get("linkedin_connected", False)
    linkedin_user_id = current_user.get("linkedin_user_id")

    return StatusResponse(
        connected=linkedin_connected,
        linkedin_user_id=linkedin_user_id,
    )


@router.post("/generate-image", response_model=GenerateLinkedInImageResponse)
async def generate_linkedin_image(
    request: GenerateLinkedInImageRequest,
    current_user: dict = Depends(get_current_user),
):
    if not request.content or not request.content.strip():
        raise HTTPException(status_code=400, detail="Post content is required")

    try:
        profile_context = _build_profile_image_context(current_user.get("profile"))
        prompt = request.content
        if profile_context:
            prompt = f"{request.content}\n\n{profile_context}"

        image_url = await freepik_service.generate_image_from_post_text(prompt)
        if image_url:
            return GenerateLinkedInImageResponse(
                image_url=image_url,
                image_status="generated",
            )

        return GenerateLinkedInImageResponse(
            image_url=None,
            image_status="skipped_failed",
        )
    except FreepikRateLimitError as e:
        logger.warning(f"Freepik generation skipped due to rate limit/quota: {str(e)}")
        return GenerateLinkedInImageResponse(
            image_url=None,
            image_status="skipped_rate_limited",
        )
    except FreepikTimeoutError as e:
        logger.warning(f"Freepik generation timed out: {str(e)}")
        return GenerateLinkedInImageResponse(
            image_url=None,
            image_status="skipped_timeout",
        )
    except (FreepikTaskFailedError, FreepikConfigurationError, FreepikServiceError) as e:
        logger.warning(f"Freepik generation failed and will be skipped: {str(e)}")
        return GenerateLinkedInImageResponse(
            image_url=None,
            image_status="skipped_failed",
        )


@router.post("/post", response_model=PostLinkedInResponse)
async def post_to_linkedin(
    request: PostLinkedInRequest,
    db=Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    if not current_user.get("linkedin_connected"):
        raise HTTPException(status_code=400, detail="LinkedIn not connected")

    access_token = await _ensure_valid_linkedin_access_token(current_user, db)

    linkedin_user_id = current_user.get("linkedin_user_id")
    if not linkedin_user_id:
        raise HTTPException(status_code=400, detail="LinkedIn user ID missing. Please reconnect LinkedIn.")

    author_urn = current_user.get("linkedin_person_urn") or linkedin_service.build_person_urn(linkedin_user_id)

    image_url = request.image_url
    image_status = request.image_status or ("generated" if image_url else "skipped_failed")

    try:
        result = await linkedin_service.create_post(
            access_token,
            request.content,
            author_urn,
            image_url=image_url,
        )
        return PostLinkedInResponse(
            success=True,
            post_id=result.get("id"),
            image_url=image_url,
            image_status=image_status,
        )
    except LinkedInAPIError as e:
        if e.status_code == 401:
            await _disconnect_linkedin_account(db, current_user["_id"])
            raise HTTPException(
                status_code=401,
                detail="LinkedIn authorization expired. Please reconnect LinkedIn.",
            )

        if image_url is not None:
            logger.warning(
                f"LinkedIn image post failed ({e.status_code}), retrying text-only post: {str(e)}"
            )
            try:
                result = await linkedin_service.create_post(
                    access_token,
                    request.content,
                    author_urn,
                    image_url=None,
                )
                return PostLinkedInResponse(
                    success=True,
                    post_id=result.get("id"),
                    image_url=None,
                    image_status="skipped_failed",
                )
            except LinkedInAPIError as fallback_error:
                logger.error(
                    f"LinkedIn fallback text-only post API error ({fallback_error.status_code}): {str(fallback_error)}"
                )
                raise HTTPException(status_code=fallback_error.status_code, detail=str(fallback_error))

        logger.error(f"LinkedIn post API error ({e.status_code}): {str(e)}")
        raise HTTPException(status_code=e.status_code, detail=str(e))
    except Exception as e:
        logger.error(f"Failed to post to LinkedIn: {str(e)}")
        raise HTTPException(status_code=500, detail="Failed to post to LinkedIn")


@router.post("/disconnect")
async def disconnect_linkedin(
    db=Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    await _disconnect_linkedin_account(db, current_user["_id"])
    return {"detail": "LinkedIn disconnected"}
