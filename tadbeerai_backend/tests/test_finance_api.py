"""API tests for GET/PUT /v1/finance — per-user Firestore-backed ledger.

The finance routes require a Firebase ID token (401 without one) and store a
whole-snapshot ledger per uid. These tests force the JSON-fallback storage
path (Firestore unavailable) against a temp dir so nothing touches the network
or real cloud storage, and drive authentication via a dependency override
(``get_authenticated_user_id``) rather than crafting real tokens.
"""

from __future__ import annotations

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

import core.finance_store as finance_store_module
from core import api_v1
from core.auth import get_authenticated_user_id
from core.finance_store import FinanceStore


@pytest.fixture
def finance_client(tmp_path, monkeypatch):
    """TestClient wired to the finance routes with a JSON-fallback store.

    Returns ``(client, set_uid)``. ``set_uid(value)`` controls what the
    overridden auth dependency resolves to (``None`` -> unauthenticated),
    simulating a valid/absent Firebase ID token without real crypto.
    """
    # Redirect the JSON fallback dir to a temp path so tests never touch
    # the repo's ./data, and force the Firestore-off branch deterministically.
    monkeypatch.setattr(finance_store_module, "FINANCE_DIR", str(tmp_path))

    store = FinanceStore()
    store._firestore_available = False  # force JSON fallback regardless of ADC
    monkeypatch.setattr(api_v1, "get_finance_store", lambda: store)

    current_uid = {"value": None}

    app = FastAPI()
    app.include_router(api_v1.router)
    app.dependency_overrides[get_authenticated_user_id] = lambda: current_uid[
        "value"
    ]
    client = TestClient(app)

    def set_uid(uid):
        current_uid["value"] = uid

    return client, set_uid


# --------------------------------------------------------------------------- #
# 401 without a token
# --------------------------------------------------------------------------- #


class TestFinanceAuth:
    def test_get_requires_token(self, finance_client):
        client, set_uid = finance_client
        set_uid(None)  # signed out / no Authorization header
        assert client.get("/v1/finance").status_code == 401

    def test_put_requires_token(self, finance_client):
        client, set_uid = finance_client
        set_uid(None)
        assert client.put("/v1/finance", json={}).status_code == 401


# --------------------------------------------------------------------------- #
# PUT then GET round-trip (JSON-fallback storage path)
# --------------------------------------------------------------------------- #


class TestFinanceRoundTrip:
    def test_empty_ledger_default(self, finance_client):
        client, set_uid = finance_client
        set_uid("user_123")
        body = client.get("/v1/finance").json()
        assert body == {
            "transactions": [],
            "budgets": [],
            "goals": [],
            "openingSavingsBalance": 0,
        }

    def test_put_then_get_round_trip(self, finance_client):
        client, set_uid = finance_client
        set_uid("user_123")
        snapshot = {
            "transactions": [
                {"id": "t1", "amount": 500, "type": "expense", "category": "Food"}
            ],
            "budgets": [{"id": "b1", "category": "Food", "limit": 5000}],
            "goals": [{"id": "g1", "title": "Emergency fund", "target": 100000}],
            "openingSavingsBalance": 25000.0,
        }

        put_resp = client.put("/v1/finance", json=snapshot)
        assert put_resp.status_code == 200
        stored = put_resp.json()
        assert stored["transactions"] == snapshot["transactions"]
        assert stored["budgets"] == snapshot["budgets"]
        assert stored["goals"] == snapshot["goals"]
        assert stored["openingSavingsBalance"] == 25000.0
        assert "updated_at" in stored  # server stamps the write time

        get_body = client.get("/v1/finance").json()
        assert get_body["transactions"] == snapshot["transactions"]
        assert get_body["openingSavingsBalance"] == 25000.0

    def test_put_replaces_whole_snapshot(self, finance_client):
        client, set_uid = finance_client
        set_uid("user_123")
        client.put("/v1/finance", json={"transactions": [{"id": "t1"}]})
        # last-write-wins: a snapshot with an empty list clears the ledger
        assert client.put("/v1/finance", json={"transactions": []}).json()[
            "transactions"
        ] == []
        assert client.get("/v1/finance").json()["transactions"] == []

    def test_missing_fields_normalize_to_defaults(self, finance_client):
        client, set_uid = finance_client
        set_uid("user_123")
        body = client.put("/v1/finance", json={"transactions": [{"id": "t1"}]}).json()
        assert body["budgets"] == []
        assert body["goals"] == []
        assert body["openingSavingsBalance"] == 0


# --------------------------------------------------------------------------- #
# guest / anonymous uid isolation
# --------------------------------------------------------------------------- #


class TestUidIsolation:
    def test_ledgers_isolated_per_user(self, finance_client):
        client, set_uid = finance_client
        set_uid("user_A")
        client.put("/v1/finance", json={"transactions": [{"id": "a1"}]})

        set_uid("user_B")
        assert client.get("/v1/finance").json()["transactions"] == []

        set_uid("user_A")
        assert client.get("/v1/finance").json()["transactions"] == [{"id": "a1"}]

    def test_anonymous_uids_isolated(self, finance_client):
        client, set_uid = finance_client
        set_uid("anon_xyz")
        client.put("/v1/finance", json={"goals": [{"id": "g_anon"}]})

        set_uid("anon_other")
        assert client.get("/v1/finance").json()["goals"] == []


# --------------------------------------------------------------------------- #
# wiring
# --------------------------------------------------------------------------- #


def test_finance_routes_wired_into_main_app():
    import main  # noqa: F401 — import runs the legacy app wiring

    paths = {route.path for route in main.app.routes}
    assert "/v1/finance" in paths
