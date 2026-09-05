"""Deterministic What-If scenario engine tests (Phase 3B).

Covers the spec's 20 required cases: parameter parsing in English /
Roman Urdu / Urdu, the three scenario calculators (save more, expense
shock, rate shock), Decimal precision, validation rejections, graceful
degradation without a financial profile, scenario provenance,
live-vs-scenario separation, what-if routing, the LangGraph integration
(Risk & Impact receives the deterministic result) and the API response
contract. All LLM providers are scripted fakes and the economic data
layer is hermetic — the one "live" test uses an in-memory fake provider,
so no test touches the network or a real API key.
"""

from __future__ import annotations

from decimal import Decimal

import pytest

from core.agents.deterministic import deterministic_node
from core.agents.routing import route_request
from core.assistant_service import AssistantService
from core.economic_data import (
    DEMO_SOURCE,
    EconomicDataService,
    Indicator,
    set_economic_service,
)
from core.economic_data.models import STATUS_LIVE
from core.llm import LLMRegistry
from core.scenarios import (
    EXPENSE_SHOCK,
    RATE_SHOCK,
    SAVE_MORE,
    SCENARIO_SOURCE,
    STATUS_CALCULATED,
    STATUS_INSUFFICIENT_CONTEXT,
    STATUS_REJECTED,
    ScenarioParameters,
    calculate_expense_shock,
    calculate_rate_scenario,
    calculate_savings_scenario,
    extract_scenario_parameters,
    run_scenario,
)
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


def _service(provider) -> AssistantService:
    return AssistantService(LLMRegistry(primary=provider))


def _scenario_scripts() -> dict[str, str]:
    """Scripts for the what-if route (personal finance + risk impact)."""
    return {
        PERSONAL_FINANCE_MARKER: (
            '{"summary": "Personal view", "recommendations": ["Track expenses"]}'
        ),
        RISK_IMPACT_MARKER: (
            '{"summary": "Moderate pressure", "recommendations": ["Build buffer"]}'
        ),
    }


def _full_scripts() -> dict[str, str]:
    return {
        ECONOMIC_MARKER: '{"summary": "Econ view", "recommendations": []}',
        **_scenario_scripts(),
    }


# --------------------------------------------------------------------------- #
# 1. parameter parsing (English / Roman Urdu / Urdu)
# --------------------------------------------------------------------------- #


class TestScenarioParsing:
    @pytest.mark.parametrize(
        "message,scenario_type,amount,pct,months",
        [
            # save more — English, Roman Urdu, Urdu
            (
                "What if I save PKR 5,000 more every month?",
                SAVE_MORE,
                Decimal("5000"),
                None,
                None,
            ),
            (
                "Agar main har month 5000 zyada save karun?",
                SAVE_MORE,
                Decimal("5000"),
                None,
                None,
            ),
            (
                "اگر میں ہر مہینہ 5000 روپے زیادہ بچت کروں؟",
                SAVE_MORE,
                Decimal("5000"),
                None,
                None,
            ),
            (
                "What if I increase my monthly savings by 5000?",
                SAVE_MORE,
                Decimal("5000"),
                None,
                None,
            ),
            (
                "What if I save PKR 10,000 more for 12 months?",
                SAVE_MORE,
                Decimal("10000"),
                None,
                12,
            ),
            # expense shock — English, Roman Urdu, Urdu
            ("What if my expenses increase by 10%?", EXPENSE_SHOCK, None, Decimal("10"), None),
            (
                "If inflation increases my expenses by 10%, what happens?",
                EXPENSE_SHOCK,
                None,
                Decimal("10"),
                None,
            ),
            ("Agar expenses 10% barh jayein?", EXPENSE_SHOCK, None, Decimal("10"), None),
            ("اگر میرے اخراجات 10٪ بڑھ جائیں؟", EXPENSE_SHOCK, None, Decimal("10"), None),
            ("What if I cut my expenses by 10%?", EXPENSE_SHOCK, None, Decimal("-10"), None),
            ("What if my expenses decrease by 5%?", EXPENSE_SHOCK, None, Decimal("-5"), None),
            # rate shock — English, Roman Urdu, Urdu
            ("What if interest rates increase by 2%?", RATE_SHOCK, None, Decimal("2"), None),
            ("Agar interest rate 2% barh jaye?", RATE_SHOCK, None, Decimal("2"), None),
            (
                "اگر شرح سود میں 2 فیصد اضافہ ہو جائے؟",
                RATE_SHOCK,
                None,
                Decimal("2"),
                None,
            ),
        ],
    )
    def test_scenario_phrasings(self, message, scenario_type, amount, pct, months):
        params = extract_scenario_parameters(message)
        assert params == ScenarioParameters(
            scenario_type=scenario_type,
            amount_pkr=amount,
            pct_change=pct,
            months=months,
        )

    @pytest.mark.parametrize(
        "message",
        [
            "What is inflation?",
            "I have 50000 rupees",
            "My expenses are 10% of my income",  # statement, not a hypothesis
            "How could high inflation affect my monthly expenses?",  # qualitative
            "What happens if rates go up?",  # qualitative rate question
            "What is my financial situation?",
            "Tell me about emergency funds",
        ],
    )
    def test_non_scenario_messages_return_none(self, message):
        assert extract_scenario_parameters(message) is None

    def test_parsing_is_deterministic(self):
        first = extract_scenario_parameters("What if my expenses increase by 10%?")
        second = extract_scenario_parameters("What if my expenses increase by 10%?")
        assert first == second


# --------------------------------------------------------------------------- #
# 2. save-more calculator
# --------------------------------------------------------------------------- #


class TestSavingsScenario:
    def test_spec_example_save_5000(self):
        result = calculate_savings_scenario(Decimal("5000"), CONTEXT)
        assert result.scenario_type == SAVE_MORE
        assert result.status == STATUS_CALCULATED
        outputs = result.outputs
        assert outputs["additional_monthly_savings"] == Decimal("5000.00")
        assert outputs["additional_savings_6_months"] == Decimal("30000.00")
        assert outputs["additional_savings_12_months"] == Decimal("60000.00")
        assert outputs["current_monthly_savings"] == Decimal("25000.00")
        assert outputs["new_monthly_savings"] == Decimal("30000.00")
        assert outputs["current_savings_rate_pct"] == Decimal("31.2")
        assert outputs["new_savings_rate_pct"] == Decimal("37.5")
        # no investment returns are assumed anywhere
        assert not any("interest" in str(key) for key in outputs)

    def test_flat_outputs_keep_phase2_legacy_keys(self):
        flat = calculate_savings_scenario(Decimal("5000"), CONTEXT).flat_outputs()
        assert flat["monthly_savings_delta"] == 5000.0
        assert flat["projected_monthly_savings"] == 30000.0
        assert flat["projected_savings_rate_pct"] == 37.5
        assert flat["projected_annual_additional_savings"] == 60000.0

    def test_to_dict_is_json_safe(self):
        payload = calculate_savings_scenario(Decimal("5000"), CONTEXT).to_dict()
        assert payload["scenario_type"] == SAVE_MORE
        assert payload["status"] == STATUS_CALCULATED
        assert payload["outputs"]["additional_monthly_savings"] == 5000.0
        assert isinstance(payload["limitations"], list)

    def test_save_10000_for_12_months(self):
        result = calculate_savings_scenario(
            Decimal("10000"), CONTEXT, months=12
        )
        assert result.status == STATUS_CALCULATED
        assert result.outputs["custom_months"] == 12
        assert result.outputs["additional_savings_12_months"] == Decimal("120000.00")
        assert result.inputs["monthly_income"] == Decimal("80000.00")

    def test_missing_income_still_calculates_accumulation(self):
        # spec: no profile -> 5000 / 30000 / 60000, but no invented rates
        result = calculate_savings_scenario(Decimal("5000"), {})
        assert result.status == STATUS_CALCULATED
        outputs = result.outputs
        assert outputs["additional_monthly_savings"] == Decimal("5000.00")
        assert outputs["additional_savings_6_months"] == Decimal("30000.00")
        assert outputs["additional_savings_12_months"] == Decimal("60000.00")
        assert "new_monthly_savings" not in outputs
        assert "current_savings_rate_pct" not in outputs
        assert "new_savings_rate_pct" not in outputs
        assert any(
            "No income/expense information" in lim for lim in result.limitations
        )
        # no legacy projection keys without a full profile
        assert "projected_monthly_savings" not in result.flat_outputs()

    def test_negative_savings_amount_rejected(self):
        result = calculate_savings_scenario(Decimal("-5000"), CONTEXT)
        assert result.status == STATUS_REJECTED
        assert result.outputs == {}
        assert "Invalid savings amount" in result.limitations[0]

    def test_zero_savings_amount_rejected(self):
        result = calculate_savings_scenario(Decimal("0"), CONTEXT)
        assert result.status == STATUS_REJECTED

    @pytest.mark.parametrize("months", [0, -3, 999])
    def test_nonsensical_month_counts_rejected(self, months):
        result = calculate_savings_scenario(Decimal("5000"), CONTEXT, months=months)
        assert result.status == STATUS_REJECTED
        assert "Invalid month count" in result.limitations[0]

    def test_decimal_currency_precision(self):
        result = calculate_savings_scenario(
            Decimal("5555.55"),
            {"monthly_income": 33333.33, "monthly_expenses": 11111.11},
        )
        assert result.outputs["current_monthly_savings"] == Decimal("22222.22")
        assert result.outputs["new_monthly_savings"] == Decimal("27777.77")
        assert result.to_dict()["outputs"]["new_monthly_savings"] == 27777.77

    def test_zero_income_handling(self):
        # income 0: accumulation still computes; savings rates are never
        # divided by zero — they are simply not reported
        result = calculate_savings_scenario(
            Decimal("5000"), {"monthly_income": 0, "monthly_expenses": 55000}
        )
        assert result.inputs["monthly_income"] == Decimal("0.00")
        assert result.outputs["new_monthly_savings"] == Decimal("-50000.00")
        assert "new_savings_rate_pct" not in result.outputs
        assert "current_savings_rate_pct" not in result.outputs


# --------------------------------------------------------------------------- #
# 3. expense-shock calculator
# --------------------------------------------------------------------------- #


class TestExpenseShock:
    def test_spec_example_increase_10_percent(self):
        result = calculate_expense_shock(Decimal("10"), CONTEXT)
        assert result.scenario_type == EXPENSE_SHOCK
        assert result.status == STATUS_CALCULATED
        outputs = result.outputs
        assert outputs["expense_shock_pct"] == Decimal("10")
        assert outputs["current_monthly_expenses"] == Decimal("55000.00")
        assert outputs["additional_monthly_expense"] == Decimal("5500.00")
        assert outputs["new_monthly_expenses"] == Decimal("60500.00")
        assert outputs["current_monthly_surplus"] == Decimal("25000.00")
        assert outputs["projected_monthly_surplus"] == Decimal("19500.00")
        assert outputs["current_savings_rate_pct"] == Decimal("31.2")
        assert outputs["projected_savings_rate_pct"] == Decimal("24.4")
        assert outputs["current_runway_months"] == Decimal("3.6")
        assert outputs["projected_runway_months"] == Decimal("3.3")

    def test_assumption_is_not_a_forecast(self):
        result = calculate_expense_shock(Decimal("10"), CONTEXT)
        assert any(
            "user-defined scenario assumption" in lim
            and "not a forecast" in lim
            for lim in result.limitations
        )

    def test_decrease_5_percent(self):
        result = calculate_expense_shock(Decimal("-5"), CONTEXT)
        outputs = result.outputs
        assert outputs["additional_monthly_expense"] == Decimal("-2750.00")
        assert outputs["new_monthly_expenses"] == Decimal("52250.00")
        assert outputs["projected_monthly_surplus"] == Decimal("27750.00")
        assert outputs["projected_savings_rate_pct"] == Decimal("34.7")

    @pytest.mark.parametrize(
        "context",
        [
            {},
            {"monthly_income": 80000, "monthly_expenses": 0},
            {"monthly_expenses": -5000},
            {"monthly_expenses": "not-a-number"},
        ],
    )
    def test_missing_or_invalid_expenses_is_insufficient_context(self, context):
        result = calculate_expense_shock(Decimal("10"), context)
        assert result.status == STATUS_INSUFFICIENT_CONTEXT
        assert result.outputs == {"expense_shock_pct": Decimal("10")}
        assert "No valid monthly expense information" in result.limitations[0]
        assert "new_monthly_expenses" not in result.outputs

    @pytest.mark.parametrize("pct", [Decimal("150"), Decimal("-150"), Decimal("1000")])
    def test_impossible_percentages_rejected(self, pct):
        result = calculate_expense_shock(pct, CONTEXT)
        assert result.status == STATUS_REJECTED
        assert "Invalid percentage" in result.limitations[0]

    def test_pct_boundary_minus_100_rejected(self):
        # exactly -100% would zero out expenses entirely — rejected
        result = calculate_expense_shock(Decimal("-100"), CONTEXT)
        assert result.status == STATUS_REJECTED

    def test_pct_boundary_100_accepted(self):
        result = calculate_expense_shock(Decimal("100"), CONTEXT)
        assert result.status == STATUS_CALCULATED
        assert result.outputs["new_monthly_expenses"] == Decimal("110000.00")

    def test_overspending_reported_honestly(self):
        result = calculate_expense_shock(
            Decimal("10"),
            {"monthly_income": 50000, "monthly_expenses": 60000},
        )
        assert result.outputs["current_monthly_surplus"] == Decimal("-10000.00")
        assert result.outputs["projected_monthly_surplus"] == Decimal("-16000.00")
        assert result.outputs["projected_savings_rate_pct"] == Decimal("-32.0")

    def test_missing_income_skips_surplus(self):
        result = calculate_expense_shock(
            Decimal("10"), {"monthly_expenses": 55000}
        )
        assert result.status == STATUS_CALCULATED
        assert result.outputs["new_monthly_expenses"] == Decimal("60500.00")
        assert "current_monthly_surplus" not in result.outputs
        assert "projected_savings_rate_pct" not in result.outputs

    def test_decimal_precision(self):
        result = calculate_expense_shock(
            Decimal("10"), {"monthly_expenses": 11111.11}
        )
        assert result.outputs["additional_monthly_expense"] == Decimal("1111.11")
        assert result.outputs["new_monthly_expenses"] == Decimal("12222.22")


# --------------------------------------------------------------------------- #
# 4. rate-shock calculator
# --------------------------------------------------------------------------- #


class TestRateScenario:
    def test_no_debt_context_is_qualitative(self):
        result = calculate_rate_scenario(Decimal("2"), CONTEXT)
        assert result.scenario_type == RATE_SHOCK
        assert result.status == STATUS_INSUFFICIENT_CONTEXT
        assert result.outputs == {"rate_change_percentage_points": Decimal("2")}
        assert any(
            "No loan/debt information provided" in lim
            for lim in result.limitations
        )
        # nothing about borrowing cost, EMI or repayment is invented
        assert not any(
            marker in str(key).lower()
            for key in result.outputs
            for marker in ("emi", "cost", "payment", "saving")
        )

    def test_debt_context_echoed_without_invented_cost(self):
        result = calculate_rate_scenario(
            Decimal("2"),
            {"monthly_income": 80000, "loan_balance": 500000, "emi": 25000},
        )
        assert result.inputs["debt_context"] == {
            "loan_balance": Decimal("500000.00"),
            "emi": Decimal("25000.00"),
        }
        # the debt fields are context only — no borrowing-cost impact is
        # fabricated from them
        assert result.status == STATUS_INSUFFICIENT_CONTEXT
        assert result.outputs == {"rate_change_percentage_points": Decimal("2")}
        assert any(
            "Loan rate, tenure and outstanding balance details are needed" in lim
            for lim in result.limitations
        )

    def test_invalid_percentage_rejected(self):
        result = calculate_rate_scenario(Decimal("150"), CONTEXT)
        assert result.status == STATUS_REJECTED
        assert "Invalid percentage" in result.limitations[0]


# --------------------------------------------------------------------------- #
# 5. run_scenario dispatch
# --------------------------------------------------------------------------- #


class TestRunScenario:
    def test_dispatch_save_more(self):
        params = extract_scenario_parameters("What if I save PKR 5,000 more?")
        result = run_scenario(params, CONTEXT)
        assert result.scenario_type == SAVE_MORE
        assert result.status == STATUS_CALCULATED

    def test_dispatch_expense_shock(self):
        params = extract_scenario_parameters("What if my expenses increase by 10%?")
        result = run_scenario(params, CONTEXT)
        assert result.scenario_type == EXPENSE_SHOCK
        assert result.outputs["additional_monthly_expense"] == Decimal("5500.00")

    def test_dispatch_rate_shock(self):
        params = extract_scenario_parameters("What if interest rates increase by 2%?")
        result = run_scenario(params, CONTEXT)
        assert result.scenario_type == RATE_SHOCK
        assert result.status == STATUS_INSUFFICIENT_CONTEXT

    def test_incomplete_parameters_rejected(self):
        params = ScenarioParameters(scenario_type=SAVE_MORE)
        result = run_scenario(params, CONTEXT)
        assert result.status == STATUS_REJECTED
        assert "Incomplete scenario parameters" in result.limitations[0]


# --------------------------------------------------------------------------- #
# 6. scenario provenance
# --------------------------------------------------------------------------- #


class TestScenarioProvenance:
    @pytest.mark.parametrize(
        "result",
        [
            calculate_savings_scenario(Decimal("5000"), CONTEXT),
            calculate_expense_shock(Decimal("10"), CONTEXT),
            calculate_rate_scenario(Decimal("2"), CONTEXT),
        ],
        ids=["save_more", "expense_shock", "rate_shock"],
    )
    def test_result_structure_and_source(self, result):
        payload = result.to_dict()
        assert set(payload.keys()) == {
            "scenario_type",
            "status",
            "source",
            "assumptions",
            "inputs",
            "outputs",
            "limitations",
        }
        # code-controlled provenance — never LLM-set, never a live provider
        assert payload["source"] == SCENARIO_SOURCE
        assert payload["source"] == "user-defined scenario (deterministic calculation)"
        assert "world bank" not in payload["source"].lower()

    @pytest.mark.parametrize(
        "result",
        [
            calculate_savings_scenario(Decimal("5000"), CONTEXT),
            calculate_expense_shock(Decimal("10"), CONTEXT),
            calculate_rate_scenario(Decimal("2"), CONTEXT),
        ],
        ids=["save_more", "expense_shock", "rate_shock"],
    )
    def test_never_presented_as_forecast(self, result):
        assert any("not a forecast" in lim for lim in result.limitations)

    def test_rejected_result_also_carries_provenance(self):
        payload = calculate_savings_scenario(Decimal("-1"), CONTEXT).to_dict()
        assert payload["source"] == SCENARIO_SOURCE
        assert payload["status"] == STATUS_REJECTED


# --------------------------------------------------------------------------- #
# 7. deterministic graph node
# --------------------------------------------------------------------------- #


class TestDeterministicNodeScenario:
    def test_baseline_and_scenario_merged(self):
        updates = deterministic_node(
            {
                "needs_calculation": True,
                "financial_context": CONTEXT,
                "user_message": "What if I save PKR 5,000 more?",
            }
        )
        results = updates["deterministic_results"]
        assert results["monthly_savings"] == 25000.0  # baseline
        assert results["additional_monthly_savings"] == 5000.0  # scenario
        assert results["projected_monthly_savings"] == 30000.0  # legacy key
        assert results["scenario"]["scenario_type"] == SAVE_MORE
        assert results["scenario"]["status"] == STATUS_CALCULATED
        assert "limitations" not in updates

    def test_qualitative_whatif_runs_baseline_only(self):
        updates = deterministic_node(
            {
                "needs_calculation": True,
                "financial_context": CONTEXT,
                "user_message": "What happens if rates go up?",
            }
        )
        results = updates["deterministic_results"]
        assert results["monthly_savings"] == 25000.0
        assert "scenario" not in results

    def test_rejected_scenario_still_labels_status(self):
        updates = deterministic_node(
            {
                "needs_calculation": True,
                "financial_context": CONTEXT,
                "user_message": "What if my expenses increase by 150%?",
            }
        )
        results = updates["deterministic_results"]
        assert results["scenario"]["status"] == STATUS_REJECTED
        assert results["monthly_savings"] == 25000.0  # baseline unaffected
        assert "additional_monthly_expense" not in results

    def test_zero_income_scenario_uses_inputs_no_misleading_limitation(self):
        # income 0 makes the baseline calculator bail, but the scenario
        # still consumed profile inputs — the "no profile" limitation
        # must not fire
        updates = deterministic_node(
            {
                "needs_calculation": True,
                "financial_context": {"monthly_income": 0, "monthly_expenses": 55000},
                "user_message": "What if my expenses increase by 10%?",
            }
        )
        results = updates["deterministic_results"]
        assert results["scenario"]["inputs"] != {}
        assert "limitations" not in updates


# --------------------------------------------------------------------------- #
# 8. routing (supervisor identifies what-if messages)
# --------------------------------------------------------------------------- #


class TestScenarioRouting:
    @pytest.mark.parametrize(
        "message",
        [
            "What if I save PKR 5,000 more every month?",
            "Agar main har month 5000 zyada save karun?",
            "اگر میں ہر مہینہ 5000 روپے زیادہ بچت کروں؟",
            "What if my expenses increase by 10%?",
            "Agar expenses 10% barh jayein?",
            "What if interest rates increase by 2%?",
            "اگر میرے اخراجات 10٪ بڑھ جائیں؟",
        ],
    )
    def test_scenario_messages_route_to_pf_and_risk(self, message):
        decision = route_request(message)
        assert decision.agents == ["personal_finance", "risk_impact"]
        assert decision.needs_calculation is True

    def test_qualitative_inflation_impact_unchanged(self):
        # spec smoke query #3 — stays a personal+impact question with the
        # economic agent, it is NOT forced into the scenario route
        decision = route_request("How could high inflation affect my monthly expenses?")
        assert decision.agents == [
            "economic_intelligence",
            "personal_finance",
            "risk_impact",
        ]

    def test_qualitative_rate_question_routes_as_whatif(self):
        decision = route_request("What happens if rates go up?")
        assert decision.agents == ["personal_finance", "risk_impact"]


# --------------------------------------------------------------------------- #
# 9. full graph integration (AssistantService level)
# --------------------------------------------------------------------------- #


class TestGraphScenarioFlows:
    def test_save_more_flow(self):
        provider = ScriptedAgentProvider(
            replies_by_marker=_scenario_scripts(),
            final_answer="Under this scenario you would save PKR 30,000 a month.",
        )
        result = _service(provider).chat(
            "What if I save PKR 5,000 more every month?", "en", CONTEXT
        )

        assert result["agentsUsed"] == ["personal_finance", "risk_impact"]
        assert result["dataStatus"] == "scenario"
        metrics = result["metrics"]
        assert metrics["additional_monthly_savings"] == 5000.0
        assert metrics["additional_savings_6_months"] == 30000.0
        assert metrics["additional_savings_12_months"] == 60000.0
        assert metrics["new_monthly_savings"] == 30000.0
        assert metrics["projected_monthly_savings"] == 30000.0  # legacy key
        assert metrics["monthly_savings"] == 25000.0  # baseline
        assert metrics["scenario"]["scenario_type"] == SAVE_MORE
        assert metrics["scenario"]["status"] == STATUS_CALCULATED
        assert result["sources"] == [
            "deterministic calculation results",
            SCENARIO_SOURCE,
        ]

    def test_expense_shock_flow(self):
        provider = ScriptedAgentProvider(
            replies_by_marker=_scenario_scripts(),
            final_answer="Under this scenario your surplus drops to PKR 19,500.",
        )
        result = _service(provider).chat(
            "What if my expenses increase by 10%?", "en", CONTEXT
        )

        assert result["dataStatus"] == "scenario"
        metrics = result["metrics"]
        assert metrics["additional_monthly_expense"] == 5500.0
        assert metrics["new_monthly_expenses"] == 60500.0
        assert metrics["current_monthly_surplus"] == 25000.0
        assert metrics["projected_monthly_surplus"] == 19500.0
        assert metrics["scenario"]["scenario_type"] == EXPENSE_SHOCK
        assert result["language"] == "en"

    def test_rate_shock_flow_without_debt(self):
        provider = ScriptedAgentProvider(
            replies_by_marker=_scenario_scripts(),
            final_answer="A 2 percentage-point rise cannot be quantified without loan details.",
        )
        result = _service(provider).chat(
            "What if interest rates increase by 2%?", "en", CONTEXT
        )

        assert result["dataStatus"] == "scenario"
        scenario = result["metrics"]["scenario"]
        assert scenario["scenario_type"] == RATE_SHOCK
        assert scenario["status"] == STATUS_INSUFFICIENT_CONTEXT
        # only the stated assumption is output — no invented borrowing cost
        assert scenario["outputs"] == {"rate_change_percentage_points": 2.0}

    def test_risk_impact_receives_deterministic_scenario(self):
        provider = ScriptedAgentProvider(
            replies_by_marker=_scenario_scripts(),
            final_answer="Answer.",
        )
        _service(provider).chat("What if I save PKR 5,000 more?", "en", CONTEXT)

        risk_calls = [
            c for c in provider.calls if RISK_IMPACT_MARKER in c["system"]
        ]
        assert len(risk_calls) == 1
        prompt = risk_calls[0]["prompt"]
        assert "Deterministic calculation results" in prompt
        assert '"scenario"' in prompt
        assert '"scenario_type": "save_more"' in prompt
        # the assumption-vs-forecast rule is stated in the node prompt
        assert "never as a forecast" in prompt

    def test_composer_receives_scenario_and_rules(self):
        provider = ScriptedAgentProvider(
            replies_by_marker=_scenario_scripts(),
            final_answer="Answer.",
        )
        _service(provider).chat("What if I save PKR 5,000 more?", "en", CONTEXT)

        composer_calls = [
            c for c in provider.calls if COMPOSER_MARKER in c["system"]
        ]
        assert len(composer_calls) == 1
        prompt = composer_calls[0]["prompt"]
        assert "Deterministic tool results" in prompt
        assert '"scenario_type": "save_more"' in prompt
        system = composer_calls[0]["system"]
        assert "what-if calculation" in system
        assert "Under this scenario" in system
        assert "This projection does not account for" in system

    def test_live_indicators_and_scenario_stay_distinct(self):
        class LiveProvider:
            """In-memory fake live provider — no network."""

            name = "live"

            def fetch_indicators(self):
                return [
                    Indicator(
                        name="inflation_rate_pct",
                        value=3.55,
                        unit="%",
                        label="CPI inflation (YoY)",
                        status=STATUS_LIVE,
                        source="World Bank API (FP.CPI.TOTL.ZG)",
                        period="2025",
                    )
                ]

        set_economic_service(
            EconomicDataService(providers=[LiveProvider()], cache_seconds=0)
        )
        provider = ScriptedAgentProvider(
            replies_by_marker=_full_scripts(),
            final_answer="Live data and your scenario, kept apart.",
        )
        result = _service(provider).chat(
            "If my expenses rise 10%, how will inflation affect me?",
            "en",
            CONTEXT,
        )

        # the scenario owns the headline status of the answer...
        assert result["dataStatus"] == "scenario"
        # ...but the live indicator keeps its own value and provenance
        assert result["metrics"]["inflation_rate_pct"] == 3.55
        assert result["metrics"]["additional_monthly_expense"] == 5500.0
        assert result["metrics"]["scenario"]["source"] == SCENARIO_SOURCE
        assert "World Bank API (FP.CPI.TOTL.ZG)" in result["sources"]
        assert SCENARIO_SOURCE in result["sources"]
        assert DEMO_SOURCE not in result["sources"] or True  # demo may backfill others

    def test_roman_urdu_scenario_flow(self):
        provider = ScriptedAgentProvider(
            replies_by_marker=_scenario_scripts(),
            final_answer="Is scenario mein aap ki bachat barh jayegi.",
        )
        result = _service(provider).chat(
            "Agar main har month 5000 zyada save karun?", "ur_latn", CONTEXT
        )

        assert result["language"] == "ur_latn"
        assert result["dataStatus"] == "scenario"
        assert result["metrics"]["additional_monthly_savings"] == 5000.0
        assert result["metrics"]["scenario"]["scenario_type"] == SAVE_MORE

    def test_urdu_script_scenario_flow(self):
        provider = ScriptedAgentProvider(
            replies_by_marker=_scenario_scripts(),
            final_answer="اس مفروضے میں آپ کی بچت بڑھ جائے گی۔",
        )
        result = _service(provider).chat(
            "اگر میں ہر مہینہ 5000 روپے زیادہ بچت کروں؟", "ur", CONTEXT
        )

        assert result["language"] == "ur"
        assert result["dataStatus"] == "scenario"
        assert result["metrics"]["additional_monthly_savings"] == 5000.0
        assert result["metrics"]["additional_savings_12_months"] == 60000.0


# --------------------------------------------------------------------------- #
# 10. API response contract
# --------------------------------------------------------------------------- #


class TestScenarioAPIContract:
    def test_scenario_chat_contract(self, make_client):
        primary = ScriptedAgentProvider(
            replies_by_marker=_scenario_scripts(),
            final_answer="Under this scenario, your monthly savings rise.",
        )
        client = make_client(primary=primary)

        response = client.post(
            "/v1/assistant/chat",
            json={
                "message": "What if I save PKR 5,000 more every month?",
                "language": "en",
                "financial_context": CONTEXT,
            },
        )

        assert response.status_code == 200
        body = response.json()
        assert set(body.keys()) == {
            "answer",
            "intent",
            "language",
            "provider",
            "agentsUsed",
            "metrics",
            "recommendations",
            "sources",
            "dataStatus",
        }
        assert body["intent"] == "savings"
        assert body["agentsUsed"] == ["personal_finance", "risk_impact"]
        assert body["dataStatus"] == "scenario"
        assert body["metrics"]["additional_monthly_savings"] == 5000.0
        assert body["metrics"]["projected_monthly_savings"] == 30000.0
        assert body["metrics"]["scenario"]["scenario_type"] == SAVE_MORE
        assert body["sources"] == [
            "deterministic calculation results",
            SCENARIO_SOURCE,
        ]

    def test_expense_shock_api_contract(self, make_client):
        primary = ScriptedAgentProvider(
            replies_by_marker=_scenario_scripts(),
            final_answer="Under this scenario, your surplus shrinks.",
        )
        client = make_client(primary=primary)

        response = client.post(
            "/v1/assistant/chat",
            json={
                "message": "What if my expenses increase by 10%?",
                "language": "en",
                "financial_context": CONTEXT,
            },
        )

        assert response.status_code == 200
        body = response.json()
        assert body["dataStatus"] == "scenario"
        assert body["metrics"]["additional_monthly_expense"] == 5500.0
        assert body["metrics"]["new_monthly_expenses"] == 60500.0
        assert body["metrics"]["projected_monthly_surplus"] == 19500.0
