from motor.motor_asyncio import AsyncIOMotorClient, AsyncIOMotorDatabase
from fastapi import Request
from app.config import settings

client: AsyncIOMotorClient = None


async def connect_to_mongo():
    global client
    client = AsyncIOMotorClient(settings.DATABASE_URL)


async def close_mongo_connection():
    global client
    if client:
        client.close()


async def get_db(request: Request):
    yield request.app.state.db
