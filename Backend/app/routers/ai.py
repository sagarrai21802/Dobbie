from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from app.services.gemini_service import gemini_service

router = APIRouter(prefix="/ai", tags=["AI"])


class GeneratePostRequest(BaseModel):
    topic: str


class GeneratePostResponse(BaseModel):
    content: str


@router.post("/generate-post", response_model=GeneratePostResponse)
async def generate_linkedin_post(request: GeneratePostRequest):
    if not request.topic or not request.topic.strip():
        raise HTTPException(status_code=400, detail="Topic is required")

    try:
        content = gemini_service.generate_linkedin_post(request.topic)
        return GeneratePostResponse(content=content)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to generate post: {str(e)}")
