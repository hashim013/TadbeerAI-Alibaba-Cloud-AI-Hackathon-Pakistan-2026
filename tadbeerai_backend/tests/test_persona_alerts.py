import pytest
from fastapi.testclient import TestClient
from main import app
from core.user_registry import get_user_registry
from core.notification_service import get_notification_service

client = TestClient(app)


def test_register_guest_user_not_eligible_for_alerts():
    payload = {
        "user_id": "guest_test_001",
        "category": "Student",
        "name": "Guest Student",
        "email": "",
        "phone": "",
        "is_guest": True,
    }
    response = client.post("/register", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert data["success"] is True
    assert data["is_guest"] is True
    assert data["eligible_for_alerts"] is False
    assert data["mode"] == "guest"


def test_register_account_user_eligible_for_alerts():
    payload = {
        "user_id": "registered_test_002",
        "category": "Salaried",
        "name": "Ahmad Ali",
        "email": "ahmad.ali@example.com",
        "phone": "+923001234567",
        "is_guest": False,
    }
    response = client.post("/register", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert data["success"] is True
    assert data["is_guest"] is False
    assert data["eligible_for_alerts"] is True
    assert data["mode"] == "account"


def test_post_user_persona_guest_mode():
    payload = {
        "user_id": "guest_persona_003",
        "persona": "student",
        "primary_goal": "emergencyFund",
        "monthly_income": 0,
        "monthly_essential_expenses": 15000,
        "total_savings": 5000,
        "is_guest": True,
    }
    response = client.post("/users/persona", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "success"
    assert data["is_guest"] is True
    assert data["eligible_for_alerts"] is False
    assert "reserved for registered users" in data["message"].lower() or "locally" in data["message"].lower()


def test_post_user_persona_registered_user():
    payload = {
        "user_id": "reg_persona_004",
        "persona": "salaried",
        "primary_goal": "saveMore",
        "monthly_income": 120000,
        "monthly_essential_expenses": 70000,
        "total_savings": 200000,
        "is_guest": False,
        "name": "Fatima Khan",
        "email": "fatima.khan@example.com",
        "phone": "+923219876543",
    }
    response = client.post("/users/persona", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "success"
    assert data["is_guest"] is False
    assert data["eligible_for_alerts"] is True
    assert "activated" in data["message"].lower() or "eligible" in data["message"].lower()


def test_alerts_eligibility_endpoint():
    # 1. Non-existent or default guest user
    res_unknown = client.get("/users/unknown_guest_999/alerts-eligibility")
    assert res_unknown.status_code == 200
    assert res_unknown.json()["eligible_for_alerts"] is False
    assert res_unknown.json()["is_guest"] is True

    # 2. Registered guest user from previous test
    res_guest = client.get("/users/guest_persona_003/alerts-eligibility")
    assert res_guest.status_code == 200
    assert res_guest.json()["eligible_for_alerts"] is False
    assert res_guest.json()["is_guest"] is True

    # 3. Registered account user
    res_reg = client.get("/users/reg_persona_004/alerts-eligibility")
    assert res_reg.status_code == 200
    assert res_reg.json()["eligible_for_alerts"] is True
    assert res_reg.json()["is_guest"] is False


def test_notification_service_skips_guest_alerts():
    svc = get_notification_service()
    # Attempt to send notification targeting the guest user
    users_reached, sms_sent, emails_sent, push_sent, summary, report = svc.notify_all_users(
        action_key="energy_increase_delivery_fee",
        action_description="Energy price alert",
        impact_amount="PKR 500",
        domain="Energy",
        action_id="act_test_001",
        user_id="guest_persona_003",
    )
    assert users_reached == 0
    assert sms_sent == 0
    assert emails_sent == 0
    assert push_sent == 0
    assert report["status"] == "guest_ineligible"
    assert report["eligible_for_alerts"] is False
    assert "guest users are not eligible" in summary.lower()
