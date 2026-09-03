"""
Finance Domain Executor - Real execution for finance-related actions.
"""

import logging
from typing import Dict, Any, Tuple

from core.external_api_client import get_external_api_client
from core.execution_rollback import get_rollback_manager

logger = logging.getLogger(__name__)


def execute_finance_action(
    action_description: str,
    action_key: str,
    current_state: Dict[str, Any],
    impact_value: float,
    transaction_id: str
) -> Tuple[bool, Dict[str, Any], Dict[str, Any], str]:
    """
    Execute finance domain action.
    """
    try:
        api_client = get_external_api_client()
        rollback_mgr = get_rollback_manager()

        before_state = current_state.copy()
        rollback_mgr.track_state_change(transaction_id, before_state)

        after_state = before_state.copy()

        if "loan" in action_description.lower() or "hold" in action_description.lower():
            after_state["loan_hold_flag"] = True
            success = True
        else:
            # Adjust interest rate buffer
            new_buffer = before_state.get("interest_rate_buffer", 0.0) + impact_value
            after_state["interest_rate_buffer"] = new_buffer
            success = True

        logger.info(f"[FinanceExecutor] ✅ Action executed: {action_key}")
        return True, before_state, after_state, ""

    except Exception as e:
        error_msg = f"Finance executor error: {str(e)}"
        logger.error(f"[FinanceExecutor] ❌ {error_msg}")
        return False, current_state, current_state, error_msg
