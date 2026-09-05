"""Response composer — the final node of the graph.

Synthesizes the specialist agents' structured outputs into the answer the
user reads, in the requested language. This node's LLM failure propagates
out of the graph (after the registry's provider fallback), surfacing as the
API's existing 503 behaviour.
"""

from __future__ import annotations

import json

from core.scenarios import SCENARIO_SOURCE

from .prompts import RESPONSE_COMPOSER_SYSTEM
from .routing import language_instruction
from .runtime import registry_from_config
from .state import AGENT_ORDER, AgentState


def collect_recommendations(state: AgentState) -> list[str]:
    """Dedupe recommendations from every successful agent, in agent order."""
    results = state.get("agent_results") or {}
    seen: set[str] = set()
    collected: list[str] = []
    for name in AGENT_ORDER:
        payload = results.get(name) or {}
        for item in payload.get("recommendations", []):
            text = str(item).strip()
            if text and text.lower() not in seen:
                seen.add(text.lower())
                collected.append(text)
    return collected


def collect_sources(state: AgentState) -> list[str]:
    """Dedupe sources from every successful agent, in agent order.

    Only code-controlled provenance survives: the economic data provider's
    snapshot label, the deterministic calculation tools and the scenario
    engine's "user-defined scenario" label. Interpretive agents' LLM-claimed
    sources are stripped in the agent nodes, so nothing unverifiable reaches
    the API response.
    """
    results = state.get("agent_results") or {}
    seen: set[str] = set()
    collected: list[str] = []
    for name in AGENT_ORDER:
        payload = results.get(name) or {}
        for item in payload.get("sources", []):
            text = str(item).strip()
            if text and text.lower() not in seen:
                seen.add(text.lower())
                collected.append(text)
    deterministic = state.get("deterministic_results") or {}
    if any(key != "scenario" for key in deterministic):
        label = "deterministic calculation results"
        if label not in seen:
            collected.append(label)
    if deterministic.get("scenario") is not None:
        if SCENARIO_SOURCE not in seen:
            collected.append(SCENARIO_SOURCE)
    return collected


def _agent_digest(state: AgentState) -> str:
    """Compact view of every successful agent's output for the composer."""
    results = state.get("agent_results") or {}
    digest: list[str] = []
    for name in AGENT_ORDER:
        payload = results.get(name)
        if not payload:
            continue
        digest.append(
            f"## {name} (data_status: {payload.get('data_status', 'demo')})\n"
            f"summary: {payload.get('summary', '')}\n"
            f"facts: {json.dumps(payload.get('facts', []), ensure_ascii=False)}\n"
            f"metrics: {json.dumps(payload.get('metrics', {}), ensure_ascii=False)}\n"
            f"recommendations: {json.dumps(payload.get('recommendations', []), ensure_ascii=False)}"
        )
    return "\n\n".join(digest) if digest else "(no agent produced results)"


def response_node(state: AgentState, config) -> dict:
    """Graph node: compose the final answer.

    Raises the LLM error (post-fallback) when generation is impossible.
    """
    registry = registry_from_config(config)
    message = state.get("user_message", "")
    language = state.get("language", "en")
    limitations = state.get("limitations") or []
    deterministic = state.get("deterministic_results") or {}

    prompt = (
        f"User question: {message}\n\n"
        f"Agent findings:\n{_agent_digest(state)}\n\n"
        f"Deterministic tool results: "
        f"{json.dumps(deterministic, ensure_ascii=False, default=str)}\n\n"
        f"Limitations to mention briefly: "
        f"{json.dumps(limitations, ensure_ascii=False) if limitations else 'none'}\n\n"
        f"Language instruction: {language_instruction(language)}\n"
        "Compose the final answer now. Give only the final answer for the "
        "user — no reasoning, no meta commentary."
    )

    result = registry.generate(prompt, system=RESPONSE_COMPOSER_SYSTEM, temperature=0.4)

    # data_status is code-controlled: the economic data layer computes it
    # (live / partial / demo / unavailable) and the agent node enforces it.
    # A scenario answer reports its own status — its numbers are the user's
    # assumption computed deterministically, never live data or a forecast.
    econ_payload = (state.get("agent_results") or {}).get("economic_intelligence") or {}
    data_status = econ_payload.get("data_status") or "demo"
    if (state.get("deterministic_results") or {}).get("scenario") is not None:
        data_status = "scenario"

    return {
        "final_response": result.text,
        "provider": result.provider,
        "data_status": data_status,
        "recommendations": collect_recommendations(state),
        "sources": collect_sources(state),
    }
