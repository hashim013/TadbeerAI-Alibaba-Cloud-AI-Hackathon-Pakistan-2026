from core.fallbacks import fallback_actions
from core.llm_client import call_llm_json

ACTION_SYSTEM_PROMPT = """
You are a Pakistan Business Action Advisor for TadbeerAI.

Generate REALISTIC, DOMAIN-SPECIFIC, QUANTIFIED action recommendations.
Actions must be executable by a Pakistani business owner TODAY.
Include business math: expected recovery amount, risk percentage, timeline.

Never give vague advice like "monitor the situation" or "review your strategy".
Give specific actions: "Update delivery fee from Rs.150 to Rs.175" not "consider updating fees".
"""


def generate_actions(insight: dict, impacts: list[dict], domain: str, user_profile: dict = None, language: str = "en") -> list[dict]:
    """
    Agent 5: Action Generator
    Uses Gemini to generate ranked, quantified, domain-specific actions.
    """
    impact_lines = [
        i["description"] + ": " + (i.get("quantified") or "unquantified")
        for i in impacts
    ]

    lang_rule = ""
    if language == "ur":
        lang_rule = "\nCRITICAL LANGUAGE RULE: You MUST write the values for 'title', 'detail', and 'business_math' in Urdu script (Urdu language)."
    elif language == "roman_ur":
        lang_rule = "\nCRITICAL LANGUAGE RULE: You MUST write the values for 'title', 'detail', and 'business_math' in Roman Urdu (Urdu written in Latin/English alphabets, e.g. 'Price update karein')."
    else:
        lang_rule = "\nCRITICAL LANGUAGE RULE: You MUST write the values for 'title', 'detail', and 'business_math' in English."

    profile_info = ""
    if user_profile:
        category = user_profile.get("category", "")
        city = user_profile.get("city", "")
        profile_info = f"\nUser Profile: {category} in {city}\n"
        if category == "employee":
            salary_range = user_profile.get("salary_range", "")
            sector = user_profile.get("sector", "")
            profile_info += f"Monthly salary range: {salary_range}, Sector: {sector}\n"
            profile_info += "Generate actions suited for employees (e.g. adjust personal budget, optimize travel routes to save fuel, switch to energy-efficient options, renegotiate transit/subsidies).\n"
        elif category == "shop":
            shop_type = user_profile.get("shop_type", "")
            monthly_revenue = user_profile.get("monthly_revenue", "")
            profile_info += f"Shop type: {shop_type}, Monthly revenue: {monthly_revenue}\n"
            profile_info += "Generate actions suited for retail shop owners (e.g. modify inventory mix, adjust storefront price lists/fees, reduce non-essential shop operating hours, run promotional bundles).\n"
        elif category == "business":
            industry = user_profile.get("industry", "")
            monthly_turnover = user_profile.get("monthly_turnover", "")
            profile_info += f"Industry: {industry}, Turnover: {monthly_turnover}\n"
            profile_info += "Generate actions suited for business owners/SMEs (e.g. hedge currency risk, audit supply chain suppliers, renegotiate corporate billing contracts, adjust client service pricing).\n"
        elif category == "student":
            field_of_study = user_profile.get("field_of_study", "")
            university = user_profile.get("university", "")
            profile_info += f"Field: {field_of_study}, University: {university}\n"
            profile_info += "Generate actions suited for students (e.g. apply for university stipends/subsidies, switch to shared student housing or carpooling, reduce monthly educational/lifestyle expenses, find online/tutoring freelance opportunities).\n"
        profile_info += "Ensure all 3 recommended actions are direct, concrete, and highly customized for the user's specific role category.\n"
    else:
        profile_info = "\nGenerate actions suitable for a Pakistan business/SME context.\n"

    prompt = f"""
Generate 3 specific, actionable recommendations based on:

INSIGHT: {insight.get('insight_title', '')}
IMPACTS: {impact_lines}
DOMAIN: {domain}

{profile_info}

{lang_rule}

Respond with JSON array (ranked by urgency):
[
  {{
    "rank": 1,
    "title": "Short action title (verb + object)",
    "detail": "Specific instruction: what exactly to do, with exact numbers",
    "business_math": "Financial impact: e.g. Recovers Rs.337,500/month OR Saves Rs.X",
    "churn_risk": "8% (estimated customer churn if action taken, or null if N/A)",
    "urgency": "immediate",
    "timeline": "Today | This week | This month"
  }}
]

Rules:
- Action titles must start with a verb: Update, Draft, Flag, Pause, Increase, Reduce, Send, Set (or equivalent meaning in Urdu/Roman Urdu)
- detail must include specific numbers from the insight
- business_math must calculate recovery/saving/cost in Rs. where possible
- rank 1 = most urgent
- Domain context: {domain}
- All actions must make sense for Pakistan market
"""

    result = call_llm_json(prompt, ACTION_SYSTEM_PROMPT)

    if not result or not isinstance(result, list):
        result = fallback_actions(domain, insight.get("insight_detail", ""))

    # Ensure all actions are properly structured with non-null string values
    sanitized_result = []
    for action in (result or []):
        if isinstance(action, dict):
            try:
                rank_val = int(action.get("rank") if action.get("rank") is not None else 1)
            except (ValueError, TypeError):
                rank_val = 1

            sanitized_action = {
                "rank": rank_val,
                "title": str(action.get("title") or ""),
                "detail": str(action.get("detail") or ""),
                "business_math": str(action.get("business_math") if action.get("business_math") is not None else ""),
                "churn_risk": str(action.get("churn_risk") if action.get("churn_risk") is not None else ""),
                "urgency": str(action.get("urgency") or "immediate"),
                "timeline": str(action.get("timeline") or "Today"),
            }
            sanitized_result.append(sanitized_action)

    print(f"[Agent5] Generated and sanitized {len(sanitized_result)} actions for {domain}")
    return sanitized_result
