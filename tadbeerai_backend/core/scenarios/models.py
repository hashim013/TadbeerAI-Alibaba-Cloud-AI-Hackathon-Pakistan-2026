"""Typed models for the deterministic What-If scenario engine.

A scenario is the user's OWN assumption ("what if my expenses rise 10%") —
never a live indicator and never a forecast. Every result carries
code-controlled provenance (``SCENARIO_SOURCE``) so scenario projections can
never be confused with live economic data or with LLM claims.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from decimal import Decimal
from typing import Any

#: code-controlled provenance label for every scenario result (never LLM-set)
SCENARIO_SOURCE = "user-defined scenario (deterministic calculation)"

#: scenario family identifiers
SAVE_MORE = "save_more"
EXPENSE_SHOCK = "expense_shock"
RATE_SHOCK = "rate_shock"

#: scenario outcome statuses
STATUS_CALCULATED = "calculated"
STATUS_INSUFFICIENT_CONTEXT = "insufficient_context"
STATUS_REJECTED = "rejected"


@dataclass(frozen=True)
class ScenarioParameters:
    """Deterministically parsed scenario request from a user message.

    * ``amount_pkr`` — monthly savings increase (save_more)
    * ``pct_change`` — signed percentage for expense/rate shocks (+10 = +10%)
    * ``months``     — optional custom accumulation horizon (save_more)
    """

    scenario_type: str
    amount_pkr: Decimal | None = None
    pct_change: Decimal | None = None
    months: int | None = None


def _jsonify(value: Any) -> Any:
    """Convert Decimals to floats so results are JSON-safe everywhere."""
    if isinstance(value, Decimal):
        return float(value)
    if isinstance(value, dict):
        return {key: _jsonify(item) for key, item in value.items()}
    if isinstance(value, (list, tuple)):
        return [_jsonify(item) for item in value]
    return value


@dataclass
class ScenarioResult:
    """Outcome of one deterministic what-if calculation.

    Every field is machine-produced: the LLM only ever sees (and may only
    interpret) this structure — it can never add numbers, sources or status.
    """

    scenario_type: str
    status: str
    assumptions: dict[str, Any] = field(default_factory=dict)
    inputs: dict[str, Any] = field(default_factory=dict)
    outputs: dict[str, Any] = field(default_factory=dict)
    limitations: list[str] = field(default_factory=list)
    source: str = SCENARIO_SOURCE

    def to_dict(self) -> dict[str, Any]:
        """JSON-safe structured view (Decimal -> float)."""
        return {
            "scenario_type": self.scenario_type,
            "status": self.status,
            "source": self.source,
            "assumptions": _jsonify(self.assumptions),
            "inputs": _jsonify(self.inputs),
            "outputs": _jsonify(self.outputs),
            "limitations": list(self.limitations),
        }

    def flat_outputs(self) -> dict[str, Any]:
        """Scalar outputs flattened for the metrics dict.

        For save-more with a full profile this also includes the Phase 2
        ``projected_*`` keys so the older consumers keep working unchanged.
        """
        flat: dict[str, Any] = {}
        for key, value in self.outputs.items():
            if isinstance(value, Decimal):
                flat[key] = float(value)
            elif isinstance(value, (int, float, str)):
                flat[key] = value
        if self.scenario_type == SAVE_MORE and "new_monthly_savings" in flat:
            flat["monthly_savings_delta"] = flat["additional_monthly_savings"]
            flat["projected_monthly_savings"] = flat["new_monthly_savings"]
            flat["projected_savings_rate_pct"] = flat["new_savings_rate_pct"]
            flat["projected_annual_additional_savings"] = flat[
                "additional_savings_12_months"
            ]
        return flat
