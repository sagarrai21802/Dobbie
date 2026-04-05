from pydantic_settings import BaseSettings
from typing import Optional


class Settings(BaseSettings):
    DATABASE_URL: str = "mongodb://localhost:27017"
    DATABASE_NAME: str = "dobbie"
    SECRET_KEY: str = "dev-secret-key-change-in-production"
    DEBUG: bool = True
    API_V1_PREFIX: str = "/api/v1"
    JWT_SECRET_KEY: str = "dev-jwt-secret-change-in-production"
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 15
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7

    # Gemini API Configuration
    GEMINI_API_KEY: str = ""

    # Freepik Mystic Configuration
    FREEPIK_API_KEY: str = ""
    FREEPIK_BASE_URL: str = "https://api.freepik.com"
    FREEPIK_MYSTIC_POLL_INTERVAL_SECONDS: int = 3
    FREEPIK_MYSTIC_MAX_ATTEMPTS: int = 10

    # LinkedIn OAuth Configuration
    LINKEDIN_CLIENT_ID: str = ""
    LINKEDIN_CLIENT_SECRET: str = ""
    LINKEDIN_REDIRECT_URL: str = ""
    LINKEDIN_SCOPE: str = "openid profile w_member_social email"
    LINKEDIN_APP_REDIRECT_URL: str = "dobbie://linkedin/connected"

    # Google OAuth Configuration
    GOOGLE_PROJECT_ID: str = ""
    GOOGLE_ANDROID_CLIENT_ID: str = ""
    GOOGLE_IOS_CLIENT_ID: str = ""
    GOOGLE_WEB_CLIENT_ID: str = ""
    GOOGLE_CLIENT_SECRET: str = ""
    
    # OAuth Redirect URIs
    GOOGLE_REDIRECT_URI: str = "http://localhost:8000/api/v1/auth/google/callback"
    FRONTEND_URL: str = "http://localhost:3000"
    
    # OAuth State Secret (for CSRF protection)
    OAUTH_STATE_SECRET: str = "dev-oauth-state-secret-change-in-production"
    
    # Google OAuth URLs
    GOOGLE_AUTH_URL: str = "https://accounts.google.com/o/oauth2/v2/auth"
    GOOGLE_TOKEN_URL: str = "https://oauth2.googleapis.com/token"
    GOOGLE_SCOPE: str = "openid email profile"

    # Firebase Configuration
    FIREBASE_CREDENTIALS_PATH: str = ""
    GOOGLE_APPLICATION_CREDENTIALS: str = ""

    class Config:
        env_file = ".env"
        case_sensitive = True


settings = Settings()

