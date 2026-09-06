"""
Finance Store — Per-user finance ledger persistence.

Stores each user's finance ledger (transactions, budgets, goals and the
opening savings balance) as a single snapshot. Dual storage mirrors
``user_registry.py``:

* Firestore (production): ``users/{uid}/finance/ledger``
* JSON file fallback (local dev): ``data/finance/{uid}.json``

The ledger is a pure pass-through snapshot — the backend stores exactly what
the Flutter client sends (``FinanceData.toJson()``) and returns it verbatim.
No domain interpretation happens here, which keeps the offline-first sync
model (whole-snapshot last-write-wins) trivial on both sides.
"""

import json
import logging
import os
from datetime import datetime
from typing import Any, Dict, Optional

from core.paths import get_data_dir

logger = logging.getLogger(__name__)

FINANCE_DIR = os.path.join(get_data_dir(), "finance")

#: Shape returned when a user has no ledger yet — matches the Flutter
#: ``FinanceData`` empty constructor so the client can parse it directly.
_EMPTY_LEDGER: Dict[str, Any] = {
    "transactions": [],
    "budgets": [],
    "goals": [],
    "openingSavingsBalance": 0,
}


def _safe_uid(uid: str) -> str:
    """Filesystem-safe uid for the JSON fallback filename."""
    safe = "".join(c for c in uid if c.isalnum() or c in ("-", "_"))
    return safe or "guest"


def _normalize(raw: Optional[Dict[str, Any]]) -> Dict[str, Any]:
    """Guarantee the four ledger keys exist with the right types."""
    raw = raw or {}
    return {
        "transactions": list(raw.get("transactions") or []),
        "budgets": list(raw.get("budgets") or []),
        "goals": list(raw.get("goals") or []),
        "openingSavingsBalance": float(raw.get("openingSavingsBalance") or 0),
    }


class FinanceStore:
    """Per-user finance ledger with Firestore primary + JSON fallback."""

    def __init__(self) -> None:
        self._firestore = None
        self._firestore_available = False

        try:
            from core.firestore_client import get_firestore_client

            client = get_firestore_client()
            if client.available:
                self._firestore = client
                self._firestore_available = True
                logger.info("[FinanceStore] Using Firestore storage")
            else:
                logger.info(
                    "[FinanceStore] Firestore unavailable, using JSON fallback"
                )
        except Exception as e:  # pragma: no cover - init guard
            logger.warning(
                f"[FinanceStore] Firestore init failed: {e}. Using JSON fallback."
            )

    # ==================== PUBLIC API ====================

    def get_ledger(self, uid: str) -> Dict[str, Any]:
        """Return the user's ledger snapshot (empty defaults when absent)."""
        if self._firestore_available:
            try:
                doc = self._doc(uid).get()
                if doc.exists:
                    return _normalize(doc.to_dict())
                return dict(_EMPTY_LEDGER)
            except Exception as e:
                logger.error(f"[FinanceStore] Firestore read failed: {e}")

        return self._read_json(uid)

    def put_ledger(self, uid: str, data: Dict[str, Any]) -> Dict[str, Any]:
        """Replace the user's ledger snapshot; stamps ``updated_at``."""
        ledger = _normalize(data)
        ledger["updated_at"] = datetime.utcnow().isoformat()

        if self._firestore_available:
            try:
                self._doc(uid).set(ledger)
                logger.info(f"[FinanceStore] Saved ledger for {uid} to Firestore")
                return ledger
            except Exception as e:
                logger.error(
                    f"[FinanceStore] Firestore write failed: {e}. Saving to JSON."
                )

        self._write_json(uid, ledger)
        return ledger

    def delete_ledger(self, uid: str) -> bool:
        """Remove a user's ledger (used on account deletion)."""
        deleted = False
        if self._firestore_available:
            try:
                self._doc(uid).delete()
                deleted = True
                logger.info(f"[FinanceStore] Deleted ledger for {uid} from Firestore")
            except Exception as e:
                logger.error(f"[FinanceStore] Firestore delete failed: {e}")

        path = self._json_path(uid)
        if os.path.exists(path):
            try:
                os.remove(path)
                deleted = True
            except Exception as e:
                logger.error(f"[FinanceStore] JSON delete failed: {e}")
        return deleted

    # ==================== INTERNALS ====================

    def _doc(self, uid: str):
        """Firestore doc reference at users/{uid}/finance/ledger."""
        return (
            self._firestore.db.collection("users")
            .document(uid)
            .collection("finance")
            .document("ledger")
        )

    def _json_path(self, uid: str) -> str:
        return os.path.join(FINANCE_DIR, f"{_safe_uid(uid)}.json")

    def _read_json(self, uid: str) -> Dict[str, Any]:
        try:
            with open(self._json_path(uid), "r", encoding="utf-8") as f:
                return _normalize(json.load(f))
        except (FileNotFoundError, json.JSONDecodeError):
            return dict(_EMPTY_LEDGER)
        except Exception as e:
            logger.error(f"[FinanceStore] JSON read failed: {e}")
            return dict(_EMPTY_LEDGER)

    def _write_json(self, uid: str, ledger: Dict[str, Any]) -> None:
        try:
            os.makedirs(FINANCE_DIR, exist_ok=True)
            with open(self._json_path(uid), "w", encoding="utf-8") as f:
                json.dump(ledger, f, indent=2, default=str)
            logger.info(f"[FinanceStore] Saved ledger for {uid} to JSON")
        except Exception as e:
            logger.error(f"[FinanceStore] JSON write failed: {e}")


# ==================== SINGLETON ====================

_finance_store: Optional[FinanceStore] = None


def get_finance_store() -> FinanceStore:
    """Get or create the FinanceStore singleton."""
    global _finance_store
    if _finance_store is None:
        _finance_store = FinanceStore()
    return _finance_store
