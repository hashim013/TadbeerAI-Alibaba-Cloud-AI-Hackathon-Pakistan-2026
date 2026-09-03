from typing import Optional

from pydantic import BaseModel


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
