from core.domain_config import IMPACT_FORMULAS
from core.fallbacks import fallback_impacts
from core.llm_client import call_llm_json

IMPACT_SYSTEM_PROMPT = """
You are a Pakistan Business Impact Analyst for TadbeerAI.

Calculate QUANTIFIED business impacts. Use real math.
Always express impacts in Pakistani Rupees (Rs.) where possible.
Think about: delivery costs, procurement costs, revenue impact, operational costs.

Domain-specific guidance:
- Energy (fuel): delivery_cost = fuel_increase * litres_per_route * routes_per_day * 30 days
- Currency (rupee): import_cost = rupee_drop_amount * import_volume * buffer_factor
- Gold: procurement_cost = tola_increase * monthly_procurement_volume
- Stock Market: portfolio_impact = portfolio_value * drop_percentage
- Logistics (port): inventory_cost = extra_storage_days * daily_storage_rate
- Finance: loan_cost = loan_amount * rate_change_pct
- Policy: compliance_cost = compliance_cost_fixed + audit_fees
- Trade: export_impact = export_volume * tariff_change_pct
- Supply Chain: delay_impact = stockout_units * unit_price + premium_shipping_cost
"""


def analyze_impact(insight: dict, domain: str, entities: list[str], user_profile: dict = None, language: str = "en") -> list[dict]:
    """
    Agent 4: Impact Analyzer
    Uses Gemini + formulas to calculate quantified business impacts.
    """
    formulas = IMPACT_FORMULAS.get(domain, {})

    lang_rule = ""
    if language == "ur":
        lang_rule = "\nCRITICAL LANGUAGE RULE: You MUST write the values for 'description' and 'calculation_logic' in Urdu script (Urdu language)."
    elif language == "roman_ur":
        lang_rule = "\nCRITICAL LANGUAGE RULE: You MUST write the values for 'description' and 'calculation_logic' in Roman Urdu (Urdu written in Latin/English alphabets, e.g. 'Nuksan Rs. 5000 hoga')."
    else:
        lang_rule = "\nCRITICAL LANGUAGE RULE: You MUST write the values for 'description' and 'calculation_logic' in English."

    profile_info = ""
    if user_profile:
        category = user_profile.get("category", "")
        city = user_profile.get("city", "")
        profile_info = f"User Profile: {category} in {city}\n"
        if category == "employee":
            salary_range = user_profile.get("salary_range", "")
            sector = user_profile.get("sector", "")
            profile_info += f"Monthly salary range: {salary_range}, Sector: {sector}\n"
        elif category == "shop":
            shop_type = user_profile.get("shop_type", "")
            monthly_revenue = user_profile.get("monthly_revenue", "")
            profile_info += f"Shop type: {shop_type}, Monthly revenue: {monthly_revenue}\n"
        elif category == "business":
            industry = user_profile.get("industry", "")
            monthly_turnover = user_profile.get("monthly_turnover", "")
            profile_info += f"Industry: {industry}, Turnover: {monthly_turnover}\n"
        elif category == "student":
            field_of_study = user_profile.get("field_of_study", "")
            university = user_profile.get("university", "")
            profile_info += f"Field: {field_of_study}, University: {university}\n"
        profile_info += "\nAnalyse how this specific news impacts THIS user personally.\nGive impact in Pakistani Rupees relevant to their exact situation.\nBe specific — not generic business advice.\n"
    else:
        profile_info = "Analyse business impact of: local Pakistan business context."

    prompt = f"""
{profile_info}

INSIGHT: {insight.get('insight_title', '')}
DETAIL: {insight.get('insight_detail', '')}
DOMAIN: {domain}
ENTITIES/NUMBERS FOUND: {', '.join(entities)}
CALCULATION PARAMETERS: {formulas}

{lang_rule}

Respond with JSON array of impact objects:
[
  {{
    "description": "Clear description of who is affected and how",
    "quantified": "Rs.X per order / Rs.X per month / X% increase (calculate using the numbers from insight)",
    "severity": "high",
    "calculation_logic": "Show your math: e.g. Rs.15 increase × 5L/route × 150 routes × 30 days = Rs.337,500/month"
  }}
]

Rules:
- Provide 3-4 impacts
- At least 2 must be quantified with Rs. or % amounts
- severity: "high" | "medium" | "low"
- calculation_logic shows the actual math (judges love this)
- Focus on Pakistan SME/business context
- Be specific to the situation.
"""

    result = call_llm_json(prompt, IMPACT_SYSTEM_PROMPT)

    if not result or not isinstance(result, list):
        result = fallback_impacts(domain, insight.get("insight_detail", ""))

    # Ensure all impacts are structured with non-null string values
    sanitized_result = []
    for impact in (result or []):
        if isinstance(impact, dict):
            sanitized_impact = {
                "description": str(impact.get("description") or ""),
                "quantified": str(impact.get("quantified") if impact.get("quantified") is not None else ""),
                "severity": str(impact.get("severity") or "medium"),
                "calculation_logic": str(impact.get("calculation_logic") if impact.get("calculation_logic") is not None else ""),
            }
            sanitized_result.append(sanitized_impact)

    print(f"[Agent4] Generated and sanitized {len(sanitized_result)} impacts for {domain}")
    return sanitized_result
