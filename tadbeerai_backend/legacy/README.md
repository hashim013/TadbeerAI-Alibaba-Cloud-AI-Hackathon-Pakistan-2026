# Legacy Archive (first-generation backend)

This folder is an **archive**. Nothing here is imported by the running
application (`main.py`), the current `core/` services, or the test suite. It is
kept only for historical reference and is **not** part of the deployed system.

## What lives here

The original TadbeerAI "business news automation" pipeline (Agents 0-6) and the
modules that only it used:

| Archived item | Former role |
| --- | --- |
| `agents/rss_watcher.py` | Agent 0 — fetched RSS feeds (`feedparser`) |
| `agents/relevance_filter.py` | Agent 1 — keyword scoring / filtering |
| `agents/content_ingestor.py` | Agent 2 — scraped/normalised article text (`beautifulsoup4`) |
| `agents/insight_extractor.py` | Agent 3 — LLM insight extraction |
| `agents/impact_analyzer.py` | Agent 4 — domain impact analysis |
| `agents/action_generator.py` | Agent 5 — recommended business actions |
| `agents/simulation_agent.py` | Agent 6 — before/after business simulation |
| `agents/execution_handlers/` | Per-domain mock "execution" handlers |
| `llm_client.py` | Old single-provider LLM client (superseded by `core/llm/`) |
| `trace_builder.py` | Agent-trace payloads for the old `/analyse` + `/simulate` |
| `rss_sources.py` | RSS feed URLs + domain keyword lists |
| `external_api_client.py` | Stub billing/inventory/analytics API client |
| `execution_rollback.py` | Rollback for the mock execution handlers |
| `fallbacks.py` | Hardcoded fallback insight/impact/action payloads |
| `domain_config.py` | Domain impact formulas for the old pipeline |

These previously backed the removed endpoints `GET /feed`, `POST /analyse`
(`/analyze`), `POST /simulate` (`/execute`), `GET /trace` and `GET|POST /state`,
plus the background RSS scheduler. The Flutter screens they served
(`FeedScreen`, `InsightScreen`, `BeforeAfterScreen`) no longer exist in
`tadbeerai_app/lib/features/`.

## Current architecture (what replaced it)

```
Flutter -> Firebase Auth -> FastAPI /v1 (core/api_v1.py)
  -> AssistantService -> LangGraph (core/agents) -> LLM registry (core/llm: Gemini/Groq)
  -> Economic data (core/economic_data: World Bank live-annual + PBS/SBP)
  -> Deterministic What-If (core/scenarios)
  -> Finance ledger (core/finance_store: Firestore + JSON fallback)
```

## Notes

- Intra-archive imports were rewritten from `core.<module>` to `legacy.<module>`
  for the modules that moved here. References to modules that **remain** in
  `core/` (e.g. `core.firestore_client`, `core.paths`, `core.mock_db`,
  `core.schemas`, `core.notification_service`, `core.user_registry`) are
  intentionally left pointing at `core/`.
- This archive is not maintained and is not covered by tests. Do not import it
  from production code.
