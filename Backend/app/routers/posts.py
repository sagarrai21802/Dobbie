from fastapi import APIRouter, Depends, HTTPException, status
from typing import List

from app.database import get_db
from app.schemas.post import PostCreate, PostUpdate, PostResponse
from app.services.post_service import PostService

router = APIRouter(prefix="/posts", tags=["posts"])


@router.get("/", response_model=List[PostResponse])
async def get_posts(skip: int = 0, limit: int = 100, db=Depends(get_db)):
    return await PostService.get_all_posts(db, skip=skip, limit=limit)


@router.get("/{post_id}", response_model=PostResponse)
async def get_post(post_id: str, db=Depends(get_db)):
    post = await PostService.get_post_by_id(db, post_id)
    if not post:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Post not found")
    return post


@router.post("/", response_model=PostResponse, status_code=status.HTTP_201_CREATED)
async def create_post(post: PostCreate, db=Depends(get_db)):
    return await PostService.create_post(db, post)


@router.put("/{post_id}", response_model=PostResponse)
async def update_post(post_id: str, post_update: PostUpdate, db=Depends(get_db)):
    post = await PostService.update_post(db, post_id, post_update)
    if not post:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Post not found")
    return post


@router.delete("/{post_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_post(post_id: str, db=Depends(get_db)):
    success = await PostService.delete_post(db, post_id)
    if not success:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Post not found")
