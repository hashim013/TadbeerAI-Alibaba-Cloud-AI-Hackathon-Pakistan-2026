# TadbeerAI Backend

FastAPI backend for TadbeerAI — Pakistan business intelligence from RSS + Gemini.

## Setup

```bash
python -m venv .venv
.venv\Scripts\activate   # Windows
pip install -r requirements.txt
```

Create `.env`:

```
GEMINI_API_KEY=your_key_here
GEMINI_MODEL=gemini-2.0-flash
APP_ENV=development
POLL_INTERVAL_MINUTES=15
MAX_FEED_ITEMS=20
```

Ensure the API key allows **Generative Language API** (Google AI Studio). If you see `API_KEY_SERVICE_BLOCKED`, create a new key at [Google AI Studio](https://aistudio.google.com/apikey).

## Verify the backend

1. Start: `uvicorn main:app --host 0.0.0.0 --port 8000`
2. Open **`http://127.0.0.1:8000/docs`** (Swagger UI) and try **`GET /health`**, **`GET /feed`**, **`POST /analyse`**.
3. Or in a terminal: `curl http://127.0.0.1:8000/health`

`GET /health` should return `{"status":"ok",...,"ai_provider":"gemini"}` (or `groq` if `AI_PROVIDER=groq`).

## Deploy to Google Cloud

Step-by-step: **[DEPLOY_GCP.md](DEPLOY_GCP.md)** (App Engine + env vars + Flutter URL).

## Run locally

```bash
uvicorn main:app --reload --port 8000
```

## API

| Method | Path | Description |
|--------|------|-------------|
| GET | `/health` | Health check |
| GET | `/feed` | Ranked Pakistan business news |
| POST | `/analyse` | Insight + impacts + actions (Agents 2-5) |
| POST | `/simulate` | Mock execution of top action (Agent 6) |
| GET | `/trace` | Full agent trace (Flutter `AgentStep[]`) |

Aliases: `/analyze`, `/execute`

## Deploy (Render)

1. Connect GitHub repo
2. Build: `pip install -r requirements.txt`
3. Start: `uvicorn main:app --host 0.0.0.0 --port $PORT`
4. Env: `GEMINI_API_KEY`, optional `GEMINI_MODEL`, `POLL_INTERVAL_MINUTES=15`
5. Optional: use [`render.yaml`](render.yaml) as a blueprint

Team: **TADBEERAI** - AISeekho2026 - Challenge 1

---

## Connect the Flutter app

1. Open **`tadbeerai_app/lib/core/services/api_service.dart`** (or your app’s equivalent).
2. Change **`_base`** to your backend URL (no trailing slash):

| Where you run the API | Example `_base` |
|------------------------|------------------|
| Render / public HTTPS | `https://your-service.onrender.com` |
| Android emulator → PC localhost | `http://10.0.2.2:8000` |
| iOS simulator → Mac localhost | `http://127.0.0.1:8000` |
| Physical phone on same Wi‑Fi | `http://192.168.x.x:8000` (your PC’s LAN IP) |

3. Hot restart the Flutter app. The app calls **`GET /feed`**, **`POST /analyse`**, **`POST /simulate`**, **`GET /trace`** on that base URL.

**Real RSS news:** The server fetches live Pakistan RSS feeds on startup and every `POLL_INTERVAL_MINUTES`. As long as the device can reach your URL and the server has internet, **`/feed`** returns real articles (not mock). If the request fails, the Flutter app falls back to **`MockData.feedItems`**.

## Gemini + Groq

Set in **`.env`** (local) or **Render environment variables** (production):

| Variable | Purpose |
|----------|----------|
| `AI_PROVIDER` | `gemini` (default) or `groq` |
| `GEMINI_API_KEY` | [Google AI Studio](https://aistudio.google.com/apikey) |
| `GEMINI_MODEL` | e.g. `gemini-2.0-flash` |
| `GROQ_API_KEY` | [Groq Console](https://console.groq.com) |
| `GROQ_MODEL` | e.g. `llama-3.3-70b-versatile` |

If the primary provider errors and the other key is set, the backend **automatically tries the other provider** once. Check **`GET /health`** → `ai_provider` shows which is configured as primary.

Copy from **`.env.example`** to **`.env`** and fill keys; never commit **`.env`**.
