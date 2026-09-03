import re
from core.rss_sources import DOMAIN_KEYWORDS


# Words that indicate an article is NOT business news
NON_BUSINESS_SIGNALS = [
    "film", "movie", "cinema", "bollywood", "hollywood", "lollywood",
    "actor", "actress", "celebrity", "drama", "entertainment",
    "cricket", "sports", "football", "match result", "wedding",
    "murder", "killed", "accident", "weather", "heatwave",
    "earthquake", "flood warning", "rain", "prince", "princess",
    "royal", "cannes", "oscar", "grammy", "fashion",
    "recipe", "diet", "fitness", "horoscope",
    "hajj", "umrah", "pilgrimage", "religious", "mosque",
    "temple", "church", "funeral", "obituary",
]

# Compile regex with word boundaries to avoid matching substrings like:
# 'training' (rain), 'factory' (actor), 'skilled' (killed), 'transportation' (sports), etc.
_NON_BUSINESS_REGEX = re.compile(
    r"\b(" + "|".join(re.escape(signal) for signal in NON_BUSINESS_SIGNALS) + r")\b",
    re.IGNORECASE,
)


def score_and_filter(articles: list[dict]) -> list[dict]:
    """
    Agent 1: Relevance Filter
    Scores each article for Pakistan business relevance.
    Assigns domain, urgency, relevance_score.
    Keeps only genuinely business-relevant items.
    """
    scored = []
    pakistan_keywords = [
        "pakistan", "pakistani", "pkr", "rupee", "rs.", "imf", "sbp",
        "ogra", "nepra", "karachi", "lahore", "islamabad", "peshawar",
        "quetta", "rawalpindi", "fbr", "sbr", "tax", "sst", "gst", "secp", "psx", "kse", "cpec"
    ]

    for article in articles:
        title_lower = article["title"].lower()
        text_lower = (article.get("raw_text", "") + " " + article["title"]).lower()

        # Strict Pakistan relevance check
        is_pakistan = any(kw in text_lower for kw in pakistan_keywords)
        if not is_pakistan:
            continue

        # Check for Indian-related topics to filter out
        indian_keywords = ["india", "indian", "modi", "new delhi", "bjp", "hindu", "gandhi", "kashmir", "loc ", "line of control"]
        if any(kw in text_lower for kw in indian_keywords):
            continue

        # Reject non-business articles using word boundary regex to avoid false positives
        if _NON_BUSINESS_REGEX.search(text_lower):
            continue

        best_domain = None
        best_score = 0
        matched_keywords: list[str] = []

        for domain, keywords in DOMAIN_KEYWORDS.items():
            hits = [kw for kw in keywords if kw in text_lower]
            title_hits = [kw for kw in keywords if kw in title_lower]
            # Title hits weighted 3x, body hits 1x; break ties by distinct keyword count
            score = len(hits) + len(title_hits) * 3
            distinct_keywords = len(set(hits + title_hits))
            if score > best_score or (score == best_score and distinct_keywords > len(set(matched_keywords))):
                best_score = score
                best_domain = domain
                matched_keywords = hits + title_hits

        # Require at least 1 domain keyword hit
        if best_score < 1 or best_domain is None:
            continue

        relevance_score = min(best_score / 10.0, 1.0)

        urgency = "low"
        if relevance_score >= 0.7:
            urgency = "high"
        elif relevance_score >= 0.4:
            urgency = "medium"

        critical_keywords = [
            "hike", "increase", "drop", "fall", "crash",
            "shortage", "ban", "crisis", "record", "historic",
        ]
        if any(kw in title_lower for kw in critical_keywords):
            if urgency == "medium":
                urgency = "high"
            elif urgency == "low":
                urgency = "medium"

        scored.append({
            **article,
            "domain": best_domain,
            "urgency": urgency,
            "relevance_score": round(relevance_score, 2),
            "matched_keywords": matched_keywords[:5],
        })

    urgency_order = {"high": 0, "medium": 1, "low": 2}
    scored.sort(key=lambda x: (urgency_order[x["urgency"]], -x["relevance_score"]))

    top = scored[0]["domain"] if scored else "none"
    print(f"[Agent1] Filtered {len(scored)}/{len(articles)} articles. Top domain: {top}")
    return scored[:30]
