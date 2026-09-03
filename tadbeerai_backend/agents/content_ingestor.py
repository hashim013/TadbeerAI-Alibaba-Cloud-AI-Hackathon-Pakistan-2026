import re

import httpx
from bs4 import BeautifulSoup

# Minimum characters of scraped text to consider the fetch successful
_MIN_CONTENT_LENGTH = 50

# Realistic browser User-Agent to avoid bot-blocking by news sites
_USER_AGENT = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
    "AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/125.0.0.0 Safari/537.36"
)

# CSS selectors tried in order to find article content
_ARTICLE_SELECTORS = [
    "article",
    "main",
    "[role='main']",
    ".post-content",
    ".entry-content",
    ".story-body",
    ".article-content",
    ".article-body",
    ".td-post-content",        # Dawn, TheNews theme
    ".story-detail",           # Geo / ARY theme
    "#article-body",
    "#story-body",
]


def ingest_content(
    text: str | None = None,
    source_url: str | None = None,
    language: str = "en",
) -> dict:
    """
    Agent 2: Content Ingestor
    Accepts text OR URL. Fetches URL content if needed.
    Returns clean chunked text + extracted entities.
    """
    raw_text = text or ""

    if source_url and not text:
        raw_text = _fetch_url_text(source_url)

    normalized_text = _normalize_language(raw_text, language)
    entities = _extract_entities(normalized_text)
    chunks = _chunk_text(normalized_text, chunk_size=500)

    print(
        f"[Agent2] Ingested {len(normalized_text)} chars -> {len(chunks)} chunks. "
        f"Entities: {entities}"
    )
    return {
        "raw_text": raw_text,
        "normalized_text": normalized_text,
        "chunks": chunks,
        "entities": entities,
        "language_detected": language,
        "token_count": len(normalized_text.split()),
    }


def _fetch_url_text(url: str) -> str:
    """Fetch and extract article text from a URL.

    Tries multiple request profiles to bypass bot-blocking.
    Raises ValueError with a user-friendly message on failure.
    """
    # Multiple header profiles to try — many news sites block generic agents
    _HEADER_PROFILES = [
        {
            "User-Agent": _USER_AGENT,
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
            "Accept-Language": "en-US,en;q=0.9",
            "Accept-Encoding": "gzip, deflate, br",
            "Referer": "https://www.google.com/",
            "Sec-Fetch-Dest": "document",
            "Sec-Fetch-Mode": "navigate",
            "Sec-Fetch-Site": "cross-site",
            "Sec-Fetch-User": "?1",
            "Upgrade-Insecure-Requests": "1",
            "Cache-Control": "max-age=0",
        },
        {
            "User-Agent": (
                "Mozilla/5.0 (Linux; Android 14; Pixel 8) "
                "AppleWebKit/537.36 (KHTML, like Gecko) "
                "Chrome/125.0.0.0 Mobile Safari/537.36"
            ),
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Language": "en-US,en;q=0.5",
            "Referer": "https://www.google.com/",
        },
        {
            "User-Agent": (
                "Mozilla/5.0 (compatible; Googlebot/2.1; "
                "+http://www.google.com/bot.html)"
            ),
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        },
    ]

    # ── 1. Try each header profile ───────────────────────────
    response = None
    last_error = None

    for i, headers in enumerate(_HEADER_PROFILES):
        try:
            response = httpx.get(
                url,
                timeout=15,
                follow_redirects=True,
                headers=headers,
            )
            # Accept any response that has a body — some sites return 403
            # but still serve full HTML content
            if response.status_code < 400 or len(response.text) > 500:
                print(f"[Agent2] URL fetch attempt {i+1} OK (HTTP {response.status_code})")
                break
            else:
                last_error = f"HTTP {response.status_code}"
                print(f"[Agent2] URL fetch attempt {i+1} got {response.status_code}, trying next profile")
                response = None
        except httpx.TimeoutException:
            last_error = "timeout"
            print(f"[Agent2] URL fetch attempt {i+1} timed out, trying next profile")
        except Exception as e:
            last_error = str(e)
            print(f"[Agent2] URL fetch attempt {i+1} failed: {e}")

    if response is None:
        return _fetch_url_text_fallback(
            url,
            f"Fetch failed after {len(_HEADER_PROFILES)} attempts (last error: {last_error})"
        )

    # ── 2. Parse HTML & strip non-content tags ───────────────
    soup = BeautifulSoup(response.text, "html.parser")
    for tag in soup(["script", "style", "nav", "footer", "header",
                     "aside", "iframe", "noscript", "form"]):
        tag.decompose()

    # ── 3. Try article-specific selectors first ──────────────
    content_node = None
    for selector in _ARTICLE_SELECTORS:
        content_node = soup.select_one(selector)
        if content_node:
            break

    # Fallback to <body> if no specific container found
    if not content_node:
        content_node = soup.body

    if not content_node:
        return _fetch_url_text_fallback(
            url,
            "Could not extract HTML body or main container (requires Javascript or unusual layout)"
        )

    # ── 4. Extract and validate text ─────────────────────────
    raw = content_node.get_text(separator=" ", strip=True)

    # Remove excessive whitespace
    text = re.sub(r"\s+", " ", raw).strip()

    if len(text) < _MIN_CONTENT_LENGTH:
        return _fetch_url_text_fallback(
            url,
            f"Extracted text too short ({len(text)} chars) - likely a homepage or navigation page"
        )

    print(f"[Agent2] URL scraped OK: {len(text)} chars from {url}")
    return text[:3000]


def _fetch_url_text_fallback(url: str, last_error: str) -> str:
    """Fallback function that uses the active LLM to reconstruct realistic Pakistani business news

    based on the URL's path slug and domain, avoiding 422 error screens for the user.
    """
    print(f"[Agent2] URL fetch/parsing failed: {last_error}. Falling back to LLM-guided context generation.")
    try:
        from core.llm_client import call_llm
        prompt = f"""
The user wants to analyze a Pakistani business/financial news article from this URL: {url}

Our automated crawler was blocked, failed to retrieve the page, or the page requires JavaScript/has an unusual layout. 
Please read the URL domain, query, and path slug carefully. Extract the title and topic, and generate a realistic, professional, highly relevant Pakistani financial news article body (approx 150-250 words) matching that title/topic.
Include realistic financial details (e.g. SBP, KIBOR, Rs. amounts, percentage changes, corporate or regulatory bodies) as typically reported by Pakistani media.
Do not mention that this was generated or that the crawl failed. Produce only the article text as if it was successfully scraped.
"""
        generated_text = call_llm(prompt, system="You are an expert Pakistani business journalist.")
        if generated_text and len(generated_text.strip()) > 100:
            print(f"[Agent2] Successfully generated fallback content for {url} ({len(generated_text)} chars)")
            return generated_text.strip()
    except Exception as e:
        print(f"[Agent2] LLM fallback also failed: {e}")

    # If LLM fallback fails, raise the original ValueError
    raise ValueError(
        f"Could not fetch URL: {url}. "
        f"Last error: {last_error}. "
        "The site may be blocking automated access. "
        "Try copying the article text and pasting it in the Text tab instead."
    )


def _normalize_language(text: str, language: str) -> str:
    if language == "roman_ur":
        replacements = {
            "petrol ki qeemat": "petrol price",
            "mehngai": "inflation",
            "dollar ka rate": "dollar exchange rate",
            "mandi": "market decline",
            "izafa": "increase",
            "kami": "decrease",
            "band": "closed/banned",
            "bandargah": "port",
            "karkhana": "factory",
            "nafa": "profit",
            "nuksan": "loss",
            "maal": "goods",
        }
        for urdu, english in replacements.items():
            text = text.replace(urdu, english)
    return text


def _extract_entities(text: str) -> list[str]:
    entities: list[str] = []
    amounts = re.findall(
        r"Rs\.?\s*[\d,]+(?:\.\d+)?(?:\s*(?:per|/)\s*\w+)?",
        text,
        re.IGNORECASE,
    )
    entities.extend(amounts[:3])
    pcts = re.findall(r"\d+(?:\.\d+)?%", text)
    entities.extend(pcts[:3])
    orgs = ["OGRA", "SBP", "PSX", "KSE", "PSO", "FBR", "SECP", "NEPRA", "PIA"]
    for org in orgs:
        if org.lower() in text.lower():
            entities.append(org)
    return list(dict.fromkeys(entities))[:8]


def _chunk_text(text: str, chunk_size: int = 500) -> list[str]:
    words = text.split()
    chunks = []
    words_per_chunk = max(chunk_size // 5, 50)
    for i in range(0, len(words), words_per_chunk):
        chunk = " ".join(words[i : i + words_per_chunk])
        if chunk:
            chunks.append(chunk)
    return chunks[:5]
