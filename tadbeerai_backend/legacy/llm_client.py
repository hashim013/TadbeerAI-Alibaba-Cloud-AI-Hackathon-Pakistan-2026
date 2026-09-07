import json
import os

import google.generativeai as genai
import httpx
from dotenv import load_dotenv

load_dotenv()

AI_PROVIDER = os.getenv("AI_PROVIDER", "gemini").lower().strip()
GEMINI_MODEL = os.getenv("GEMINI_MODEL", "gemini-2.0-flash")
GROQ_MODEL = os.getenv("GROQ_MODEL", "llama-3.3-70b-versatile")

_gemini_key_index = 0
_groq_key_index = 0

_ACTIVE_AI_PROVIDER = AI_PROVIDER if AI_PROVIDER in ("gemini", "groq") else "gemini"


def get_ai_provider() -> str:
    """Active LLM backend currently in use: gemini | groq."""
    return _ACTIVE_AI_PROVIDER


def get_primary_ai_provider() -> str:
    """Configured primary LLM backend from environment."""
    return AI_PROVIDER if AI_PROVIDER in ("gemini", "groq") else "gemini"


def _set_active_ai_provider(provider: str) -> None:
    global _ACTIVE_AI_PROVIDER
    if provider in ("gemini", "groq"):
        _ACTIVE_AI_PROVIDER = provider


def _get_all_gemini_keys() -> list[str]:
    """Retrieve all configured Gemini API keys (comma-separated or indexed)."""
    keys = []
    env_keys = os.getenv("GEMINI_API_KEYS")
    if env_keys:
        for k in env_keys.split(","):
            clean_k = k.strip()
            if clean_k:
                keys.append(clean_k)
    
    main_key = os.getenv("GEMINI_API_KEY")
    if main_key and main_key not in keys:
        keys.append(main_key)
        
    for i in range(2, 10):
        key = os.getenv(f"GEMINI_API_KEY_{i}")
        if key and key not in keys:
            keys.append(key)
            
    return keys


def _call_gemini_text(prompt: str, system: str = "") -> str:
    global _gemini_key_index
    full_prompt = f"{system}\n\n{prompt}" if system else prompt
    
    keys = _get_all_gemini_keys()
    if not keys:
        raise ValueError("No GEMINI_API_KEY set in environment")
        
    last_error = None
    for _ in range(len(keys)):
        if _gemini_key_index >= len(keys):
            _gemini_key_index = 0
            
        current_key = keys[_gemini_key_index]
        try:
            genai.configure(api_key=current_key)
            model = genai.GenerativeModel(GEMINI_MODEL)
            response = model.generate_content(full_prompt)
            return response.text.strip()
        except Exception as e:
            last_error = e
            print(f"[LLM] Gemini key index {_gemini_key_index} failed: {e}. Rotating to next key.")
            _gemini_key_index = (_gemini_key_index + 1) % len(keys)
            
    raise last_error or RuntimeError("All Gemini API keys failed")


def _get_all_groq_keys() -> list[str]:
    """Retrieve all configured Groq API keys (comma-separated or indexed)."""
    keys = []
    env_keys = os.getenv("GROQ_API_KEYS")
    if env_keys:
        for k in env_keys.split(","):
            clean_k = k.strip()
            if clean_k:
                keys.append(clean_k)
                
    main_key = os.getenv("GROQ_API_KEY")
    if main_key and main_key not in keys:
        keys.append(main_key)
        
    for i in range(2, 10):
        key = os.getenv(f"GROQ_API_KEY_{i}")
        if key and key not in keys:
            keys.append(key)
            
    return keys


def _call_groq_text(prompt: str, system: str = "") -> str:
    global _groq_key_index
    full_prompt = f"{system}\n\n{prompt}" if system else prompt
    
    keys = _get_all_groq_keys()
    if not keys:
        raise ValueError("No GROQ_API_KEY set in environment")

    messages = []
    if system:
        messages.append({"role": "system", "content": system})
    messages.append({"role": "user", "content": prompt})

    payload = {
        "model": GROQ_MODEL,
        "messages": messages,
        "temperature": 0.4,
    }
    
    last_error = None
    for _ in range(len(keys)):
        if _groq_key_index >= len(keys):
            _groq_key_index = 0
            
        current_key = keys[_groq_key_index]
        try:
            with httpx.Client(timeout=60.0) as client:
                r = client.post(
                    "https://api.groq.com/openai/v1/chat/completions",
                    headers={
                        "Authorization": f"Bearer {current_key}",
                        "Content-Type": "application/json",
                    },
                    json=payload,
                )
                r.raise_for_status()
                data = r.json()
            return data["choices"][0]["message"]["content"].strip()
        except Exception as e:
            last_error = e
            print(f"[LLM] Groq key index {_groq_key_index} failed: {e}. Rotating to next key.")
            _groq_key_index = (_groq_key_index + 1) % len(keys)
            
    raise last_error or RuntimeError("All Groq API keys failed")


def call_llm(prompt: str, system: str = "") -> str:
    """Call configured LLM (Gemini or Groq). Returns text response with automatic fallback."""
    provider = get_ai_provider()
    try:
        if provider == "groq":
            return _call_groq_text(prompt, system)
        else:
            return _call_gemini_text(prompt, system)
    except Exception as e:
        print(f"[LLM] {provider.capitalize()} error: {e}")
        # Fallback to other provider
        if provider == "gemini":
            try:
                keys = _get_all_groq_keys()
                if keys:
                    print("[LLM] Falling back to Groq")
                    _set_active_ai_provider("groq")
                    return _call_groq_text(prompt, system)
            except Exception as e2:
                print(f"[LLM] Groq fallback also failed: {e2}")
        else:
            try:
                keys = _get_all_gemini_keys()
                if keys:
                    print("[LLM] Falling back to Gemini")
                    _set_active_ai_provider("gemini")
                    return _call_gemini_text(prompt, system)
            except Exception as e2:
                print(f"[LLM] Gemini fallback also failed: {e2}")
        return ""


def call_llm_json(prompt: str, system: str = "") -> dict | list:
    """Call LLM (Gemini or Groq) expecting JSON. Returns parsed dict or list with auto-fallback."""
    system_json = (
        (system or "")
        + "\n\nRESPOND ONLY WITH VALID JSON. NO MARKDOWN. NO EXPLANATION. NO BACKTICKS."
    )
    raw = call_llm(prompt, system_json)
    try:
        clean = raw.replace("```json", "").replace("```", "").strip()
        return json.loads(clean)
    except json.JSONDecodeError:
        print(f"JSON parse error. Raw: {raw[:200]}")
        return {}


def normalize_confidence(value) -> float:
    """Normalize confidence score to 0.0-1.0 for Flutter InsightResult."""
    if value is None:
        return 0.75
    try:
        c = float(value)
    except (TypeError, ValueError):
        return 0.75
    if c > 1.0:
        c = c / 100.0
    return max(0.0, min(0.99, c))