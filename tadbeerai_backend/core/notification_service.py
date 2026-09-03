"""
Notification Service for Real SMS and Email Sending

Sends actual notifications to ALL registered users via Twilio (SMS) and SendGrid (Email).
Includes fan-out logic, retry handling, and full audit logging.
"""

import json
import logging
import os
from typing import Tuple, List, Dict, Any
from datetime import datetime

try:
    from twilio.rest import Client as TwilioClient
    TWILIO_AVAILABLE = True
except ImportError:
    TWILIO_AVAILABLE = False

try:
    from sendgrid import SendGridAPIClient
    from sendgrid.helpers.mail import Mail, Email, To, Content
    SENDGRID_AVAILABLE = True
except ImportError:
    SENDGRID_AVAILABLE = False

try:
    import firebase_admin
    from firebase_admin import messaging
    FIREBASE_AVAILABLE = True
except ImportError:
    FIREBASE_AVAILABLE = False

from core.firestore_client import get_firestore_client
from core.notification_templates import format_notification_for_user
from core.user_registry import get_user_registry
from core.paths import get_data_dir

logger = logging.getLogger(__name__)

NOTIFICATION_LOG_FILE = os.path.join(get_data_dir(), "notification_log.json")


class NotificationService:
    """Service for sending SMS and email notifications to registered users."""

    def __init__(self):
        """Initialize notification clients."""
        self.twilio_client = None
        self.sendgrid_client = None
        self.firestore = get_firestore_client()
        self.fcm_available = False

        self._init_twilio()
        self._init_sendgrid()
        self._init_fcm()

    def _init_twilio(self) -> None:
        """Initialize Twilio client for SMS."""
        if not TWILIO_AVAILABLE:
            logger.warning("[Notifications] Twilio not installed. SMS disabled.")
            return

        account_sid = os.getenv("TWILIO_ACCOUNT_SID")
        auth_token = os.getenv("TWILIO_AUTH_TOKEN")

        if not account_sid or not auth_token:
            logger.warning("[Notifications] TWILIO_ACCOUNT_SID or TWILIO_AUTH_TOKEN not set. SMS disabled.")
            return

        try:
            self.twilio_client = TwilioClient(account_sid, auth_token)
            logger.info("[Notifications] ✅ Twilio initialized")
        except Exception as e:
            logger.error(f"[Notifications] ❌ Failed to initialize Twilio: {e}")

    def _init_sendgrid(self) -> None:
        """Initialize SendGrid client for email."""
        if not SENDGRID_AVAILABLE:
            logger.warning("[Notifications] SendGrid not installed. Email disabled.")
            return

        api_key = os.getenv("SENDGRID_API_KEY")

        if not api_key:
            logger.warning("[Notifications] SENDGRID_API_KEY not set. Email disabled.")
            return

        try:
            self.sendgrid_client = SendGridAPIClient(api_key)
            logger.info("[Notifications] ✅ SendGrid initialized")
        except Exception as e:
            logger.error(f"[Notifications] ❌ Failed to initialize SendGrid: {e}")

    def _init_fcm(self) -> None:
        """Initialize FCM capabilities."""
        if not FIREBASE_AVAILABLE:
            logger.warning("[Notifications] Firebase Admin SDK not installed. FCM disabled.")
            return

        try:
            if self.firestore.available:
                self.fcm_available = True
                logger.info("[Notifications] ✅ FCM Messaging capabilities initialized")
            else:
                logger.warning("[Notifications] Firestore/Firebase not initialized. FCM disabled.")
        except Exception as e:
            logger.error(f"[Notifications] ❌ Failed to initialize FCM: {e}")

    # ==================== SINGLE-USER SEND ====================

    def send_sms(self, to_phone: str, message: str, action_id: str = "") -> Tuple[bool, str]:
        """
        Send SMS via Twilio. (Currently disabled/commented in backend)
        """
        logger.info(f"[Notifications] SMS sending is currently disabled in backend. (Target: {to_phone}, Message: {message})")
        self._log_notification(to_phone, "sms", message, action_id, "disabled")
        return False, "disabled"


    def send_email(
        self,
        to_email: str,
        subject: str,
        body: str,
        action_id: str = ""
    ) -> Tuple[bool, str]:
        """
        Send email via Gmail SMTP or Resend.

        Args:
            to_email: Recipient email address
            subject: Email subject
            body: Email body
            action_id: Related action ID for audit trail

        Returns:
            (success: bool, message_id: str)
        """
        try:
            # Import dynamically to avoid circular import issues
            from gmail_smtp import send_email_alert
            send_email_alert(to_email, subject, body)
            logger.info(f"[Notifications] ✅ Email sent to {to_email}")
            self._log_notification(to_email, "email", f"{subject}: {body[:100]}", action_id, "sent")
            return True, "sent"
        except Exception as e:
            error_msg = f"Failed to send email to {to_email}: {str(e)}"
            logger.error(f"[Notifications] ❌ {error_msg}")
            self._log_notification(to_email, "email", f"{subject}: {body[:100]}", action_id, "failed")
            return False, error_msg

    def send_push(self, token: str, title: str, body: str, action_id: str = "") -> Tuple[bool, str]:
        """
        Send a push notification via FCM.

        Args:
            token: FCM device registration token
            title: Push title
            body: Push body message
            action_id: Related action ID for tracking

        Returns:
            (success: bool, response_id: str)
        """
        if not self.fcm_available or not token:
            logger.warning(f"[Notifications] Push skipped (FCM not available or no token): {token}")
            self._log_notification(token or "unknown", "push", body, action_id, "skipped")
            return False, "skipped"

        try:
            from firebase_admin import messaging
            message = messaging.Message(
                notification=messaging.Notification(
                    title=title,
                    body=body,
                ),
                token=token,
                data={
                    "click_action": "FLUTTER_NOTIFICATION_CLICK",
                    "action_id": action_id,
                }
            )
            response = messaging.send(message)
            logger.info(f"[Notifications] ✅ Push sent: {response}")
            self._log_notification(token, "push", body, action_id, "sent")
            return True, response
        except Exception as e:
            error_msg = f"Failed to send push: {str(e)}"
            logger.error(f"[Notifications] ❌ {error_msg}")
            self._log_notification(token, "push", body, action_id, "failed")
            return False, error_msg

    # ==================== FAN-OUT TO ALL USERS ====================

    def notify_all_users(
        self,
        action_key: str,
        action_description: str,
        impact_amount: str,
        domain: str,
        action_id: str,
        diffs: list[dict] | None = None,
        notify_channels: list[str] | None = None,
        user_id: str | None = None,
        insight: dict | None = None,
        action_detail: str | None = None,
        sms_draft: str | None = None,
        business_math: str | None = None,
        urgency: str | None = None,
        timeline: str | None = None,
    ) -> Tuple[int, int, int, int, str, dict]:
        """
        Send SMS, email, and push notifications to registered users for an executed action.
        If user_id is provided, only that user is notified. Otherwise, all subscribed users are notified.

        Args:
            action_key: Action template key (e.g., 'energy_increase_delivery_fee')
            action_description: Human-readable description
            impact_amount: Quantified impact
            domain: Business domain
            action_id: Unique action ID
            diffs: List of before/after state change dicts
            notify_channels: Filter channels requested (e.g., ['sms', 'email', 'push'])
            user_id: Optional ID of a single user to notify
            insight: Optional insight dict
            action_detail: Optional recommended action instruction/detail
            sms_draft: Optional generated SMS draft text
            business_math: Optional business recovery math
            urgency: Optional urgency level
            timeline: Optional timeline

        Returns:
            (users_reached, sms_sent, emails_sent, push_sent, summary_message, delivery_report)
        """
        try:
            timestamp = datetime.utcnow().strftime("%Y-%m-%d %H:%M UTC")
            registry = get_user_registry()

            if user_id:
                single_user = registry.get_user(user_id)
                users = [single_user] if single_user else []
            else:
                # Get users subscribed to this domain
                users = registry.get_users_for_domain(domain)

            if not users:
                msg = "No notification recipients (user not found or guest mode)"
                logger.info(f"[Notifications] ℹ️ {msg}")
                empty_report = {
                    "sms_recipients": 0,
                    "email_recipients": 0,
                    "push_recipients": 0,
                    "status": "guest",
                    "sms_skipped": True,
                    "email_skipped": True,
                    "push_skipped": True
                }
                return 0, 0, 0, 0, msg, empty_report

            logger.info(f"[Notifications] 📧 Sending alerts to {len(users)} users for {domain} action...")

            sms_sent = 0
            sms_failed = 0
            emails_sent = 0
            emails_failed = 0
            push_sent = 0
            push_failed = 0

            wants_any_sms = False
            wants_any_email = False
            wants_any_push = False

            for user in users:
                user_name = user.get("name", "User")
                user_phone = user.get("phone", "")
                user_email = user.get("email", "")
                user_fcm_token = user.get("fcm_token", "")

                u_wants_sms = user.get("notify_sms", True)
                u_wants_email = user.get("notify_email", True)
                u_wants_push = user.get("notify_push", True)

                # Filter by notify_channels requested in API call if present
                wants_sms = u_wants_sms and (notify_channels is None or "sms" in notify_channels)
                wants_email = u_wants_email and (notify_channels is None or "email" in notify_channels)
                wants_push = u_wants_push and (notify_channels is None or "push" in notify_channels)

                if wants_sms and user_phone:
                    wants_any_sms = True
                if wants_email and user_email:
                    wants_any_email = True
                if wants_push and user_fcm_token:
                    wants_any_push = True

                # Format personalized content
                try:
                    sms_content, email_subject, email_body = format_notification_for_user(
                        template_key=action_key,
                        user_name=user_name,
                        action_description=action_description,
                        impact_amount=impact_amount,
                        domain=domain,
                        timestamp=timestamp,
                        diffs=diffs,
                        insight=insight,
                        action_detail=action_detail,
                        sms_draft=sms_draft,
                        business_math=business_math,
                        urgency=urgency,
                        timeline=timeline,
                    )
                except Exception as e:
                    logger.error(f"[Notifications] ❌ Template format error for {user_name}: {e}")
                    continue

                # Send SMS
                if wants_sms and user_phone:
                    success, _ = self.send_sms(user_phone, sms_content, action_id)
                    if success:
                        sms_sent += 1
                    else:
                        sms_failed += 1

                # Send Email
                if wants_email and user_email:
                    success, _ = self.send_email(user_email, email_subject, email_body, action_id)
                    if success:
                        emails_sent += 1
                    else:
                        emails_failed += 1

                # Send Push Notification
                if wants_push and user_fcm_token:
                    push_title = f"⚡ TadbeerAI: {action_description[:40]}"
                    success, _ = self.send_push(user_fcm_token, push_title, sms_content, action_id)
                    if success:
                        push_sent += 1
                    else:
                        push_failed += 1

            users_reached = len(users)
            summary_parts = []
            summary_parts.append(f"{users_reached} users")
            summary_parts.append(f"SMS: {sms_sent}/{sms_sent + sms_failed}")
            summary_parts.append(f"Email: {emails_sent}/{emails_sent + emails_failed}")
            summary_parts.append(f"Push: {push_sent}/{push_sent + push_failed}")
            summary = " · ".join(summary_parts)

            status_emoji = "✅" if (sms_failed == 0 and emails_failed == 0 and push_failed == 0) else "⚠️"
            logger.info(f"[Notifications] {status_emoji} Fan-out complete: {summary}")

            # Build delivery report
            delivery_report = {
                "sms_recipients": sms_sent,
                "email_recipients": emails_sent,
                "push_recipients": push_sent,
                "status": "sent" if (sms_sent + emails_sent + push_sent > 0) else "partial",
                "sms_skipped": not wants_any_sms or not self.twilio_client,
                "email_skipped": not wants_any_email or not self.sendgrid_client,
                "push_skipped": not wants_any_push or not self.fcm_available,
            }

            return users_reached, sms_sent, emails_sent, push_sent, summary, delivery_report

        except Exception as e:
            error_msg = f"Notification fan-out error: {str(e)}"
            logger.error(f"[Notifications] ❌ {error_msg}")
            fallback_report = {
                "sms_recipients": 0,
                "email_recipients": 0,
                "push_recipients": 0,
                "status": "failed",
                "sms_skipped": True,
                "email_skipped": True,
                "push_skipped": True
            }
            return 0, 0, 0, 0, error_msg, fallback_report

    # ==================== NOTIFICATION HISTORY ====================

    def get_notification_history(self, limit: int = 50) -> List[Dict[str, Any]]:
        """
        Get notification history from Firestore or JSON fallback.

        Args:
            limit: Max number of records to return

        Returns:
            List of notification log dicts (newest first)
        """
        # Try Firestore first
        if self.firestore.available:
            try:
                from firebase_admin import firestore as fs
                docs = self.firestore.db.collection("notification_log").order_by(
                    "timestamp", direction=fs.Query.DESCENDING
                ).limit(limit).stream()
                history = [doc.to_dict() for doc in docs]
                if history:
                    return history
            except Exception as e:
                logger.error(f"[Notifications] ❌ Firestore history fetch failed: {e}")

        # JSON fallback
        try:
            with open(NOTIFICATION_LOG_FILE, "r") as f:
                logs = json.load(f)
            # Return newest first, limited
            return sorted(logs, key=lambda x: x.get("timestamp", ""), reverse=True)[:limit]
        except (FileNotFoundError, json.JSONDecodeError):
            return []

    # ==================== HELPERS ====================

    def _log_notification(
        self,
        recipient: str,
        notification_type: str,
        content: str,
        action_id: str,
        status: str,
    ) -> None:
        """Log notification attempt to Firestore and JSON fallback."""
        log_entry = {
            "recipient": recipient,
            "type": notification_type,
            "content": content[:200],  # Truncate for storage
            "action_id": action_id,
            "status": status,
            "timestamp": datetime.utcnow().isoformat(),
        }

        # Log to Firestore
        try:
            self.firestore.create_notification_log(
                recipient, notification_type, content[:200], action_id, status
            )
        except Exception as e:
            logger.error(f"[Notifications] Firestore log failed: {e}")

        # Also log to local JSON (always, as backup)
        self._append_to_json_log(log_entry)

    def _append_to_json_log(self, entry: Dict[str, Any]) -> None:
        """Append notification log entry to local JSON file."""
        try:
            os.makedirs(os.path.dirname(NOTIFICATION_LOG_FILE), exist_ok=True)

            logs = []
            if os.path.exists(NOTIFICATION_LOG_FILE):
                try:
                    with open(NOTIFICATION_LOG_FILE, "r") as f:
                        logs = json.load(f)
                except (json.JSONDecodeError, FileNotFoundError):
                    logs = []

            logs.append(entry)

            # Keep last 200 entries
            if len(logs) > 200:
                logs = logs[-200:]

            with open(NOTIFICATION_LOG_FILE, "w") as f:
                json.dump(logs, f, indent=2, default=str)

        except Exception as e:
            logger.error(f"[Notifications] JSON log write failed: {e}")

    @staticmethod
    def _format_html_email(plain_text: str) -> str:
        """Convert plain text email to HTML with styling."""
        # Convert markdown-style bold to HTML
        import re
        html_body = plain_text.replace("\n", "<br>")
        html_body = re.sub(r'\*\*(.*?)\*\*', r'<strong>\1</strong>', html_body)

        html_content = f"""
        <html>
            <body style="font-family: 'Segoe UI', Arial, sans-serif; line-height: 1.8; color: #2d3748; background-color: #f7fafc;">
                <div style="max-width: 600px; margin: 20px auto; padding: 0;">
                    <!-- Header -->
                    <div style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 24px 30px; border-radius: 12px 12px 0 0;">
                        <h1 style="margin: 0; color: #ffffff; font-size: 20px; font-weight: 600;">
                            ⚡ TadbeerAI Alert
                        </h1>
                        <p style="margin: 4px 0 0 0; color: rgba(255,255,255,0.85); font-size: 13px;">
                            Pakistan Business Intelligence
                        </p>
                    </div>

                    <!-- Body -->
                    <div style="background-color: #ffffff; padding: 28px 30px; border-left: 1px solid #e2e8f0; border-right: 1px solid #e2e8f0;">
                        {html_body}
                    </div>

                    <!-- Footer -->
                    <div style="background-color: #edf2f7; padding: 16px 30px; border-radius: 0 0 12px 12px; border: 1px solid #e2e8f0; border-top: none;">
                        <p style="margin: 0; font-size: 12px; color: #718096;">
                            This is an automated alert from TadbeerAI Business Intelligence System.<br>
                            You are receiving this because you are registered for notification alerts.
                        </p>
                    </div>
                </div>
            </body>
        </html>
        """
        return html_content


# Global singleton instance
_notification_service = None


def get_notification_service() -> NotificationService:
    """Get or create NotificationService singleton."""
    global _notification_service
    if _notification_service is None:
        _notification_service = NotificationService()
    return _notification_service
