"""Economic Intelligence Agent — Pakistan macro picture from the data layer.

The agent consumes a normalized :class:`EconomicSnapshot` (live / demo /
unavailable per indicator, code-controlled provenance) from
``core.economic_data`` and interprets it for an ordinary household. The
LLM only ever sees values this layer supplied — it never generates
numbers, sources or statuses, and the agent node overwrites the payload's
metrics, sources and data_status in code.

When every indicator is demo (no live provider succeeded) the prompt is
identical to Phase 2, so the fallback path stays well-tested.
"""

from __future__ import annotations

from typing import Any

from core.economic_data import EconomicSnapshot, get_economic_service
from core.economic_data.models import (
    STATUS_DEMO,
    Indicator,
    overall_status,
)

from .prompts import ECONOMIC_INTELLIGENCE_SYSTEM
from .routing import language_instruction
from .runtime import registry_from_config, run_agent
from .state import AgentState

#: intent / keyword -> indicators to surface
_TOPIC_INDICATORS: list[tuple[tuple[str, ...], tuple[str, ...]]] = [
    (("inflation", "mehngai", "مہنگائی", "price", "cost of living"), ("inflation_rate_pct",)),
    (("kibor",), ("kibor_3m_pct", "policy_rate_pct")),
    (("policy rate", "interest rate", "monetary"), ("policy_rate_pct", "kibor_3m_pct")),
    (("dollar", "usd", "pkr", "rupee", "exchange", "currency"), ("usd_pkr",)),
    (("reserve",), ("fx_reserves_usd_bn",)),
    (("remittance",), ("remittances_usd_bn",)),
]

_HEADLINE_INDICATORS: tuple[str, ...] = (
    "inflation_rate_pct",
    "policy_rate_pct",
    "usd_pkr",
)


def select_indicators(message: str, intent: str) -> list[str]:
    """Pick the indicator names relevant to the user's question."""
    text = f"{message} {intent}".lower()
    selected: list[str] = []
    for keywords, indicators in _TOPIC_INDICATORS:
        if any(keyword in text for keyword in keywords):
            for indicator in indicators:
                if indicator not in selected:
                    selected.append(indicator)
    if not selected:
        selected = list(_HEADLINE_INDICATORS)
    return selected


def build_economic_prompt(
    message: str, indicators: list[Indicator], language: str
) -> str:
    """Assemble the specialist prompt from the snapshot's indicators.

    Phase 2 compatibility: when every selected indicator is demo the header
    keeps the original DEMO wording and each line stays "(demo data)".
    """
    all_demo = bool(indicators) and all(
        ind.status == STATUS_DEMO for ind in indicators
    )
    if all_demo:
        header = "Available DEMO indicators (values are placeholders, not live):"
    else:
        header = "Available economic indicators (status marked per indicator):"

    lines: list[str] = []
    for ind in indicators:
        if ind.status == "live":
            period = f", period {ind.period}" if ind.period else ""
            lines.append(
                f"- {ind.label}: {ind.value} {ind.unit} "
                f"(live — {ind.source}{period})"
            )
        elif ind.status == STATUS_DEMO:
            lines.append(f"- {ind.label}: {ind.value} {ind.unit} (demo data)")
        else:
            lines.append(f"- {ind.label}: unavailable from live sources")

    facts_block = "\n".join(lines)
    return (
        f"User question: {message}\n\n"
        f"{header}\n{facts_block}\n\n"
        f"Language instruction: {language_instruction(language)}\n"
        "Summarize what these indicators mean for an ordinary Pakistani "
        "household. Use ONLY the values above."
    )


def economic_intelligence_node(state: AgentState, config) -> dict:
    """Graph node: economic intelligence with graceful degradation."""
    registry = registry_from_config(config)
    message = state.get("user_message", "")
    intent = state.get("intent", "")
    language = state.get("language", "en")

    try:
        snapshot: EconomicSnapshot = get_economic_service().snapshot()
    except Exception as exc:  # noqa: BLE001 — degrade, never crash the graph
        print(f"[Agent:economic_intelligence] data layer failed: {exc}")
        return {
            "limitations": [
                "Economic intelligence unavailable — answer may miss current "
                "economic context."
            ]
        }

    names = [
        name
        for name in select_indicators(message, intent)
        if name in snapshot.indicators
    ]
    indicators = [snapshot.indicators[name] for name in names] or list(
        snapshot.indicators.values()
    )
    prompt = build_economic_prompt(message, indicators, language)

    try:
        payload = run_agent(
            registry,
            agent="economic_intelligence",
            system=ECONOMIC_INTELLIGENCE_SYSTEM,
            prompt=prompt,
        )
    except Exception as exc:  # noqa: BLE001 — degrade, never crash the graph
        print(f"[Agent:economic_intelligence] failed: {type(exc).__name__}: {exc}")
        return {
            "limitations": [
                "Economic intelligence unavailable — answer may miss current "
                "economic context."
            ]
        }

    # deterministic overrides: metrics, sources and status come from the
    # data layer in code, never from the LLM reply
    payload["metrics"] = snapshot.metric_values(names or list(snapshot.indicators))
    payload["sources"] = snapshot.sources(names)
    payload["data_status"] = overall_status(indicators)

    update: dict[str, Any] = {"agent_results": {"economic_intelligence": payload}}

    # honest limitation when a live value was attempted but fell back to demo
    fallbacks = [
        snapshot.indicators[name].label
        for name in names
        if name in snapshot.fallback_reasons
        and name in snapshot.indicators
    ]
    if fallbacks:
        update["limitations"] = [
            f"Using demo value for {label} — live source unavailable."
            for label in fallbacks
        ]

    return update
