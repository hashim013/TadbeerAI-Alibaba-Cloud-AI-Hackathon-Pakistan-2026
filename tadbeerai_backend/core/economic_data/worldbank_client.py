"""World Bank client — the verified live provider for Pakistan indicators.

Uses the public, documented World Bank API (no API key required). The
date-range form returns every annual observation in the window (newest
first) in the same envelope the client already parsed::

    https://api.worldbank.org/v2/country/PAK/indicator/<code>
        ?format=json&date=<start>:<end>&per_page=50

    [{"page":1,...,"lastupdated":"2026-07-13"},
     [{"indicator":{"id":"FP.CPI.TOTL.ZG","value":"..."},
       "countryiso3code":"PAK","date":"2025","value":3.54555214890893,...},
      {... "date":"2024" ...}, ...]]

From those observations the client derives the latest value, the previous
year's value, the year-on-year change and an oldest-first history series, so
the headline number and the last chart point always come from the SAME real
observation. Years without data carry a null value and are skipped
(most-recent-non-empty semantics). Series values are rounded to 2 decimals.

World Bank series are annual (period averages / annual totals) — the
``period``, ``frequency`` and ``notes`` fields make that explicit; values are
never presented as today's spot figures.
"""

from __future__ import annotations

import os
from datetime import datetime

import httpx

from .client import EconomicDataError, env_timeout, fetch_json, parse_number
from .models import Indicator, STATUS_LIVE, STATUS_UNAVAILABLE, spec_for

#: canonical indicator -> (series code, scaling, extra note)
_SERIES: dict[str, tuple[str, float, str]] = {
    "inflation_rate_pct": (
        "FP.CPI.TOTL.ZG",
        1.0,
        "annual average",
    ),
    "usd_pkr": (
        "PA.NUS.FCRF",
        1.0,
        "annual period average, not today's spot rate",
    ),
    "fx_reserves_usd_bn": (
        "FI.RES.TOTL.CD",
        1e-9,
        "total reserves including gold",
    ),
    "remittances_usd_bn": (
        "BX.TRF.PWKR.CD.DT",
        1e-9,
        "annual total",
    ),
    "gdp_growth_pct": (
        "NY.GDP.MKTP.KD.ZG",
        1.0,
        "annual real growth rate",
    ),
}

_DEFAULT_BASE_URL = "https://api.worldbank.org/v2"

#: how many annual observations to request for the trend history
_HISTORY_YEARS = 11


class WorldBankClient:
    """Fetches the World Bank–sourced Pakistan indicators with real history."""

    name = "worldbank"

    def __init__(
        self,
        base_url: str = _DEFAULT_BASE_URL,
        timeout: float | None = None,
        http_client: httpx.Client | None = None,
    ) -> None:
        self._base_url = base_url.rstrip("/")
        self._timeout = env_timeout() if timeout is None else timeout
        self._client = http_client or httpx.Client(timeout=self._timeout)

    @classmethod
    def from_env(cls) -> "WorldBankClient":
        """Build the client (public API — no key). The base URL may be
        overridden with WORLD_BANK_BASE_URL; it defaults to the official API."""
        base_url = os.getenv("WORLD_BANK_BASE_URL", "").strip() or _DEFAULT_BASE_URL
        return cls(base_url)

    def fetch_indicators(self) -> list[Indicator]:
        end_year = datetime.now().year - 1
        start_year = end_year - (_HISTORY_YEARS - 1)
        results: list[Indicator] = []
        for indicator_name, (series_code, scale, note) in _SERIES.items():
            spec = spec_for(indicator_name)
            if spec is None:  # pragma: no cover — catalog and series stay in sync
                continue
            url = (
                f"{self._base_url}/country/PAK/indicator/{series_code}"
                f"?format=json&date={start_year}:{end_year}&per_page=50"
            )
            try:
                payload = fetch_json(self._client, url)
                last_updated, observations = self._envelope(payload)
                series = self._clean_series(observations, scale)
                if not series:
                    raise EconomicDataError("no data point in response")
            except EconomicDataError as exc:
                results.append(
                    Indicator(
                        name=spec.name,
                        value=None,
                        unit=spec.unit,
                        label=spec.label,
                        status=STATUS_UNAVAILABLE,
                        source="",
                        notes=f"World Bank API unavailable ({exc})",
                    )
                )
                continue

            # ``series`` is newest-first, already scaled and rounded; the
            # headline value and the last history point are the same observation.
            newest_period, value = series[0]
            previous_value = series[1][1] if len(series) > 1 else None
            change_value = (
                round(value - previous_value, 2)
                if previous_value is not None
                else None
            )
            change_percent = (
                round((value - previous_value) / previous_value * 100, 2)
                if previous_value not in (None, 0)
                else None
            )

            results.append(
                Indicator(
                    name=spec.name,
                    value=value,
                    unit=spec.unit,
                    label=spec.label,
                    status=STATUS_LIVE,
                    source=f"World Bank API ({series_code})",
                    period=newest_period,
                    notes=note,
                    previous_value=previous_value,
                    change_value=change_value,
                    change_percent=change_percent,
                    frequency="annual",
                    source_url=(
                        f"{self._base_url}/country/PAK/indicator/{series_code}"
                    ),
                    last_updated=last_updated or newest_period,
                    history=tuple(reversed(series)),  # oldest-first
                )
            )
        return results

    @staticmethod
    def _envelope(payload: object) -> tuple[str, list]:
        """Split the World Bank envelope into (lastupdated, observations)."""
        if not isinstance(payload, list) or len(payload) < 2:
            raise EconomicDataError("unexpected response shape")
        meta = payload[0] if isinstance(payload[0], dict) else {}
        observations = payload[1]
        if not isinstance(observations, list):
            raise EconomicDataError("unexpected response shape")
        if not observations:
            raise EconomicDataError("empty observation list")
        last_updated = str(meta.get("lastupdated") or "").strip()
        return last_updated, observations

    @staticmethod
    def _clean_series(
        observations: list, scale: float
    ) -> list[tuple[str, float]]:
        """Newest-first ``(period, value)`` pairs with null/invalid values
        dropped. The World Bank returns observations newest-first; years
        without data carry a null value and are skipped so the latest real
        observation wins (most-recent-non-empty semantics)."""
        series: list[tuple[str, float]] = []
        for observation in observations:
            if not isinstance(observation, dict):
                continue
            value = parse_number(observation.get("value"))
            if value is None:
                continue
            period = str(observation.get("date") or "").strip()
            if not period:
                continue
            series.append((period, round(value * scale, 2)))
        return series
