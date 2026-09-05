"""Deterministic What-If scenario engine (Phase 3B).

The LLM never performs financial arithmetic: user messages are parsed into
:class:`ScenarioParameters` by regex (English / Roman Urdu / Urdu), the
calculators compute every number with ``Decimal`` from the user's real
financial context, and the agents only interpret the resulting
:class:`ScenarioResult`.

Scenario outputs are always distinct from live economic indicators:
``ScenarioResult.source`` is code-controlled and reads
"user-defined scenario (deterministic calculation)".
"""

from __future__ import annotations

from .calculators import (
    calculate_expense_shock,
    calculate_rate_scenario,
    calculate_savings_scenario,
    run_scenario,
)
from .models import (
    EXPENSE_SHOCK,
    RATE_SHOCK,
    SAVE_MORE,
    SCENARIO_SOURCE,
    STATUS_CALCULATED,
    STATUS_INSUFFICIENT_CONTEXT,
    STATUS_REJECTED,
    ScenarioParameters,
    ScenarioResult,
)
from .parsing import extract_save_amount, extract_scenario_parameters, normalize_message

__all__ = [
    "EXPENSE_SHOCK",
    "RATE_SHOCK",
    "SAVE_MORE",
    "SCENARIO_SOURCE",
    "STATUS_CALCULATED",
    "STATUS_INSUFFICIENT_CONTEXT",
    "STATUS_REJECTED",
    "ScenarioParameters",
    "ScenarioResult",
    "calculate_expense_shock",
    "calculate_rate_scenario",
    "calculate_savings_scenario",
    "extract_save_amount",
    "extract_scenario_parameters",
    "normalize_message",
    "run_scenario",
]
