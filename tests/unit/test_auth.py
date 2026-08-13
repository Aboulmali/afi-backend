"""Tests unitaires de l'authentification"""


def test_register_success(client):
    """Test inscription réussie"""
    response = client.post("/api/v1/auth/register", json={
        "email": "new@afi.com",
        "password": "password123",
        "full_name": "New User"
    })
    assert response.status_code == 201
    assert "access_token" in response.json()


def test_register_duplicate_email(client, test_user):
    """Test inscription avec email existant"""
    response = client.post("/api/v1/auth/register", json={
        "email": "test@afi.com",
        "password": "password123",
        "full_name": "Duplicate"
    })
    assert response.status_code == 400


def test_login_success(client, test_user):
    """Test connexion réussie"""
    response = client.post("/api/v1/auth/login", json={
        "email": "test@afi.com",
        "password": "password123"
    })
    assert response.status_code == 200
    assert "access_token" in response.json()


def test_login_wrong_password(client, test_user):
    """Test connexion avec mauvais mot de passe"""
    response = client.post("/api/v1/auth/login", json={
        "email": "test@afi.com",
        "password": "wrongpassword"
    })
    assert response.status_code == 401


def test_get_me(client, auth_headers):
    """Test récupération profil"""
    response = client.get("/api/v1/auth/me", headers=auth_headers)
    assert response.status_code == 200
    assert response.json()["email"] == "test@afi.com"


def test_forgot_password(client, test_user):
    """Test demande de reset (token généré en dev)"""
    response = client.post("/api/v1/auth/forgot-password", json={
        "email": "test@afi.com"
    })
    assert response.status_code == 200
    assert response.json()["reset_token"]


def test_reset_password_flow(client, test_user):
    """Test réinitialisation complète + nouvelle connexion"""
    forgot = client.post("/api/v1/auth/forgot-password", json={
        "email": "test@afi.com"
    }).json()
    token = forgot["reset_token"]

    response = client.post("/api/v1/auth/reset-password", json={
        "token": token,
        "new_password": "nouveau123"
    })
    assert response.status_code == 200

    # Ancien mot de passe ne fonctionne plus
    old = client.post("/api/v1/auth/login", json={
        "email": "test@afi.com", "password": "password123"
    })
    assert old.status_code == 401

    # Nouveau mot de passe fonctionne
    new = client.post("/api/v1/auth/login", json={
        "email": "test@afi.com", "password": "nouveau123"
    })
    assert new.status_code == 200
    assert "access_token" in new.json()


def test_login_rate_limited(client, test_user):
    """Test anti brute-force : 5 tentatives puis 429"""
    for _ in range(5):
        response = client.post("/api/v1/auth/login", json={
            "email": "test@afi.com", "password": "wrongpassword"
        })
        assert response.status_code == 401

    blocked = client.post("/api/v1/auth/login", json={
        "email": "test@afi.com", "password": "wrongpassword"
    })
    assert blocked.status_code == 429
    assert "Retry-After" in blocked.headers