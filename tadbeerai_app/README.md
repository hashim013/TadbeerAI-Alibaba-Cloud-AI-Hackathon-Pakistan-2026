# Tadbeer AI 2.0 — Flutter Mobile App

The cross-platform Flutter client for **Tadbeer AI 2.0**, a personal financial
intelligence companion for everyday Pakistani users. It pairs offline-first
personal-finance tools with macroeconomic context and a multi-agent AI assistant
("Ask Tadbeer"), fully localised in English, Urdu (اردو) and Roman Urdu.

## What it does
- **Home** — dashboard with an economic pulse preview and profile prompts.
- **Finance** — income, expenses, budgets (50/30/20), savings, goals and a
  transparent Financial Health Score. Offline-first: data is cached on-device and
  syncs to a per-user Firestore ledger for signed-in accounts (the cache bucket is
  dropped on account switch); guest sessions stay local-only and never call the network.
- **Economy** — World Bank **annual** indicators (inflation, USD/PKR, FX reserves,
  remittances, GDP growth) plus a demo PBS essential-commodity price catalogue, each
  badged `live` / `partial` / `demo` / `unavailable`.
- **Ask Tadbeer** — chat with the backend's supervised LangGraph multi-agent
  assistant; all arithmetic is computed server-side by deterministic tools.
- **Profile** — Firebase Authentication (email/password + Google Sign-In), session
  persistence, settings and the 4-step financial profile wizard.

## Architecture
- **State**: Riverpod providers and notifier state.
- **Navigation**: `go_router` with a 5-branch `StatefulShellRoute` (Home, Finance,
  Economy, Ask, Profile).
- **Networking**: Dio against the FastAPI `/v1` backend.
- **Charts**: `fl_chart` for indicator and budget visualisations.
- **Local storage**: `shared_preferences` (offline-first cache).
- **Auth**: `firebase_auth` only — the app never holds server or LLM API keys and does
  not embed `cloud_firestore` (the backend owns the Firestore service account).

## Backend
The app talks to the FastAPI backend in `../tadbeerai_backend` (see the root
`README.md`). Key endpoints:

- `POST /v1/assistant/chat` — Ask Tadbeer multi-agent assistant
- `GET  /v1/economy/snapshot` — macro indicators
- `GET  /v1/economy/essential-prices` (and `/{item_id}`) — commodity prices
- `GET|PUT /v1/finance` — per-user finance ledger
- `POST /users/persona`, `PUT /users/{id}` — profile & theme sync

Authenticated requests carry the Firebase ID token in the `Authorization` header.

## Configuration
No secrets are compiled into the app. The backend base URL is injected at build time:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

`API_BASE_URL` defaults to `http://10.0.2.2:8000` (the Android emulator's alias for the
host machine); use your machine's LAN IP for a physical device. The Firebase client
config lives in the gitignored `lib/firebase_options.dart`.

## Getting started
```bash
flutter pub get
flutter analyze      # 0 issues
flutter test         # 304 passed, 5 skipped (opt-in E2E)
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

## Localisation
English (`en`), Urdu (`ur`) and Roman Urdu (`ur-Latn`); catalogs live in `lib/l10n/*.arb`.
