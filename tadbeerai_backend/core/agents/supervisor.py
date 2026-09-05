"""Supervisor node — routing brain of the multi-agent graph.

Deterministic by design (see ``routing.py``): the supervisor sets the
intent, the minimum useful agent set and whether deterministic
calculations are needed. An explicit language request inside the message
("... in Roman Urdu", Urdu script, ...) overrides the request-level
language.
"""

from __future__ import annotations

from .routing import infer_language_from_message, route_request
from .state import AgentState


def supervisor_node(state: AgentState) -> dict:
    """Graph node: decide intent, agents and calculation needs."""
    message = state.get("user_message", "")
    decision = route_request(message, state.get("financial_context") or {})

    updates: dict = {
        "intent": decision.intent,
        "selected_agents": decision.agents,
        "needs_calculation": decision.needs_calculation,
    }

    inferred = infer_language_from_message(message)
    if inferred is not None:
        updates["language"] = inferred

    print(f"[Supervisor] intent={decision.intent} agents={decision.agents} "
          f"calc={decision.needs_calculation} lang={updates.get('language', state.get('language'))}")
    return updates
