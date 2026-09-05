"""Vendor-neutral LLM provider abstraction for TadbeerAI.

Agents and services depend on :class:`LLMProvider` — never on a specific
vendor SDK. New vendors (e.g. Qwen / Alibaba Cloud) are added later by
implementing this interface and registering them in
``core/llm/registry.py`` — agent business logic stays untouched.
"""

from __future__ import annotations

import json
import re
from abc import ABC, abstractmethod
from dataclasses import dataclass


class LLMError(Exception):
    """Base class for all LLM provider failures."""


class ProviderUnavailableError(LLMError):
    """The provider is not configured (e.g. missing API key)."""


class ProviderAuthError(LLMError):
    """Authentication failed — invalid or revoked API key."""


class ProviderRateLimitError(LLMError):
    """The provider rate-limited the request."""


class ProviderTimeoutError(LLMError):
    """The request timed out."""


class ProviderResponseError(LLMError):
    """The model returned a malformed or empty response."""


@dataclass
class GenerationResult:
    """Outcome of a successful generation, including routing metadata."""

    text: str
    provider: str
    model: str
    used_fallback: bool = False


class LLMProvider(ABC):
    """Contract every TadbeerAI LLM backend must satisfy.

    Implementations wrap exactly one vendor (Gemini, Groq, Qwen, ...) and
    translate vendor-specific failures into the typed errors above so the
    registry can make fallback decisions without knowing vendor details.
    """

    #: short vendor identifier, e.g. "gemini"
    name: str = "abstract"

    @property
    @abstractmethod
    def model(self) -> str:
        """Model identifier used for calls (response metadata only)."""

    @abstractmethod
    def is_configured(self) -> bool:
        """True when this provider has everything it needs to run."""

    @abstractmethod
    def generate(
        self,
        prompt: str,
        *,
        system: str = "",
        temperature: float = 0.4,
    ) -> str:
        """Run a completion and return the assistant text.

        Raises one of the typed provider errors on failure.
        """

    def generate_structured(self, prompt: str, *, system: str = "") -> dict | list:
        """Ask for JSON and parse the reply into a dict or list.

        Subclasses may override to use a native JSON mode; the default
        relies on prompt instructions plus tolerant parsing.
        """
        json_system = (
            (system or "")
            + "\n\nRESPOND ONLY WITH VALID JSON. NO MARKDOWN. "
            + "NO EXPLANATION. NO BACKTICKS."
        )
        raw = self.generate(prompt, system=json_system)
        try:
            return extract_json(raw)
        except (ValueError, json.JSONDecodeError) as exc:
            raise ProviderResponseError(
                f"{self.name} did not return valid JSON"
            ) from exc


_JSON_FENCE_RE = re.compile(r"```(?:json)?\s*(.*?)\s*```", re.DOTALL)


def extract_json(raw: str) -> dict | list:
    """Parse raw model output as JSON, tolerating markdown fences.

    Raises ``json.JSONDecodeError`` when the output is not valid JSON.
    """
    cleaned = raw.strip()
    fenced = _JSON_FENCE_RE.search(cleaned)
    if fenced:
        cleaned = fenced.group(1).strip()
    return json.loads(cleaned)
