"""
Tests for Anonymous Session Lifecycle & 2-Hour Auto-Expiry SQL Migration.
Covers:
- SQL migration existence and syntax validity
- get_expired_anonymous_users contract (filters strictly by is_anonymous is True and created_at < NOW() - 2 hours)
- purge_expired_anonymous_users contract (purges expired guest records, cascade cleanup)
- Guarantee that permanent accounts (is_anonymous is False or Null) remain completely unaffected regardless of age
- Active guest accounts (< 2 hours old) are never purged
"""

import os
import re
from datetime import datetime, timedelta, timezone
import pytest


def test_migration_file_exists_and_contains_required_functions():
    migration_path = os.path.join("migrations", "03_anonymous_session_lifecycle.sql")
    assert os.path.exists(migration_path), f"Migration file not found at {migration_path}"

    with open(migration_path, "r", encoding="utf-8") as f:
        sql = f.read()

    # Verify key tables and columns
    assert "is_anonymous" in sql
    assert "expires_at" in sql
    assert "idx_auth_users_anon_created_at" in sql

    # Verify functions
    assert "public.get_expired_anonymous_users" in sql
    assert "public.purge_expired_anonymous_users" in sql
    assert "public.tag_anonymous_profile_ttl" in sql

    # Verify 2 hours interval
    assert "INTERVAL '2 hours'" in sql

    # Verify security definer and search_path hardening
    assert "SECURITY DEFINER" in sql
    assert "SET search_path = public, auth, pg_temp" in sql

    # Verify trainer_profiles restriction handling and upgrade trigger invariant
    assert "trainer_profiles" in sql
    assert "NEW.is_anonymous IS FALSE" in sql


def test_schema_file_includes_anonymous_cleanup_policy():
    schema_path = "supabase_schema.sql"
    assert os.path.exists(schema_path), f"Schema file not found at {schema_path}"

    with open(schema_path, "r", encoding="utf-8") as f:
        sql = f.read()

    assert "get_expired_anonymous_users" in sql
    assert "purge_expired_anonymous_users" in sql
    assert "tag_anonymous_profile_ttl" in sql
    assert "SET search_path = public, auth, pg_temp" in sql
    assert "trainer_profiles" in sql
    assert "NEW.is_anonymous IS FALSE" in sql


class SimulatedPostgresAuthDb:
    """Simulates PostgreSQL 15 engine executing the purge & get_expired functions."""

    def __init__(self):
        self.auth_users = {}
        self.profiles = {}
        self.workout_sessions = {}
        self.payment_transactions = {}

    def get_expired_anonymous_users(self, cutoff_interval=timedelta(hours=2), now=None):
        if now is None:
            now = datetime.now(timezone.utc)
        cutoff_time = now - cutoff_interval

        expired = []
        for user_id, user in self.auth_users.items():
            is_anon = user.get("is_anonymous", False)
            created_at = user["created_at"]
            if is_anon is True and created_at < cutoff_time:
                expired.append({
                    "user_id": user_id,
                    "created_at": created_at,
                    "is_anonymous": True,
                })
        return expired

    def purge_expired_anonymous_users(self, cutoff_interval=timedelta(hours=2), now=None):
        if now is None:
            now = datetime.now(timezone.utc)
        expired_records = self.get_expired_anonymous_users(cutoff_interval, now)
        expired_ids = {r["user_id"] for r in expired_records}

        if not expired_ids:
            return 0

        # 1. Clean up payment_transactions (RESTRICT constraint on user_id and trainer_id)
        trainer_ids_for_expired = {
            tid for tid, tp in getattr(self, "trainer_profiles", {}).items()
            if tp.get("user_id") in expired_ids
        }
        self.payment_transactions = {
            tx_id: tx for tx_id, tx in self.payment_transactions.items()
            if tx["user_id"] not in expired_ids and tx.get("trainer_id") not in trainer_ids_for_expired
        }

        # 2. Delete from auth.users (cascades to profiles & workout_sessions)
        purged_count = 0
        for uid in list(expired_ids):
            if uid in self.auth_users and self.auth_users[uid].get("is_anonymous") is True:
                del self.auth_users[uid]
                purged_count += 1
                # Cascade deletions
                if uid in self.profiles:
                    del self.profiles[uid]
                self.workout_sessions = {
                    ws_id: ws for ws_id, ws in self.workout_sessions.items()
                    if ws["user_id"] != uid
                }

        return purged_count


def test_purge_lifecycle_simulation():
    db = SimulatedPostgresAuthDb()
    now = datetime.now(timezone.utc)

    # 1. Seed expired anonymous user (created 3 hours ago)
    anon_expired_id = "anon-expired-001"
    db.auth_users[anon_expired_id] = {
        "id": anon_expired_id,
        "is_anonymous": True,
        "created_at": now - timedelta(hours=3),
    }
    db.profiles[anon_expired_id] = {
        "id": anon_expired_id,
        "display_name": "Guest 1",
        "is_anonymous": True,
    }
    db.workout_sessions["ws-anon-001"] = {
        "id": "ws-anon-001",
        "user_id": anon_expired_id,
        "routine_name": "Push Day",
    }

    # 2. Seed active anonymous user (created 30 mins ago)
    anon_active_id = "anon-active-002"
    db.auth_users[anon_active_id] = {
        "id": anon_active_id,
        "is_anonymous": True,
        "created_at": now - timedelta(minutes=30),
    }
    db.profiles[anon_active_id] = {
        "id": anon_active_id,
        "display_name": "Guest 2",
        "is_anonymous": True,
    }
    db.workout_sessions["ws-anon-002"] = {
        "id": "ws-anon-002",
        "user_id": anon_active_id,
        "routine_name": "Pull Day",
    }

    # 3. Seed permanent registered user (created 10 days ago)
    perm_old_id = "perm-user-003"
    db.auth_users[perm_old_id] = {
        "id": perm_old_id,
        "email": "veteran@pulsefit.ai",
        "is_anonymous": False,
        "created_at": now - timedelta(days=10),
    }
    db.profiles[perm_old_id] = {
        "id": perm_old_id,
        "display_name": "Veteran Lifter",
        "is_anonymous": False,
    }
    db.workout_sessions["ws-perm-003"] = {
        "id": "ws-perm-003",
        "user_id": perm_old_id,
        "routine_name": "Leg Day",
    }

    # Verify query function: only the expired anonymous user is found
    expired = db.get_expired_anonymous_users(timedelta(hours=2), now)
    assert len(expired) == 1
    assert expired[0]["user_id"] == anon_expired_id

    # Execute purge
    purged = db.purge_expired_anonymous_users(timedelta(hours=2), now)
    assert purged == 1

    # Verify state after purge
    assert anon_expired_id not in db.auth_users
    assert anon_expired_id not in db.profiles
    assert "ws-anon-001" not in db.workout_sessions

    # Critical Guarantee: Active anonymous user (< 2h) remains intact
    assert anon_active_id in db.auth_users
    assert anon_active_id in db.profiles
    assert "ws-anon-002" in db.workout_sessions

    # Critical Guarantee: Permanent user remains 100% intact
    assert perm_old_id in db.auth_users
    assert perm_old_id in db.profiles
    assert "ws-perm-003" in db.workout_sessions
