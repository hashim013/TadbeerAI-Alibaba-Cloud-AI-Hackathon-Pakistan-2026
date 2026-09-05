"""Pakistan Bureau of Statistics gateway client — essential commodity prices.

PBS publishes weekly Sensitive Price Indicator (SPI) reports on pbs.gov.pk
as PDF and Excel bulletins. This client targets an operator-configured
gateway serving PBS's weekly commodity prices in JSON format:

    PBS_COMMODITIES_BASE_URL=https://your-gateway.example.com/spi
    PBS_COMMODITIES_API_KEY=<optional>

When PBS_COMMODITIES_BASE_URL is not configured, the service reports the
client as inactive and relies on the verified official baseline snapshot
(clearly marked as demo/fallback). No live value is ever fabricated.
"""

from __future__ import annotations

import os
from typing import Any
from urllib.parse import urlparse

import httpx

from .client import EconomicDataError, env_timeout, fetch_json, parse_number
from .commodity_models import (
    DEFAULT_SCOPE,
    OFFICIAL_PBS_SOURCE,
    OFFICIAL_PBS_URL,
    CommodityPrice,
    compute_trend,
)
from .models import STATUS_LIVE, STATUS_UNAVAILABLE


class PBSCommodityClient:
    """Fetches official essential commodity prices from a configured gateway."""

    name = "pbs_commodities"

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
    def from_env(cls) -> "PBSCommodityClient | None":
        """Build the client when PBS_COMMODITIES_BASE_URL is set, else None."""
        base_url = os.getenv("PBS_COMMODITIES_BASE_URL", "").strip()
        if not base_url:
            return None
        return cls(base_url, api_key=os.getenv("PBS_COMMODITIES_API_KEY", ""))

    def _headers(self) -> dict[str, str] | None:
        if not self._api_key:
            return None
        return {"Authorization": f"Bearer {self._api_key}"}

    def _source_label(self) -> str:
        host = urlparse(self._base_url).hostname or self._base_url
        return f"{OFFICIAL_PBS_SOURCE} (via {host})"

    def fetch_commodities(self) -> list[CommodityPrice]:
        """Fetch and normalize commodity prices from the gateway."""
        try:
            payload = fetch_json(self._client, self._base_url, headers=self._headers())
        except EconomicDataError as exc:
            raise EconomicDataError(f"PBS commodities gateway failed: {exc}") from exc

        if not isinstance(payload, dict):
            raise EconomicDataError("PBS commodities gateway returned non-dict payload")

        items_raw = payload.get("items")
        if not isinstance(items_raw, list):
            raise EconomicDataError("Missing 'items' list in PBS commodities payload")

        period = str(payload.get("period") or "Latest Reported Week").strip()
        published_at = str(payload.get("published_at") or "").strip()
        source_label = self._source_label()

        results: list[CommodityPrice] = []
        for raw in items_raw:
            if not isinstance(raw, dict):
                continue
            item_id = str(raw.get("id") or "").strip()
            name = str(raw.get("name") or item_id).strip()
            if not item_id or not name:
                continue

            price = parse_number(raw.get("price"))
            if price is None:
                continue
            price = round(price, 2)

            prev = parse_number(raw.get("previous_price"))
            if prev is not None:
                prev = round(prev, 2)

            chg_abs, chg_pct, trend = compute_trend(price, prev)

            category = str(raw.get("category") or "Other").strip()
            unit = str(raw.get("unit") or "1 kg").strip()
            scope = str(raw.get("location_scope") or DEFAULT_SCOPE).strip()

            results.append(
                CommodityPrice(
                    id=item_id,
                    name=name,
                    normalized_name=str(raw.get("normalized_name") or item_id).strip().lower(),
                    category=category,
                    unit=unit,
                    price=price,
                    previous_price=prev,
                    change_absolute=chg_abs,
                    change_percent=chg_pct,
                    trend=trend,
                    location_scope=scope,
                    source_name=source_label,
                    source_url=OFFICIAL_PBS_URL,
                    source_type="official_statistical",
                    observation_period=period,
                    published_at=published_at,
                    data_status=STATUS_LIVE,
                    notes=str(raw.get("notes") or ""),
                    what_changed=str(raw.get("what_changed") or ""),
                    why_it_matters=str(raw.get("why_it_matters") or ""),
                    financial_impact_hint=str(raw.get("financial_impact_hint") or ""),
                )
            )

        return results
