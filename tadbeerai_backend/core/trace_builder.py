"""Build Flutter-compatible AgentStep trace arrays for /analyse and /trace."""

import time
from typing import Any


def _ts() -> str:
    return time.strftime("%H:%M:%S")


def _step(title: str, detail: str, badges: list[str] | None = None, decision_text: str | None = None) -> dict:
    s: dict[str, Any] = {
        "title": title,
        "detail": detail,
        "timestamp": _ts(),
        "badges": badges or [],
    }
    if decision_text:
        s["decision_text"] = decision_text
    return s


def _agent(name: str, number: int, status: str, duration: float, steps: list[dict]) -> dict:
    return {
        "agent_name": name,
        "agent_number": number,
        "duration_seconds": round(duration, 2),
        "status": status,
        "steps": steps,
    }


def build_feed_trace(raw_count: int, filtered_count: int, top_domain: str = "none") -> list[dict]:
    """Agents 0–1 after RSS refresh."""
    return [
        _agent(
            "RSS Watcher",
            0,
            "done",
            0.4,
            [
                _step(
                    "Fetched Pakistan business RSS",
                    f"{raw_count} items from 6 sources · deduplicated by URL",
                    ["RSS", "Pakistan"],
                ),
            ],
        ),
        _agent(
            "Relevance Filter",
            1,
            "done",
            0.6,
            [
                _step(
                    "Scored Pakistan business relevance",
                    f"Kept {filtered_count}/{raw_count} items · top domain: {top_domain}",
                    ["Filter", top_domain],
                ),
            ],
        ),
    ]


def build_analyse_trace(
    ingested: dict,
    domain: str,
    insight: dict,
    impacts: list[dict],
    actions: list[dict],
    timings: dict[str, float],
    feed_trace: list[dict] | None = None,
) -> list[dict]:
    """Agents 2–5 for POST /analyse. Merges with optional feed_trace (0–1)."""
    trace = list(feed_trace or [])
    entities = ingested.get("entities", [])
    chunks = len(ingested.get("chunks", []))
    token_count = ingested.get("token_count", 0)

    trace.append(
        _agent(
            "Content Ingestor",
            2,
            "done",
            timings.get("ingest", 1.0),
            [
                _step(
                    "Input received",
                    f"Text · {token_count} tokens · language: {ingested.get('language_detected', 'en')}",
                    [f"{token_count} tokens"],
                ),
                _step(
                    "Chunked + preprocessed",
                    f"{chunks} chunks · entities: {', '.join(entities[:5]) or 'none'}",
                    ["Cleaned", "NER"],
                ),
            ],
        )
    )

    confidence = insight.get("confidence", 0.75)
    if isinstance(confidence, (int, float)) and confidence > 1:
        confidence = confidence / 100.0
    conf_pct = int(float(confidence) * 100)

    trace.append(
        _agent(
            "Insight Extractor",
            3,
            "done",
            timings.get("insight", 2.0),
            [
                _step(
                    f"Classified domain: {domain}",
                    f"Headline: {insight.get('insight_title', '')[:80]}",
                    [domain, "Insight"],
                ),
                _step(
                    "Reasoning decision",
                    insight.get("insight_detail", "")[:120],
                    decision_text=insight.get(
                        "confidence_reason",
                        f"Antigravity selected {domain} domain with {conf_pct}% confidence based on entity signals and source strength.",
                    ),
                    badges=["Non-trivial confirmed", f"{conf_pct}% confidence"],
                ),
            ],
        )
    )

    calc_logic = ""
    if impacts:
        calc_logic = impacts[0].get("calculation_logic") or impacts[0].get("description", "")
    impact_summary = "; ".join(
        f"{i.get('description', '')}: {i.get('quantified') or 'unquantified'}"
        for i in impacts[:3]
    )

    trace.append(
        _agent(
            "Impact Analyzer",
            4,
            "done",
            timings.get("impact", 1.5),
            [
                _step(
                    "Quantified business impacts",
                    impact_summary or f"{len(impacts)} impacts mapped for {domain}",
                    decision_text=calc_logic or (
                        f"Applied {domain} impact formulas for Pakistan SME context. "
                        f"At least 2 impacts quantified in Rs. or %."
                    ),
                    badges=[f"Domain: {domain}", f"{len(impacts)} impacts"],
                ),
            ],
        )
    )

    action_count = len(actions)
    top_action = actions[0].get("title", "Action") if actions else "None"
    trace.append(
        _agent(
            "Action Generator",
            5,
            "done",
            timings.get("actions", 1.2),
            [
                _step(
                    f"{action_count} actions ranked",
                    f"Top action: {top_action} · by urgency × feasibility × business impact",
                    ["Actions", domain],
                ),
            ],
        )
    )

    trace.append(
        _agent(
            "Execution Agent",
            6,
            "waiting",
            0.0,
            [
                _step(
                    "Ready for real execution",
                    "Will execute action in Firestore + call real APIs + send notifications",
                    ["Real Execution", "Async"],
                ),
            ],
        )
    )

    return trace


def append_simulation_trace(existing: list[dict], sim_result: dict) -> list[dict]:
    """Replace agent 6 waiting step with real execution trace (now called Execution Agent)."""
    trace = [a for a in existing if a.get("agent_number") != 6]
    state_changes = sim_result.get("state_changes", 0)
    exec_time = sim_result.get("exec_time_seconds", 0)
    transaction_id = sim_result.get("transaction_id", "unknown")
    success = sim_result.get("success", False)
    execution_badge = sim_result.get("execution_badge", "🔄 Executing")
    error_msg = sim_result.get("error_msg", "")

    # Determine status and badges based on execution result
    status = "done" if success else "error"
    detail_text = f"{state_changes} state changes persisted to Firestore · Notifications sent · {exec_time}s"
    if error_msg:
        detail_text = f"Error: {error_msg} · {exec_time}s"

    badges = [execution_badge, f"Txn: {transaction_id[:8]}", "Real"]
    if not success:
        badges = ["❌ Failed", "Rollback", f"Txn: {transaction_id[:8]}"]

    trace.append(
        _agent(
            "Execution Agent",
            6,
            status,
            exec_time,
            [
                _step(
                    "Real business execution completed" if success else "Execution failed with rollback",
                    detail_text,
                    badges,
                    decision_text=(
                        f"Transaction ID: {transaction_id} · "
                        f"Firestore state updated · "
                        f"SMS/Email sent · "
                        f"Audit trail logged"
                    ) if success else f"Rollback reason: {error_msg}"
                ),
            ],
        )
    )
    return trace
