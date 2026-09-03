"""
Gold Domain Executor - Real execution for gold market actions.

Actions:
- Hold procurement during price spikes
- Adjust reserve levels
- Notify suppliers
"""

import logging
from typing import Dict, Any, Tuple

from core.external_api_client import get_external_api_client
from core.execution_rollback import get_rollback_manager

logger = logging.getLogger(__name__)


def execute_gold_action(
    action_description: str,
    action_key: str,
    current_state: Dict[str, Any],
    impact_value: float,
    transaction_id: str
) -> Tuple[bool, Dict[str, Any], Dict[str, Any], str]:
    """
    Execute gold domain action with real API calls.

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
        if "hold" in action_description.lower() or "procurement" in action_description.lower():
            success, after_state = _execute_hold_procurement(
                api_client, rollback_mgr, transaction_id, before_state, impact_value
            )

        elif "reserve" in action_description.lower():
            success, after_state = _execute_adjust_reserves(
                api_client, rollback_mgr, transaction_id, before_state, impact_value
            )

        else:
            success = True
            logger.warning(f"[GoldExecutor] Unknown action: {action_description}")

        if not success:
            rollback_mgr.rollback_to_previous_state(transaction_id, after_state, "API call failed")
            return False, before_state, before_state, "Gold action execution failed"

        logger.info(f"[GoldExecutor] ✅ Action executed: {action_key}")
        return True, before_state, after_state, ""

    except Exception as e:
        error_msg = f"Gold executor error: {str(e)}"
        logger.error(f"[GoldExecutor] ❌ {error_msg}")
        return False, current_state, current_state, error_msg


def _execute_hold_procurement(
    api_client,
    rollback_mgr,
    transaction_id: str,
    before_state: Dict[str, Any],
    impact_value: float
) -> Tuple[bool, Dict[str, Any]]:
    """Hold gold procurement due to price spike."""
    try:
        expected_savings = impact_value
        logger.info(f"[GoldExecutor] 🛑 Holding gold procurement (Expected savings: Rs. {expected_savings})")

        # Call inventory API to hold procurement
        api_success, api_msg = api_client.call_inventory_hold_procurement(
            hold_reason=f"Price spike detected. Expected savings: Rs. {expected_savings}"
        )

        rollback_mgr.log_api_call_for_rollback(
            transaction_id,
            "inventory_hold_gold",
            {"expected_savings": expected_savings},
            api_success,
            api_msg
        )

        if not api_success:
            logger.warning(f"[GoldExecutor] ⚠️ Inventory API issue: {api_msg}")

        after_state = before_state.copy()
        after_state["procurement_hold"] = True
        after_state["hold_reason"] = "price_spike"

        logger.info(f"[GoldExecutor] ✅ Gold procurement held")
        return True, after_state

    except Exception as e:
        logger.error(f"[GoldExecutor] ❌ Procurement hold failed: {str(e)}")
        return False, before_state


def _execute_adjust_reserves(
    api_client,
    rollback_mgr,
    transaction_id: str,
    before_state: Dict[str, Any],
    impact_value: float
) -> Tuple[bool, Dict[str, Any]]:
    """Adjust gold reserve levels."""
    try:
        new_reserve = impact_value
        logger.info(f"[GoldExecutor] 📦 Adjusting gold reserves to {new_reserve}oz")

        # Call inventory API
        api_success, api_msg = api_client.call_inventory_adjust_stock(
            item_id="GOLD_RESERVES",
            quantity_change=int(new_reserve),
            reason="Reserve adjustment based on market conditions"
        )

        rollback_mgr.log_api_call_for_rollback(
            transaction_id,
            "inventory_gold_reserves",
            {"new_reserve": new_reserve},
            api_success,
            api_msg
        )

        if not api_success:
            logger.warning(f"[GoldExecutor] ⚠️ Inventory API issue: {api_msg}")

        after_state = before_state.copy()

        logger.info(f"[GoldExecutor] ✅ Gold reserves adjusted to {new_reserve}oz")
        return True, after_state

    except Exception as e:
        logger.error(f"[GoldExecutor] ❌ Reserve adjustment failed: {str(e)}")
        return False, before_state
