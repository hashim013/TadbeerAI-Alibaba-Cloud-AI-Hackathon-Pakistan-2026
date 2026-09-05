"""Provider-layer tests: configuration, selection, fallback, error mapping.

Spec coverage (Phase 1 testing requirements 1-6):
1. Gemini configuration
2. Groq configuration
3. primary provider selection
4. fallback behavior
5. timeout / failure handling
6. malformed model responses

Vendor SDK calls are replaced with fakes via ``monkeypatch`` — no real API
keys, no network.
"""

from __future__ import annotations

import httpx
import pytest
from google.api_core import exceptions as gexc

from core.llm import (
    GeminiProvider,
    GroqProvider,
    LLMError,
    LLMRegistry,
    ProviderAuthError,
    ProviderRateLimitError,
    ProviderResponseError,
    ProviderTimeoutError,
    ProviderUnavailableError,
    build_provider,
    extract_json,
    get_llm_registry,
    set_llm_registry,
)
from core.llm import gemini_provider, groq_provider
from tests.conftest import FakeProvider

# --------------------------------------------------------------------------- #
# fakes for the vendor SDK layers
# --------------------------------------------------------------------------- #


class _FakeGeminiResponse:
    def __init__(self, text: str) -> None:
        self.text = text


class _BlockedGeminiResponse:
    """Mimics a safety-blocked response: ``.text`` raises ValueError."""

    @property
    def text(self):
        raise ValueError("Candidate was blocked")


class _FakeGeminiModel:
    def __init__(self, response=None, exc=None) -> None:
        self._response = response
        self._exc = exc

    def generate_content(self, prompt, **kwargs):
        if self._exc is not None:
            raise self._exc
        return self._response


def _patch_gemini(monkeypatch, response=None, exc=None) -> None:
    fake_model = _FakeGeminiModel(response=response, exc=exc)
    monkeypatch.setattr(
        gemini_provider.genai, "GenerativeModel", lambda name: fake_model
    )
    monkeypatch.setattr(gemini_provider.genai, "configure", lambda **kw: None)


class _FakeHttpResponse:
    def __init__(self, status_code: int = 200, payload: dict | None = None) -> None:
        self.status_code = status_code
        self._payload = payload if payload is not None else {}

    def json(self):
        return self._payload


class _BadJsonHttpResponse:
    status_code = 200

    def json(self):
        raise ValueError("response body is not JSON")


class _FakeHttpClient:
    def __init__(self, response=None, exc=None) -> None:
        self._response = response
        self._exc = exc
        self.requests: list[dict] = []

    def __enter__(self):
        return self

    def __exit__(self, *args):
        return False

    def post(self, url, **kwargs):
        self.requests.append({"url": url, **kwargs})
        if self._exc is not None:
            raise self._exc
        return self._response


def _patch_groq_http(monkeypatch, response=None, exc=None) -> _FakeHttpClient:
    fake_client = _FakeHttpClient(response=response, exc=exc)
    monkeypatch.setattr(groq_provider.httpx, "Client", lambda *a, **kw: fake_client)
    return fake_client


# --------------------------------------------------------------------------- #
# 1. Gemini configuration
# --------------------------------------------------------------------------- #


class TestGeminiConfiguration:
    def test_reads_env_configuration(self, monkeypatch):
        monkeypatch.setenv("GEMINI_API_KEY", "test-key")
        monkeypatch.setenv("GEMINI_MODEL", "gemini-test-model")
        provider = GeminiProvider()
        assert provider.is_configured() is True
        assert provider.model == "gemini-test-model"
        assert provider.name == "gemini"

    def test_default_model_when_unset(self, monkeypatch):
        monkeypatch.setenv("GEMINI_API_KEY", "test-key")
        monkeypatch.delenv("GEMINI_MODEL", raising=False)
        assert GeminiProvider().model == "gemini-3.1-flash-lite"

    def test_unconfigured_without_key(self, monkeypatch):
        monkeypatch.delenv("GEMINI_API_KEY", raising=False)
        provider = GeminiProvider(api_key="")
        assert provider.is_configured() is False
        with pytest.raises(ProviderUnavailableError):
            provider.generate("hello")


class TestGeminiGenerate:
    def test_success(self, monkeypatch):
        _patch_gemini(
            monkeypatch, response=_FakeGeminiResponse("hello from gemini")
        )
        provider = GeminiProvider(api_key="test-key", model="m")
        assert provider.generate("hi", system="be brief") == "hello from gemini"

    def test_blank_response_rejected(self, monkeypatch):
        _patch_gemini(monkeypatch, response=_FakeGeminiResponse("   "))
        provider = GeminiProvider(api_key="test-key")
        with pytest.raises(ProviderResponseError):
            provider.generate("hi")

    def test_blocked_response_rejected(self, monkeypatch):
        _patch_gemini(monkeypatch, response=_BlockedGeminiResponse())
        provider = GeminiProvider(api_key="test-key")
        with pytest.raises(ProviderResponseError):
            provider.generate("hi")

    @pytest.mark.parametrize(
        "sdk_exc,expected",
        [
            (gexc.PermissionDenied("bad key"), ProviderAuthError),
            (gexc.InvalidArgument("bad request"), ProviderAuthError),
            (gexc.ResourceExhausted("quota"), ProviderRateLimitError),
            (gexc.DeadlineExceeded("slow"), ProviderTimeoutError),
            (gexc.GoogleAPIError("boom"), LLMError),
            (ConnectionError("network down"), LLMError),
        ],
    )
    def test_error_mapping(self, monkeypatch, sdk_exc, expected):
        _patch_gemini(monkeypatch, exc=sdk_exc)
        provider = GeminiProvider(api_key="test-key")
        with pytest.raises(expected):
            provider.generate("hi")


# --------------------------------------------------------------------------- #
# 2. Groq configuration
# --------------------------------------------------------------------------- #


class TestGroqConfiguration:
    def test_reads_env_configuration(self, monkeypatch):
        monkeypatch.setenv("GROQ_API_KEY", "test-key")
        monkeypatch.setenv("GROQ_MODEL", "groq-test-model")
        provider = GroqProvider()
        assert provider.is_configured() is True
        assert provider.model == "groq-test-model"
        assert provider.name == "groq"

    def test_default_model_when_unset(self, monkeypatch):
        monkeypatch.setenv("GROQ_API_KEY", "test-key")
        monkeypatch.delenv("GROQ_MODEL", raising=False)
        assert GroqProvider().model == "openai/gpt-oss-120b"

    def test_unconfigured_without_key(self, monkeypatch):
        monkeypatch.delenv("GROQ_API_KEY", raising=False)
        provider = GroqProvider(api_key="")
        assert provider.is_configured() is False
        with pytest.raises(ProviderUnavailableError):
            provider.generate("hello")


class TestGroqGenerate:
    def test_success_sends_expected_payload(self, monkeypatch):
        payload = {"choices": [{"message": {"content": "hello from groq"}}]}
        fake = _patch_groq_http(
            monkeypatch, response=_FakeHttpResponse(200, payload)
        )
        provider = GroqProvider(api_key="test-key", model="m")
        assert provider.generate("hi", system="be brief") == "hello from groq"
        request = fake.requests[0]
        assert request["url"] == groq_provider._GROQ_CHAT_URL
        assert request["headers"]["Authorization"] == "Bearer test-key"
        assert request["json"]["model"] == "m"
        assert request["json"]["messages"][0] == {
            "role": "system",
            "content": "be brief",
        }
        assert request["json"]["messages"][1] == {"role": "user", "content": "hi"}

    @pytest.mark.parametrize(
        "status,expected",
        [
            (401, ProviderAuthError),
            (429, ProviderRateLimitError),
            (500, LLMError),
        ],
    )
    def test_error_status_mapping(self, monkeypatch, status, expected):
        _patch_groq_http(monkeypatch, response=_FakeHttpResponse(status))
        provider = GroqProvider(api_key="test-key")
        with pytest.raises(expected):
            provider.generate("hi")

    def test_timeout_maps_to_provider_timeout(self, monkeypatch):
        _patch_groq_http(monkeypatch, exc=httpx.ReadTimeout("too slow"))
        provider = GroqProvider(api_key="test-key")
        with pytest.raises(ProviderTimeoutError):
            provider.generate("hi")

    def test_network_failure_maps_to_llm_error(self, monkeypatch):
        _patch_groq_http(monkeypatch, exc=httpx.ConnectError("no network"))
        provider = GroqProvider(api_key="test-key")
        with pytest.raises(LLMError):
            provider.generate("hi")

    def test_malformed_body_rejected(self, monkeypatch):
        _patch_groq_http(monkeypatch, response=_BadJsonHttpResponse())
        provider = GroqProvider(api_key="test-key")
        with pytest.raises(ProviderResponseError):
            provider.generate("hi")

    def test_missing_choices_rejected(self, monkeypatch):
        _patch_groq_http(
            monkeypatch, response=_FakeHttpResponse(200, {"unexpected": True})
        )
        provider = GroqProvider(api_key="test-key")
        with pytest.raises(ProviderResponseError):
            provider.generate("hi")

    def test_empty_content_rejected(self, monkeypatch):
        payload = {"choices": [{"message": {"content": "   "}}]}
        _patch_groq_http(monkeypatch, response=_FakeHttpResponse(200, payload))
        provider = GroqProvider(api_key="test-key")
        with pytest.raises(ProviderResponseError):
            provider.generate("hi")


# --------------------------------------------------------------------------- #
# 3. primary provider selection
# --------------------------------------------------------------------------- #


class TestRegistryFromEnv:
    def _clear_env(self, monkeypatch):
        for var in ("PRIMARY_LLM", "FALLBACK_LLM", "AI_PROVIDER"):
            monkeypatch.delenv(var, raising=False)

    def test_primary_gemini_fallback_groq(self, monkeypatch):
        self._clear_env(monkeypatch)
        monkeypatch.setenv("PRIMARY_LLM", "gemini")
        monkeypatch.setenv("FALLBACK_LLM", "groq")
        registry = LLMRegistry.from_env()
        assert registry.primary_name == "gemini"
        assert registry.fallback_name == "groq"

    def test_primary_groq_fallback_gemini(self, monkeypatch):
        self._clear_env(monkeypatch)
        monkeypatch.setenv("PRIMARY_LLM", "groq")
        monkeypatch.setenv("FALLBACK_LLM", "gemini")
        registry = LLMRegistry.from_env()
        assert registry.primary_name == "groq"
        assert registry.fallback_name == "gemini"

    def test_legacy_ai_provider_honoured(self, monkeypatch):
        self._clear_env(monkeypatch)
        monkeypatch.setenv("AI_PROVIDER", "groq")
        registry = LLMRegistry.from_env()
        assert registry.primary_name == "groq"

    def test_invalid_primary_defaults_to_gemini(self, monkeypatch):
        self._clear_env(monkeypatch)
        monkeypatch.setenv("PRIMARY_LLM", "qwen")  # not supported (yet)
        registry = LLMRegistry.from_env()
        assert registry.primary_name == "gemini"
        assert registry.fallback_name == "groq"

    def test_blank_env_defaults_to_gemini(self, monkeypatch):
        self._clear_env(monkeypatch)
        registry = LLMRegistry.from_env()
        assert registry.primary_name == "gemini"
        assert registry.fallback_name == "groq"

    def test_fallback_equal_to_primary_auto_derived(self, monkeypatch):
        self._clear_env(monkeypatch)
        monkeypatch.setenv("PRIMARY_LLM", "gemini")
        monkeypatch.setenv("FALLBACK_LLM", "gemini")
        registry = LLMRegistry.from_env()
        assert registry.fallback_name == "groq"

    def test_invalid_fallback_auto_derived(self, monkeypatch):
        self._clear_env(monkeypatch)
        monkeypatch.setenv("PRIMARY_LLM", "groq")
        monkeypatch.setenv("FALLBACK_LLM", "qwen")
        registry = LLMRegistry.from_env()
        assert registry.fallback_name == "gemini"

    def test_build_provider_unknown_name(self):
        with pytest.raises(ValueError):
            build_provider("qwen")


class TestRegistrySingleton:
    def test_set_and_reset(self):
        registry = LLMRegistry(primary=FakeProvider())
        set_llm_registry(registry)
        try:
            assert get_llm_registry() is registry
        finally:
            set_llm_registry(None)
        assert isinstance(get_llm_registry(), LLMRegistry)
        set_llm_registry(None)  # leave global state clean


# --------------------------------------------------------------------------- #
# 4. fallback behavior  (and 5. timeout/failure via one-attempt assertions)
# --------------------------------------------------------------------------- #


class TestRegistryFallback:
    def test_primary_success_never_calls_fallback(self):
        primary = FakeProvider(name="primary", replies=["from primary"])
        fallback = FakeProvider(name="fallback", replies=["from fallback"])
        registry = LLMRegistry(primary=primary, fallback=fallback)

        result = registry.generate("hi")

        assert result.text == "from primary"
        assert result.provider == "primary"
        assert result.model == "fake-model"
        assert result.used_fallback is False
        assert len(fallback.calls) == 0

    def test_primary_failure_uses_fallback_once(self):
        primary = FakeProvider(name="primary", error=ProviderAuthError("bad key"))
        fallback = FakeProvider(name="fallback", replies=["from fallback"])
        registry = LLMRegistry(primary=primary, fallback=fallback)

        result = registry.generate("hi")

        assert result.text == "from fallback"
        assert result.provider == "fallback"
        assert result.used_fallback is True
        assert len(primary.calls) == 1
        assert len(fallback.calls) == 1

    def test_timeout_on_primary_falls_back(self):
        primary = FakeProvider(name="primary", error=ProviderTimeoutError("t/o"))
        fallback = FakeProvider(name="fallback", replies=["from fallback"])
        registry = LLMRegistry(primary=primary, fallback=fallback)

        result = registry.generate("hi")

        assert result.provider == "fallback"
        assert result.used_fallback is True

    def test_unconfigured_primary_skipped_entirely(self):
        primary = FakeProvider(name="primary", configured=False)
        fallback = FakeProvider(name="fallback", replies=["from fallback"])
        registry = LLMRegistry(primary=primary, fallback=fallback)

        result = registry.generate("hi")

        assert result.provider == "fallback"
        assert result.used_fallback is True
        assert len(primary.calls) == 0

    def test_both_fail_raises_last_error(self):
        primary = FakeProvider(name="primary", error=ProviderAuthError("bad key"))
        fallback = FakeProvider(
            name="fallback", error=ProviderRateLimitError("quota")
        )
        registry = LLMRegistry(primary=primary, fallback=fallback)

        with pytest.raises(ProviderRateLimitError):
            registry.generate("hi")

    def test_no_provider_configured(self):
        registry = LLMRegistry(primary=FakeProvider(configured=False))
        with pytest.raises(ProviderUnavailableError):
            registry.generate("hi")

    def test_exactly_one_attempt_per_provider(self):
        """No retry storms: one primary call, one fallback call, then stop."""
        primary = FakeProvider(name="primary", error=ProviderTimeoutError("t/o"))
        fallback = FakeProvider(name="fallback", error=ProviderRateLimitError("q"))
        registry = LLMRegistry(primary=primary, fallback=fallback)

        with pytest.raises(LLMError):
            registry.generate("hi")

        assert len(primary.calls) == 1
        assert len(fallback.calls) == 1


# --------------------------------------------------------------------------- #
# 6. malformed model responses (structured generation)
# --------------------------------------------------------------------------- #


class TestStructuredGeneration:
    def test_plain_json(self):
        provider = FakeProvider(replies=['{"answer": 42}'])
        registry = LLMRegistry(primary=provider)
        assert registry.generate_structured("q") == {"answer": 42}

    def test_fenced_json(self):
        provider = FakeProvider(replies=['```json\n{"a": 1}\n```'])
        registry = LLMRegistry(primary=provider)
        assert registry.generate_structured("q") == {"a": 1}

    def test_garbage_raises_response_error(self):
        provider = FakeProvider(replies=["this is not json at all"])
        registry = LLMRegistry(primary=provider)
        with pytest.raises(ProviderResponseError):
            registry.generate_structured("q")

    def test_structured_falls_back_on_malformed_json(self):
        primary = FakeProvider(name="primary", replies=["garbage not json"])
        fallback = FakeProvider(name="fallback", replies=['{"ok": true}'])
        registry = LLMRegistry(primary=primary, fallback=fallback)

        assert registry.generate_structured("q") == {"ok": True}
        assert len(primary.calls) == 1
        assert len(fallback.calls) == 1

    def test_structured_prompt_includes_json_instruction(self):
        provider = FakeProvider(replies=['{"a": 1}'])
        registry = LLMRegistry(primary=provider)
        registry.generate_structured("q", system="base system")
        system = provider.calls[0]["system"]
        assert "base system" in system
        assert "VALID JSON" in system

    def test_extract_json_variants(self):
        assert extract_json('{"a": 1}') == {"a": 1}
        assert extract_json("```\n[1, 2]\n```") == [1, 2]
        assert extract_json('```json {"a": 1} ```') == {"a": 1}
        with pytest.raises(ValueError):
            extract_json("nope")
