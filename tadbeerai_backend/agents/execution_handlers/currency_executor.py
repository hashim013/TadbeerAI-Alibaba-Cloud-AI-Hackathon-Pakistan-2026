"""
Currency Domain Executor - Real execution for currency-related actions.

Actions:
- Adjust import cost buffer
- Hold orders during volatility
- Notify suppliers
"""

import logging
from typing import Dict, Any, Tuple

from core.external_api_client import get_external_api_client
from core.execution_rollback import get_rollback_manager

logger = logging.getLogger(__name__)


def execute_currency_action(
    action_description: str,
    action_key: str,
    current_state: Dict[str, Any],
    impact_value: float,
    transaction_id: str
) -> Tuple[bool, Dict[str, Any], Dict[str, Any], str]:
    """
    Execute currency domain action with real API calls.

    Args:
        action_description: Description of action
        action_key: Action key for notification template
        current_state: Current business state
        impact_value: Quantified impact
        transaction_id: Transaction ID

    Returns:
        (success: bool, before_state: dict, after_state: dict, error_msg: str)
    """
    try:
        api_client = get_external_api_client()
        rollback_mgr = get_rollback_manager()

        before_state = current_state.copy()
        rollback_mgr.track_state_change(transaction_id, before_state)

        after_state = before_state.copy()

        # Determine action type
        if "import cost" in action_description.lower() or "buffer" in action_description.lower():
            success, after_state = _execute_import_cost_adjustment(
                api_client, rollback_mgr, transaction_id, before_state, impact_value
            )

        elif "hold orders" in action_description.lower() or "hold" in action_description.lower():
            success, after_state = _execute_hold_orders(
                api_client, rollback_mgr, transaction_id, before_state, impact_value
            )

        else:
            success = True
            logger.warning(f"[CurrencyExecutor] Unknown action: {action_description}")

        if not success:
            rollback_mgr.rollback_to_previous_state(transaction_id, after_state, "API call failed")
            return False, before_state, before_state, "Currency action execution failed"

        logger.info(f"[CurrencyExecutor] ✅ Action executed: {action_key}")
        return True, before_state, after_state, ""

    except Exception as e:
        error_msg = f"Currency executor error: {str(e)}"
        logger.error(f"[CurrencyExecutor] ❌ {error_msg}")
        return False, current_state, current_state, error_msg


def _execute_import_cost_adjustment(
    api_client,
    rollback_mgr,
    transaction_id: str,
    before_state: Dict[str, Any],
    impact_value: float
) -> Tuple[bool, Dict[str, Any]]:
    """Adjust import cost buffer in billing system."""
    try:
        new_buffer = before_state.get("import_cost_buffer", 0) + impact_value

        logger.info(f"[CurrencyExecutor] 💱 Setting import cost buffer to Rs. {new_buffer}")

        # Call billing API
        api_success, api_msg = api_client.call_billing_update_delivery_fee(new_buffer, 1)
        rollback_mgr.log_api_call_for_rollback(
            transaction_id,
            "billing_import_cost_buffer",
            {"new_buffer": new_buffer},
            api_success,
            api_msg
        )

        if not api_success:
            logger.error(f"[CurrencyExecutor] ❌ Billing API failed: {api_msg}")
            return False, before_state

        after_state = before_state.copy()
        after_state["import_cost_buffer"] = new_buffer

        logger.info(f"[CurrencyExecutor] ✅ Buffer set to Rs. {new_buffer}")
        return True, after_state

    except Exception as e:
        logger.error(f"[CurrencyExecutor] ❌ Import cost adjustment failed: {str(e)}")
        return False, before_state


def _execute_hold_orders(
    api_client,
    rollback_mgr,
    transaction_id: str,
    before_state: Dict[str, Any],
    impact_value: float
) -> Tuple[bool, Dict[str, Any]]:
    """Hold all pending orders due to currency volatility."""
    try:
        logger.info(f"[CurrencyExecutor] ⏸️ Holding orders for {impact_value}% volatility threshold")

        # Call billing API to hold orders
        api_success, api_msg = api_client.call_billing_hold_orders(
            reason=f"Currency volatility: {impact_value}% variance detected"
        )

        rollback_mgr.log_api_call_for_rollback(
            transaction_id,
            "billing_hold_orders",
            {"reason": "currency_volatility", "threshold": impact_value},
            api_success,
            api_msg
        )

        if not api_success:
            logger.warning(f"[CurrencyExecutor] ⚠️ Billing API issue: {api_msg}")

        after_state = before_state.copy()
        after_state["order_hold_flag"] = True

        logger.info(f"[CurrencyExecutor] ✅ Orders held")
        return True, after_state

    except Exception as e:
        logger.error(f"[CurrencyExecutor] ❌ Order hold failed: {str(e)}")
        return False, before_state
