"""LLM registry — provider selection, configuration and one controlled fallback.

Reads ``PRIMARY_LLM`` / ``FALLBACK_LLM`` from the environment (falling back to
the legacy ``AI_PROVIDER`` variable when PRIMARY_LLM is absent), builds the
matching providers, and routes every call through at most one fallback attempt.
Agents and services depend on this registry — never on a vendor SDK.
"""

from __future__ import annotations

import os

from .base import (
    GenerationResult,
    LLMError,
    LLMProvider,
    ProviderUnavailableError,
)
from .gemini_provider import GeminiProvider
from .groq_provider import GroqProvider

#: providers supported today; Qwen/Alibaba Cloud joins this tuple later
_SUPPORTED_PROVIDERS: tuple[str, ...] = ("gemini", "groq")
_DEFAULT_PRIMARY = "gemini"


def build_provider(name: str) -> LLMProvider:
    """Create a provider instance by vendor name.

    Raises ``ValueError`` for names that are not implemented (yet).
    """
    if name == "gemini":
        return GeminiProvider()
    if name == "groq":
        return GroqProvider()
    raise ValueError(f"Unsupported LLM provider: {name!r}")


class LLMRegistry:
    """Routes generation calls to a primary provider with one fallback."""

    def __init__(
        self,
        primary: LLMProvider,
        fallback: LLMProvider | None = None,
    ) -> None:
        self._primary = primary
        self._fallback = fallback

    # ------------------------------------------------------------------ #
    # construction
    # ------------------------------------------------------------------ #

    @classmethod
    def from_env(cls) -> "LLMRegistry":
        """Build the registry from environment variables.

        Selection rules:
        * ``PRIMARY_LLM`` wins; the legacy ``AI_PROVIDER`` is honoured when
          ``PRIMARY_LLM`` is not set (backwards compatibility).
        * Unknown / empty values fall back to the ``gemini`` default.
        * ``FALLBACK_LLM`` must differ from the primary; invalid or missing
          values auto-derive the other supported provider.
        """
        primary_name = os.getenv("PRIMARY_LLM", "").strip().lower()
        if not primary_name:
            primary_name = os.getenv("AI_PROVIDER", "").strip().lower()
        if primary_name not in _SUPPORTED_PROVIDERS:
            primary_name = _DEFAULT_PRIMARY

        fallback_name = os.getenv("FALLBACK_LLM", "").strip().lower()
        if fallback_name not in _SUPPORTED_PROVIDERS or fallback_name == primary_name:
            fallback_name = next(
                (n for n in _SUPPORTED_PROVIDERS if n != primary_name), ""
            )

        primary = build_provider(primary_name)
        fallback = build_provider(fallback_name) if fallback_name else None
        return cls(primary=primary, fallback=fallback)

    # ------------------------------------------------------------------ #
    # introspection
    # ------------------------------------------------------------------ #

    @property
    def primary(self) -> LLMProvider:
        return self._primary

    @property
    def fallback(self) -> LLMProvider | None:
        return self._fallback

    @property
    def primary_name(self) -> str:
        return self._primary.name

    @property
    def fallback_name(self) -> str:
        return self._fallback.name if self._fallback else ""

    def any_configured(self) -> bool:
        """True when at least one provider is usable."""
        if self._primary.is_configured():
            return True
        return self._fallback is not None and self._fallback.is_configured()

    # ------------------------------------------------------------------ #
    # generation
    # ------------------------------------------------------------------ #

    def _attempt_order(self) -> list[LLMProvider]:
        """Configured providers in call order (primary first, fallback once)."""
        order: list[LLMProvider] = []
        if self._primary.is_configured():
            order.append(self._primary)
        if (
            self._fallback is not None
            and self._fallback is not self._primary
            and self._fallback.is_configured()
        ):
            order.append(self._fallback)
        return order

    def generate(
        self,
        prompt: str,
        *,
        system: str = "",
        temperature: float = 0.4,
    ) -> GenerationResult:
        """Generate text via the primary provider, falling back at most once.

        Raises the last provider error when every attempt fails, and
        ``ProviderUnavailableError`` when no provider is configured.
        """
        order = self._attempt_order()
        if not order:
            raise ProviderUnavailableError(
                "No LLM provider is configured (set GEMINI_API_KEY or GROQ_API_KEY)"
            )

        last_error: LLMError | None = None
        for provider in order:
            try:
                text = provider.generate(
                    prompt, system=system, temperature=temperature
                )
                return GenerationResult(
                    text=text,
                    provider=provider.name,
                    model=provider.model,
                    used_fallback=provider is not self._primary,
                )
            except LLMError as exc:
                last_error = exc
                print(f"[LLM] provider '{provider.name}' failed: {type(exc).__name__}: {exc}")

        assert last_error is not None  # order was non-empty, so at least one error
        raise last_error

    def generate_structured(self, prompt: str, *, system: str = "") -> dict | list:
        """Ask for JSON and parse the reply, with the same fallback routing."""
        order = self._attempt_order()
        if not order:
            raise ProviderUnavailableError(
                "No LLM provider is configured (set GEMINI_API_KEY or GROQ_API_KEY)"
            )

        last_error: LLMError | None = None
        for provider in order:
            try:
                return provider.generate_structured(prompt, system=system)
            except LLMError as exc:
                last_error = exc
                print(f"[LLM] provider '{provider.name}' failed: {type(exc).__name__}: {exc}")

        assert last_error is not None
        raise last_error


# ---------------------------------------------------------------------- #
# module-level singleton (dependency-injection friendly)
# ---------------------------------------------------------------------- #

_registry: LLMRegistry | None = None


def get_llm_registry() -> LLMRegistry:
    """Return the process-wide registry, building it from env on first use."""
    global _registry
    if _registry is None:
        _registry = LLMRegistry.from_env()
    return _registry


def set_llm_registry(registry: LLMRegistry | None) -> None:
    """Override (or reset with ``None``) the process-wide registry."""
    global _registry
    _registry = registry
