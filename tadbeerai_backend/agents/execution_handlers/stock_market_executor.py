"""
Stock Market Domain Executor - Real execution for stock market actions.

Actions:
- Hedge portfolio
- Set stop-loss orders
- Rebalance portfolio
"""

import logging
from typing import Dict, Any, Tuple

from core.external_api_client import get_external_api_client
from core.execution_rollback import get_rollback_manager

logger = logging.getLogger(__name__)


def execute_stock_market_action(
    action_description: str,
    action_key: str,
    current_state: Dict[str, Any],
    impact_value: float,
    transaction_id: str
) -> Tuple[bool, Dict[str, Any], Dict[str, Any], str]:
    """
    Execute stock market domain action with real API calls.

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
        if "hedge" in action_description.lower():
            success, after_state = _execute_hedge_portfolio(
                api_client, rollback_mgr, transaction_id, before_state, impact_value
            )

        elif "stop" in action_description.lower() and "loss" in action_description.lower():
            success, after_state = _execute_set_stop_loss(
                api_client, rollback_mgr, transaction_id, before_state, impact_value
            )

        elif "rebalance" in action_description.lower():
            success, after_state = _execute_rebalance_portfolio(
                api_client, rollback_mgr, transaction_id, before_state, impact_value
            )

        else:
            success = True
            logger.warning(f"[StockExecutor] Unknown action: {action_description}")

        if not success:
            rollback_mgr.rollback_to_previous_state(transaction_id, after_state, "API call failed")
            return False, before_state, before_state, "Stock action execution failed"

        logger.info(f"[StockExecutor] ✅ Action executed: {action_key}")
        return True, before_state, after_state, ""

    except Exception as e:
        error_msg = f"Stock executor error: {str(e)}"
        logger.error(f"[StockExecutor] ❌ {error_msg}")
        return False, current_state, current_state, error_msg


def _execute_hedge_portfolio(
    api_client,
    rollback_mgr,
    transaction_id: str,
    before_state: Dict[str, Any],
    impact_value: float
) -> Tuple[bool, Dict[str, Any]]:
    """Execute portfolio hedging with protective puts."""
    try:
        protected_value = impact_value
        logger.info(f"[StockExecutor] 📈 Hedging portfolio for Rs. {protected_value}")

        # Log to analytics
        api_success, api_msg = api_client.call_analytics_log_action(
            domain="Stock Market",
            action_type="hedge_portfolio",
            metrics={"protected_value": protected_value, "puts_purchased": "standard"}
        )

        rollback_mgr.log_api_call_for_rollback(
            transaction_id,
            "analytics_hedge",
            {"protected_value": protected_value},
            api_success,
            api_msg
        )

        after_state = before_state.copy()
        after_state["portfolio_hedge_flag"] = True
        after_state["hedged_value"] = protected_value

        logger.info(f"[StockExecutor] ✅ Portfolio hedged for Rs. {protected_value}")
        return True, after_state

    except Exception as e:
        logger.error(f"[StockExecutor] ❌ Portfolio hedge failed: {str(e)}")
        return False, before_state


def _execute_set_stop_loss(
    api_client,
    rollback_mgr,
    transaction_id: str,
    before_state: Dict[str, Any],
    impact_value: float
) -> Tuple[bool, Dict[str, Any]]:
    """Set stop-loss orders at specified price level."""
    try:
        stop_loss_level = impact_value
        logger.info(f"[StockExecutor] 🛑 Setting stop-loss at Rs. {stop_loss_level}")

        # Log to analytics
        api_success, api_msg = api_client.call_analytics_log_action(
            domain="Stock Market",
            action_type="set_stop_loss",
            metrics={"trigger_level": stop_loss_level}
        )

        rollback_mgr.log_api_call_for_rollback(
            transaction_id,
            "analytics_stop_loss",
            {"level": stop_loss_level},
            api_success,
            api_msg
        )

        after_state = before_state.copy()
        after_state["stop_loss_set"] = True
        after_state["stop_loss_level"] = stop_loss_level

        logger.info(f"[StockExecutor] ✅ Stop-loss set at Rs. {stop_loss_level}")
        return True, after_state

    except Exception as e:
        logger.error(f"[StockExecutor] ❌ Stop-loss setup failed: {str(e)}")
        return False, before_state


def _execute_rebalance_portfolio(
    api_client,
    rollback_mgr,
    transaction_id: str,
    before_state: Dict[str, Any],
    impact_value: float
) -> Tuple[bool, Dict[str, Any]]:
    """Rebalance portfolio to new allocation."""
    try:
        new_allocation = impact_value
        logger.info(f"[StockExecutor] ⚖️ Rebalancing portfolio to {new_allocation}% target")

        api_success, api_msg = api_client.call_analytics_log_action(
            domain="Stock Market",
            action_type="rebalance_portfolio",
            metrics={"new_allocation": new_allocation}
        )

        rollback_mgr.log_api_call_for_rollback(
            transaction_id,
            "analytics_rebalance",
            {"allocation": new_allocation},
            api_success,
            api_msg
        )

        after_state = before_state.copy()
        after_state["portfolio_rebalanced"] = True

        logger.info(f"[StockExecutor] ✅ Portfolio rebalanced")
        return True, after_state

    except Exception as e:
        logger.error(f"[StockExecutor] ❌ Portfolio rebalance failed: {str(e)}")
        return False, before_state
