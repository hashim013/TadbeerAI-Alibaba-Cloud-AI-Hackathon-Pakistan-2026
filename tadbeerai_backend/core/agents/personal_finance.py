"""Personal Finance Agent — interprets the user's own financial picture.

This agent NEVER calculates financial metrics itself; it interprets the
profile qualitatively and defers arithmetic to the deterministic tools
(``core/agents/deterministic.py``) whose results are attached to the graph
state for the Risk & Impact agent.
"""

from __future__ import annotations

import json

from .prompts import PERSONAL_FINANCE_SYSTEM
from .routing import language_instruction
from .runtime import registry_from_config, run_agent
from .state import AgentState


def _format_context(context: dict) -> str:
    if not context:
        return "(no financial profile connected)"
    return json.dumps(context, ensure_ascii=False, default=str)


def personal_finance_node(state: AgentState, config) -> dict:
    """Graph node: personal finance interpretation with degradation."""
    registry = registry_from_config(config)
    message = state.get("user_message", "")
    language = state.get("language", "en")
    context = state.get("financial_context") or {}

    prompt = (
        f"User question: {message}\n\n"
        f"User financial profile: {_format_context(context)}\n\n"
        f"Language instruction: {language_instruction(language)}\n"
        "Interpret what this financial picture means for the user. Do not "
        "perform any arithmetic — describe pressure, headroom and stability "
        "qualitatively. If no profile is connected, say so and give general "
        "guidance."
    )

    try:
        payload = run_agent(
            registry,
            agent="personal_finance",
            system=PERSONAL_FINANCE_SYSTEM,
            prompt=prompt,
        )
    except Exception as exc:  # noqa: BLE001 — degrade, never crash the graph
        print(f"[Agent:personal_finance] failed: {type(exc).__name__}: {exc}")
        return {
            "limitations": [
                "Personal finance analysis unavailable for this answer."
            ]
        }

    # raw profile echo (not a calculation) for downstream consumers
    if context:
        payload["metrics"] = dict(context)
    # interpretive agents cite no verifiable sources: provenance is
    # code-controlled (demo snapshot / deterministic tools), never LLM-claimed
    payload["sources"] = []
    return {"agent_results": {"personal_finance": payload}}
