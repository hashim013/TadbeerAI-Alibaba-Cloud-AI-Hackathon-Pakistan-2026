"""
External API Client for Domain-Specific Operations

Stub implementation for calling real business APIs:
- Billing API: Update customer charges
- Inventory API: Update stock levels
- Analytics API: Log business metrics

This is a STUB - you fill in the actual API endpoints in production.
"""

import logging
import os
from typing import Tuple, Dict, Any
from datetime import datetime

try:
    import requests
    REQUESTS_AVAILABLE = True
except ImportError:
    REQUESTS_AVAILABLE = False

logger = logging.getLogger(__name__)


class ExternalAPIClient:
    """Client for calling external business APIs."""

    def __init__(self):
        """Initialize API endpoints from environment variables."""
        self.billing_api_url = os.getenv("BILLING_API_URL", "http://billing.internal/api")
        self.inventory_api_url = os.getenv("INVENTORY_API_URL", "http://inventory.internal/api")
        self.analytics_api_url = os.getenv("ANALYTICS_API_URL", "http://analytics.internal/api")
        self.api_timeout = 10  # seconds

    # ==================== BILLING API ====================

    def call_billing_update_delivery_fee(
        self,
        new_fee: float,
        affected_customers: int
    ) -> Tuple[bool, str]:
        """
        Update delivery fee in billing system.

        Args:
            new_fee: New delivery fee in Rs.
            affected_customers: Number of customers affected

        Returns:
            (success: bool, message: str)
        """
        try:
            payload = {
                "action": "update_delivery_fee",
                "new_fee": new_fee,
                "affected_customers": affected_customers,
                "timestamp": datetime.utcnow().isoformat(),
                "source": "TadbeerAI"
            }

            if not REQUESTS_AVAILABLE:
                logger.warning("[ExternalAPI] Requests library not available. Logging mock call.")
                return True, f"Mock: Updated delivery fee to Rs. {new_fee} for {affected_customers} customers"

            try:
                response = requests.post(
                    f"{self.billing_api_url}/update-delivery-fee",
                    json=payload,
                    timeout=self.api_timeout
                )

                if response.status_code in [200, 201]:
                    logger.info(f"[ExternalAPI] ✅ Billing API: Fee updated to Rs. {new_fee}")
                    return True, response.json().get("message", "Fee updated")
                else:
                    error_msg = f"Billing API returned {response.status_code}"
                    logger.error(f"[ExternalAPI] ❌ {error_msg}")
                    return False, error_msg

            except requests.RequestException as e:
                # API unreachable - log and continue (don't fail entire transaction)
                logger.warning(f"[ExternalAPI] ⚠️ Billing API unreachable: {str(e)}. Proceeding with state change.")
                return True, f"Billing API unreachable (proceeding): {str(e)}"

        except Exception as e:
            error_msg = f"Billing update failed: {str(e)}"
            logger.error(f"[ExternalAPI] ❌ {error_msg}")
            return False, error_msg

    def call_billing_hold_orders(self, reason: str) -> Tuple[bool, str]:
        """
        Hold all pending orders in billing system.

        Args:
            reason: Reason for hold (e.g., 'currency_volatility')

        Returns:
            (success: bool, message: str)
        """
        try:
            payload = {
                "action": "hold_orders",
                "reason": reason,
                "timestamp": datetime.utcnow().isoformat(),
                "source": "TadbeerAI"
            }

            if not REQUESTS_AVAILABLE:
                logger.warning("[ExternalAPI] Mock: Held orders due to " + reason)
                return True, f"Mock: Orders held due to {reason}"

            try:
                response = requests.post(
                    f"{self.billing_api_url}/hold-orders",
                    json=payload,
                    timeout=self.api_timeout
                )

                if response.status_code in [200, 201]:
                    logger.info(f"[ExternalAPI] ✅ Billing API: Orders held ({reason})")
                    return True, response.json().get("message", "Orders held")
                else:
                    logger.warning(f"[ExternalAPI] ⚠️ Billing API returned {response.status_code}. Continuing.")
                    return True, f"Billing API {response.status_code}"

            except requests.RequestException as e:
                logger.warning(f"[ExternalAPI] ⚠️ Billing API unreachable: {str(e)}. Proceeding.")
                return True, f"Billing API unreachable: {str(e)}"

        except Exception as e:
            logger.error(f"[ExternalAPI] ❌ Billing hold failed: {str(e)}")
            return False, str(e)

    # ==================== INVENTORY API ====================

    def call_inventory_adjust_stock(
        self,
        item_id: str,
        quantity_change: int,
        reason: str
    ) -> Tuple[bool, str]:
        """
        Adjust inventory stock levels.

        Args:
            item_id: Item identifier
            quantity_change: Change in quantity (positive/negative)
            reason: Reason for adjustment

        Returns:
            (success: bool, message: str)
        """
        try:
            payload = {
                "action": "adjust_stock",
                "item_id": item_id,
                "quantity_change": quantity_change,
                "reason": reason,
                "timestamp": datetime.utcnow().isoformat(),
                "source": "TadbeerAI"
            }

            if not REQUESTS_AVAILABLE:
                logger.warning("[ExternalAPI] Mock: Adjusted stock")
                return True, f"Mock: {item_id} adjusted by {quantity_change} units"

            try:
                response = requests.post(
                    f"{self.inventory_api_url}/adjust-stock",
                    json=payload,
                    timeout=self.api_timeout
                )

                if response.status_code in [200, 201]:
                    logger.info(f"[ExternalAPI] ✅ Inventory API: Stock adjusted for {item_id}")
                    return True, response.json().get("message", "Stock adjusted")
                else:
                    logger.warning(f"[ExternalAPI] ⚠️ Inventory API {response.status_code}. Continuing.")
                    return True, f"Inventory API {response.status_code}"

            except requests.RequestException as e:
                logger.warning(f"[ExternalAPI] ⚠️ Inventory API unreachable: {str(e)}. Proceeding.")
                return True, f"Inventory API unreachable: {str(e)}"

        except Exception as e:
            logger.error(f"[ExternalAPI] ❌ Inventory adjust failed: {str(e)}")
            return False, str(e)

    def call_inventory_hold_procurement(self, hold_reason: str) -> Tuple[bool, str]:
        """
        Hold all procurement in inventory system.

        Args:
            hold_reason: Reason for hold

        Returns:
            (success: bool, message: str)
        """
        try:
            payload = {
                "action": "hold_procurement",
                "reason": hold_reason,
                "timestamp": datetime.utcnow().isoformat(),
                "source": "TadbeerAI"
            }

            if not REQUESTS_AVAILABLE:
                logger.warning("[ExternalAPI] Mock: Held procurement")
                return True, f"Mock: Procurement held due to {hold_reason}"

            try:
                response = requests.post(
                    f"{self.inventory_api_url}/hold-procurement",
                    json=payload,
                    timeout=self.api_timeout
                )

                if response.status_code in [200, 201]:
                    logger.info(f"[ExternalAPI] ✅ Inventory API: Procurement held")
                    return True, response.json().get("message", "Procurement held")
                else:
                    logger.warning(f"[ExternalAPI] ⚠️ Inventory API {response.status_code}. Continuing.")
                    return True, f"Inventory API {response.status_code}"

            except requests.RequestException as e:
                logger.warning(f"[ExternalAPI] ⚠️ Inventory API unreachable: {str(e)}. Proceeding.")
                return True, f"Inventory API unreachable: {str(e)}"

        except Exception as e:
            logger.error(f"[ExternalAPI] ❌ Inventory hold failed: {str(e)}")
            return False, str(e)

    # ==================== ANALYTICS API ====================

    def call_analytics_log_action(
        self,
        domain: str,
        action_type: str,
        metrics: Dict[str, Any]
    ) -> Tuple[bool, str]:
        """
        Log action execution to analytics system.

        Args:
            domain: Business domain
            action_type: Type of action
            metrics: Dict of metrics (e.g., {'fee_change': 28, 'affected_customers': 3200})

        Returns:
            (success: bool, message: str)
        """
        try:
            payload = {
                "domain": domain,
                "action_type": action_type,
                "metrics": metrics,
                "timestamp": datetime.utcnow().isoformat(),
                "source": "TadbeerAI"
            }

            if not REQUESTS_AVAILABLE:
                logger.info(f"[ExternalAPI] Mock: Logged {action_type} for {domain}")
                return True, f"Mock: Action logged"

            try:
                response = requests.post(
                    f"{self.analytics_api_url}/log-action",
                    json=payload,
                    timeout=self.api_timeout
                )

                if response.status_code in [200, 201]:
                    logger.info(f"[ExternalAPI] ✅ Analytics API: Action logged")
                    return True, response.json().get("message", "Logged")
                else:
                    logger.warning(f"[ExternalAPI] ⚠️ Analytics API {response.status_code}. Continuing.")
                    return True, f"Analytics API {response.status_code}"

            except requests.RequestException as e:
                logger.warning(f"[ExternalAPI] ⚠️ Analytics API unreachable: {str(e)}. Proceeding.")
                return True, f"Analytics unreachable: {str(e)}"

        except Exception as e:
            logger.error(f"[ExternalAPI] ❌ Analytics log failed: {str(e)}")
            return False, str(e)


# Global singleton instance
_external_api_client = None


def get_external_api_client() -> ExternalAPIClient:
    """Get or create ExternalAPIClient singleton."""
    global _external_api_client
    if _external_api_client is None:
        _external_api_client = ExternalAPIClient()
    return _external_api_client
