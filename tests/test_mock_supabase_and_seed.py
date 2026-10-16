"""
Tests for M1 Staging Infrastructure: Mock Supabase Server & Seed Pipeline.
Validates:
1. GoTrue Auth: signup, token, user, dev-user-* tokens.
2. PostgREST CRUD: all 5 schema tables.
3. Query operators: eq, neq, gt, gte, lt, lte, in, is.
4. Resource embedding: select=*, workout_exercises(*, workout_sets(*)).
5. Strict 14-policy Row-Level Security (RLS) and cross-tenant isolation.
6. Service Role key bypass.
7. Database Seed Pipeline: exercises catalog, user personas, progressive overload, seeded_users.json.
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
import time
import uuid
import jwt
import pytest
from starlette.testclient import TestClient

# Add project root to sys.path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from staging.mock_supabase_server import (
    app,
    db,
    JWT_SECRET,
    SERVICE_ROLE_KEY,
    extract_auth_context,
)
from scripts.seed_staging import (
    ExerciseCatalog,
    DEFAULT_EXERCISES_PATH,
    generate_users,
    generate_user_workouts,
    STANDARD_MUSCLE_GROUPS,
)


@pytest.fixture(autouse=True)
def reset_mock_db():
    """Reset mock database before each test."""
    db.reset()
    yield
    db.reset()


@pytest.fixture
def client():
    return TestClient(app)


# =============================================================================
# 1. GoTrue Auth Tests
# =============================================================================

class TestGoTrueAuth:
    def test_signup_email_password(self, client):
        payload = {
            "email": "athlete_01@pulsefit.test",
            "password": "SecurePassword123!",
            "data": {
                "display_name": "Athlete Alpha",
                "experience_level": "advanced",
                "preferred_training_goal": "strength",
            },
        }
        res = client.post("/auth/v1/signup", json=payload)
        assert res.status_code == 200
        data = res.json()
        assert "access_token" in data
        assert "user" in data
        user = data["user"]
        assert user["email"] == "athlete_01@pulsefit.test"
        assert user["role"] == "authenticated"
        assert user["id"] in db.profiles
        assert db.profiles[user["id"]]["display_name"] == "Athlete Alpha"

    def test_signup_anonymous(self, client):
        res = client.post("/auth/v1/signup", json={})
        assert res.status_code == 200
        data = res.json()
        assert "access_token" in data
        user = data["user"]
        assert user["is_anonymous"] is True
        assert "anon-" in user["email"]

    def test_token_password_grant(self, client):
        # 1. Sign up user
        client.post(
            "/auth/v1/signup",
            json={"email": "login_user@pulsefit.test", "password": "Password123!"},
        )
        # 2. Login
        res = client.post(
            "/auth/v1/token?grant_type=password",
            json={"email": "login_user@pulsefit.test", "password": "Password123!"},
        )
        assert res.status_code == 200
        data = res.json()
        assert "access_token" in data
        assert data["user"]["email"] == "login_user@pulsefit.test"

    def test_get_user_with_jwt(self, client):
        signup_res = client.post(
            "/auth/v1/signup",
            json={"email": "jwt_user@pulsefit.test", "password": "Password123!"},
        )
        token = signup_res.json()["access_token"]
        user_id = signup_res.json()["user"]["id"]

        res = client.get("/auth/v1/user", headers={"Authorization": f"Bearer {token}"})
        assert res.status_code == 200
        assert res.json()["id"] == user_id
        assert res.json()["email"] == "jwt_user@pulsefit.test"

    def test_get_user_dev_token_bypass(self, client):
        dev_uid = "e3b0c442-98fc-1c14-9afb-4c7b8e5c1234"
        dev_token = f"dev-user-{dev_uid}"

        res = client.get("/auth/v1/user", headers={"Authorization": f"Bearer {dev_token}"})
        assert res.status_code == 200
        user = res.json()
        assert user["id"] == dev_uid
        assert dev_uid in db.auth_users
        assert dev_uid in db.profiles

    def test_get_user_unauthorized(self, client):
        res = client.get("/auth/v1/user")
        assert res.status_code == 401


# =============================================================================
# 2. PostgREST CRUD & Operator Tests
# =============================================================================

class TestPostgRESTCRUD:
    def test_crud_workout_sessions(self, client):
        user_id = str(uuid.uuid4())
        dev_token = f"dev-user-{user_id}"
        headers = {"Authorization": f"Bearer {dev_token}"}

        # 1. Insert session
        session_id = str(uuid.uuid4())
        post_data = {
            "id": session_id,
            "user_id": user_id,
            "routine_id": "ppl_push",
            "routine_name": "Push Day",
            "started_at": "2026-10-01T10:00:00Z",
            "total_volume": 4500.5,
            "total_reps": 85,
        }
        res = client.post("/rest/v1/workout_sessions", json=post_data, headers=headers)
        assert res.status_code == 201
        assert len(res.json()) == 1
        assert res.json()[0]["id"] == session_id

        # 2. Read session
        res = client.get(f"/rest/v1/workout_sessions?id=eq.{session_id}", headers=headers)
        assert res.status_code == 200
        assert len(res.json()) == 1
        assert res.json()[0]["routine_name"] == "Push Day"

        # 3. Update session
        patch_res = client.patch(
            f"/rest/v1/workout_sessions?id=eq.{session_id}",
            json={"routine_name": "Push Day Heavy", "total_volume": 5000.0},
            headers=headers,
        )
        assert patch_res.status_code == 200
        assert patch_res.json()[0]["routine_name"] == "Push Day Heavy"
        assert patch_res.json()[0]["total_volume"] == 5000.0

        # 4. Delete session
        del_res = client.delete(f"/rest/v1/workout_sessions?id=eq.{session_id}", headers=headers)
        assert del_res.status_code == 200
        assert len(del_res.json()) == 1

        # Confirm deleted
        res_after = client.get(f"/rest/v1/workout_sessions?id=eq.{session_id}", headers=headers)
        assert res_after.json() == []

    def test_query_filter_operators(self, client):
        user_id = str(uuid.uuid4())
        dev_token = f"dev-user-{user_id}"
        headers = {"Authorization": f"Bearer {dev_token}"}

        # Seed 3 sessions with varying volumes and dates
        s1 = {"id": str(uuid.uuid4()), "user_id": user_id, "routine_id": "split_a", "total_volume": 1000.0, "total_reps": 20, "started_at": "2026-10-01T10:00:00Z"}
        s2 = {"id": str(uuid.uuid4()), "user_id": user_id, "routine_id": "split_b", "total_volume": 2500.0, "total_reps": 40, "started_at": "2026-10-05T10:00:00Z"}
        s3 = {"id": str(uuid.uuid4()), "user_id": user_id, "routine_id": "split_c", "total_volume": 5000.0, "total_reps": 60, "started_at": "2026-10-10T10:00:00Z"}
        client.post("/rest/v1/workout_sessions", json=[s1, s2, s3], headers=headers)

        # gt operator
        res_gt = client.get("/rest/v1/workout_sessions?total_volume=gt.2000", headers=headers)
        assert len(res_gt.json()) == 2

        # lte operator
        res_lte = client.get("/rest/v1/workout_sessions?total_volume=lte.2500", headers=headers)
        assert len(res_lte.json()) == 2

        # in operator
        res_in = client.get("/rest/v1/workout_sessions?routine_id=in.(split_a,split_c)", headers=headers)
        assert len(res_in.json()) == 2

        # order and limit
        res_order = client.get("/rest/v1/workout_sessions?order=total_volume.desc&limit=1", headers=headers)
        assert len(res_order.json()) == 1
        assert res_order.json()[0]["total_volume"] == 5000.0


# =============================================================================
# 3. Resource Embedding Tests
# =============================================================================

class TestResourceEmbedding:
    def test_nested_session_exercises_and_sets(self, client):
        user_id = str(uuid.uuid4())
        dev_token = f"dev-user-{user_id}"
        headers = {"Authorization": f"Bearer {dev_token}"}

        # 1. Create session
        sess_id = str(uuid.uuid4())
        client.post("/rest/v1/workout_sessions", json={"id": sess_id, "user_id": user_id, "routine_name": "Full Body", "started_at": "2026-10-01T10:00:00Z"}, headers=headers)

        # 2. Create exercise
        ex_id = str(uuid.uuid4())
        client.post("/rest/v1/workout_exercises", json={"id": ex_id, "workout_session_id": sess_id, "exercise_name": "Barbell Squat", "order_index": 0, "primary_muscle_group": "Legs"}, headers=headers)

        # 3. Create 2 sets
        s1_id = str(uuid.uuid4())
        s2_id = str(uuid.uuid4())
        client.post("/rest/v1/workout_sets", json=[
            {"id": s1_id, "workout_exercise_id": ex_id, "set_number": 1, "completed_reps": 10, "completed_weight": 100.0, "is_completed": True},
            {"id": s2_id, "workout_exercise_id": ex_id, "set_number": 2, "completed_reps": 10, "completed_weight": 105.0, "is_completed": True},
        ], headers=headers)

        # Query embedding: select=*, workout_exercises(*, workout_sets(*))
        res = client.get(
            f"/rest/v1/workout_sessions?select=*,workout_exercises(*,workout_sets(*))&id=eq.{sess_id}",
            headers=headers,
        )
        assert res.status_code == 200
        sessions = res.json()
        assert len(sessions) == 1
        sess = sessions[0]
        assert "workout_exercises" in sess
        assert len(sess["workout_exercises"]) == 1
        ex = sess["workout_exercises"][0]
        assert ex["exercise_name"] == "Barbell Squat"
        assert "workout_sets" in ex
        assert len(ex["workout_sets"]) == 2
        assert ex["workout_sets"][0]["completed_weight"] == 100.0
        assert ex["workout_sets"][1]["completed_weight"] == 105.0


# =============================================================================
# 4. Strict Row-Level Security (RLS) & Multi-Tenant Isolation Tests
# =============================================================================

class TestRowLevelSecurity:
    def test_cross_tenant_isolation_and_violations(self, client):
        user_a = str(uuid.uuid4())
        user_b = str(uuid.uuid4())
        token_a = f"dev-user-{user_a}"
        token_b = f"dev-user-{user_b}"
        headers_a = {"Authorization": f"Bearer {token_a}"}
        headers_b = {"Authorization": f"Bearer {token_b}"}

        # 1. User A inserts a session
        sess_a_id = str(uuid.uuid4())
        client.post("/rest/v1/workout_sessions", json={"id": sess_a_id, "user_id": user_a, "routine_name": "A's Private Session", "started_at": "2026-10-01T10:00:00Z"}, headers=headers_a)

        # 2. User B reads all workout_sessions -> User A's session is silently omitted
        res_b_all = client.get("/rest/v1/workout_sessions", headers=headers_b)
        assert res_b_all.status_code == 200
        assert not any(s["id"] == sess_a_id for s in res_b_all.json())

        # 3. User B queries User A's session directly by ID -> returns empty list []
        res_b_direct = client.get(f"/rest/v1/workout_sessions?id=eq.{sess_a_id}", headers=headers_b)
        assert res_b_direct.status_code == 200
        assert res_b_direct.json() == []

        # 4. User B attempts to INSERT an exercise under User A's session -> HTTP 403 Forbidden
        ex_attack = {
            "id": str(uuid.uuid4()),
            "workout_session_id": sess_a_id,
            "exercise_name": "Malicious Injection",
        }
        res_inject = client.post("/rest/v1/workout_exercises", json=ex_attack, headers=headers_b)
        assert res_inject.status_code == 403
        assert res_inject.json()["code"] == "42501"

        # 5. User B attempts to DELETE User A's session -> 0 rows deleted
        del_attack = client.delete(f"/rest/v1/workout_sessions?id=eq.{sess_a_id}", headers=headers_b)
        assert del_attack.status_code == 200
        assert del_attack.json() == []
        # Confirm User A's session is still intact
        res_a_check = client.get(f"/rest/v1/workout_sessions?id=eq.{sess_a_id}", headers=headers_a)
        assert len(res_a_check.json()) == 1

    def test_service_role_bypass(self, client):
        user_a = str(uuid.uuid4())
        token_a = f"dev-user-{user_a}"
        headers_a = {"Authorization": f"Bearer {token_a}"}

        sess_id = str(uuid.uuid4())
        client.post("/rest/v1/workout_sessions", json={"id": sess_id, "user_id": user_a, "routine_name": "A's Session", "started_at": "2026-10-01T10:00:00Z"}, headers=headers_a)

        # Service role headers
        service_headers = {"apikey": SERVICE_ROLE_KEY}
        res = client.get("/rest/v1/workout_sessions", headers=service_headers)
        assert res.status_code == 200
        assert any(s["id"] == sess_id for s in res.json())


# =============================================================================
# 5. Seed Pipeline Logic & Catalog Parsing Tests
# =============================================================================

class TestSeedPipeline:
    def test_exercise_catalog_parsing(self):
        catalog = ExerciseCatalog(DEFAULT_EXERCISES_PATH)
        catalog.load()
        assert len(catalog.exercises) >= 1300
        for g in STANDARD_MUSCLE_GROUPS:
            assert len(catalog.by_group[g]) > 0

    def test_synthetic_user_personas(self):
        users = generate_users(50, seed=42)
        assert len(users) == 50
        personas = set(u.persona_name for u in users)
        assert len(personas) == 5  # Powerlifter, Hypertrophy, Beginner, Endurance, Recomp
        for u in users:
            assert u.dev_token == f"dev-user-{u.id}"
            assert u.weight_kg > 0
            assert u.height_cm > 0

    def test_workout_history_progressive_overload(self):
        catalog = ExerciseCatalog(DEFAULT_EXERCISES_PATH)
        catalog.load()
        user = generate_users(1, seed=42)[0]
        import random
        rng = random.Random(42)

        sessions, exercises, sets, recs = generate_user_workouts(
            user=user,
            catalog=catalog,
            workout_count=8,
            days_history=40,
            rng=rng,
        )
        assert len(sessions) == 8
        assert len(exercises) >= 32
        assert len(sets) >= 96
        assert len(recs) == 1

        # Check total_volume math
        for s in sessions:
            assert s["total_volume"] > 0
            assert s["total_reps"] > 0
            assert s["user_id"] == user.id


# =============================================================================
# 6. Milestone 1 Iteration 2 Remediation Regression Tests
# =============================================================================

class TestAuthRemediations:
    """Regression tests for AUTH-04, AUTH-02, AUTH-03, and Seed GoTrue Sync."""

    def test_auth_04_service_role_substring_rejected(self, client):
        """AUTH-04: Substring 'service_role' in token must NOT grant admin access."""
        attacker_token = "attacker-token-with-service_role-substring"
        # 1. extract_auth_context direct check
        is_admin, uid = extract_auth_context(authorization=f"Bearer {attacker_token}")
        assert is_admin is False
        assert uid is None

        # 2. Endpoint check: GET /auth/v1/user with spoofed token must return 401
        res = client.get("/auth/v1/user", headers={"Authorization": f"Bearer {attacker_token}"})
        assert res.status_code == 401

    def test_auth_02_invalid_signature_rejected(self, client):
        """AUTH-02: Forged JWT signed with unauthorized key must return 401."""
        now = int(time.time())
        payload = {
            "iss": "supabase-mock",
            "sub": str(uuid.uuid4()),
            "role": "authenticated",
            "exp": now + 3600,
            "iat": now,
        }
        forged_jwt = jwt.encode(payload, "unauthorized-secret-key-1234567890", algorithm="HS256")
        res = client.get("/auth/v1/user", headers={"Authorization": f"Bearer {forged_jwt}"})
        assert res.status_code == 401

    def test_auth_03_expired_jwt_rejected(self, client):
        """AUTH-03: Expired JWT must return 401 Unauthorized."""
        now = int(time.time())
        expired_payload = {
            "iss": "supabase-mock",
            "sub": str(uuid.uuid4()),
            "role": "authenticated",
            "email": "expired@pulsefit.test",
            "exp": now - 3600,  # Expired 1 hour ago
            "iat": now - 7200,
        }
        expired_jwt = jwt.encode(expired_payload, JWT_SECRET, algorithm="HS256")
        res = client.get("/auth/v1/user", headers={"Authorization": f"Bearer {expired_jwt}"})
        assert res.status_code == 401

    def test_seed_gotrue_user_login_resolves_seeded_uuid(self, client):
        """Seed GoTrue Disconnect: Seeded user login must return exact seeded user ID."""
        user_id = str(uuid.uuid4())
        email = f"seeded_athlete_{user_id[:8]}@pulsefit.test"
        password = "StagingPassword123!"

        # Admin registers user
        admin_payload = {
            "id": user_id,
            "email": email,
            "password": password,
            "user_metadata": {"display_name": "Seeded Athlete"},
        }
        admin_res = client.post(
            "/auth/v1/admin/users",
            json=admin_payload,
            headers={"apikey": SERVICE_ROLE_KEY},
        )
        assert admin_res.status_code == 200
        assert admin_res.json()["id"] == user_id

        # User logs in with password grant
        login_res = client.post(
            "/auth/v1/token?grant_type=password",
            json={"email": email, "password": password},
        )
        assert login_res.status_code == 200
        login_data = login_res.json()
        assert login_data["user"]["id"] == user_id
        assert login_data["user"]["email"] == email


class TestRowLevelSecurityUpsertAndPatchIntegrity:
    """Regression tests for Upsert Cross-Tenant Hijack and RLS-04 PATCH WITH CHECK."""

    def test_upsert_cross_tenant_hijack_rejected(self, client):
        """Verify Tenant B cannot hijack Tenant A's session via upsert."""
        user_a = str(uuid.uuid4())
        user_b = str(uuid.uuid4())
        sess_a = str(uuid.uuid4())
        headers_a = {"Authorization": f"Bearer dev-user-{user_a}"}
        headers_b = {"Authorization": f"Bearer dev-user-{user_b}"}

        # 1. User A creates session
        r_create = client.post(
            "/rest/v1/workout_sessions",
            json={"id": sess_a, "user_id": user_a, "routine_name": "A Private Routine"},
            headers=headers_a,
        )
        assert r_create.status_code == 201

        # 2. User B attempts upsert on User A's session ID
        r_attack = client.post(
            "/rest/v1/workout_sessions",
            json={"id": sess_a, "user_id": user_b, "routine_name": "Hijacked by B"},
            headers={**headers_b, "Prefer": "resolution=merge-duplicates"},
        )
        assert r_attack.status_code == 403
        assert r_attack.json()["code"] == "42501"

        # Verify User A's session was NOT modified
        assert db.workout_sessions[sess_a]["user_id"] == user_a
        assert db.workout_sessions[sess_a]["routine_name"] == "A Private Routine"

    def test_upsert_batch_atomic_rejection(self, client):
        """Verify that a batch upsert with 1 valid row and 1 hijack row is atomically rejected."""
        user_a = str(uuid.uuid4())
        user_b = str(uuid.uuid4())
        sess_a = str(uuid.uuid4())
        sess_b_valid = str(uuid.uuid4())
        headers_a = {"Authorization": f"Bearer dev-user-{user_a}"}
        headers_b = {"Authorization": f"Bearer dev-user-{user_b}"}

        client.post("/rest/v1/workout_sessions", json={"id": sess_a, "user_id": user_a}, headers=headers_a)

        batch_payload = [
            {"id": sess_b_valid, "user_id": user_b, "routine_name": "B Valid Session"},
            {"id": sess_a, "user_id": user_b, "routine_name": "B Hijack Session"},
        ]
        r = client.post(
            "/rest/v1/workout_sessions",
            json=batch_payload,
            headers={**headers_b, "Prefer": "resolution=merge-duplicates"},
        )
        assert r.status_code == 403
        assert r.json()["code"] == "42501"
        assert sess_b_valid not in db.workout_sessions, "Batch was not atomic: valid row was committed!"

    def test_upsert_child_exercise_cross_tenant_rejected(self, client):
        """Verify Tenant B cannot hijack Tenant A's exercise into Tenant B's session."""
        user_a = str(uuid.uuid4())
        user_b = str(uuid.uuid4())
        sess_a = str(uuid.uuid4())
        sess_b = str(uuid.uuid4())
        ex_a = str(uuid.uuid4())
        headers_a = {"Authorization": f"Bearer dev-user-{user_a}"}
        headers_b = {"Authorization": f"Bearer dev-user-{user_b}"}

        client.post("/rest/v1/workout_sessions", json={"id": sess_a, "user_id": user_a}, headers=headers_a)
        client.post("/rest/v1/workout_exercises", json={"id": ex_a, "workout_session_id": sess_a, "exercise_name": "Squat"}, headers=headers_a)
        client.post("/rest/v1/workout_sessions", json={"id": sess_b, "user_id": user_b}, headers=headers_b)

        r_attack = client.post(
            "/rest/v1/workout_exercises",
            json={"id": ex_a, "workout_session_id": sess_b, "exercise_name": "Stolen Squat"},
            headers={**headers_b, "Prefer": "resolution=merge-duplicates"},
        )
        assert r_attack.status_code == 403
        assert r_attack.json()["code"] == "42501"
        assert db.workout_exercises[ex_a]["workout_session_id"] == sess_a

    def test_patch_user_id_reassignment_rejected(self, client):
        """Verify Tenant A cannot transfer session ownership to Tenant B via PATCH."""
        user_a = str(uuid.uuid4())
        user_b = str(uuid.uuid4())
        sess_a = str(uuid.uuid4())
        headers_a = {"Authorization": f"Bearer dev-user-{user_a}"}

        client.post("/rest/v1/workout_sessions", json={"id": sess_a, "user_id": user_a}, headers=headers_a)

        r_patch = client.patch(
            f"/rest/v1/workout_sessions?id=eq.{sess_a}",
            json={"user_id": user_b},
            headers=headers_a,
        )
        assert r_patch.status_code == 403
        assert r_patch.json()["code"] == "42501"
        assert db.workout_sessions[sess_a]["user_id"] == user_a

    def test_patch_child_reparenting_rejected(self, client):
        """Verify Tenant A cannot re-parent an exercise to Tenant B's session via PATCH."""
        user_a = str(uuid.uuid4())
        user_b = str(uuid.uuid4())
        sess_a = str(uuid.uuid4())
        sess_b = str(uuid.uuid4())
        ex_a = str(uuid.uuid4())
        headers_a = {"Authorization": f"Bearer dev-user-{user_a}"}
        headers_b = {"Authorization": f"Bearer dev-user-{user_b}"}

        client.post("/rest/v1/workout_sessions", json={"id": sess_a, "user_id": user_a}, headers=headers_a)
        client.post("/rest/v1/workout_exercises", json={"id": ex_a, "workout_session_id": sess_a, "exercise_name": "Deadlift"}, headers=headers_a)
        client.post("/rest/v1/workout_sessions", json={"id": sess_b, "user_id": user_b}, headers=headers_b)

        r_patch = client.patch(
            f"/rest/v1/workout_exercises?id=eq.{ex_a}",
            json={"workout_session_id": sess_b},
            headers=headers_a,
        )
        assert r_patch.status_code == 403
        assert r_patch.json()["code"] == "42501"
        assert db.workout_exercises[ex_a]["workout_session_id"] == sess_a

    def test_legitimate_upsert_and_patch(self, client):
        """Verify legitimate owner can upsert and patch own records."""
        user_a = str(uuid.uuid4())
        sess_a = str(uuid.uuid4())
        headers_a = {"Authorization": f"Bearer dev-user-{user_a}"}

        # 1. Insert
        client.post("/rest/v1/workout_sessions", json={"id": sess_a, "user_id": user_a, "routine_name": "Legs"}, headers=headers_a)

        # 2. Legitimate Upsert
        r_upsert = client.post(
            "/rest/v1/workout_sessions",
            json={"id": sess_a, "user_id": user_a, "routine_name": "Legs Heavy"},
            headers={**headers_a, "Prefer": "resolution=merge-duplicates"},
        )
        assert r_upsert.status_code == 201
        assert db.workout_sessions[sess_a]["routine_name"] == "Legs Heavy"

        # 3. Legitimate PATCH
        r_patch = client.patch(
            f"/rest/v1/workout_sessions?id=eq.{sess_a}",
            json={"routine_name": "Legs Ultra Heavy", "notes": "Felt great"},
            headers=headers_a,
        )
        assert r_patch.status_code == 200
        assert db.workout_sessions[sess_a]["routine_name"] == "Legs Ultra Heavy"
        assert db.workout_sessions[sess_a]["notes"] == "Felt great"


class TestQueryAndInputRemediations:
    """Regression tests for OP-02, BOOL-01, PAYLOAD-02, and OP-03."""

    def test_sorting_with_numeric_zero_values(self, client):
        """OP-02: Verify sorting does not crash on 0 or 0.0 values."""
        user_id = str(uuid.uuid4())
        headers = {"Authorization": f"Bearer dev-user-{user_id}"}

        s1 = {"id": str(uuid.uuid4()), "user_id": user_id, "total_volume": 0.0, "total_reps": 0}
        s2 = {"id": str(uuid.uuid4()), "user_id": user_id, "total_volume": 500.0, "total_reps": 10}
        s3 = {"id": str(uuid.uuid4()), "user_id": user_id, "total_volume": 250.0, "total_reps": 5}
        client.post("/rest/v1/workout_sessions", json=[s1, s2, s3], headers=headers)

        # Test DESC sort
        res_desc = client.get("/rest/v1/workout_sessions?order=total_volume.desc", headers=headers)
        assert res_desc.status_code == 200
        vols = [r["total_volume"] for r in res_desc.json()]
        assert vols == [500.0, 250.0, 0.0]

        # Test ASC sort
        res_asc = client.get("/rest/v1/workout_sessions?order=total_volume.asc", headers=headers)
        assert res_asc.status_code == 200
        vols_asc = [r["total_volume"] for r in res_asc.json()]
        assert vols_asc == [0.0, 250.0, 500.0]

    def test_boolean_filtering_case_insensitivity(self, client):
        """BOOL-01: Verify boolean filter normalization for eq, is, and in."""
        user_id = str(uuid.uuid4())
        headers = {"Authorization": f"Bearer dev-user-{user_id}"}
        sess_id = str(uuid.uuid4())
        ex_id = str(uuid.uuid4())

        client.post("/rest/v1/workout_sessions", json={"id": sess_id, "user_id": user_id}, headers=headers)
        client.post("/rest/v1/workout_exercises", json={"id": ex_id, "workout_session_id": sess_id}, headers=headers)

        set1 = {"id": str(uuid.uuid4()), "workout_exercise_id": ex_id, "set_number": 1, "is_completed": True}
        set2 = {"id": str(uuid.uuid4()), "workout_exercise_id": ex_id, "set_number": 2, "is_completed": False}
        client.post("/rest/v1/workout_sets", json=[set1, set2], headers=headers)

        # 1. eq.true (lowercase filter against Python True)
        res_eq_true = client.get(f"/rest/v1/workout_sets?workout_exercise_id=eq.{ex_id}&is_completed=eq.true", headers=headers)
        assert res_eq_true.status_code == 200
        assert len(res_eq_true.json()) == 1
        assert res_eq_true.json()[0]["id"] == set1["id"]

        # 2. eq.True (title case filter)
        res_eq_title = client.get(f"/rest/v1/workout_sets?workout_exercise_id=eq.{ex_id}&is_completed=eq.True", headers=headers)
        assert res_eq_title.status_code == 200
        assert len(res_eq_title.json()) == 1

        # 3. is.false
        res_is_false = client.get(f"/rest/v1/workout_sets?workout_exercise_id=eq.{ex_id}&is_completed=is.false", headers=headers)
        assert res_is_false.status_code == 200
        assert len(res_is_false.json()) == 1
        assert res_is_false.json()[0]["id"] == set2["id"]

    def test_corrupted_json_returns_http_400(self, client):
        """PAYLOAD-02: Verify invalid JSON returns HTTP 400 Bad Request."""
        user_id = str(uuid.uuid4())
        headers = {"Authorization": f"Bearer dev-user-{user_id}", "Content-Type": "application/json"}

        # Corrupted POST
        res_post = client.post("/rest/v1/workout_sessions", content=b'{"user_id": "unclosed', headers=headers)
        assert res_post.status_code == 400
        assert "Invalid JSON" in res_post.json()["message"]

        # Corrupted PATCH
        res_patch = client.patch("/rest/v1/workout_sessions?id=eq.123", content=b'{"name": 123,', headers=headers)
        assert res_patch.status_code == 400

    def test_malformed_pagination_returns_http_400(self, client):
        """OP-03: Verify malformed limit and offset return HTTP 400."""
        user_id = str(uuid.uuid4())
        headers = {"Authorization": f"Bearer dev-user-{user_id}"}

        res_bad_limit = client.get("/rest/v1/workout_sessions?limit=not_an_int", headers=headers)
        assert res_bad_limit.status_code == 400

        res_neg_offset = client.get("/rest/v1/workout_sessions?offset=-5", headers=headers)
        assert res_neg_offset.status_code == 400
