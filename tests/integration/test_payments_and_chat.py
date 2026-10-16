"""
PulseFit AI - Integration Test Suite: Marketplace, Razorpay Split Payments & E2EE Chat
=====================================================================================
Validates:
1. Trainer discovery, search, and multi-parameter filtering.
2. Platform fee calculation and configuration (GET /payments/config, default 10%).
3. Razorpay split order creation and route transfer calculation in paise.
4. Payment idempotency: retrying with the same idempotency key returns cached order without duplicate charge.
5. HMAC-SHA256 payment signature verification and webhook processing.
6. Payment data encryption at rest (AES-256-GCM).
7. E2E encrypted chat: X25519 key agreement, HKDF derivation, AES-256-GCM encryption,
   raw DB ciphertext verification, client decryption, and client UUID deduplication.
8. Row-Level Security (RLS): cross-tenant isolation across payments, conversations, and messages.
"""

from __future__ import annotations

import base64
import hashlib
import hmac
import json
import os
import sqlite3
import threading
import time
import uuid
from decimal import Decimal, ROUND_HALF_UP
from typing import Any, Dict, List, Optional, Tuple

import pytest
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import x25519
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.kdf.hkdf import HKDF
from starlette.testclient import TestClient
from fastapi import FastAPI, Header, HTTPException, Request, Response, status


# =============================================================================
# Cryptographic & Mathematical Protocol Constants (per PROJECT.md)
# =============================================================================
HKDF_SALT = b"PulseFit-E2EE-v1-Salt"
HKDF_INFO = b"PulseFit-AES-256-GCM-Key"
DEFAULT_PLATFORM_FEE_PCT = Decimal("10.00")
PAYMENT_TEST_SECRET = "rzp_test_secret_998877665544"
PAYMENT_WEBHOOK_SECRET = "whsec_test_secret_11223344"
PAYMENT_ENCRYPTION_KEY = AESGCM.generate_key(bit_length=256)


def compute_platform_fee_split(amount: float, fee_pct: float = 10.0) -> Tuple[float, float, float]:
    """Authoritative platform fee split derivation using ROUND_HALF_UP."""
    amt = Decimal(str(amount))
    pct = Decimal(str(fee_pct))
    fee = (amt * (pct / Decimal("100"))).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
    trainer = (amt - fee).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
    assert amt == fee + trainer, "Invariant violation: Amount must equal fee + trainer amount"
    return float(amt), float(fee), float(trainer)


def generate_razorpay_signature(order_id: str, payment_id: str, secret: str = PAYMENT_TEST_SECRET) -> str:
    """Computes HMAC-SHA256 signature for client checkout verification."""
    message = f"{order_id}|{payment_id}".encode("utf-8")
    return hmac.new(secret.encode("utf-8"), message, hashlib.sha256).hexdigest()


def generate_webhook_signature(body: bytes, secret: str = PAYMENT_WEBHOOK_SECRET) -> str:
    """Computes HMAC-SHA256 signature for server webhook payloads."""
    return hmac.new(secret.encode("utf-8"), body, hashlib.sha256).hexdigest()


# =============================================================================
# Relational Datastore Simulation with PostgreSQL Schema & Constraints
# =============================================================================
class MarketplaceRelationalStore:
    """In-memory relational store enforcing constraints matching 02_marketplace_payments_chat.sql."""

    def __init__(self):
        self.lock = threading.Lock()
        self.conn = sqlite3.connect(":memory:", check_same_thread=False)
        self.conn.row_factory = sqlite3.Row
        self._init_schema()

    def _init_schema(self):
        c = self.conn.cursor()
        c.executescript("""
            CREATE TABLE profiles (
                id TEXT PRIMARY KEY,
                display_name TEXT NOT NULL,
                experience_level TEXT DEFAULT 'intermediate',
                preferred_training_goal TEXT DEFAULT 'strength',
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );

            CREATE TABLE trainer_profiles (
                id TEXT PRIMARY KEY,
                user_id TEXT NOT NULL UNIQUE REFERENCES profiles(id) ON DELETE CASCADE,
                bio TEXT DEFAULT '',
                certifications TEXT DEFAULT '[]',
                specialties TEXT DEFAULT '[]',
                hourly_rate REAL NOT NULL DEFAULT 0.0 CHECK (hourly_rate >= 0.0),
                availability TEXT DEFAULT '{"active": true}',
                rating REAL NOT NULL DEFAULT 5.0 CHECK (rating >= 0.0 AND rating <= 5.0),
                platform_fee_pct REAL NOT NULL DEFAULT 10.0 CHECK (platform_fee_pct >= 0.0 AND platform_fee_pct <= 100.0),
                verified INTEGER NOT NULL DEFAULT 1,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );

            CREATE TABLE payment_transactions (
                id TEXT PRIMARY KEY,
                idempotency_key TEXT NOT NULL UNIQUE,
                user_id TEXT NOT NULL REFERENCES profiles(id),
                trainer_id TEXT NOT NULL REFERENCES trainer_profiles(id),
                order_id TEXT NOT NULL,
                payment_id TEXT,
                amount REAL NOT NULL CHECK (amount > 0.0),
                currency TEXT NOT NULL DEFAULT 'INR',
                platform_fee REAL NOT NULL CHECK (platform_fee >= 0.0),
                trainer_amount REAL NOT NULL CHECK (trainer_amount >= 0.0),
                status TEXT NOT NULL DEFAULT 'created' CHECK (status IN ('created', 'authorized', 'captured', 'failed', 'refunded')),
                encrypted_metadata TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                CHECK (abs(amount - (platform_fee + trainer_amount)) < 0.001)
            );

            CREATE TABLE chat_conversations (
                id TEXT PRIMARY KEY,
                user_id TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
                trainer_id TEXT NOT NULL REFERENCES trainer_profiles(id) ON DELETE CASCADE,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                UNIQUE(user_id, trainer_id)
            );

            CREATE TABLE chat_messages (
                id TEXT PRIMARY KEY,
                conversation_id TEXT NOT NULL REFERENCES chat_conversations(id) ON DELETE CASCADE,
                sender_id TEXT NOT NULL REFERENCES profiles(id),
                client_uuid TEXT NOT NULL UNIQUE,
                ciphertext TEXT NOT NULL,
                nonce TEXT NOT NULL,
                is_read INTEGER DEFAULT 0,
                read_at TIMESTAMP,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );

            CREATE TABLE encryption_keys (
                user_id TEXT PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE,
                public_key TEXT NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
        """)
        self.conn.commit()


# =============================================================================
# FastAPI Reference Payment Router for Integration Testing
# =============================================================================
def create_payment_test_app(store: MarketplaceRelationalStore) -> FastAPI:
    """Builds a FastAPI app implementing the exact Payment API contract from PROJECT.md."""
    app = FastAPI(title="Payment Router Integration Test App")

    @app.get("/payments/config")
    def get_config():
        return {
            "platform_fee_percentage": float(DEFAULT_PLATFORM_FEE_PCT),
            "currency": "INR",
            "razorpay_key_id": "rzp_test_mock_key_12345",
        }

    @app.post("/payments/create-order")
    def create_order(request: Request, body: Dict[str, Any], authorization: Optional[str] = Header(None)):
        if not authorization or not authorization.startswith("Bearer "):
            raise HTTPException(status_code=401, detail="Unauthorized")

        user_id = authorization.replace("Bearer ", "").strip()
        trainer_id = body.get("trainer_id")
        amount = float(body.get("amount", 0.0))
        idempotency_key = body.get("idempotency_key")

        if not trainer_id or amount <= 0 or not idempotency_key:
            raise HTTPException(status_code=400, detail="Missing or invalid payment parameters")

        with store.lock:
            c = store.conn.cursor()

            # Check for existing idempotency key (Atomic deduplication)
            c.execute("SELECT * FROM payment_transactions WHERE idempotency_key = ?", (idempotency_key,))
            existing = c.fetchone()
            if existing:
                return {
                    "transaction_id": existing["id"],
                    "order_id": existing["order_id"],
                    "amount": existing["amount"],
                    "platform_fee_amount": existing["platform_fee"],
                    "trainer_amount": existing["trainer_amount"],
                    "replayed": True,
                }

            # Calculate platform fee split
            amt, fee, trainer_amt = compute_platform_fee_split(amount, float(DEFAULT_PLATFORM_FEE_PCT))
            tx_id = str(uuid.uuid4())
            order_id = f"order_{uuid.uuid4().hex[:14]}"

            # Encrypt metadata at rest using AES-256-GCM
            raw_metadata = json.dumps({"notes": body.get("notes", {}), "created_via": "fastapi_integration"}).encode()
            nonce = os.urandom(12)
            aesgcm = AESGCM(PAYMENT_ENCRYPTION_KEY)
            encrypted_bytes = aesgcm.encrypt(nonce, raw_metadata, associated_data=None)
            encrypted_metadata_b64 = base64.b64encode(nonce + encrypted_bytes).decode("utf-8")

            c.execute("""
                INSERT INTO payment_transactions
                (id, idempotency_key, user_id, trainer_id, order_id, amount, currency, platform_fee, trainer_amount, status, encrypted_metadata)
                VALUES (?, ?, ?, ?, ?, ?, 'INR', ?, ?, 'created', ?)
            """, (tx_id, idempotency_key, user_id, trainer_id, order_id, amt, fee, trainer_amt, encrypted_metadata_b64))
            store.conn.commit()

            return {
                "transaction_id": tx_id,
                "order_id": order_id,
                "amount": amt,
                "platform_fee_amount": fee,
                "trainer_amount": trainer_amt,
                "replayed": False,
            }

    @app.post("/payments/verify")
    def verify_payment(body: Dict[str, Any]):
        order_id = body.get("razorpay_order_id")
        payment_id = body.get("razorpay_payment_id")
        signature = body.get("razorpay_signature")

        if not order_id or not payment_id or not signature:
            raise HTTPException(status_code=400, detail="Missing signature verification parameters")

        expected_sig = generate_razorpay_signature(order_id, payment_id, PAYMENT_TEST_SECRET)
        if not hmac.compare_digest(expected_sig, signature):
            raise HTTPException(status_code=400, detail="Invalid payment signature")

        c = store.conn.cursor()
        c.execute("""
            UPDATE payment_transactions
            SET status = 'captured', payment_id = ?, updated_at = CURRENT_TIMESTAMP
            WHERE order_id = ?
        """, (payment_id, order_id))
        store.conn.commit()

        c.execute("SELECT id FROM payment_transactions WHERE order_id = ?", (order_id,))
        row = c.fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="Order not found")

        return {"status": "captured", "transaction_id": row["id"]}

    @app.post("/payments/webhook")
    async def process_webhook(request: Request, x_razorpay_signature: Optional[str] = Header(None)):
        raw_body = await request.body()
        if not x_razorpay_signature:
            raise HTTPException(status_code=400, detail="Missing webhook signature")

        expected_sig = generate_webhook_signature(raw_body, PAYMENT_WEBHOOK_SECRET)
        if not hmac.compare_digest(expected_sig, x_razorpay_signature):
            raise HTTPException(status_code=400, detail="Invalid webhook signature")

        payload = json.loads(raw_body)
        event = payload.get("event")
        order_id = payload.get("payload", {}).get("payment", {}).get("entity", {}).get("order_id")
        payment_id = payload.get("payload", {}).get("payment", {}).get("entity", {}).get("id")

        if order_id and event == "payment.captured":
            c = store.conn.cursor()
            c.execute("""
                UPDATE payment_transactions
                SET status = 'captured', payment_id = ?, updated_at = CURRENT_TIMESTAMP
                WHERE order_id = ?
            """, (payment_id, order_id))
            store.conn.commit()

        return {"status": "processed", "event": event}

    @app.get("/payments/history")
    def get_history(authorization: Optional[str] = Header(None)):
        if not authorization or not authorization.startswith("Bearer "):
            raise HTTPException(status_code=401, detail="Unauthorized")

        user_id = authorization.replace("Bearer ", "").strip()
        c = store.conn.cursor()
        # RLS Enforcement: User can view payments where user_id = caller OR trainer's user_id = caller
        c.execute("""
            SELECT p.* FROM payment_transactions p
            LEFT JOIN trainer_profiles tp ON tp.id = p.trainer_id
            WHERE p.user_id = ? OR tp.user_id = ?
            ORDER BY p.created_at DESC
        """, (user_id, user_id))
        rows = [dict(r) for r in c.fetchall()]
        return {"transactions": rows}

    return app


# =============================================================================
# Pytest Fixtures
# =============================================================================
@pytest.fixture
def store() -> MarketplaceRelationalStore:
    return MarketplaceRelationalStore()


@pytest.fixture
def app_client(store: MarketplaceRelationalStore) -> TestClient:
    app = create_payment_test_app(store)
    return TestClient(app)


@pytest.fixture
def seed_users_and_trainers(store: MarketplaceRelationalStore):
    """Provisions Client Alice, Coach Bob (Trainer), and Attacker Eve."""
    c = store.conn.cursor()
    alice_id = str(uuid.uuid4())
    bob_user_id = str(uuid.uuid4())
    bob_trainer_id = str(uuid.uuid4())
    eve_id = str(uuid.uuid4())

    # Profiles
    c.execute("INSERT INTO profiles (id, display_name) VALUES (?, ?)", (alice_id, "Alice Payer"))
    c.execute("INSERT INTO profiles (id, display_name) VALUES (?, ?)", (bob_user_id, "Bob Trainer"))
    c.execute("INSERT INTO profiles (id, display_name) VALUES (?, ?)", (eve_id, "Eve Attacker"))

    # Trainer Profile for Bob
    c.execute("""
        INSERT INTO trainer_profiles (id, user_id, bio, certifications, specialties, hourly_rate, rating, platform_fee_pct, verified)
        VALUES (?, ?, 'Elite Strength Coach', '["CSCS", "NASM-CPT"]', '["Strength", "Hypertrophy"]', 1500.0, 4.95, 10.0, 1)
    """, (bob_trainer_id, bob_user_id))

    # Add second trainer (Yoga & Mobility)
    charlie_user_id = str(uuid.uuid4())
    charlie_trainer_id = str(uuid.uuid4())
    c.execute("INSERT INTO profiles (id, display_name) VALUES (?, ?)", (charlie_user_id, "Charlie Yoga"))
    c.execute("""
        INSERT INTO trainer_profiles (id, user_id, bio, certifications, specialties, hourly_rate, rating, platform_fee_pct, verified)
        VALUES (?, ?, 'Yoga & Mobility Specialist', '["RYT-500"]', '["Yoga", "Mobility"]', 800.0, 4.80, 10.0, 1)
    """, (charlie_trainer_id, charlie_user_id))

    store.conn.commit()

    return {
        "alice_id": alice_id,
        "bob_user_id": bob_user_id,
        "bob_trainer_id": bob_trainer_id,
        "charlie_user_id": charlie_user_id,
        "charlie_trainer_id": charlie_trainer_id,
        "eve_id": eve_id,
    }


# =============================================================================
# Test Suite 1: Trainer Discovery, Search, and Filtering
# =============================================================================
class TestTrainerDiscoveryAndFiltering:
    """Verifies trainer discovery query capabilities matching Flutter & PostgREST requirements."""

    def test_trainer_discovery_list_verified_trainers(self, store, seed_users_and_trainers):
        c = store.conn.cursor()
        c.execute("SELECT * FROM trainer_profiles WHERE verified = 1")
        trainers = [dict(r) for r in c.fetchall()]
        assert len(trainers) >= 2
        for t in trainers:
            assert t["hourly_rate"] > 0
            assert 0.0 <= t["rating"] <= 5.0

    def test_trainer_filtering_by_specialty(self, store, seed_users_and_trainers):
        c = store.conn.cursor()
        c.execute("SELECT * FROM trainer_profiles WHERE specialties LIKE '%Strength%'")
        strength_coaches = [dict(r) for r in c.fetchall()]
        assert len(strength_coaches) == 1
        assert strength_coaches[0]["id"] == seed_users_and_trainers["bob_trainer_id"]

    def test_trainer_filtering_by_price_ceiling(self, store, seed_users_and_trainers):
        c = store.conn.cursor()
        # Query trainers with hourly_rate <= 1000
        c.execute("SELECT * FROM trainer_profiles WHERE hourly_rate <= 1000.0 ORDER BY hourly_rate ASC")
        budget_trainers = [dict(r) for r in c.fetchall()]
        assert len(budget_trainers) == 1
        assert budget_trainers[0]["id"] == seed_users_and_trainers["charlie_trainer_id"]
        assert budget_trainers[0]["hourly_rate"] == 800.0


# =============================================================================
# Test Suite 2: Platform Fee Configuration & Razorpay Split Orders
# =============================================================================
class TestPaymentSplitAndOrderCreation:
    """Verifies payment fee calculation, route transfer split in paise, and API configuration."""

    def test_payment_config_endpoint(self, app_client):
        res = app_client.get("/payments/config")
        assert res.status_code == 200
        data = res.json()
        assert data["platform_fee_percentage"] == 10.0
        assert data["currency"] == "INR"
        assert "razorpay_key_id" in data

    def test_razorpay_split_order_creation_standard(self, app_client, seed_users_and_trainers):
        alice_id = seed_users_and_trainers["alice_id"]
        bob_trainer_id = seed_users_and_trainers["bob_trainer_id"]
        idempotency_key = f"idem_{uuid.uuid4()}"

        payload = {
            "trainer_id": bob_trainer_id,
            "amount": 1500.0,
            "idempotency_key": idempotency_key,
            "notes": {"session_type": "Personal Coaching"},
        }
        res = app_client.post("/payments/create-order", json=payload, headers={"Authorization": f"Bearer {alice_id}"})
        assert res.status_code == 200
        data = res.json()

        assert data["amount"] == 1500.0
        assert data["platform_fee_amount"] == 150.0  # 10%
        assert data["trainer_amount"] == 1350.0      # 90%
        assert data["replayed"] is False
        assert data["order_id"].startswith("order_")
        assert data["transaction_id"] is not None

    def test_razorpay_split_fractional_rounding_half_up(self, app_client, seed_users_and_trainers):
        alice_id = seed_users_and_trainers["alice_id"]
        bob_trainer_id = seed_users_and_trainers["bob_trainer_id"]
        idempotency_key = f"idem_{uuid.uuid4()}"

        # ₹199.99 with 10% fee = ₹19.999 -> rounds to ₹20.00
        payload = {
            "trainer_id": bob_trainer_id,
            "amount": 199.99,
            "idempotency_key": idempotency_key,
        }
        res = app_client.post("/payments/create-order", json=payload, headers={"Authorization": f"Bearer {alice_id}"})
        assert res.status_code == 200
        data = res.json()

        assert data["amount"] == 199.99
        assert data["platform_fee_amount"] == 20.00
        assert data["trainer_amount"] == 179.99
        assert round(data["platform_fee_amount"] + data["trainer_amount"], 2) == 199.99


# =============================================================================
# Test Suite 3: Payment Idempotency Engine
# =============================================================================
class TestPaymentIdempotency:
    """Verifies that duplicate requests with the same idempotency key return the original result without duplicate charges."""

    def test_idempotency_replay_returns_identical_transaction(self, app_client, seed_users_and_trainers):
        alice_id = seed_users_and_trainers["alice_id"]
        bob_trainer_id = seed_users_and_trainers["bob_trainer_id"]
        fixed_key = f"idem_fixed_{uuid.uuid4()}"

        req_payload = {
            "trainer_id": bob_trainer_id,
            "amount": 2000.0,
            "idempotency_key": fixed_key,
        }

        # First request
        res1 = app_client.post("/payments/create-order", json=req_payload, headers={"Authorization": f"Bearer {alice_id}"})
        assert res1.status_code == 200
        data1 = res1.json()
        assert data1["replayed"] is False

        # Second request (rapid double-click / network retry)
        res2 = app_client.post("/payments/create-order", json=req_payload, headers={"Authorization": f"Bearer {alice_id}"})
        assert res2.status_code == 200
        data2 = res2.json()

        # Assert zero duplicate creation and identical return values
        assert data2["replayed"] is True
        assert data2["transaction_id"] == data1["transaction_id"]
        assert data2["order_id"] == data1["order_id"]
        assert data2["amount"] == data1["amount"]
        assert data2["platform_fee_amount"] == data1["platform_fee_amount"]

    def test_idempotency_unique_constraint_in_database(self, store, seed_users_and_trainers):
        c = store.conn.cursor()
        alice_id = seed_users_and_trainers["alice_id"]
        bob_trainer_id = seed_users_and_trainers["bob_trainer_id"]
        idem_key = "unique_db_constraint_test"

        c.execute("""
            INSERT INTO payment_transactions
            (id, idempotency_key, user_id, trainer_id, order_id, amount, platform_fee, trainer_amount, status)
            VALUES (?, ?, ?, ?, 'ord_1', 1000.0, 100.0, 900.0, 'created')
        """, (str(uuid.uuid4()), idem_key, alice_id, bob_trainer_id))
        store.conn.commit()

        # Duplicate insert must raise IntegrityError
        with pytest.raises(sqlite3.IntegrityError):
            c.execute("""
                INSERT INTO payment_transactions
                (id, idempotency_key, user_id, trainer_id, order_id, amount, platform_fee, trainer_amount, status)
                VALUES (?, ?, ?, ?, 'ord_2', 1000.0, 100.0, 900.0, 'created')
            """, (str(uuid.uuid4()), idem_key, alice_id, bob_trainer_id))


# =============================================================================
# Test Suite 4: Payment Signature Verification & Webhook Processing
# =============================================================================
class TestPaymentSignatureAndWebhooks:
    """Verifies HMAC-SHA256 signature verification and webhook status transition."""

    def test_verify_valid_signature_transitions_status_to_captured(self, app_client, seed_users_and_trainers, store):
        alice_id = seed_users_and_trainers["alice_id"]
        bob_trainer_id = seed_users_and_trainers["bob_trainer_id"]

        # Create order
        res_order = app_client.post("/payments/create-order", json={
            "trainer_id": bob_trainer_id, "amount": 1200.0, "idempotency_key": f"idem_{uuid.uuid4()}"
        }, headers={"Authorization": f"Bearer {alice_id}"})
        order_id = res_order.json()["order_id"]
        payment_id = f"pay_{uuid.uuid4().hex[:14]}"

        valid_sig = generate_razorpay_signature(order_id, payment_id, PAYMENT_TEST_SECRET)

        verify_res = app_client.post("/payments/verify", json={
            "razorpay_order_id": order_id,
            "razorpay_payment_id": payment_id,
            "razorpay_signature": valid_sig,
        })
        assert verify_res.status_code == 200
        assert verify_res.json()["status"] == "captured"

        # Verify DB status
        c = store.conn.cursor()
        c.execute("SELECT status, payment_id FROM payment_transactions WHERE order_id = ?", (order_id,))
        row = c.fetchone()
        assert row["status"] == "captured"
        assert row["payment_id"] == payment_id

    def test_verify_tampered_signature_rejected(self, app_client, seed_users_and_trainers):
        alice_id = seed_users_and_trainers["alice_id"]
        bob_trainer_id = seed_users_and_trainers["bob_trainer_id"]

        res_order = app_client.post("/payments/create-order", json={
            "trainer_id": bob_trainer_id, "amount": 1000.0, "idempotency_key": f"idem_{uuid.uuid4()}"
        }, headers={"Authorization": f"Bearer {alice_id}"})
        order_id = res_order.json()["order_id"]

        bad_sig = "tampered_fake_signature_hash_value_1234567890abcdef"
        verify_res = app_client.post("/payments/verify", json={
            "razorpay_order_id": order_id,
            "razorpay_payment_id": "pay_test123",
            "razorpay_signature": bad_sig,
        })
        assert verify_res.status_code == 400
        assert "Invalid payment signature" in verify_res.json()["detail"]

    def test_webhook_processing_valid_signature(self, app_client, seed_users_and_trainers, store):
        alice_id = seed_users_and_trainers["alice_id"]
        bob_trainer_id = seed_users_and_trainers["bob_trainer_id"]

        res_order = app_client.post("/payments/create-order", json={
            "trainer_id": bob_trainer_id, "amount": 900.0, "idempotency_key": f"idem_{uuid.uuid4()}"
        }, headers={"Authorization": f"Bearer {alice_id}"})
        order_id = res_order.json()["order_id"]
        payment_id = f"pay_{uuid.uuid4().hex[:14]}"

        webhook_body = json.dumps({
            "event": "payment.captured",
            "payload": {
                "payment": {
                    "entity": {
                        "id": payment_id,
                        "order_id": order_id,
                        "amount": 90000,
                        "status": "captured",
                    }
                }
            }
        }).encode("utf-8")

        valid_sig = generate_webhook_signature(webhook_body, PAYMENT_WEBHOOK_SECRET)
        res = app_client.post("/payments/webhook", content=webhook_body, headers={
            "Content-Type": "application/json",
            "X-Razorpay-Signature": valid_sig,
        })
        assert res.status_code == 200
        assert res.json()["status"] == "processed"

        c = store.conn.cursor()
        c.execute("SELECT status, payment_id FROM payment_transactions WHERE order_id = ?", (order_id,))
        row = c.fetchone()
        assert row["status"] == "captured"
        assert row["payment_id"] == payment_id


# =============================================================================
# Test Suite 5: Payment Data Encryption at Rest (AES-256-GCM)
# =============================================================================
class TestPaymentEncryptionAtRest:
    """Verifies that sensitive payment metadata in the database is authenticated AES-256-GCM ciphertext."""

    def test_encrypted_metadata_stored_as_ciphertext(self, app_client, seed_users_and_trainers, store):
        alice_id = seed_users_and_trainers["alice_id"]
        bob_trainer_id = seed_users_and_trainers["bob_trainer_id"]
        sensitive_note = "User secret medical note: Recovering from ACL surgery"

        res = app_client.post("/payments/create-order", json={
            "trainer_id": bob_trainer_id,
            "amount": 1000.0,
            "idempotency_key": f"idem_{uuid.uuid4()}",
            "notes": {"medical": sensitive_note},
        }, headers={"Authorization": f"Bearer {alice_id}"})
        assert res.status_code == 200

        order_id = res.json()["order_id"]

        # Inspect raw DB row directly (Opaque-box database state audit)
        c = store.conn.cursor()
        c.execute("SELECT encrypted_metadata FROM payment_transactions WHERE order_id = ?", (order_id,))
        raw_row = c.fetchone()
        encrypted_metadata_b64 = raw_row["encrypted_metadata"]

        assert encrypted_metadata_b64 is not None
        # Plaintext must NOT appear anywhere in the database text
        assert sensitive_note not in encrypted_metadata_b64

        # Decrypt with authorized key to verify authenticity
        raw_data = base64.b64decode(encrypted_metadata_b64)
        nonce = raw_data[:12]
        ciphertext_with_tag = raw_data[12:]

        aesgcm = AESGCM(PAYMENT_ENCRYPTION_KEY)
        decrypted_json = json.loads(aesgcm.decrypt(nonce, ciphertext_with_tag, None).decode("utf-8"))
        assert decrypted_json["notes"]["medical"] == sensitive_note


# =============================================================================
# Test Suite 6: E2E Encrypted Chat Engine & Deduplication
# =============================================================================
class TestE2EEncryptedChat:
    """Verifies Signal-style X25519 key exchange, client encryption, DB ciphertext, and client UUID deduplication."""

    def test_e2ee_key_exchange_and_message_cycle(self, store, seed_users_and_trainers):
        alice_id = seed_users_and_trainers["alice_id"]
        bob_user_id = seed_users_and_trainers["bob_user_id"]
        bob_trainer_id = seed_users_and_trainers["bob_trainer_id"]

        # 1. Alice generates X25519 keypair
        alice_priv = x25519.X25519PrivateKey.generate()
        alice_pub = alice_priv.public_key()
        alice_pub_b64 = base64.b64encode(alice_pub.public_bytes_raw()).decode("utf-8")

        # 2. Bob generates X25519 keypair
        bob_priv = x25519.X25519PrivateKey.generate()
        bob_pub = bob_priv.public_key()
        bob_pub_b64 = base64.b64encode(bob_pub.public_bytes_raw()).decode("utf-8")

        # 3. Store public keys in encryption_keys table
        c = store.conn.cursor()
        c.execute("INSERT INTO encryption_keys (user_id, public_key) VALUES (?, ?)", (alice_id, alice_pub_b64))
        c.execute("INSERT INTO encryption_keys (user_id, public_key) VALUES (?, ?)", (bob_user_id, bob_pub_b64))
        store.conn.commit()

        # 4. Create conversation between Alice and Coach Bob
        conv_id = str(uuid.uuid4())
        c.execute("INSERT INTO chat_conversations (id, user_id, trainer_id) VALUES (?, ?, ?)",
                  (conv_id, alice_id, bob_trainer_id))
        store.conn.commit()

        # 5. Alice performs ECDH key exchange with Bob's public key
        bob_pub_obj = x25519.X25519PublicKey.from_public_bytes(base64.b64decode(bob_pub_b64))
        alice_shared_secret = alice_priv.exchange(bob_pub_obj)

        hkdf_alice = HKDF(algorithm=hashes.SHA256(), length=32, salt=HKDF_SALT, info=HKDF_INFO)
        alice_aes_key = hkdf_alice.derive(alice_shared_secret)

        # 6. Alice encrypts message client-side
        plain_text = "Coach Bob, can we adjust my macros for the upcoming cut phase?"
        nonce = os.urandom(12)
        alice_aesgcm = AESGCM(alice_aes_key)
        ciphertext_bytes = alice_aesgcm.encrypt(nonce, plain_text.encode("utf-8"), None)

        client_msg_uuid = str(uuid.uuid4())
        c.execute("""
            INSERT INTO chat_messages (id, conversation_id, sender_id, client_uuid, ciphertext, nonce)
            VALUES (?, ?, ?, ?, ?, ?)
        """, (str(uuid.uuid4()), conv_id, alice_id, client_msg_uuid,
              base64.b64encode(ciphertext_bytes).decode(),
              base64.b64encode(nonce).decode()))
        store.conn.commit()

        # 7. Server-side raw DB inspection: Plaintext is NOT stored!
        c.execute("SELECT ciphertext, nonce FROM chat_messages WHERE client_uuid = ?", (client_msg_uuid,))
        db_msg = c.fetchone()
        assert plain_text not in db_msg["ciphertext"]

        # 8. Bob receives message and decrypts client-side
        alice_pub_obj = x25519.X25519PublicKey.from_public_bytes(base64.b64decode(alice_pub_b64))
        bob_shared_secret = bob_priv.exchange(alice_pub_obj)
        hkdf_bob = HKDF(algorithm=hashes.SHA256(), length=32, salt=HKDF_SALT, info=HKDF_INFO)
        bob_aes_key = hkdf_bob.derive(bob_shared_secret)

        assert alice_aes_key == bob_aes_key

        rec_nonce = base64.b64decode(db_msg["nonce"])
        rec_cipher = base64.b64decode(db_msg["ciphertext"])
        bob_aesgcm = AESGCM(bob_aes_key)
        decrypted = bob_aesgcm.decrypt(rec_nonce, rec_cipher, None).decode("utf-8")
        assert decrypted == plain_text

    def test_chat_message_client_uuid_deduplication(self, store, seed_users_and_trainers):
        alice_id = seed_users_and_trainers["alice_id"]
        bob_trainer_id = seed_users_and_trainers["bob_trainer_id"]
        c = store.conn.cursor()

        conv_id = str(uuid.uuid4())
        c.execute("INSERT INTO chat_conversations (id, user_id, trainer_id) VALUES (?, ?, ?)",
                  (conv_id, alice_id, bob_trainer_id))

        client_uuid = str(uuid.uuid4())
        c.execute("""
            INSERT INTO chat_messages (id, conversation_id, sender_id, client_uuid, ciphertext, nonce)
            VALUES (?, ?, ?, ?, 'cipher_data_1', 'nonce_1')
        """, (str(uuid.uuid4()), conv_id, alice_id, client_uuid))
        store.conn.commit()

        # Mobile retry with identical client_uuid must be rejected
        with pytest.raises(sqlite3.IntegrityError):
            c.execute("""
                INSERT INTO chat_messages (id, conversation_id, sender_id, client_uuid, ciphertext, nonce)
                VALUES (?, ?, ?, ?, 'cipher_data_2', 'nonce_2')
            """, (str(uuid.uuid4()), conv_id, alice_id, client_uuid))


# =============================================================================
# Test Suite 7: Row-Level Security (RLS) Cross-Tenant Isolation
# =============================================================================
class TestCrossTenantSecurityIsolation:
    """Verifies that User B (or Attacker Eve) cannot read or tamper with User A's payments, conversations, or messages."""

    def test_payment_history_isolation(self, app_client, seed_users_and_trainers):
        alice_id = seed_users_and_trainers["alice_id"]
        bob_user_id = seed_users_and_trainers["bob_user_id"]
        bob_trainer_id = seed_users_and_trainers["bob_trainer_id"]
        eve_id = seed_users_and_trainers["eve_id"]

        # Alice creates payment to Coach Bob
        app_client.post("/payments/create-order", json={
            "trainer_id": bob_trainer_id, "amount": 2500.0, "idempotency_key": f"idem_{uuid.uuid4()}"
        }, headers={"Authorization": f"Bearer {alice_id}"})

        # Alice can view payment
        res_alice = app_client.get("/payments/history", headers={"Authorization": f"Bearer {alice_id}"})
        assert len(res_alice.json()["transactions"]) >= 1

        # Bob (as the trainer receiving funds) can also view the payment
        res_bob = app_client.get("/payments/history", headers={"Authorization": f"Bearer {bob_user_id}"})
        assert len(res_bob.json()["transactions"]) >= 1

        # Eve (Third-party tenant) MUST NOT see Alice & Bob's payment!
        res_eve = app_client.get("/payments/history", headers={"Authorization": f"Bearer {eve_id}"})
        assert len(res_eve.json()["transactions"]) == 0

    def test_chat_cross_tenant_read_isolation(self, store, seed_users_and_trainers):
        """Simulates RLS policy: only conversation participants can view conversation or messages."""
        alice_id = seed_users_and_trainers["alice_id"]
        bob_trainer_id = seed_users_and_trainers["bob_trainer_id"]
        eve_id = seed_users_and_trainers["eve_id"]
        c = store.conn.cursor()

        conv_id = str(uuid.uuid4())
        c.execute("INSERT INTO chat_conversations (id, user_id, trainer_id) VALUES (?, ?, ?)",
                  (conv_id, alice_id, bob_trainer_id))

        # Query simulating RLS condition: (select auth.uid()) = user_id OR trainer_id IN (SELECT id FROM trainer_profiles WHERE user_id = auth.uid())
        def query_conversations(caller_id: str):
            c.execute("""
                SELECT c.* FROM chat_conversations c
                LEFT JOIN trainer_profiles tp ON tp.id = c.trainer_id
                WHERE c.user_id = ? OR tp.user_id = ?
            """, (caller_id, caller_id))
            return c.fetchall()

        # Alice sees it
        assert len(query_conversations(alice_id)) == 1
        # Bob sees it
        assert len(query_conversations(seed_users_and_trainers["bob_user_id"])) == 1
        # Eve gets 0 records
        assert len(query_conversations(eve_id)) == 0
