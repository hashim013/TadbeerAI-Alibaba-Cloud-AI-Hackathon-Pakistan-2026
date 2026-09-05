"""Deterministic routing rules for the Supervisor.

Routing is intentionally rule-based (no LLM): it is fast, free, predictable
and testable, and it keeps working even when every LLM provider is down.
LLM-assisted routing can be layered on later without touching the graph.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field

from core.agents.state import AGENT_ORDER

# --------------------------------------------------------------------------- #
# intent classification (keyword based, deterministic)
# --------------------------------------------------------------------------- #

_INTENT_KEYWORDS: list[tuple[str, tuple[str, ...]]] = [
    (
        "inflation",
        (
            "inflation", "mehngai", "مہنگائی", "price rise", "cost of living",
            "petrol price", "grocery", "groceries", "chicken", "tamatar",
            "tomato", "tomatoes", "onion", "onions", "pyaz", "atta", "wheat",
            "flour", "oil", "ghee", "sugar", "cheeni", "prices", "rates",
            "daal", "pulse", "eggs", "anda", "milk", "doodh", "sabzi",
            "qeemat", "qimat", "قیمت", "راشن", "ration", "essential items",
        ),
    ),
    (
        "savings",
        ("save", "saving", "savings", "bachat", "بچت", "emergency fund"),
    ),
    (
        "currency",
        ("currency", "rupee", "pkr", "dollar", "exchange rate"),
    ),
    (
        "interest_rate",
        ("interest rate", "kibor", "policy rate", "monetary policy"),
    ),
    (
        "budgeting",
        ("budget", "budgeting", "kharcha", "monthly expenses", "spending plan"),
    ),
    (
        "financial_health",
        (
            "financial health",
            "financial score",
            "financial situation",
            "money health",
            "finances overall",
        ),
    ),
    (
        "economic_literacy",
        ("economy", "economic", "gdp", "fiscal", "trade deficit", "imf", "remittance"),
    ),
]

_DEFAULT_INTENT = "financial_literacy"

_ECONOMIC_INTENTS = frozenset(
    {"inflation", "currency", "interest_rate", "economic_literacy"}
)

# --------------------------------------------------------------------------- #
# routing signal patterns
# --------------------------------------------------------------------------- #

# Strong personal signals: possessives almost always mark a personal question.
_PERSONAL_STRONG_RE = re.compile(
    r"\b(my|mine|myself|our|ours|mera|mere|meri|apna|apni|khud)\b",
    re.IGNORECASE,
)

# Weak personal signals: bare pronouns ("tell me a joke") are ambiguous and
# only count as personal when combined with a finance topic keyword.
_PERSONAL_WEAK_RE = re.compile(r"\b(me|i|we)\b", re.IGNORECASE)

_FINANCE_TOPIC_RE = re.compile(
    r"\b(save|savings?|bachat|budget|income|expenses?|spend(?:ing)?|goal|debt|"
    r"loan|salary|earn|money|financ(?:e|ial)|kharcha|bill|rent|insurance)\b",
    re.IGNORECASE,
)

_IMPACT_RE = re.compile(
    r"\b(affect|affects|affected|affecting|impact|impacts|impacted|impacting|"
    r"effect|effects|hurt|harm)\b|mean(?:s)? for",
    re.IGNORECASE,
)

_WHAT_IF_MARKERS: tuple[str, ...] = (
    "what if",
    "what happens",  # also catches "..., what happens?" (status question form)
    "suppose i",
    "agar",  # roman urdu "if" — agar main / agar expenses ...
    "اگر",  # urdu script "if"
    "if i save",
    "if i spend",
    "save more",
    "saved more",
    "spend less",
    "spending less",
    "cut my",
    "reduce my",
    "extra savings",
    "additional savings",
)

_CONCEPT_MARKERS: tuple[str, ...] = (
    "what is",
    "what are",
    "what's",
    "what does",
    "explain",
    "define",
    "meaning of",
    "difference between",
    "tell me about",
    "kya hai",
    "kya hota",
    "kya hote",
    "samjha",
)

_SITUATION_MARKERS: tuple[str, ...] = (
    "financial situation",
    "financial health",
    "my finances",
    "am i doing okay",
    "how am i doing",
    "mera kharcha",
)


def classify_intent(message: str) -> str:
    """Deterministic keyword-based intent classification."""
    text = message.lower()
    for intent, keywords in _INTENT_KEYWORDS:
        if any(keyword in text for keyword in keywords):
            return intent
    return _DEFAULT_INTENT


# --------------------------------------------------------------------------- #
# language handling
# --------------------------------------------------------------------------- #

_LANGUAGE_INSTRUCTIONS: dict[str, str] = {
    "en": "Answer in clear, simple English.",
    "ur": "Answer in Urdu script (اردو).",
    "ur_latn": "Answer in Roman Urdu (Urdu written in Latin letters).",
}


def language_instruction(language: str) -> str:
    """Human-readable instruction for the requested output language."""
    return _LANGUAGE_INSTRUCTIONS.get(language, _LANGUAGE_INSTRUCTIONS["en"])


def normalize_language(language: str | None) -> str:
    """Map free-form language input to ``en`` | ``ur`` | ``ur_latn``."""
    code = (language or "en").strip().lower()
    if code in ("ur_latn", "ur-latn", "urdu_latn", "roman urdu", "roman_urdu"):
        return "ur_latn"
    if code.startswith("ur"):
        return "ur"
    return "en"


_URDU_SCRIPT_RE = re.compile(r"[\u0600-\u06FF]")


def infer_language_from_message(message: str) -> str | None:
    """Detect an explicit language request inside the user message.

    Returns ``None`` when the message does not ask for a specific language,
    letting the request-level language stand. Explicit requests in the
    message always win over the request-level language.
    """
    text = message.lower()
    if "roman urdu" in text or "romanised urdu" in text or "romanized urdu" in text:
        return "ur_latn"
    if _URDU_SCRIPT_RE.search(message):
        return "ur"
    if re.search(r"\bin urdu\b|\burdu script\b|\burdu language\b|\burdu zaban\b", text):
        return "ur"
    if re.search(r"\bin english\b|\benglish mein\b", text):
        return "en"
    return None


# --------------------------------------------------------------------------- #
# routing decision
# --------------------------------------------------------------------------- #


@dataclass(frozen=True)
class RoutingDecision:
    """Outcome of the supervisor's routing rules."""

    intent: str
    agents: list[str] = field(default_factory=list)
    needs_calculation: bool = False


def route_request(message: str, financial_context: dict | None = None) -> RoutingDecision:
    """Pick the minimum useful set of agents for a user message.

    Rules (checked in order):
    1. what-if scenarios            -> personal_finance + risk_impact
    2. personal situation overview  -> personal_finance
    3. personal + impact question   -> economic_intelligence (if topic) +
                                       personal_finance + risk_impact
    4. concept/definition question  -> financial_literacy
    5. other personal finance Q     -> personal_finance (+ econ topic if any)
       (needs a possessive or a finance keyword — bare "tell me a
       joke" style pronouns fall through to the safe default)
    6. economic topic question      -> economic_intelligence
    7. anything else                -> financial_literacy (safe default)
    """
    text = message.lower()
    intent = classify_intent(message)
    has_econ_topic = intent in _ECONOMIC_INTENTS

    has_whatif = any(marker in text for marker in _WHAT_IF_MARKERS)
    has_situation = any(marker in text for marker in _SITUATION_MARKERS)
    has_personal_strong = bool(_PERSONAL_STRONG_RE.search(text))
    has_personal = has_personal_strong or bool(_PERSONAL_WEAK_RE.search(text))
    has_finance_topic = bool(_FINANCE_TOPIC_RE.search(text))
    has_impact = bool(_IMPACT_RE.search(text))
    has_concept = any(marker in text for marker in _CONCEPT_MARKERS)
    # "what is happening" is a status question, not a definition request —
    # let it fall through to the economic-topic route
    if has_concept and ("what is happening" in text or "what's happening" in text):
        has_concept = False

    if has_whatif:
        agents = {"personal_finance", "risk_impact"}
    elif has_situation:
        agents = {"personal_finance"}
    elif has_personal and has_impact:
        agents = {"personal_finance", "risk_impact"}
        if has_econ_topic:
            agents.add("economic_intelligence")
    elif has_concept:
        agents = {"financial_literacy"}
    elif has_personal and (has_personal_strong or has_finance_topic):
        agents = {"personal_finance"}
        if has_econ_topic:
            agents.add("economic_intelligence")
    elif has_econ_topic:
        agents = {"economic_intelligence"}
    else:
        agents = {"financial_literacy"}

    ordered = [name for name in AGENT_ORDER if name in agents]
    needs_calculation = bool(agents & {"personal_finance", "risk_impact"})
    return RoutingDecision(
        intent=intent, agents=ordered, needs_calculation=needs_calculation
    )
