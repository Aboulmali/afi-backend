"""Configuration de la base de données PostgreSQL"""
from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker

from app.config import settings

# Engine SQLAlchemy
engine = create_engine(
    settings.DATABASE_URL,
    pool_pre_ping=True,  # Vérifie la connexion avant utilisation
    echo=settings.DEBUG,  # Log les requêtes SQL en mode debug
)

# Session factory
SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine,
)

# Base pour les modèles
Base = declarative_base()


def get_db():
    """Dependency pour obtenir une session DB dans les endpoints"""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()