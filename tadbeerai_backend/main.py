import json
import os
import time
from contextlib import asynccontextmanager

from apscheduler.schedulers.background import BackgroundScheduler
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, Header
from fastapi.middleware.cors import CORSMiddleware
from typing import Optional


from agents.action_generator import generate_actions
from agents.content_ingestor import ingest_content
from agents.impact_analyzer import analyze_impact
from agents.insight_extractor import extract_insight
from agents.relevance_filter import score_and_filter
from agents.rss_watcher import fetch_all_feeds
from agents.simulation_agent import simulate_action
from core.llm_client import get_ai_provider, normalize_confidence
from core.paths import get_data_dir
from core.schemas import (
    AnalyseRequest,
    SimulateRequest,
    RegisterUserRequest,
    UpdateUserRequest,
    FcmTokenRequest,
)
from core.trace_builder import (
    append_simulation_trace,
    build_analyse_trace,
    build_feed_trace,
)
from core.firestore_client import init_firestore, get_firestore_client
from core.user_registry import get_user_registry
from core.notification_service import get_notification_service

load_dotenv()

DATA_DIR = get_data_dir()
FEED_CACHE = os.path.join(DATA_DIR, "feed_cache.json")
TRACE_LOG = os.path.join(DATA_DIR, "trace_log.json")
POLL_MINUTES = int(os.getenv("POLL_INTERVAL_MINUTES", "15"))

_feed_trace: list[dict] = []

def get_authenticated_user_id(authorization: Optional[str] = Header(None)) -> Optional[str]:
    """Helper to verify ID token and extract user_id (supporting local fallback if Firebase is disabled)."""
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
            
        print(f"[Auth] Firebase verify_id_token failed: {e}. Attempting local JWT decode fallback for development/testing...")
        try:
            import base64
            import json
            parts = id_token.split('.')
            if len(parts) >= 2:
                payload_b64 = parts[1]
                padding = len(payload_b64) % 4
                if padding:
                    payload_b64 += '=' * (4 - padding)
                payload_bytes = base64.urlsafe_b64decode(payload_b64)
                decoded_token = json.loads(payload_bytes.decode('utf-8'))
                user_id = decoded_token.get("uid") or decoded_token.get("user_id") or decoded_token.get("sub")
                if user_id:
                    return user_id
            return id_token
        except Exception:
            raise HTTPException(status_code=401, detail="Invalid authorization token format")

def get_trace_log_path(user_id: Optional[str]) -> str:
    if not user_id:
        user_id = "guest"
    safe_uid = "".join(c for c in user_id if c.isalnum() or c in ("-", "_"))
    if not safe_uid:
        safe_uid = "guest"
    return os.path.join(DATA_DIR, f"trace_log_{safe_uid}.json")

scheduler = BackgroundScheduler()


def refresh_feed() -> list[dict]:
    """Runs Agent 0 + 1 and caches filtered feed."""
    global _feed_trace
    print("[Scheduler] Refreshing RSS feed...")
    os.makedirs(DATA_DIR, exist_ok=True)
    raw = fetch_all_feeds()

    # Load and merge mock news from mock_db/news_feed.json
    try:
        from email.utils import parsedate_to_datetime
        from datetime import datetime
        mock_feed_path = os.path.join(os.path.dirname(__file__), "mock_db", "news_feed.json")
        if os.path.exists(mock_feed_path):
            with open(mock_feed_path, "r", encoding="utf-8") as f:
                mock_data = json.load(f)
                mock_news = mock_data.get("news", [])
                
                formatted_mock_news = []
                for item in mock_news:
                    pub_str = item.get("published", "")
                    try:
                        pub_iso = parsedate_to_datetime(pub_str).isoformat()
                    except Exception:
                        pub_iso = datetime.now().isoformat()
                        
                    formatted_mock_news.append({
                        "id": str(item.get("id")),
                        "title": item.get("title", ""),
                        "url": item.get("link", ""),
                        "source": item.get("source", ""),
                        "preview_text": item.get("summary", "")[:200],
                        "published_at": pub_iso,
                        "image_url": item.get("image_url"),
                        "raw_text": item.get("summary", "") + " " + item.get("title", ""),
                    })
                
                seen_urls = {item["url"] for item in raw}
                merged_count = 0
                for item in formatted_mock_news:
                    if item["url"] not in seen_urls:
                        raw.append(item)
                        seen_urls.add(item["url"])
                        merged_count += 1
                print(f"[Scheduler] Merged {merged_count} articles from news_feed.json")
    except Exception as e:
        print(f"[Scheduler] Failed to load/merge mock news_feed.json: {e}")

    filtered = score_and_filter(raw)
    top_domain = filtered[0]["domain"] if filtered else "none"
    _feed_trace = build_feed_trace(len(raw), len(filtered), top_domain)

    with open(FEED_CACHE, "w") as f:
        json.dump(filtered, f, default=str)

    print(f"[Scheduler] Feed refreshed: {len(filtered)} items")
    return filtered


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Initialize Firestore on startup
    try:
        init_firestore()
        print("[Startup] [OK] Firestore initialized")
    except Exception as e:
        print(f"[Startup] [WARN] Firestore initialization warning: {e}")

    # Reset MockDatabase on startup (Agent Rule 5)
    try:
        from core.mock_db import MockDatabase
        MockDatabase().reset()
        print("[Startup] [OK] MockDatabase reset to default")
    except Exception as e:
        print(f"[Startup] [WARN] MockDatabase reset warning: {e}")
    
    scheduler.add_job(refresh_feed, "interval", minutes=POLL_MINUTES)
    scheduler.start()
    try:
        refresh_feed()
    except Exception as e:
        print(f"[Startup] Feed refresh failed: {e}")
    yield
    scheduler.shutdown(wait=False)


app = FastAPI(title="TadbeerAI API", version="2.0.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


# ==================== CORE ENDPOINTS ====================


@app.get("/")
def root():
    return {
        "app": "TadbeerAI",
        "team": "TADBEERAI",
        "hackathon": "AISeekho2026",
        "version": "2.0.0",
        "endpoints": [
            "/feed", "/analyse", "/simulate", "/trace", "/health",
            "/register", "/users", "/notifications",
        ],
    }


@app.get("/health")
def health():
    firestore = get_firestore_client()
    registry = get_user_registry()
    user_count = len(registry.get_all_users())
    return {
        "status": "ok",
        "team": "TADBEERAI",
        "challenge": "1",
        "ai_provider": get_ai_provider(),
        "firestore": "✅ Connected" if firestore.available else "⚠️ Fallback (Mock)",
        "registered_users": user_count,
    }


@app.get("/feed")
def get_feed(refresh: bool = False, category: Optional[str] = None):
    """GET /feed — Pakistan business news for Flutter FeedScreen (filtered by user category if provided)."""
    cache_exists = os.path.exists(FEED_CACHE)
    should_refresh = refresh or not cache_exists
    items = []

    if cache_exists and not should_refresh:
        # Check file age to auto-expire cache after 10 minutes (600 seconds)
        mtime = os.path.getmtime(FEED_CACHE)
        age_seconds = time.time() - mtime
        if age_seconds > 600:
            should_refresh = True
            print(f"[Feed] Cache is {int(age_seconds)}s old (>600s). Triggering auto-refresh.")

    if not should_refresh:
        try:
            with open(FEED_CACHE) as f:
                items = json.load(f)
            if items:
                print(f"[Feed] Returning {len(items)} cached items")
        except Exception as e:
            print(f"[Feed] Cache read error, will refresh: {e}")
            should_refresh = True

    if should_refresh:
        print("[Feed] Refreshing and scoring feed...")
        items = refresh_feed()

    if category:
        category_lower = category.lower().strip()
        
        KEYWORDS_BY_CATEGORY = {
            "student": [
                "student", "university", "education", "stipend", "school", "college", "scholarship", 
                "youth", "career", "degree", "internship", "tuition", "hnd", "graduat"
            ],
            "business": [
                "business", "company", "corporate", "turnover", "employee", "industry", "export", 
                "import", "tax", "imf", "sbp", "policy", "startup", "finance", "funding", "audit", 
                "securities", "trade"
            ],
            "shop": [
                "shop", "retail", "store", "revenue", "inventory", "sales", "consumer", "price", 
                "delivery", "tax", "importer", "grocer", "supermarket", "pos", "shopkeeper"
            ],
            "employee": [
                "salary", "employee", "job", "wage", "income", "pay", "tax slab", "hiring", 
                "workforce", "allowance", "pension", "bonus", "recruiting", "unemployment"
            ]
        }
        
        CATEGORY_MAP = {
            "shop": "shop",
            "shopkeeper": "shop",
            "shop keeper": "shop",
            "business": "business",
            "business owner": "business",
            "employee": "employee",
            "student": "student"
        }
        
        mapped_cat = CATEGORY_MAP.get(category_lower)
        if mapped_cat:
            kws = KEYWORDS_BY_CATEGORY[mapped_cat]
            filtered = []
            for item in items:
                title_desc = (item.get("title", "") + " " + item.get("preview_text", "")).lower()
                if any(kw in title_desc for kw in kws):
                    filtered.append(item)
            print(f"[Feed] Filtered feed for category '{category}' (mapped: '{mapped_cat}'): {len(filtered)}/{len(items)} items")
            items = filtered

    return items


def _run_analyse(request: AnalyseRequest, user_id: Optional[str] = None) -> dict:
    global _feed_trace
    timings: dict[str, float] = {}

    t0 = time.time()
    ingested = ingest_content(
        text=request.text,
        source_url=request.source_url,
        language=request.language,
    )
    timings["ingest"] = time.time() - t0

    detect_text = request.text or ingested["normalized_text"]
    temp_articles = score_and_filter([{
        "title": detect_text[:100],
        "raw_text": ingested["normalized_text"],
        "id": "temp",
        "url": request.source_url or "",
        "source": "",
        "published_at": "",
        "preview_text": "",
    }])
    domain = temp_articles[0]["domain"] if temp_articles else "Finance"

    t0 = time.time()
    insight = extract_insight(ingested, domain, user_profile=request.user_profile, language=request.language)
    timings["insight"] = time.time() - t0

    t0 = time.time()
    impacts = analyze_impact(insight, domain, ingested["entities"], request.user_profile, language=request.language)
    timings["impact"] = time.time() - t0

    t0 = time.time()
    actions = generate_actions(insight, impacts, domain, user_profile=request.user_profile, language=request.language)
    timings["actions"] = time.time() - t0

    agent_trace = build_analyse_trace(
        ingested, domain, insight, impacts, actions, timings, feed_trace=_feed_trace
    )

    trace_payload = {
        "insight": insight,
        "impacts": impacts,
        "actions": actions,
        "domain": domain,
        "agent_trace": agent_trace,
    }
    os.makedirs(DATA_DIR, exist_ok=True)
    trace_path = get_trace_log_path(user_id)
    with open(trace_path, "w") as f:
        json.dump(trace_payload, f, default=str)

    return {
        "insight": insight.get("insight_title", ""),
        "insight_detail": insight.get("insight_detail", ""),
        "confidence": normalize_confidence(insight.get("confidence", 0.75)),
        "confidence_reason": insight.get("confidence_reason", ""),
        "tags": insight.get("tags", [domain]),
        "impacts": impacts,
        "actions": actions,
        "agent_trace": agent_trace,
        "domain": domain,
    }


@app.post("/analyse")
@app.post("/analyze")
def analyse(request: AnalyseRequest, authorization: Optional[str] = Header(None)):
    """POST /analyse — Agents 2→5 pipeline for Flutter InsightScreen."""
    if not request.text and not request.source_url:
        raise HTTPException(status_code=400, detail="No text or source_url provided")
    try:
        user_id = get_authenticated_user_id(authorization)
        if not user_id and request.user_profile:
            user_id = request.user_profile.get("user_id") or request.user_profile.get("uid")
        return _run_analyse(request, user_id)
    except ValueError as e:
        # User-facing errors from URL scraping (bad URL, empty content, etc.)
        print(f"[Analyse] URL error: {e}")
        raise HTTPException(status_code=422, detail=str(e))
    except Exception as e:
        print(f"[Analyse] Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/simulate")
@app.post("/execute")
def simulate(request: SimulateRequest, authorization: Optional[str] = Header(None)):
    """POST /simulate — Agent 6 real execution for Flutter BeforeAfterScreen."""
    user_id = get_authenticated_user_id(authorization)
    if not user_id:
        user_id = request.user_id
    if not user_id and request.user_profile:
        user_id = request.user_profile.get("user_id") or request.user_profile.get("uid")
        
    trace_path = get_trace_log_path(user_id)
    try:
        with open(trace_path) as f:
            trace_data = json.load(f)
    except Exception:
        trace_data = {
            "insight": {
                "insight_title": "Business development detected",
                "insight_detail": "",
            },
            "actions": [{
                "rank": 1,
                "title": "Review situation",
                "detail": "Monitor development",
                "business_math": "",
                "churn_risk": "",
                "urgency": "medium",
                "timeline": "This week"
            }],
            "domain": "Finance",
            "agent_trace": _feed_trace,
        }

    all_actions = trace_data.get("actions", [])
    idx = min(max(0, request.action_index), len(all_actions) - 1) if all_actions else 0
    ordered_actions = (
        [all_actions[idx]] + [a for i, a in enumerate(all_actions) if i != idx]
        if all_actions
        else []
    )

    insight_dict = trace_data.get("insight", {})
    if "impacts" in trace_data:
        insight_dict["impacts"] = trace_data["impacts"]

    result = simulate_action(
        actions=ordered_actions,
        domain=trace_data.get("domain", "Finance"),
        insight=insight_dict,
        user_id=user_id,
        notify_channels=request.notify_channels,
        user_profile=request.user_profile,
    )

    agent_trace = append_simulation_trace(
        trace_data.get("agent_trace", _feed_trace),
        result,
    )
    trace_data["agent_trace"] = agent_trace
    trace_data["simulation"] = result
    os.makedirs(DATA_DIR, exist_ok=True)
    with open(trace_path, "w") as f:
        json.dump(trace_data, f, default=str)

    result["agent_trace"] = agent_trace
    return result


@app.get("/trace")
def get_trace(authorization: Optional[str] = Header(None)):
    """GET /trace — Flutter expects top-level List[AgentStep]."""
    user_id = get_authenticated_user_id(authorization)
    trace_path = get_trace_log_path(user_id)
    try:
        with open(trace_path) as f:
            data = json.load(f)
        return data.get("agent_trace", [])
    except FileNotFoundError:
        return _feed_trace if _feed_trace else []


# ==================== STATE MANAGEMENT ENDPOINTS ====================


@app.get("/state")
def get_state():
    """GET /state — Get the current business state including FBR and SBR tax rates."""
    try:
        firestore = get_firestore_client()
        state = firestore.get_business_state()
        return state
    except Exception as e:
        print(f"[State] Error fetching state: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/state")
def update_state(updates: dict, authorization: Optional[str] = Header(None)):
    """POST /state — Update the business state directly (e.g. adjust FBR/SBR tax rates)."""
    auth_uid = get_authenticated_user_id(authorization)
    if not auth_uid:
        raise HTTPException(status_code=401, detail="Unauthorized")
    try:
        firestore = get_firestore_client()
        success, err = firestore.update_business_state(updates)
        if err:
            raise HTTPException(status_code=400, detail=err)
        return {"status": "success", "state": firestore.get_business_state()}
    except Exception as e:
        print(f"[State] Error updating state: {e}")
        raise HTTPException(status_code=500, detail=str(e))


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
        user_data = {
            "user_id": user_id,
            "category": request.category,
            "name": request.name,
            "email": request.email,
            "phone": request.phone,
            "fcm_token": request.fcm_token or "",
            "profile_data": request.profile_data or {},
            "created_at": datetime.utcnow().isoformat(),
            "mode": "account" if (request.email or request.phone) else "guest"
        }
        
        # Save to Firestore /users/{user_id}/
        client = get_firestore_client()
        if client.available:
            client.db.collection("users").document(user_id).set(user_data)
            print(f"[Register] Saved user {user_id} to Firestore")
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
            print(f"[Register] Saved user {user_id} to JSON fallback")
            
        return {"success": True, "user_id": user_id}
    except Exception as e:
        print(f"[Register] Error: {e}")
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

    uvicorn.run("main:app", host="0.0.0.0", port=int(os.getenv("PORT", "8000")), reload=True)
