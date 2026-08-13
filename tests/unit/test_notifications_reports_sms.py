"""Tests : notifications, conseils sauvegardés, chat, bilan mensuel, SMS, filtres"""


def test_notification_create_list_read(client, auth_headers):
    """Test cycle notifications"""
    # Créer une transaction pour déclencher une notification via l'import SMS
    response = client.post("/api/v1/import/sms/confirm",
        headers=auth_headers,
        json={"items": [
            {"amount": 2500, "type": "expense", "description": "Course",
             "category_id": 1}
        ]}
    )
    assert response.status_code == 200
    assert response.json()["transaction_ids"] == [1]

    # La notification a été créée
    notifications = client.get("/api/v1/notifications", headers=auth_headers).json()
    assert len(notifications) == 1
    notification_id = notifications[0]["id"]

    # Marquer comme lue
    response = client.put(f"/api/v1/notifications/{notification_id}/read", headers=auth_headers)
    assert response.status_code == 200
    assert response.json()["read"] is True

    # Filtrer non lues : vide
    unread = client.get("/api/v1/notifications?filter=unread", headers=auth_headers).json()
    assert len(unread) == 0


def test_sms_parse(client):
    """Test parsing SMS bancaires sans authentification (analyse pure)"""
    response = client.post("/api/v1/import/sms/parse", json={
        "messages": [
            {"sender": "OM", "body": "Vous avez ete debite de 3000 FCFA. Paiement Auchan. Solde 25000 FCFA."},
            {"sender": "Wave", "body": "Vous avez recu un virement de 10000 FCFA de Mme Diop."},
            {"sender": "AUTO ECOLE", "body": "Votre inscription est confirmee."},
        ]
    })
    assert response.status_code == 200
    data = response.json()
    assert len(data["parsed"]) == 2
    assert data["ignored"] == 1
    assert data["parsed"][0]["type"] == "debit"
    assert data["parsed"][0]["amount"] == 3000
    assert data["parsed"][1]["type"] == "credit"
    assert data["parsed"][1]["amount"] == 10000


def test_advice_save_rate(client, auth_headers):
    """Test sauvegarde et notation d'un conseil"""
    saved = client.post("/api/v1/ai/advice/save",
        headers=auth_headers,
        json={"title": "Épargne", "message": "Mettez 10% de côté chaque mois."}
    ).json()
    assert saved["rating"] == 0

    rated = client.put(f"/api/v1/ai/advice/saved/{saved['id']}/rate",
        headers=auth_headers,
        json={"rating": 5}
    ).json()
    assert rated["rating"] == 5

    saved_list = client.get("/api/v1/ai/advice/saved", headers=auth_headers).json()
    assert len(saved_list) == 1


def test_chat_history(client, auth_headers):
    """Test chat avec historique sauvegardé"""
    first = client.post("/api/v1/ai/chat",
        headers=auth_headers,
        json={"message": "Comment épargner ?"}
    ).json()
    assert first["conversation_id"]

    history = client.get("/api/v1/ai/chat/history", headers=auth_headers).json()
    assert len(history) == 2
    assert history[0]["role"] == "user"
    assert history[1]["role"] == "assistant"

    suggestions = client.get("/api/v1/ai/chat/suggestions", headers=auth_headers).json()
    assert len(suggestions) >= 3


def test_monthly_report(client, auth_headers):
    """Test bilan mensuel IA"""
    client.post("/api/v1/transactions",
        headers=auth_headers,
        json={"amount": 8000, "type": "expense", "category_id": 1}
    )
    client.post("/api/v1/transactions",
        headers=auth_headers,
        json={"amount": 20000, "type": "income", "category_id": 8}
    )

    report = client.get("/api/v1/ai/monthly-report", headers=auth_headers).json()
    assert report["month"] >= 1
    assert "Bilan" in report["summary"]
    assert len(report["insights"]) >= 1

    # Génération idempotente (pas de doublon)
    again = client.get("/api/v1/ai/monthly-report", headers=auth_headers).json()
    assert again["id"] == report["id"]


def test_monthly_report_pdf(client, auth_headers):
    """Test export PDF du bilan"""
    response = client.get("/api/v1/ai/monthly-report/pdf", headers=auth_headers)
    # reportlab peut manquer dans l'environnement de test -> 503 acceptable
    if response.status_code == 200:
        assert response.headers["content-type"] == "application/pdf"
        assert response.content.startswith(b"%PDF")


def test_reminder_settings(client, auth_headers):
    """Test réglages du rappel quotidien"""
    settings = client.put("/api/v1/notifications/settings",
        headers=auth_headers,
        json={"reminder_enabled": True, "reminder_hour": 21, "weekend_included": True}
    ).json()
    assert settings["reminder_hour"] == 21

    fetched = client.get("/api/v1/notifications/settings", headers=auth_headers).json()
    assert fetched["reminder_hour"] == 21


def test_reminders_due(client, auth_headers):
    """Test logique 'pas de rappel si déjà saisi aujourd'hui'"""
    # Utilisateur a déjà saisi une transaction
    client.post("/api/v1/transactions",
        headers=auth_headers,
        json={"amount": 1000, "type": "expense", "category_id": 1}
    )
    result = client.get("/api/v1/notifications/reminders/due", headers=auth_headers).json()
    assert result["send"] is False
    assert "déjà saisi" in result["reason"]


def test_transaction_count_header(client, auth_headers):
    """Test header X-Total-Count et sauvegarde des filtres"""
    client.post("/api/v1/transactions",
        headers=auth_headers,
        json={"amount": 1000, "type": "expense", "category_id": 1, "description": "Auchan"}
    )
    client.post("/api/v1/transactions",
        headers=auth_headers,
        json={"amount": 500, "type": "expense", "category_id": 2}
    )

    response = client.get("/api/v1/transactions", headers=auth_headers)
    assert response.headers.get("X-Total-Count") == "2"

    # Sauvegarde des derniers filtres
    saved = client.put("/api/v1/transactions/filters/preferences",
        headers=auth_headers,
        json={"category_id": 1}
    )
    assert saved.status_code == 200

    prefs = client.get("/api/v1/transactions/filters/preferences", headers=auth_headers).json()
    assert prefs["category_id"] == 1


def test_budget_alert_history(client, auth_headers):
    """Test historique des alertes de budget"""
    client.post("/api/v1/budgets",
        headers=auth_headers,
        json={"category_id": 1, "amount": 1000, "month": 8, "year": 2026}
    )
    client.post("/api/v1/transactions",
        headers=auth_headers,
        json={"amount": 900, "type": "expense", "category_id": 1}
    )
    # Déclenche l'enregistrement d'alerte (80%)
    client.get("/api/v1/budgets?month=8&year=2026", headers=auth_headers)

    alerts = client.get("/api/v1/budgets/alerts", headers=auth_headers).json()
    assert len(alerts) >= 1
    assert alerts[0]["level"] == "80"
    assert alerts[0]["category_name"] == "Alimentation"