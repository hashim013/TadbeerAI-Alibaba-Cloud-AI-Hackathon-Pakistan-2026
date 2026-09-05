"""Supervisor routing tests — the Phase 2 routing matrix.

Pure deterministic logic: no LLM, no network. Covers the five required
routing cases from the spec plus defaults, calculation flags and
language inference.
"""

from __future__ import annotations

import pytest

from core.agents.routing import (
    classify_intent,
    infer_language_from_message,
    route_request,
)
from core.agents.supervisor import supervisor_node


# --------------------------------------------------------------------------- #
# required routing cases (Phase 2 spec)
# --------------------------------------------------------------------------- #


class TestRequiredRoutingCases:
    @pytest.mark.parametrize(
        "message,expected_agents,expected_intent",
        [
            (
                "How will inflation affect me?",
                ["economic_intelligence", "personal_finance", "risk_impact"],
                "inflation",
            ),
            ("What is KIBOR?", ["financial_literacy"], "interest_rate"),
            (
                "What if I save PKR 5,000 more?",
                ["personal_finance", "risk_impact"],
                "savings",
            ),
            ("Explain inflation in Roman Urdu.", ["financial_literacy"], "inflation"),
            (
                "What is my financial situation?",
                ["personal_finance"],
                "financial_health",
            ),
        ],
    )
    def test_required_cases(self, message, expected_agents, expected_intent):
        decision = route_request(message)
        assert decision.agents == expected_agents
        assert decision.intent == expected_intent

    def test_inflation_affect_me_needs_calculation(self):
        decision = route_request("How will inflation affect me?")
        assert decision.needs_calculation is True

    def test_kibor_concept_needs_no_calculation(self):
        decision = route_request("What is KIBOR?")
        assert decision.needs_calculation is False

    def test_whatif_needs_calculation(self):
        decision = route_request("What if I save PKR 5,000 more?")
        assert decision.needs_calculation is True

    def test_roman_urdu_case_needs_no_calculation(self):
        decision = route_request("Explain inflation in Roman Urdu.")
        assert decision.needs_calculation is False


# --------------------------------------------------------------------------- #
# additional routing behaviour
# --------------------------------------------------------------------------- #


class TestRoutingBehaviour:
    def test_economic_question_without_personal_angle(self):
        decision = route_request("Why is the dollar rising?")
        assert decision.agents == ["economic_intelligence"]
        assert decision.intent == "currency"

    def test_unknown_question_defaults_to_literacy(self):
        decision = route_request("Tell me a joke")
        assert decision.agents == ["financial_literacy"]

    def test_impact_without_economic_topic(self):
        decision = route_request("How does my budget affect my savings goal?")
        assert "economic_intelligence" not in decision.agents
        assert "personal_finance" in decision.agents
        assert "risk_impact" in decision.agents

    def test_concept_question_skips_personal_agents(self):
        decision = route_request("What is an emergency fund?")
        assert decision.agents == ["financial_literacy"]

    @pytest.mark.parametrize(
        "message",
        [
            "What is happening with inflation and interest rates in Pakistan?",
            "What's happening with the economy?",
        ],
    )
    def test_status_question_is_not_a_concept_question(self, message):
        # "what is happening" asks for a live read on the economy, not a
        # definition — it must reach the economic data layer
        decision = route_request(message)
        assert decision.agents == ["economic_intelligence"]

    def test_agents_are_ordered_canonically(self):
        decision = route_request("How will inflation affect me?")
        assert decision.agents == [
            "economic_intelligence",
            "personal_finance",
            "risk_impact",
        ]

    def test_routing_is_deterministic(self):
        first = route_request("How will inflation affect me?")
        second = route_request("How will inflation affect me?")
        assert first == second


# --------------------------------------------------------------------------- #
# language inference
# --------------------------------------------------------------------------- #


class TestLanguageInference:
    @pytest.mark.parametrize(
        "message,expected",
        [
            ("Explain inflation in Roman Urdu.", "ur_latn"),
            ("Explain inflation in urdu", "ur"),
            ("KIBOR kya hai? batao urdu script mein", "ur"),
            ("مہنگائی کیا ہے؟", "ur"),  # Urdu script input
            ("Explain this in english please", "en"),
            ("What is inflation?", None),
            ("", None),
        ],
    )
    def test_inference(self, message, expected):
        assert infer_language_from_message(message) == expected

    def test_supervisor_overrides_language_from_message(self):
        state = {"user_message": "Explain inflation in Roman Urdu.", "language": "en"}
        updates = supervisor_node(state)
        assert updates["language"] == "ur_latn"

    def test_supervisor_keeps_request_language_when_no_hint(self):
        state = {"user_message": "What is inflation?", "language": "ur"}
        updates = supervisor_node(state)
        assert "language" not in updates  # request-level language stands

    def test_supervisor_sets_routing_fields(self):
        state = {"user_message": "What is KIBOR?", "language": "en"}
        updates = supervisor_node(state)
        assert updates["intent"] == "interest_rate"
        assert updates["selected_agents"] == ["financial_literacy"]
        assert updates["needs_calculation"] is False


# --------------------------------------------------------------------------- #
# intent classification (supersedes the Phase-1 classifier, same behaviour)
# --------------------------------------------------------------------------- #


class TestIntentClassification:
    @pytest.mark.parametrize(
        "message,intent",
        [
            ("What is inflation?", "inflation"),
            ("Mehngai barh rahi hai", "inflation"),
            ("Why is the dollar rising?", "currency"),
            ("What is the PKR exchange rate?", "currency"),
            ("What is the current KIBOR rate?", "interest_rate"),
            ("How do I start saving bachat?", "savings"),
            ("What if I save PKR 5000 more?", "savings"),
            ("Help me plan my monthly budget", "budgeting"),
            ("What does GDP mean?", "economic_literacy"),
            ("Tell me a joke", "financial_literacy"),
            ("", "financial_literacy"),
        ],
    )
    def test_classification(self, message, intent):
        assert classify_intent(message) == intent

    def test_classification_is_case_insensitive(self):
        assert classify_intent("WHAT IS INFLATION?") == "inflation"
