from datetime import datetime
from typing import List, Optional

from pydantic import BaseModel, Field


class ProfileData(BaseModel):
    name: str = ""
    headline: str = ""
    location: str = ""
    current_role: str = ""
    industry: str = ""
    skills: List[str] = Field(default_factory=list)
    years_experience: Optional[int] = None
    preferred_tone: str = "conversational"
    is_complete: bool = False


class ProfileSaveRequest(BaseModel):
    name: str = ""
    headline: str = ""
    location: str = ""
    current_role: str = ""
    industry: str = ""
    skills: List[str] = Field(default_factory=list)
    years_experience: Optional[int] = None
    preferred_tone: str = "conversational"


class ProfileResponse(BaseModel):
    profile: ProfileData
    updated_at: datetime


class ProfileUploadResponse(BaseModel):
    extracted: ProfileData
