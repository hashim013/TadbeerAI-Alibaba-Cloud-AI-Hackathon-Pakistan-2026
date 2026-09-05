"""Deterministic calculation tools — pure functions, zero LLM involvement.

Phase 3B wires the What-If scenario engine (``core/scenarios``) into the
graph here: user messages are parsed into scenario parameters by regex,
``run_scenario`` computes every number with ``Decimal``, and the result is
attached to the graph state for the Risk & Impact agent and the composer.
The LLM is NEVER the calculator.

The Phase 2 entry points (``financial_calculator``, ``impact_calculator``,
``extract_savings_delta``) keep their exact contracts — the latter two now
delegate to the scenario engine instead of duplicating arithmetic.
"""

from __future__ import annotations

from decimal import Decimal
from typing import Any

from core.scenarios import (
    calculate_savings_scenario,
    extract_scenario_parameters,
    extract_save_amount,
    normalize_message,
    run_scenario,
)

from .state import AgentState


def _to_float(value: Any) -> float | None:
    """Return a non-negative finite number, or None when unusable."""
    if isinstance(value, bool) or value is None:
        return None
    if isinstance(value, (int, float)):
        number = float(value)
    elif isinstance(value, str):
        try:
            number = float(value.replace(",", "").strip())
        except ValueError:
            return None
    else:
        return None
    if number != number or number in (float("inf"), float("-inf")):  # NaN / inf
        return None
    if number < 0:
        return None
    return number


def financial_calculator(context: dict[str, Any]) -> dict[str, float]:
    """Baseline personal metrics from the financial profile.

    Pure arithmetic: monthly savings, savings rate, expense ratio and
    emergency-fund runway. Returns ``{}`` when the context is missing the
    required fields — it never guesses.
    """
    income = _to_float(context.get("monthly_income"))
    expenses = _to_float(context.get("monthly_expenses"))
    savings = _to_float(context.get("total_savings"))
    if income is None or expenses is None or income <= 0:
        return {}

    result: dict[str, float] = {}
    monthly_savings = round(income - expenses, 2)
    result["monthly_savings"] = monthly_savings
    result["savings_rate_pct"] = round(monthly_savings / income * 100, 1)
    result["expense_ratio_pct"] = round(expenses / income * 100, 1)
    if savings is not None and expenses > 0:
        result["runway_months"] = round(savings / expenses, 1)
    return result


def extract_savings_delta(message: str) -> float | None:
    """Parse a monthly savings delta from a what-if message.

    Thin compatibility wrapper over the scenario parser (same regexes as
    Phase 2 plus the Roman-Urdu/Urdu patterns): returns the amount as a
    positive monthly savings increase, or None.
    """
    amount = extract_save_amount(normalize_message(message))
    return float(amount) if amount is not None else None


def impact_calculator(
    scenario: dict[str, Any], context: dict[str, Any]
) -> dict[str, float]:
    """Project the effect of a savings delta on the user's profile.

    Delegates to ``calculate_savings_scenario`` and maps the result onto
    the Phase 2 flat keys. Returns ``{}`` when inputs are insufficient
    (the full profile is required for the legacy projection).
    """
    delta = _to_float(scenario.get("monthly_savings_delta"))
    if delta is None or delta == 0:
        return {}

    result = calculate_savings_scenario(Decimal(str(delta)), context)
    flat = result.flat_outputs()
    legacy_keys = (
        "monthly_savings_delta",
        "projected_monthly_savings",
        "projected_savings_rate_pct",
        "projected_annual_additional_savings",
    )
    return {key: flat[key] for key in legacy_keys if key in flat}


def deterministic_node(state: AgentState) -> dict:
    """Graph node: run the deterministic tools when calculations are needed.

    No-op (returns nothing) when the supervisor did not request
    calculations. The baseline metrics come from ``financial_calculator``;
    a recognized what-if message additionally runs the scenario engine and
    attaches the structured result under ``deterministic_results["scenario"]``
    (plus its flat outputs for the metrics contract). Missing financial
    context produces a limitation note instead of invented numbers — but
    a scenario still computes whatever its stated assumption allows.
    """
    if not state.get("needs_calculation"):
        return {}

    context: dict[str, Any] = state.get("financial_context") or {}
    message = state.get("user_message", "")

    results: dict[str, Any] = {}
    baseline = financial_calculator(context)
    results.update(baseline)

    params = extract_scenario_parameters(message)
    if params is not None:
        scenario = run_scenario(params, context)
        results["scenario"] = scenario.to_dict()
        results.update(scenario.flat_outputs())

    updates: dict[str, Any] = {"deterministic_results": results}
    if not results:
        updates["limitations"] = [
            "No financial profile connected — personal calculations unavailable."
        ]
    elif not baseline and not (results.get("scenario") or {}).get("inputs"):
        # the scenario ran but the profile contributed nothing usable
        updates["limitations"] = [
            "No financial profile connected — scenario results limited to "
            "the stated assumption."
        ]
    return updates
