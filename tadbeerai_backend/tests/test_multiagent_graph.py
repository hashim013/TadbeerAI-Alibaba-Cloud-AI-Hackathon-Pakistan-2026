"""Multi-agent graph integration tests (AssistantService level).

Runs the real compiled LangGraph pipeline with marker-scripted fake
providers — no real API keys, no network. Covers routing, degradation,
failure propagation, language handling and the response contract.
"""

from __future__ import annotations

import pytest

from core.assistant_service import AssistantService
from core.llm import (
    LLMError,
    LLMRegistry,
    ProviderAuthError,
    ProviderRateLimitError,
)
from tests.conftest import (
    COMPOSER_MARKER,
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
        ECONOMIC_MARKER: (
            '{"summary": "Econ demo view", "facts": ["inflation 11.8%"], '
            '"recommendations": ["Watch monthly spending"]}'
        ),
        PERSONAL_FINANCE_MARKER: (
            '{"summary": "Personal view", '
            '"recommendations": ["Track expenses"]}'
        ),
        RISK_IMPACT_MARKER: (
            '{"summary": "Moderate pressure", '
            '"recommendations": ["Build a small buffer", "Watch monthly spending"]}'
        ),
    }


def _service(provider, fallback=None) -> AssistantService:
    return AssistantService(LLMRegistry(primary=provider, fallback=fallback))


def _calls_with(provider, marker: str) -> list[dict]:
    return [c for c in provider.calls if marker in c["system"]]


# --------------------------------------------------------------------------- #
# happy paths
# --------------------------------------------------------------------------- #


class TestGraphHappyPaths:
    def test_full_multiagent_pipeline(self):
        provider = ScriptedAgentProvider(
            replies_by_marker=_full_scripts(),
            final_answer="Final composed multi-agent answer.",
        )
        result = _service(provider).chat(
            "How will inflation affect me?", "en", CONTEXT
        )

        assert result["answer"] == "Final composed multi-agent answer."
        assert result["intent"] == "inflation"
        assert result["language"] == "en"
        assert result["provider"] == "fake"
        assert result["agentsUsed"] == [
            "economic_intelligence",
            "personal_finance",
            "risk_impact",
        ]
        assert result["dataStatus"] == "demo"
        assert result["sources"] == [
            "demo snapshot (not live data)",
            "deterministic calculation results",
        ]

    def test_deterministic_and_economic_metrics_merged(self):
        provider = ScriptedAgentProvider(replies_by_marker=_full_scripts())
        result = _service(provider).chat(
            "How will inflation affect me?", "en", CONTEXT
        )

        metrics = result["metrics"]
        assert metrics["monthly_savings"] == 25000.0
        assert metrics["savings_rate_pct"] == 31.2
        assert metrics["runway_months"] == 3.6
        assert metrics["inflation_rate_pct"] == 11.8  # demo economic indicator

    def test_recommendations_deduped_across_agents(self):
        provider = ScriptedAgentProvider(replies_by_marker=_full_scripts())
        result = _service(provider).chat(
            "How will inflation affect me?", "en", CONTEXT
        )

        # "Watch monthly spending" suggested by two agents, kept once
        assert result["recommendations"].count("Watch monthly spending") == 1
        assert "Track expenses" in result["recommendations"]
        assert "Build a small buffer" in result["recommendations"]

    def test_literacy_only_routing(self):
        provider = ScriptedAgentProvider(
            replies_by_marker={
                LITERACY_MARKER: '{"summary": "KIBOR explained", "recommendations": []}',
            },
            final_answer="KIBOR is the interbank rate.",
        )
        result = _service(provider).chat("What is KIBOR?", "en")

        assert result["agentsUsed"] == ["financial_literacy"]
        assert result["intent"] == "interest_rate"
        assert result["metrics"] == {}
        assert result["sources"] == []
        assert len(_calls_with(provider, ECONOMIC_MARKER)) == 0

    def test_whatif_uses_deterministic_projection(self):
        provider = ScriptedAgentProvider(replies_by_marker=_full_scripts())
        result = _service(provider).chat(
            "What if I save PKR 5,000 more?", "en", CONTEXT
        )

        assert result["agentsUsed"] == ["personal_finance", "risk_impact"]
        metrics = result["metrics"]
        assert metrics["monthly_savings"] == 25000.0
        assert metrics["projected_monthly_savings"] == 30000.0
        assert metrics["projected_savings_rate_pct"] == 37.5

    def test_risk_impact_receives_deterministic_results(self):
        provider = ScriptedAgentProvider(replies_by_marker=_full_scripts())
        _service(provider).chat("What if I save PKR 5,000 more?", "en", CONTEXT)

        risk_calls = _calls_with(provider, RISK_IMPACT_MARKER)
        assert len(risk_calls) == 1
        assert "projected_monthly_savings" in risk_calls[0]["prompt"]
        assert "Deterministic calculation results" in risk_calls[0]["prompt"]


# --------------------------------------------------------------------------- #
# language handling
# --------------------------------------------------------------------------- #


class TestGraphLanguages:
    def test_roman_urdu_inferred_from_message(self):
        provider = ScriptedAgentProvider(
            replies_by_marker={
                LITERACY_MARKER: '{"summary": "مہنگائی کی وضاحت", "recommendations": []}',
            },
            final_answer="Roman Urdu answer.",
        )
        result = _service(provider).chat("Explain inflation in Roman Urdu.", "en")

        assert result["language"] == "ur_latn"
        literacy_calls = _calls_with(provider, LITERACY_MARKER)
        assert "Roman Urdu" in literacy_calls[0]["prompt"]
        composer_calls = _calls_with(provider, COMPOSER_MARKER)
        assert "Roman Urdu" in composer_calls[0]["prompt"]

    def test_unsupported_language_falls_back_to_english(self):
        provider = ScriptedAgentProvider(
            replies_by_marker={LITERACY_MARKER: '{"summary": "ok"}'},
        )
        result = _service(provider).chat("Hello there", "fr")

        assert result["language"] == "en"

    def test_request_language_respected_without_hint(self):
        provider = ScriptedAgentProvider(
            replies_by_marker={LITERACY_MARKER: '{"summary": "ok"}'},
        )
        result = _service(provider).chat("What is inflation?", "ur-PK")

        assert result["language"] == "ur"


# --------------------------------------------------------------------------- #
# failure handling
# --------------------------------------------------------------------------- #


class TestGraphFailures:
    def test_single_agent_failure_continues(self):
        provider = ScriptedAgentProvider(
            replies_by_marker={
                ECONOMIC_MARKER: ProviderAuthError("primary rejected"),
                PERSONAL_FINANCE_MARKER: '{"summary": "Personal view"}',
                RISK_IMPACT_MARKER: '{"summary": "Impact view"}',
            },
            final_answer="Answer from the surviving agents.",
        )
        result = _service(provider).chat(
            "How will inflation affect me?", "en", CONTEXT
        )

        assert result["answer"] == "Answer from the surviving agents."
        assert "economic_intelligence" not in result["agentsUsed"]
        assert "personal_finance" in result["agentsUsed"]
        assert "risk_impact" in result["agentsUsed"]
        # the composer was told about the limitation
        composer_calls = _calls_with(provider, COMPOSER_MARKER)
        assert "Economic intelligence unavailable" in composer_calls[0]["prompt"]

    def test_malformed_structured_output_degrades(self):
        provider = ScriptedAgentProvider(
            replies_by_marker={
                ECONOMIC_MARKER: "this is not json at all",
                PERSONAL_FINANCE_MARKER: '{"summary": "Personal view"}',
                RISK_IMPACT_MARKER: '{"summary": "Impact view"}',
            },
            final_answer="Answer despite malformed data.",
        )
        result = _service(provider).chat(
            "How will inflation affect me?", "en", CONTEXT
        )

        assert result["answer"] == "Answer despite malformed data."
        assert "economic_intelligence" not in result["agentsUsed"]

    def test_total_llm_failure_raises(self):
        primary = FakeProvider(error=ProviderAuthError("no key"))
        fallback = FakeProvider(error=ProviderRateLimitError("quota"))
        service = _service(primary, fallback)

        with pytest.raises(LLMError):
            service.chat("What is inflation?", "en")

    def test_registry_fallback_used_inside_graph(self):
        failing_primary = FakeProvider(error=ProviderAuthError("bad key"))
        fallback = ScriptedAgentProvider(
            replies_by_marker={LITERACY_MARKER: '{"summary": "ok from fallback"}'},
            final_answer="Answer via fallback provider.",
            name="groq",
        )
        result = _service(failing_primary, fallback).chat("What is inflation?", "en")

        assert result["provider"] == "groq"
        assert result["answer"] == "Answer via fallback provider."

    def test_empty_financial_context_degrades(self):
        provider = ScriptedAgentProvider(
            replies_by_marker={
                PERSONAL_FINANCE_MARKER: '{"summary": "No profile connected"}',
                RISK_IMPACT_MARKER: '{"summary": "General guidance"}',
            },
            final_answer="General what-if guidance.",
        )
        result = _service(provider).chat("What if I save PKR 5,000 more?", "en")

        # Phase 3B: the stated assumption still computes (5000/month ->
        # 30000 in 6 months / 60000 in a year); profile-dependent metrics
        # like the savings rate are NOT invented
        assert result["metrics"]["additional_monthly_savings"] == 5000.0
        assert result["metrics"]["additional_savings_6_months"] == 30000.0
        assert result["metrics"]["additional_savings_12_months"] == 60000.0
        assert "new_savings_rate_pct" not in result["metrics"]
        assert result["dataStatus"] == "scenario"
        assert result["answer"] == "General what-if guidance."
        # personal finance agent was told there is no profile
        pf_calls = _calls_with(provider, PERSONAL_FINANCE_MARKER)
        assert "no financial profile connected" in pf_calls[0]["prompt"]
        # deterministic node noted the limitation
        composer_calls = _calls_with(provider, COMPOSER_MARKER)
        assert "No financial profile connected" in composer_calls[0]["prompt"]


# --------------------------------------------------------------------------- #
# safety: agents' prompts carry the hard rules
# --------------------------------------------------------------------------- #


class TestGraphSafetyPrompts:
    def test_specialist_prompts_carry_safety_rules(self):
        provider = ScriptedAgentProvider(replies_by_marker=_full_scripts())
        _service(provider).chat("How will inflation affect me?", "en", CONTEXT)

        systems = [c["system"] for c in provider.calls]
        specialist_systems = [
            s for s in systems if s.startswith("[AGENT:")
        ]
        assert len(specialist_systems) == 3  # economic + personal finance + risk
        for system in specialist_systems:
            assert "not a licensed financial advisor" in system
            assert "Never invent numbers" in system
            assert "NOT a calculator" in system
            assert "chain-of-thought" in system

    def test_composer_prompt_forbids_meta_commentary(self):
        provider = ScriptedAgentProvider(replies_by_marker=_full_scripts())
        _service(provider).chat("How will inflation affect me?", "en", CONTEXT)

        composer_calls = _calls_with(provider, COMPOSER_MARKER)
        assert len(composer_calls) == 1
        system = composer_calls[0]["system"]
        assert "Never guarantee outcomes" in system
        assert "No chain-of-thought" in system

    def test_economic_agent_gets_demo_labelling_enforced(self):
        provider = ScriptedAgentProvider(replies_by_marker=_full_scripts())
        result = _service(provider).chat(
            "How will inflation affect me?", "en", CONTEXT
        )

        # demo labelling is enforced in code even though the scripted
        # agent reply never mentioned data_status
        assert result["dataStatus"] == "demo"
        assert result["sources"] == [
            "demo snapshot (not live data)",
            "deterministic calculation results",
        ]
        econ_calls = _calls_with(provider, ECONOMIC_MARKER)
        assert "DEMO indicators" in econ_calls[0]["prompt"]
        assert "demo data" in econ_calls[0]["prompt"]

    def test_llm_claimed_sources_are_stripped(self):
        provider = ScriptedAgentProvider(
            replies_by_marker={
                ECONOMIC_MARKER: (
                    '{"summary": "Econ view", '
                    '"sources": ["Made-up Bank report"]}'
                ),
                PERSONAL_FINANCE_MARKER: (
                    '{"summary": "Personal view", '
                    '"sources": ["Invented World Bank outlook"]}'
                ),
                RISK_IMPACT_MARKER: (
                    '{"summary": "Impact view", '
                    '"sources": ["economic_intelligence", "personal_finance"]}'
                ),
            },
            final_answer="Answer.",
        )
        result = _service(provider).chat(
            "How will inflation affect me?", "en", CONTEXT
        )

        # interpretive agents' LLM-claimed sources never reach the API;
        # the economic agent's code override wins over its LLM reply too
        assert result["sources"] == [
            "demo snapshot (not live data)",
            "deterministic calculation results",
        ]
