from motor.motor_asyncio import AsyncIOMotorClient
from app.config import settings

client: AsyncIOMotorClient = None
db = None


async def connect_to_mongo():
    global client, db
    client = AsyncIOMotorClient(settings.DATABASE_URL)
    db = client.get_default_database()


async def close_mongo_connection():
    global client
    if client:
        client.close()


def get_db():
    return db
