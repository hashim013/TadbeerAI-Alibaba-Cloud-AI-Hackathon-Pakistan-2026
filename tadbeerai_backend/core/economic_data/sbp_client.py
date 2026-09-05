"""State Bank of Pakistan gateway client — policy rate and KIBOR.

SBP's public data services (sbp.org.pk ECODATA pages, the EasyData portal
at easydata.sbp.org.pk) publish these indicators as HTML/PDF through an
Oracle APEX portal — there is no documented public JSON API today. Rather
than inventing or scraping an endpoint, this client targets an
operator-configured gateway that serves SBP's official figures as JSON:

    SBP_BASE_URL=https://your-gateway.example.com/indicators
    SBP_API_KEY=<only if the gateway requires one>

Expected JSON contract (documented here — the gateway must serve it)::

    {
      "policy_rate_pct": {"value": 11.5, "period": "2026-08-01"},
      "kibor_3m_pct":    {"value": 11.9, "period": "2026-09-02"}
    }

When SBP_BASE_URL is not configured the client reports both indicators
honestly as unavailable; the service then applies the demo fallback.
No value is ever fabricated.
"""

from __future__ import annotations

import os
from urllib.parse import urlparse

import httpx

from .client import EconomicDataError, env_timeout, fetch_json, parse_number
from .models import Indicator, STATUS_LIVE, STATUS_UNAVAILABLE, spec_for

#: indicators this gateway owns (SBP's own rates)
_INDICATORS: tuple[str, ...] = ("policy_rate_pct", "kibor_3m_pct")


class SBPGatewayClient:
    """Fetches SBP policy rate and 3-month KIBOR from a configured gateway."""

    name = "sbp"

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
    def from_env(cls) -> "SBPGatewayClient | None":
        """Build the client when SBP_BASE_URL is configured, else None."""
        base_url = os.getenv("SBP_BASE_URL", "").strip()
        if not base_url:
            return None
        return cls(base_url, api_key=os.getenv("SBP_API_KEY", ""))

    def _headers(self) -> dict[str, str] | None:
        if not self._api_key:
            return None
        return {"Authorization": f"Bearer {self._api_key}"}

    def _source_label(self) -> str:
        host = urlparse(self._base_url).hostname or self._base_url
        return f"State Bank of Pakistan (via {host})"

    def fetch_indicators(self) -> list[Indicator]:
        results: list[Indicator] = []
        try:
            payload = fetch_json(self._client, self._base_url, headers=self._headers())
        except EconomicDataError as exc:
            return [
                Indicator(
                    name=name,
                    value=None,
                    unit=(spec_for(name) or _no_spec(name)).unit,
                    label=(spec_for(name) or _no_spec(name)).label,
                    status=STATUS_UNAVAILABLE,
                    source="",
                    notes=f"SBP gateway unavailable ({exc})",
                )
                for name in _INDICATORS
            ]

        for name in _INDICATORS:
            spec = spec_for(name) or _no_spec(name)
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
                        notes="SBP gateway returned no usable value",
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
                )
            )
        return results


def _no_spec(name: str):  # pragma: no cover — catalog and clients stay in sync
    from .models import IndicatorSpec

    return IndicatorSpec(name, name, 0.0, "")
