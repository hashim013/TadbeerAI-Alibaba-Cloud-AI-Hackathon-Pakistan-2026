"""Pakistan Bureau of Statistics gateway client — monthly CPI inflation.

PBS publishes CPI on pbs.gov.pk as HTML pages and PDF bulletins; no
official machine-readable public API is documented today. Rather than
inventing an endpoint, this client targets an operator-configured gateway
that serves PBS's official monthly CPI figures as JSON:

    PBS_BASE_URL=https://your-gateway.example.com/cpi
    PBS_API_KEY=<only if the gateway requires one>

Expected JSON contract (documented here — the gateway must serve it)::

    {"inflation_rate_pct": {"value": 4.2, "period": "2026-07"}}

When PBS_BASE_URL is not configured the client reports the indicator
honestly as unavailable; the service then applies the demo fallback (or
the World Bank's annual inflation series, which is live by default).
No value is ever fabricated.
"""

from __future__ import annotations

import os
from urllib.parse import urlparse

import httpx

from .client import EconomicDataError, env_timeout, fetch_json, parse_number
from .models import (
    Indicator,
    IndicatorSpec,
    STATUS_LIVE,
    STATUS_UNAVAILABLE,
    spec_for,
)

#: indicators this gateway owns (PBS's own price statistics)
_INDICATORS: tuple[str, ...] = ("inflation_rate_pct",)


class PBSGatewayClient:
    """Fetches the official monthly CPI inflation from a configured gateway."""

    name = "pbs"

    def __init__(
        self,
        base_url: str,
        api_key: str = "",
        timeout: float | None = None,
        http_client: httpx.Client | None = None,
    ) -> None:
        self._base_url = base_url.rstrip("/")
        self._api_key = api_key.strip()
        self._timeout = env_timeout() if timeout is None else timeout
        self._client = http_client or httpx.Client(timeout=self._timeout)

    @classmethod
    def from_env(cls) -> "PBSGatewayClient | None":
        """Build the client when PBS_BASE_URL is configured, else none."""
        base_url = os.getenv("PBS_BASE_URL", "").strip()
        if not base_url:
            return None
        return cls(base_url, api_key=os.getenv("PBS_API_KEY", ""))

    def _headers(self) -> dict[str, str] | None:
        if not self._api_key:
            return None
        return {"Authorization": f"Bearer {self._api_key}"}

    def _source_label(self) -> str:
        host = urlparse(self._base_url).hostname or self._base_url
        return f"Pakistan Bureau of Statistics (via {host})"

    def fetch_indicators(self) -> list[Indicator]:
        try:
            payload = fetch_json(self._client, self._base_url, headers=self._headers())
        except EconomicDataError as exc:
            return [
                Indicator(
                    name=name,
                    value=None,
                    unit=(spec_for(name) or IndicatorSpec(name, name, 0.0, "")).unit,
                    label=(spec_for(name) or IndicatorSpec(name, name, 0.0, "")).label,
                    status=STATUS_UNAVAILABLE,
                    source="",
                    notes=f"PBS gateway unavailable ({exc})",
                )
                for name in _INDICATORS
            ]

        results: list[Indicator] = []
        for name in _INDICATORS:
            spec = spec_for(name) or IndicatorSpec(name, name, 0.0, "")
            entry = payload.get(name) if isinstance(payload, dict) else None
            value = parse_number(entry.get("value")) if isinstance(entry, dict) else None
            period = (
                str(entry.get("period") or "").strip()
                if isinstance(entry, dict)
                else ""
            )
            if value is None:
                results.append(
                    Indicator(
                        name=spec.name,
                        value=None,
                        unit=spec.unit,
                        label=spec.label,
                        status=STATUS_UNAVAILABLE,
                        source="",
                        notes="PBS gateway returned no usable value",
                    )
                )
                continue
            results.append(
                Indicator(
                    name=spec.name,
                    value=round(value, 2),
                    unit=spec.unit,
                    label=spec.label,
                    status=STATUS_LIVE,
                    source=self._source_label(),
                    period=period,
                    notes="monthly CPI, year-on-year",
                )
            )
        return results
