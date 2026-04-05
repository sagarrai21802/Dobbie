from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.database import connect_to_mongo, close_mongo_connection
from app.routers import posts, auth, ai, profile
from app.routers.linkedin import router as linkedin_router
from app.routers.subscription import router as subscription_router
from app.routers.topics import router as topics_router
from app.routers.schedule import router as schedule_router
from app.routers.notifications import router as notifications_router


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    await connect_to_mongo()
    from app.database import client
    from app.config import settings as cfg
    app.state.db = client[cfg.DATABASE_NAME]
    await create_indexes(app)
    
    # Start background scheduler
    from app.scheduler import start_scheduler
    start_scheduler()
    
    yield
    
    # Shutdown
    from app.scheduler import stop_scheduler
    stop_scheduler()
    await close_mongo_connection()


async def create_indexes(app: FastAPI):
    # User indexes
    await app.state.db.users.create_index("email", unique=True)
    
    # Refresh token indexes
    await app.state.db.refresh_tokens.create_index("token_hash", unique=True)
    await app.state.db.refresh_tokens.create_index("user_id")
    await app.state.db.refresh_tokens.create_index("expires_at")
    
    # Scheduling indexes
    await app.state.db.scheduled_calendars.create_index("user_id")
    await app.state.db.scheduled_calendars.create_index("status")
    await app.state.db.calendar_entries.create_index("user_id")
    await app.state.db.calendar_entries.create_index("calendar_id")
    await app.state.db.calendar_entries.create_index("scheduled_date")
    await app.state.db.calendar_entries.create_index([("scheduled_date", 1), ("scheduled_time", 1)])
    await app.state.db.user_preferences.create_index("user_id", unique=True)


app = FastAPI(
    title="Dobbie API",
    description="Backend API for Dobbie application",
    version="1.0.0",
    debug=settings.DEBUG,
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000", "http://localhost:8080"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router, prefix=settings.API_V1_PREFIX)
app.include_router(posts.router, prefix=settings.API_V1_PREFIX)
app.include_router(ai.router, prefix=settings.API_V1_PREFIX)
app.include_router(profile.router, prefix=settings.API_V1_PREFIX)
app.include_router(linkedin_router, prefix=settings.API_V1_PREFIX)
app.include_router(subscription_router, prefix=settings.API_V1_PREFIX)
app.include_router(topics_router, prefix=settings.API_V1_PREFIX)
app.include_router(schedule_router, prefix=settings.API_V1_PREFIX)
app.include_router(notifications_router, prefix=settings.API_V1_PREFIX)


@app.get("/")
def root():
    return {"message": "Welcome to Dobbie API", "version": "1.0.0"}


@app.get("/health")
def health_check():
    return {"status": "healthy"}