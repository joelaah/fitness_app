# Project: PulseFit AI Trainer Marketplace, Razorpay Split Payments & E2E Encrypted Chat

## Architecture
PulseFit AI is a Flutter Web & Mobile fitness tracking application backed by Supabase and FastAPI:
1. **Frontend / Client**: Flutter 3.x (`D:\fitness_app`) with BLoC + Provider state management, Freezed models, Google Fonts (Poppins & Inter), and a Dark/Neon PulseFit design system (`#0F172A` background, `#00E676` Electric Mint primary CTA). Uses `cryptography: ^2.7.0` for web-compatible client-side cryptographic primitives (X25519 + AES-256-GCM), Supabase Realtime for WebSocket event streams, and an abstract `RazorpayBridge` for cross-platform payment checkout.
2. **Database & Storage**: Supabase PostgreSQL (`supabase_schema.sql` and `02_marketplace_payments_chat.sql`) enforcing strict Row-Level Security (RLS) across 10 tables: `profiles`, `workout_sessions`, `workout_exercises`, `workout_sets`, `ai_recommendations`, `trainer_profiles`, `payment_transactions`, `chat_conversations`, `chat_messages`, `encryption_keys`. Uses `(select auth.uid())` subquery wrapping for high-throughput isolation with zero cross-tenant leakage.
3. **Backend Service**: Python FastAPI service (`D:\Rag\api.py`) with a dedicated `payment_router.py` (`/payments` prefix) handling Razorpay split order creation, default 10% platform fee deduction, atomic idempotency deduplication via database unique constraints, HMAC-SHA256 signature verification, and AES-256-GCM encryption at rest for sensitive transaction metadata.
4. **End-to-End Encryption Protocol**: Signal-protocol-style client-side key agreement. Users publish X25519 public keys to `encryption_keys`. Chat participants establish a shared secret via X25519 ECDH, derive a 256-bit symmetric key via HKDF-SHA256, and encrypt messages client-side using AES-256-GCM with fresh 96-bit CSPRNG nonces and 128-bit authentication tags. Server stores only ciphertext.
5. **Real-Time Synchronization & Metadata**: Ephemeral typing indicators use Supabase Realtime Broadcast channels (avoiding DB bloat). Read receipts update `chat_messages.read_at` with `REPLICA IDENTITY FULL` streaming real-time status to senders. Client UUIDs enforce idempotent message deduplication.

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| F1 | Supabase DB Schema & Migration | 5 new tables (`trainer_profiles`, `payment_transactions`, `chat_conversations`, `chat_messages`, `encryption_keys`) + additive profiles SELECT policy | M1 | Survey / R4 |
| F2 | RLS Multi-Tenant Security & Staging Sync | Strict RLS policies on all tables ensuring 2-party isolation, synced with staging mock Supabase server | M1 | Survey / R4 |
| F3 | FastAPI Payment Router & Configuration | `/payments/config` providing configurable platform fee (default 10%), currency, and key configuration | M2 | Survey / R1, R2 |
| F4 | Razorpay Split Order Creation & Route Transfers | `/payments/create-order` calculating exact platform cut and net trainer payout in paise, with sandbox fallback | M2 | Survey / R2 |
| F5 | Payment Idempotency Engine | Atomic idempotency key deduplication returning cached order on replay without duplicate charge | M2 | Survey / R2 |
| F6 | Payment Verification & Webhook Signatures | HMAC-SHA256 signature verification on `/payments/verify` and `/payments/webhook` transitioning status to captured | M2 | Survey / R2 |
| F7 | Payment Encryption at Rest & In Transit | TLS 1.3/HSTS in transit and AES-256-GCM encryption for sensitive transaction metadata at rest | M2 | Survey / R2 |
| F8 | Trainer Model & Auth Upgrade Service | Anonymous-to-permanent account upgrade via `supabase.auth.updateUser` and Freezed `TrainerProfile` model | M3 | Survey / R1 |
| F9 | Trainer Discovery & Filter UI | Search bar, specialty filter chips, hourly rate range slider, rating placeholder, and trainer list screen | M3 | Survey / R1 |
| F10 | Trainer Profile Creation & Dashboard | Profile registration/edit form, certifications, bio, and dashboard with transparent platform fee cut | M3 | Survey / R1 |
| F11 | Razorpay Checkout Bridge & Transaction History | Abstract `RazorpayBridge`, web JS interop, test mode support, and user/trainer payment history screen | M4 | Survey / R2 |
| F12 | Signal-Style E2E Encryption Engine | X25519 key agreement, HKDF-SHA256, and AES-256-GCM encryption/decryption via `cryptography: ^2.7.0` | M5 | Survey / R3 |
| F13 | Encrypted Real-Time Chat UI & Deduplication | Supabase Realtime channel, client UUID deduplication, dark/neon PulseFit theme, and 1-on-1 chat screen | M5 | Survey / R3 |
| F14 | Ephemeral Typing Indicators & Read Receipts | Realtime broadcast channel for typing status and `chat_messages.read_at` updates for read checkmarks | M5 | Survey / R3 |
| F15 | Main Navigation & Theme Integration | MainScreen bottom navigation tab for Trainers, header action icons for chat and payments, design token compliance | M6 | Survey / AC |
| F16 | Web Release Build Verification | Clean compilation of `flutter build web --release` without errors | M6 | Survey / AC |
| F17 | Opaque-Box E2E Testing Suite (Tiers 1-4) | Comprehensive test suite (Dart unit tests + Python integration tests) covering idempotency, fee math, E2EE, and RLS | Final Milestone | ORIGINAL_REQUEST |
| F18 | Adversarial Coverage Hardening (Tier 5) | White-box stress testing, tamper injection, and edge case coverage validation | Final Milestone | ORIGINAL_REQUEST |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| M1 | Database Schema, Migration & RLS Security | F1, F2: SQL migration file, table schemas, check constraints, RLS policies, mock Supabase server update | none | DONE |
| M2 | FastAPI Payment Router & Backend Engine | F3, F4, F5, F6, F7: `payment_router.py`, Razorpay route orders, 10% fee calculation, idempotency replay, HMAC verify, AES-GCM at rest | M1 | DONE |
| M3 | Trainer Registration, Discovery & Auth Upgrade | F8, F9, F10: `lib/features/auth/`, `lib/features/trainers/`, anonymous upgrade, discovery search/filter, profile registration, fee dashboard | M1 | DONE |
| M4 | Razorpay Checkout Integration & Payment History | F11: `lib/features/payments/`, `RazorpayBridge`, checkout flow, transaction history screen, fee breakdown | M2, M3 | DONE |
| M5 | E2E Encrypted Real-Time Chat System | F12, F13, F14: `lib/features/chat/`, `CryptoService`, X25519 ECDH, AES-256-GCM, Supabase Realtime, typing indicators, read receipts | M1, M3 | DONE |
| M6 | Main Navigation, Design System & Web Build | F15, F16: `lib/main_screen.dart`, header icons, Dark/Neon PulseFit theme alignment, `flutter build web --release` verification | M3, M4, M5 | DONE |
| Final | E2E Test Pass (Tiers 1-4) & Adversarial Hardening (Tier 5) | F17, F18: 100% pass on comprehensive E2E test suite, adversarial coverage hardening with Challengers | M6, E2E Track | DONE |
| E2E | E2E Testing Track (Parallel) | Test infrastructure (`TEST_INFRA.md`), Python integration suite, Dart unit test suite across Tiers 1-4 | none | DONE |

## Code Layout
```text
D:\fitness_app\
├── lib/
│   ├── core/
│   │   ├── config/supabase_config.dart
│   │   ├── theme/ (app_colors.dart, app_theme.dart)
│   │   └── widgets/ (elevated_card.dart, primary_button.dart, etc.)
│   ├── features/
│   │   ├── auth/
│   │   │   ├── screens/auth_upgrade_dialog.dart
│   │   │   └── services/auth_service.dart
│   │   ├── trainers/
│   │   │   ├── bloc/ (trainer_bloc.dart, trainer_event.dart, trainer_state.dart)
│   │   │   ├── models/ (trainer_profile.dart)
│   │   │   ├── screens/ (trainer_discovery_screen.dart, trainer_detail_screen.dart, trainer_registration_screen.dart, trainer_dashboard_screen.dart)
│   │   │   ├── services/trainer_service.dart
│   │   │   └── widgets/ (trainer_card.dart, specialty_chip.dart)
│   │   ├── payments/
│   │   │   ├── bloc/ (payment_bloc.dart, payment_event.dart, payment_state.dart)
│   │   │   ├── models/ (payment_transaction.dart)
│   │   │   ├── screens/ (payment_history_screen.dart, checkout_bottom_sheet.dart)
│   │   │   └── services/ (payment_service.dart, razorpay_bridge.dart, razorpay_bridge_web.dart, razorpay_bridge_stub.dart)
│   │   └── chat/
│   │       ├── bloc/ (chat_bloc.dart, chat_event.dart, chat_state.dart)
│   │       ├── models/ (chat_conversation.dart, chat_message.dart, encryption_key.dart)
│   │       ├── screens/ (conversations_screen.dart, chat_screen.dart)
│   │       ├── services/ (crypto_service.dart, chat_realtime_service.dart)
│   │       └── widgets/ (chat_bubble.dart, typing_indicator.dart, e2e_badge.dart)
│   ├── main.dart
│   └── main_screen.dart
├── supabase_schema.sql
├── migrations/
│   └── 02_marketplace_payments_chat.sql
├── tests/
│   ├── integration/
│   │   └── test_payments_and_chat.py
│   └── e2e/
│       ├── test_e2e_marketplace.py
│       └── test_crypto_e2ee.py
├── test/
│   ├── crypto_service_test.dart
│   ├── trainer_bloc_test.dart
│   └── payment_idempotency_test.dart
└── D:\Rag\
    ├── api.py
    └── payment_router.py
```

## Interface Contracts

### 1. Database Schema ↔ Backend & Frontend
- `trainer_profiles`:
  - `id`: UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE
  - `bio`: TEXT, `certifications`: TEXT[], `specialties`: TEXT[], `experience_years`: INT
  - `hourly_rate`: NUMERIC(10,2) CHECK (hourly_rate >= 0.00)
  - `rating`: NUMERIC(3,2) DEFAULT 5.00 CHECK (rating >= 0.00 AND rating <= 5.00)
  - `platform_fee_pct`: NUMERIC(5,2) DEFAULT 10.00 CHECK (platform_fee_pct >= 0.00 AND platform_fee_pct <= 100.00)
  - `is_verified`: BOOLEAN DEFAULT TRUE
  - RLS: Public SELECT `USING (true)`; Write `USING ((select auth.uid()) = id)`

- `payment_transactions`:
  - `id`: UUID PRIMARY KEY DEFAULT uuid_generate_v4()
  - `idempotency_key`: TEXT NOT NULL
  - `user_id`: UUID NOT NULL REFERENCES auth.users(id), `trainer_id`: UUID NOT NULL REFERENCES auth.users(id)
  - `amount`: NUMERIC(10,2) NOT NULL, `currency`: TEXT DEFAULT 'INR' NOT NULL
  - `platform_fee_percent`: NUMERIC(5,2) DEFAULT 10.00 NOT NULL
  - `platform_fee_amount`: NUMERIC(10,2) NOT NULL, `trainer_amount`: NUMERIC(10,2) NOT NULL
  - `razorpay_order_id`: TEXT NOT NULL, `razorpay_payment_id`: TEXT, `razorpay_signature`: TEXT
  - `status`: TEXT NOT NULL DEFAULT 'created' -- 'created', 'captured', 'failed'
  - `encrypted_metadata`: TEXT (AES-256-GCM ciphertext)
  - Constraints: `UNIQUE (user_id, idempotency_key)`, `CHECK (amount = platform_fee_amount + trainer_amount)`
  - RLS: SELECT `USING ((select auth.uid()) = user_id OR (select auth.uid()) = trainer_id)`

- `chat_conversations`:
  - `id`: UUID PRIMARY KEY DEFAULT uuid_generate_v4()
  - `user_id`: UUID NOT NULL REFERENCES auth.users(id), `trainer_id`: UUID NOT NULL REFERENCES auth.users(id)
  - Constraints: `UNIQUE (user_id, trainer_id)`
  - RLS: SELECT/INSERT `USING ((select auth.uid()) = user_id OR (select auth.uid()) = trainer_id)`

- `chat_messages`:
  - `id`: UUID PRIMARY KEY, `conversation_id`: UUID NOT NULL REFERENCES chat_conversations(id)
  - `sender_id`: UUID NOT NULL REFERENCES auth.users(id)
  - `client_uuid`: UUID NOT NULL UNIQUE
  - `ciphertext`: TEXT NOT NULL, `nonce`: TEXT NOT NULL, `mac`: TEXT NOT NULL
  - `is_read`: BOOLEAN DEFAULT FALSE, `read_at`: TIMESTAMPTZ
  - RLS: SELECT/INSERT `USING (EXISTS (SELECT 1 FROM chat_conversations c WHERE c.id = conversation_id AND ((select auth.uid()) = c.user_id OR (select auth.uid()) = c.trainer_id)))`

- `encryption_keys`:
  - `user_id`: UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE
  - `public_key`: TEXT NOT NULL (32-byte X25519 public key base64)
  - RLS: SELECT `USING ((select auth.role()) = 'authenticated')`; Write `USING ((select auth.uid()) = user_id)`

### 2. FastAPI Backend ↔ Frontend Client
- `GET /payments/config`:
  - Response: `{"platform_fee_percentage": 10.0, "currency": "INR", "razorpay_key_id": "..."}`
- `POST /payments/create-order`:
  - Request: `{"trainer_id": "...", "amount": 1000.0, "idempotency_key": "uuid"}`
  - Response: `{"transaction_id": "...", "order_id": "...", "amount": 1000.0, "platform_fee_amount": 100.0, "trainer_amount": 900.0, "replayed": false}`
- `POST /payments/verify`:
  - Request: `{"razorpay_order_id": "...", "razorpay_payment_id": "...", "razorpay_signature": "..."}`
  - Response: `{"status": "captured", "transaction_id": "..."}`
- `GET /payments/history`:
  - Response: `{"transactions": [...]}`

### 3. Cryptographic Protocol Contract
- **Curve**: Curve25519 (X25519)
- **Key Derivation**: HKDF-SHA256 with Salt = `b"PulseFit-E2EE-v1-Salt"`, Info = `b"PulseFit-AES-256-GCM-Key"`, Output Length = 32 bytes (256 bits).
- **Authenticated Encryption**: AES-256-GCM with fresh random 96-bit (12-byte) CSPRNG nonce.
- **Wire Format**:
  - `ciphertext`: Base64 string of raw AES ciphertext + 16-byte GCM tag.
  - `nonce`: Base64 string of 12-byte IV.
  - `mac`: Base64 string of 16-byte authentication tag (or embedded in ciphertext).
