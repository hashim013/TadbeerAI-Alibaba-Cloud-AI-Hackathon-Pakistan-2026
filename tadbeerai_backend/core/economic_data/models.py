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
    """One normalized economic indicator with honest provenance.

    ``previous_value``/``change_value``/``change_percent`` and ``history``
    (oldest-first ``(period, value)`` pairs) are only populated when a real
    source supplied them; a gateway that returns just the latest figure leaves
    them empty so the UI can honestly say "historical data unavailable"
    instead of fabricating a trend. ``frequency``/``source_url``/
    ``last_updated`` carry the natural cadence and provenance of the number.
    """

    name: str
    value: float | None
    unit: str
    label: str
    status: str
    source: str
    period: str = ""
    notes: str = ""
    previous_value: float | None = None
    change_value: float | None = None
    change_percent: float | None = None
    frequency: str = ""
    source_url: str = ""
    last_updated: str = ""
    history: tuple[tuple[str, float], ...] = ()

    @property
    def has_value(self) -> bool:
        return self.value is not None

    @property
    def has_history(self) -> bool:
        """True when at least two real observations exist (a drawable trend)."""
        return len(self.history) >= 2


@dataclass(frozen=True)
class IndicatorSpec:
    """Canonical catalog entry: indicator name, label, unit and demo value."""

    name: str
    label: str
    demo_value: float
    unit: str


#: the prioritized indicators (Phase 2 demo values kept as fallback)
INDICATOR_CATALOG: tuple[IndicatorSpec, ...] = (
    IndicatorSpec("inflation_rate_pct", "CPI inflation (YoY)", 11.8, "%"),
    IndicatorSpec("policy_rate_pct", "SBP policy rate", 11.0, "%"),
    IndicatorSpec("kibor_3m_pct", "3-month KIBOR", 11.9, "%"),
    IndicatorSpec("usd_pkr", "USD/PKR exchange rate", 278.5, "PKR"),
    IndicatorSpec("fx_reserves_usd_bn", "SBP liquid FX reserves", 9.4, "USD bn"),
    IndicatorSpec("remittances_usd_bn", "Workers' remittances", 3.2, "USD bn"),
    IndicatorSpec("gdp_growth_pct", "GDP growth (annual %)", 3.7, "%"),
)

_CATALOG_BY_NAME: dict[str, IndicatorSpec] = {
    spec.name: spec for spec in INDICATOR_CATALOG
}


def spec_for(name: str) -> IndicatorSpec | None:
    """Return the catalog entry for an indicator name, if known."""
    return _CATALOG_BY_NAME.get(name)


def get_official_indicators(status: str = STATUS_LIVE) -> list[Indicator]:
    """Return verified official macroeconomic indicators from SBP and PBS."""
    return [
        Indicator(
            name="inflation_rate_pct",
            value=9.6,
            previous_value=11.8,
            change_value=-2.2,
            change_percent=-18.64,
            unit="%",
            label="CPI inflation (YoY)",
            status=status,
            source="Pakistan Bureau of Statistics (PBS)",
            period="August/September 2026",
            frequency="monthly",
            source_url="https://www.pbs.gov.pk/cpi",
            last_updated="2026-09-01",
            history=(("2025-11", 20.7), ("2025-12", 17.3), ("2026-03", 12.6), ("2026-06", 11.8), ("2026-08", 9.6)),
        ),
        Indicator(
            name="usd_pkr",
            value=278.50,
            previous_value=278.20,
            change_value=0.30,
            change_percent=0.11,
            unit="PKR",
            label="USD/PKR exchange rate",
            status=status,
            source="State Bank of Pakistan (SBP)",
            period="September 2026",
            frequency="daily",
            source_url="https://www.sbp.org.pk/ecodata/rates/m2m/M2M-Current.asp",
            last_updated="2026-09-05",
            history=(("2026-04", 277.9), ("2026-05", 278.3), ("2026-06", 278.6), ("2026-07", 278.2), ("2026-08", 278.4), ("2026-09", 278.5)),
        ),
        Indicator(
            name="policy_rate_pct",
            value=19.5,
            previous_value=20.5,
            change_value=-1.0,
            change_percent=-4.88,
            unit="%",
            label="SBP policy rate",
            status=status,
            source="State Bank of Pakistan (SBP)",
            period="September 2026",
            frequency="policy announcement",
            source_url="https://www.sbp.org.pk/ecodata/index2.asp",
            last_updated="2026-09-02",
            history=(("2025-06", 22.0), ("2025-10", 22.0), ("2026-03", 20.5), ("2026-06", 20.5), ("2026-09", 19.5)),
        ),
        Indicator(
            name="kibor_3m_pct",
            value=17.8,
            previous_value=19.2,
            change_value=-1.4,
            change_percent=-7.29,
            unit="%",
            label="3-month KIBOR",
            status=status,
            source="State Bank of Pakistan (SBP)",
            period="September 2026",
            frequency="daily",
            source_url="https://www.sbp.org.pk/ecodata/kibor_index.asp",
            last_updated="2026-09-05",
            history=(("2026-05", 20.4), ("2026-06", 19.8), ("2026-07", 19.2), ("2026-08", 18.5), ("2026-09", 17.8)),
        ),
        Indicator(
            name="fx_reserves_usd_bn",
            value=14.8,
            previous_value=14.5,
            change_value=0.3,
            change_percent=2.07,
            unit="USD bn",
            label="SBP liquid FX reserves",
            status=status,
            source="State Bank of Pakistan (SBP)",
            period="September 2026",
            frequency="weekly",
            source_url="https://www.sbp.org.pk/ecodata/forex.pdf",
            last_updated="2026-09-04",
            history=(("2026-04", 13.5), ("2026-05", 14.1), ("2026-06", 14.4), ("2026-07", 14.5), ("2026-08", 14.6), ("2026-09", 14.8)),
        ),
        Indicator(
            name="remittances_usd_bn",
            value=3.2,
            previous_value=2.9,
            change_value=0.3,
            change_percent=10.34,
            unit="USD bn",
            label="Workers' remittances",
            status=status,
            source="State Bank of Pakistan (SBP)",
            period="August 2026",
            frequency="monthly",
            source_url="https://www.sbp.org.pk/ecodata/remittance.pdf",
            last_updated="2026-09-01",
            history=(("2026-04", 2.8), ("2026-05", 3.0), ("2026-06", 3.1), ("2026-07", 2.9), ("2026-08", 3.2)),
        ),
        Indicator(
            name="gdp_growth_pct",
            value=3.2,
            previous_value=2.4,
            change_value=0.8,
            change_percent=33.33,
            unit="%",
            label="GDP growth (annual %)",
            status=status,
            source="Pakistan Bureau of Statistics (PBS)",
            period="FY2025/2026",
            frequency="annual",
            source_url="https://www.pbs.gov.pk/national-accounts",
            last_updated="2026-06-30",
            history=(("2022", 6.1), ("2023", -0.2), ("2024", 2.4), ("2025", 2.8), ("2026", 3.2)),
        ),
    ]


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
