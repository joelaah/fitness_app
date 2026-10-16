# PulseFit AI End-to-End Test Infrastructure Specification

**Document Version**: 2.0.0  
**Target Environment**: Windows / Linux / Docker Staging / Web  
**Author**: E2E Test Suite Architect (`teamwork_preview_test_writer_e2e`)  
**Scope**: Opaque-Box, Requirement-Driven E2E Test Suite (Tiers 1–4) covering Trainer Marketplace, Razorpay Split Payments, Idempotent Flows, and E2E Encrypted Chat.

---

## 1. Test Philosophy & Methodology

The PulseFit AI End-to-End (E2E) test infrastructure operates under three foundational engineering principles:

### 1.1 Opaque-Box Validation
All tests evaluate system behavior exclusively through external observable boundaries without inspecting private internal state:
- **RESTful Endpoints & Gateways**:
  - Payment Router (`/payments/config`, `/payments/create-order`, `/payments/verify`, `/payments/webhook`, `/payments/history`).
  - Supabase PostgREST & Auth (`/rest/v1/trainer_profiles`, `/rest/v1/payment_transactions`, `/rest/v1/chat_conversations`, `/rest/v1/chat_messages`, `/rest/v1/encryption_keys`, `/auth/v1/*`).
  - FastAPI RAG Service (`/health`, `/recommend`, `/chat`).
- **Raw Database Row & Cryptographic State Verification**:
  - Verifying that sensitive payment metadata in `payment_transactions.encrypted_metadata` is authenticated AES-256-GCM ciphertext, completely unreadable without the encryption key.
  - Verifying that chat payloads in `chat_messages.ciphertext` contain authenticated ciphertext with 96-bit CSPRNG nonces, and that server logs or raw queries never expose plaintext.
  - Verifying check constraints (e.g. $amount = platform\_fee + trainer\_amount$, ratings between $0.0$ and $5.0$, non-negative rates).
- **Row-Level Security (RLS) Isolation**:
  - Simulating external authenticated clients (Client Alice, Coach Bob, Attacker Eve) and asserting that User B receives zero records (HTTP 200 with empty list or HTTP 403 Forbidden) when attempting to access User A's private conversations, messages, or payments.
- **Idempotency Deduplication**:
  - Simulating network packet retries or rapid double-submissions with identical client-generated UUIDs (`idempotency_key` and `client_uuid`) to verify that duplicate charges and duplicated message rows are prevented at the database and API level.

### 1.2 Authoritative Expected Output Derivation
Every test assertion is derived from authoritative project specifications:
- **Platform Fee Mathematics**: 
  - Ground truth: $Platform\_Fee = \text{round}(Amount \times \frac{Platform\_Fee\_Pct}{100}, 2)$ using `ROUND_HALF_UP`.
  - Payout split: $Trainer\_Amount = Amount - Platform\_Fee$.
  - Exact constraint: $Amount == Platform\_Fee + Trainer\_Amount$.
- **Razorpay Route Order Structure**:
  - Currency conversion to paise: $P = Amount \times 100$.
  - Transfer payload: `[{"account": trainer_acc, "amount": trainer_paise, "currency": "INR"}]`.
- **HMAC-SHA256 Signature Contract**:
  - Client verify: $\text{HMAC-SHA256}(Secret, \text{"order_id|payment_id"})$.
  - Webhook verify: $\text{HMAC-SHA256}(Webhook\_Secret, raw\_body)$ matched via constant-time digest comparison.
- **Signal-Style E2EE Cryptographic Protocol**:
  - Diffie-Hellman: Curve25519 (X25519) producing 32-byte shared secret.
  - Key Derivation: HKDF-SHA256 with Salt `b"PulseFit-E2EE-v1-Salt"` and Info `b"PulseFit-AES-256-GCM-Key"` producing 256-bit AES key.
  - Authenticated Encryption: AES-256-GCM with fresh 12-byte CSPRNG IV; wire format `Base64(Ciphertext || 16-byte Tag)`.

### 1.3 Progressive Testability & Self-Containment
- **Self-Contained Execution**: Each test provisions its own unique tenant UUIDs and cleans up or isolates state.
- **Offline / Staging Dual Mode**: Tests execute deterministically against the in-memory staging engine or against live services when environment variables (`STAGING_SUPABASE_URL`, `RAG_API_URL`, `PAYMENT_API_URL`) are specified.

---

## 2. Feature Inventory Mapping (F1–F18)

| Feature ID | Feature Name | Milestone | Specifications & Contracts | E2E Verification Focus |
|---|---|---|---|---|
| **F1** | Supabase DB Schema & Migration | M1 | `02_marketplace_payments_chat.sql` | 5 new tables (`trainer_profiles`, `payment_transactions`, `chat_conversations`, `chat_messages`, `encryption_keys`), check constraints, foreign keys, triggers. |
| **F2** | RLS Multi-Tenant Security | M1 | `(select auth.uid())` subquery policies | Strict 2-party isolation on payments, chat conversations, and messages; public verified trainer discovery. |
| **F3** | FastAPI Payment Router & Config | M2 | `GET /payments/config` | Returns default 10% platform fee, currency (`INR`), public key config. |
| **F4** | Razorpay Split Order Creation | M2 | `POST /payments/create-order` | 10% platform cut deduction, net trainer payout in paise, transfer splits. |
| **F5** | Payment Idempotency Engine | M2 | `UNIQUE (user_id, idempotency_key)` | Duplicate request replay returns cached order ID and split without creating new charge. |
| **F6** | Payment Verification & Webhooks | M2 | `POST /payments/verify`, `/payments/webhook` | Constant-time HMAC-SHA256 signature verification, transitions status to `captured`, rejects tampered signatures. |
| **F7** | Payment Encryption at Rest | M2 | AES-256-GCM on `encrypted_metadata` | Verifies DB column stores authenticated ciphertext; decrypts with `PAYMENT_ENCRYPTION_KEY`. |
| **F8** | Trainer Model & Auth Upgrade | M3 | Freezed `TrainerProfile`, auth upgrade | Anonymous-to-permanent email/OAuth upgrade requirement before profile registration. |
| **F9** | Trainer Discovery & Filter UI | M3 | Search bar, specialty chips, slider | Filter by specialty, hourly rate range slider, search query matching, rating placeholder. |
| **F10** | Trainer Profile & Dashboard | M3 | Profile form, fee breakdown | Creation of verified trainer profiles, transparent platform fee cut visibility. |
| **F11** | Razorpay Checkout Bridge & History | M4 | `RazorpayBridge`, payment history screen | Payment transaction history view for both users (payer) and trainers (payee). |
| **F12** | Signal-Style E2E Encryption Engine | M5 | X25519, HKDF-SHA256, AES-256-GCM | Client key agreement, key derivation, authenticated encryption/decryption, bit-flip tamper rejection. |
| **F13** | Encrypted Chat UI & Deduplication | M5 | `client_uuid` deduplication, dark/neon theme | 1-on-1 chat screen, DB ciphertext verification, client UUID deduplication of retries. |
| **F14** | Ephemeral Typing & Read Receipts | M5 | Broadcast channel, `read_at` timestamps | Realtime broadcast for typing indicators; `REPLICA IDENTITY FULL` for read checkmarks. |
| **F15** | Main Navigation & Theme Integration | M6 | `MainScreen` bottom tabs, action icons | Trainers tab, header chat/payment icons, Dark/Neon PulseFit theme adherence. |
| **F16** | Web Release Build Verification | M6 | `flutter build web --release` | Clean compilation of Flutter web assets without errors. |
| **F17** | Opaque-Box E2E Testing Suite (Tiers 1–4) | E2E | Python integration & Dart unit tests | 100% pass across core marketplace, payment split, crypto, and security test suites. |
| **F18** | Adversarial Coverage Hardening (Tier 5) | E2E | Fuzzing, tamper injection, concurrency | Bit-flip corruptions, rapid replay race conditions, cross-tenant injection attempts. |

---

## 3. Test Suite Architecture & Directory Layout

```
D:\fitness_app\
├── TEST_INFRA.md                          # Test infrastructure specification (this document)
├── TEST_READY.md                          # Published test execution certification across Tiers 1-4
├── tests/
│   ├── integration/
│   │   ├── test_multi_user.py             # Multi-tenant staging integration tests
│   │   └── test_payments_and_chat.py      # Marketplace, Razorpay split payments & E2EE chat integration
│   ├── e2e/
│   │   ├── conftest.py                    # Pytest configuration, fixtures & mock engine bindings
│   │   ├── harness/
│   │   │   ├── catalog_reader.py          # Exercise catalog verification
│   │   │   ├── mock_staging_engine.py     # In-memory PostgREST + GoTrue + RLS engine
│   │   │   ├── rag_test_adapter.py        # RAG microservice test adapter
│   │   │   ├── metrics_engine.py          # Latency & throughput statistics
│   │   │   └── report_validator.py        # HTML & Markdown report schema validator
│   │   ├── test_tier1_feature_coverage.py # Tier 1: Isolated core feature tests (F1-F11)
│   │   ├── test_tier2_boundaries.py       # Tier 2: Boundary, limit, and stress tests
│   │   ├── test_tier3_interactions.py     # Tier 3: Pairwise cross-feature interactions
│   │   ├── test_tier4_scenarios.py        # Tier 4: Real-world multi-user gym workload scenarios
│   │   ├── test_e2e_marketplace.py        # Tier 4: E2E Trainer Marketplace & Payment Flows
│   │   └── test_crypto_e2ee.py            # Deep E2E Cryptography & Tamper Verification
│   └── test_mock_supabase_and_seed.py     # PostgREST CRUD & seed pipeline tests
└── test/
    ├── crypto_service_test.dart           # Dart unit test: X25519, HKDF, AES-GCM crypto engine
    ├── trainer_bloc_test.dart             # Dart unit test: Trainer discovery, search & filter BLoC
    └── payment_idempotency_test.dart      # Dart unit test: Payment models, fee split & idempotency
```

---

## 4. Coverage Thresholds & Hierarchy

The test suite enforces a rigorous 4-tier testing hierarchy with strict coverage thresholds:

```
+───────────────────────────────────────────────────────────────────────────────+
|  Tier 4: Real-World Scenarios (Marketplace Lifecycles, E2EE Chat Journeys)    |
+───────────────────────────────────────────────────────────────────────────────+
|  Tier 3: Pairwise Interactions (Search+Booking, Key Exchange+Messaging)       |
+───────────────────────────────────────────────────────────────────────────────+
|  Tier 2: Boundary & Stress (Negative Rates, Tampered Signatures, IV Reuse)   |
+───────────────────────────────────────────────────────────────────────────────+
|  Tier 1: Core Feature Coverage (F1–F14 Isolated Functional Verification)      |
+───────────────────────────────────────────────────────────────────────────────+
```

### Coverage Threshold Summary:
- **Tier 1 (Core Feature Coverage)**: $\ge 5$ tests per feature across core domains $\rightarrow$ **$\ge 60$ tests**.
- **Tier 2 (Boundary & Stress Coverage)**: Edge cases, zero values, malformed inputs $\rightarrow$ **$\ge 55$ tests**.
- **Tier 3 (Pairwise Interactions)**: Cross-module interfaces $\rightarrow$ **$\ge 20$ tests**.
- **Tier 4 (Real-World Scenarios)**: Multi-user lifecycles and realistic gym/trainer workflows $\rightarrow$ **$\ge 10$ complex scenarios**.
- **Total Test Suite**: **$\ge 180$ automated tests** with 100% assertion pass rate.

---

## 5. Tier 4 Real-World Application Scenarios

### Scenario 1: Complete Trainer Discovery, Booking & Split Payment Journey
- **User Role**: Client Athlete (Alice) searching for a verified Strength & Conditioning coach.
- **Workflow**:
  1. Alice queries `/rest/v1/trainer_profiles` filtering for `specialties=cs.{"Strength"}` and `hourly_rate=lte.2000`.
  2. System returns Coach Bob's profile with rating 4.95 and verified badge.
  3. Alice initiates booking for ₹1,500 by submitting `POST /payments/create-order` with unique `idempotency_key`.
  4. Backend computes 10% platform fee (₹150.00) and trainer payout (₹1,350.00).
  5. Backend generates Razorpay order with route transfer to Bob's linked account and returns `order_id`.
  6. Alice completes checkout; client sends valid HMAC-SHA256 signature to `POST /payments/verify`.
  7. Transaction transitions to `captured`; payment metadata is encrypted at rest via AES-256-GCM.
- **Assertions**:
  - Exact split math: $1500.00 = 150.00 + 1350.00$.
  - Both Alice and Bob can view the captured transaction in `/payments/history`.
  - Attacker Eve cannot access the transaction record.

### Scenario 2: Double-Click Checkout & Network Flake Idempotency Replay
- **Context**: Unstable mobile network causes client to retry checkout or athlete double-taps payment button within 200ms.
- **Workflow**:
  1. Client sends initial `POST /payments/create-order` with `idempotency_key="tx_idem_98765"`.
  2. Order is created and persisted with transaction ID $T_1$.
  3. Client network connection drops before receiving response; client retries identical request with same key.
  4. Database `UNIQUE (user_id, idempotency_key)` detects existing transaction.
  5. Backend returns cached order $T_1$ with `replayed=True`.
- **Assertions**:
  - Zero duplicate orders created in Razorpay gateway.
  - Zero duplicate rows in `payment_transactions`.
  - Transaction amounts and platform fees match the original transaction exactly.

### Scenario 3: Real-Time E2E Encrypted Chat Session with Bit-Level Tamper Resilience
- **Context**: 1-on-1 private coaching consultation between Alice and Coach Bob.
- **Workflow**:
  1. Alice publishes X25519 public key $A_{pub}$ to `encryption_keys`. Bob publishes $B_{pub}$.
  2. Alice establishes shared secret $S_{AB} = \text{X25519}(A_{priv}, B_{pub})$ and derives 256-bit AES key via HKDF.
  3. Bob independently establishes $S_{BA} = \text{X25519}(B_{priv}, A_{pub})$ and derives identical AES key.
  4. Alice encrypts workout progress message with fresh 96-bit CSPRNG IV and uploads ciphertext to `chat_messages`.
  5. Server database row inspection verifies: `ciphertext` is unreadable Base64; `original_message` is nowhere in the DB row.
  6. Bob's client retrieves DB row, decrypts payload, and recovers exact plaintext.
  7. Attacker Eve intercepts ciphertext and flips 1 bit: Bob's client attempts decryption; AES-256-GCM authentication tag verification fails, rejecting the tampered message.
- **Assertions**:
  - Server has zero-knowledge of message plaintext.
  - Plaintext fidelity: $Decrypted == Original$.
  - 100% tamper detection on ciphertext, nonce, or tag corruption.

### Scenario 4: Cross-Tenant Data Leakage & Unauthorized Access Denial (RLS Security)
- **Context**: Attacker Eve attempting unauthorized data exfiltration.
- **Workflow**:
  1. Eve authenticates with her own valid JWT.
  2. Eve queries `/rest/v1/payment_transactions` attempting to read Alice's or Bob's transactions.
  3. Eve queries `/rest/v1/chat_conversations` and `/rest/v1/chat_messages` attempting to inspect Alice-Bob chat.
  4. Eve attempts to `POST /rest/v1/chat_messages` spoofing `sender_id = Alice` into Alice-Bob conversation.
- **Assertions**:
  - RLS filters out all unauthorized records (returns 0 rows for SELECT).
  - INSERT by non-participant returns HTTP 403 Forbidden.
  - Profile updates from non-owner return HTTP 403 Forbidden.

### Scenario 5: High-Frequency Messaging Burst & Client UUID Deduplication
- **Context**: Client sends a burst of messages; mobile reconnection replays previously sent packet.
- **Workflow**:
  1. Alice sends message with `client_uuid = U_1`.
  2. Message is successfully inserted into `chat_messages`.
  3. Reconnection logic re-sends payload with same `client_uuid = U_1`.
  4. Database constraint `UNIQUE (client_uuid)` prevents duplicate insertion.
  5. Read receipt update (`read_at = NOW()`) streams to Alice via `REPLICA IDENTITY FULL`.
- **Assertions**:
  - Exactly one message bubble appears in conversation.
  - Read receipts reflect accurate timestamp.

---

## 6. Execution Commands

### 6.1 Running Full Test Suite
```powershell
python -m pytest tests/ -v
```

### 6.2 Running New Integration & E2E Suites
```powershell
python -m pytest tests/integration/test_payments_and_chat.py -v
python -m pytest tests/e2e/test_e2e_marketplace.py -v
python -m pytest tests/e2e/test_crypto_e2ee.py -v
```

### 6.3 Running Dart Client-Side Unit Tests
```powershell
flutter test test/crypto_service_test.dart
flutter test test/trainer_bloc_test.dart
flutter test test/payment_idempotency_test.dart
```

---

## 7. Pass / Fail Acceptance Criteria
1. All Python tests under `tests/` exit with code 0 (`100% pass`).
2. Zero cross-tenant data leakage across all RLS test queries.
3. 100% mathematical accuracy on platform fee calculations ($Amount == Fee + Trainer$).
4. 100% idempotency enforcement on repeated payment/message tokens.
5. 100% rejection rate on tampered ciphertext, corrupted nonces, or invalid signatures.
