import os
from contextlib import asynccontextmanager

from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, Header
from fastapi.middleware.cors import CORSMiddleware
from typing import Optional

from core.api_v1 import router as v1_router
from core.llm import get_llm_registry
from core.paths import get_data_dir
from core.schemas import (
    RegisterUserRequest,
    UserPersonaRequest,
    UpdateUserRequest,
    FcmTokenRequest,
)
from core.auth import get_authenticated_user_id
from core.firestore_client import init_firestore, get_firestore_client
from core.user_registry import get_user_registry
from core.notification_service import get_notification_service

load_dotenv()

DATA_DIR = get_data_dir()


def get_trace_log_path(user_id: Optional[str]) -> str:
    if not user_id:
        user_id = "guest"
    safe_uid = "".join(c for c in user_id if c.isalnum() or c in ("-", "_"))
    if not safe_uid:
        safe_uid = "guest"
    return os.path.join(DATA_DIR, f"trace_log_{safe_uid}.json")


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Initialize Firestore on startup
    try:
        init_firestore()
        print("[Startup] [OK] Firestore initialized")
    except Exception as e:
        print(f"[Startup] [WARN] Firestore initialization warning: {e}")
    yield


app = FastAPI(title="TadbeerAI API", version="2.0.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# Versioned v1 API (provider-agnostic assistant stack)
app.include_router(v1_router)


# ==================== CORE ENDPOINTS ====================


@app.get("/")
def root():
    return {
        "app": "TadbeerAI",
        "team": "TADBEERAI",
        "hackathon": "AISeekho2026",
        "version": "2.0.0",
        "endpoints": [
            "/health",
            "/v1/health",
            "/v1/assistant/chat",
            "/v1/economy/snapshot",
            "/v1/economy/essential-prices",
            "/v1/finance",
            "/register",
            "/users",
            "/users/persona",
            "/notifications",
        ],
    }


@app.get("/health")
def health():
    firestore = get_firestore_client()
    registry = get_user_registry()
    user_count = len(registry.get_all_users())
    llm_registry = get_llm_registry()
    return {
        "status": "ok",
        "team": "TADBEERAI",
        "challenge": "1",
        "ai_provider": llm_registry.primary_name,
        "firestore": "✅ Connected" if firestore.available else "⚠️ Fallback (Mock)",
        "registered_users": user_count,
    }


# ==================== USER REGISTRATION ENDPOINTS ====================


@app.post("/register")
def register_user(request: RegisterUserRequest, authorization: Optional[str] = Header(None)):
    """POST /register — Save user profile to Firestore /users/{user_id}/."""
    auth_uid = get_authenticated_user_id(authorization)
    if auth_uid and auth_uid != request.user_id:
        raise HTTPException(status_code=403, detail="Forbidden: Cannot register under a different user ID")
    try:
        from datetime import datetime
        user_id = request.user_id
        is_guest = request.is_guest if request.is_guest is not None else (request.mode == "guest" or not (request.email or request.phone))
        mode = "guest" if is_guest else "account"
        eligible_for_alerts = False if is_guest else True

        user_data = {
            "user_id": user_id,
            "category": request.category or "General",
            "name": request.name or ("Guest User" if is_guest else "User"),
            "email": request.email or "",
            "phone": request.phone or "",
            "fcm_token": request.fcm_token or "",
            "profile_data": request.profile_data or {},
            "created_at": datetime.utcnow().isoformat(),
            "mode": mode,
            "is_guest": is_guest,
            "eligible_for_alerts": eligible_for_alerts,
        }

        # Save to Firestore /users/{user_id}/
        client = get_firestore_client()
        if client.available:
            client.db.collection("users").document(user_id).set(user_data)
            print(f"[Register] Saved user {user_id} to Firestore (mode: {mode}, eligible_for_alerts: {eligible_for_alerts})")
        else:
            # Save to local JSON fallback
            registry = get_user_registry()
            users = registry._load_from_json()
            found = False
            for i, u in enumerate(users):
                if u.get("user_id") == user_id:
                    users[i].update(user_data)
                    found = True
                    break
            if not found:
                users.append(user_data)
            registry._write_json(users)
            print(f"[Register] Saved user {user_id} to JSON fallback (mode: {mode}, eligible_for_alerts: {eligible_for_alerts})")

        return {
            "success": True,
            "user_id": user_id,
            "mode": mode,
            "is_guest": is_guest,
            "eligible_for_alerts": eligible_for_alerts,
        }
    except Exception as e:
        print(f"[Register] Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/users/persona")
def save_user_persona(request: UserPersonaRequest, authorization: Optional[str] = Header(None)):
    """POST /users/persona — Save or update user financial persona.

    In guest mode, preferences are recorded locally / marked as guest, and user
    is explicitly NOT eligible for alerts.
    For registered accounts (Email/Password or Google), user is marked eligible for alerts.
    """
    auth_uid = get_authenticated_user_id(authorization)
    if auth_uid and auth_uid != request.user_id:
        raise HTTPException(status_code=403, detail="Forbidden: Cannot update persona for another user")
    try:
        from datetime import datetime
        user_id = request.user_id
        is_guest = bool(request.is_guest or (not request.email and not request.phone))
        mode = "guest" if is_guest else "account"
        eligible_for_alerts = not is_guest

        persona_data = {
            "user_id": user_id,
            "persona": request.persona,
            "primary_goal": request.primary_goal,
            "monthly_income": request.monthly_income,
            "monthly_essential_expenses": request.monthly_essential_expenses,
            "total_savings": request.total_savings,
            "name": request.name or ("Guest User" if is_guest else "User"),
            "email": request.email or "",
            "phone": request.phone or "",
            "is_guest": is_guest,
            "mode": mode,
            "eligible_for_alerts": eligible_for_alerts,
            "updated_at": datetime.utcnow().isoformat(),
        }

        client = get_firestore_client()
        if client.available:
            client.db.collection("users").document(user_id).set(persona_data, merge=True)
            print(f"[Persona] Synced persona for {user_id} (is_guest: {is_guest}, eligible_for_alerts: {eligible_for_alerts})")

        registry = get_user_registry()
        registry.update_user(user_id, persona_data)

        return {
            "status": "success",
            "user_id": user_id,
            "is_guest": is_guest,
            "eligible_for_alerts": eligible_for_alerts,
            "persona": request.persona,
            "message": (
                "Preferences saved locally on device. Alerts are reserved for registered users."
                if is_guest
                else "Persona updated successfully. Real-time alerts activated."
            ),
        }
    except Exception as e:
        print(f"[Persona] Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/users/{user_id}/alerts-eligibility")
def check_alerts_eligibility(user_id: str, authorization: Optional[str] = Header(None)):
    """GET /users/{user_id}/alerts-eligibility — Check whether a user is eligible for real-time alerts."""
    try:
        registry = get_user_registry()
        user = registry.get_user(user_id)
        if not user:
            return {
                "user_id": user_id,
                "is_guest": True,
                "eligible_for_alerts": False,
                "reason": "Guest mode: preferences saved locally on device. Account registration required to receive alerts.",
            }
        is_guest = bool(user.get("is_guest", False) or user.get("mode") == "guest")
        eligible = bool(user.get("eligible_for_alerts", not is_guest) and not is_guest)
        return {
            "user_id": user_id,
            "is_guest": is_guest,
            "eligible_for_alerts": eligible,
            "reason": (
                "Guest mode: preferences saved locally on device. Account registration required to receive alerts."
                if is_guest
                else "Registered account: eligible for real-time market and commodity alerts."
            ),
        }
    except Exception as e:
        print(f"[Alerts Eligibility] Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.delete("/delete-account")
def delete_account(authorization: Optional[str] = Header(None)):
    """DELETE /delete-account — Delete Firestore profile, alerts subcollection, and remove FCM token."""
    user_id = get_authenticated_user_id(authorization)
    if not user_id:
        raise HTTPException(status_code=401, detail="Unauthorized")

    try:
        client = get_firestore_client()
        fcm_token = None

        # 1. Fetch user to retrieve FCM token before deletion
        if client.available:
            doc_ref = client.db.collection("users").document(user_id)
            doc = doc_ref.get()
            if doc.exists:
                fcm_token = doc.to_dict().get("fcm_token")

                # Delete subcollection /users/{user_id}/alerts
                alerts_ref = doc_ref.collection("alerts")
                alert_docs = alerts_ref.stream()
                for alert_doc in alert_docs:
                    alert_doc.reference.delete()

                # Delete the main document
                doc_ref.delete()
                print(f"[Delete Account] Firestore documents deleted for {user_id}")

            # Also clean up from registry (Firestore "registered_users" + JSON fallback)
            registry = get_user_registry()
            if not fcm_token:
                user_data = registry.get_user(user_id)
                if user_data:
                    fcm_token = user_data.get("fcm_token")
            registry.delete_user(user_id)
            print(f"[Delete Account] Registry clean up completed for {user_id}")
        else:
            # Local fallback deletion
            registry = get_user_registry()
            user_data = registry.get_user(user_id)
            if user_data:
                fcm_token = user_data.get("fcm_token")
            registry.delete_user(user_id)
            print(f"[Delete Account] Local JSON user deleted for {user_id}")

        # 2. Remove FCM token from notification groups
        if fcm_token:
            try:
                from firebase_admin import messaging
                messaging.unsubscribe_from_topic([fcm_token], "all")
                print(f"[Delete Account] Unsubscribed FCM token from 'all' topic")
            except Exception as e:
                print(f"[Delete Account] FCM unsubscribe warning (non-fatal): {e}")

        # 3. Clean up user trace file if it exists
        trace_path = get_trace_log_path(user_id)
        if os.path.exists(trace_path):
            try:
                os.remove(trace_path)
                print(f"[Delete Account] Purged trace file: {trace_path}")
            except Exception as e:
                print(f"[Delete Account] Trace purge warning (non-fatal): {e}")

        return {"success": True}
    except Exception as e:
        print(f"[Delete Account] Deletion error: {e}")
        raise HTTPException(status_code=500, detail=str(e))



@app.post("/users/fcm-token")
def update_fcm_token(request: FcmTokenRequest, authorization: Optional[str] = Header(None)):
    """POST /users/fcm-token — Update user's FCM push token."""
    auth_uid = get_authenticated_user_id(authorization)
    if auth_uid and auth_uid != request.user_id:
        raise HTTPException(status_code=403, detail="Forbidden: Cannot update FCM token for another user")
    try:
        registry = get_user_registry()
        user = registry.update_user(request.user_id, {"fcm_token": request.fcm_token})
        print(f"[FCM Token] [OK] Updated FCM token for user: {request.user_id}")
        return {"status": "updated", "user": user}
    except Exception as e:
        print(f"[FCM Token] Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/users")
def list_users(authorization: Optional[str] = Header(None)):
    """GET /users — List all registered users (Admin-only or disabled in live env)."""
    client = get_firestore_client()
    if client.available:
        raise HTTPException(status_code=403, detail="Forbidden: Listing all users is disabled in production")
    try:
        registry = get_user_registry()
        users = registry.get_all_users()
        return {"count": len(users), "users": users}
    except Exception as e:
        print(f"[Users] Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/users/{user_id}")
def get_user(user_id: str, authorization: Optional[str] = Header(None)):
    """GET /users/{user_id} — Get a single user."""
    auth_uid = get_authenticated_user_id(authorization)
    if auth_uid and auth_uid != user_id:
        raise HTTPException(status_code=403, detail="Forbidden: You can only access your own profile")
    try:
        registry = get_user_registry()
        user = registry.get_user(user_id)
        if not user:
            raise HTTPException(status_code=404, detail=f"User {user_id} not found")
        return user
    except HTTPException:
        raise
    except Exception as e:
        print(f"[Users] Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.put("/users/{user_id}")
def update_user(user_id: str, request: UpdateUserRequest, authorization: Optional[str] = Header(None)):
    """PUT /users/{user_id} — Update user notification preferences."""
    auth_uid = get_authenticated_user_id(authorization)
    if auth_uid and auth_uid != user_id:
        raise HTTPException(status_code=403, detail="Forbidden: You can only update your own profile")
    try:
        registry = get_user_registry()
        updates = request.model_dump(exclude_none=True)
        if not updates:
            raise HTTPException(status_code=400, detail="No fields to update")
        user = registry.update_user(user_id, updates)
        print(f"[Users] [OK] Updated user: {user_id}")
        return {"status": "updated", "user": user}
    except HTTPException:
        raise
    except Exception as e:
        print(f"[Users] Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.delete("/users/{user_id}")
def delete_user(user_id: str, authorization: Optional[str] = Header(None)):
    """DELETE /users/{user_id} — Unregister a user."""
    auth_uid = get_authenticated_user_id(authorization)
    if auth_uid and auth_uid != user_id:
        raise HTTPException(status_code=403, detail="Forbidden: You can only delete your own profile")
    try:
        registry = get_user_registry()
        deleted = registry.delete_user(user_id)
        if not deleted:
            raise HTTPException(status_code=404, detail=f"User {user_id} not found")
        print(f"[Users] [OK] Deleted user: {user_id}")
        return {"status": "deleted", "user_id": user_id}
    except HTTPException:
        raise
    except Exception as e:
        print(f"[Users] Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# ==================== NOTIFICATION HISTORY ====================


@app.get("/notifications")
def get_notifications(limit: int = 50, authorization: Optional[str] = Header(None)):
    """GET /notifications — Get notification history log (Admin-only or disabled in live env)."""
    client = get_firestore_client()
    if client.available:
        raise HTTPException(status_code=403, detail="Forbidden: Listing notification history is disabled in production")
    try:
        svc = get_notification_service()
        history = svc.get_notification_history(limit=limit)
        return {"count": len(history), "notifications": history}
    except Exception as e:
        print(f"[Notifications] Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


if __name__ == "__main__":
    import uvicorn

    host = os.getenv("API_HOST", "0.0.0.0")
    port = int(os.getenv("API_PORT", os.getenv("PORT", "8000")))
    uvicorn.run("main:app", host=host, port=port, reload=True)
