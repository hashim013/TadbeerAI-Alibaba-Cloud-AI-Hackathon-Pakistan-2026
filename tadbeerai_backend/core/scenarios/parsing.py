"""Deterministic scenario-parameter parsing — English, Roman Urdu, Urdu.

Pure regex extraction: the LLM is NEVER asked to parse numbers or scenarios.
A message is a scenario only when it states an explicit user assumption (an
amount to save, or a percentage applied to expenses / interest rates).
Qualitative questions ("how could inflation affect me?") parse to ``None``
and keep the Phase 2 impact flow untouched.

Family precedence: rate shock (explicit rate wording + a percentage) →
expense shock (expense wording + a percentage) → save more (an explicit
savings amount). Shock families additionally require a change/hypothesis
signal so statements like "my expenses are 10% of my income" do not fire.
"""

from __future__ import annotations

import re
from decimal import Decimal

from .models import EXPENSE_SHOCK, RATE_SHOCK, SAVE_MORE, ScenarioParameters

_NUMBER = r"(\d+(?:\.\d+)?)"

#: "10%", "10 %", "10 percent" (Urdu ٪ / فیصد are normalized first)
_PERCENT_RE = re.compile(_NUMBER + r"\s*(?:%|percent)")

#: a percentage applies only with a change/hypothesis signal nearby
_CHANGE_WORDS: tuple[str, ...] = (
    "what if", "what happens", "suppose", " if ", "agar",
    "increase", "increases", "increased", "rise", "rises", "rising",
    "go up", "goes up", "going up", "grow", "grows",
    "decrease", "decreases", "decreased", "reduce", "reduced", "reduction",
    "cut", "cutting", "fall", "falls", "fell", "drop", "drops",
    "lower", "lowered", "higher",
    "barh", "barhte", "barh gay", "zyada", "kam", "jaye", "jayein",
    "اگر", "اضافہ", "بڑھ", "کم", "زیادہ",
)

#: words that flip a shock percentage to negative (a decrease)
_DECREASE_WORDS: tuple[str, ...] = (
    "decrease", "decreases", "decreased", "reduce", "reduced", "reduction",
    "cut", "cutting", "fall", "falls", "fell", "drop", "drops",
    "lower", "lowered", "less", "kam", "کم",
)

_EXPENSE_WORDS: tuple[str, ...] = (
    "expense", "expenses", "kharcha", "kharche", "kharchay",
    "grocery", "groceries", "food", "ration", "rasan", "sabzi", "daal",
    "مصارف", "اخراجات", "راشن",
)

#: interest/policy/KIBOR wording (plural "rates" only, so "inflation rate"
#: statements about a level are not mistaken for a rate-shock request)
_RATE_WORDS_RE = re.compile(
    r"\b(?:interest|policy\s+rate|kibor|rates)\b|شرح\s*سود",
    re.IGNORECASE,
)

#: "food expenses rise by 5000", "expenses increase by 5000", "kharcha 5000 barh jaye"
_EXPENSE_AMOUNT_RE = re.compile(
    r"(?:(?:expense|expenses|kharcha|food|grocery|ration)[^0-9]{0,25}?(?:rise|rises|increase|increases|go up|barh|barhte)[^0-9]{0,20}?(\d+(?:\.\d+)?))|"
    r"(?:(?:rise|rises|increase|increases|barh)[^0-9]{0,20}?(?:by\s+)?(\d+(?:\.\d+)?)[^0-9]{0,20}?(?:expense|expenses|kharcha|food|grocery|ration))"
)

#: "save 5000", "saving pkr 5000", "cut my spending by 3000" (Phase 2 parity)
_SAVE_VERB_RE = re.compile(
    r"(?:save|saving|savings|bachat|بچت|spend(?:ing)?\s+(?:less|kam)|cut|reduce)"
    r"[^0-9]{0,20}?(\d+(?:\.\d+)?)"
)

#: "5000 more", "5000 extra", "5000 zyada" (Phase 2 parity + Roman/Urdu)
_NUMBER_MORE_RE = re.compile(
    r"(\d+(?:\.\d+)?)\s*(?:more|extra|additional|zyada|زیادہ)"
)

#: Urdu-script save phrasing: "5000 روپے زیادہ بچت"
_URDU_SAVE_RE = re.compile(
    r"(\d+(?:\.\d+)?)\s*(?:rupees?|rs\.?|pkr|روپے)?\s*(?:zyada|زیادہ)\s*"
    r"(?:save|saving|savings|bachat|بچت|karun|karo|karna)?"
)

#: "for 12 months", "12 months", "6 mahine"
_MONTHS_RE = re.compile(
    r"(?:for\s+)?(\d{1,3})\s*(?:months?|mahine|mahinay)",
    re.IGNORECASE,
)


def normalize_message(message: str) -> str:
    """Lowercase, comma-free text with Urdu percent markers normalized."""
    text = (message or "").lower().replace(",", "")
    return text.replace("٪", "%").replace("فیصد", " percent ")


def extract_save_amount(text: str) -> Decimal | None:
    """Monthly savings increase stated in ``text`` (already normalized)."""
    for pattern in (_SAVE_VERB_RE, _NUMBER_MORE_RE, _URDU_SAVE_RE):
        match = pattern.search(text)
        if match:
            return Decimal(match.group(1))
    return None


def _extract_months(text: str) -> int | None:
    match = _MONTHS_RE.search(text)
    return int(match.group(1)) if match else None


def _signed(pct: Decimal, text: str, pct_start: int, pct_end: int) -> Decimal:
    """Flip the percentage negative when a decrease is stated.

    Direction words are honoured only just before the percentage or right
    after it ("expenses 10% kam") — a distant "less savings" cannot flip
    the sign of an otherwise explicit increase.
    """
    before = text[max(0, pct_start - 40):pct_start]
    after = text[pct_end:pct_end + 12]
    if any(word in before for word in _DECREASE_WORDS) or any(
        word in after for word in _DECREASE_WORDS
    ):
        return -pct
    return pct


def extract_scenario_parameters(message: str) -> ScenarioParameters | None:
    """Parse a user message into scenario parameters, or ``None``.

    Deterministic by design — the same message always yields the same
    parameters. Unknown/unquantified questions return ``None``.
    """
    text = normalize_message(message)
    padded = f" {text} "
    pct_match = _PERCENT_RE.search(text)
    pct = Decimal(pct_match.group(1)) if pct_match else None
    has_change = any(word in padded for word in _CHANGE_WORDS)

    if pct is not None and has_change:
        sign = _signed(pct, text, pct_match.start(), pct_match.end())
        if _RATE_WORDS_RE.search(text):
            return ScenarioParameters(RATE_SHOCK, pct_change=sign)
        if any(word in text for word in _EXPENSE_WORDS):
            return ScenarioParameters(EXPENSE_SHOCK, pct_change=sign)

    exp_amt_match = _EXPENSE_AMOUNT_RE.search(text)
    if exp_amt_match:
        val = exp_amt_match.group(1) or exp_amt_match.group(2)
        if val:
            return ScenarioParameters(EXPENSE_SHOCK, amount_pkr=Decimal(val))

    amount = extract_save_amount(text)
    if amount is not None:
        return ScenarioParameters(
            SAVE_MORE, amount_pkr=amount, months=_extract_months(text)
        )
    return None
