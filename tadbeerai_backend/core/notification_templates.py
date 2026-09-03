"""
Notification Templates for Per-Action SMS and Email

Each action has unique content templates with placeholder variables:
- {action_description}: What the action does
- {impact_amount}: Quantified impact value
- {domain}: Business domain
- {timestamp}: When action was executed
- {user_name}: Registered user's name
- {diffs_summary}: Before/after state changes summary

Recipients are now resolved dynamically from UserRegistry at send time.
"""

from typing import Dict, Any, Tuple


NOTIFICATION_TEMPLATES: Dict[str, Dict[str, Dict[str, str]]] = {
    # ==================== ENERGY DOMAIN ====================
    "energy_increase_delivery_fee": {
        "sms": {
            "content": "🚗 ENERGY ALERT: Delivery fee updated to Rs. {impact_amount}. {action_description}. — TadbeerAI ({timestamp})"
        },
        "email": {
            "subject": "⚡ TadbeerAI Alert: Delivery Fee Adjustment",
            "body": """
Dear {user_name},

The following energy-related action has been executed by TadbeerAI:

**Action**: {action_description}
**New Delivery Fee**: Rs. {impact_amount}
**Domain**: {domain}
**Timestamp**: {timestamp}

**State Changes**:
{diffs_summary}

**Impact Summary**:
- Monthly operational cost impact: Rs. {impact_amount}
- Customers affected: Based on current routes
- Effective immediately

Please review and update billing systems accordingly.

Best regards,
TadbeerAI Business Intelligence
            """
        }
    },

    "energy_optimize_routes": {
        "sms": {
            "content": "📍 ROUTE ALERT: Route optimization executed. Save {impact_amount}L fuel/month. — TadbeerAI ({timestamp})"
        },
        "email": {
            "subject": "📍 TadbeerAI Alert: Route Optimization Complete",
            "body": """
Dear {user_name},

Route optimization has been executed:

**Action**: {action_description}
**Fuel Savings**: {impact_amount}L per month
**Domain**: {domain}
**Timestamp**: {timestamp}

**State Changes**:
{diffs_summary}

Update your fleet management systems with new routes.

Best regards,
TadbeerAI Business Intelligence
            """
        }
    },

    # ==================== CURRENCY DOMAIN ====================
    "currency_adjust_import_cost": {
        "sms": {
            "content": "💱 CURRENCY ALERT: Import cost buffer set to Rs. {impact_amount}. — TadbeerAI ({timestamp})"
        },
        "email": {
            "subject": "💱 TadbeerAI Alert: Import Cost Buffer Updated",
            "body": """
Dear {user_name},

Currency-based import cost action executed:

**Action**: {action_description}
**Buffer Amount**: Rs. {impact_amount}
**Domain**: {domain}
**Timestamp**: {timestamp}

**State Changes**:
{diffs_summary}

**Action Items**:
1. Update supplier contracts with new cost parameters
2. Adjust procurement forecasts
3. Notify finance team for budget adjustment

Best regards,
TadbeerAI Business Intelligence
            """
        }
    },

    "currency_hold_orders": {
        "sms": {
            "content": "⏸️ CURRENCY ALERT: Order hold activated. Expected savings: Rs. {impact_amount}. — TadbeerAI ({timestamp})"
        },
        "email": {
            "subject": "⏸️ TadbeerAI Alert: Order Hold Activated",
            "body": """
Dear {user_name},

Order hold has been activated due to currency fluctuation:

**Action**: {action_description}
**Expected Savings**: Rs. {impact_amount}
**Domain**: {domain}
**Duration**: Pending price stabilization
**Timestamp**: {timestamp}

**State Changes**:
{diffs_summary}

**Status**: 
- All pending orders HELD
- Existing commitments continue
- Monitor daily for price triggers

Best regards,
TadbeerAI Business Intelligence
            """
        }
    },

    # ==================== STOCK MARKET DOMAIN ====================
    "stock_hedge_portfolio": {
        "sms": {
            "content": "📈 STOCK ALERT: Portfolio hedging activated. Protected value: Rs. {impact_amount}. — TadbeerAI ({timestamp})"
        },
        "email": {
            "subject": "📈 TadbeerAI Alert: Portfolio Hedge Activated",
            "body": """
Dear {user_name},

Portfolio hedging strategy has been activated:

**Action**: {action_description}
**Protected Value**: Rs. {impact_amount}
**Domain**: {domain}
**Timestamp**: {timestamp}

**State Changes**:
{diffs_summary}

**Hedge Details**:
- Puts purchased on major holdings
- Coverage period: 30 days
- Cost: Deducted from trading budget

Best regards,
TadbeerAI Business Intelligence
            """
        }
    },

    "stock_set_stop_loss": {
        "sms": {
            "content": "🛑 STOCK ALERT: Stop-loss set at Rs. {impact_amount}. Risk managed. — TadbeerAI ({timestamp})"
        },
        "email": {
            "subject": "🛑 TadbeerAI Alert: Stop-Loss Activated",
            "body": """
Dear {user_name},

Stop-loss orders have been placed:

**Action**: {action_description}
**Trigger Level**: Rs. {impact_amount}
**Domain**: {domain}
**Timestamp**: {timestamp}

**State Changes**:
{diffs_summary}

**Portfolio Protection**:
- All holdings protected with SL
- Automatic execution on trigger
- Review portfolio weight daily

Best regards,
TadbeerAI Business Intelligence
            """
        }
    },

    # ==================== GOLD DOMAIN ====================
    "gold_hold_procurement": {
        "sms": {
            "content": "🛑 GOLD ALERT: Procurement hold activated. Savings: Rs. {impact_amount}. — TadbeerAI ({timestamp})"
        },
        "email": {
            "subject": "🥇 TadbeerAI Alert: Gold Procurement Hold",
            "body": """
Dear {user_name},

Gold procurement has been placed on hold:

**Action**: {action_description}
**Potential Savings**: Rs. {impact_amount}
**Domain**: {domain}
**Timestamp**: {timestamp}

**State Changes**:
{diffs_summary}

**Status**:
- STOP all new gold purchase orders
- Current inventory sufficient
- Hold duration: Until price drops {impact_amount}Rs/g

Best regards,
TadbeerAI Business Intelligence
            """
        }
    },

    # ==================== LOGISTICS DOMAIN ====================
    "logistics_increase_safety_stock": {
        "sms": {
            "content": "📦 LOGISTICS ALERT: Safety stock increased by {impact_amount} days. — TadbeerAI ({timestamp})"
        },
        "email": {
            "subject": "📦 TadbeerAI Alert: Safety Stock Updated",
            "body": """
Dear {user_name},

Safety stock levels have been adjusted:

**Action**: {action_description}
**New Safety Stock**: {impact_amount} days
**Domain**: {domain}
**Timestamp**: {timestamp}

**State Changes**:
{diffs_summary}

**Implementation**:
1. Increase reorder points by {impact_amount} days worth
2. Update warehouse capacity allocations
3. Schedule additional inbound shipments

Best regards,
TadbeerAI Business Intelligence
            """
        }
    },

    # ==================== FINANCE DOMAIN ====================
    "finance_adjust_interest": {
        "sms": {
            "content": "💱 FINANCE ALERT: Interest rate adjusted. Variance: {impact_amount}%. — TadbeerAI ({timestamp})"
        },
        "email": {
            "subject": "💵 TadbeerAI Alert: Interest Rate Adjustment",
            "body": """
Dear {user_name},

Financial adjustments have been executed:

**Action**: {action_description}
**Variance**: {impact_amount}%
**Domain**: {domain}
**Timestamp**: {timestamp}

**State Changes**:
{diffs_summary}

Best regards,
TadbeerAI Business Intelligence
            """
        }
    },

    # ==================== POLICY DOMAIN ====================
    "policy_audit_check": {
        "sms": {
            "content": "⚖️ POLICY ALERT: Compliance updates applied. Cost impact: Rs. {impact_amount}. — TadbeerAI ({timestamp})"
        },
        "email": {
            "subject": "⚖️ TadbeerAI Alert: Regulatory Compliance Update",
            "body": """
Dear {user_name},

A compliance/policy action has been executed:

**Action**: {action_description}
**Compliance Impact**: Rs. {impact_amount}
**Domain**: {domain}
**Timestamp**: {timestamp}

**State Changes**:
{diffs_summary}

Best regards,
TadbeerAI Business Intelligence
            """
        }
    },

    # ==================== TRADE DOMAIN ====================
    "trade_adjust_tariff": {
        "sms": {
            "content": "🚢 TRADE ALERT: Tariffs/duties adjusted. Impact: Rs. {impact_amount}. — TadbeerAI ({timestamp})"
        },
        "email": {
            "subject": "🚢 TadbeerAI Alert: Trade & Tariff Adjustments",
            "body": """
Dear {user_name},

Trade action executed:

**Action**: {action_description}
**Tariff/Export Impact**: Rs. {impact_amount}
**Domain**: {domain}
**Timestamp**: {timestamp}

**State Changes**:
{diffs_summary}

Best regards,
TadbeerAI Business Intelligence
            """
        }
    },

    # ==================== SUPPLY CHAIN DOMAIN ====================
    "supply_chain_optimize": {
        "sms": {
            "content": "⛓️ SUPPLY CHAIN ALERT: Optimization triggered. Delay delta: {impact_amount} days. — TadbeerAI ({timestamp})"
        },
        "email": {
            "subject": "⛓️ TadbeerAI Alert: Supply Chain Optimization",
            "body": """
Dear {user_name},

Supply Chain action executed:

**Action**: {action_description}
**Delay delta**: {impact_amount} days
**Domain**: {domain}
**Timestamp**: {timestamp}

**State Changes**:
{diffs_summary}

Best regards,
TadbeerAI Business Intelligence
            """
        }
    },

    # ==================== GENERIC ACTION (DEFAULT) ====================
    "generic_action": {
        "sms": {
            "content": "⚡ TADBEERAI ALERT: {action_description}. Impact: Rs. {impact_amount}. ({timestamp})"
        },
        "email": {
            "subject": "⚡ TadbeerAI Alert: {domain} Action Executed",
            "body": """
Dear {user_name},

The following business action has been executed:

**Action**: {action_description}
**Domain**: {domain}
**Impact**: Rs. {impact_amount}
**Timestamp**: {timestamp}

**State Changes**:
{diffs_summary}

Review trace logs in TadbeerAI dashboard for full details.

Best regards,
TadbeerAI Business Intelligence
            """
        }
    }
}


def get_template(action_key: str) -> Dict[str, Any]:
    """
    Get notification template for an action.

    Args:
        action_key: Action identifier (e.g., 'energy_increase_delivery_fee')

    Returns:
        Dict with 'sms' and 'email' templates, or generic template if not found
    """
    return NOTIFICATION_TEMPLATES.get(action_key, NOTIFICATION_TEMPLATES["generic_action"])


def format_notification_for_user(
    template_key: str,
    user_name: str,
    action_description: str,
    impact_amount: str,
    domain: str,
    timestamp: str,
    diffs: list[dict] | None = None,
    insight: dict | None = None,
    action_detail: str | None = None,
    sms_draft: str | None = None,
    business_math: str | None = None,
    urgency: str | None = None,
    timeline: str | None = None,
) -> Tuple[str, str, str]:
    """
    Format SMS and email content from template for a specific user.

    Args:
        template_key: Action template key
        user_name: Registered user's display name
        action_description: Human-readable action description
        impact_amount: Quantified impact (e.g., "Rs. 15,000")
        domain: Business domain
        timestamp: ISO format timestamp
        diffs: List of before/after dicts
        insight: Optional insight dict
        action_detail: Optional recommended action instruction/detail
        sms_draft: Optional generated SMS draft text
        business_math: Optional business recovery math
        urgency: Optional urgency level
        timeline: Optional timeline

    Returns:
        (sms_content, email_subject, email_body)
    """
    template = get_template(template_key)

    # Build diffs summary text
    diffs_summary = _build_diffs_text(diffs or [])

    format_vars = {
        "user_name": user_name,
        "action_description": action_description,
        "impact_amount": impact_amount,
        "domain": domain,
        "timestamp": timestamp,
        "diffs_summary": diffs_summary,
    }

    # Format SMS
    sms_content = template["sms"]["content"].format(**format_vars)

    # Format Email
    email_subject = template["email"]["subject"].format(**format_vars)
    email_body = template["email"]["body"].format(**format_vars)

    additional_details = []

    # 1. Insight Section
    if insight:
        title = insight.get("insight_title") or ""
        detail = insight.get("insight_detail") or ""
        additional_details.append("\n### 🚨 TADBEERAI BUSINESS ADVISOR INSIGHT & ANALYSIS")
        if title:
            additional_details.append(f"**Key Business Insight**: {title}")
        if detail:
            additional_details.append(f"**Implications & Context**: {detail}")

        # 2. Impact Section
        impacts = insight.get("impacts")
        if impacts and isinstance(impacts, list):
            additional_details.append("\n**Impact Analysis**:")
            for imp in impacts:
                if isinstance(imp, dict):
                    desc = imp.get("description", "")
                    quant = imp.get("quantified", "")
                    calc = imp.get("calculation_logic", "")
                    sev = imp.get("severity", "medium").lower()

                    sev_emoji = "🔴 High" if sev == "high" else "🟡 Medium" if sev == "medium" else "🟢 Low"

                    impact_line = f"  • [{sev_emoji}] {desc}"
                    if quant:
                        impact_line += f" (Impact: {quant})"
                    additional_details.append(impact_line)
                    if calc:
                        additional_details.append(f"    Calculation: {calc}")

    # 3. Recommended Action Detail Section
    if action_description:
        additional_details.append("\n**Recommended Action Details**:")
        additional_details.append(f"  • **Action**: {action_description}")
        if action_detail:
            additional_details.append(f"  • **Detail**: {action_detail}")
        if business_math:
            additional_details.append(f"  • **Business Math / Savings**: {business_math}")

        urgency_timeline_parts = []
        if urgency:
            urgency_timeline_parts.append(f"Urgency: {urgency.capitalize()}")
        if timeline:
            urgency_timeline_parts.append(f"Timeline: {timeline}")
        if urgency_timeline_parts:
            additional_details.append(f"  • **{', '.join(urgency_timeline_parts)}**")

    # 4. SMS Draft Section
    if sms_draft:
        additional_details.append("\n**Generated Customer/User SMS Draft**:")
        # Indent or wrap the SMS draft
        sms_indented = "\n".join(f"  {line}" for line in sms_draft.split("\n"))
        additional_details.append(sms_indented)

    if additional_details:
        divider = "\n" + "-"*40 + "\n"
        email_body = email_body.strip() + divider + "\n".join(additional_details) + divider

    return sms_content, email_subject, email_body


def _build_diffs_text(diffs: list[dict]) -> str:
    """Build a readable text summary of state diffs."""
    if not diffs:
        return "No state changes recorded."

    lines = []
    for diff in diffs:
        field = diff.get("field", "Unknown")
        before = diff.get("before", "N/A")
        after = diff.get("after", "N/A")
        lines.append(f"  • {field}: {before} → {after}")

    return "\n".join(lines)
