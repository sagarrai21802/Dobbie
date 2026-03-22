import logging
from fastapi import APIRouter, HTTPException, Depends, Query
from pydantic import BaseModel
from typing import Optional
from bson import ObjectId

from app.database import get_db
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


@router.get("/callback", response_model=CallbackResponse)
async def linkedin_callback(
    code: Optional[str] = Query(None),
    state: Optional[str] = Query(None),
    db=Depends(get_db)
):
    if not code:
        logger.warning("LinkedIn callback missing authorization code")
        raise HTTPException(status_code=400, detail="Missing authorization code")

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
        result = await db.users.update_one(
            {"_id": ObjectId(user_id)},
            {
                "$set": {
                    "linkedin_access_token": access_token,
                    "linkedin_refresh_token": token_data.get("refresh_token"),
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
    return CallbackResponse(message="LinkedIn connected successfully", connected=True)


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
        image_url = await freepik_service.generate_image_from_post_text(request.content)
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
    current_user: dict = Depends(get_current_user),
):
    if not current_user.get("linkedin_connected"):
        raise HTTPException(status_code=400, detail="LinkedIn not connected")

    access_token = current_user.get("linkedin_access_token")
    if not access_token:
        raise HTTPException(status_code=400, detail="No LinkedIn access token found")

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
