"""Configuration de l'application AFI"""
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Configuration principale chargée depuis .env"""

    # Application
    APP_NAME: str = "AFI - Assistant Financier Intelligent"
    APP_VERSION: str = "1.0.0"
    DEBUG: bool = False

    # Database
    DATABASE_URL: str = "postgresql://afi:password@localhost:5432/afi_db"

    # JWT
    SECRET_KEY: str = "change-me-in-production"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 1440  # 24h

    # OpenAI (ou fournisseur compatible : Groq, Gemini, Ollama...)
    OPENAI_API_KEY: str = ""
    OPENAI_BASE_URL: str = ""  # ex. https://api.groq.com/openai/v1
    OPENAI_MODEL: str = ""  # ex. llama-3.3-70b-versatile

    # Redis
    REDIS_URL: str = "redis://localhost:6379"

    # SMTP (email)
    SMTP_HOST: str = ""
    SMTP_PORT: int = 587
    SMTP_USER: str = ""
    SMTP_PASSWORD: str = ""
    SMTP_FROM: str = "afi@example.com"

    # CORS (à restreindre en prod ; "*" actif uniquement si DEBUG=true)
    CORS_ORIGINS: list[str] = []

    # Stockage objet (S3)
    AWS_ACCESS_KEY_ID: str = ""
    AWS_SECRET_ACCESS_KEY: str = ""
    AWS_REGION: str = "eu-west-3"
    UPLOADS_BUCKET: str = ""

    model_config = SettingsConfigDict(env_file=".env", case_sensitive=True)


settings = Settings()