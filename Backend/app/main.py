from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.database import connect_to_mongo, close_mongo_connection
from app.routers import posts, auth


@asynccontextmanager
async def lifespan(app: FastAPI):
    await connect_to_mongo()
    await create_indexes()
    yield
    await close_mongo_connection()


async def create_indexes():
    from app.database import db
    from pymongo import ASCENDING
    await db.users.create_index("email", unique=True)


app = FastAPI(
    title="Dobbie API",
    description="Backend API for Dobbie application",
    version="1.0.0",
    debug=settings.DEBUG,
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router, prefix=settings.API_V1_PREFIX)
app.include_router(posts.router, prefix=settings.API_V1_PREFIX)


@app.get("/")
def root():
    return {"message": "Welcome to Dobbie API", "version": "1.0.0"}


@app.get("/health")
def health_check():
    return {"status": "healthy"}
