# TadbeerAI Backend — Antigravity Agent Instructions

## Project
Pakistan Business Intelligence Agent Backend
FastAPI + Gemini + RSS feeds → Dynamic insight/action pipeline

## Tech Stack
- Python 3.11, FastAPI, Gemini or Groq (`AI_PROVIDER` + `call_llm_json()`)
- feedparser for RSS, APScheduler for background jobs
- Deploy to Render.com

## Agent Rules
1. NEVER hardcode insights, impacts or actions
2. ALL analysis must use Gemini via call_llm_json()
3. ALL fallbacks must return sensible mock data
4. RSS polling runs every 15 min via APScheduler
5. MockDatabase resets to default on restart
6. Trace log saved to data/trace_log.json after each /analyse

## Code Style
- Type hints on all functions
- Docstrings on all agents
- Print [AgentN] prefix in all agent logs
- Handle ALL exceptions — never crash on bad RSS/LLM response

## Testing
After each change, test:
GET /health → {"status": "ok"}
GET /feed → list of Pakistan news items
POST /analyse {"text": "Petrol increased Rs.15"} → insight + impacts + actions
POST /simulate {"action_index": 0} → before/after diffs
GET /trace → full agent trace array
