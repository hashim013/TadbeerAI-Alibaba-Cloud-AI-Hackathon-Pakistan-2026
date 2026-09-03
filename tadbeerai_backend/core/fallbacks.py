"""
Dynamic fallback content when Gemini API is unavailable.
Extracts actual numbers, percentages, and entities from the news text
to generate contextual (not generic) analysis.
"""

import re
from core.domain_config import IMPACT_FORMULAS


# ==================== TEXT EXTRACTION ====================


def extract_amount(text: str) -> str | None:
    """Extract Rs. amount from text."""
    m = re.search(r"Rs\.?\s*[\d,]+(?:\.\d+)?", text, re.IGNORECASE)
    return m.group(0) if m else None


def extract_number(text: str) -> float | None:
    """Extract the first meaningful number from text (amount, percentage, points)."""
    # Try Rs. amount first
    m = re.search(r"Rs\.?\s*([\d,]+(?:\.\d+)?)", text, re.IGNORECASE)
    if m:
        return float(m.group(1).replace(",", ""))

    # Try percentage
    m = re.search(r"([\d.]+)\s*%", text)
    if m:
        return float(m.group(1))

    # Try points (stock market)
    m = re.search(r"([\d,]+)\s*points?", text, re.IGNORECASE)
    if m:
        return float(m.group(1).replace(",", ""))

    # Try generic number after key signal words
    m = re.search(r"(?:by|of|to|from)\s+([\d,.]+)", text)
    if m:
        return float(m.group(1).replace(",", ""))

    return None


def extract_percentage(text: str) -> float | None:
    """Extract percentage value from text."""
    m = re.search(r"([\d.]+)\s*%", text)
    return float(m.group(1)) if m else None


def extract_direction(text: str) -> str:
    """Detect if the news signals increase or decrease."""
    up_words = ["increase", "rise", "hike", "surge", "jump", "gain", "up", "higher", "soar", "rally"]
    down_words = ["decrease", "fall", "drop", "crash", "decline", "down", "lower", "dip", "plunge", "slump"]

    text_lower = text.lower()
    for w in up_words:
        if w in text_lower:
            return "increase"
    for w in down_words:
        if w in text_lower:
            return "decrease"
    return "change"


def extract_entity(text: str) -> str:
    """Extract the key business entity mentioned."""
    entities = {
        "petrol": "Petrol", "fuel": "Fuel", "diesel": "Diesel", "gas": "Gas", "lng": "LNG",
        "rupee": "PKR", "dollar": "USD", "exchange rate": "Exchange Rate",
        "kse-100": "KSE-100", "psx": "PSX", "stock": "Stock Market",
        "gold": "Gold", "silver": "Silver", "tola": "Gold",
        "interest rate": "Interest Rate", "inflation": "Inflation",
        "tariff": "Tariff", "import": "Imports", "export": "Exports", "textile": "Textiles",
        "supply chain": "Supply Chain", "inventory": "Inventory",
        "fbr": "FBR", "compliance": "Compliance", "audit": "Regulatory Audit",
    }
    text_lower = text.lower()
    for keyword, entity in entities.items():
        if keyword in text_lower:
            return entity
    return "Business"


# ==================== DYNAMIC FALLBACK INSIGHT ====================


def fallback_insight(text: str, domain: str) -> dict:
    """Generate a context-aware insight from the actual news text."""
    amount = extract_amount(text)
    number = extract_number(text)
    pct = extract_percentage(text)
    direction = extract_direction(text)
    entity = extract_entity(text)

    # Build dynamic title using actual extracted values
    if amount and direction != "change":
        title = f"{entity} {direction} detected — {amount}"
    elif pct is not None:
        title = f"{entity} {direction} detected — {pct}%"
    elif number is not None:
        title = f"{entity} {direction} detected — {number:,.0f}"
    else:
        title = f"{entity} {direction} detected in {domain} sector"

    # Build dynamic detail from the text itself
    text_summary = text[:200].strip()
    detail_templates = {
        "Energy": f"{entity} price {direction} directly impacts delivery and logistics costs for Pakistan businesses. {text_summary}",
        "Currency": f"PKR {direction} affects import landed costs and FX exposure. {text_summary}",
        "Stock Market": f"Equity market {direction} signals portfolio risk adjustment needed. {text_summary}",
        "Gold": f"Bullion price {direction} affects procurement and jewellery sector costs. {text_summary}",
        "Logistics": f"Logistics disruption impacts delivery timelines and safety stock. {text_summary}",
        "Finance": f"Monetary/fiscal {direction} affects business borrowing and operational costs. {text_summary}",
        "Policy": f"Regulatory update requires compliance review and cost adjustment. {text_summary}",
        "Trade": f"Trade policy {direction} impacts import/export margins. {text_summary}",
        "Supply Chain": f"Supply chain disruption requires buffer and alternate sourcing. {text_summary}",
    }

    detail = detail_templates.get(domain, f"Business development in {domain}: {text_summary}")

    return {
        "insight_title": title,
        "insight_detail": detail,
        "confidence": 0.72 if number else 0.60,
        "confidence_reason": (
            f"Rule-based extraction: {domain} domain matched. "
            f"{'Quantified signal detected' if number else 'Signal detected without clear magnitude'}. "
            f"Gemini unavailable — using keyword and pattern analysis."
        ),
        "tags": [domain, "Pakistan"],
        "is_trivial": False,
    }


# ==================== DYNAMIC FALLBACK IMPACTS ====================


def fallback_impacts(domain: str, text: str = "") -> list[dict]:
    """Generate context-aware impacts using actual numbers from the news."""
    amount = extract_amount(text) or "Rs.15"
    number = extract_number(text) or 15.0
    pct = extract_percentage(text)
    direction = extract_direction(text)
    entity = extract_entity(text)
    formulas = IMPACT_FORMULAS.get(domain, {})

    # Domain-specific calculations using actual numbers
    if domain == "Energy":
        monthly = number * 5 * 150 * 30  # fuel_increase * litres * routes * days
        return [
            {
                "description": f"Delivery cost {direction} per order due to {entity} {direction}",
                "quantified": f"Rs.{number * 5 / 150:.0f}-{number * 5 / 100:.0f} per order",
                "severity": "high" if number >= 10 else "medium",
                "calculation_logic": f"{amount} {entity} {direction} × 5L/route × 150 routes × 30 days = Rs.{monthly:,.0f}/month",
            },
            {
                "description": f"Monthly logistics cost {direction} for mid-size operations",
                "quantified": f"~Rs.{monthly:,.0f}/month",
                "severity": "high" if monthly > 200000 else "medium",
                "calculation_logic": f"150 routes/day × 5L × Rs.{number:.0f} delta × 30 working days",
            },
        ]

    elif domain == "Currency":
        pct_val = pct or 3.0
        import_exposure = 5000000  # Rs.50L typical
        impact = import_exposure * pct_val / 100
        return [
            {
                "description": f"Import cost buffer required due to {entity} {direction}",
                "quantified": f"+{pct_val}% landed cost",
                "severity": "high" if pct_val >= 3 else "medium",
                "calculation_logic": f"Monthly imports Rs.50L × {pct_val}% buffer = Rs.{impact:,.0f} exposure",
            },
            {
                "description": "Large orders on hold until FX stabilizes",
                "quantified": f"Rs.{impact:,.0f} at risk",
                "severity": "high",
                "calculation_logic": f"FX volatility of {pct_val}% exceeds 2% threshold",
            },
        ]

    elif domain == "Stock Market":
        points = number or 500
        portfolio = 12000000  # Rs.12M
        pct_drop = pct or (points / 900)  # rough KSE scaling
        loss = portfolio * pct_drop / 100
        return [
            {
                "description": f"Portfolio risk from {points:,.0f} point {direction}",
                "quantified": f"-Rs.{loss:,.0f} exposure",
                "severity": "high" if pct_drop >= 3 else "medium",
                "calculation_logic": f"Portfolio Rs.12M × {pct_drop:.1f}% = Rs.{loss:,.0f} drawdown",
            },
            {
                "description": "Stop-loss trigger evaluation needed",
                "quantified": f"{pct_drop:.1f}% drawdown",
                "severity": "high" if pct_drop >= 5 else "medium",
                "calculation_logic": f"{points:,.0f} points ≈ {pct_drop:.1f}% of index",
            },
        ]

    elif domain == "Gold":
        tola_change = number or 2000
        monthly_vol = 50  # tolas
        impact = tola_change * monthly_vol
        return [
            {
                "description": f"Procurement cost {direction} for gold-linked products",
                "quantified": f"Rs.{impact:,.0f}/month",
                "severity": "high" if impact > 50000 else "medium",
                "calculation_logic": f"Rs.{tola_change:,.0f}/tola × {monthly_vol} tolas/month = Rs.{impact:,.0f}",
            },
        ]

    elif domain == "Finance":
        rate_change = pct or number or 1.0
        loan_base = 10000000  # Rs.1Cr
        annual_impact = loan_base * rate_change / 100
        return [
            {
                "description": f"Loan servicing cost {direction} due to {rate_change}% rate shift",
                "quantified": f"Rs.{annual_impact:,.0f}/year",
                "severity": "high" if rate_change >= 1.0 else "medium",
                "calculation_logic": f"Loan base Rs.{loan_base/1000000:.0f}M × {rate_change}% = Rs.{annual_impact:,.0f}/year",
            },
        ]

    elif domain == "Policy":
        compliance_cost = number or 250000
        return [
            {
                "description": f"Compliance cost for {entity} requirement",
                "quantified": f"Rs.{compliance_cost:,.0f}",
                "severity": "high" if compliance_cost > 100000 else "medium",
                "calculation_logic": f"Audit fee + documentation + implementation = Rs.{compliance_cost:,.0f}",
            },
        ]

    elif domain == "Trade":
        pct_val = pct or 10.0
        trade_vol = 3000000  # Rs.30L
        impact = trade_vol * pct_val / 100
        return [
            {
                "description": f"Export/import margin impact from {pct_val}% {entity} {direction}",
                "quantified": f"Rs.{impact:,.0f}/month",
                "severity": "high" if pct_val >= 5 else "medium",
                "calculation_logic": f"Trade volume Rs.{trade_vol/100000:.0f}L × {pct_val}% = Rs.{impact:,.0f}/month",
            },
        ]

    elif domain == "Supply Chain":
        delay_days = number or 14
        daily_cost = 25000
        impact = delay_days * daily_cost
        return [
            {
                "description": f"Supply disruption cost for {delay_days:.0f}-day delay",
                "quantified": f"Rs.{impact:,.0f}",
                "severity": "high" if delay_days >= 7 else "medium",
                "calculation_logic": f"{delay_days:.0f} days × Rs.{daily_cost:,}/day storage/premium = Rs.{impact:,.0f}",
            },
        ]

    elif domain == "Logistics":
        delay_days = number or 14
        return [
            {
                "description": "Safety stock extension required due to port/shipping delays",
                "quantified": f"7 to {7 + delay_days:.0f} days",
                "severity": "high",
                "calculation_logic": f"+{delay_days:.0f} days buffer on logistics delay",
            },
        ]

    return [
        {
            "description": f"Business costs affected by {entity} {direction} in {domain}",
            "quantified": amount or "Under analysis",
            "severity": "medium",
            "calculation_logic": "Quantification pending detailed analysis",
        },
    ]


# ==================== DYNAMIC FALLBACK ACTIONS ====================


def fallback_actions(domain: str, text: str = "") -> list[dict]:
    """Generate context-aware actions using actual numbers from the news."""
    number = extract_number(text) or 15.0
    pct = extract_percentage(text)
    amount = extract_amount(text) or f"Rs.{number:.0f}"
    direction = extract_direction(text)
    entity = extract_entity(text)

    if domain == "Energy":
        fee_increase = max(10, number * 5 / 150)  # Proportional to fuel hike
        return [
            {
                "rank": 1,
                "title": f"Update delivery pricing by Rs.{fee_increase:.0f}",
                "detail": f"Increase delivery fee from Rs.150 to Rs.{150 + fee_increase:.0f} to absorb {amount} {entity} {direction}",
                "business_math": f"Recovers Rs.{fee_increase * 150 * 30:,.0f}/month across 150 daily routes",
                "churn_risk": "8%",
                "urgency": "immediate",
                "timeline": "Today",
            },
            {
                "rank": 2,
                "title": "Draft customer notification about price revision",
                "detail": f"Inform customers about Rs.{fee_increase:.0f} delivery fee adjustment due to {entity} {direction}",
                "business_math": "",
                "churn_risk": "",
                "urgency": "immediate",
                "timeline": "Today",
            },
        ]

    elif domain == "Currency":
        buffer_pct = pct or 15.0
        return [
            {
                "rank": 1,
                "title": f"Raise import cost buffer to {buffer_pct:.0f}%",
                "detail": f"Increase buffer from 0% to {buffer_pct:.0f}% on open POs due to {entity} {direction}",
                "business_math": f"Protects Rs.{50000 * buffer_pct:,.0f} margin exposure",
                "churn_risk": "5%",
                "urgency": "immediate",
                "timeline": "Today",
            },
        ]

    elif domain == "Stock Market":
        points = number or 500
        return [
            {
                "rank": 1,
                "title": f"Activate portfolio hedge after {points:,.0f}-point {direction}",
                "detail": f"Enable hedge flag on equity portfolio to cap downside from {points:,.0f}-point {direction}",
                "business_math": f"Caps max loss at ~Rs.{12000000 * 0.08:,.0f}",
                "churn_risk": "",
                "urgency": "immediate",
                "timeline": "Today",
            },
        ]

    elif domain == "Gold":
        tola_delta = number or 2000
        return [
            {
                "rank": 1,
                "title": f"Hold gold procurement after Rs.{tola_delta:,.0f}/tola {direction}",
                "detail": f"Freeze new POs for gold-linked components until price stabilizes",
                "business_math": f"Avoids Rs.{tola_delta * 50:,.0f} overspend on 50 tolas/month",
                "churn_risk": "",
                "urgency": "immediate",
                "timeline": "This week",
            },
        ]

    elif domain == "Logistics":
        delay = number or 14
        return [
            {
                "rank": 1,
                "title": f"Extend safety stock by {delay:.0f} days",
                "detail": f"Raise days-of-cover from 7 to {7 + delay:.0f} to absorb logistics delay",
                "business_math": f"Prevents ~{delay * 24:.0f} potential stock-outs",
                "churn_risk": "",
                "urgency": "immediate",
                "timeline": "Today",
            },
        ]

    elif domain == "Finance":
        rate = pct or number or 1.0
        return [
            {
                "rank": 1,
                "title": f"Adjust loan buffer by {rate:.1f}%",
                "detail": f"Increase interest buffer setting to account for {rate:.1f}% rate {direction}",
                "business_math": f"Saves Rs.{10000000 * rate / 100:,.0f}/year on Rs.1Cr loan base",
                "churn_risk": "",
                "urgency": "immediate",
                "timeline": "Today",
            },
        ]

    elif domain == "Policy":
        return [
            {
                "rank": 1,
                "title": f"Perform {entity} review",
                "detail": f"Allocate compliance budget and update {entity.lower()} checklist for new requirements",
                "business_math": f"Budget Rs.{number:,.0f} for compliance",
                "churn_risk": "",
                "urgency": "medium",
                "timeline": "This week",
            },
        ]

    elif domain == "Trade":
        tariff_pct = pct or 10.0
        return [
            {
                "rank": 1,
                "title": f"Adjust export buffer by {tariff_pct:.0f}%",
                "detail": f"Increase export price buffer to cover {tariff_pct:.0f}% {entity} {direction}",
                "business_math": f"Recovers Rs.{3000000 * tariff_pct / 100:,.0f}/month",
                "churn_risk": "5%",
                "urgency": "immediate",
                "timeline": "Today",
            },
        ]

    elif domain == "Supply Chain":
        delay = number or 14
        return [
            {
                "rank": 1,
                "title": "Activate alternate supply line",
                "detail": f"Switch to alternate supplier route to mitigate {delay:.0f}-day supply disruption",
                "business_math": f"Saves {delay:.0f} days of production delays",
                "churn_risk": "",
                "urgency": "immediate",
                "timeline": "Today",
            },
        ]

    return [
        {
            "rank": 1,
            "title": f"Review {domain} exposure to {entity} {direction}",
            "detail": f"Assess current business exposure to {amount} {entity} {direction}",
            "business_math": "",
            "churn_risk": "",
            "urgency": "medium",
            "timeline": "This week",
        },
    ]
