"""Vendor-neutral LLM provider abstraction.

Public surface used by services and agents::

    from core.llm import LLMProvider, get_llm_registry

Adding a new vendor (e.g. Qwen / Alibaba Cloud) means:
1. implement ``core/llm/qwen_provider.py`` against :class:`LLMProvider`,
2. register its name in ``registry.build_provider`` / ``_SUPPORTED_PROVIDERS``.

Agent and service code stays untouched.
"""

from .base import (
    GenerationResult,
    LLMError,
    LLMProvider,
    ProviderAuthError,
    ProviderRateLimitError,
    ProviderResponseError,
    ProviderTimeoutError,
    ProviderUnavailableError,
    extract_json,
)
from .gemini_provider import GeminiProvider
from .groq_provider import GroqProvider
from .registry import (
    LLMRegistry,
    build_provider,
    get_llm_registry,
    set_llm_registry,
)

__all__ = [
    "GenerationResult",
    "GeminiProvider",
    "GroqProvider",
    "LLMError",
    "LLMProvider",
    "LLMRegistry",
    "ProviderAuthError",
    "ProviderRateLimitError",
    "ProviderResponseError",
    "ProviderTimeoutError",
    "ProviderUnavailableError",
    "build_provider",
    "extract_json",
    "get_llm_registry",
    "set_llm_registry",
]
