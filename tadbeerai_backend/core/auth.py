"""Shared Firebase ID-token authentication helper.

Extracted from ``main.py`` so both the legacy endpoints and the versioned
``core/api_v1.py`` router can verify the Flutter app's Firebase ID token
without a circular import.

Usage:
* As a FastAPI dependency: ``user_id: Optional[str] = Depends(get_authenticated_user_id)``
* Called directly with a raw header string (as ``main.py`` does).
"""

from typing import Optional

from fastapi import Header, HTTPException

from core.firestore_client import get_firestore_client


def get_authenticated_user_id(
    authorization: Optional[str] = Header(None),
) -> Optional[str]:
    """Verify the bearer ID token and return the Firebase ``uid``.

    Returns ``None`` when no ``Authorization: Bearer`` header is present. In a
    live environment (Firestore available) an invalid token is a hard 401; in
    local development it falls back to decoding the JWT payload without
    signature verification so tests and offline dev keep working.
    """
    if not authorization or not authorization.startswith("Bearer "):
        return None
    id_token = authorization.split("Bearer ")[1]

    try:
        from firebase_admin import auth

        decoded_token = auth.verify_id_token(id_token)
        return decoded_token["uid"]
    except Exception as e:
        client = get_firestore_client()
        if client.available:
            print(f"[Auth] Firebase verify_id_token failed in live environment: {e}")
            raise HTTPException(status_code=401, detail="Invalid authorization token")

        print(
            f"[Auth] Firebase verify_id_token failed: {e}. "
            "Attempting local JWT decode fallback for development/testing..."
        )
        try:
            import base64
            import json

            parts = id_token.split(".")
            if len(parts) >= 2:
                payload_b64 = parts[1]
                padding = len(payload_b64) % 4
                if padding:
                    payload_b64 += "=" * (4 - padding)
                payload_bytes = base64.urlsafe_b64decode(payload_b64)
                decoded_token = json.loads(payload_bytes.decode("utf-8"))
                user_id = (
                    decoded_token.get("uid")
                    or decoded_token.get("user_id")
                    or decoded_token.get("sub")
                )
                if user_id:
                    return user_id
            return id_token
        except Exception:
            raise HTTPException(
                status_code=401, detail="Invalid authorization token format"
            )
