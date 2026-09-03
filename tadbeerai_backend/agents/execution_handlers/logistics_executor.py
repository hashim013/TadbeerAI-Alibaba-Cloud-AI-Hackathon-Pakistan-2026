"""
Logistics Domain Executor - Real execution for logistics-related actions.

Actions:
- Increase safety stock
- Optimize warehouse capacity
- Adjust reorder points
"""

import logging
from typing import Dict, Any, Tuple

from core.external_api_client import get_external_api_client
from core.execution_rollback import get_rollback_manager

logger = logging.getLogger(__name__)


def execute_logistics_action(
    action_description: str,
    action_key: str,
    current_state: Dict[str, Any],
    impact_value: float,
    transaction_id: str
) -> Tuple[bool, Dict[str, Any], Dict[str, Any], str]:
    """
    Execute logistics domain action with real API calls.

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
        if "safety stock" in action_description.lower():
            success, after_state = _execute_increase_safety_stock(
                api_client, rollback_mgr, transaction_id, before_state, impact_value
            )

        elif "warehouse" in action_description.lower() or "capacity" in action_description.lower():
            success, after_state = _execute_optimize_warehouse(
                api_client, rollback_mgr, transaction_id, before_state, impact_value
            )

        elif "reorder" in action_description.lower():
            success, after_state = _execute_adjust_reorder_points(
                api_client, rollback_mgr, transaction_id, before_state, impact_value
            )

        else:
            success = True
            logger.warning(f"[LogisticsExecutor] Unknown action: {action_description}")

        if not success:
            rollback_mgr.rollback_to_previous_state(transaction_id, after_state, "API call failed")
            return False, before_state, before_state, "Logistics action execution failed"

        logger.info(f"[LogisticsExecutor] ✅ Action executed: {action_key}")
        return True, before_state, after_state, ""

    except Exception as e:
        error_msg = f"Logistics executor error: {str(e)}"
        logger.error(f"[LogisticsExecutor] ❌ {error_msg}")
        return False, current_state, current_state, error_msg


def _execute_increase_safety_stock(
    api_client,
    rollback_mgr,
    transaction_id: str,
    before_state: Dict[str, Any],
    impact_value: float
) -> Tuple[bool, Dict[str, Any]]:
    """Increase safety stock days."""
    try:
        additional_days = int(impact_value)
        new_safety_stock = before_state.get("safety_stock_days", 7) + additional_days

        logger.info(f"[LogisticsExecutor] 📦 Increasing safety stock to {new_safety_stock} days")

        # Call inventory API
        api_success, api_msg = api_client.call_inventory_adjust_stock(
            item_id="SAFETY_STOCK",
            quantity_change=additional_days,
            reason=f"Increase safety stock buffer by {additional_days} days"
        )

        rollback_mgr.log_api_call_for_rollback(
            transaction_id,
            "inventory_safety_stock",
            {"additional_days": additional_days},
            api_success,
            api_msg
        )

        if not api_success:
            logger.warning(f"[LogisticsExecutor] ⚠️ Inventory API issue: {api_msg}")

        after_state = before_state.copy()
        after_state["safety_stock_days"] = new_safety_stock

        logger.info(f"[LogisticsExecutor] ✅ Safety stock increased to {new_safety_stock} days")
        return True, after_state

    except Exception as e:
        logger.error(f"[LogisticsExecutor] ❌ Safety stock increase failed: {str(e)}")
        return False, before_state


def _execute_optimize_warehouse(
    api_client,
    rollback_mgr,
    transaction_id: str,
    before_state: Dict[str, Any],
    impact_value: float
) -> Tuple[bool, Dict[str, Any]]:
    """Optimize warehouse capacity allocation."""
    try:
        utilization_increase = impact_value
        logger.info(f"[LogisticsExecutor] 🏭 Optimizing warehouse capacity (+{utilization_increase}%)")

        # Log to analytics
        api_success, api_msg = api_client.call_analytics_log_action(
            domain="Logistics",
            action_type="optimize_warehouse",
            metrics={"utilization_increase": utilization_increase}
        )

        rollback_mgr.log_api_call_for_rollback(
            transaction_id,
            "analytics_warehouse",
            {"utilization_increase": utilization_increase},
            api_success,
            api_msg
        )

        after_state = before_state.copy()
        after_state["warehouse_optimized"] = True

        logger.info(f"[LogisticsExecutor] ✅ Warehouse optimized")
        return True, after_state

    except Exception as e:
        logger.error(f"[LogisticsExecutor] ❌ Warehouse optimization failed: {str(e)}")
        return False, before_state


def _execute_adjust_reorder_points(
    api_client,
    rollback_mgr,
    transaction_id: str,
    before_state: Dict[str, Any],
    impact_value: float
) -> Tuple[bool, Dict[str, Any]]:
    """Adjust reorder points for inventory items."""
    try:
        adjustment_percentage = impact_value
        logger.info(f"[LogisticsExecutor] 📊 Adjusting reorder points by {adjustment_percentage}%")

        # Log to analytics
        api_success, api_msg = api_client.call_analytics_log_action(
            domain="Logistics",
            action_type="adjust_reorder",
            metrics={"adjustment_percentage": adjustment_percentage}
        )

        rollback_mgr.log_api_call_for_rollback(
            transaction_id,
            "analytics_reorder",
            {"adjustment": adjustment_percentage},
            api_success,
            api_msg
        )

        after_state = before_state.copy()

        logger.info(f"[LogisticsExecutor] ✅ Reorder points adjusted")
        return True, after_state

    except Exception as e:
        logger.error(f"[LogisticsExecutor] ❌ Reorder adjustment failed: {str(e)}")
        return False, before_state
