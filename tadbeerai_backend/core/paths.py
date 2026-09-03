"""Central data directory for JSON caches (feed, trace, mock DB)."""

import os


def get_data_dir() -> str:
    """
    Writable directory for runtime JSON files.

    - Local dev: ./data
    - App Engine Standard / Cloud Run: default /tmp/... (app dir is not writable)
    - Override anytime: env DATA_DIR=/path
    """
    explicit = os.getenv("DATA_DIR", "").strip()
    if explicit:
        return explicit
    if os.getenv("GAE_ENV") == "standard" or os.getenv("K_SERVICE"):
        return "/tmp/tadbeerai_data"
    return "data"
