"""Economic data layer tests — every external HTTP call is mocked.

Covers the Phase 3A spec matrix: World Bank/SBP/PBS parsing, malformed
responses, timeouts, HTTP errors, unavailable indicators, partial live
snapshots, demo fallback, mixed live+demo, code-controlled provenance,
the graph integration (economic agent + risk & impact) and the API
response contract. No test touches the network.
"""

from __future__ import annotations

import httpx
import pytest

from core.assistant_service import AssistantService
from core.economic_data import (
    DEMO_SOURCE,
    EconomicDataService,
    Indicator,
    WorldBankClient,
    set_economic_service,
)
from core.economic_data.models import (
    INDICATOR_CATALOG,
    STATUS_DEMO,
    STATUS_LIVE,
    STATUS_UNAVAILABLE,
    overall_status,
)
from core.economic_data.pbs_client import PBSGatewayClient
from core.economic_data.sbp_client import SBPGatewayClient
from core.llm import LLMRegistry
from tests.conftest import (
    COMPOSER_MARKER,
    ECONOMIC_MARKER,
    PERSONAL_FINANCE_MARKER,
    RISK_IMPACT_MARKER,
    ScriptedAgentProvider,
)

CONTEXT = {
    "monthly_income": 80000,
    "monthly_expenses": 55000,
    "total_savings": 200000,
}


# --------------------------------------------------------------------------- #
# helpers
# --------------------------------------------------------------------------- #


def _wb_envelope(code: str, name: str, value, date: str = "2025"):
    """Verified World Bank API response shape (per-series)."""
    return [
        {
            "page": 1,
            "pages": 1,
            "per_page": 50,
            "total": 1,
            "lastupdated": "2026-07-13",
        },
        [
            {
                "indicator": {"id": code, "value": name},
                "country": {"id": "PK", "value": "Pakistan"},
                "countryiso3code": "PAK",
                "date": date,
                "value": value,
            }
        ],
    ]


_WB_LIVE_PAYLOADS = {
    "FP.CPI.TOTL.ZG": _wb_envelope(
        "FP.CPI.TOTL.ZG", "Inflation, consumer prices (annual %)", 3.54555214890893
    ),
    "PA.NUS.FCRF": _wb_envelope(
        "PA.NUS.FCRF",
        "Official exchange rate (LCU per US$, period average)",
        281.143001173202,
    ),
    "FI.RES.TOTL.CD": _wb_envelope(
        "FI.RES.TOTL.CD", "Total reserves (includes gold, current US$)", 26455819675.7312
    ),
    "BX.TRF.PWKR.CD.DT": _wb_envelope(
        "BX.TRF.PWKR.CD.DT", "Personal remittances, received (current US$)", 40478000000
    ),
}


def _mock_client(payloads: dict[str, object], status: int = 200) -> httpx.Client:
    """httpx client whose transport serves canned payloads by URL substring."""

    def handler(request: httpx.Request) -> httpx.Response:
        for key, payload in payloads.items():
            if key in str(request.url):
                if isinstance(payload, Exception):
                    raise payload
                return httpx.Response(status, json=payload)
        return httpx.Response(404, json={"message": "unexpected url"})

    return httpx.Client(transport=httpx.MockTransport(handler))


def _live_wb_client(payloads: dict[str, object] | None = None) -> WorldBankClient:
    return WorldBankClient(
        http_client=_mock_client(payloads or _WB_LIVE_PAYLOADS)
    )


def _live(name: str, value: float, source: str, period: str = "2025") -> Indicator:
    spec = next(s for s in INDICATOR_CATALOG if s.name == name)
    return Indicator(
        name=name,
        value=value,
        unit=spec.unit,
        label=spec.label,
        status=STATUS_LIVE,
        source=source,
        period=period,
    )


class FakeClient:
    """Minimal scripted provider (counts fetches for cache tests)."""

    name = "fake"

    def __init__(self, indicators):
        self.indicators = list(indicators)
        self.fetches = 0

    def fetch_indicators(self) -> list[Indicator]:
        self.fetches += 1
        return list(self.indicators)


class ExplodingClient:
    """Provider whose fetch crashes — must never propagate."""

    name = "exploding"

    def fetch_indicators(self) -> list[Indicator]:
        raise RuntimeError("provider exploded")


def _service(*providers, allow_demo=None) -> EconomicDataService:
    return EconomicDataService(
        providers=list(providers), allow_demo=allow_demo, cache_seconds=0
    )


def _chat_service(provider, **kwargs) -> AssistantService:
    return AssistantService(LLMRegistry(primary=provider, **kwargs))


# --------------------------------------------------------------------------- #
# World Bank client
# --------------------------------------------------------------------------- #


class TestWorldBankParsing:
    def test_live_series_parsed_and_scaled(self):
        indicators = {ind.name: ind for ind in _live_wb_client().fetch_indicators()}

        assert indicators["inflation_rate_pct"].value == 3.55
        assert indicators["usd_pkr"].value == 281.14
        assert indicators["fx_reserves_usd_bn"].value == 26.46  # USD -> USD bn
        assert indicators["remittances_usd_bn"].value == 40.48
        for ind in indicators.values():
            assert ind.status == STATUS_LIVE
            assert ind.period == "2025"
            assert ind.source.startswith("World Bank API (")
        assert indicators["inflation_rate_pct"].source == "World Bank API (FP.CPI.TOTL.ZG)"

    def test_malformed_response_degrades_per_indicator(self):
        client = _live_wb_client({"FP.CPI.TOTL.ZG": {"unexpected": True}})
        results = client.fetch_indicators()

        inflation = next(r for r in results if r.name == "inflation_rate_pct")
        assert inflation.status == STATUS_UNAVAILABLE
        assert inflation.value is None
        assert "unexpected response shape" in inflation.notes

    def test_http_timeout_marks_unavailable(self):
        payloads = {
            code: httpx.ConnectTimeout("timed out") for code in _WB_LIVE_PAYLOADS
        }
        results = _live_wb_client(payloads).fetch_indicators()

        assert results
        for ind in results:
            assert ind.status == STATUS_UNAVAILABLE
            assert "timeout" in ind.notes.lower()

    def test_http_error_marks_unavailable(self):
        client = WorldBankClient(http_client=_mock_client({"FP.CPI.TOTL.ZG": {}}, status=500))
        results = client.fetch_indicators()

        inflation = next(r for r in results if r.name == "inflation_rate_pct")
        assert inflation.status == STATUS_UNAVAILABLE
        assert "HTTP 500" in inflation.notes

    def test_null_value_marks_unavailable(self):
        payloads = dict(_WB_LIVE_PAYLOADS)
        payloads["PA.NUS.FCRF"] = _wb_envelope("PA.NUS.FCRF", "series", None)
        results = _live_wb_client(payloads).fetch_indicators()

        usd = next(r for r in results if r.name == "usd_pkr")
        assert usd.status == STATUS_UNAVAILABLE
        assert "no data point" in usd.notes

    def test_empty_observation_list_marks_unavailable(self):
        payloads = dict(_WB_LIVE_PAYLOADS)
        payloads["FI.RES.TOTL.CD"] = [{"page": 1}, []]
        results = _live_wb_client(payloads).fetch_indicators()

        reserves = next(r for r in results if r.name == "fx_reserves_usd_bn")
        assert reserves.status == STATUS_UNAVAILABLE
        assert "empty observation list" in reserves.notes


# --------------------------------------------------------------------------- #
# SBP gateway client
# --------------------------------------------------------------------------- #


class TestSBPGateway:
    def test_contract_parsed_live(self):
        payload = {
            "policy_rate_pct": {"value": 11.5, "period": "2026-08-01"},
            "kibor_3m_pct": {"value": 11.87, "period": "2026-09-02"},
        }
        client = SBPGatewayClient(
            "https://mock.test/indicators",
            http_client=_mock_client({"indicators": payload}),
        )
        results = {ind.name: ind for ind in client.fetch_indicators()}

        assert results["policy_rate_pct"].status == STATUS_LIVE
        assert results["policy_rate_pct"].value == 11.5
        assert results["policy_rate_pct"].period == "2026-08-01"
        assert results["kibor_3m_pct"].value == 11.87
        assert (
            results["policy_rate_pct"].source
            == "State Bank of Pakistan (via mock.test)"
        )

    def test_api_key_sent_as_bearer(self):
        seen_headers = {}

        def handler(request: httpx.Request) -> httpx.Response:
            seen_headers.update(request.headers)
            return httpx.Response(
                200,
                json={"policy_rate_pct": {"value": 11.5}, "kibor_3m_pct": {"value": 11.9}},
            )

        client = SBPGatewayClient(
            "https://mock.test/indicators",
            api_key="secret-key",
            http_client=httpx.Client(transport=httpx.MockTransport(handler)),
        )
        client.fetch_indicators()

        assert seen_headers.get("authorization") == "Bearer secret-key"

    def test_malformed_payload_marks_unavailable(self):
        client = SBPGatewayClient(
            "https://mock.test/indicators",
            http_client=_mock_client({"indicators": {"policy_rate_pct": "not a dict"}}),
        )
        results = {ind.name: ind for ind in client.fetch_indicators()}

        assert results["policy_rate_pct"].status == STATUS_UNAVAILABLE
        assert "no usable value" in results["policy_rate_pct"].notes
        assert results["kibor_3m_pct"].status == STATUS_UNAVAILABLE

    def test_http_error_marks_both_unavailable(self):
        client = SBPGatewayClient(
            "https://mock.test/indicators",
            http_client=_mock_client({"indicators": {}}, status=503),
        )
        results = client.fetch_indicators()

        assert len(results) == 2
        for ind in results:
            assert ind.status == STATUS_UNAVAILABLE
            assert "HTTP 503" in ind.notes

    def test_not_configured_returns_none(self, monkeypatch):
        monkeypatch.delenv("SBP_BASE_URL", raising=False)
        assert SBPGatewayClient.from_env() is None


# --------------------------------------------------------------------------- #
# PBS gateway client
# --------------------------------------------------------------------------- #


class TestPBSGateway:
    def test_contract_parsed_live(self):
        payload = {"inflation_rate_pct": {"value": 4.2, "period": "2026-07"}}
        client = PBSGatewayClient(
            "https://mock.test/cpi",
            http_client=_mock_client({"cpi": payload}),
        )
        results = client.fetch_indicators()

        assert len(results) == 1
        inflation = results[0]
        assert inflation.status == STATUS_LIVE
        assert inflation.value == 4.2
        assert inflation.period == "2026-07"
        assert (
            inflation.source == "Pakistan Bureau of Statistics (via mock.test)"
        )
        assert inflation.notes == "monthly CPI, year-on-year"

    def test_malformed_payload_marks_unavailable(self):
        client = PBSGatewayClient(
            "https://mock.test/cpi",
            http_client=_mock_client({"cpi": {"inflation_rate_pct": 4.2}}),
        )
        results = client.fetch_indicators()

        assert results[0].status == STATUS_UNAVAILABLE
        assert "no usable value" in results[0].notes

    def test_not_configured_returns_none(self, monkeypatch):
        monkeypatch.delenv("PBS_BASE_URL", raising=False)
        assert PBSGatewayClient.from_env() is None


# --------------------------------------------------------------------------- #
# service merge policy
# --------------------------------------------------------------------------- #


class TestServiceMerge:
    def test_demo_fallback_without_providers(self):
        snapshot = _service().snapshot()

        assert snapshot.status == "demo"
        assert set(snapshot.indicators) == {spec.name for spec in INDICATOR_CATALOG}
        for ind in snapshot.indicators.values():
            assert ind.status == STATUS_DEMO
            assert ind.source == DEMO_SOURCE
            assert ind.value is not None
        assert snapshot.fallback_reasons == {}

    def test_partial_live_snapshot_from_world_bank(self):
        snapshot = _service(_live_wb_client()).snapshot()

        live = [
            "inflation_rate_pct",
            "usd_pkr",
            "fx_reserves_usd_bn",
            "remittances_usd_bn",
        ]
        demo = ["policy_rate_pct", "kibor_3m_pct"]
        for name in live:
            assert snapshot.indicators[name].status == STATUS_LIVE
            assert snapshot.indicators[name].value is not None
        for name in demo:
            assert snapshot.indicators[name].status == STATUS_DEMO
            assert snapshot.indicators[name].source == DEMO_SOURCE
        assert snapshot.status == "partial"

    def test_unavailable_when_demo_disabled(self):
        snapshot = _service(allow_demo=False).snapshot()

        assert snapshot.status == "unavailable"
        for ind in snapshot.indicators.values():
            assert ind.status == STATUS_UNAVAILABLE
            assert ind.value is None
            assert ind.source == ""
        assert snapshot.metric_values(["inflation_rate_pct"]) == {}
        assert snapshot.sources(["inflation_rate_pct"]) == []

    def test_unavailable_when_provider_fails_and_demo_disabled(self):
        failing_wb = _live_wb_client(
            {code: httpx.ConnectTimeout("down") for code in _WB_LIVE_PAYLOADS}
        )
        snapshot = _service(failing_wb, allow_demo=False).snapshot()

        assert snapshot.status == "unavailable"
        inflation = snapshot.indicators["inflation_rate_pct"]
        assert inflation.value is None
        assert "timeout" in inflation.notes.lower()

    def test_first_live_provider_wins(self):
        pbs = FakeClient(
            [_live("inflation_rate_pct", 4.2, "Pakistan Bureau of Statistics (via mock.test)", "2026-07")]
        )
        wb = FakeClient([_live("inflation_rate_pct", 3.55, "World Bank API (FP.CPI.TOTL.ZG)")])
        snapshot = _service(pbs, wb).snapshot()

        assert (
            snapshot.indicators["inflation_rate_pct"].source
            == "Pakistan Bureau of Statistics (via mock.test)"
        )

    def test_provider_crash_never_propagates(self):
        snapshot = _service(ExplodingClient()).snapshot()

        assert snapshot.status == "demo"  # honest fallback, no exception

    def test_fallback_reason_recorded_when_live_attempt_fails(self):
        failing_wb = _live_wb_client(
            {code: httpx.ConnectError("no route") for code in _WB_LIVE_PAYLOADS}
        )
        snapshot = _service(failing_wb).snapshot()

        assert snapshot.indicators["inflation_rate_pct"].status == STATUS_DEMO
        assert "transport error" in snapshot.fallback_reasons["inflation_rate_pct"]

    def test_snapshot_sources_and_metrics_are_catalog_ordered(self):
        snapshot = _service(_live_wb_client()).snapshot()
        names = [
            "inflation_rate_pct",
            "policy_rate_pct",
            "usd_pkr",
            "fx_reserves_usd_bn",
        ]

        metrics = snapshot.metric_values(names)
        assert metrics["inflation_rate_pct"] == 3.55
        assert metrics["usd_pkr"] == 281.14
        assert metrics["policy_rate_pct"] == 11.0  # demo fallback value
        assert list(metrics) == names

        sources = snapshot.sources(names)
        assert sources == [
            "World Bank API (FP.CPI.TOTL.ZG)",
            "demo snapshot (not live data)",
            "World Bank API (PA.NUS.FCRF)",
            "World Bank API (FI.RES.TOTL.CD)",
        ]

    def test_cache_avoids_refetch_and_can_be_invalidated(self):
        provider = FakeClient([_live("usd_pkr", 281.14, "World Bank API (PA.NUS.FCRF)")])
        service = EconomicDataService(providers=[provider], cache_seconds=600)

        first = service.snapshot()
        second = service.snapshot()

        assert first is second
        assert provider.fetches == 1
        assert first.fetched_at  # freshness metadata present

        service.invalidate_cache()
        third = service.snapshot()
        assert third is not first
        assert provider.fetches == 2


# --------------------------------------------------------------------------- #
# graph integration — economic agent on live data
# --------------------------------------------------------------------------- #


def _graph_scripts() -> dict[str, str]:
    return {
        ECONOMIC_MARKER: '{"summary": "Econ view"}',
        PERSONAL_FINANCE_MARKER: '{"summary": "Personal view"}',
        RISK_IMPACT_MARKER: '{"summary": "Impact view"}',
    }


class TestGraphWithLiveData:
    def test_economic_agent_interprets_live_data(self):
        set_economic_service(_service(_live_wb_client()))
        provider = ScriptedAgentProvider(
            replies_by_marker=_graph_scripts(),
            final_answer="Composed answer.",
        )

        result = _chat_service(provider).chat(
            "How are inflation and interest rates moving in Pakistan?",
            "en",
        )

        econ_calls = [c for c in provider.calls if ECONOMIC_MARKER in c["system"]]
        prompt = econ_calls[0]["prompt"]
        assert "live — World Bank API (FP.CPI.TOTL.ZG)" in prompt
        assert "3.55" in prompt
        # policy rate / KIBOR fall back to the labelled demo values
        assert "(demo data)" in prompt

        assert result["dataStatus"] == "partial"
        assert result["metrics"]["inflation_rate_pct"] == 3.55
        assert result["metrics"]["policy_rate_pct"] == 11.0
        assert "World Bank API (FP.CPI.TOTL.ZG)" in result["sources"]
        assert DEMO_SOURCE in result["sources"]

    def test_all_live_answer_reports_live(self):
        pbs = PBSGatewayClient(
            "https://mock.test/cpi",
            http_client=_mock_client(
                {"cpi": {"inflation_rate_pct": {"value": 4.2, "period": "2026-07"}}}
            ),
        )
        sbp = SBPGatewayClient(
            "https://mock.test/indicators",
            http_client=_mock_client(
                {
                    "indicators": {
                        "policy_rate_pct": {"value": 11.5, "period": "2026-08-01"},
                        "kibor_3m_pct": {"value": 11.9, "period": "2026-09-02"},
                    }
                }
            ),
        )
        set_economic_service(_service(pbs, sbp, _live_wb_client()))
        provider = ScriptedAgentProvider(
            replies_by_marker=_graph_scripts(),
            final_answer="All live.",
        )

        result = _chat_service(provider).chat(
            "How are inflation and interest rates moving in Pakistan?",
            "en",
        )

        assert result["dataStatus"] == "live"
        assert result["metrics"]["inflation_rate_pct"] == 4.2
        assert result["metrics"]["policy_rate_pct"] == 11.5
        assert result["metrics"]["kibor_3m_pct"] == 11.9
        # only the selected indicators' provenance surfaces (inflation +
        # policy rate + KIBOR were requested)
        assert result["sources"] == [
            "Pakistan Bureau of Statistics (via mock.test)",
            "State Bank of Pakistan (via mock.test)",
        ]

    def test_demo_fallback_reason_surfaces_as_limitation(self):
        failing_wb = _live_wb_client(
            {code: httpx.ConnectError("no route") for code in _WB_LIVE_PAYLOADS}
        )
        set_economic_service(_service(failing_wb))
        provider = ScriptedAgentProvider(
            replies_by_marker=_graph_scripts(),
            final_answer="Answer with limitations.",
        )

        result = _chat_service(provider).chat(
            "How are inflation and interest rates moving in Pakistan?",
            "en",
        )

        composer_calls = [c for c in provider.calls if COMPOSER_MARKER in c["system"]]
        assert any(
            "Using demo value for CPI inflation (YoY)" in c["prompt"]
            for c in composer_calls
        )
        assert result["dataStatus"] == "demo"

    def test_risk_impact_works_when_indicators_unavailable(self):
        set_economic_service(_service(allow_demo=False))
        provider = ScriptedAgentProvider(
            replies_by_marker=_graph_scripts(),
            final_answer="Impact answer without economic numbers.",
        )

        result = _chat_service(provider).chat(
            "How will inflation affect me?", "en", CONTEXT
        )

        # the answer still composes — economic data is absent, not fabricated
        assert result["answer"] == "Impact answer without economic numbers."
        assert result["agentsUsed"] == [
            "economic_intelligence",
            "personal_finance",
            "risk_impact",
        ]
        assert result["dataStatus"] == "unavailable"
        assert "inflation_rate_pct" not in result["metrics"]
        econ_calls = [c for c in provider.calls if ECONOMIC_MARKER in c["system"]]
        assert "unavailable from live sources" in econ_calls[0]["prompt"]

    def test_llm_cannot_inject_provenance(self):
        set_economic_service(_service(_live_wb_client()))
        provider = ScriptedAgentProvider(
            replies_by_marker={
                ECONOMIC_MARKER: (
                    '{"summary": "Econ view", '
                    '"sources": ["Totally Real Bank", "http://fake.url"], '
                    '"data_status": "live", '
                    '"metrics": {"inflation_rate_pct": 99.9}}'
                ),
                PERSONAL_FINANCE_MARKER: '{"summary": "Personal view"}',
                RISK_IMPACT_MARKER: '{"summary": "Impact view"}',
            },
            final_answer="Answer.",
        )

        result = _chat_service(provider).chat(
            "How are inflation and interest rates moving in Pakistan?",
            "en",
        )

        # provenance, values and status are overwritten in code from the
        # data layer — the LLM's claims never survive
        assert "Totally Real Bank" not in result["sources"]
        assert "http://fake.url" not in result["sources"]
        assert result["metrics"]["inflation_rate_pct"] == 3.55
        assert result["dataStatus"] == "partial"

    def test_default_demo_path_unchanged(self):
        # the autouse fixture installed a provider-less service; the
        # Phase 2 behaviour (demo everywhere) must hold
        provider = ScriptedAgentProvider(
            replies_by_marker=_graph_scripts(),
            final_answer="Demo answer.",
        )

        result = _chat_service(provider).chat(
            "How will inflation affect me?", "en", CONTEXT
        )

        assert result["dataStatus"] == "demo"
        assert result["metrics"]["inflation_rate_pct"] == 11.8
        assert result["sources"] == [
            "demo snapshot (not live data)",
            "deterministic calculation results",
        ]


# --------------------------------------------------------------------------- #
# API contract
# --------------------------------------------------------------------------- #


class TestAPIContract:
    def test_chat_response_contract_with_live_data(self, make_client):
        set_economic_service(_service(_live_wb_client()))
        primary = ScriptedAgentProvider(
            replies_by_marker=_graph_scripts(),
            final_answer="Composed live answer.",
        )
        client = make_client(primary=primary)

        response = client.post(
            "/v1/assistant/chat",
            json={
                "message": "How are inflation and interest rates moving in Pakistan?",
                "language": "en",
                "financial_context": CONTEXT,
            },
        )

        assert response.status_code == 200
        body = response.json()
        for field in (
            "answer",
            "intent",
            "language",
            "provider",
            "agentsUsed",
            "metrics",
            "recommendations",
            "sources",
            "dataStatus",
        ):
            assert field in body
        assert body["dataStatus"] == "partial"
        assert body["metrics"]["inflation_rate_pct"] == 3.55
        assert body["metrics"]["policy_rate_pct"] == 11.0  # demo fallback
        # pure economic question: no personal agents, no deterministic tools
        assert body["agentsUsed"] == ["economic_intelligence"]


# --------------------------------------------------------------------------- #
# unit bits
# --------------------------------------------------------------------------- #


class TestUnits:
    def test_overall_status_matrix(self):
        live = _live("usd_pkr", 281.0, "s")
        demo = Indicator("kibor_3m_pct", 11.9, "%", "3-month KIBOR", STATUS_DEMO, DEMO_SOURCE)
        unavail = Indicator("policy_rate_pct", None, "%", "SBP policy rate", STATUS_UNAVAILABLE, "")

        assert overall_status([live]) == "live"
        assert overall_status([live, demo]) == "partial"
        assert overall_status([demo]) == "demo"
        assert overall_status([demo, unavail]) == "demo"
        assert overall_status([unavail]) == "unavailable"
        assert overall_status([]) == "unavailable"

    @pytest.mark.parametrize(
        "raw,expected",
        [
            (11.5, 11.5),
            ("11.5", 11.5),
            ("1,250.50", 1250.5),
            (True, None),
            (None, None),
            ("abc", None),
            (float("nan"), None),
            (float("inf"), None),
            ([], None),
        ],
    )
    def test_parse_number(self, raw, expected):
        from core.economic_data.client import parse_number

        assert parse_number(raw) == expected
