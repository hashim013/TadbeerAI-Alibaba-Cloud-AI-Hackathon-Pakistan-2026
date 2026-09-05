"""Deterministic calculation tool tests — pure math, zero LLM.

Verifies the arithmetic guards of the financial_calculator /
impact_calculator tool interfaces and the savings-delta parser.
"""

from __future__ import annotations

from core.agents.deterministic import (
    deterministic_node,
    extract_savings_delta,
    financial_calculator,
    impact_calculator,
)

CONTEXT = {
    "monthly_income": 80000,
    "monthly_expenses": 55000,
    "total_savings": 200000,
}


# --------------------------------------------------------------------------- #
# financial_calculator
# --------------------------------------------------------------------------- #


class TestFinancialCalculator:
    def test_full_context(self):
        metrics = financial_calculator(CONTEXT)
        assert metrics["monthly_savings"] == 25000.0
        assert metrics["savings_rate_pct"] == 31.2
        assert metrics["expense_ratio_pct"] == 68.8
        assert metrics["runway_months"] == 3.6

    def test_empty_context(self):
        assert financial_calculator({}) == {}

    def test_missing_expenses(self):
        assert financial_calculator({"monthly_income": 80000}) == {}

    def test_zero_income_rejected(self):
        assert financial_calculator(
            {"monthly_income": 0, "monthly_expenses": 1000}
        ) == {}

    def test_negative_values_rejected(self):
        assert financial_calculator(
            {"monthly_income": -50000, "monthly_expenses": 1000}
        ) == {}

    def test_string_numbers_accepted(self):
        metrics = financial_calculator(
            {
                "monthly_income": "80,000",
                "monthly_expenses": "55000",
                "total_savings": "200000",
            }
        )
        assert metrics["monthly_savings"] == 25000.0

    def test_overspending_reported_honestly(self):
        metrics = financial_calculator(
            {"monthly_income": 50000, "monthly_expenses": 60000}
        )
        assert metrics["monthly_savings"] == -10000.0
        assert metrics["savings_rate_pct"] == -20.0

    def test_runway_needs_savings(self):
        metrics = financial_calculator(
            {"monthly_income": 80000, "monthly_expenses": 55000}
        )
        assert "runway_months" not in metrics

    def test_no_division_by_zero_on_zero_expenses(self):
        metrics = financial_calculator(
            {"monthly_income": 80000, "monthly_expenses": 0, "total_savings": 5000}
        )
        assert metrics["expense_ratio_pct"] == 0.0
        assert "runway_months" not in metrics


# --------------------------------------------------------------------------- #
# extract_savings_delta
# --------------------------------------------------------------------------- #


class TestExtractSavingsDelta:
    def test_pkr_amount_with_commas(self):
        assert extract_savings_delta("What if I save PKR 5,000 more every month?") == 5000.0

    def test_rs_amount(self):
        assert extract_savings_delta("If I save Rs 2500 extra monthly") == 2500.0

    def test_plain_saving_amount(self):
        assert extract_savings_delta("how about saving 10000?") == 10000.0

    def test_cut_phrasing(self):
        assert extract_savings_delta("cut my spending by 3000") == 3000.0

    def test_no_amount_returns_none(self):
        assert extract_savings_delta("What is inflation?") is None

    def test_amount_without_save_keyword_returns_none(self):
        assert extract_savings_delta("I have 50000 rupees") is None


# --------------------------------------------------------------------------- #
# impact_calculator
# --------------------------------------------------------------------------- #


class TestImpactCalculator:
    def test_delta_projection(self):
        metrics = impact_calculator({"monthly_savings_delta": 5000}, CONTEXT)
        assert metrics["monthly_savings_delta"] == 5000.0
        assert metrics["projected_monthly_savings"] == 30000.0
        assert metrics["projected_savings_rate_pct"] == 37.5
        assert metrics["projected_annual_additional_savings"] == 60000.0

    def test_no_context_returns_empty(self):
        assert impact_calculator({"monthly_savings_delta": 5000}, {}) == {}

    def test_zero_delta_returns_empty(self):
        assert impact_calculator({"monthly_savings_delta": 0}, CONTEXT) == {}

    def test_invalid_delta_returns_empty(self):
        assert impact_calculator({"monthly_savings_delta": "abc"}, CONTEXT) == {}


# --------------------------------------------------------------------------- #
# deterministic graph node
# --------------------------------------------------------------------------- #


class TestDeterministicNode:
    def test_noop_without_calculation_need(self):
        assert deterministic_node({"needs_calculation": False}) == {}

    def test_runs_with_context(self):
        updates = deterministic_node(
            {
                "needs_calculation": True,
                "financial_context": CONTEXT,
                "user_message": "What if I save PKR 5,000 more?",
            }
        )
        metrics = updates["deterministic_results"]
        assert metrics["monthly_savings"] == 25000.0
        assert metrics["projected_monthly_savings"] == 30000.0
        assert "limitations" not in updates

    def test_empty_context_still_calculates_scenario(self):
        # Phase 3B contract: a stated assumption is computed even without
        # a financial profile — savings-rate style metrics are NOT invented
        updates = deterministic_node(
            {
                "needs_calculation": True,
                "financial_context": {},
                "user_message": "What if I save PKR 5,000 more?",
            }
        )
        metrics = updates["deterministic_results"]
        assert metrics["additional_monthly_savings"] == 5000.0
        assert metrics["additional_savings_6_months"] == 30000.0
        assert metrics["additional_savings_12_months"] == 60000.0
        assert "new_monthly_savings" not in metrics
        assert "new_savings_rate_pct" not in metrics
        assert len(updates["limitations"]) == 1
        assert "No financial profile" in updates["limitations"][0]
        assert metrics["scenario"]["scenario_type"] == "save_more"
        assert metrics["scenario"]["status"] == "calculated"

    def test_empty_context_without_scenario_notes_limitation(self):
        updates = deterministic_node(
            {
                "needs_calculation": True,
                "financial_context": {},
                "user_message": "What happens if rates go up?",
            }
        )
        assert updates["deterministic_results"] == {}
        assert len(updates["limitations"]) == 1
        assert "No financial profile" in updates["limitations"][0]
