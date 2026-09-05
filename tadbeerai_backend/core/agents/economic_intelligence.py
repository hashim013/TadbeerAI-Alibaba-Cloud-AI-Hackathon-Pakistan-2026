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


_COMMODITY_KEYWORDS: tuple[str, ...] = (
    "grocery", "groceries", "chicken", "tamatar", "tomato", "tomatoes",
    "onion", "onions", "pyaz", "atta", "wheat flour", "flour", "cooking oil",
    "ghee", "sugar", "cheeni", "daal", "pulse", "pulses", "egg", "eggs",
    "milk", "doodh", "sabzi", "vegetable", "vegetables", "ration", "rasan",
    "commodity", "commodities", "essential prices", "essential items", "spi",
    "food price", "food prices", "راشن", "سبزی", "گوشت", "آٹا",
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


def select_commodities(
    message: str, intent: str, commodities: list[Any]
) -> list[Any]:
    """Pick relevant essential commodities for the user's inquiry."""
    text = message.lower()
    has_commodity_signal = any(kw in text for kw in _COMMODITY_KEYWORDS)
    if not has_commodity_signal:
        return []

    matched: list[Any] = []
    for c in commodities:
        if (
            c.id in text
            or c.name.lower() in text
            or c.normalized_name in text
            or c.category.lower() in text
        ):
            matched.append(c)

    # If general grocery inquiry without specific item named, select top movers & staples
    if not matched:
        top_ids = {"onions", "tomatoes", "chicken_broiler", "wheat_flour_bag", "cooking_oil"}
        matched = [c for c in commodities if c.id in top_ids]

    return matched


def build_economic_prompt(
    message: str,
    indicators: list[Indicator],
    language: str,
    commodities: list[Any] | None = None,
) -> str:
    """Assemble the specialist prompt from the snapshot's indicators and commodities."""
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

    if commodities:
        lines.append("\nVerified Pakistan Bureau of Statistics (PBS) Essential Commodity Prices (SPI):")
        for c in commodities:
            chg = f"{c.change_percent:+.2f}%" if c.change_percent is not None else "0.0%"
            lines.append(
                f"- {c.name} ({c.unit}): PKR {c.price:.2f} ({chg} WoW trend: {c.trend}) "
                f"— {c.why_it_matters}"
            )
        lines.append(f"Observation Period: {commodities[0].observation_period} | Source: {commodities[0].source_name}")

    facts_block = "\n".join(lines)
    return (
        f"User question: {message}\n\n"
        f"{header}\n{facts_block}\n\n"
        f"Language instruction: {language_instruction(language)}\n"
        "Summarize what these indicators and essential commodity prices mean for an ordinary Pakistani "
        "household budget. Use ONLY the values above and explain why price movements matter without claiming exact individual spending unless stated."
    )


def economic_intelligence_node(state: AgentState, config) -> dict:
    """Graph node: economic intelligence with graceful degradation."""
    registry = registry_from_config(config)
    message = state.get("user_message", "")
    intent = state.get("intent", "")
    language = state.get("language", "en")

    try:
        service = get_economic_service()
        snapshot: EconomicSnapshot = service.snapshot()
        commodity_overview = service.commodity_snapshot()
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
    relevant_commodities = select_commodities(
        message, intent, commodity_overview.items
    )
    prompt = build_economic_prompt(
        message, indicators, language, commodities=relevant_commodities
    )

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
    metrics = snapshot.metric_values(names or list(snapshot.indicators))
    if relevant_commodities:
        for c in relevant_commodities:
            metrics[f"price_{c.id}"] = c.price
            if c.change_percent is not None:
                metrics[f"wow_{c.id}"] = c.change_percent

    sources = snapshot.sources(names)
    if relevant_commodities:
        pbs_src = f"{commodity_overview.source['name']} ({commodity_overview.period})"
        if pbs_src not in sources:
            sources.append(pbs_src)

    payload["metrics"] = metrics
    payload["sources"] = sources
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
