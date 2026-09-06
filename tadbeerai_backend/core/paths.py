"""Central data directory for JSON caches (feed, trace, mock DB)."""

import os


def get_data_dir() -> str:
    """
    Writable directory for runtime JSON files.

    - Local dev: ./data
    - Vercel (serverless): /tmp/... — the app dir is read-only, and /tmp is
      ephemeral per invocation, which is fine for the feed cache; the finance
      ledger and users live in Firestore, so nothing important is lost between
      invocations.
    - Override anytime: env DATA_DIR=/path
    """
    explicit = os.getenv("DATA_DIR", "").strip()
    if explicit:
        return explicit
    if os.getenv("VERCEL") or os.getenv("VERCEL_ENV"):
        return "/tmp/tadbeerai_data"
    return "data"
