"""Groq provider — wraps the Groq OpenAI-compatible REST API behind LLMProvider.

Uses ``httpx`` directly (same pattern as the legacy ``core/llm_client.py``)
so no additional SDK dependency is required.
"""

from __future__ import annotations

import os

import httpx

from .base import (
    LLMError,
    LLMProvider,
    ProviderAuthError,
    ProviderRateLimitError,
    ProviderResponseError,
    ProviderTimeoutError,
    ProviderUnavailableError,
)

_GROQ_CHAT_URL = "https://api.groq.com/openai/v1/chat/completions"
_DEFAULT_MODEL = "openai/gpt-oss-120b"
_DEFAULT_TIMEOUT_SECONDS = 30.0


class GroqProvider(LLMProvider):
    """Groq Cloud via its OpenAI-compatible chat completions endpoint."""

    name = "groq"

    def __init__(
        self,
        api_key: str | None = None,
        model: str | None = None,
        timeout: float = _DEFAULT_TIMEOUT_SECONDS,
    ) -> None:
        self._api_key = api_key or os.getenv("GROQ_API_KEY", "").strip()
        self._model = model or os.getenv("GROQ_MODEL", "").strip() or _DEFAULT_MODEL
        self._timeout = timeout

    @property
    def model(self) -> str:
        return self._model

    def is_configured(self) -> bool:
        return bool(self._api_key)

    def generate(
        self,
        prompt: str,
        *,
        system: str = "",
        temperature: float = 0.4,
    ) -> str:
        if not self._api_key:
            raise ProviderUnavailableError("Groq API key is not configured")

        messages: list[dict[str, str]] = []
        if system:
            messages.append({"role": "system", "content": system})
        messages.append({"role": "user", "content": prompt})

        try:
            with httpx.Client(timeout=self._timeout) as client:
                response = client.post(
                    _GROQ_CHAT_URL,
                    headers={
                        "Authorization": f"Bearer {self._api_key}",
                        "Content-Type": "application/json",
                    },
                    json={
                        "model": self._model,
                        "messages": messages,
                        "temperature": temperature,
                    },
                )
        except httpx.TimeoutException as exc:
            raise ProviderTimeoutError("Groq request timed out") from exc
        except httpx.HTTPError as exc:  # connection / network failures
            raise LLMError(f"Groq request failed: {exc}") from exc

        if response.status_code == 401:
            raise ProviderAuthError("Groq rejected the API key")
        if response.status_code == 429:
            raise ProviderRateLimitError("Groq rate limit reached")
        if response.status_code >= 400:
            raise LLMError(f"Groq request failed with status {response.status_code}")

        try:
            content = response.json()["choices"][0]["message"]["content"]
        except (KeyError, IndexError, TypeError, ValueError) as exc:
            raise ProviderResponseError("Groq returned a malformed response") from exc

        text = (content or "").strip()
        if not text:
            raise ProviderResponseError("Groq returned an empty response")
        return text
