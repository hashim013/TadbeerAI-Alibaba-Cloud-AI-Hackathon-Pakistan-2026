"""Financial Literacy Agent — explains financial concepts simply.

Serves English, Urdu and Roman Urdu with everyday Pakistani examples.
"""

from __future__ import annotations

from .prompts import FINANCIAL_LITERACY_SYSTEM
from .routing import language_instruction
from .runtime import registry_from_config, run_agent
from .state import AgentState


def financial_literacy_node(state: AgentState, config) -> dict:
    """Graph node: concept explanation with degradation."""
    registry = registry_from_config(config)
    message = state.get("user_message", "")
    language = state.get("language", "en")

    prompt = (
        f"User question: {message}\n\n"
        f"Language instruction: {language_instruction(language)}\n"
        "Explain the financial concept simply, with an everyday Pakistani "
        "example. Keep it short and practical."
    )

    try:
        payload = run_agent(
            registry,
            agent="financial_literacy",
            system=FINANCIAL_LITERACY_SYSTEM,
            prompt=prompt,
        )
    except Exception as exc:  # noqa: BLE001 — degrade, never crash the graph
        print(f"[Agent:financial_literacy] failed: {type(exc).__name__}: {exc}")
        return {
            "limitations": ["Concept explanation unavailable for this answer."]
        }

    # interpretive agents cite no verifiable sources: provenance is
    # code-controlled (demo snapshot / deterministic tools), never LLM-claimed
    payload["sources"] = []
    return {"agent_results": {"financial_literacy": payload}}
