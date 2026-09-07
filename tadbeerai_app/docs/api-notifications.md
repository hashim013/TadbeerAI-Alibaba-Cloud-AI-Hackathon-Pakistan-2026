# TadbeerAI Notification API Contract

When extending the backend (deployed on Vercel), support the following so the Flutter client can use server-side delivery reports.

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
