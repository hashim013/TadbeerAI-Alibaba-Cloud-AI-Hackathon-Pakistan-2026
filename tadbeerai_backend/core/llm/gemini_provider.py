"""Gemini provider — wraps the google-generativeai SDK behind LLMProvider.

The SDK is imported ONLY here (and in the legacy ``core/llm_client.py``);
agents and services talk to the :class:`LLMProvider` interface instead.
"""

from __future__ import annotations

import os

import google.generativeai as genai
from google.api_core import exceptions as gexc

from .base import (
    LLMError,
    LLMProvider,
    ProviderAuthError,
    ProviderRateLimitError,
    ProviderResponseError,
    ProviderTimeoutError,
    ProviderUnavailableError,
)

_DEFAULT_MODEL = "gemini-3.1-flash-lite"
_DEFAULT_TIMEOUT_SECONDS = 30.0


class GeminiProvider(LLMProvider):
    """Google Gemini via the ``google-generativeai`` SDK."""

    name = "gemini"

    def __init__(
        self,
        api_key: str | None = None,
        model: str | None = None,
        timeout: float = _DEFAULT_TIMEOUT_SECONDS,
    ) -> None:
        self._api_key = api_key or os.getenv("GEMINI_API_KEY", "").strip()
        self._model = model or os.getenv("GEMINI_MODEL", "").strip() or _DEFAULT_MODEL
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
            raise ProviderUnavailableError("Gemini API key is not configured")

        full_prompt = f"{system}\n\n{prompt}" if system else prompt
        try:
            genai.configure(api_key=self._api_key)
            model = genai.GenerativeModel(self._model)
            response = model.generate_content(
                full_prompt,
                generation_config={"temperature": temperature},
                request_options={"timeout": self._timeout},
            )
        except gexc.PermissionDenied as exc:
            raise ProviderAuthError("Gemini rejected the API key") from exc
        except gexc.InvalidArgument as exc:
            raise ProviderAuthError("Gemini rejected the API key") from exc
        except gexc.ResourceExhausted as exc:
            raise ProviderRateLimitError("Gemini rate limit reached") from exc
        except gexc.DeadlineExceeded as exc:
            raise ProviderTimeoutError("Gemini request timed out") from exc
        except gexc.GoogleAPIError as exc:
            raise LLMError(f"Gemini request failed: {exc}") from exc
        except Exception as exc:  # network / SDK-level failures
            raise LLMError(f"Gemini request failed: {exc}") from exc

        try:
            text = (response.text or "").strip()
        except ValueError as exc:  # no candidates (e.g. safety block)
            raise ProviderResponseError("Gemini returned an empty response") from exc
        if not text:
            raise ProviderResponseError("Gemini returned an empty response")
        return text
