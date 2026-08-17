"""Tests du service de cache Redis et de son intégration au dashboard."""
import pytest

from app.services import cache as cache_module
from app.services.cache import get, invalidate, set_cache


class FakeRedis:
    """Client Redis en mémoire pour les tests."""

    def __init__(self):
        self.store = {}

    def ping(self):
        return True

    def get(self, key):
        return self.store.get(key)

    def set(self, key, value, ex=None):
        self.store[key] = value

    def delete(self, key):
        self.store.pop(key, None)


@pytest.fixture
def fake_redis(monkeypatch):
    client = FakeRedis()
    monkeypatch.setattr(cache_module, "_get_client", lambda: client)
    return client


def test_get_absent_returns_none(fake_redis):
    assert get(1, "balance") is None


def test_set_then_get_roundtrip(fake_redis):
    set_cache(42, "stats", {"balance": 100.5}, ttl=60)
    assert fake_redis.store["afi:dashboard:42:stats"] == '{"balance": 100.5}'
    assert get(42, "stats") == {"balance": 100.5}


def test_invalidate_removes_key(fake_redis):
    set_cache(1, "balance", {"balance": 0})
    invalidate(1, "balance")
    assert "afi:dashboard:1:balance" not in fake_redis.store


def test_get_ignores_redis_errors(monkeypatch):
    monkeypatch.setattr(cache_module, "_get_client", lambda: FailingRedis())
    assert get(1, "balance") is None


class FailingRedis(FakeRedis):
    def get(self, key):
        raise RuntimeError("down")

    def set(self, key, value, ex=None):
        raise RuntimeError("down")

    def delete(self, key):
        raise RuntimeError("down")


@pytest.fixture
def failing_redis(monkeypatch):
    monkeypatch.setattr(cache_module, "_get_client", lambda: FailingRedis())


def test_set_ignores_redis_errors(failing_redis):
    set_cache(1, "balance", {"balance": 0})  # ne doit pas lever


def test_invalidate_ignores_redis_errors(failing_redis):
    invalidate(1, "balance")  # ne doit pas lever


def test_client_none_sans_redis(monkeypatch):
    monkeypatch.setattr(cache_module.settings, "REDIS_URL", "")
    monkeypatch.setattr(cache_module, "HAS_REDIS", True)
    assert cache_module._get_client() is None


def test_dashboard_balance_sert_le_cache(monkeypatch, client, auth_headers):
    cached = {"balance": 999.0, "total_income": 1000.0, "total_expenses": 1.0,
              "month_income": 1000.0, "month_expenses": 1.0}
    monkeypatch.setattr(cache_module, "get", lambda _uid, _n: cached)
    response = client.get("/api/v1/dashboard/balance", headers=auth_headers)
    assert response.status_code == 200
    assert response.json()["balance"] == 999.0


def test_dashboard_balance_met_en_cache(monkeypatch, client, auth_headers):
    seen = {}
    monkeypatch.setattr(cache_module, "get", lambda _uid, _n: None)
    monkeypatch.setattr(cache_module, "set_cache",
                        lambda uid, name, value, ttl=60: seen.update(name=name, value=value))
    response = client.get("/api/v1/dashboard/balance", headers=auth_headers)
    assert response.status_code == 200
    assert seen["name"] == "balance"
    assert seen["value"]["balance"] == 0.0


def test_dashboard_stats_sert_le_cache(monkeypatch, client, auth_headers):
    cached = {"month": 8, "year": 2026, "total_expenses": 0.0, "total_income": 0.0,
              "balance": 0.0, "daily_average": 0.0, "top_category_id": None,
              "top_category_name": None, "top_category_amount": 0.0,
              "previous_month_expenses": 0.0, "previous_month_income": 0.0,
              "expenses_change_percent": None, "income_change_percent": None}
    monkeypatch.setattr(cache_module, "get", lambda _uid, _n: cached)
    response = client.get("/api/v1/dashboard/stats", headers=auth_headers)
    assert response.status_code == 200
    assert response.json()["balance"] == 0.0


def test_ecriture_transaction_invalide_le_cache(monkeypatch, client, auth_headers):
    invalidated = []
    monkeypatch.setattr(cache_module, "invalidate",
                        lambda uid, name: invalidated.append((uid, name)))
    response = client.post("/api/v1/transactions", headers=auth_headers, json={
        "amount": 5000, "type": "expense", "description": "Test", "category_id": 1})
    assert response.status_code == 201
    assert invalidated == [(1, "balance"), (1, "stats")]


def test_update_transaction_invalide_le_cache(monkeypatch, client, auth_headers):
    created = client.post("/api/v1/transactions", headers=auth_headers, json={
        "amount": 1000, "type": "expense", "category_id": 1}).json()
    invalidated = []
    monkeypatch.setattr(cache_module, "invalidate",
                        lambda uid, name: invalidated.append((uid, name)))
    response = client.put(f"/api/v1/transactions/{created['id']}", headers=auth_headers,
                          json={"amount": 2000})
    assert response.status_code == 200
    assert invalidated == [(1, "balance"), (1, "stats")]


def test_delete_transaction_invalide_le_cache(monkeypatch, client, auth_headers):
    created = client.post("/api/v1/transactions", headers=auth_headers, json={
        "amount": 1000, "type": "expense", "category_id": 1}).json()
    invalidated = []
    monkeypatch.setattr(cache_module, "invalidate",
                        lambda uid, name: invalidated.append((uid, name)))
    response = client.delete(f"/api/v1/transactions/{created['id']}", headers=auth_headers)
    assert response.status_code == 204
    assert invalidated == [(1, "balance"), (1, "stats")]
