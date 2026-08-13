"""Tests E2E (IHM/API) : fumée de l'application complète sur la stack réelle.

Lancement : AFI_TEST_POSTGRES=1 DATABASE_URL=postgresql://afi:password@localhost:5432/afi_test \
            pytest tests/e2e -q
"""


def test_smoke_health_and_openapi(client):
    """L'application démarre et expose son contrat d'API"""
    health = client.get("/health")
    assert health.status_code == 200
    assert health.json()["status"] == "healthy"

    openapi = client.get("/openapi.json")
    assert openapi.status_code == 200
    paths = openapi.json()["paths"]
    for required in [
        "/api/v1/auth/login", "/api/v1/auth/register",
        "/api/v1/transactions", "/api/v1/budgets",
        "/api/v1/ai/chat", "/api/v1/notifications", "/api/v1/scan",
        "/api/v1/import/sms/parse", "/api/v1/dashboard/stats",
    ]:
        assert required in paths, f"Route manquante : {required}"


def test_metrics_endpoint_exposed(client):
    """L'observabilité expose /metrics (Prometheus)"""
    response = client.get("/metrics")
    assert response.status_code == 200
    body = response.text
    assert "http_requests_total" in body or "http_request_duration" in body


def test_budget_alert_reminder_end_to_end(client):
    """Rappel de saisie + alerte budget, scénario utilisateur réel"""
    # Utilisateur complet
    reg = client.post("/api/v1/auth/register", json={
        "email": "e2e@afi.com", "password": "password123", "full_name": "E2E"})
    headers = {"Authorization": f"Bearer {reg.json()['access_token']}"}

    # Activation du rappel
    settings = client.put("/api/v1/notifications/settings", headers=headers, json={
        "reminder_enabled": True, "reminder_hour": 20, "weekend_included": False})
    assert settings.status_code == 200

    # Pas de transaction aujourd'hui -> rappel dû
    due = client.get("/api/v1/notifications/reminders/due", headers=headers).json()
    assert due["send"] is True

    # Budget serré -> alerte
    cats = client.get("/api/v1/categories", headers=headers).json()
    client.post("/api/v1/budgets", headers=headers, json={
        "category_id": cats[0]["id"], "amount": 500, "month": 8, "year": 2026})
    client.post("/api/v1/transactions", headers=headers, json={
        "amount": 450, "type": "expense", "category_id": cats[0]["id"]})
    statuses = client.get("/api/v1/budgets?month=8&year=2026", headers=headers).json()
    assert statuses[0]["alert_80"] is True

    # Une transaction aujourd'hui -> plus de rappel
    due_after = client.get("/api/v1/notifications/reminders/due", headers=headers).json()
    assert due_after["send"] is False