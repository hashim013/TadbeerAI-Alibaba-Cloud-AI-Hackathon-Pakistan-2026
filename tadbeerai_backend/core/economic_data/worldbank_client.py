"""World Bank client — the verified live provider for Pakistan indicators.

Uses the public, documented World Bank API (no API key required):
https://api.worldbank.org/v2/country/PAK/indicator/<code>?format=json&mrnev=1

Response contract (verified against the live API)::

    [{"page":1,...,"lastupdated":"2026-07-13"},
     [{"indicator":{"id":"FP.CPI.TOTL.ZG","value":"..."},
       "country":{...},"countryiso3code":"PAK",
       "date":"2025","value":3.54555214890893,...}]]

``mrnev=1`` returns the most recent non-empty observation. Series values
are rounded to 2 decimals so metrics stay readable (e.g. 26.46 USD bn).

World Bank series are annual (period averages / annual totals) — the
``period`` and ``notes`` fields make that explicit; values are never
presented as today's spot figures.
"""

from __future__ import annotations

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
}

_BASE_URL = "https://api.worldbank.org/v2"


class WorldBankClient:
    """Fetches the four World Bank–sourced Pakistan indicators."""

    name = "worldbank"

    def __init__(
        self,
        timeout: float | None = None,
        http_client: httpx.Client | None = None,
    ) -> None:
        self._timeout = env_timeout() if timeout is None else timeout
        self._client = http_client or httpx.Client(timeout=self._timeout)

    @classmethod
    def from_env(cls) -> "WorldBankClient":
        """Build the default client (public API — no key, no URL config)."""
        return cls()

    def fetch_indicators(self) -> list[Indicator]:
        results: list[Indicator] = []
        for indicator_name, (series_code, scale, note) in _SERIES.items():
            spec = spec_for(indicator_name)
            if spec is None:  # pragma: no cover — catalog and series stay in sync
                continue
            url = (
                f"{_BASE_URL}/country/PAK/indicator/{series_code}"
                "?format=json&mrnev=1"
            )
            try:
                payload = fetch_json(self._client, url)
                observation = self._latest_observation(payload)
                value = parse_number(observation.get("value"))
                if value is None:
                    raise EconomicDataError("no data point in response")
                period = str(observation.get("date") or "").strip()
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

            results.append(
                Indicator(
                    name=spec.name,
                    value=round(value * scale, 2),
                    unit=spec.unit,
                    label=spec.label,
                    status=STATUS_LIVE,
                    source=f"World Bank API ({series_code})",
                    period=period,
                    notes=note,
                )
            )
        return results

    @staticmethod
    def _latest_observation(payload: object) -> dict:
        """Extract the newest observation from the World Bank envelope."""
        if not isinstance(payload, list) or len(payload) < 2:
            raise EconomicDataError("unexpected response shape")
        observations = payload[1]
        if not isinstance(observations, list) or not observations:
            raise EconomicDataError("empty observation list")
        first = observations[0]
        if not isinstance(first, dict):
            raise EconomicDataError("observation is not an object")
        return first
