"""Runtime helpers shared by graph nodes.

The LLM registry is injected per-invocation through LangGraph's
``configurable`` dict (``config["configurable"]["registry"]``), so the
compiled graph stays provider-agnostic and tests can pass fake registries.
"""

from __future__ import annotations

from typing import Any, Callable

from langchain_core.runnables import RunnableConfig

from core.llm import LLMError, LLMRegistry, ProviderResponseError

from .state import normalize_agent_payload


def registry_from_config(config: RunnableConfig) -> LLMRegistry:
    """Extract the injected LLM registry from the runnable config."""
    configurable: dict[str, Any] = dict(config.get("configurable") or {})
    registry = configurable.get("registry")
    if not isinstance(registry, LLMRegistry):
        raise ProviderResponseError("LLM registry missing from graph config")
    return registry


def run_agent(
    registry: LLMRegistry,
    *,
    agent: str,
    system: str,
    prompt: str,
) -> dict:
    """Run one specialist agent and return its normalized structured payload.

    Raises ``LLMError`` (after the registry's own fallback) when generation
    fails; the caller decides whether to degrade gracefully.
    """
    raw = registry.generate_structured(prompt, system=system)
    try:
        return normalize_agent_payload(agent, raw)
    except ValueError as exc:
        raise ProviderResponseError(
            f"{agent} returned malformed structured output"
        ) from exc


#: node signature type: (state, config) -> partial state update
NodeFn = Callable[..., dict]
