from motor.motor_asyncio import AsyncIOMotorDatabase
from app.schemas.post import PostCreate, PostUpdate
from bson import ObjectId
from typing import List, Optional
from datetime import datetime


class PostService:
    @staticmethod
    async def get_all_posts(db: AsyncIOMotorDatabase, skip: int = 0, limit: int = 100) -> List[dict]:
        posts = []
        async for post in db.posts.find().skip(skip).limit(limit):
            post["id"] = str(post.pop("_id"))
            posts.append(post)
        return posts

    @staticmethod
    async def get_post_by_id(db: AsyncIOMotorDatabase, post_id: str) -> Optional[dict]:
        post = await db.posts.find_one({"_id": ObjectId(post_id)})
        if post:
            post["id"] = str(post.pop("_id"))
        return post

    @staticmethod
    async def create_post(db: AsyncIOMotorDatabase, post: PostCreate) -> dict:
        post_dict = post.model_dump()
        post_dict["created_at"] = datetime.utcnow()
        post_dict["updated_at"] = datetime.utcnow()
        result = await db.posts.insert_one(post_dict)
        post_dict["id"] = str(result.inserted_id)
        return post_dict

    @staticmethod
    async def update_post(db: AsyncIOMotorDatabase, post_id: str, post_update: PostUpdate) -> Optional[dict]:
        update_data = post_update.model_dump(exclude_unset=True)
        if not update_data:
            return await PostService.get_post_by_id(db, post_id)

        update_data["updated_at"] = datetime.utcnow()
        result = await db.posts.find_one_and_update(
            {"_id": ObjectId(post_id)},
            {"$set": update_data},
            return_document=True
        )
        if result:
            result["id"] = str(result.pop("_id"))
        return result

    @staticmethod
    async def delete_post(db: AsyncIOMotorDatabase, post_id: str) -> bool:
        result = await db.posts.delete_one({"_id": ObjectId(post_id)})
        return result.deleted_count > 0
