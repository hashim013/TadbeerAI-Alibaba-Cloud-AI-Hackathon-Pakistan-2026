"""
Execution Rollback Logic

Handles transaction rollback when external API calls fail.
Restores previous state and logs the rollback.
"""

import logging
from typing import Dict, Any, Tuple
from datetime import datetime

from core.firestore_client import get_firestore_client

logger = logging.getLogger(__name__)


class ExecutionRollback:
    """Manages transaction rollback on failures."""

    def __init__(self):
        """Initialize rollback manager."""
        self.firestore = get_firestore_client()
        self.rollback_history = {}

    def track_state_change(self, transaction_id: str, before_state: Dict[str, Any]) -> None:
        """
        Track the state before a transaction for potential rollback.

        Args:
            transaction_id: Unique transaction identifier
            before_state: State snapshot before transaction
        """
        self.rollback_history[transaction_id] = {
            "before_state": before_state,
            "timestamp": datetime.utcnow().isoformat(),
            "rolled_back": False
        }
        logger.info(f"[Rollback] 📌 Tracking transaction: {transaction_id}")

    def rollback_to_previous_state(
        self,
        transaction_id: str,
        current_state: Dict[str, Any],
        reason: str
    ) -> Tuple[bool, str]:
        """
        Rollback transaction to previous state.

        Args:
            transaction_id: Transaction to rollback
            current_state: Current (failed) state
            reason: Reason for rollback

        Returns:
            (success: bool, error_msg: str)
        """
        if transaction_id not in self.rollback_history:
            error_msg = f"No rollback history for {transaction_id}"
            logger.error(f"[Rollback] ❌ {error_msg}")
            return False, error_msg

        if self.rollback_history[transaction_id]["rolled_back"]:
            error_msg = f"Transaction {transaction_id} already rolled back"
            logger.warning(f"[Rollback] ⚠️ {error_msg}")
            return False, error_msg

        try:
            before_state = self.rollback_history[transaction_id]["before_state"]

            # Restore to Firestore
            success, error = get_firestore_client().update_business_state(before_state)

            if not success:
                error_msg = f"Failed to restore state: {error}"
                logger.error(f"[Rollback] ❌ {error_msg}")
                return False, error_msg

            # Mark as rolled back
            self.rollback_history[transaction_id]["rolled_back"] = True
            self.rollback_history[transaction_id]["rollback_timestamp"] = datetime.utcnow().isoformat()
            self.rollback_history[transaction_id]["rollback_reason"] = reason

            logger.info(f"[Rollback] 🔄 Transaction rolled back: {transaction_id}")

            # Log rollback to Firestore
            get_firestore_client().create_execution_log(
                action_id=transaction_id,
                domain="rollback",
                before_state=current_state,
                after_state=before_state,
                status="rolled_back",
                error_msg=reason
            )

            return True, ""

        except Exception as e:
            error_msg = f"Rollback failed: {str(e)}"
            logger.error(f"[Rollback] ❌ {error_msg}")
            return False, error_msg

    def get_rollback_history(self, transaction_id: str) -> Dict[str, Any]:
        """Get rollback history for a transaction."""
        return self.rollback_history.get(transaction_id, {})

    def log_api_call_for_rollback(
        self,
        transaction_id: str,
        api_name: str,
        payload: Dict[str, Any],
        success: bool,
        response: str
    ) -> None:
        """
        Track API call details for potential rollback reverse operation.

        Args:
            transaction_id: Transaction ID
            api_name: Name of API called (e.g., 'billing_update_fee')
            payload: Request payload
            success: Whether API call succeeded
            response: Response from API
        """
        if transaction_id not in self.rollback_history:
            logger.warning(f"[Rollback] ⚠️ No history for {transaction_id}")
            return

        if "api_calls" not in self.rollback_history[transaction_id]:
            self.rollback_history[transaction_id]["api_calls"] = []

        self.rollback_history[transaction_id]["api_calls"].append({
            "api_name": api_name,
            "payload": payload,
            "success": success,
            "response": response,
            "timestamp": datetime.utcnow().isoformat()
        })

        logger.debug(f"[Rollback] Tracked API call: {api_name}")

    def clear_history(self, transaction_id: str = None) -> None:
        """
        Clear rollback history (after transaction is committed safely).

        Args:
            transaction_id: Specific transaction to clear, or None to clear all
        """
        if transaction_id:
            if transaction_id in self.rollback_history:
                del self.rollback_history[transaction_id]
                logger.debug(f"[Rollback] Cleared history for {transaction_id}")
        else:
            self.rollback_history.clear()
            logger.debug(f"[Rollback] Cleared all history")


# Global singleton instance
_rollback_manager = None


def get_rollback_manager() -> ExecutionRollback:
    """Get or create ExecutionRollback singleton."""
    global _rollback_manager
    if _rollback_manager is None:
        _rollback_manager = ExecutionRollback()
    return _rollback_manager
