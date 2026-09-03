from core.fallbacks import fallback_insight
from core.llm_client import call_llm_json, normalize_confidence

INSIGHT_SYSTEM_PROMPT = """
You are a Pakistan Business Intelligence Agent for TadbeerAI.

Your job is to extract a specific business insight that is DIRECTLY and EXACTLY related to the provided news text.
DO NOT make up facts or hallucinate trends not mentioned in the news.
DO NOT produce generic industry advice or high-level generic summaries.
DO produce: specific signal, magnitude, trend, and domain relevance for Pakistan businesses directly based on the news events.

Focus on domains: Energy, Currency, Stock Market, Gold, Logistics, Finance, Policy, Trade, Supply Chain.
Always quantify when possible: mention Rs. amounts, percentages, time periods exactly as reported in the news.

CRITICAL: The insight must be strictly derived from the facts and figures of the provided news text, explaining the immediate business implication of that specific event.
"""


def extract_insight(ingested: dict, domain: str, user_profile: dict = None, language: str = "en") -> dict:
    """
    Agent 3: Insight Extractor
    Uses Gemini/Groq to extract specific business signal exactly from news content.
    """
    text = ingested["normalized_text"][:2000]
    entities = ingested["entities"]

    lang_rule = ""
    if language == "ur":
        lang_rule = "\nCRITICAL LANGUAGE RULE: You MUST write the values for 'insight_title', 'insight_detail', and 'confidence_reason' in Urdu script (Urdu language)."
    elif language == "roman_ur":
        lang_rule = "\nCRITICAL LANGUAGE RULE: You MUST write the values for 'insight_title', 'insight_detail', and 'confidence_reason' in Roman Urdu (Urdu written in Latin/English alphabets, e.g. 'petrol ki qeemat Rs.15 barh gayi hai')."
    else:
        lang_rule = "\nCRITICAL LANGUAGE RULE: You MUST write the values for 'insight_title', 'insight_detail', and 'confidence_reason' in English."

    profile_info = ""
    if user_profile:
        category = user_profile.get("category", "")
        city = user_profile.get("city", "")
        profile_info = f"\nUser Category/Persona: {category}\nUser Location: {city}\n"
        if category == "employee":
            profile_info += "Analyze how this news specifically affects employees, salaried workers, or jobs in Pakistan. Emphasize impacts on salary, jobs, commuting, or daily costs.\n"
        elif category == "shop":
            profile_info += "Analyze how this news specifically affects retail shop owners, small merchants, or storefronts in Pakistan. Emphasize impacts on retail prices, stock inventory, local customer traffic, or utility costs.\n"
        elif category == "business":
            profile_info += "Analyze how this news specifically affects business owners, manufacturers, SMEs, or industry corporations. Emphasize impacts on production costs, imports/exports, taxes, or B2B sales.\n"
        elif category == "student":
            profile_info += "Analyze how this news specifically affects students, cost of education, student transport, or daily personal student budgets in Pakistan.\n"
        profile_info += "Tailor the 'insight_detail' and emphasis of 'insight_title' to highlight factors relevant to this user category.\n"
    else:
        profile_info = "\nAnalyze news and implications in Pakistan.\n"

    prompt = f"""
Analyze this Pakistan business news and extract a specific, actionable insight that is EXACTLY and DIRECTLY related to this news.

DOMAIN: {domain}
KEY ENTITIES FOUND: {', '.join(entities)}
NEWS TEXT:
{text}

{profile_info}

{lang_rule}

Respond with JSON in exactly this format:
{{
  "insight_title": "One clear sentence stating exactly what changed in the news and by how much",
  "insight_detail": "2-3 sentences explaining the immediate business implications, context, and trend directly tied to the facts of this news article",
  "confidence": 0.88,
  "confidence_reason": "Explain why this confidence score: mention source authority, signal strength, and direct recency of this news",
  "tags": ["tag1", "tag2", "tag3"],
  "is_trivial": false
}}

Rules:
- insight_title and insight_detail MUST be strictly and exactly derived from the provided news text. Do not generalize or suggest unrelated strategies.
- insight_title MUST include specific number/amount exactly as reported in the news (e.g. "Rs.15", "25%", "Rs.295").
- confidence between 0.5 and 0.99 (use decimal 0.88 not 88).
- is_trivial = true only if it's truly generic news with no business impact.
- tags from: Energy, Currency, Stock Market, Gold, Logistics, Finance, Policy, Trade, Supply Chain, Pakistan, OGRA, SBP, PSX.
"""

    result = call_llm_json(prompt, INSIGHT_SYSTEM_PROMPT)

    if not result or not isinstance(result, dict) or result.get("is_trivial"):
        result = fallback_insight(text, domain)

    # Ensure all insight fields are non-null and typed correctly
    sanitized_result = {
        "insight_title": str(result.get("insight_title") or ""),
        "insight_detail": str(result.get("insight_detail") or ""),
        "confidence": normalize_confidence(result.get("confidence")),
        "confidence_reason": str(result.get("confidence_reason") or ""),
        "tags": [str(t) for t in result.get("tags", []) if t] if isinstance(result.get("tags"), list) else [domain],
        "is_trivial": bool(result.get("is_trivial", False)),
    }

    print(
        f"[Agent3] Insight: '{sanitized_result.get('insight_title', '')}' | "
        f"Confidence: {sanitized_result.get('confidence', 0)}"
    )
    return sanitized_result

