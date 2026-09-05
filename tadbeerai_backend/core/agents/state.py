"""Typed LangGraph state for the Tadbeer AI 2.0 multi-agent pipeline.

The state carries only structured information — never hidden
chain-of-thought, raw internal reasoning, or private model messages.
"""

from __future__ import annotations

from typing import Annotated, Any, TypedDict


def merge_agent_results(left: dict | None, right: dict | None) -> dict:
    """Reducer merging parallel specialist writes into ``agent_results``."""
    merged = dict(left or {})
    merged.update(right or {})
    return merged


def merge_lists(left: list | None, right: list | None) -> list:
    """Reducer appending parallel writes to a list channel."""
    return (list(left) if left else []) + (list(right) if right else [])


class AgentState(TypedDict, total=False):
    """Graph state shared by the supervisor, specialists and composer."""

    user_message: str
    language: str
    intent: str
    financial_context: dict[str, Any]
    economic_context: dict[str, Any]
    selected_agents: list[str]
    needs_calculation: bool
    agent_results: Annotated[dict[str, Any], merge_agent_results]
    deterministic_results: dict[str, Any]
    recommendations: list[str]
    sources: list[str]
    data_status: str
    limitations: Annotated[list[str], merge_lists]
    final_response: str
    provider: str


#: canonical agent order used for routing decisions and response metadata
AGENT_ORDER: tuple[str, ...] = (
    "economic_intelligence",
    "personal_finance",
    "financial_literacy",
    "risk_impact",
)

SPECIALIST_AGENTS: tuple[str, ...] = (
    "economic_intelligence",
    "personal_finance",
    "financial_literacy",
)


def new_state(
    message: str,
    language: str,
    financial_context: dict[str, Any] | None = None,
    economic_context: dict[str, Any] | None = None,
) -> AgentState:
    """Build the initial state handed to the compiled graph."""
    return {
        "user_message": message,
        "language": language,
        "financial_context": dict(financial_context or {}),
        "economic_context": dict(economic_context or {}),
    }


def _as_str(value: Any) -> str:
    if value is None:
        return ""
    if isinstance(value, str):
        return value.strip()
    if isinstance(value, (int, float, bool)):
        return str(value)
    return ""


def _as_str_list(value: Any) -> list[str]:
    if isinstance(value, str):
        return [value.strip()] if value.strip() else []
    if isinstance(value, (list, tuple)):
        return [_as_str(item) for item in value if _as_str(item)]
    return []


def _as_dict(value: Any) -> dict[str, Any]:
    if isinstance(value, dict):
        return {str(k): v for k, v in value.items()}
    return {}


def normalize_agent_payload(agent: str, raw: Any) -> dict:
    """Coerce an LLM structured reply into the canonical agent payload.

    Raises ``ValueError`` when the reply is not an object at all.
    """
    if not isinstance(raw, dict):
        raise ValueError(f"{agent} reply is not a JSON object")
    return {
        "agent": agent,
        "summary": _as_str(raw.get("summary")),
        "facts": _as_str_list(raw.get("facts")),
        "metrics": _as_dict(raw.get("metrics")),
        "recommendations": _as_str_list(raw.get("recommendations")),
        "sources": _as_str_list(raw.get("sources")),
        "data_status": _as_str(raw.get("data_status")) or "demo",
    }
