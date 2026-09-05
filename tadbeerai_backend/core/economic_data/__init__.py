"""Economic data layer — normalized Pakistan economic indicators.

Public surface::

    get_economic_service()  -> EconomicDataService   (process singleton)
    service.snapshot()       -> EconomicSnapshot     (live/demo/unavailable)
    Indicator                (name, value, unit, label, status, source, period)

Source metadata is code-controlled end to end: the LLM never generates,
modifies or sees its own provenance — it only interprets the values this
layer hands it.
"""

from __future__ import annotations

from .client import (
    EconomicDataClient,
    EconomicDataError,
    fetch_json,
    parse_number,
)
from .models import (
    DEMO_SOURCE,
    INDICATOR_CATALOG,
    SNAPSHOT_DEMO,
    SNAPSHOT_LIVE,
    SNAPSHOT_PARTIAL,
    SNAPSHOT_UNAVAILABLE,
    STATUS_DEMO,
    STATUS_LIVE,
    STATUS_UNAVAILABLE,
    EconomicSnapshot,
    Indicator,
    IndicatorSpec,
    overall_status,
    spec_for,
)
from .commodity_models import (
    DEFAULT_SCOPE,
    OFFICIAL_PBS_SOURCE,
    OFFICIAL_PBS_URL,
    CommodityOverview,
    CommodityPrice,
    compute_trend,
    get_default_commodities,
)
from .pbs_commodity_client import PBSCommodityClient
from .pbs_client import PBSGatewayClient
from .sbp_client import SBPGatewayClient
from .service import (
    EconomicDataService,
    get_economic_service,
    reset_economic_service,
    set_economic_service,
)
from .worldbank_client import WorldBankClient

__all__ = [
    "CommodityOverview",
    "CommodityPrice",
    "DEFAULT_SCOPE",
    "DEMO_SOURCE",
    "EconomicDataClient",
    "EconomicDataError",
    "EconomicDataService",
    "EconomicSnapshot",
    "INDICATOR_CATALOG",
    "Indicator",
    "IndicatorSpec",
    "OFFICIAL_PBS_SOURCE",
    "OFFICIAL_PBS_URL",
    "PBSCommodityClient",
    "PBSGatewayClient",
    "SBPGatewayClient",
    "SNAPSHOT_DEMO",
    "SNAPSHOT_LIVE",
    "SNAPSHOT_PARTIAL",
    "SNAPSHOT_UNAVAILABLE",
    "STATUS_DEMO",
    "STATUS_LIVE",
    "STATUS_UNAVAILABLE",
    "WorldBankClient",
    "compute_trend",
    "fetch_json",
    "get_default_commodities",
    "get_economic_service",
    "overall_status",
    "parse_number",
    "reset_economic_service",
    "set_economic_service",
    "spec_for",
]
