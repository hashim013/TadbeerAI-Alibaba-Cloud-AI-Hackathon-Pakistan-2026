# TadbeerAI Notification API Contract

When extending the App Engine backend, support the following so the Flutter client can use server-side delivery reports.

## POST /simulate

**Request body (additional fields):**

```json
{
  "action_index": 0,
  "scenario": "petrol",
  "user_id": "firebase-uid",
  "notify_channels": ["sms", "email", "push"]
}
```

**Response (additional field):**

```json
{
  "delivery_report": {
    "sms_recipients": 1200,
    "email_recipients": 1200,
    "push_recipients": 1200,
    "status": "sent",
    "sms_skipped": false,
    "email_skipped": false,
    "push_skipped": false
  }
}
```

## POST /users/fcm-token (optional)

If not using Firestore for FCM tokens:

```json
{
  "user_id": "firebase-uid",
  "fcm_token": "..."
}
```

## Authorization

The Flutter client sends `Authorization: Bearer <Firebase ID token>` on all requests when the user is signed in.
