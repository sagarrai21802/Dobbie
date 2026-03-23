from datetime import datetime, timezone

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile

from app.database import get_db
from app.schemas.profile import ProfileSaveRequest, ProfileUploadResponse, ProfileResponse
from app.services.profile_service import ProfileService
from app.utils.dependencies import get_current_user

router = APIRouter(prefix="/profile", tags=["profile"])


@router.post("/upload-pdf", response_model=ProfileUploadResponse)
async def upload_profile_pdf(
    file: UploadFile = File(...),
    current_user: dict = Depends(get_current_user),
):
    filename = (file.filename or "").lower()
    if not filename.endswith(".pdf"):
        raise HTTPException(status_code=400, detail="Only PDF files are supported")

    file_bytes = await file.read()
    if len(file_bytes) > ProfileService.MAX_PDF_SIZE_BYTES:
        raise HTTPException(status_code=400, detail="PDF file size must be 5MB or less")

    try:
        extracted = await ProfileService.extract_profile_from_pdf(file_bytes)
        return ProfileUploadResponse(extracted=extracted)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    except Exception as exc:
        raise HTTPException(status_code=422, detail=f"PDF parse failed: {str(exc)}")


@router.post("/save", response_model=ProfileResponse)
async def save_profile(
    request: ProfileSaveRequest,
    db=Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    profile = await ProfileService.save_profile(db, current_user["_id"], request.model_dump())
    return ProfileResponse(profile=profile, updated_at=profile.get("updated_at") or datetime.now(timezone.utc))


@router.get("/me", response_model=ProfileResponse)
async def get_my_profile(current_user: dict = Depends(get_current_user)):
    profile = ProfileService.get_profile_from_user(current_user)
    return ProfileResponse(profile=profile, updated_at=profile.get("updated_at") or datetime.now(timezone.utc))
