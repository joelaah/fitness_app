#!/usr/bin/env python3
"""
PulseFit AI - Multi-User Integration & Concurrency Test Suite
============================================================
Validates multi-tenant data isolation, concurrent user sessions,
Row-Level Security (RLS) enforcement, and race-condition immunity.
"""

import concurrent.futures
import uuid
import pytest
from starlette.testclient import TestClient

from staging.mock_supabase_server import app, db


@pytest.fixture
def test_app():
    """Provides an isolated mock Supabase server instance."""
    db.reset()
    client = TestClient(app)
    return client


def create_authenticated_user(client: TestClient, prefix: str = "user") -> dict:
    """Helper to create and log in a unique test user."""
    uid = uuid.uuid4().hex[:8]
    email = f"{prefix}_{uid}@pulsefit.test"
    password = f"P@ssword_{uid}!"

    resp = client.post("/auth/v1/signup", json={"email": email, "password": password})
    assert resp.status_code == 200, f"Signup failed: {resp.text}"
    data = resp.json()

    user_id = data["user"]["id"]
    token = data["access_token"]
    headers = {
        "Authorization": f"Bearer {token}",
        "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.mock_anon",
        "Content-Type": "application/json",
    }
    return {
        "user_id": user_id,
        "email": email,
        "token": token,
        "headers": headers,
    }


class TestMultiUserIntegration:
    """Multi-User Concurrency & Data Isolation Tests."""

    def test_multi_user_creation_and_jwt_issuance(self, test_app):
        """Validates that multiple independent users can sign up with unique JWT tokens."""
        user1 = create_authenticated_user(test_app, "alice")
        user2 = create_authenticated_user(test_app, "bob")

        assert user1["user_id"] != user2["user_id"]
        assert user1["token"] != user2["token"]
        assert user1["email"] != user2["email"]

    def test_cross_tenant_data_isolation_read(self, test_app):
        """Verifies that User B cannot read User A's private workout sessions (RLS)."""
        user_a = create_authenticated_user(test_app, "alice")
        user_b = create_authenticated_user(test_app, "bob")

        # User A creates a workout session
        session_id = str(uuid.uuid4())
        resp = test_app.post(
            "/rest/v1/workout_sessions",
            headers=user_a["headers"],
            json={
                "id": session_id,
                "user_id": user_a["user_id"],
                "routine_name": "Alice's Heavy Leg Day",
                "started_at": "2026-10-12T08:00:00Z",
                "total_volume": 5000.0,
            },
        )
        assert resp.status_code == 201

        # User A can query their workout
        res_a = test_app.get(f"/rest/v1/workout_sessions?id=eq.{session_id}", headers=user_a["headers"])
        assert res_a.status_code == 200
        items_a = res_a.json()
        assert len(items_a) == 1
        assert items_a[0]["routine_name"] == "Alice's Heavy Leg Day"

        # User B queries workout_sessions -> must receive 0 items (RLS isolation)
        res_b = test_app.get(f"/rest/v1/workout_sessions?id=eq.{session_id}", headers=user_b["headers"])
        assert res_b.status_code == 200
        items_b = res_b.json()
        assert len(items_b) == 0, "Security Violation: User B was able to see User A's workout session!"

    def test_cross_tenant_tamper_prevention(self, test_app):
        """Verifies that User B cannot modify or delete User A's workout data."""
        user_a = create_authenticated_user(test_app, "alice")
        user_b = create_authenticated_user(test_app, "bob")

        session_id = str(uuid.uuid4())
        test_app.post(
            "/rest/v1/workout_sessions",
            headers=user_a["headers"],
            json={
                "id": session_id,
                "user_id": user_a["user_id"],
                "routine_name": "Chest Hypertrophy",
                "started_at": "2026-10-12T09:00:00Z",
            },
        )

        # User B tries to PATCH User A's workout
        patch_res = test_app.patch(
            f"/rest/v1/workout_sessions?id=eq.{session_id}",
            headers=user_b["headers"],
            json={"routine_name": "Hacked Routine"},
        )
        # Should be forbidden or return 0 rows affected
        if patch_res.status_code == 200:
            assert len(patch_res.json()) == 0

        # Verify User A's data remains untouched
        verify_res = test_app.get(f"/rest/v1/workout_sessions?id=eq.{session_id}", headers=user_a["headers"])
        assert verify_res.json()[0]["routine_name"] == "Chest Hypertrophy"

    def test_concurrent_multi_user_write_burst(self, test_app):
        """Simulates 10 concurrent users actively logging workouts simultaneously."""
        users = [create_authenticated_user(test_app, f"runner_{i}") for i in range(10)]
        created_session_ids = {}

        def log_workout_worker(user):
            s_id = str(uuid.uuid4())
            res = test_app.post(
                "/rest/v1/workout_sessions",
                headers=user["headers"],
                json={
                    "id": s_id,
                    "user_id": user["user_id"],
                    "routine_name": f"Workout for {user['email']}",
                    "started_at": "2026-10-12T10:00:00Z",
                    "total_volume": 3200.0,
                },
            )
            assert res.status_code == 201
            return user["user_id"], s_id

        # Execute concurrent writes
        with concurrent.futures.ThreadPoolExecutor(max_workers=10) as executor:
            results = list(executor.map(log_workout_worker, users))

        for uid, sid in results:
            created_session_ids[uid] = sid

        # Verify each user sees exactly their own workout and only their own
        for user in users:
            my_sid = created_session_ids[user["user_id"]]
            q_res = test_app.get("/rest/v1/workout_sessions", headers=user["headers"])
            assert q_res.status_code == 200
            user_sessions = q_res.json()

            # Must contain user's workout
            assert any(s["id"] == my_sid for s in user_sessions)
            # Must NOT contain any other user's workout
            for s in user_sessions:
                assert s["user_id"] == user["user_id"], f"Data leak detected for user {user['email']}"
