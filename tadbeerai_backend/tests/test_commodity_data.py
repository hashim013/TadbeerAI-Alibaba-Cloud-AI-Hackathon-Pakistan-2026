"""Tests for essential commodity models, PBS client, and service integration."""

from __future__ import annotations

from decimal import Decimal
import httpx
import pytest

from core.economic_data import (
    CommodityOverview,
    CommodityPrice,
    EconomicDataError,
    EconomicDataService,
    PBSCommodityClient,
    STATUS_DEMO,
    STATUS_LIVE,
    STATUS_UNAVAILABLE,
    compute_trend,
    get_default_commodities,
)
from core.scenarios import (
    EXPENSE_SHOCK,
    STATUS_CALCULATED,
    calculate_expense_shock,
    extract_scenario_parameters,
)


class TestCommodityModels:
    def test_compute_trend_increase(self):
        diff, pct, trend = compute_trend(120.0, 100.0)
        assert diff == 20.0
        assert pct == 20.0
        assert trend == "up"

    def test_compute_trend_decrease(self):
        diff, pct, trend = compute_trend(90.0, 100.0)
        assert diff == -10.0
        assert pct == -10.0
        assert trend == "down"

    def test_compute_trend_stable(self):
        diff, pct, trend = compute_trend(100.05, 100.0)
        assert trend == "stable"

    def test_compute_trend_missing_previous(self):
        diff, pct, trend = compute_trend(100.0, None)
        assert diff == 0.0
        assert pct == 0.0
        assert trend == "stable"

    def test_default_commodities_catalog(self):
        items = get_default_commodities(status=STATUS_DEMO)
        assert len(items) >= 12
        tomatoes = next(item for item in items if item.id == "tomatoes")
        assert tomatoes.name == "Tomatoes"
        assert tomatoes.category == "Vegetables"
        assert tomatoes.price > 0
        assert tomatoes.data_status == STATUS_DEMO
        assert "Pakistan Bureau of Statistics" in tomatoes.source_name
        assert tomatoes.source_url.startswith("https://")
        assert tomatoes.what_changed != ""
        assert tomatoes.why_it_matters != ""

    def test_to_dict_serialization(self):
        items = get_default_commodities()
        d = items[0].to_dict()
        assert isinstance(d, dict)
        assert "price" in d
        assert "source_name" in d
        assert "data_status" in d


class TestPBSCommodityClient:
    def test_fetch_commodities_success(self):
        sample_payload = {
            "period": "Week ended Sep 03, 2026",
            "published_at": "2026-09-03",
            "items": [
                {
                    "id": "tomatoes",
                    "name": "Tomatoes",
                    "category": "Vegetables",
                    "unit": "1 kg",
                    "price": 118.5,
                    "previous_price": 115.55,
                    "what_changed": "Up by 2.55%",
                    "why_it_matters": "Seasonal shift",
                }
            ],
        }

        def handler(request: httpx.Request) -> httpx.Response:
            assert request.headers.get("Authorization") == "Bearer secret-key"
            return httpx.Response(200, json=sample_payload)

        transport = httpx.MockTransport(handler)
        http_client = httpx.Client(transport=transport)
        client = PBSCommodityClient(
            base_url="https://gateway.example.com/spi",
            api_key="secret-key",
            http_client=http_client,
        )

        results = client.fetch_commodities()
        assert len(results) == 1
        item = results[0]
        assert item.id == "tomatoes"
        assert item.price == 118.5
        assert item.previous_price == 115.55
        assert item.trend == "up"
        assert item.data_status == STATUS_LIVE
        assert "via gateway.example.com" in item.source_name

    def test_fetch_commodities_invalid_payload_raises(self):
        transport = httpx.MockTransport(lambda req: httpx.Response(200, json={"error": "bad"}))
        http_client = httpx.Client(transport=transport)
        client = PBSCommodityClient(
            base_url="https://gateway.example.com/spi",
            http_client=http_client,
        )
        with pytest.raises(EconomicDataError):
            client.fetch_commodities()

    def test_from_env_none_when_unset(self, monkeypatch):
        monkeypatch.delenv("PBS_COMMODITIES_BASE_URL", raising=False)
        assert PBSCommodityClient.from_env() is None


class TestCommodityService:
    def test_service_snapshot_default_demo(self):
        service = EconomicDataService(allow_demo=True)
        overview = service.commodity_snapshot()
        assert overview.data_status == STATUS_DEMO
        assert len(overview.items) >= 12
        assert overview.period != ""
        assert "Pakistan Bureau of Statistics" in overview.source["name"]

    def test_service_snapshot_filtering(self):
        service = EconomicDataService(allow_demo=True)
        veg_overview = service.commodity_snapshot(category="Vegetables")
        assert len(veg_overview.items) > 0
        assert all(item.category == "Vegetables" for item in veg_overview.items)

        limited_overview = service.commodity_snapshot(limit=3)
        assert len(limited_overview.items) == 3

    def test_service_detail_found_and_not_found(self):
        service = EconomicDataService(allow_demo=True)
        tomatoes = service.commodity_detail("tomatoes")
        assert tomatoes is not None
        assert tomatoes.id == "tomatoes"

        missing = service.commodity_detail("nonexistent_item")
        assert missing is None

    def test_service_disallow_demo_returns_empty(self):
        service = EconomicDataService(allow_demo=False)
        overview = service.commodity_snapshot()
        assert overview.data_status == STATUS_UNAVAILABLE
        assert len(overview.items) == 0


class TestCommodityWhatIfIntegration:
    def test_extract_scenario_grocery_percent(self):
        params = extract_scenario_parameters("What if my grocery expenses increase by 10%?")
        assert params is not None
        assert params.scenario_type == EXPENSE_SHOCK
        assert params.pct_change == Decimal("10")

    def test_extract_scenario_food_amount_pkr(self):
        params = extract_scenario_parameters("What if food expenses rise by PKR 5,000?")
        assert params is not None
        assert params.scenario_type == EXPENSE_SHOCK
        assert params.amount_pkr == Decimal("5000")

    def test_calculate_expense_shock_with_amount(self):
        context = {
            "monthly_income": 100000,
            "monthly_expenses": 60000,
            "total_savings": 120000,
        }
        res = calculate_expense_shock(None, context, amount_pkr=Decimal("5000"))
        assert res.status == STATUS_CALCULATED
        assert res.outputs["additional_monthly_expense"] == Decimal("5000.00")
        assert res.outputs["new_monthly_expenses"] == Decimal("65000.00")
        assert res.outputs["projected_monthly_surplus"] == Decimal("35000.00")
        assert res.outputs["expense_shock_pct"] == Decimal("8.3")
