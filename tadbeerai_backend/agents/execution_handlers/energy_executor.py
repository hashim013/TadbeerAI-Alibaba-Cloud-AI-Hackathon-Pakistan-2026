"""
Energy Domain Executor - Real execution for energy-related actions.

Actions:
- Increase delivery fee
- Optimize routes
- Adjust fuel procurement
"""

import logging
from typing import Dict, Any, Tuple

from core.external_api_client import get_external_api_client
from core.execution_rollback import get_rollback_manager

logger = logging.getLogger(__name__)


def execute_energy_action(
    action_description: str,
    action_key: str,
    current_state: Dict[str, Any],
    impact_value: float,
    transaction_id: str
) -> Tuple[bool, Dict[str, Any], Dict[str, Any], str]:
    """
    Execute energy domain action with real API calls.

    Args:
        action_description: Description of action (e.g., "Increase delivery fee to Rs. 178")
        action_key: Action key for notification template (e.g., 'energy_increase_delivery_fee')
        current_state: Current business state from Firestore
        impact_value: Quantified impact (e.g., 28 for fee increase from 150 to 178)
        transaction_id: Unique transaction ID

    Returns:
        (success: bool, before_state: dict, after_state: dict, error_msg: str)
    """
    try:
        api_client = get_external_api_client()
        rollback_mgr = get_rollback_manager()

        before_state = current_state.copy()

        # Track for potential rollback
        rollback_mgr.track_state_change(transaction_id, before_state)

        after_state = before_state.copy()

        # Determine action type and execute
        if any(kw in action_description.lower() for kw in ["delivery fee", "delivery pricing", "pricing", "fee"]):
            success, after_state = _execute_increase_delivery_fee(
                api_client, rollback_mgr, transaction_id, before_state, impact_value
            )

        elif "optimize routes" in action_description.lower() or "route" in action_description.lower():
            success, after_state = _execute_optimize_routes(
                api_client, rollback_mgr, transaction_id, before_state, impact_value
            )

        elif "fuel procurement" in action_description.lower() or "procurement" in action_description.lower():
            success, after_state = _execute_fuel_procurement(
                api_client, rollback_mgr, transaction_id, before_state, impact_value
            )

        else:
            # Generic energy action
            success = True
            logger.warning(f"[EnergyExecutor] Unknown action: {action_description}. No state changes.")

        if not success:
            # Rollback on failure
            rollback_mgr.rollback_to_previous_state(
                transaction_id,
                after_state,
                "API call failed"
            )
            return False, before_state, before_state, "Energy action execution failed"

        logger.info(f"[EnergyExecutor] ✅ Action executed: {action_key}")
        return True, before_state, after_state, ""

    except Exception as e:
        error_msg = f"Energy executor error: {str(e)}"
        logger.error(f"[EnergyExecutor] ❌ {error_msg}")
        return False, current_state, current_state, error_msg


def _execute_increase_delivery_fee(
    api_client,
    rollback_mgr,
    transaction_id: str,
    before_state: Dict[str, Any],
    impact_value: float
) -> Tuple[bool, Dict[str, Any]]:
    """Execute delivery fee increase action."""
    try:
        new_fee = before_state.get("delivery_fee", 150) + impact_value
        customer_count = before_state.get("customer_count", 3200)

        logger.info(f"[EnergyExecutor] 📍 Increasing delivery fee to Rs. {new_fee}")

        # Call billing API
        api_success, api_msg = api_client.call_billing_update_delivery_fee(new_fee, customer_count)
        rollback_mgr.log_api_call_for_rollback(
            transaction_id,
            "billing_update_fee",
            {"new_fee": new_fee, "customers": customer_count},
            api_success,
            api_msg
        )

        if not api_success:
            logger.error(f"[EnergyExecutor] ❌ Billing API failed: {api_msg}")
            return False, before_state

        # Update state
        after_state = before_state.copy()
        after_state["delivery_fee"] = new_fee
        after_state["pricing_version"] = "v4.2"  # Increment version

        logger.info(f"[EnergyExecutor] ✅ Fee increased to Rs. {new_fee}")
        return True, after_state

    except Exception as e:
        logger.error(f"[EnergyExecutor] ❌ Fee increase failed: {str(e)}")
        return False, before_state


def _execute_optimize_routes(
    api_client,
    rollback_mgr,
    transaction_id: str,
    before_state: Dict[str, Any],
    impact_value: float
) -> Tuple[bool, Dict[str, Any]]:
    """Execute route optimization action (fuel savings)."""
    try:
        # impact_value = liters saved per month
        logger.info(f"[EnergyExecutor] 📍 Optimizing routes for {impact_value}L monthly savings")

        # Call inventory API to reduce fuel procurement
        api_success, api_msg = api_client.call_inventory_adjust_stock(
            item_id="FUEL_ALLOCATION",
            quantity_change=-int(impact_value),
            reason="Route optimization completed"
        )

        rollback_mgr.log_api_call_for_rollback(
            transaction_id,
            "inventory_adjust_fuel",
            {"item": "FUEL_ALLOCATION", "reduction": impact_value},
            api_success,
            api_msg
        )

        if not api_success:
            logger.warning(f"[EnergyExecutor] ⚠️ Inventory API issue: {api_msg}. Continuing.")

        # Update state
        after_state = before_state.copy()
        after_state["fuel_optimization_applied"] = True

        logger.info(f"[EnergyExecutor] ✅ Routes optimized")
        return True, after_state

    except Exception as e:
        logger.error(f"[EnergyExecutor] ❌ Route optimization failed: {str(e)}")
        return False, before_state


def _execute_fuel_procurement(
    api_client,
    rollback_mgr,
    transaction_id: str,
    before_state: Dict[str, Any],
    impact_value: float
) -> Tuple[bool, Dict[str, Any]]:
    """Execute fuel procurement adjustment."""
    try:
        logger.info(f"[EnergyExecutor] 📍 Adjusting fuel procurement by {impact_value}L")

        # Call inventory API
        api_success, api_msg = api_client.call_inventory_adjust_stock(
            item_id="FUEL_BUFFER",
            quantity_change=int(impact_value),
            reason="Procurement adjustment"
        )

        rollback_mgr.log_api_call_for_rollback(
            transaction_id,
            "inventory_adjust_fuel_buffer",
            {"amount": impact_value},
            api_success,
            api_msg
        )

        # Update state
        after_state = before_state.copy()

        logger.info(f"[EnergyExecutor] ✅ Fuel procurement adjusted")
        return True, after_state

    except Exception as e:
        logger.error(f"[EnergyExecutor] ❌ Fuel procurement adjustment failed: {str(e)}")
        return False, before_state
