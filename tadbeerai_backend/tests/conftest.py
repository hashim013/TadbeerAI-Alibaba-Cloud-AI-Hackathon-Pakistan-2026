"""Shared fixtures — fake LLM providers and an app factory.

Every test in this suite runs against in-memory fakes or monkeypatched SDK
client objects. No test requires real API keys and nothing touches the
network.

Phase 2 additions:
* ``ScriptedAgentProvider`` — routes scripted replies to the multi-agent
  graph by matching the ``[AGENT:<name>]`` / ``[COMPOSER]`` markers in each
  node's system prompt, so tests stay independent of node execution order.
"""

from __future__ import annotations

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from core import api_v1
from core.economic_data import EconomicDataService, set_economic_service
from core.llm import (
    LLMProvider,
    LLMRegistry,
    ProviderResponseError,
    get_llm_registry,
)


@pytest.fixture(autouse=True)
def _hermetic_economic_data():
    """Force the pure-demo economic snapshot for every test.

    The default production service calls the World Bank API; tests must
    never touch the network, so the snapshot is swapped for a service
    with no providers (all indicators fall back to the labelled demo
    values, exactly like Phase 2).
    """
    set_economic_service(EconomicDataService(providers=[]))
    yield
    set_economic_service(None)


class FakeProvider(LLMProvider):
    """Scriptable in-memory provider.

    * ``replies`` — scripted answers, popped in order (one per generate call).
    * ``error`` — raised on every generate call when set.
    * ``configured`` — what :meth:`is_configured` reports.
    * ``name`` — provider identifier used in routing metadata.
    """

    def __init__(
        self,
        replies: list[str] | None = None,
        error: Exception | None = None,
        configured: bool = True,
        name: str = "fake",
    ) -> None:
        self.name = name
        self.replies = list(replies or [])
        self.error = error
        self._configured = configured
        self.calls: list[dict] = []

    @property
    def model(self) -> str:
        return "fake-model"

    def is_configured(self) -> bool:
        return self._configured

    def generate(
        self,
        prompt: str,
        *,
        system: str = "",
        temperature: float = 0.4,
    ) -> str:
        self.calls.append(
            {"prompt": prompt, "system": system, "temperature": temperature}
        )
        if self.error is not None:
            raise self.error
        if not self.replies:
            raise ProviderResponseError("fake provider has no scripted reply")
        return self.replies.pop(0)


#: markers used by the multi-agent system prompts
ECONOMIC_MARKER = "[AGENT:economic_intelligence]"
PERSONAL_FINANCE_MARKER = "[AGENT:personal_finance]"
LITERACY_MARKER = "[AGENT:financial_literacy]"
RISK_IMPACT_MARKER = "[AGENT:risk_impact]"
COMPOSER_MARKER = "[COMPOSER]"


class ScriptedAgentProvider(LLMProvider):
    """Marker-routed scripted provider for the multi-agent graph.

    ``replies_by_marker`` maps a system-prompt marker (e.g.
    ``"[AGENT:risk_impact]"``) to either a scripted reply string or an
    exception to raise for that agent. Calls that match no marker fall
    through to the composer marker and return ``final_answer``.
    """

    def __init__(
        self,
        replies_by_marker: dict[str, str | Exception] | None = None,
        final_answer: str = "Composed final answer.",
        configured: bool = True,
        name: str = "fake",
    ) -> None:
        self.name = name
        self.replies_by_marker = dict(replies_by_marker or {})
        self.final_answer = final_answer
        self._configured = configured
        self.calls: list[dict] = []

    @property
    def model(self) -> str:
        return "fake-model"

    def is_configured(self) -> bool:
        return self._configured

    def generate(
        self,
        prompt: str,
        *,
        system: str = "",
        temperature: float = 0.4,
    ) -> str:
        self.calls.append(
            {"prompt": prompt, "system": system, "temperature": temperature}
        )
        for marker, reply in self.replies_by_marker.items():
            if marker in system:
                if isinstance(reply, Exception):
                    raise reply
                return reply
        if COMPOSER_MARKER in system:
            return self.final_answer
        raise ProviderResponseError(
            f"no script matched system prompt: {system[:60]!r}"
        )


@pytest.fixture
def make_client():
    """Factory building a ``TestClient`` wired to the given fake providers.

    The registry dependency is overridden, so the app under test never reads
    environment variables or builds real providers.
    """

    def _make(
        primary: LLMProvider, fallback: LLMProvider | None = None
    ) -> TestClient:
        registry = LLMRegistry(primary=primary, fallback=fallback)
        app = FastAPI()
        app.include_router(api_v1.router)
        app.dependency_overrides[get_llm_registry] = lambda: registry
        return TestClient(app)

    return _make
