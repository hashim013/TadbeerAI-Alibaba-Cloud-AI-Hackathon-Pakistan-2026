import os
import requests
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

def send_email_alert(to_email, subject, insight, action=None):
    """
    Sends an email alert. Supports:
    1. Google Gmail SMTP (if GMAIL_USER and GMAIL_APP_PASSWORD are set)
    2. Resend.com API (if RESEND_API_KEY is set)
    """
    gmail_user = os.getenv("GMAIL_USER")
    gmail_password = os.getenv("GMAIL_APP_PASSWORD")
    resend_key = os.getenv("RESEND_API_KEY")

    # Format the email body (Plain Text & HTML fallback)
    if action is None:
        insight_html = insight.replace('\n', '<br>')
        html_body = f"""
        <html>
        <body style="font-family: sans-serif; line-height: 1.5; color: #333;">
            <h2>TadbeerAI Alert 🚨</h2>
            <div>{insight_html}</div>
            <p style='color:gray; font-size: 12px; margin-top: 20px;'>TadbeerAI — Pakistan ka AI Business Advisor</p>
        </body>
        </html>
        """
        text_body = f"TadbeerAI Alert 🚨\n\n{insight}\n\nTrace: TadbeerAI"
    else:
        html_body = f"""
        <html>
        <body style="font-family: sans-serif; line-height: 1.5; color: #333;">
            <h2>TadbeerAI Alert 🚨</h2>
            <p><b>Insight:</b> {insight}</p>
            <p><b>Recommended Action:</b> {action}</p>
            <p style='color:gray; font-size: 12px; margin-top: 20px;'>TadbeerAI — Pakistan ka AI Business Advisor</p>
        </body>
        </html>
        """
        text_body = f"TadbeerAI Alert 🚨\n\nInsight: {insight}\n\nRecommended Action: {action}\n\nTrace: TadbeerAI"

    # Option 1: Gmail SMTP
    if gmail_user and gmail_password:
        print(f"[gmail_smtp] Attempting to send email via Gmail SMTP to {to_email}...")
        try:
            msg = MIMEMultipart("alternative")
            msg["Subject"] = subject
            msg["From"] = f"TadbeerAI <{gmail_user}>"
            msg["To"] = to_email

            part1 = MIMEText(text_body, "plain")
            part2 = MIMEText(html_body, "html")
            msg.attach(part1)
            msg.attach(part2)

            # Connect using SSL on port 465 (App Engine friendly)
            with smtplib.SMTP_SSL("smtp.gmail.com", 465) as server:
                server.login(gmail_user, gmail_password)
                server.sendmail(gmail_user, to_email, msg.as_string())
            print(f"[gmail_smtp] ✅ Email sent to {to_email} successfully via Gmail SMTP.")
            return
        except Exception as e:
            print(f"[gmail_smtp] ❌ Gmail SMTP failed: {e}")

    # Option 2: Resend API
    if resend_key and resend_key != "re_xxxxxxxxxxxxxxxx":
        print(f"[gmail_smtp] Attempting to send email via Resend to {to_email}...")
        url = "https://api.resend.com/emails"
        headers = {
            "Authorization": f"Bearer {resend_key}",
            "Content-Type": "application/json"
        }
        payload = {
            "from": "TadbeerAI <onboarding@resend.dev>",
            "to": [to_email],
            "subject": subject,
            "html": html_body
        }
        try:
            response = requests.post(url, json=payload, headers=headers)
            if response.status_code in [200, 201, 202]:
                print(f"[gmail_smtp] ✅ Email sent to {to_email} successfully via Resend: {response.text}")
                return
            else:
                print(f"[gmail_smtp] ❌ Failed to send email via Resend: {response.status_code} - {response.text}")
        except Exception as e:
            print(f"[gmail_smtp] ❌ Resend API failed: {e}")
            return

    print("[gmail_smtp] ⚠️ No email service credentials configured. Email skipped.")

