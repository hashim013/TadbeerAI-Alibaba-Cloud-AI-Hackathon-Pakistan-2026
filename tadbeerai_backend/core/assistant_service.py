"""Assistant service — delegates chat to the LangGraph multi-agent pipeline.

Flow: API -> AssistantService -> LangGraph -> Supervisor -> specialists ->
deterministic tools -> Risk & Impact -> response composer.

The service keeps the Phase-1 response contract (``AssistantChatResponse``)
unchanged and re-exports the routing helpers so existing imports keep
working.
"""

from __future__ import annotations

from typing import Any

from core.agents.graph import build_assistant_graph
from core.agents.routing import (  # noqa: F401 — re-exported for compatibility
    classify_intent,
    normalize_language,
)
from core.agents.state import AGENT_ORDER, new_state
from core.llm import LLMError, LLMRegistry

# The compiled graph is provider-agnostic: the registry is injected per
# invocation through LangGraph's ``configurable`` dict.
_ASSISTANT_GRAPH = build_assistant_graph()


def _find_llm_error(exc: BaseException) -> LLMError | None:
    """Search an exception chain for an LLMError."""
    seen: set[int] = set()
    current: BaseException | None = exc
    while current is not None and id(current) not in seen:
        seen.add(id(current))
        if isinstance(current, LLMError):
            return current
        current = current.__cause__ or current.__context__
    return None


class AssistantService:
    """Answers user questions through the multi-agent graph."""

    def __init__(self, registry: LLMRegistry) -> None:
        self._registry = registry

    def chat(
        self,
        message: str,
        language: str = "en",
        financial_context: dict[str, Any] | None = None,
    ) -> dict:
        """Run the multi-agent pipeline and return the structured payload."""
        state = new_state(
            message=message,
            language=normalize_language(language),
            financial_context=financial_context,
        )
        config = {"configurable": {"registry": self._registry}}

        try:
            result = _ASSISTANT_GRAPH.invoke(state, config=config)
        except LLMError:
            raise
        except Exception as exc:
            llm_error = _find_llm_error(exc)
            if llm_error is not None:
                raise llm_error from exc
            raise

        return self._to_response(result)

    # ------------------------------------------------------------------ #
    # response mapping
    # ------------------------------------------------------------------ #

    def _to_response(self, result: dict) -> dict:
        """Map the final graph state onto the AssistantChatResponse fields."""
        agent_results = result.get("agent_results") or {}

        metrics: dict[str, Any] = dict(result.get("deterministic_results") or {})
        for name in AGENT_ORDER:
            payload = agent_results.get(name) or {}
            for key, value in (payload.get("metrics") or {}).items():
                metrics.setdefault(key, value)

        agents_used = [name for name in AGENT_ORDER if name in agent_results]

        return {
            "answer": result.get("final_response", ""),
            "intent": result.get("intent", "financial_literacy"),
            "language": result.get("language", "en"),
            "provider": result.get("provider", ""),
            "agentsUsed": agents_used,
            "metrics": metrics,
            "recommendations": result.get("recommendations") or [],
            "sources": result.get("sources") or [],
            "dataStatus": result.get("data_status", "demo"),
        }
