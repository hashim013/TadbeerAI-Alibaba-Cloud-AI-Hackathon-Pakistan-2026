"""Economic data service — combines providers into one honest snapshot.

Merge policy (first live result wins, provider priority = list order):
PBS gateway (freshest monthly CPI) > SBP gateway (policy rate / KIBOR) >
World Bank (keyless, always available). Indicators no provider could
supply fall back to the clearly-labelled demo snapshot — or, when demo
fallback is disabled, surface as honest ``unavailable`` entries with no
value. Live and demo values are never mixed silently: every indicator
carries its own status and code-controlled source.

A short in-process cache (default 10 minutes) avoids hammering the
public APIs during a demo.
"""

from __future__ import annotations

import os
import threading
import time
from datetime import datetime, timezone

from .client import EconomicDataClient
from .models import (
    INDICATOR_CATALOG,
    EconomicSnapshot,
    Indicator,
    demo_indicator,
    overall_status,
    unavailable_indicator,
)
from .pbs_client import PBSGatewayClient
from .sbp_client import SBPGatewayClient
from .worldbank_client import WorldBankClient

DEFAULT_CACHE_SECONDS = 600.0


def _env_cache_seconds() -> float:
    raw = os.getenv("ECONOMIC_DATA_CACHE_SECONDS", "").strip()
    if not raw:
        return DEFAULT_CACHE_SECONDS
    try:
        value = float(raw)
    except ValueError:
        return DEFAULT_CACHE_SECONDS
    return value if value > 0 else DEFAULT_CACHE_SECONDS


def _env_allow_demo() -> bool:
    raw = os.getenv("ECONOMIC_DATA_ALLOW_DEMO", "").strip().lower()
    if not raw:
        return True
    return raw not in ("0", "false", "no", "off")


class EconomicDataService:
    """Builds and caches the combined economic snapshot."""

    def __init__(
        self,
        providers: list[EconomicDataClient] | None = None,
        cache_seconds: float | None = None,
        allow_demo: bool | None = None,
    ) -> None:
        self._providers = list(providers or [])
        self._cache_seconds = (
            _env_cache_seconds() if cache_seconds is None else cache_seconds
        )
        self._allow_demo = _env_allow_demo() if allow_demo is None else allow_demo
        self._lock = threading.Lock()
        self._cache: EconomicSnapshot | None = None
        self._cached_at: float = 0.0

    @property
    def allow_demo(self) -> bool:
        return self._allow_demo

    def snapshot(self) -> EconomicSnapshot:
        """Return the (cached) combined snapshot."""
        now = time.monotonic()
        with self._lock:
            if (
                self._cache is not None
                and now - self._cached_at < self._cache_seconds
            ):
                return self._cache
            built = self._build_snapshot()
            self._cache = built
            self._cached_at = now
            return built

    def invalidate_cache(self) -> None:
        """Drop the cached snapshot (used by tests and manual refresh)."""
        with self._lock:
            self._cache = None
            self._cached_at = 0.0

    # ------------------------------------------------------------------ #
    # merge logic
    # ------------------------------------------------------------------ #

    def _build_snapshot(self) -> EconomicSnapshot:
        fetched: dict[str, Indicator] = {}
        reasons: dict[str, str] = {}

        for provider in self._providers:
            try:
                results = provider.fetch_indicators()
            except Exception as exc:  # noqa: BLE001 — a provider must never crash us
                print(
                    f"[EconomicData] provider "
                    f"{getattr(provider, 'name', '?')} failed: "
                    f"{type(exc).__name__}: {exc}"
                )
                continue
            for indicator in results:
                if indicator.status != "live":
                    if indicator.name not in reasons and indicator.notes:
                        reasons[indicator.name] = indicator.notes
                    continue
                if indicator.name not in fetched:
                    fetched[indicator.name] = indicator

        final: dict[str, Indicator] = {}
        fallback_reasons: dict[str, str] = {}
        for spec in INDICATOR_CATALOG:
            if spec.name in fetched:
                final[spec.name] = fetched[spec.name]
                continue
            reason = reasons.get(spec.name, "")
            if self._allow_demo:
                if reason:
                    fallback_reasons[spec.name] = reason
                final[spec.name] = demo_indicator(spec, notes=reason)
            else:
                final[spec.name] = unavailable_indicator(spec, notes=reason)

        return EconomicSnapshot(
            indicators=final,
            status=overall_status(list(final.values())),
            fetched_at=datetime.now(timezone.utc).isoformat(),
            fallback_reasons=fallback_reasons,
        )


# ---------------------------------------------------------------------- #
# process-wide singleton (tests swap it via set_economic_service)
# ---------------------------------------------------------------------- #

_SERVICE: EconomicDataService | None = None
_SERVICE_LOCK = threading.Lock()


def _default_service() -> EconomicDataService:
    """Production default: PBS gateway (if configured), SBP gateway (if
    configured) and the keyless World Bank API."""
    providers: list[EconomicDataClient] = []
    pbs = PBSGatewayClient.from_env()
    if pbs is not None:
        providers.append(pbs)
    sbp = SBPGatewayClient.from_env()
    if sbp is not None:
        providers.append(sbp)
    providers.append(WorldBankClient.from_env())
    return EconomicDataService(providers=providers)


def get_economic_service() -> EconomicDataService:
    """Return the process-wide economic data service (lazily built)."""
    global _SERVICE
    with _SERVICE_LOCK:
        if _SERVICE is None:
            _SERVICE = _default_service()
        return _SERVICE


def set_economic_service(service: EconomicDataService | None) -> None:
    """Override the service (used by tests to stay hermetic)."""
    global _SERVICE
    with _SERVICE_LOCK:
        _SERVICE = service


def reset_economic_service() -> None:
    """Drop any override and rebuild from the environment on next use."""
    set_economic_service(None)
