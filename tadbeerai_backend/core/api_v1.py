"""Versioned v1 API routes — health check and assistant chat.

Kept in a separate router (not inline in ``main.py``) so the new
provider-agnostic stack grows independently of the legacy endpoint set.

Architecture::

    API (this module)
      -> AssistantService          (intent + prompt + response shaping)
        -> LLMRegistry              (selection + one controlled fallback)
          -> GeminiProvider / GroqProvider   (vendor SDKs live here only)
"""

from __future__ import annotations

from typing import Optional

from fastapi import APIRouter, Depends, HTTPException

from .assistant_service import AssistantService
from .auth import get_authenticated_user_id
from .economic_data import EconomicDataService, get_economic_service
from .finance_store import get_finance_store
from .llm import LLMError, LLMRegistry, get_llm_registry
from .schemas import (
    AssistantChatRequest,
    AssistantChatResponse,
    FinanceLedgerRequest,
)

router = APIRouter(prefix="/v1")


def get_assistant_service(
    registry: LLMRegistry = Depends(get_llm_registry),
) -> AssistantService:
    """FastAPI dependency: build the assistant on top of the LLM registry."""
    return AssistantService(registry=registry)


@router.get("/health")
def v1_health(registry: LLMRegistry = Depends(get_llm_registry)) -> dict:
    """Liveness + provider routing summary. Never exposes secrets."""
    status = "ok" if registry.any_configured() else "degraded"
    return {
        "status": status,
        "primary_llm": registry.primary_name,
        "fallback_llm": registry.fallback_name,
    }


@router.post("/assistant/chat", response_model=AssistantChatResponse)
def assistant_chat(
    request: AssistantChatRequest,
    service: AssistantService = Depends(get_assistant_service),
) -> AssistantChatResponse:
    """Answer a financial question through the LangGraph multi-agent pipeline."""
    try:
        payload = service.chat(
            message=request.message,
            language=request.language,
            financial_context=request.financial_context,
        )
    except LLMError:
        # provider failures are never leaked to the client verbatim
        raise HTTPException(
            status_code=503,
            detail="The assistant is temporarily unavailable. Please try again shortly.",
        )
    return AssistantChatResponse(**payload)


@router.get("/economy/snapshot")
def v1_economy_snapshot(
    service: EconomicDataService = Depends(get_economic_service),
) -> dict:
    """Return the normalized Pakistan economic indicators snapshot."""
    snapshot = service.snapshot()
    return {
        "status": snapshot.status,
        "fetched_at": snapshot.fetched_at,
        "indicators": {
            name: {
                "name": ind.name,
                "value": ind.value,
                "unit": ind.unit,
                "label": ind.label,
                "status": ind.status,
                "source": ind.source,
                "period": ind.period,
                "notes": ind.notes,
                "previous_value": ind.previous_value,
                "change_value": ind.change_value,
                "change_percent": ind.change_percent,
                "frequency": ind.frequency,
                "source_url": ind.source_url,
                "last_updated": ind.last_updated,
                "history": [
                    {"period": point_period, "value": point_value}
                    for point_period, point_value in ind.history
                ],
            }
            for name, ind in snapshot.indicators.items()
        },
        "fallback_reasons": snapshot.fallback_reasons,
    }


@router.get("/economy/essential-prices")
def v1_essential_prices(
    category: str | None = None,
    location: str | None = None,
    limit: int | None = None,
    service: EconomicDataService = Depends(get_economic_service),
) -> dict:
    """Return the essential commodity prices monitored under the PBS SPI."""
    overview = service.commodity_snapshot(
        category=category, location=location, limit=limit
    )
    return overview.to_dict()


@router.get("/economy/essential-prices/{item_id}")
def v1_essential_price_detail(
    item_id: str,
    service: EconomicDataService = Depends(get_economic_service),
) -> dict:
    """Return price details and economic interpretation for a single commodity."""
    item = service.commodity_detail(item_id)
    if item is None:
        raise HTTPException(
            status_code=404,
            detail=f"Essential commodity '{item_id}' not found.",
        )
    return item.to_dict()


# ==================== FINANCE LEDGER (per-user, Firestore-backed) ====================


@router.get("/finance")
def get_finance_ledger(
    user_id: Optional[str] = Depends(get_authenticated_user_id),
) -> dict:
    """Return the authenticated user's ledger snapshot (empty defaults if none).

    Requires a valid Firebase ID token; 401 otherwise. The snapshot mirrors the
    Flutter ``FinanceData.toJson()`` shape so the client can parse it directly.
    """
    if not user_id:
        raise HTTPException(status_code=401, detail="Unauthorized")
    return get_finance_store().get_ledger(user_id)


@router.put("/finance")
def put_finance_ledger(
    request: FinanceLedgerRequest,
    user_id: Optional[str] = Depends(get_authenticated_user_id),
) -> dict:
    """Replace the authenticated user's ledger with the given snapshot.

    Whole-snapshot last-write-wins: the client sends its full local ledger and
    the stored doc is overwritten, then the persisted snapshot is returned.
    Requires a valid Firebase ID token; 401 otherwise.
    """
    if not user_id:
        raise HTTPException(status_code=401, detail="Unauthorized")
    return get_finance_store().put_ledger(user_id, request.model_dump())
