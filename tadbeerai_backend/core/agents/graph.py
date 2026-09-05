"""LangGraph graph builder — the Tadbeer AI 2.0 orchestration topology.

::

    START
      -> supervisor                     (deterministic routing)
      -> [ fan-out: relevant specialists run in one superstep ]
      -> deterministic_tools             (financial/impact calculators)
      -> risk_impact                     (only when selected)
      -> response                        (compose final answer)
      -> END

Specialists run in the same superstep (logically parallel); LangGraph
joins them at ``deterministic_tools``. When a specialist fails it records a
limitation instead of crashing the graph — only the composer's total LLM
failure aborts the request.
"""

from __future__ import annotations

from functools import lru_cache

from langgraph.graph import END, START, StateGraph

from .deterministic import deterministic_node
from .economic_intelligence import economic_intelligence_node
from .financial_literacy import financial_literacy_node
from .personal_finance import personal_finance_node
from .response import response_node
from .risk_impact import risk_impact_node
from .state import SPECIALIST_AGENTS, AgentState
from .supervisor import supervisor_node

_FALLBACK_AGENT = "financial_literacy"


def _route_specialists(state: AgentState) -> list[str]:
    """Fan-out edge: run the selected specialists (all but risk_impact)."""
    selected = state.get("selected_agents") or []
    specialists = [name for name in selected if name in SPECIALIST_AGENTS]
    return specialists or [_FALLBACK_AGENT]


def _route_after_tools(state: AgentState) -> str:
    """Continue to risk_impact when selected, otherwise straight to the composer."""
    selected = state.get("selected_agents") or []
    return "risk_impact" if "risk_impact" in selected else "response"


def build_assistant_graph():
    """Compile the multi-agent assistant graph (provider-agnostic)."""
    graph = StateGraph(AgentState)

    graph.add_node("supervisor", supervisor_node)
    graph.add_node("economic_intelligence", economic_intelligence_node)
    graph.add_node("personal_finance", personal_finance_node)
    graph.add_node("financial_literacy", financial_literacy_node)
    graph.add_node("deterministic_tools", deterministic_node)
    graph.add_node("risk_impact", risk_impact_node)
    graph.add_node("response", response_node)

    graph.add_edge(START, "supervisor")
    graph.add_conditional_edges(
        "supervisor",
        _route_specialists,
        list(SPECIALIST_AGENTS),
    )
    for specialist in SPECIALIST_AGENTS:
        graph.add_edge(specialist, "deterministic_tools")

    graph.add_conditional_edges(
        "deterministic_tools",
        _route_after_tools,
        ["risk_impact", "response"],
    )
    graph.add_edge("risk_impact", "response")
    graph.add_edge("response", END)

    return graph.compile()


@lru_cache(maxsize=1)
def get_assistant_graph():
    """Process-wide compiled graph (nodes stay provider-agnostic).

    The LLM registry is injected per invocation via ``configurable``.
    """
    return build_assistant_graph()
