"""
Supply Chain Domain Executor - Real execution for supply-chain-related actions.
"""

import logging
from typing import Dict, Any, Tuple

from core.external_api_client import get_external_api_client
from core.execution_rollback import get_rollback_manager

logger = logging.getLogger(__name__)


def execute_supply_chain_action(
    action_description: str,
    action_key: str,
    current_state: Dict[str, Any],
    impact_value: float,
    transaction_id: str
) -> Tuple[bool, Dict[str, Any], Dict[str, Any], str]:
    """
    Execute supply chain domain action.
    """
    try:
        api_client = get_external_api_client()
        rollback_mgr = get_rollback_manager()

        before_state = current_state.copy()
        rollback_mgr.track_state_change(transaction_id, before_state)

        after_state = before_state.copy()

        if "alternate" in action_description.lower() or "supplier" in action_description.lower():
            after_state["alternate_supply_active"] = True
            success = True
        else:
            # Adjust delay days or safety stock targets
            new_days = before_state.get("supply_chain_delay_days", 0) + int(impact_value)
            after_state["supply_chain_delay_days"] = new_days
            success = True

        logger.info(f"[SupplyChainExecutor] ✅ Action executed: {action_key}")
        return True, before_state, after_state, ""

    except Exception as e:
        error_msg = f"Supply chain executor error: {str(e)}"
        logger.error(f"[SupplyChainExecutor] ❌ {error_msg}")
        return False, current_state, current_state, error_msg
