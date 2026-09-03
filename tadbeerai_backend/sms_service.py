import os
import requests

def send_sms_alert(to_phone: str, message: str):
    """
    Sends an SMS alert using Fast2SMS API. (Currently disabled/commented in backend)
    """
    print(f"[sms_service] SMS sending is currently disabled in the backend. (Target: {to_phone}, Message: {message})")
    return

