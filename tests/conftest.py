"""Configuration des tests"""
import os

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.main import app, seed_categories
from app.database import Base, get_db

# -- Base en mémoire (SQLite) par défaut : tests unitaires rapides.
# -- Si AFI_TEST_POSTGRES=1 (CI / tests d'intégration et e2e) : base réelle
#    définie par DATABASE_URL (Postgres).
if os.environ.get("AFI_TEST_POSTGRES") == "1":
    SQLALCHEMY_DATABASE_URL = os.environ.get(
        "DATABASE_URL",
        "postgresql://afi:password@localhost:5432/afi_db",
    )
    engine = create_engine(SQLALCHEMY_DATABASE_URL)
    _POSTGRES = True
else:
    # StaticPool : tous les threads partagent la même base en mémoire
    SQLALCHEMY_DATABASE_URL = "sqlite://"
    engine = create_engine(
        SQLALCHEMY_DATABASE_URL,
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    _POSTGRES = False

TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


def override_get_db():
    try:
        db = TestingSessionLocal()
        yield db
    finally:
        db.close()


app.dependency_overrides[get_db] = override_get_db


@pytest.fixture(scope="function")
def client():
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)
    db = TestingSessionLocal()
    try:
        seed_categories(db)
    finally:
        db.close()
    yield TestClient(app)
    Base.metadata.drop_all(bind=engine)


@pytest.fixture(autouse=True)
def reset_rate_limiter():
    """Réinitialise le limiteur de login entre chaque test"""
    from app.utils.rate_limiter import login_limiter
    login_limiter.reset()
    yield


@pytest.fixture
def test_user(client):
    """Crée un utilisateur de test"""
    response = client.post("/api/v1/auth/register", json={
        "email": "test@afi.com",
        "password": "password123",
        "full_name": "Test User"
    })
    return response.json()


@pytest.fixture
def auth_headers(test_user):
    """Headers d'authentification"""
    return {"Authorization": f"Bearer {test_user['access_token']}"}