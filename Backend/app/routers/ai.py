from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import List, Optional
from app.services.gemini_service import gemini_service
from app.utils.dependencies import get_current_user_optional
from fastapi import Depends

router = APIRouter(prefix="/ai", tags=["AI"])


class GeneratePostRequest(BaseModel):
    topic: str


class GeneratePostResponse(BaseModel):
    content: str


class ResearchTopicResponse(BaseModel):
    topic: str
    content: str


@router.post("/generate-post", response_model=GeneratePostResponse)
async def generate_linkedin_post(
    request: GeneratePostRequest,
    current_user: Optional[dict] = Depends(get_current_user_optional),
):
    if not request.topic or not request.topic.strip():
        raise HTTPException(status_code=400, detail="Topic is required")

    try:
        profile = current_user.get("profile") if current_user else None
        content = gemini_service.generate_linkedin_post(request.topic, profile=profile)
        return GeneratePostResponse(content=content)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to generate post: {str(e)}")


@router.post("/research-topics", response_model=List[ResearchTopicResponse])
async def generate_research_topics(
    current_user: Optional[dict] = Depends(get_current_user_optional),
):
    try:
        profile = current_user.get("profile") if current_user else None
        topics = gemini_service.generate_research_topics(profile=profile)
        return [
            ResearchTopicResponse(topic=item["topic"], content=item["content"])
            for item in topics
        ]
    except TimeoutError as e:
        raise HTTPException(status_code=504, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to generate research topics: {str(e)}")
