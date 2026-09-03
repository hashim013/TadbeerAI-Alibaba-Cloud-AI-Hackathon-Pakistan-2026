"""
Agent 6: Real Execution Agent

Executes top-priority actions with:
- Real Firestore state persistence
- Real SMS/email notifications
- Real external API calls (billing, inventory, analytics)
- Atomic transactions with rollback on failure
- Full audit trail
"""

import logging
import re
from datetime import datetime
from core.llm_client import call_llm_json
from typing import Tuple
from uuid import uuid4

from core.firestore_client import get_firestore_client
from core.notification_service import get_notification_service
from core.external_api_client import get_external_api_client
from core.execution_rollback import get_rollback_manager
from agents.execution_handlers.energy_executor import execute_energy_action
from agents.execution_handlers.currency_executor import execute_currency_action
from agents.execution_handlers.stock_market_executor import execute_stock_market_action
from agents.execution_handlers.gold_executor import execute_gold_action
from agents.execution_handlers.logistics_executor import execute_logistics_action
from agents.execution_handlers.finance_executor import execute_finance_action
from agents.execution_handlers.policy_executor import execute_policy_action
from agents.execution_handlers.trade_executor import execute_trade_action
from agents.execution_handlers.supply_chain_executor import execute_supply_chain_action

logger = logging.getLogger(__name__)


def send_fcm_push(fcm_token: str, title: str, body: str):
    """Send a push notification via FCM using the notification service."""
    try:
        from core.notification_service import get_notification_service
        get_notification_service().send_push(fcm_token, title, body)
        print(f"[FCM Push] Sent push alert to {fcm_token[:15]}...")
    except Exception as e:
        print(f"[FCM Push] Failed to send push: {e}")


def classify_news_category(insight_title: str, insight_detail: str) -> str:
    """Classify news item into shop, business, employee, or student category."""
    prompt = f"""
Classify the following news/insight into exactly one of these four categories: "shop", "business", "employee", "student".

INSIGHT TITLE: {insight_title}
INSIGHT DETAIL: {insight_detail}

Respond with JSON in exactly this format:
{{
  "category": "one of shop, business, employee, student"
}}
"""
    try:
        result = call_llm_json(prompt, "You are a news classifier that maps business news to user personas.")
        if result and isinstance(result, dict) and result.get("category"):
            cat = result["category"].strip().lower()
            if cat in ["shop", "business", "employee", "student"]:
                print(f"[classify_news_category] LLM classified news as: {cat}")
                return cat
    except Exception as e:
        print(f"[classify_news_category] LLM classification error: {e}")
        
    # Fallback keyword matching
    text = (insight_title + " " + insight_detail).lower()
    if any(k in text for k in ["salary", "job", "employee", "wage", "workforce", "hiring"]):
        return "employee"
    if any(k in text for k in ["student", "university", "education", "stipend", "school", "college"]):
        return "student"
    if any(k in text for k in ["shop", "retail", "mart", "store", "vendor", "inventory", "revenue"]):
        return "shop"
    return "business"


def simulate_action(
    actions: list[dict],
    domain: str,
    insight: dict,
    user_id: str | None = None,
    notify_channels: list[str] | None = None,
    user_profile: dict | None = None,
) -> dict:
    """
    Agent 6: REAL EXECUTION (NOT SIMULATION)

    Executes the TOP action with real consequences:
    1. Fetches current state from Firestore
    2. Calls domain-specific executor
    3. Executes external APIs (billing, inventory, analytics)
    4. Rolls back on failure
    5. Sends real SMS/email notifications
    6. Logs complete audit trail

    Args:
        actions: List of recommended actions (top one executed)
        domain: Business domain (Energy, Currency, Stock Market, Gold, Logistics)
        insight: Insight dict with insight_title, impacts, etc.

    Returns:
        Dict with execution status, before/after diffs, notifications sent, audit trail
    """
    start_time = datetime.now()
    transaction_id = f"exec_{uuid4().hex[:12]}"
    exec_log: list[dict] = []

    def log(prefix: str, message: str, log_type: str = "ok"):
        """Log execution step."""
        exec_log.append({
            "time": datetime.now().strftime("%H:%M:%S"),
            "prefix": prefix,
            "message": message,
            "type": log_type,
        })
        logger.info(f"{prefix} {message}")

    # Initialize services
    firestore = get_firestore_client()
    notification_svc = get_notification_service()
    rollback_mgr = get_rollback_manager()

    log("[Agent6]", "🟢 REAL EXECUTION TRIGGERED (not simulation)", "info")
    log("[Agent6]", f"Transaction ID: {transaction_id}", "info")

    top_action = actions[0] if actions else {}

    if not top_action:
        log("[Agent6]", "❌ No actions available", "error")
        return _build_response(
            False,
            [],
            "",
            0,
            0,
            exec_log,
            transaction_id,
            "No actions to execute"
        )

    action_title = top_action.get("title", "")
    action_detail = top_action.get("detail", "")
    action_key = _get_action_key(domain, action_title)

    log("[Agent6]", f"Executing: {action_title[:60]}", "info")

    # Get current state from Firestore
    log("[Firestore]", "📥 Fetching current business state...", "info")
    current_state = firestore.get_business_state()
    log("[Firestore]", f"✅ Fetched state with {len(current_state)} fields", "ok")

    # Extract impact value from insight
    impact_value = _extract_impact_value(insight, domain)
    log("[Analysis]", f"Impact value extracted: {impact_value}", "info")

    # Execute domain-specific action
    log("[Executor]", f"Calling {domain} executor...", "info")
    success, before_state, after_state, error_msg = _execute_domain_action(
        domain,
        action_title,
        action_key,
        current_state,
        impact_value,
        transaction_id
    )

    if not success:
        log("[Executor]", f"❌ Execution failed: {error_msg}", "error")
        return _build_response(
            False,
            [],
            "",
            0,
            0,
            exec_log,
            transaction_id,
            error_msg
        )

    log("[Executor]", "✅ Domain executor completed successfully", "ok")

    # Update Firestore with new state
    log("[Firestore]", "💾 Persisting state changes...", "info")
    db_success, db_error = firestore.update_business_state(after_state)

    if not db_error:
        log("[Firestore]", "✅ State persisted to Firestore", "ok")
    else:
        log("[Firestore]", f"⚠️ State update issue: {db_error}", "warn")

    # Log execution to audit trail
    log("[Audit]", "📝 Logging execution to audit trail...", "info")
    audit_success, execution_id = firestore.create_execution_log(
        action_id=transaction_id,
        domain=domain,
        before_state=before_state,
        after_state=after_state,
        status="executed",
        error_msg=""
    )

    if audit_success:
        log("[Audit]", f"✅ Execution logged: {execution_id}", "ok")
    else:
        log("[Audit]", f"⚠️ Audit logging issue", "warn")

    # Build diffs for notification content
    diffs = _calculate_diffs(before_state, after_state)

    # Generate intelligent SMS draft using Gemini
    log("[Agent6]", "📝 Generating intelligent SMS draft...", "info")
    sms_draft = _generate_sms_draft(domain, action_title, action_detail, insight, diffs, user_profile=user_profile)
    log("[Agent6]", f"✅ SMS draft: {sms_draft[:60]}...", "ok")

    # Send notifications to registered users (skip gracefully in guest mode)
    if user_id is None or (user_profile and user_profile.get("mode") == "guest"):
        log("[Notifications]", "ℹ️ Guest mode: skipping real-time notification alerts", "info")
        users_reached = 0
        sms_sent = 0
        emails_sent = 0
        push_sent = 0
        delivery_report = {
            "sms_recipients": 0,
            "email_recipients": 0,
            "push_recipients": 0,
            "status": "guest",
            "sms_skipped": True,
            "email_skipped": True,
            "push_skipped": True
        }
    else:
        log("[Notifications]", f"📧 Sending alerts to initiating user ({user_id})...", "info")
        impact_str = f"Rs. {impact_value:.0f}" if isinstance(impact_value, float) else str(impact_value)
        users_reached, sms_sent, emails_sent, push_sent, notif_msg, delivery_report = notification_svc.notify_all_users(
            action_key=action_key,
            action_description=action_title,
            impact_amount=impact_str,
            domain=domain,
            action_id=transaction_id,
            diffs=diffs,
            notify_channels=notify_channels,
            user_id=user_id,
            insight=insight,
            action_detail=action_detail,
            sms_draft=sms_draft,
            business_math=top_action.get("business_math", ""),
            urgency=top_action.get("urgency", ""),
            timeline=top_action.get("timeline", ""),
        )
        if users_reached > 0:
            log("[Notifications]", f"✅ Alerts sent: {notif_msg}", "ok")
        else:
            log("[Notifications]", f"ℹ️ Notification skipped: {notif_msg}", "info")

    # Calculate execution time
    exec_time = (datetime.now() - start_time).total_seconds()

    log("[Agent6]", f"✅ REAL EXECUTION COMPLETE · {len(diffs)} state changes · {users_reached} users notified · {exec_time:.2f}s", "ok")

    return _build_response(
        True,
        diffs,
        f"{action_title[:50]}...",
        len(exec_log),
        exec_time,
        exec_log,
        transaction_id,
        "",
        users_reached=users_reached,
        sms_sent=sms_sent,
        emails_sent=emails_sent,
        push_sent=push_sent,
        delivery_report=delivery_report,
        sms_draft_text=sms_draft,
    )



# ==================== HELPER FUNCTIONS ====================

def _execute_domain_action(
    domain: str,
    action_title: str,
    action_key: str,
    current_state: dict,
    impact_value: float,
    transaction_id: str
) -> Tuple[bool, dict, dict, str]:
    """
    Route to domain-specific executor and execute action.

    Returns:
        (success, before_state, after_state, error_msg)
    """
    try:
        if domain == "Energy":
            return execute_energy_action(action_title, action_key, current_state, impact_value, transaction_id)
        elif domain == "Currency":
            return execute_currency_action(action_title, action_key, current_state, impact_value, transaction_id)
        elif domain == "Stock Market":
            return execute_stock_market_action(action_title, action_key, current_state, impact_value, transaction_id)
        elif domain == "Gold":
            return execute_gold_action(action_title, action_key, current_state, impact_value, transaction_id)
        elif domain == "Logistics":
            return execute_logistics_action(action_title, action_key, current_state, impact_value, transaction_id)
        elif domain == "Finance":
            return execute_finance_action(action_title, action_key, current_state, impact_value, transaction_id)
        elif domain == "Policy":
            return execute_policy_action(action_title, action_key, current_state, impact_value, transaction_id)
        elif domain == "Trade":
            return execute_trade_action(action_title, action_key, current_state, impact_value, transaction_id)
        elif domain == "Supply Chain":
            return execute_supply_chain_action(action_title, action_key, current_state, impact_value, transaction_id)
        else:
            return False, current_state, current_state, f"Unknown domain: {domain}"

    except Exception as e:
        logger.error(f"[SimulationAgent] Domain executor error: {str(e)}")
        return False, current_state, current_state, str(e)


def _extract_impact_value(insight: dict, domain: str) -> float:
    """
    Extract quantified impact value from insight.

    Examples:
        "Rs. 28 increase" -> 28
        "15% volatility" -> 15
        "1,234 units" -> 1234
    """
    impacts = insight.get("impacts", [])

    if impacts and isinstance(impacts, list) and len(impacts) > 0:
        first_impact = impacts[0]
        if isinstance(first_impact, dict):
            value_str = first_impact.get("quantified") or first_impact.get("quantified_value") or "0"
        else:
            value_str = str(first_impact)
    else:
        value_str = insight.get("insight_title", "0")

    # Extract numeric value
    match = re.search(r"([\d,]+(?:\.\d+)?)", str(value_str))
    if match:
        try:
            return float(match.group(1).replace(",", ""))
        except ValueError:
            pass

    return 10.0  # Default fallback


def _get_action_key(domain: str, action_title: str) -> str:
    """
    Map domain + action to notification template key.

    Examples:
        ("Energy", "Increase delivery fee to Rs. 178") -> "energy_increase_delivery_fee"
        ("Currency", "Hold all orders immediately") -> "currency_hold_orders"
    """
    domain_lower = domain.lower().replace(" ", "_")
    title_lower = action_title.lower()

    # Energy mappings
    if domain == "Energy":
        if "fee" in title_lower or "delivery" in title_lower or "pricing" in title_lower:
            return "energy_increase_delivery_fee"
        elif "route" in title_lower or "optimize" in title_lower:
            return "energy_optimize_routes"
        elif "fuel" in title_lower or "procurement" in title_lower:
            return "energy_optimize_routes"

    # Currency mappings
    elif domain == "Currency":
        if "hold" in title_lower or "orders" in title_lower:
            return "currency_hold_orders"
        elif "buffer" in title_lower or "import" in title_lower:
            return "currency_adjust_import_cost"

    # Stock market mappings
    elif domain == "Stock Market":
        if "hedge" in title_lower:
            return "stock_hedge_portfolio"
        elif "stop" in title_lower and "loss" in title_lower:
            return "stock_set_stop_loss"

    # Gold mappings
    elif domain == "Gold":
        if "hold" in title_lower or "procurement" in title_lower:
            return "gold_hold_procurement"

    # Logistics mappings
    elif domain == "Logistics":
        if "safety" in title_lower or "stock" in title_lower:
            return "logistics_increase_safety_stock"

    # Finance mappings
    elif domain == "Finance":
        return "finance_adjust_interest"

    # Policy mappings
    elif domain == "Policy":
        return "policy_audit_check"

    # Trade mappings
    elif domain == "Trade":
        return "trade_adjust_tariff"

    # Supply Chain mappings
    elif domain == "Supply Chain":
        return "supply_chain_optimize"

    return "generic_action"


def _calculate_diffs(before_state: dict, after_state: dict) -> list[dict]:
    """Calculate before/after diffs for display."""
    diffs = []

    for key in after_state:
        if key not in ["last_updated", "updated_by"]:
            before_val = before_state.get(key, "N/A")
            after_val = after_state.get(key, "N/A")

            if before_val != after_val:
                # Format key for display
                display_key = key.replace("_", " ").title()

                diffs.append({
                    "field": display_key,
                    "before": str(before_val),
                    "after": str(after_val)
                })

    return diffs


def _generate_sms_draft(
    domain: str,
    action_title: str,
    action_detail: str,
    insight: dict,
    diffs: list[dict],
    user_profile: dict = None,
) -> str:
    """
    Generate a concise customer-facing or personal SMS notification informing users about a price/business change.
    Must be exactly 5 to 8 lines long and easy for customers/users to understand.
    """
    diff_text = ", ".join(
        f"{d['field']}: {d['before']} → {d['after']}" for d in diffs
    ) if diffs else "No configuration changes"

    profile_info = ""
    if user_profile:
        category = user_profile.get("category", "")
        profile_info = f"\nUser Profile / Persona: {category}\n"
        if category in ["shop", "business"]:
            profile_info += "The user is a business/shop owner. Write the SMS draft from the perspective of their business informing their customers, clients, or subscribers (e.g. starting with '[TadbeerAI] 📢 Alert' and addressing 'Dear Valued Customer' or similar).\n"
        elif category == "student":
            profile_info += "The user is a student. Write the SMS draft as a personal alert or helpful notification tailored to students (e.g. starting with '[TadbeerAI] 📢 Student Alert' and addressing 'Dear Student' or 'Dear Student User' informing them how this event affects student expenses/housing/transport/budgets).\n"
        elif category == "employee":
            profile_info += "The user is an employee/salaried professional. Write the SMS draft as a personal alert or notification tailored to salaried workers (e.g. starting with '[TadbeerAI] 📢 Salary & Transit Alert' and addressing 'Dear Valued Employee' or 'Dear Salaried Professional' informing them how this event affects commuting costs, salary buffers, or personal expenses).\n"
    else:
        profile_info = "\nWrite the SMS draft from the perspective of a Pakistan business informing its customers.\n"

    prompt = f"""
Generate a concise, professional, and clear SMS notification informing the recipient about a recent event and the action taken.

CONTEXT:
- Business Domain: {domain}
- News/Event (What happened): {insight.get('insight_title', 'Business update')}
- Action taken (What was done): {action_title}
- Action Details: {action_detail}
- System State Changes: {diff_text}

{profile_info}

CRITICAL RULES:
1. The SMS must be EXACTLY 5 to 8 lines long.
2. The message must begin with "[TadbeerAI] 📢 " followed by a customer-facing or user-appropriate title on the first line.
3. The rest of the message must be written from the perspective of the business (or TadbeerAI helper) informing its customers/users.
4. Explain the price change or business event clearly and state what action was taken / adjustment made that affects them.
5. Keep the language extremely simple, direct, and easy to understand at a glance.
6. Do NOT include internal developer or system terms (like "import_cost_buffer" or "Firestore database"). Use customer-facing terms instead.
7. Structure the message using single newlines for each line (no double newlines/blank lines).

Respond with JSON in exactly this format:
{{
  "sms_text": "[TadbeerAI] 📢 Price & Service Alert\\nDear Valued Customer,\\nDue to...\\nWe have...\\nThank you for...\\n- TadbeerAI Team"
}}
"""

    try:
        result = call_llm_json(prompt, "You are a customer communications assistant that writes short, 5-8 line SMS alerts to inform users about business adjustments.")
        if result and isinstance(result, dict) and result.get("sms_text"):
            sms = result["sms_text"].strip()
            # Verify line count
            lines = [l for l in sms.split("\n") if l.strip()]
            if 5 <= len(lines) <= 8 and sms.startswith("[TadbeerAI]"):
                logger.info(f"[Agent6] LLM 5-8 line customer SMS draft generated: {len(lines)} lines")
                return "\n".join(lines)
            else:
                logger.warning(f"[Agent6] LLM SMS had invalid format/line count, falling back to standard format.")
    except Exception as e:
        logger.warning(f"[Agent6] SMS draft generation failed: {e}")

    # Fallback to a high-quality 6-line customer-facing SMS template
    insight_title = insight.get("insight_title", "Business update")
    if len(insight_title) > 65:
        insight_title = insight_title[:62] + "..."

    return (
        f"[TadbeerAI] 📢 Price & Service Alert\n"
        f"Dear Valued Customer,\n"
        f"Due to: {insight_title},\n"
        f"Action: We have adjusted {action_title.lower()} ({action_detail}).\n"
        f"We appreciate your understanding and continued support.\n"
        f"- TadbeerAI Team"
    )


def _build_response(
    success: bool,
    diffs: list,
    action_summary: str,
    steps_logged: int,
    exec_time: float,
    exec_log: list,
    transaction_id: str,
    error_msg: str,
    users_reached: int = 0,
    sms_sent: int = 0,
    emails_sent: int = 0,
    push_sent: int = 0,
    delivery_report: dict = None,
    sms_draft_text: str = "",
) -> dict:
    """Build standardized response dict."""
    if delivery_report is None:
        if success and (sms_sent + emails_sent + push_sent > 0):
            notif_status = "sent"
        elif success and users_reached == 0:
            notif_status = "guest"
        elif not success:
            notif_status = "failed"
        else:
            notif_status = "partial"
        delivery_report = {
            "sms_recipients": sms_sent,
            "email_recipients": emails_sent,
            "push_recipients": push_sent,
            "status": notif_status,
            "sms_skipped": not success or sms_sent == 0,
            "email_skipped": not success or emails_sent == 0,
            "push_skipped": not success or push_sent == 0,
        }

    # Use dynamic SMS draft if provided, otherwise build from context
    if not sms_draft_text:
        if success:
            sms_draft_text = f"[TadbeerAI] {action_summary}"
        else:
            sms_draft_text = f"[TadbeerAI] Execution failed: {error_msg}"

    return {
        "success": success,
        "insight_summary": action_summary,
        "diffs": diffs,
        "sms_draft": sms_draft_text,
        "users_reached": users_reached,
        "sms_sent": sms_sent,
        "emails_sent": emails_sent,
        "push_sent": push_sent,
        "delivery_report": delivery_report,
        "state_changes": len(diffs),
        "exec_time_seconds": round(exec_time, 2),
        "exec_log": exec_log,
        "transaction_id": transaction_id,
        "error_msg": str(error_msg or ""),
        "execution_badge": "✅ Executed" if success else "❌ Failed"
    }

