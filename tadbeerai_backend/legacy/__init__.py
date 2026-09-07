"""Archived legacy pipeline (NOT wired into the running application).

This package holds the first-generation TadbeerAI backend: the RSS / news
business-automation agents and their supporting modules. It was superseded by
the provider-agnostic ``/v1`` stack (``core/api_v1.py`` -> ``core/assistant_service``
-> ``core/agents`` LangGraph -> ``core/llm`` Gemini/Groq registry) plus the
``core/economic_data``, ``core/scenarios`` and ``core/finance_store`` services.

Nothing in ``main.py``, ``core/`` or the test suite imports this package any
more; it is retained for historical reference only. See ``legacy/README.md``.
"""
