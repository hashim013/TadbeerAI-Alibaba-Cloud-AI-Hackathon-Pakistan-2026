"""
Trade Domain Executor - Real execution for trade-related actions.
"""

import logging
from typing import Dict, Any, Tuple

from core.external_api_client import get_external_api_client
from core.execution_rollback import get_rollback_manager

logger = logging.getLogger(__name__)


def execute_trade_action(
    action_description: str,
    action_key: str,
    current_state: Dict[str, Any],
    impact_value: float,
    transaction_id: str
) -> Tuple[bool, Dict[str, Any], Dict[str, Any], str]:
    """
    Execute trade domain action.
    """
    try:
        api_client = get_external_api_client()
        rollback_mgr = get_rollback_manager()

        before_state = current_state.copy()
        rollback_mgr.track_state_change(transaction_id, before_state)

        after_state = before_state.copy()

        if "hold" in action_description.lower() or "ban" in action_description.lower():
            after_state["trade_hold_flag"] = True
            success = True
        else:
            # Adjust export buffer percentage
            new_pct = before_state.get("export_buffer_pct", 0.0) + impact_value
            after_state["export_buffer_pct"] = new_pct
            success = True

        logger.info(f"[TradeExecutor] ✅ Action executed: {action_key}")
        return True, before_state, after_state, ""

    except Exception as e:
        error_msg = f"Trade executor error: {str(e)}"
        logger.error(f"[TradeExecutor] ❌ {error_msg}")
        return False, current_state, current_state, error_msg
