"""Tests d'intégration : workflows complets sur une base PostgreSQL réelle.

Lancement : AFI_TEST_POSTGRES=1 DATABASE_URL=postgresql://afi:password@localhost:5432/afi_test \
            pytest tests/integration -q
"""

from datetime import datetime


def _register(client, email):
    return client.post("/api/v1/auth/register", json={
        "email": email,
        "password": "password123",
        "full_name": "Intégration",
    })


def test_full_user_journey(client):
    """Parcours utilisateur complet : compte → transactions → budgets → bilan"""
    # 1. Inscription + profil
    reg = _register(client, "integration@afi.com")
    assert reg.status_code == 201
    token = reg.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    me = client.get("/api/v1/auth/me", headers=headers)
    assert me.status_code == 200
    assert me.json()["email"] == "integration@afi.com"

    # 2. Catégories disponibles
    cats = client.get("/api/v1/categories", headers=headers).json()
    assert len(cats) >= 5
    alimentation = next(c for c in cats if c["name"] == "Alimentation")
    transport = next(c for c in cats if c["name"] == "Transport")
    salaire = next(c for c in cats if c["name"] == "Salaire")

    # 3. Revenus + dépenses
    income = client.post("/api/v1/transactions", headers=headers, json={
        "amount": 100000, "type": "income", "category_id": salaire["id"],
        "description": "Salaire août",
    })
    assert income.status_code == 201

    for amount, cat, desc in [
        (15000, alimentation["id"], "Marché"),
        (20000, alimentation["id"], "Épicerie"),
        (8000, transport["id"], "Taxi"),
    ]:
        r = client.post("/api/v1/transactions", headers=headers, json={
            "amount": amount, "type": "expense", "category_id": cat,
            "description": desc,
        })
        assert r.status_code == 201

    # 4. Filtres et comptage
    filtered = client.get(
        "/api/v1/transactions?type=expense&search=march", headers=headers)
    assert len(filtered.json()) == 1
    assert filtered.headers["X-Total-Count"] == "1"

    # 5. Stats dashboard
    stats = client.get("/api/v1/dashboard/stats", headers=headers).json()
    assert stats["total_income"] == 100000
    assert stats["total_expenses"] == 43000
    assert stats["top_category_name"] == "Alimentation"

    # 6. Budget + alerte 80% -> notification avec suggestions
    now = datetime.utcnow()
    budget = client.post("/api/v1/budgets", headers=headers, json={
        "category_id": alimentation["id"], "amount": 40000,
        "month": now.month, "year": now.year,
    })
    assert budget.status_code == 201
    statuses = client.get(
        f"/api/v1/budgets?month={now.month}&year={now.year}", headers=headers).json()
    assert statuses[0]["percentage"] == 87.5
    assert statuses[0]["alert_80"] is True

    notifs = client.get("/api/v1/notifications?filter=unread", headers=headers).json()
    assert any("budget" in n["message"] for n in notifs)

    # 7. Insights + historique consulté
    insights = client.get("/api/v1/ai/insights", headers=headers)
    assert insights.status_code == 200
    history = client.get("/api/v1/ai/insights/history", headers=headers)
    assert len(history.json()) >= 1

    # 8. Bilan mensuel + PDF
    report = client.get("/api/v1/ai/monthly-report", headers=headers)
    assert report.status_code == 200
    assert "Bilan" in report.json()["summary"]
    pdf = client.get("/api/v1/ai/monthly-report/pdf", headers=headers)
    assert pdf.status_code == 200
    assert pdf.headers["content-type"] == "application/pdf"

    # 9. Chat avec historique
    chat = client.post("/api/v1/ai/chat", headers=headers,
                       json={"message": "Où puis-je réduire mes dépenses ?"})
    assert chat.status_code == 200
    history_chat = client.get("/api/v1/ai/chat/history", headers=headers)
    assert len(history_chat.json()) >= 2


def test_password_reset_full_flow(client):
    """Réinitialisation de mot de passe de bout en bout"""
    _register(client, "reset-flow@afi.com")

    forgot = client.post("/api/v1/auth/forgot-password",
                         json={"email": "reset-flow@afi.com"}).json()
    assert forgot["reset_token"]

    reset = client.post("/api/v1/auth/reset-password", json={
        "token": forgot["reset_token"], "new_password": "nouveau123",
    })
    assert reset.status_code == 200

    login_old = client.post("/api/v1/auth/login", json={
        "email": "reset-flow@afi.com", "password": "password123"})
    assert login_old.status_code == 401

    login_new = client.post("/api/v1/auth/login", json={
        "email": "reset-flow@afi.com", "password": "nouveau123"})
    assert login_new.status_code == 200
    assert "access_token" in login_new.json()