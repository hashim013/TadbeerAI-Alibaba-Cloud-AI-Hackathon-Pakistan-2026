"""Deterministic What-If calculators — Decimal arithmetic, zero LLM.

Every function is pure: profile in, typed :class:`ScenarioResult` out.
Money is computed with ``decimal.Decimal`` (quantized to 2dp at the
boundary, percentages to 1dp). Missing profile fields degrade to honest
limitations — a number is either computed from the user's real context or
not reported at all. Nothing here ever consults the network or an LLM.
"""

from __future__ import annotations

from decimal import Decimal, InvalidOperation
from typing import Any

from .models import (
    EXPENSE_SHOCK,
    RATE_SHOCK,
    SAVE_MORE,
    STATUS_CALCULATED,
    STATUS_INSUFFICIENT_CONTEXT,
    STATUS_REJECTED,
    ScenarioParameters,
    ScenarioResult,
)

_TWO_PLACES = Decimal("0.01")
_ONE_PLACE = Decimal("0.1")
_PCT_BOUNDS = (Decimal(-100), Decimal(100))
_MAX_MONTHS = 600

#: context keys whose presence marks debt/borrowing information
_DEBT_KEY_MARKERS: tuple[str, ...] = (
    "debt", "loan", "emi", "mortgage", "credit", "leasing",
)


# --------------------------------------------------------------------------- #
# input validation
# --------------------------------------------------------------------------- #


def _decimal(value: Any) -> Decimal | None:
    """Non-negative finite Decimal from int/float/str/Decimal, else None."""
    if isinstance(value, bool) or value is None:
        return None
    if isinstance(value, Decimal):
        number = value
    elif isinstance(value, (int, float)):
        number = Decimal(str(value))
    elif isinstance(value, str):
        try:
            number = Decimal(value.replace(",", "").strip())
        except InvalidOperation:
            return None
    else:
        return None
    if number.is_nan() or number.is_infinite() or number < 0:
        return None
    return number


def _money(value: Decimal) -> Decimal:
    return value.quantize(_TWO_PLACES)


def _round1(value: Decimal) -> Decimal:
    return value.quantize(_ONE_PLACE)


def _reject(scenario_type: str, reason: str) -> ScenarioResult:
    return ScenarioResult(
        scenario_type=scenario_type,
        status=STATUS_REJECTED,
        limitations=[reason],
    )


def _valid_pct(pct: Decimal) -> bool:
    return _PCT_BOUNDS[0] < pct <= _PCT_BOUNDS[1]


# --------------------------------------------------------------------------- #
# A. save more
# --------------------------------------------------------------------------- #


def calculate_savings_scenario(
    delta: Decimal,
    context: dict[str, Any],
    months: int | None = None,
) -> ScenarioResult:
    """Simple savings accumulation for a monthly savings increase.

    No investment returns or interest are assumed — this is plain
    accumulation of the user's stated additional amount.
    """
    if delta <= 0:
        return _reject(
            SAVE_MORE,
            f"Invalid savings amount ({delta}) — must be a positive PKR amount.",
        )
    if months is not None and not 1 <= months <= _MAX_MONTHS:
        return _reject(
            SAVE_MORE,
            f"Invalid month count ({months}) — must be between 1 and {_MAX_MONTHS}.",
        )

    income = _decimal(context.get("monthly_income"))
    expenses = _decimal(context.get("monthly_expenses"))

    assumptions: dict[str, Any] = {
        "additional_monthly_savings_pkr": _money(delta),
    }
    inputs: dict[str, Any] = {}
    outputs: dict[str, Any] = {
        "additional_monthly_savings": _money(delta),
        "additional_savings_6_months": _money(delta * 6),
        "additional_savings_12_months": _money(delta * 12),
    }
    if months is not None:
        outputs["custom_months"] = months
        outputs[f"additional_savings_{months}_months"] = _money(delta * months)

    limitations = [
        "Simple savings accumulation only — no investment returns or "
        "interest assumed.",
        "This is an illustrative calculation, not a forecast.",
    ]

    if income is not None:
        inputs["monthly_income"] = _money(income)
    if expenses is not None:
        inputs["monthly_expenses"] = _money(expenses)

    if income is not None and expenses is not None:
        current = income - expenses
        outputs["current_monthly_savings"] = _money(current)
        outputs["new_monthly_savings"] = _money(current + delta)
        if income > 0:
            outputs["current_savings_rate_pct"] = _round1(current / income * 100)
            outputs["new_savings_rate_pct"] = _round1(
                (current + delta) / income * 100
            )
    else:
        limitations.append(
            "No income/expense information provided — current savings, new "
            "monthly savings and savings rates not calculated."
        )

    return ScenarioResult(
        scenario_type=SAVE_MORE,
        status=STATUS_CALCULATED,
        assumptions=assumptions,
        inputs=inputs,
        outputs=outputs,
        limitations=limitations,
    )


# --------------------------------------------------------------------------- #
# B. expense shock / inflation impact
# --------------------------------------------------------------------------- #


def calculate_expense_shock(
    pct: Decimal, context: dict[str, Any]
) -> ScenarioResult:
    """Project a user-defined percentage change in monthly expenses."""
    if not _valid_pct(pct):
        return _reject(
            EXPENSE_SHOCK,
            f"Invalid percentage ({pct}%) — must be greater than -100% and "
            f"at most 100%.",
        )

    income = _decimal(context.get("monthly_income"))
    expenses = _decimal(context.get("monthly_expenses"))
    savings = _decimal(context.get("total_savings"))

    assumptions: dict[str, Any] = {"expense_change_pct": pct}
    inputs: dict[str, Any] = {}
    outputs: dict[str, Any] = {"expense_shock_pct": pct}
    limitations = [
        f"The {pct}% expense change is a user-defined scenario assumption, "
        "not a forecast of actual inflation.",
    ]

    if income is not None:
        inputs["monthly_income"] = _money(income)
    if savings is not None:
        inputs["total_savings"] = _money(savings)

    if expenses is None or expenses <= 0:
        limitations.insert(
            0,
            "No valid monthly expense information — expense shock cannot "
            "be quantified.",
        )
        return ScenarioResult(
            scenario_type=EXPENSE_SHOCK,
            status=STATUS_INSUFFICIENT_CONTEXT,
            assumptions=assumptions,
            inputs=inputs,
            outputs=outputs,
            limitations=limitations,
        )

    inputs["monthly_expenses"] = _money(expenses)
    additional = _money(expenses * pct / 100)
    new_expenses = _money(expenses + additional)
    outputs["current_monthly_expenses"] = _money(expenses)
    outputs["additional_monthly_expense"] = additional
    outputs["new_monthly_expenses"] = new_expenses

    if income is not None and income > 0:
        current_surplus = _money(income - expenses)
        projected_surplus = _money(income - new_expenses)
        outputs["current_monthly_surplus"] = current_surplus
        outputs["projected_monthly_surplus"] = projected_surplus
        outputs["current_savings_rate_pct"] = _round1(
            (income - expenses) / income * 100
        )
        outputs["projected_savings_rate_pct"] = _round1(
            (income - new_expenses) / income * 100
        )

    if savings is not None and new_expenses > 0:
        outputs["current_runway_months"] = _round1(savings / expenses)
        outputs["projected_runway_months"] = _round1(savings / new_expenses)

    return ScenarioResult(
        scenario_type=EXPENSE_SHOCK,
        status=STATUS_CALCULATED,
        assumptions=assumptions,
        inputs=inputs,
        outputs=outputs,
        limitations=limitations,
    )


# --------------------------------------------------------------------------- #
# C. interest / rate shock
# --------------------------------------------------------------------------- #


def _debt_fields(context: dict[str, Any]) -> dict[str, Decimal]:
    found: dict[str, Decimal] = {}
    for key, value in (context or {}).items():
        lowered = str(key).lower()
        if any(marker in lowered for marker in _DEBT_KEY_MARKERS):
            number = _decimal(value)
            if number is not None:
                found[str(key)] = number
    return found


def calculate_rate_scenario(
    pct: Decimal, context: dict[str, Any]
) -> ScenarioResult:
    """A rate change scenario — quantified only with debt information.

    Without loan/debt details the personal borrowing impact cannot be
    quantified, and it is NEVER invented: the result stays qualitative and
    the Risk & Impact agent explains possible effects.
    """
    if not _valid_pct(pct):
        return _reject(
            RATE_SHOCK,
            f"Invalid percentage ({pct}%) — must be greater than -100% and "
            f"at most 100%.",
        )

    assumptions: dict[str, Any] = {"rate_change_percentage_points": pct}
    inputs: dict[str, Any] = {}
    outputs: dict[str, Any] = {"rate_change_percentage_points": pct}
    limitations = [
        f"The {pct} percentage-point rate change is a user-defined scenario "
        "assumption, not a forecast of SBP policy.",
    ]

    debt = _debt_fields(context)
    if debt:
        inputs["debt_context"] = {
            key: _money(value) for key, value in debt.items()
        }
        limitations.append(
            "Loan rate, tenure and outstanding balance details are needed "
            "to quantify the borrowing-cost impact — the listed debt fields "
            "are shown for context only."
        )
    else:
        limitations.append(
            "No loan/debt information provided — the direct personal "
            "borrowing impact cannot be quantified. Possible effects can "
            "still be explained qualitatively."
        )

    return ScenarioResult(
        scenario_type=RATE_SHOCK,
        status=STATUS_INSUFFICIENT_CONTEXT,
        assumptions=assumptions,
        inputs=inputs,
        outputs=outputs,
        limitations=limitations,
    )


# --------------------------------------------------------------------------- #
# entry point used by the deterministic tools node
# --------------------------------------------------------------------------- #


def run_scenario(
    params: ScenarioParameters, context: dict[str, Any]
) -> ScenarioResult:
    """Dispatch parsed parameters to the matching calculator."""
    if params.scenario_type == SAVE_MORE and params.amount_pkr is not None:
        return calculate_savings_scenario(
            params.amount_pkr, context, months=params.months
        )
    if params.pct_change is not None:
        if params.scenario_type == EXPENSE_SHOCK:
            return calculate_expense_shock(params.pct_change, context)
        if params.scenario_type == RATE_SHOCK:
            return calculate_rate_scenario(params.pct_change, context)
    return _reject(
        params.scenario_type,
        "Incomplete scenario parameters — no calculation performed.",
    )
