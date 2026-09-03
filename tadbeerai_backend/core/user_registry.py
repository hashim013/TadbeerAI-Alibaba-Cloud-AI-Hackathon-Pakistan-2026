"""
User Registry — Manage Registered App Users

Stores user phone + email for notification delivery.
Dual storage: Firestore (production) with JSON file fallback (dev).
"""

import json
import logging
import os
from datetime import datetime
from typing import Dict, Any, List, Optional, Tuple
from uuid import uuid4

from core.paths import get_data_dir

logger = logging.getLogger(__name__)

USERS_FILE = os.path.join(get_data_dir(), "registered_users.json")


class UserRegistry:
    """Manages registered users for notification delivery."""

    def __init__(self):
        """Initialize registry with Firestore or JSON fallback."""
        self._firestore = None
        self._firestore_available = False

        try:
            from core.firestore_client import get_firestore_client
            client = get_firestore_client()
            if client.available:
                self._firestore = client
                self._firestore_available = True
                logger.info("[UserRegistry] ✅ Using Firestore storage")
            else:
                logger.info("[UserRegistry] ⚠️ Firestore unavailable, using JSON fallback")
        except Exception as e:
            logger.warning(f"[UserRegistry] Firestore init failed: {e}. Using JSON fallback.")

        # Ensure JSON file exists for fallback
        self._ensure_json_file()

    def _ensure_json_file(self) -> None:
        """Create default JSON file if it doesn't exist."""
        os.makedirs(os.path.dirname(USERS_FILE), exist_ok=True)
        if not os.path.exists(USERS_FILE):
            with open(USERS_FILE, "w") as f:
                json.dump([], f, indent=2)
            logger.info("[UserRegistry] Created empty registered_users.json")

    # ==================== CRUD OPERATIONS ====================

    def register_user(
        self,
        name: str,
        phone: str,
        email: str,
        notify_sms: bool = True,
        notify_email: bool = True,
        notify_push: bool = True,
        fcm_token: str = "",
        domains: List[str] | None = None,
    ) -> Dict[str, Any]:
        """
        Register a new user for notifications.

        Args:
            name: User display name
            phone: Phone number (e.g., '+923001234567')
            email: Email address
            notify_sms: Whether to send SMS notifications
            notify_email: Whether to send email notifications
            notify_push: Whether to send push notifications
            fcm_token: FCM device token for push notifications
            domains: List of domains to subscribe to, or ['all']

        Returns:
            Dict with the created user record
        """
        user_id = f"usr_{uuid4().hex[:10]}"
        user = {
            "user_id": user_id,
            "name": name,
            "phone": phone,
            "email": email,
            "notify_sms": notify_sms,
            "notify_email": notify_email,
            "notify_push": notify_push,
            "fcm_token": fcm_token,
            "domains": domains or ["all"],
            "registered_at": datetime.utcnow().isoformat(),
        }

        # Check for duplicate phone or email (skip for guests with no contact info)
        existing = self.get_all_users()
        if phone or email:
            for u in existing:
                if (phone and u.get("phone") == phone) or (email and u.get("email") == email):
                    logger.warning(f"[UserRegistry] Duplicate found: {phone} / {email}. Updating existing.")
                    return self.update_user(u["user_id"], {
                        "name": name,
                        "phone": phone,
                        "email": email,
                        "notify_sms": notify_sms,
                        "notify_email": notify_email,
                        "notify_push": notify_push,
                        "fcm_token": fcm_token,
                        "domains": domains or ["all"],
                    })

        if self._firestore_available:
            try:
                self._firestore.db.collection("registered_users").document(user_id).set(user)
                logger.info(f"[UserRegistry] ✅ Registered {name} ({user_id}) in Firestore")
            except Exception as e:
                logger.error(f"[UserRegistry] ❌ Firestore write failed: {e}. Saving to JSON.")
                self._save_to_json(user)
        else:
            self._save_to_json(user)

        return user

    def get_all_users(self) -> List[Dict[str, Any]]:
        """
        Get all registered users.

        Returns:
            List of user dicts
        """
        if self._firestore_available:
            try:
                users = []
                # 1. Fetch from 'users' collection (Flutter app)
                try:
                    docs = self._firestore.db.collection("users").stream()
                    for doc in docs:
                        d = doc.to_dict()
                        uid = d.get("uid") or doc.id
                        users.append({
                            "user_id": uid,
                            "name": d.get("display_name") or d.get("name") or "User",
                            "phone": d.get("phone") or "",
                            "email": d.get("email") or "",
                            "notify_sms": d.get("notify_sms") if d.get("notify_sms") is not None else True,
                            "notify_email": d.get("notify_email") if d.get("notify_email") is not None else True,
                            "notify_push": d.get("notify_push") if d.get("notify_push") is not None else True,
                            "fcm_token": d.get("fcm_token") or "",
                            "domains": d.get("domains") or ["all"],
                            "mode": d.get("mode") or "account"
                        })
                except Exception as e_users:
                    logger.error(f"[UserRegistry] Failed to fetch from 'users' collection: {e_users}")

                # 2. Fetch from 'registered_users' collection (fallback)
                try:
                    registered_docs = self._firestore.db.collection("registered_users").stream()
                    registered_uids = {u["user_id"] for u in users}
                    for doc in registered_docs:
                        d = doc.to_dict()
                        uid = d.get("user_id") or doc.id
                        if uid not in registered_uids:
                            users.append({
                                "user_id": uid,
                                "name": d.get("name") or "User",
                                "phone": d.get("phone") or "",
                                "email": d.get("email") or "",
                                "notify_sms": d.get("notify_sms") if d.get("notify_sms") is not None else True,
                                "notify_email": d.get("notify_email") if d.get("notify_email") is not None else True,
                                "notify_push": d.get("notify_push") if d.get("notify_push") is not None else True,
                                "fcm_token": d.get("fcm_token") or "",
                                "domains": d.get("domains") or ["all"],
                                "mode": d.get("mode") or "account"
                            })
                except Exception as e_reg:
                    logger.error(f"[UserRegistry] Failed to fetch from 'registered_users' collection: {e_reg}")

                if users:
                    logger.info(f"[UserRegistry] ✅ Fetched {len(users)} users from Firestore")
                    return users
            except Exception as e:
                logger.error(f"[UserRegistry] ❌ Firestore read failed: {e}. Using JSON fallback.")

        return self._load_from_json()

    def get_user(self, user_id: str) -> Optional[Dict[str, Any]]:
        """
        Get a single user by ID.

        Args:
            user_id: User identifier

        Returns:
            User dict or None if not found
        """
        if self._firestore_available:
            try:
                # Try 'users' collection first
                doc = self._firestore.db.collection("users").document(user_id).get()
                if doc.exists:
                    d = doc.to_dict()
                    return {
                        "user_id": d.get("uid") or doc.id,
                        "name": d.get("display_name") or d.get("name") or "User",
                        "phone": d.get("phone") or "",
                        "email": d.get("email") or "",
                        "notify_sms": d.get("notify_sms") if d.get("notify_sms") is not None else True,
                        "notify_email": d.get("notify_email") if d.get("notify_email") is not None else True,
                        "notify_push": d.get("notify_push") if d.get("notify_push") is not None else True,
                        "fcm_token": d.get("fcm_token") or "",
                        "domains": d.get("domains") or ["all"],
                        "mode": d.get("mode") or "account"
                    }
                
                # Try 'registered_users' second
                doc = self._firestore.db.collection("registered_users").document(user_id).get()
                if doc.exists:
                    d = doc.to_dict()
                    return {
                        "user_id": d.get("user_id") or doc.id,
                        "name": d.get("name") or "User",
                        "phone": d.get("phone") or "",
                        "email": d.get("email") or "",
                        "notify_sms": d.get("notify_sms") if d.get("notify_sms") is not None else True,
                        "notify_email": d.get("notify_email") if d.get("notify_email") is not None else True,
                        "notify_push": d.get("notify_push") if d.get("notify_push") is not None else True,
                        "fcm_token": d.get("fcm_token") or "",
                        "domains": d.get("domains") or ["all"],
                        "mode": d.get("mode") or "account"
                    }
            except Exception as e:
                logger.error(f"[UserRegistry] ❌ Firestore read failed: {e}")

        # JSON fallback
        users = self._load_from_json()
        for u in users:
            if u.get("user_id") == user_id:
                return u
        return None

    def update_user(self, user_id: str, updates: Dict[str, Any]) -> Dict[str, Any]:
        """
        Update user preferences.

        Args:
            user_id: User identifier
            updates: Dict of fields to update

        Returns:
            Updated user dict
        """
        updates["updated_at"] = datetime.utcnow().isoformat()

        # Normalize fields for 'users' collection format (snake_case)
        normalized_updates = {}
        for k, v in updates.items():
            if k == "name":
                normalized_updates["display_name"] = v
            elif k == "user_id":
                normalized_updates["uid"] = v
            else:
                normalized_updates[k] = v

        if self._firestore_available:
            try:
                # Update in 'users' collection if document exists
                try:
                    self._firestore.db.collection("users").document(user_id).update(normalized_updates)
                except Exception:
                    pass

                # Update in 'registered_users' collection if document exists
                try:
                    self._firestore.db.collection("registered_users").document(user_id).update(updates)
                except Exception:
                    pass

                logger.info(f"[UserRegistry] ✅ Updated {user_id} in Firestore")
                return self.get_user(user_id) or updates
            except Exception as e:
                logger.error(f"[UserRegistry] ❌ Firestore update failed: {e}")

        # JSON fallback
        users = self._load_from_json()
        for i, u in enumerate(users):
            if u.get("user_id") == user_id:
                users[i].update(updates)
                self._write_json(users)
                logger.info(f"[UserRegistry] ✅ Updated {user_id} in JSON")
                return users[i]

        logger.warning(f"[UserRegistry] User {user_id} not found for update")
        return updates

    def delete_user(self, user_id: str) -> bool:
        """
        Delete/unregister a user.

        Args:
            user_id: User identifier

        Returns:
            True if deleted, False if not found
        """
        if self._firestore_available:
            try:
                self._firestore.db.collection("registered_users").document(user_id).delete()
                logger.info(f"[UserRegistry] ✅ Deleted {user_id} from Firestore")
            except Exception as e:
                logger.error(f"[UserRegistry] ❌ Firestore delete failed: {e}")

        # JSON fallback
        users = self._load_from_json()
        original_count = len(users)
        users = [u for u in users if u.get("user_id") != user_id]

        if len(users) < original_count:
            self._write_json(users)
            logger.info(f"[UserRegistry] ✅ Deleted {user_id} from JSON")
            return True

        return False

    def get_users_for_domain(self, domain: str) -> List[Dict[str, Any]]:
        """
        Get users subscribed to a specific domain.

        Args:
            domain: Business domain (e.g., 'Energy', 'Currency')

        Returns:
            List of users who should receive notifications for this domain
        """
        all_users = self.get_all_users()
        result = []
        for user in all_users:
            user_domains = user.get("domains", ["all"])
            if "all" in user_domains or domain in user_domains:
                result.append(user)
        return result

    # ==================== JSON FILE HELPERS ====================

    def _load_from_json(self) -> List[Dict[str, Any]]:
        """Load users from JSON file."""
        try:
            with open(USERS_FILE, "r") as f:
                users = json.load(f)
            # Normalize user objects with defaults
            for u in users:
                if "notify_push" not in u:
                    u["notify_push"] = True
                if "fcm_token" not in u:
                    u["fcm_token"] = ""
            return users
        except (FileNotFoundError, json.JSONDecodeError):
            return []

    def _save_to_json(self, user: Dict[str, Any]) -> None:
        """Append a single user to JSON file."""
        users = self._load_from_json()
        users.append(user)
        self._write_json(users)
        logger.info(f"[UserRegistry] ✅ Saved {user['user_id']} to JSON")

    def _write_json(self, users: List[Dict[str, Any]]) -> None:
        """Write full users list to JSON file."""
        os.makedirs(os.path.dirname(USERS_FILE), exist_ok=True)
        with open(USERS_FILE, "w") as f:
            json.dump(users, f, indent=2, default=str)


# ==================== SINGLETON ====================

_user_registry: Optional[UserRegistry] = None


def get_user_registry() -> UserRegistry:
    """Get or create UserRegistry singleton."""
    global _user_registry
    if _user_registry is None:
        _user_registry = UserRegistry()
    return _user_registry
