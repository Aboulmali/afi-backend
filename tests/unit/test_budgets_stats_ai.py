"""Tests unitaires des budgets, statistiques et IA"""


def test_create_budget(client, auth_headers):
    """Test création budget"""
    response = client.post("/api/v1/budgets",
        headers=auth_headers,
        json={"category_id": 2, "amount": 5000, "month": 8, "year": 2026}
    )
    assert response.status_code == 201
    assert response.json()["amount"] == 5000


def test_budget_status_alerts(client, auth_headers):
    """Test alerte 80% et 100% sur un budget"""
    client.post("/api/v1/budgets",
        headers=auth_headers,
        json={"category_id": 3, "amount": 1000, "month": 8, "year": 2026}
    )
    # Dépense 900 > 80% du budget de 1000
    client.post("/api/v1/transactions",
        headers=auth_headers,
        json={"amount": 900, "type": "expense", "category_id": 3}
    )

    response = client.get("/api/v1/budgets?month=8&year=2026", headers=auth_headers)
    assert response.status_code == 200
    data = response.json()
    assert len(data) == 1
    assert data[0]["spent"] == 900
    assert data[0]["percentage"] == 90.0
    assert data[0]["alert_80"] is True
    assert data[0]["alert_100"] is False
    assert data[0]["remaining"] == 100.0


def test_update_budget(client, auth_headers):
    """Test modification budget"""
    created = client.post("/api/v1/budgets",
        headers=auth_headers,
        json={"category_id": 1, "amount": 3000, "month": 8, "year": 2026}
    ).json()

    response = client.put(f"/api/v1/budgets/{created['id']}",
        headers=auth_headers,
        json={"amount": 4000}
    )
    assert response.status_code == 200
    assert response.json()["amount"] == 4000


def test_delete_budget(client, auth_headers):
    """Test suppression budget"""
    created = client.post("/api/v1/budgets",
        headers=auth_headers,
        json={"category_id": 4, "amount": 2000, "month": 8, "year": 2026}
    ).json()

    response = client.delete(f"/api/v1/budgets/{created['id']}", headers=auth_headers)
    assert response.status_code == 204


def test_month_stats(client, auth_headers):
    """Test statistiques du mois avec comparaison"""
    client.post("/api/v1/transactions",
        headers=auth_headers,
        json={"amount": 10000, "type": "income", "category_id": 8}
    )
    client.post("/api/v1/transactions",
        headers=auth_headers,
        json={"amount": 4000, "type": "expense", "category_id": 1}
    )

    response = client.get("/api/v1/dashboard/stats", headers=auth_headers)
    assert response.status_code == 200
    data = response.json()
    assert data["total_income"] == 10000
    assert data["total_expenses"] == 4000
    assert data["balance"] == 6000
    assert data["top_category_name"] == "Alimentation"
    assert data["top_category_amount"] == 4000


def test_spending_chart(client, auth_headers):
    """Test graphique dépenses par catégorie"""
    client.post("/api/v1/transactions",
        headers=auth_headers,
        json={"amount": 2000, "type": "expense", "category_id": 1}
    )
    client.post("/api/v1/transactions",
        headers=auth_headers,
        json={"amount": 3000, "type": "expense", "category_id": 2}
    )

    response = client.get("/api/v1/dashboard/spending?period=month", headers=auth_headers)
    assert response.status_code == 200
    data = response.json()
    assert data["total"] == 5000
    assert len(data["categories"]) == 2
    # Trié par montant décroissant : Transport (3000) d'abord
    assert data["categories"][0]["category_name"] == "Transport"
    assert data["categories"][0]["percentage"] == 60.0


def test_evolution(client, auth_headers):
    """Test évolution mensuelle 6 mois"""
    response = client.get("/api/v1/dashboard/evolution", headers=auth_headers)
    assert response.status_code == 200
    data = response.json()
    assert len(data) == 6
    assert all("label" in p and "expenses" in p and "income" in p for p in data)


def test_transaction_filters(client, auth_headers):
    """Test filtres combinés (catégorie + recherche)"""
    client.post("/api/v1/transactions",
        headers=auth_headers,
        json={"amount": 1000, "type": "expense", "category_id": 1, "description": "Auchan"}
    )
    client.post("/api/v1/transactions",
        headers=auth_headers,
        json={"amount": 2000, "type": "expense", "category_id": 2, "description": "Bus"}
    )

    response = client.get("/api/v1/transactions?category_id=1&search=auch", headers=auth_headers)
    assert response.status_code == 200
    data = response.json()
    assert len(data) == 1
    assert data[0]["category_id"] == 1

    response = client.get("/api/v1/transactions?type=income", headers=auth_headers)
    assert len(response.json()) == 0


def test_ai_insights(client, auth_headers):
    """Test insights IA sans clé OpenAI (fallback local)"""
    response = client.get("/api/v1/ai/insights", headers=auth_headers)
    assert response.status_code == 200
    data = response.json()
    assert len(data) >= 1
    assert all("title" in i and "message" in i for i in data)


def test_ai_advice(client, auth_headers):
    """Test conseils IA (fallback local)"""
    response = client.get("/api/v1/ai/advice", headers=auth_headers)
    assert response.status_code == 200
    data = response.json()
    assert len(data) >= 1
    assert all("title" in a and "message" in a for a in data)


def test_ai_chat(client, auth_headers):
    """Test chat IA avec mots-clés"""
    response = client.post("/api/v1/ai/chat",
        headers=auth_headers,
        json={"message": "Comment épargner davantage ?"}
    )
    assert response.status_code == 200
    assert "reply" in response.json()


def test_ai_insights_history(client, auth_headers):
    """Test historique des insights consultés (#8)"""
    response = client.get("/api/v1/ai/insights", headers=auth_headers)
    assert response.status_code == 200
    insights = response.json()
    assert len(insights) >= 1

    history = client.get("/api/v1/ai/insights/history", headers=auth_headers)
    assert history.status_code == 200
    entries = history.json()
    assert len(entries) >= 1
    assert entries[0]["title"] == insights[0]["title"]
    assert entries[0]["message"] == insights[0]["message"]
    assert all("viewed_at" in e for e in entries)


def test_budget_alert_creates_notification(client, auth_headers):
    """Test alerte budget 80% -> notification avec suggestions (#10)"""
    client.post("/api/v1/budgets",
        headers=auth_headers,
        json={"category_id": 3, "amount": 1000, "month": 8, "year": 2026}
    )
    client.post("/api/v1/transactions",
        headers=auth_headers,
        json={"amount": 900, "type": "expense", "category_id": 3}
    )
    client.get("/api/v1/budgets?month=8&year=2026", headers=auth_headers)

    response = client.get("/api/v1/notifications", headers=auth_headers)
    assert response.status_code == 200
    notifications = response.json()
    assert len(notifications) >= 1
    assert any("Sous tension" in n["title"] or "Budget" in n["title"] for n in notifications)
    assert any("réduire" in n["message"] or "Réduisez" in n["message"] for n in notifications)


def test_ai_chat_voice_without_key(client, auth_headers):
    """Test chat vocal sans OPENAI_API_KEY -> 503 (#11)"""
    response = client.post("/api/v1/ai/chat/voice",
        headers=auth_headers,
        files={"file": ("voice.mp3", b"fake-audio-bytes", "audio/mpeg")}
    )
    assert response.status_code == 503
    assert "OPENAI_API_KEY" in response.json()["detail"]