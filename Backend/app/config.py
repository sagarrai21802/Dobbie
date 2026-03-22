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

    class Config:
        env_file = ".env"
        case_sensitive = True


settings = Settings()
