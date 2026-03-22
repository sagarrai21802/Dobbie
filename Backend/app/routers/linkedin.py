from fastapi import APIRouter, HTTPException, Depends, Query
from pydantic import BaseModel
from typing import Optional
from app.services.linkedin_service import linkedin_service
from app.utils.dependencies import get_current_user
from app.database import db

router = APIRouter(prefix="/auth/linkedin", tags=["LinkedIn"])


class PostLinkedInRequest(BaseModel):
    content: str


class AuthorizeResponse(BaseModel):
    authorization_url: str


class StatusResponse(BaseModel):
    connected: bool
    linkedin_user_id: Optional[str] = None


@router.get("/authorize", response_model=AuthorizeResponse)
async def authorize_linkedin():
    try:
        auth_url = linkedin_service.get_authorization_url()
        return AuthorizeResponse(authorization_url=auth_url)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get authorization URL: {str(e)}")


@router.get("/callback")
async def linkedin_callback(code: str = Query(...), state: str = Query("random_state")):
    try:
        token_data = await linkedin_service.exchange_code_for_token(code)
        access_token = token_data.get("access_token")
        
        if not access_token:
            raise HTTPException(status_code=400, detail="No access token received")
        
        profile = await linkedin_service.get_user_profile(access_token)
        linkedin_user_id = profile.get("sub")
        
        users_collection = db.users
        
        current_user_id = "current_user_id"
        
        await users_collection.update_one(
            {"_id": current_user_id},
            {
                "$set": {
                    "linkedin_access_token": access_token,
                    "linkedin_refresh_token": token_data.get("refresh_token"),
                    "linkedin_user_id": linkedin_user_id,
                    "linkedin_connected": True,
                }
            },
            upsert=True,
        )
        
        return {"message": "LinkedIn connected successfully", "connected": True}
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Callback failed: {str(e)}")


@router.get("/status", response_model=StatusResponse)
async def get_linkedin_status(current_user: dict = Depends(get_current_user)):
    linkedin_connected = current_user.get("linkedin_connected", False)
    linkedin_user_id = current_user.get("linkedin_user_id")
    
    return StatusResponse(
        connected=linkedin_connected,
        linkedin_user_id=linkedin_user_id,
    )


@router.post("/post")
async def post_to_linkedin(
    request: PostLinkedInRequest,
    current_user: dict = Depends(get_current_user),
):
    if not current_user.get("linkedin_connected"):
        raise HTTPException(status_code=400, detail="LinkedIn not connected")
    
    access_token = current_user.get("linkedin_access_token")
    if not access_token:
        raise HTTPException(status_code=400, detail="No LinkedIn access token found")
    
    try:
        result = await linkedin_service.create_post(access_token, request.content)
        return {"success": True, "post_id": result.get("id")}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to post: {str(e)}")
