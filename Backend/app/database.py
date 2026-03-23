from motor.motor_asyncio import AsyncIOMotorClient, AsyncIOMotorDatabase
from fastapi import HTTPException, Request
import certifi
from app.config import settings

client: AsyncIOMotorClient = None


async def connect_to_mongo():
    global client
    db_url = settings.DATABASE_URL
    mongo_kwargs = {}

    # Force trusted CA bundle for Atlas/TLS connections.
    if db_url.startswith("mongodb+srv://") or "tls=true" in db_url.lower():
        mongo_kwargs["tlsCAFile"] = certifi.where()

    client = AsyncIOMotorClient(db_url, **mongo_kwargs)


async def close_mongo_connection():
    global client
    if client:
        client.close()


async def get_db(request: Request):
    if request.app.state.db is None:
        raise HTTPException(
            status_code=503,
            detail="Database is unavailable. Check MongoDB connection and retry.",
        )
    yield request.app.state.db
