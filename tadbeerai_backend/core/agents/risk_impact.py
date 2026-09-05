"""Risk & Impact Agent — "What does this information mean for THIS user?"

Runs after the specialists and the deterministic tools. It consumes the
user's financial context, the deterministic calculation results, the
economic indicators and the other agents' findings, and turns them into a
personal impact assessment with reasonable, hedged action suggestions.
"""

from __future__ import annotations

import json

from .prompts import RISK_IMPACT_SYSTEM
from .routing import language_instruction
from .runtime import registry_from_config, run_agent
from .state import AGENT_ORDER, AgentState


def _collect_specialist_payloads(state: AgentState) -> dict:
    """Summaries/facts/recommendations of every agent that already ran."""
    results = state.get("agent_results") or {}
    collected: dict[str, dict] = {}
    for name in AGENT_ORDER:
        payload = results.get(name)
        if not payload or name == "risk_impact":
            continue
        collected[name] = {
            "summary": payload.get("summary", ""),
            "facts": payload.get("facts", []),
            "recommendations": payload.get("recommendations", []),
            "metrics": payload.get("metrics", {}),
        }
    return collected


def risk_impact_node(state: AgentState, config) -> dict:
    """Graph node: personal impact analysis with degradation."""
    registry = registry_from_config(config)
    message = state.get("user_message", "")
    language = state.get("language", "en")

    prompt = (
        f"User question: {message}\n\n"
        f"User financial context: "
        f"{json.dumps(state.get('financial_context') or {}, ensure_ascii=False, default=str)}"
        f"\n\nDeterministic calculation results (computed by tools, NOT by you): "
        f"{json.dumps(state.get('deterministic_results') or {}, ensure_ascii=False, default=str)}"
        f"\n\nSpecialist agent findings:\n"
        f"{json.dumps(_collect_specialist_payloads(state), ensure_ascii=False, default=str)}"
        f"\n\nLanguage instruction: {language_instruction(language)}\n"
        "Assess what this information means for THIS user's finances. "
        "If the deterministic results include a 'scenario', treat its "
        "numbers as the user's own assumption — never as a forecast. "
        "Estimate financial pressure where inputs allow, explain the impact, "
        "and suggest reasonable actions. Estimates are possibilities, never "
        "guarantees."
    )

    try:
        payload = run_agent(
            registry,
            agent="risk_impact",
            system=RISK_IMPACT_SYSTEM,
            prompt=prompt,
        )
    except Exception as exc:  # noqa: BLE001 — degrade, never crash the graph
        print(f"[Agent:risk_impact] failed: {type(exc).__name__}: {exc}")
        return {
            "limitations": [
                "Personal impact analysis unavailable for this answer."
            ]
        }

    # interpretive agents cite no verifiable sources: provenance is
    # code-controlled (demo snapshot / deterministic tools), never LLM-claimed
    payload["sources"] = []
    return {"agent_results": {"risk_impact": payload}}
