"""
Milestone 1 Test Verification Suite: Trainer Marketplace, Payments & E2EE Chat
Covers:
- Schema contracts and check constraints
- Full RLS evaluation across User, Trainer, Anonymous, and Service Role
- Anti-tamper trigger simulation and field harmonization
- Payment idempotency and split fee invariant
- Chat message client_uuid deduplication and immutability
- Array filter (cs) and multi-item range queries
- Resource embedding for conversations and trainer profiles
- Foreign key cascading deletes
"""

import uuid
import pytest
from starlette.testclient import TestClient
from staging.mock_supabase_server import app, db


@pytest.fixture(autouse=True)
def reset_mock_db():
    """Reset mock database before each test to ensure test isolation."""
    db.reset()
    yield
    db.reset()


@pytest.fixture
def client():
    return TestClient(app)


class TestM1TrainerProfiles:
    """Tests for trainer_profiles table, public discovery, ownership, and check constraints."""

    def test_public_discovery_anonymous_access(self, client):
        """Anonymous callers (no auth token) must be able to view trainer profiles."""
        trainer_user_id = str(uuid.uuid4())
        # Seed a profile and trainer profile via service role
        db.profiles[trainer_user_id] = {
            "id": trainer_user_id,
            "display_name": "Coach Arnold",
            "experience_level": "advanced",
            "preferred_training_goal": "hypertrophy",
            "created_at": "2026-10-14T06:00:00Z",
        }
        tp_id = str(uuid.uuid4())
        db.trainer_profiles[tp_id] = {
            "id": tp_id,
            "user_id": trainer_user_id,
            "bio": "Certified Olympic weightlifting coach.",
            "certifications": ["CSCS", "USAW-L2"],
            "specialties": ["Hypertrophy", "Strength"],
            "experience_years": 8,
            "hourly_rate": 1500.0,
            "rating": 4.95,
            "platform_fee_pct": 10.0,
            "verified": True,
            "is_verified": True,
            "created_at": "2026-10-14T06:00:00Z",
            "updated_at": "2026-10-14T06:00:00Z",
        }

        # Anonymous GET without Authorization header
        resp = client.get("/rest/v1/trainer_profiles")
        assert resp.status_code == 200
        data = resp.json()
        assert len(data) == 1
        assert data[0]["id"] == tp_id
        assert data[0]["hourly_rate"] == 1500.0

    def test_trainer_profile_insert_ownership_enforcement(self, client):
        """Trainer can only insert a trainer profile for their own user_id."""
        trainer_uid = str(uuid.uuid4())
        other_uid = str(uuid.uuid4())

        # Attempt to insert for another user -> 403 Forbidden
        bad_payload = {
            "user_id": other_uid,
            "bio": "Malicious impostor profile",
            "hourly_rate": 2000.0,
        }
        resp = client.post(
            "/rest/v1/trainer_profiles",
            json=bad_payload,
            headers={"Authorization": f"Bearer dev-user-{trainer_uid}"},
        )
        assert resp.status_code == 403

        # Legitimate insert for own user_id -> 201 Created
        good_payload = {
            "user_id": trainer_uid,
            "bio": "Legitimate trainer profile",
            "hourly_rate": 1200.0,
            "specialties": ["Powerlifting", "Strength"],
            "experience_years": 5,
        }
        resp = client.post(
            "/rest/v1/trainer_profiles",
            json=good_payload,
            headers={"Authorization": f"Bearer dev-user-{trainer_uid}"},
        )
        assert resp.status_code == 201
        created = resp.json()[0]
        assert created["user_id"] == trainer_uid
        assert created["hourly_rate"] == 1200.0
        assert created["verified"] is True
        assert created["is_verified"] is True

    def test_trainer_profile_check_constraints(self, client):
        """Negative rates, invalid ratings, or fee out-of-bounds must be rejected with HTTP 400."""
        trainer_uid = str(uuid.uuid4())
        headers = {"Authorization": f"Bearer dev-user-{trainer_uid}"}

        # 1. Negative hourly_rate
        resp = client.post(
            "/rest/v1/trainer_profiles",
            json={"user_id": trainer_uid, "hourly_rate": -50.0},
            headers=headers,
        )
        assert resp.status_code == 400
        assert resp.json()["code"] == "23514"

        # 2. Rating > 5.0
        resp = client.post(
            "/rest/v1/trainer_profiles",
            json={"user_id": trainer_uid, "hourly_rate": 500.0, "rating": 6.5},
            headers=headers,
        )
        assert resp.status_code == 400
        assert resp.json()["code"] == "23514"

        # 3. Platform fee pct > 100.0
        resp = client.post(
            "/rest/v1/trainer_profiles",
            json={"user_id": trainer_uid, "hourly_rate": 500.0, "platform_fee_pct": 105.0},
            headers=headers,
        )
        assert resp.status_code == 400
        assert resp.json()["code"] == "23514"

    def test_trainer_profile_anti_tamper_protection(self, client):
        """Trainers cannot self-modify verified, platform_fee_pct, or rating via PATCH."""
        trainer_uid = str(uuid.uuid4())
        headers = {"Authorization": f"Bearer dev-user-{trainer_uid}"}

        # Create profile
        resp = client.post(
            "/rest/v1/trainer_profiles",
            json={"user_id": trainer_uid, "hourly_rate": 1000.0, "verified": False, "is_verified": False},
            headers=headers,
        )
        assert resp.status_code == 201
        tp_id = resp.json()[0]["id"]

        # Attempt to escalate fee to 0% -> 403 Forbidden
        patch_resp = client.patch(
            f"/rest/v1/trainer_profiles?id=eq.{tp_id}",
            json={"platform_fee_pct": 0.0},
            headers=headers,
        )
        assert patch_resp.status_code == 403

        # Legitimate bio update -> 200 OK
        ok_patch = client.patch(
            f"/rest/v1/trainer_profiles?id=eq.{tp_id}",
            json={"bio": "Updated bio information."},
            headers=headers,
        )
        assert ok_patch.status_code == 200
        assert ok_patch.json()[0]["bio"] == "Updated bio information."


class TestM1EncryptionKeys:
    """Tests for public key storage and E2EE key agreement support."""

    def test_encryption_key_crud_and_format_check(self, client):
        user_a = str(uuid.uuid4())
        headers_a = {"Authorization": f"Bearer dev-user-{user_a}"}

        # 1. Reject invalid short key (< 40 chars)
        bad_key = client.post(
            "/rest/v1/encryption_keys",
            json={"user_id": user_a, "public_key": "short_key"},
            headers=headers_a,
        )
        assert bad_key.status_code == 400
        assert bad_key.json()["code"] == "23514"

        # 2. Accept valid 44-character base64 X25519 public key
        valid_b64_key = "MCowBQYDK2VuAyEA8M5h8f+9G1uX9U5G9J6V9W1X2Y3Z0="
        good_resp = client.post(
            "/rest/v1/encryption_keys",
            json={"user_id": user_a, "public_key": valid_b64_key},
            headers=headers_a,
        )
        assert good_resp.status_code == 201
        key_id = good_resp.json()[0]["id"]

        # 3. Authenticated user B can read user A's public key (to perform Diffie-Hellman)
        user_b = str(uuid.uuid4())
        headers_b = {"Authorization": f"Bearer dev-user-{user_b}"}
        get_resp = client.get(f"/rest/v1/encryption_keys?user_id=eq.{user_a}", headers=headers_b)
        assert get_resp.status_code == 200
        assert len(get_resp.json()) == 1
        assert get_resp.json()[0]["public_key"] == valid_b64_key

        # 4. User B cannot modify or delete user A's key
        del_resp = client.delete(f"/rest/v1/encryption_keys?id=eq.{key_id}", headers=headers_b)
        assert del_resp.status_code == 200
        assert len(del_resp.json()) == 0  # 0 rows deleted due to RLS


class TestM1ChatConversationsAndMessages:
    """Tests for chat conversations, E2EE message ciphertext, deduplication, and immutability."""

    def test_conversation_and_message_lifecycle(self, client):
        client_uid = str(uuid.uuid4())
        trainer_uid = str(uuid.uuid4())

        # Setup profiles
        db.profiles[client_uid] = {"id": client_uid, "display_name": "Alice Client"}
        db.profiles[trainer_uid] = {"id": trainer_uid, "display_name": "Bob Trainer"}

        # Create trainer profile
        tp_resp = client.post(
            "/rest/v1/trainer_profiles",
            json={"user_id": trainer_uid, "hourly_rate": 1500.0},
            headers={"Authorization": f"Bearer dev-user-{trainer_uid}"},
        )
        assert tp_resp.status_code == 201
        tp_id = tp_resp.json()[0]["id"]

        # Client initiates conversation
        client_headers = {"Authorization": f"Bearer dev-user-{client_uid}"}
        conv_resp = client.post(
            "/rest/v1/chat_conversations",
            json={"user_id": client_uid, "trainer_id": tp_id},
            headers=client_headers,
        )
        assert conv_resp.status_code == 201
        conv_id = conv_resp.json()[0]["id"]

        # Unrelated third party cannot view conversation
        eve_uid = str(uuid.uuid4())
        eve_headers = {"Authorization": f"Bearer dev-user-{eve_uid}"}
        eve_get = client.get(f"/rest/v1/chat_conversations?id=eq.{conv_id}", headers=eve_headers)
        assert eve_get.status_code == 200
        assert len(eve_get.json()) == 0

        # Alice sends encrypted message
        msg_uuid = str(uuid.uuid4())
        msg_payload = {
            "conversation_id": conv_id,
            "sender_id": client_uid,
            "client_uuid": msg_uuid,
            "ciphertext": "83jfnsd8942hjkdshf==",
            "nonce": "123456789012",
        }
        msg_resp = client.post("/rest/v1/chat_messages", json=msg_payload, headers=client_headers)
        assert msg_resp.status_code == 201
        created_msg = msg_resp.json()[0]
        assert created_msg["ciphertext"] == "83jfnsd8942hjkdshf=="
        assert created_msg["is_read"] is False

        # Duplicate message (same client_uuid) without upsert returns HTTP 409
        dup_resp = client.post("/rest/v1/chat_messages", json=msg_payload, headers=client_headers)
        assert dup_resp.status_code == 409
        assert dup_resp.json()["code"] == "23505"

        # Idempotent retry with resolution=merge-duplicates returns existing message
        idempotent_resp = client.post(
            "/rest/v1/chat_messages",
            json=msg_payload,
            headers={**client_headers, "Prefer": "resolution=merge-duplicates"},
        )
        assert idempotent_resp.status_code == 201
        assert idempotent_resp.json()[0]["client_uuid"] == msg_uuid

        # Trainer reads message
        trainer_headers = {"Authorization": f"Bearer dev-user-{trainer_uid}"}
        trainer_view = client.get(f"/rest/v1/chat_messages?conversation_id=eq.{conv_id}", headers=trainer_headers)
        assert trainer_view.status_code == 200
        assert len(trainer_view.json()) == 1

        # Trainer marks message as read
        patch_read = client.patch(
            f"/rest/v1/chat_messages?id=eq.{created_msg['id']}",
            json={"is_read": True},
            headers=trainer_headers,
        )
        assert patch_read.status_code == 200
        assert patch_read.json()[0]["is_read"] is True
        assert patch_read.json()[0]["read_at"] is not None

        # Message content immutability: participant cannot tamper with ciphertext
        tamper_resp = client.patch(
            f"/rest/v1/chat_messages?id=eq.{created_msg['id']}",
            json={"ciphertext": "tampered_ciphertext=="},
            headers=trainer_headers,
        )
        assert tamper_resp.status_code == 403


class TestM1PaymentTransactions:
    """Tests for payment creation, fee split invariant, idempotency deduplication, and RLS."""

    def test_payment_split_math_and_idempotency(self, client):
        user_uid = str(uuid.uuid4())
        trainer_uid = str(uuid.uuid4())

        # Setup profiles & trainer profile
        db.profiles[user_uid] = {"id": user_uid, "display_name": "Payer User"}
        db.profiles[trainer_uid] = {"id": trainer_uid, "display_name": "Recipient Trainer"}
        tp_id = str(uuid.uuid4())
        db.trainer_profiles[tp_id] = {"id": tp_id, "user_id": trainer_uid, "hourly_rate": 1500.0}

        headers = {"Authorization": f"Bearer dev-user-{user_uid}"}

        # 1. Fee split invariant validation: 1500 != 100 + 1300 -> 400 Bad Request
        bad_split = {
            "idempotency_key": "idem-bad-split",
            "user_id": user_uid,
            "trainer_id": tp_id,
            "order_id": "order_123",
            "amount": 1500.0,
            "platform_fee": 100.0,
            "trainer_amount": 1300.0,  # 100 + 1300 = 1400 != 1500
        }
        resp = client.post("/rest/v1/payment_transactions", json=bad_split, headers=headers)
        assert resp.status_code == 400
        assert resp.json()["code"] == "23514"

        # 2. Legitimate payment: 1500 = 150 + 1350
        good_payment = {
            "idempotency_key": "idem-key-abc-001",
            "user_id": user_uid,
            "trainer_id": tp_id,
            "order_id": "order_legit_001",
            "amount": 1500.0,
            "platform_fee": 150.0,
            "trainer_amount": 1350.0,
            "status": "created",
        }
        create_resp = client.post("/rest/v1/payment_transactions", json=good_payment, headers=headers)
        assert create_resp.status_code == 201
        txn = create_resp.json()[0]
        txn_id = txn["id"]
        assert txn["order_id"] == "order_legit_001"
        assert txn["razorpay_order_id"] == "order_legit_001"
        assert txn["platform_fee_amount"] == 150.0

        # 3. Duplicate POST without merge-duplicates -> 409 Conflict
        dup_resp = client.post("/rest/v1/payment_transactions", json=good_payment, headers=headers)
        assert dup_resp.status_code == 409
        assert dup_resp.json()["code"] == "23505"

        # 4. Idempotent replay with merge-duplicates or on_conflict -> returns original transaction
        replay_resp = client.post(
            "/rest/v1/payment_transactions?on_conflict=idempotency_key",
            json=good_payment,
            headers=headers,
        )
        assert replay_resp.status_code == 201
        assert replay_resp.json()[0]["id"] == txn_id

        # 5. Recipient trainer can view transaction
        trainer_headers = {"Authorization": f"Bearer dev-user-{trainer_uid}"}
        trainer_history = client.get("/rest/v1/payment_transactions", headers=trainer_headers)
        assert trainer_history.status_code == 200
        assert len(trainer_history.json()) == 1
        assert trainer_history.json()[0]["id"] == txn_id

        # 6. Unrelated third party cannot view transaction
        third_party_headers = {"Authorization": f"Bearer dev-user-{str(uuid.uuid4())}"}
        tp_view = client.get("/rest/v1/payment_transactions", headers=third_party_headers)
        assert tp_view.status_code == 200
        assert len(tp_view.json()) == 0


class TestM1QueryAndResourceEmbedding:
    """Tests for array contains (cs), multi-item range queries, and resource embedding."""

    def test_array_contains_and_price_range_queries(self, client):
        # Seed 3 trainers
        t1 = str(uuid.uuid4())
        t2 = str(uuid.uuid4())
        t3 = str(uuid.uuid4())
        db.trainer_profiles[t1] = {
            "id": t1,
            "user_id": t1,
            "specialties": ["Powerlifting", "Strength"],
            "hourly_rate": 800.0,
            "rating": 4.8,
        }
        db.trainer_profiles[t2] = {
            "id": t2,
            "user_id": t2,
            "specialties": ["Yoga", "Mobility"],
            "hourly_rate": 1500.0,
            "rating": 5.0,
        }
        db.trainer_profiles[t3] = {
            "id": t3,
            "user_id": t3,
            "specialties": ["Strength", "Bodybuilding"],
            "hourly_rate": 2500.0,
            "rating": 4.9,
        }

        # Query array contains: specialties=cs.{Strength}
        resp = client.get("/rest/v1/trainer_profiles?specialties=cs.{Strength}")
        assert resp.status_code == 200
        ids = [r["id"] for r in resp.json()]
        assert t1 in ids
        assert t3 in ids
        assert t2 not in ids

        # Multi-parameter range query: hourly_rate=gte.1000&hourly_rate=lte.3000
        range_resp = client.get("/rest/v1/trainer_profiles?hourly_rate=gte.1000&hourly_rate=lte.3000")
        assert range_resp.status_code == 200
        range_ids = [r["id"] for r in range_resp.json()]
        assert t2 in range_ids
        assert t3 in range_ids
        assert t1 not in range_ids

    def test_conversation_and_trainer_resource_embedding(self, client):
        user_uid = str(uuid.uuid4())
        trainer_uid = str(uuid.uuid4())
        db.profiles[user_uid] = {"id": user_uid, "display_name": "Alice"}
        db.profiles[trainer_uid] = {"id": trainer_uid, "display_name": "Bob Trainer"}

        tp_id = str(uuid.uuid4())
        db.trainer_profiles[tp_id] = {
            "id": tp_id,
            "user_id": trainer_uid,
            "hourly_rate": 1200.0,
            "specialties": ["Cardio"],
        }

        conv_id = str(uuid.uuid4())
        db.chat_conversations[conv_id] = {
            "id": conv_id,
            "user_id": user_uid,
            "trainer_id": tp_id,
            "created_at": "2026-10-14T06:00:00Z",
        }

        msg_id = str(uuid.uuid4())
        db.chat_messages[msg_id] = {
            "id": msg_id,
            "conversation_id": conv_id,
            "sender_id": user_uid,
            "client_uuid": str(uuid.uuid4()),
            "ciphertext": "cipher==",
            "nonce": "123456789012",
            "created_at": "2026-10-14T06:01:00Z",
        }

        # Resource embedding on chat_conversations: embed chat_messages, trainer_profiles, and profiles
        headers = {"Authorization": f"Bearer dev-user-{user_uid}"}
        resp = client.get(
            f"/rest/v1/chat_conversations?id=eq.{conv_id}&select=*,chat_messages(*),trainer_profiles(*),profiles(*)",
            headers=headers,
        )
        assert resp.status_code == 200
        conv_data = resp.json()[0]
        assert "chat_messages" in conv_data
        assert len(conv_data["chat_messages"]) == 1
        assert conv_data["chat_messages"][0]["id"] == msg_id
        assert "trainer_profiles" in conv_data
        assert conv_data["trainer_profiles"]["id"] == tp_id
        assert "profiles" in conv_data
        assert conv_data["profiles"]["display_name"] == "Alice"


class TestM1CascadingDeletes:
    """Tests for cascading delete integrity across user profiles and marketplace records."""

    def test_profile_deletion_cascades_to_marketplace_tables(self, client):
        user_uid = str(uuid.uuid4())
        db.profiles[user_uid] = {"id": user_uid, "display_name": "User To Delete"}

        # Add trainer profile, encryption key, conversation, message
        tp_id = str(uuid.uuid4())
        db.trainer_profiles[tp_id] = {"id": tp_id, "user_id": user_uid}

        ek_id = str(uuid.uuid4())
        db.encryption_keys[ek_id] = {"id": ek_id, "user_id": user_uid, "public_key": "x" * 44}

        conv_id = str(uuid.uuid4())
        db.chat_conversations[conv_id] = {"id": conv_id, "user_id": user_uid, "trainer_id": tp_id}

        msg_id = str(uuid.uuid4())
        db.chat_messages[msg_id] = {"id": msg_id, "conversation_id": conv_id, "sender_id": user_uid}

        # Service role deletes user profile
        del_resp = client.delete(
            f"/rest/v1/profiles?id=eq.{user_uid}",
            headers={"apikey": "mock-service-key"},
        )
        assert del_resp.status_code == 200

        # Assert all child records purged
        assert user_uid not in db.profiles
        assert tp_id not in db.trainer_profiles
        assert ek_id not in db.encryption_keys
        assert conv_id not in db.chat_conversations
        assert msg_id not in db.chat_messages
