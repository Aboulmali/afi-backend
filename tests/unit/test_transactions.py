"""Tests unitaires des transactions"""


def test_create_transaction(client, auth_headers):
    """Test création transaction"""
    response = client.post("/api/v1/transactions",
        headers=auth_headers,
        json={
            "amount": 5000,
            "type": "expense",
            "description": "Course Auchan",
            "category_id": 1
        }
    )
    assert response.status_code == 201
    assert response.json()["amount"] == 5000


def test_list_transactions(client, auth_headers):
    """Test liste transactions"""
    # Créer 2 transactions
    for i in range(2):
        client.post("/api/v1/transactions",
            headers=auth_headers,
            json={
                "amount": 1000 * (i + 1),
                "type": "expense",
                "category_id": 1
            }
        )

    response = client.get("/api/v1/transactions", headers=auth_headers)
    assert response.status_code == 200
    assert len(response.json()) == 2


def test_get_balance(client, auth_headers):
    """Test récupération solde"""
    # Ajouter une recette
    client.post("/api/v1/transactions",
        headers=auth_headers,
        json={"amount": 10000, "type": "income", "category_id": 8}
    )
    # Ajouter une dépense
    client.post("/api/v1/transactions",
        headers=auth_headers,
        json={"amount": 3000, "type": "expense", "category_id": 1}
    )

    response = client.get("/api/v1/dashboard/balance", headers=auth_headers)
    assert response.status_code == 200
    data = response.json()
    assert data["balance"] == 7000
    assert data["total_income"] == 10000
    assert data["total_expenses"] == 3000