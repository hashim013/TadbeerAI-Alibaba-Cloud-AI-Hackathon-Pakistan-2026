"""Provider-neutral interface for economic data clients.

Clients fetch indicators from one external source each. They never raise
on failure: an indicator they own but could not fetch comes back as an
``unavailable`` :class:`Indicator` carrying the reason, so the service can
apply the honest fallback policy (demo or unavailable — never fabricated).
"""

from __future__ import annotations

import math
from typing import Any, Protocol, runtime_checkable

import httpx

from .models import Indicator

DEFAULT_TIMEOUT_SECONDS = 10.0


class EconomicDataError(Exception):
    """Raised when an external economic data call fails."""


@runtime_checkable
class EconomicDataClient(Protocol):
    """Interface every economic data provider implements."""

    name: str

    def fetch_indicators(self) -> list[Indicator]:
        """Return the indicators this provider owns, each live or
        unavailable (never raising)."""
        ...


def parse_number(value: Any) -> float | None:
    """Coerce a provider value into a finite float, or None."""
    if isinstance(value, bool):
        return None
    if isinstance(value, (int, float)):
        number = float(value)
        return number if math.isfinite(number) else None
    if isinstance(value, str):
        text = value.strip().replace(",", "")
        if not text:
            return None
        try:
            number = float(text)
        except ValueError:
            return None
        return number if math.isfinite(number) else None
    return None


def fetch_json(
    client: httpx.Client,
    url: str,
    *,
    headers: dict[str, str] | None = None,
) -> Any:
    """GET a JSON document through the given client.

    Raises :class:`EconomicDataError` on timeout, transport errors,
    non-200 status codes and malformed JSON — callers translate that into
    honest ``unavailable`` indicators.
    """
    try:
        response = client.get(url, headers=headers)
    except httpx.TimeoutException as exc:
        raise EconomicDataError(f"timeout calling {url}") from exc
    except httpx.HTTPError as exc:
        raise EconomicDataError(f"transport error calling {url}: {exc}") from exc

    if response.status_code != 200:
        raise EconomicDataError(f"HTTP {response.status_code} from {url}")

    try:
        return response.json()
    except ValueError as exc:
        raise EconomicDataError(f"malformed JSON from {url}") from exc


def env_timeout(default: float = DEFAULT_TIMEOUT_SECONDS) -> float:
    """Read ECONOMIC_DATA_TIMEOUT_SECONDS from the environment."""
    import os

    raw = os.getenv("ECONOMIC_DATA_TIMEOUT_SECONDS", "").strip()
    if not raw:
        return default
    try:
        value = float(raw)
    except ValueError:
        return default
    return value if value > 0 else default
