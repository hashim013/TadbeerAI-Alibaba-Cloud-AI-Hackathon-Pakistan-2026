"""API tests for GET /v1/health and POST /v1/assistant/chat.

The chat endpoint now runs the LangGraph multi-agent pipeline. Tests use
marker-scripted fake providers — no real API keys, no network.

Spec coverage (Phase 1 requirements 7-10, updated for Phase 2):
7.  /v1/health
8.  /v1/assistant/chat (multi-agent flow)
9.  invalid / empty requests
10. provider unavailable
"""

from __future__ import annotations

import pytest

from core.agents.routing import normalize_language
from core.llm import ProviderAuthError
from tests.conftest import (
    ECONOMIC_MARKER,
    LITERACY_MARKER,
    PERSONAL_FINANCE_MARKER,
    RISK_IMPACT_MARKER,
    FakeProvider,
    ScriptedAgentProvider,
)

CONTEXT = {
    "monthly_income": 80000,
    "monthly_expenses": 55000,
    "total_savings": 200000,
}


def _full_scripts() -> dict[str, str]:
    return {
        ECONOMIC_MARKER: '{"summary": "Econ view", "recommendations": ["Watch spending"]}',
        PERSONAL_FINANCE_MARKER: '{"summary": "Personal view", "recommendations": ["Track expenses"]}',
        RISK_IMPACT_MARKER: '{"summary": "Impact view", "recommendations": ["Build buffer"]}',
    }


# --------------------------------------------------------------------------- #
# 7. /v1/health
# --------------------------------------------------------------------------- #


class TestHealth:
    def test_health_ok_with_providers_configured(self, make_client):
        client = make_client(
            primary=ScriptedAgentProvider(),
            fallback=FakeProvider(name="groq"),
        )
        response = client.get("/v1/health")

        assert response.status_code == 200
        body = response.json()
        assert body == {
            "status": "ok",
            "primary_llm": "fake",
            "fallback_llm": "groq",
        }
        # exactly three keys — no keys, models or secrets leak out
        assert set(body.keys()) == {"status", "primary_llm", "fallback_llm"}

    def test_health_degraded_when_nothing_configured(self, make_client):
        client = make_client(
            primary=FakeProvider(name="gemini", configured=False),
            fallback=FakeProvider(name="groq", configured=False),
        )
        body = client.get("/v1/health").json()
        assert body["status"] == "degraded"
        assert body["primary_llm"] == "gemini"
        assert body["fallback_llm"] == "groq"


# --------------------------------------------------------------------------- #
# 8. POST /v1/assistant/chat (multi-agent pipeline)
# --------------------------------------------------------------------------- #


class TestAssistantChat:
    def test_happy_path_literacy(self, make_client):
        primary = ScriptedAgentProvider(
            replies_by_marker={
                LITERACY_MARKER: '{"summary": "Inflation raises prices.", "recommendations": ["Compare prices"]}',
            },
            final_answer="Inflation means a general rise in prices.",
        )
        client = make_client(primary=primary)

        response = client.post(
            "/v1/assistant/chat",
            json={"message": "What is inflation?", "language": "en"},
        )

        assert response.status_code == 200
        body = response.json()
        assert body["answer"] == "Inflation means a general rise in prices."
        assert body["intent"] == "inflation"
        assert body["language"] == "en"
        assert body["provider"] == "fake"
        assert body["agentsUsed"] == ["financial_literacy"]
        assert body["metrics"] == {}
        assert body["recommendations"] == ["Compare prices"]
        assert body["sources"] == []
        assert body["dataStatus"] == "demo"

    def test_multiagent_flow_with_financial_context(self, make_client):
        primary = ScriptedAgentProvider(
            replies_by_marker=_full_scripts(),
            final_answer="Composed impact answer.",
        )
        client = make_client(primary=primary)

        response = client.post(
            "/v1/assistant/chat",
            json={
                "message": "How will inflation affect me?",
                "language": "en",
                "financial_context": CONTEXT,
            },
        )

        assert response.status_code == 200
        body = response.json()
        assert body["answer"] == "Composed impact answer."
        assert body["intent"] == "inflation"
        assert body["agentsUsed"] == [
            "economic_intelligence",
            "personal_finance",
            "risk_impact",
        ]
        assert body["metrics"]["monthly_savings"] == 25000.0
        assert body["metrics"]["inflation_rate_pct"] == 11.8
        assert body["sources"] == [
            "demo snapshot (not live data)",
            "deterministic calculation results",
        ]
        assert body["dataStatus"] == "demo"

    def test_agent_prompts_enforce_safety_rules(self, make_client):
        primary = ScriptedAgentProvider(
            replies_by_marker={
                LITERACY_MARKER: '{"summary": "ok"}',
            },
        )
        client = make_client(primary=primary)

        client.post(
            "/v1/assistant/chat", json={"message": "What is inflation?"}
        )

        specialist_systems = [
            c["system"] for c in primary.calls if c["system"].startswith("[AGENT:")
        ]
        assert specialist_systems, "expected at least one specialist call"
        for system in specialist_systems:
            assert "not a licensed financial advisor" in system
            assert "Never invent numbers" in system
            assert "NOT a calculator" in system
            assert "chain-of-thought" in system
        composer_systems = [
            c["system"] for c in primary.calls if c["system"].startswith("[COMPOSER]")
        ]
        assert composer_systems
        assert "Never guarantee outcomes" in composer_systems[0]

    def test_language_inference_via_api(self, make_client):
        primary = ScriptedAgentProvider(
            replies_by_marker={LITERACY_MARKER: '{"summary": "ok"}'},
        )
        client = make_client(primary=primary)

        body = client.post(
            "/v1/assistant/chat",
            json={"message": "Explain inflation in Roman Urdu."},
        ).json()

        assert body["language"] == "ur_latn"
        literacy_prompts = [
            c["prompt"] for c in primary.calls if LITERACY_MARKER in c["system"]
        ]
        assert "Roman Urdu" in literacy_prompts[0]

    def test_language_defaults_to_english(self, make_client):
        client = make_client(
            primary=ScriptedAgentProvider(
                replies_by_marker={LITERACY_MARKER: '{"summary": "ok"}'},
            )
        )

        body = client.post(
            "/v1/assistant/chat", json={"message": "hello"}
        ).json()

        assert body["language"] == "en"

    def test_language_is_normalized(self, make_client):
        client = make_client(
            primary=ScriptedAgentProvider(
                replies_by_marker={LITERACY_MARKER: '{"summary": "ok"}'},
            )
        )

        body = client.post(
            "/v1/assistant/chat",
            json={"message": "hello", "language": "ur-PK"},
        ).json()

        assert body["language"] == "ur"

    def test_fallback_answer_via_api(self, make_client):
        primary = FakeProvider(name="gemini", error=ProviderAuthError("bad key"))
        fallback = ScriptedAgentProvider(
            replies_by_marker={LITERACY_MARKER: '{"summary": "ok from fallback"}'},
            final_answer="Answer from the fallback provider.",
            name="groq",
        )
        client = make_client(primary=primary, fallback=fallback)

        response = client.post(
            "/v1/assistant/chat", json={"message": "What is inflation?"}
        )

        assert response.status_code == 200
        body = response.json()
        assert body["provider"] == "groq"
        assert body["answer"] == "Answer from the fallback provider."

    def test_v1_routes_are_wired_into_main_app(self):
        import main  # noqa: F401 — import runs the legacy app wiring

        paths = {route.path for route in main.app.routes}
        assert "/v1/health" in paths
        assert "/v1/assistant/chat" in paths


# --------------------------------------------------------------------------- #
# language normalization (API boundary, unit level)
# --------------------------------------------------------------------------- #


class TestLanguageNormalization:
    @pytest.mark.parametrize(
        "raw,expected",
        [
            ("en", "en"),
            ("EN", "en"),
            ("English", "en"),
            ("", "en"),
            (None, "en"),
            ("ur", "ur"),
            ("ur-PK", "ur"),
            ("urdu", "ur"),
            ("ur_latn", "ur_latn"),
            ("ur-latn", "ur_latn"),
            ("roman urdu", "ur_latn"),
        ],
    )
    def test_normalization(self, raw, expected):
        assert normalize_language(raw) == expected


# --------------------------------------------------------------------------- #
# 9. invalid / empty requests
# --------------------------------------------------------------------------- #


class TestAssistantChatValidation:
    def test_missing_message_rejected(self, make_client):
        client = make_client(primary=ScriptedAgentProvider())
        response = client.post("/v1/assistant/chat", json={})
        assert response.status_code == 422

    def test_blank_message_rejected(self, make_client):
        client = make_client(primary=ScriptedAgentProvider())
        response = client.post("/v1/assistant/chat", json={"message": "   "})
        assert response.status_code == 422

    def test_wrong_type_rejected(self, make_client):
        client = make_client(primary=ScriptedAgentProvider())
        response = client.post("/v1/assistant/chat", json={"message": 12345})
        assert response.status_code == 422

    def test_overlong_message_rejected(self, make_client):
        client = make_client(primary=ScriptedAgentProvider())
        response = client.post(
            "/v1/assistant/chat", json={"message": "a" * 4001}
        )
        assert response.status_code == 422

    def test_financial_context_wrong_type_rejected(self, make_client):
        client = make_client(primary=ScriptedAgentProvider())
        response = client.post(
            "/v1/assistant/chat",
            json={"message": "hi", "financial_context": "not-a-dict"},
        )
        assert response.status_code == 422


# --------------------------------------------------------------------------- #
# 10. provider unavailable
# --------------------------------------------------------------------------- #


class TestAssistantChatUnavailable:
    def test_503_when_no_provider_configured(self, make_client):
        client = make_client(
            primary=FakeProvider(name="gemini", configured=False),
            fallback=FakeProvider(name="groq", configured=False),
        )
        response = client.post(
            "/v1/assistant/chat", json={"message": "What is inflation?"}
        )

        assert response.status_code == 503
        detail = response.json()["detail"]
        assert detail == (
            "The assistant is temporarily unavailable. "
            "Please try again shortly."
        )
        # raw provider errors and configuration details never leak
        lowered = detail.lower()
        assert "key" not in lowered
        assert "gemini" not in lowered
        assert "groq" not in lowered

    def test_503_when_all_providers_fail(self, make_client):
        client = make_client(
            primary=FakeProvider(name="gemini", error=ProviderAuthError("x")),
            fallback=FakeProvider(name="groq", error=ProviderAuthError("y")),
        )
        response = client.post(
            "/v1/assistant/chat", json={"message": "What is inflation?"}
        )

        assert response.status_code == 503
        # the raw internal error text ("x"/"y") must not appear anywhere
        assert "ProviderAuthError" not in response.text


# --------------------------------------------------------------------------- #
# 11. /v1/economy/snapshot
# --------------------------------------------------------------------------- #


class TestEconomySnapshot:
    def test_snapshot_returns_normalized_indicators(self, make_client):
        client = make_client(
            primary=ScriptedAgentProvider(),
            fallback=FakeProvider(name="groq"),
        )
        response = client.get("/v1/economy/snapshot")

        assert response.status_code == 200
        body = response.json()
        assert "status" in body
        assert body["status"] in ("live", "partial", "demo", "unavailable")
        assert "fetched_at" in body
        assert "indicators" in body
        assert isinstance(body["indicators"], dict)
        assert len(body["indicators"]) >= 6

        # Check expected indicators
        expected_indicators = (
            "inflation_rate_pct",
            "policy_rate_pct",
            "kibor_3m_pct",
            "usd_pkr",
            "fx_reserves_usd_bn",
            "remittances_usd_bn",
        )
        for name in expected_indicators:
            assert name in body["indicators"]
            ind = body["indicators"][name]
            assert "name" in ind
            assert "value" in ind
            assert "unit" in ind
            assert "label" in ind
            assert "status" in ind
            assert "source" in ind
            assert ind["status"] in ("live", "demo", "unavailable")
