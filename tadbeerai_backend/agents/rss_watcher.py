import hashlib
from datetime import datetime
from email.utils import parsedate_to_datetime

import feedparser
from bs4 import BeautifulSoup

from core.rss_sources import RSS_FEEDS


import httpx

_USER_AGENT = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
    "AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/125.0.0.0 Safari/537.36"
)


def fetch_all_feeds() -> list[dict]:
    """
    Agent 0: RSS Watcher
    Polls all Pakistan RSS feeds. Returns raw list of articles.
    Deduplicates by URL hash.
    """
    all_items = []
    seen_hashes: set[str] = set()

    headers = {
        "User-Agent": _USER_AGENT,
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    }

    for feed_config in RSS_FEEDS:
        try:
            # Fetch feed content with browser headers to avoid Cloudflare/bot blocks
            response = httpx.get(
                feed_config["url"],
                headers=headers,
                timeout=12,
                follow_redirects=True
            )
            if response.status_code != 200:
                print(f"RSS fetch error for {feed_config['name']}: HTTP {response.status_code}")
                continue

            feed = feedparser.parse(response.content)
            # Parse up to 25 entries per feed for a richer dashboard
            for entry in feed.entries[:25]:
                url_hash = hashlib.md5(entry.get("link", "").encode()).hexdigest()
                if url_hash in seen_hashes:
                    continue
                seen_hashes.add(url_hash)

                all_items.append({
                    "id": url_hash[:8],
                    "title": entry.get("title", ""),
                    "url": entry.get("link", ""),
                    "source": feed_config["source"],
                    "preview_text": _strip_html(entry.get("summary", ""))[:200],
                    "published_at": _parse_date(entry.get("published", "")),
                    "image_url": _extract_image(entry),
                    "raw_text": _strip_html(entry.get("summary", "")),
                })
        except Exception as e:
            print(f"RSS error for {feed_config['name']}: {e}")

    print(f"[Agent0] Fetched {len(all_items)} items from {len(RSS_FEEDS)} sources")
    return all_items


def _strip_html(text: str) -> str:
    if not text:
        return ""
    if "<" in text and ">" in text:
        try:
            return BeautifulSoup(text, "html.parser").get_text(separator=" ").strip()
        except Exception:
            pass
    return text.strip()


def _parse_date(date_str: str) -> str:
    try:
        return parsedate_to_datetime(date_str).isoformat()
    except Exception:
        return datetime.now().isoformat()


def _extract_image(entry) -> str | None:
    if hasattr(entry, "media_content") and entry.media_content:
        return entry.media_content[0].get("url")
    if hasattr(entry, "enclosures") and entry.enclosures:
        return entry.enclosures[0].get("href")
    return None
