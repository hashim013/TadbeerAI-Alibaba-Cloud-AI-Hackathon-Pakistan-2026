"""Normalized economic indicator models — the single internal format.

Every indicator flowing through Tadbeer AI carries explicit provenance:
``status`` (live / demo / unavailable), ``source`` (code-controlled, never
LLM-generated), ``value`` (None only when unavailable) and ``period``.
"""

from __future__ import annotations

from dataclasses import dataclass, field

#: per-indicator availability
STATUS_LIVE = "live"
STATUS_DEMO = "demo"
STATUS_UNAVAILABLE = "unavailable"

#: aggregate snapshot status
SNAPSHOT_LIVE = "live"
SNAPSHOT_PARTIAL = "partial"
SNAPSHOT_DEMO = "demo"
SNAPSHOT_UNAVAILABLE = "unavailable"

#: the one and only demo provenance label (test-pinned string)
DEMO_SOURCE = "demo snapshot (not live data)"


@dataclass(frozen=True)
class Indicator:
    """One normalized economic indicator with honest provenance."""

    name: str
    value: float | None
    unit: str
    label: str
    status: str
    source: str
    period: str = ""
    notes: str = ""

    @property
    def has_value(self) -> bool:
        return self.value is not None


@dataclass(frozen=True)
class IndicatorSpec:
    """Canonical catalog entry: indicator name, label, unit and demo value."""

    name: str
    label: str
    demo_value: float
    unit: str


#: the six prioritized indicators (Phase 2 demo values kept as fallback)
INDICATOR_CATALOG: tuple[IndicatorSpec, ...] = (
    IndicatorSpec("inflation_rate_pct", "CPI inflation (YoY)", 11.8, "%"),
    IndicatorSpec("policy_rate_pct", "SBP policy rate", 11.0, "%"),
    IndicatorSpec("kibor_3m_pct", "3-month KIBOR", 11.9, "%"),
    IndicatorSpec("usd_pkr", "USD/PKR exchange rate", 278.5, "PKR"),
    IndicatorSpec("fx_reserves_usd_bn", "SBP liquid FX reserves", 9.4, "USD bn"),
    IndicatorSpec("remittances_usd_bn", "Workers' remittances", 3.2, "USD bn"),
)

_CATALOG_BY_NAME: dict[str, IndicatorSpec] = {
    spec.name: spec for spec in INDICATOR_CATALOG
}


def spec_for(name: str) -> IndicatorSpec | None:
    """Return the catalog entry for an indicator name, if known."""
    return _CATALOG_BY_NAME.get(name)


def demo_indicator(spec: IndicatorSpec, notes: str = "") -> Indicator:
    """Build the clearly-labelled demo fallback for a catalog indicator."""
    return Indicator(
        name=spec.name,
        value=spec.demo_value,
        unit=spec.unit,
        label=spec.label,
        status=STATUS_DEMO,
        source=DEMO_SOURCE,
        period="demo snapshot",
        notes=notes,
    )


def unavailable_indicator(spec: IndicatorSpec, notes: str = "") -> Indicator:
    """Build an honest no-value indicator (never a fabricated number)."""
    return Indicator(
        name=spec.name,
        value=None,
        unit=spec.unit,
        label=spec.label,
        status=STATUS_UNAVAILABLE,
        source="",
        period="",
        notes=notes,
    )


def overall_status(indicators: list[Indicator]) -> str:
    """Aggregate per-indicator statuses into one snapshot-level status.

    live only -> "live"; any live + anything else -> "partial";
    no live + any demo -> "demo"; otherwise -> "unavailable".
    """
    statuses = {ind.status for ind in indicators}
    if not statuses:
        return SNAPSHOT_UNAVAILABLE
    if statuses == {STATUS_LIVE}:
        return SNAPSHOT_LIVE
    if STATUS_LIVE in statuses:
        return SNAPSHOT_PARTIAL
    if STATUS_DEMO in statuses:
        return SNAPSHOT_DEMO
    return SNAPSHOT_UNAVAILABLE


@dataclass(frozen=True)
class EconomicSnapshot:
    """The combined view every consumer of economic data receives."""

    indicators: dict[str, Indicator]
    status: str
    fetched_at: str
    #: indicator name -> why its live value is missing (e.g. "HTTP 500")
    fallback_reasons: dict[str, str] = field(default_factory=dict)

    def metric_values(self, names: list[str]) -> dict[str, float]:
        """Values for the requested indicators (live and demo; unavailable
        indicators have no value and are skipped)."""
        values: dict[str, float] = {}
        for name in names:
            indicator = self.indicators.get(name)
            if indicator is not None and indicator.value is not None:
                values[name] = indicator.value
        return values

    def sources(self, names: list[str]) -> list[str]:
        """Code-controlled provenance labels for the requested indicators,
        deduplicated, in catalog order. Unavailable indicators contribute
        nothing (they have no source)."""
        collected: list[str] = []
        for spec in INDICATOR_CATALOG:
            if spec.name not in names:
                continue
            indicator = self.indicators.get(spec.name)
            if indicator is not None and indicator.source and indicator.source not in collected:
                collected.append(indicator.source)
        return collected
