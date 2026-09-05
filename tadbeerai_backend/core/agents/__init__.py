"""Tadbeer AI 2.0 multi-agent package (LangGraph orchestration).

Architecture::

    API (core.api_v1)
      -> AssistantService (core.assistant_service)
        -> LangGraph (agents.graph)
          -> Supervisor (agents.supervisor)   — deterministic routing
          -> Specialists (fan-out, one superstep)
          -> Deterministic tools (agents.deterministic) — pure math
          -> Risk & Impact (agents.risk_impact)
          -> Response composer (agents.response)

Every LLM call flows through the vendor-neutral registry from
``core.llm`` — no agent imports a vendor SDK.
"""

from core.agents.graph import build_assistant_graph, get_assistant_graph
from core.agents.routing import (
    classify_intent,
    infer_language_from_message,
    normalize_language,
    route_request,
)
from core.agents.state import AgentState, new_state

__all__ = [
    "AgentState",
    "build_assistant_graph",
    "classify_intent",
    "get_assistant_graph",
    "infer_language_from_message",
    "new_state",
    "normalize_language",
    "route_request",
]
