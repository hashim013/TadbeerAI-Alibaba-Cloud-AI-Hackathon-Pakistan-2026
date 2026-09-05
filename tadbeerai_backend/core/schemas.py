from typing import Any, Optional

from pydantic import BaseModel, Field, field_validator


class AssistantChatRequest(BaseModel):
    """Request body for POST /v1/assistant/chat."""

    message: str = Field(..., min_length=1, max_length=4000)
    language: str = "en"
    #: optional personal context for the multi-agent pipeline (Phase 2+);
    #: omitted by existing clients — the graph degrades gracefully without it
    financial_context: Optional[dict[str, Any]] = None

    @field_validator("message")
    @classmethod
    def message_not_blank(cls, value: str) -> str:
        if not value.strip():
            raise ValueError("message must not be blank")
        return value


class AssistantChatResponse(BaseModel):
    """Structured reply from POST /v1/assistant/chat.

    ``agentsUsed``/``metrics``/``recommendations``/``sources`` are populated
    by the multi-agent pipeline and the deterministic tools. ``dataStatus``
    is code-controlled: "live" / "partial" / "demo" / "unavailable" for
    economic indicators, or "scenario" when the answer's numbers are a
    user-defined what-if assumption computed deterministically.
    """

    answer: str
    intent: str
    language: str = "en"
    provider: str
    agentsUsed: list[str] = Field(default_factory=list)
    metrics: dict[str, Any] = Field(default_factory=dict)
    recommendations: list[str] = Field(default_factory=list)
    sources: list[str] = Field(default_factory=list)
    dataStatus: str = "demo"


class AnalyseRequest(BaseModel):
    text: Optional[str] = None
    source_url: Optional[str] = None
    language: str = "en"
    user_profile: Optional[dict] = None


class SimulateRequest(BaseModel):
    action_index: int = 0
    insight_id: Optional[str] = None
    scenario: Optional[str] = None
    user_id: Optional[str] = None
    notify_channels: Optional[list[str]] = None
    user_profile: Optional[dict] = None


class RegisterUserRequest(BaseModel):
    """Register a user for notification alerts. All fields optional for guest mode."""
    user_id: str
    category: str
    name: str
    email: str
    phone: str
    fcm_token: Optional[str] = ""
    profile_data: Optional[dict] = None



class UpdateUserRequest(BaseModel):
    """Update user notification preferences."""
    name: Optional[str] = None
    phone: Optional[str] = None
    email: Optional[str] = None
    notify_sms: Optional[bool] = None
    notify_email: Optional[bool] = None
    notify_push: Optional[bool] = None
    fcm_token: Optional[str] = None
    domains: Optional[list[str]] = None


class FcmTokenRequest(BaseModel):
    """FCM token registration/sync request."""
    user_id: str
    fcm_token: str
