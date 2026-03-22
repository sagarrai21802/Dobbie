from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.database import connect_to_mongo, close_mongo_connection
from app.routers import posts, auth, ai
from app.routers.linkedin import router as linkedin_router


@asynccontextmanager
async def lifespan(app: FastAPI):
    await connect_to_mongo()
    from app.database import client
    from app.config import settings as cfg
    app.state.db = client[cfg.DATABASE_NAME]
    await create_indexes(app)
    yield
    await close_mongo_connection()


async def create_indexes(app: FastAPI):
    await app.state.db.users.create_index("email", unique=True)


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
app.include_router(ai.router, prefix=settings.API_V1_PREFIX)
app.include_router(linkedin_router, prefix=settings.API_V1_PREFIX)


@app.get("/")
def root():
    return {"message": "Welcome to Dobbie API", "version": "1.0.0"}


@app.get("/health")
def health_check():
    return {"status": "healthy"}
