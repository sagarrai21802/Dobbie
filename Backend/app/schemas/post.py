from pydantic import BaseModel, Field
from datetime import datetime
from typing import Optional
from bson import ObjectId


class PostBase(BaseModel):
    title: str = Field(..., min_length=1, max_length=255)
    content: str


class PostCreate(PostBase):
    pass


class PostUpdate(BaseModel):
    title: Optional[str] = Field(None, min_length=1, max_length=255)
    content: Optional[str] = None


class PostResponse(PostBase):
    id: str
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True
