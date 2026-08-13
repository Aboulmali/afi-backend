"""Point d'entrée de l'application FastAPI"""
import asyncio
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session

from app.config import settings
from app.database import engine, Base, SessionLocal
from app.models import Category  # Import pour créer les tables
from app.routers import (
    auth, transactions, categories, dashboard, budgets, ai,
    notifications, scan, sms_import,
)
from app.services.scheduler import scheduler_loop

logging.basicConfig(level=logging.INFO)

# Tâche de fond du planificateur
scheduler_task = None


def seed_categories(db: Session):
    """Ajoute les catégories par défaut si vides"""
    if db.query(Category).count() == 0:
        default_categories = [
            Category(name="Alimentation", icon="restaurant", color="#FF6B6B"),
            Category(name="Transport", icon="directions_car", color="#4ECDC4"),
            Category(name="Logement", icon="home", color="#95E1D3"),
            Category(name="Loisirs", icon="sports_esports", color="#F38181"),
            Category(name="Santé", icon="local_hospital", color="#AA96DA"),
            Category(name="Éducation", icon="school", color="#FCBAD3"),
            Category(name="Shopping", icon="shopping_cart", color="#FFFFD2"),
            Category(name="Salaire", icon="work", color="#3EC70B"),
            Category(name="Autres", icon="more_horiz", color="#A8A8A8"),
        ]
        db.add_all(default_categories)
        db.commit()
        print("✅ Catégories par défaut créées")


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Startup et shutdown"""
    global scheduler_task
    # Startup
    print("🚀 Démarrage d'AFI API...")
    Base.metadata.create_all(bind=engine)
    print("✅ Tables créées")

    # Seed les catégories
    db = SessionLocal()
    try:
        seed_categories(db)
    finally:
        db.close()

    # Planificateur (rappels 20h + bilans mensuels)
    scheduler_task = asyncio.create_task(scheduler_loop())

    yield

    # Shutdown
    if scheduler_task:
        scheduler_task.cancel()
    print("👋 Arrêt d'AFI API")


# Créer l'app FastAPI
app = FastAPI(
    title=settings.APP_NAME,
    description="API REST pour AFI - Assistant Financier Intelligent",
    version=settings.APP_VERSION,
    docs_url="/docs",
    redoc_url="/redoc",
    lifespan=lifespan,
)

# CORS pour Flutter
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Enregistrer les routers
app.include_router(auth.router, prefix="/api/v1/auth", tags=["🔐 Authentification"])
app.include_router(transactions.router, prefix="/api/v1/transactions", tags=["💸 Transactions"])
app.include_router(categories.router, prefix="/api/v1/categories", tags=["📁 Catégories"])
app.include_router(dashboard.router, prefix="/api/v1/dashboard", tags=["📊 Dashboard"])
app.include_router(budgets.router, prefix="/api/v1/budgets", tags=["💰 Budgets"])
app.include_router(ai.router, prefix="/api/v1/ai", tags=["🤖 Assistant IA"])
app.include_router(notifications.router, prefix="/api/v1/notifications", tags=["🔔 Notifications"])
app.include_router(scan.router, prefix="/api/v1", tags=["📷 Scan de factures"])
app.include_router(sms_import.router, prefix="/api/v1/import", tags=["📲 Import SMS"])


@app.get("/", tags=["Root"])
def root():
    """Endpoint racine"""
    return {
        "message": f"Bienvenue sur {settings.APP_NAME}",
        "version": settings.APP_VERSION,
        "docs": "/docs"
    }


@app.get("/health", tags=["Health"])
def health_check():
    """Health check pour Kubernetes"""
    return {"status": "healthy"}