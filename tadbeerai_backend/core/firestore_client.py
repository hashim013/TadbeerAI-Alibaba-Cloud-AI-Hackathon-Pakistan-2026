"""
Firestore Client for Real Business State Persistence

Replaces in-memory mock_db.py with persistent cloud storage.
Handles atomic transactions, rollback, and audit trails.
"""

import json
import logging
from typing import Dict, Any, Optional, Tuple
from datetime import datetime
import os

try:
    import firebase_admin
    from firebase_admin import credentials, firestore
    FIREBASE_AVAILABLE = True
except ImportError:
    FIREBASE_AVAILABLE = False

logger = logging.getLogger(__name__)


class FirestoreClient:
    """Firestore database client for business state persistence."""

    def __init__(self, fallback_to_mock: bool = True):
        """
        Initialize Firestore client.

        Args:
            fallback_to_mock: If True, use mock_db.py as fallback if Firebase unavailable.
        """
        self.fallback_to_mock = fallback_to_mock
        self.db = None
        self.available = False

        if FIREBASE_AVAILABLE:
            self._init_firebase()
        else:
            logger.warning("[Firestore] Firebase Admin SDK not installed. Will use mock fallback.")

    def _init_firebase(self) -> None:
        """Initialize Firebase Admin SDK from service account JSON or default credentials."""
        try:
            service_account_json = os.getenv("FIREBASE_SERVICE_ACCOUNT_JSON")

            if service_account_json:
                # Parse JSON from env var
                service_account_dict = json.loads(service_account_json)

                # Initialize Firebase (only once)
                if not firebase_admin._apps:
                    cred = credentials.Certificate(service_account_dict)
                    firebase_admin.initialize_app(cred)
            else:
                # Try default credentials/initialization
                if not firebase_admin._apps:
                    firebase_admin.initialize_app()

            self.db = firestore.client()
            self.available = True
            logger.info("[Firestore] ✅ Firebase initialized successfully")

        except Exception as e:
            logger.error(f"[Firestore] ❌ Failed to initialize Firebase: {e}")

    def get_business_state(self) -> Dict[str, Any]:
        """
        Fetch current business state from Firestore.

        Returns:
            Dict with business state fields
        """
        if not self.available:
            return self._get_mock_fallback()

        try:
            doc = self.db.collection("business_state").document("current_state").get()

            if doc.exists:
                logger.info("[Firestore] ✅ Fetched state from Firestore")
                return doc.to_dict()
            else:
                logger.warning("[Firestore] Document not found. Initializing default state.")
                return self._get_default_state()

        except Exception as e:
            logger.error(f"[Firestore] ❌ Failed to get state: {e}. Using mock fallback.")
            return self._get_mock_fallback()

    def update_business_state(self, updates: Dict[str, Any]) -> Tuple[bool, str]:
        """
        Update business state in Firestore.

        Args:
            updates: Dict of fields to update

        Returns:
            (success: bool, error_msg: str)
        """
        if not self.available:
            return self._update_mock_fallback(updates)

        try:
            self.db.collection("business_state").document("current_state").update({
                **updates,
                "last_updated": datetime.utcnow().isoformat(),
                "updated_by": "Agent6_RealExecution"
            })
            logger.info(f"[Firestore] ✅ Updated state: {list(updates.keys())}")
            return True, ""

        except Exception as e:
            error_msg = f"Failed to update state: {str(e)}"
            logger.error(f"[Firestore] ❌ {error_msg}")
            return False, error_msg

    def create_transaction(self) -> "FirestoreTransaction":
        """
        Create an atomic transaction for multiple updates.

        Returns:
            FirestoreTransaction object
        """
        if not self.available:
            return FirestoreTransaction(None, use_mock=True)
        return FirestoreTransaction(self.db, use_mock=False)

    def create_execution_log(
        self,
        action_id: str,
        domain: str,
        before_state: Dict[str, Any],
        after_state: Dict[str, Any],
        status: str,
        error_msg: str = ""
    ) -> Tuple[bool, str]:
        """
        Log action execution to audit trail.

        Args:
            action_id: Unique action identifier
            domain: Business domain (Energy, Currency, etc.)
            before_state: State before execution
            after_state: State after execution
            status: 'success', 'failed', 'rolled_back'
            error_msg: Error message if failed

        Returns:
            (success: bool, execution_id: str)
        """
        if not self.available:
            logger.info(f"[Firestore] Mock: Logged execution {action_id} as {status}")
            return True, f"mock_{action_id}"

        try:
            execution_id = f"{domain}_{datetime.utcnow().timestamp()}"
            doc_data = {
                "action_id": action_id,
                "domain": domain,
                "before_state": before_state,
                "after_state": after_state,
                "status": status,
                "error_msg": error_msg,
                "timestamp": datetime.utcnow().isoformat(),
                "transaction_id": execution_id
            }

            self.db.collection("action_executions").document(execution_id).set(doc_data)
            logger.info(f"[Firestore] ✅ Execution logged: {execution_id}")
            return True, execution_id

        except Exception as e:
            error_msg = f"Failed to log execution: {str(e)}"
            logger.error(f"[Firestore] ❌ {error_msg}")
            return False, ""

    def create_notification_log(
        self,
        recipient: str,
        notification_type: str,
        content: str,
        action_id: str,
        status: str = "pending"
    ) -> Tuple[bool, str]:
        """
        Log notification attempt.

        Args:
            recipient: Phone number or email
            notification_type: 'sms' or 'email'
            content: Message content
            action_id: Related action ID
            status: 'pending', 'sent', 'failed'

        Returns:
            (success: bool, log_id: str)
        """
        if not self.available:
            logger.info(f"[Firestore] Mock: Logged {notification_type} to {recipient}")
            return True, f"mock_{action_id}"

        try:
            log_id = f"{action_id}_{datetime.utcnow().timestamp()}"
            doc_data = {
                "recipient": recipient,
                "type": notification_type,
                "content": content,
                "action_id": action_id,
                "status": status,
                "timestamp": datetime.utcnow().isoformat()
            }

            self.db.collection("notification_log").document(log_id).set(doc_data)
            logger.info(f"[Firestore] ✅ Notification logged: {log_id}")
            return True, log_id

        except Exception as e:
            error_msg = f"Failed to log notification: {str(e)}"
            logger.error(f"[Firestore] ❌ {error_msg}")
            return False, ""

    def get_execution_history(self, limit: int = 10) -> list:
        """Fetch recent execution history."""
        if not self.available:
            return []

        try:
            docs = self.db.collection("action_executions").order_by(
                "timestamp", direction=firestore.Query.DESCENDING
            ).limit(limit).stream()

            history = [doc.to_dict() for doc in docs]
            logger.info(f"[Firestore] ✅ Fetched {len(history)} execution records")
            return history

        except Exception as e:
            logger.error(f"[Firestore] ❌ Failed to fetch history: {e}")
            return []

    @staticmethod
    def _get_default_state() -> Dict[str, Any]:
        """Get default business state."""
        return {
            "delivery_fee": 150,
            "pricing_version": "v4.1",
            "customer_count": 3200,
            "safety_stock_days": 7,
            "import_cost_buffer": 0,
            "order_hold_flag": False,
            "portfolio_hedge_flag": False,
            "stop_loss_set": False,
            "procurement_hold": False,
            "interest_rate_buffer": 0.0,
            "loan_hold_flag": False,
            "compliance_cost": 0,
            "audit_pending_flag": False,
            "export_buffer_pct": 0.0,
            "trade_hold_flag": False,
            "alternate_supply_active": False,
            "supply_chain_delay_days": 0,
            "fbr_tax_rate": 18.0,
            "sbr_tax_rate": 13.0,
            "last_updated": datetime.utcnow().isoformat(),
            "updated_by": "initialization"
        }

    def _get_mock_fallback(self) -> Dict[str, Any]:
        """Fallback to mock_db.py if Firestore unavailable."""
        try:
            from core.mock_db import MockDatabase
            mock = MockDatabase()
            return {
                "delivery_fee": mock.get("delivery_fee", 150),
                "pricing_version": mock.get("pricing_version", "v4.1"),
                "customer_count": mock.get("customer_count", 3200),
                "safety_stock_days": mock.get("safety_stock_days", 7),
                "import_cost_buffer": mock.get("import_cost_buffer", 0),
                "order_hold_flag": mock.get("order_hold_flag", False),
                "portfolio_hedge_flag": mock.get("portfolio_hedge_flag", False),
                "stop_loss_set": mock.get("stop_loss_set", False),
                "procurement_hold": mock.get("procurement_hold", False),
                "interest_rate_buffer": mock.get("interest_rate_buffer", 0.0),
                "loan_hold_flag": mock.get("loan_hold_flag", False),
                "compliance_cost": mock.get("compliance_cost", 0),
                "audit_pending_flag": mock.get("audit_pending_flag", False),
                "export_buffer_pct": mock.get("export_buffer_pct", 0.0),
                "trade_hold_flag": mock.get("trade_hold_flag", False),
                "alternate_supply_active": mock.get("alternate_supply_active", False),
                "supply_chain_delay_days": mock.get("supply_chain_delay_days", 0),
                "fbr_tax_rate": mock.get("fbr_tax_rate", 18.0),
                "sbr_tax_rate": mock.get("sbr_tax_rate", 13.0),
                "last_updated": datetime.utcnow().isoformat(),
                "updated_by": "mock_fallback"
            }
        except Exception as e:
            logger.error(f"[Firestore] ❌ Mock fallback failed: {e}")
            return self._get_default_state()

    def _update_mock_fallback(self, updates: Dict[str, Any]) -> Tuple[bool, str]:
        """Fallback to mock_db.py if Firestore unavailable."""
        try:
            from core.mock_db import MockDatabase
            mock = MockDatabase()
            for key, value in updates.items():
                mock.set(key, value)
            logger.info(f"[Firestore] Mock: Updated state fields: {list(updates.keys())}")
            return True, ""
        except Exception as e:
            error_msg = f"Mock fallback update failed: {str(e)}"
            logger.error(f"[Firestore] ❌ {error_msg}")
            return False, error_msg


class FirestoreTransaction:
    """Atomic transaction wrapper for Firestore."""

    def __init__(self, db, use_mock: bool = False):
        """
        Initialize transaction.

        Args:
            db: Firestore database instance
            use_mock: If True, operations are mocked
        """
        self.db = db
        self.use_mock = use_mock
        self.updates = {}
        self.committed = False
        self.transaction_id = f"txn_{datetime.utcnow().timestamp()}"

    def add_update(self, key: str, value: Any) -> None:
        """Add an update to the transaction."""
        self.updates[key] = value

    def commit(self) -> Tuple[bool, str]:
        """
        Commit all updates atomically.

        Returns:
            (success: bool, error_msg: str)
        """
        if self.use_mock:
            logger.info(f"[Firestore] Mock: Committed transaction {self.transaction_id}")
            self.committed = True
            return True, ""

        try:
            if not self.db:
                return False, "Database not available"

            self.db.collection("business_state").document("current_state").update({
                **self.updates,
                "last_updated": datetime.utcnow().isoformat(),
                "updated_by": f"Transaction_{self.transaction_id}"
            })

            self.committed = True
            logger.info(f"[Firestore] ✅ Transaction committed: {self.transaction_id}")
            return True, ""

        except Exception as e:
            error_msg = f"Transaction failed: {str(e)}"
            logger.error(f"[Firestore] ❌ {error_msg}")
            return False, error_msg

    def rollback(self) -> Tuple[bool, str]:
        """
        Rollback transaction (prevents commit).

        Returns:
            (success: bool, error_msg: str)
        """
        if self.committed:
            return False, "Transaction already committed"

        logger.info(f"[Firestore] 🔄 Transaction rolled back: {self.transaction_id}")
        return True, ""


# Global singleton instance
_firestore_instance = None


def get_firestore_client() -> FirestoreClient:
    """Get or create Firestore client singleton."""
    global _firestore_instance
    if _firestore_instance is None:
        _firestore_instance = FirestoreClient(fallback_to_mock=True)
    return _firestore_instance


def init_firestore() -> None:
    """Initialize Firestore on app startup."""
    client = get_firestore_client()
    if client.available:
        logger.info("[Firestore] ✅ Firestore initialized and ready")
    else:
        logger.warning("[Firestore] ⚠️ Firestore unavailable, using mock fallback")
