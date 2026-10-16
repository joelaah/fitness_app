#!/usr/bin/env python3
"""
PulseFit AI - Local Mock Supabase Server
========================================
High-throughput, in-memory FastAPI server emulating:
1. Supabase GoTrue Auth (/auth/v1/*): signup, token, user, admin users.
   Supports standard PyJWT, dev tokens (dev-user-*), and test-token.
2. PostgREST Table API (/rest/v1/*): CRUD, batch upsert, filtering, resource embedding.
3. Strict Row-Level Security (RLS): 14 policies exactly matching supabase_schema.sql.
"""

from __future__ import annotations

import argparse
import asyncio
import copy
import json
import logging
import os
import re
import time
import threading
import uuid
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional, Tuple, Union

import jwt
from fastapi import FastAPI, Header, HTTPException, Query, Request, Response, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import uvicorn

# ---------------------------------------------------------------------------
# Configuration & Constants
# ---------------------------------------------------------------------------

DEFAULT_PORT = 54321
DEFAULT_HOST = "0.0.0.0"

JWT_SECRET = os.getenv("JWT_SECRET", "super-secret-jwt-token-with-at-least-32-characters-long")
ANON_KEY = os.getenv("SUPABASE_ANON_KEY", "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.mock_anon")
SERVICE_ROLE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY", "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.mock_service_role")

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
log = logging.getLogger("mock_supabase")

# ---------------------------------------------------------------------------
# Database Storage Engine
# ---------------------------------------------------------------------------

class ThreadSafeAsyncRLock:
    """
    Thread-safe reentrant lock supporting both synchronous ('with lock:')
    and asynchronous ('async with lock:') context managers across multiple
    OS threads and event loops.
    """

    def __init__(self) -> None:
        self._lock = threading.RLock()

    def __enter__(self) -> bool:
        return self._lock.__enter__()

    def __exit__(self, exc_type: Any, exc_val: Any, exc_tb: Any) -> Any:
        return self._lock.__exit__(exc_type, exc_val, exc_tb)

    async def __aenter__(self) -> bool:
        return self._lock.__enter__()

    async def __aexit__(self, exc_type: Any, exc_val: Any, exc_tb: Any) -> Any:
        return self._lock.__exit__(exc_type, exc_val, exc_tb)

    def acquire(self, blocking: bool = True, timeout: float = -1) -> bool:
        return self._lock.acquire(blocking, timeout)

    def release(self) -> None:
        self._lock.release()


class MockDatabase:
    """Thread-safe in-memory datastore for Supabase tables."""

    def __init__(self) -> None:
        self.lock = ThreadSafeAsyncRLock()
        self.auth_users: Dict[str, Dict[str, Any]] = {}
        self.profiles: Dict[str, Dict[str, Any]] = {}
        self.workout_sessions: Dict[str, Dict[str, Any]] = {}
        self.workout_exercises: Dict[str, Dict[str, Any]] = {}
        self.workout_sets: Dict[str, Dict[str, Any]] = {}
        self.ai_recommendations: Dict[str, Dict[str, Any]] = {}
        self.exercises: Dict[str, Dict[str, Any]] = {}
        # Milestone 1: Trainer Marketplace, Payments & Chat Tables
        self.trainer_profiles: Dict[str, Dict[str, Any]] = {}
        self.payment_transactions: Dict[str, Dict[str, Any]] = {}
        self.chat_conversations: Dict[str, Dict[str, Any]] = {}
        self.chat_messages: Dict[str, Dict[str, Any]] = {}
        self.encryption_keys: Dict[str, Dict[str, Any]] = {}

    def get_table(self, name: str) -> Optional[Dict[str, Dict[str, Any]]]:
        return getattr(self, name, None)

    def reset(self) -> None:
        self.auth_users.clear()
        self.profiles.clear()
        self.workout_sessions.clear()
        self.workout_exercises.clear()
        self.workout_sets.clear()
        self.ai_recommendations.clear()
        self.exercises.clear()
        self.trainer_profiles.clear()
        self.payment_transactions.clear()
        self.chat_conversations.clear()
        self.chat_messages.clear()
        self.encryption_keys.clear()

db = MockDatabase()

# ---------------------------------------------------------------------------
# Auth Helpers
# ---------------------------------------------------------------------------

def normalize_user_id(token_or_id: str) -> str:
    """Ensure user identity is a valid UUIDv4 string."""
    try:
        return str(uuid.UUID(token_or_id))
    except (ValueError, AttributeError):
        return str(uuid.uuid5(uuid.NAMESPACE_DNS, token_or_id))

def get_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")

def create_mock_jwt(user_id: str, email: str, role: str = "authenticated") -> str:
    now = int(time.time())
    payload = {
        "iss": "supabase-mock",
        "sub": user_id,
        "aud": role,
        "role": role,
        "email": email,
        "exp": now + 3600 * 24,
        "iat": now,
    }
    return jwt.encode(payload, JWT_SECRET, algorithm="HS256")

def decode_token(token: str) -> Optional[Dict[str, Any]]:
    """
    Decodes and strictly validates a JWT token using JWT_SECRET and HS256.
    Enforces signature verification and expiration timestamps.
    Rejects expired tokens, invalid signatures, and malformed tokens.
    """
    try:
        return jwt.decode(
            token,
            JWT_SECRET,
            algorithms=["HS256"],
            options={"verify_signature": True, "verify_exp": True, "verify_aud": False},
        )
    except jwt.ExpiredSignatureError:
        log.warning("JWT validation rejected: Token has expired")
        return None
    except jwt.InvalidSignatureError:
        log.warning("JWT validation rejected: Invalid signature")
        return None
    except jwt.PyJWTError as e:
        log.warning("JWT decode error: %s", e)
        return None
    except Exception as e:
        log.warning("Unexpected error during JWT decode: %s", e)
        return None

def extract_auth_context(
    authorization: Optional[str] = None,
    apikey: Optional[str] = None,
) -> Tuple[bool, Optional[str]]:
    """
    Resolves caller authorization context.
    Returns:
        (is_service_role: bool, auth_uid: Optional[str])
    """
    # 1. Check apikey or bearer token for service role credentials
    candidates = [apikey]
    if authorization:
        candidates.append(authorization.replace("Bearer ", "").strip())

    for c in candidates:
        if not c:
            continue
        if c == SERVICE_ROLE_KEY or c == "mock-service-key":
            return True, None

    if not authorization:
        return False, None

    token = authorization.replace("Bearer ", "").strip()
    if not token:
        return False, None

    # 2. Check test / dev token overrides
    if token == "test-token":
        uid = "00000000-0000-0000-0000-000000000001"
        _ensure_user_exists(uid, "test-user@pulsefit.test")
        return False, uid

    if token.startswith("dev-user-"):
        raw_id = token[len("dev-user-"):]
        uid = normalize_user_id(raw_id)
        _ensure_user_exists(uid, f"{token}@pulsefit.test")
        return False, uid

    # 3. Standard JWT Token decode
    payload = decode_token(token)
    if not payload:
        return False, None

    role = payload.get("role")
    if role == "service_role":
        return True, None

    sub = payload.get("sub")
    if sub:
        uid = normalize_user_id(sub)
        email = payload.get("email", f"user-{uid[:8]}@pulsefit.test")
        _ensure_user_exists(uid, email)
        return False, uid

    return False, None

def _ensure_user_exists(uid: str, email: str) -> None:
    """Auto-provision user and profile records if absent in mock store."""
    now_iso = get_now_iso()
    if uid not in db.auth_users:
        db.auth_users[uid] = {
            "id": uid,
            "aud": "authenticated",
            "role": "authenticated",
            "email": email,
            "email_confirmed_at": now_iso,
            "created_at": now_iso,
            "updated_at": now_iso,
            "app_metadata": {"provider": "email", "providers": ["email"]},
            "user_metadata": {},
            "is_anonymous": False,
        }
    if uid not in db.profiles:
        db.profiles[uid] = {
            "id": uid,
            "display_name": email.split("@")[0],
            "experience_level": "intermediate",
            "preferred_training_goal": "hypertrophy",
            "created_at": now_iso,
        }

# ---------------------------------------------------------------------------
# Row Level Security (RLS) Engine — 14 Exact Policies
# ---------------------------------------------------------------------------

def check_row_select(
    table: str,
    row: Dict[str, Any],
    auth_uid: Optional[str],
    is_service_role: bool,
) -> bool:
    """
    Evaluates RLS SELECT policies matching supabase_schema.sql and 02_marketplace_payments_chat.sql.
    Returns True if row is readable by caller.
    """
    if is_service_role:
        return True

    # Publicly readable tables (anonymous or authenticated)
    if table in ("trainer_profiles", "exercises"):
        # Policy: "Public can view trainer profiles" (USING true)
        return True

    if not auth_uid:
        return False

    if table == "profiles":
        # Additive Policy: "Authenticated users can view profiles" (TO authenticated USING true)
        # Allows clients and trainers to resolve names and profiles across the marketplace
        return True

    if table == "encryption_keys":
        # Policy: "Authenticated users can view public keys" (TO authenticated USING true)
        return True

    if table == "payment_transactions":
        # Policy: "Users and trainers can view own transactions"
        # USING ((select auth.uid()) = user_id OR EXISTS (SELECT 1 FROM trainer_profiles tp WHERE tp.id = payment_transactions.trainer_id AND tp.user_id = (select auth.uid())))
        if row.get("user_id") == auth_uid:
            return True
        tid = row.get("trainer_id")
        if tid == auth_uid:
            return True
        t_prof = db.trainer_profiles.get(tid)
        if t_prof and (t_prof.get("user_id") == auth_uid or t_prof.get("id") == auth_uid):
            return True
        return False

    if table == "chat_conversations":
        # Policy: "Participants can view conversation"
        if row.get("user_id") == auth_uid:
            return True
        tid = row.get("trainer_id")
        if tid == auth_uid:
            return True
        t_prof = db.trainer_profiles.get(tid)
        if t_prof and (t_prof.get("user_id") == auth_uid or t_prof.get("id") == auth_uid):
            return True
        return False

    if table == "chat_messages":
        # Policy: "Participants can view messages"
        cid = row.get("conversation_id")
        conv = db.chat_conversations.get(cid)
        if not conv:
            return False
        if conv.get("user_id") == auth_uid:
            return True
        tid = conv.get("trainer_id")
        if tid == auth_uid:
            return True
        t_prof = db.trainer_profiles.get(tid)
        if t_prof and (t_prof.get("user_id") == auth_uid or t_prof.get("id") == auth_uid):
            return True
        return False

    if table == "workout_sessions":
        return row.get("user_id") == auth_uid

    if table == "workout_exercises":
        sess_id = row.get("workout_session_id")
        sess = db.workout_sessions.get(sess_id)
        return bool(sess and sess.get("user_id") == auth_uid)

    if table == "workout_sets":
        ex_id = row.get("workout_exercise_id")
        ex = db.workout_exercises.get(ex_id)
        if not ex:
            return False
        sess = db.workout_sessions.get(ex.get("workout_session_id"))
        return bool(sess and sess.get("user_id") == auth_uid)

    if table == "ai_recommendations":
        return row.get("user_id") == auth_uid

    return False

def check_row_insert(
    table: str,
    row: Dict[str, Any],
    auth_uid: Optional[str],
    is_service_role: bool,
) -> bool:
    """
    Evaluates RLS INSERT WITH CHECK policies matching supabase_schema.sql and 02_marketplace_payments_chat.sql.
    """
    if is_service_role:
        return True
    if not auth_uid:
        return False

    if table == "profiles":
        return row.get("id") == auth_uid

    if table == "trainer_profiles":
        # Policy: "Users can insert own trainer profile" WITH CHECK ((select auth.uid()) = user_id)
        return row.get("user_id") == auth_uid or row.get("id") == auth_uid

    if table == "payment_transactions":
        # Policy: "Users can insert payment transactions" WITH CHECK ((select auth.uid()) = user_id AND status = 'created')
        return row.get("user_id") == auth_uid and row.get("status", "created") == "created"

    if table == "chat_conversations":
        # Policy: "Participants can insert conversation"
        if row.get("user_id") == auth_uid:
            return True
        tid = row.get("trainer_id")
        if tid == auth_uid:
            return True
        t_prof = db.trainer_profiles.get(tid)
        if t_prof and (t_prof.get("user_id") == auth_uid or t_prof.get("id") == auth_uid):
            return True
        return False

    if table == "chat_messages":
        # Policy: "Participants can insert own message"
        # WITH CHECK ((select auth.uid()) = sender_id AND participant check)
        if row.get("sender_id") != auth_uid:
            return False
        cid = row.get("conversation_id")
        conv = db.chat_conversations.get(cid)
        if not conv:
            return False
        if conv.get("user_id") == auth_uid:
            return True
        tid = conv.get("trainer_id")
        if tid == auth_uid:
            return True
        t_prof = db.trainer_profiles.get(tid)
        if t_prof and (t_prof.get("user_id") == auth_uid or t_prof.get("id") == auth_uid):
            return True
        return False

    if table == "encryption_keys":
        # Policy: "Users can insert own public key" WITH CHECK ((select auth.uid()) = user_id)
        return row.get("user_id") == auth_uid or row.get("id") == auth_uid

    if table == "workout_sessions":
        return row.get("user_id") == auth_uid

    if table == "workout_exercises":
        sess_id = row.get("workout_session_id")
        sess = db.workout_sessions.get(sess_id)
        return bool(sess and sess.get("user_id") == auth_uid)

    if table == "workout_sets":
        ex_id = row.get("workout_exercise_id")
        ex = db.workout_exercises.get(ex_id)
        if not ex:
            return False
        sess = db.workout_sessions.get(ex.get("workout_session_id"))
        return bool(sess and sess.get("user_id") == auth_uid)

    if table == "ai_recommendations":
        return row.get("user_id") == auth_uid

    if table == "exercises":
        return is_service_role

    return False

def check_row_update(
    table: str,
    row: Dict[str, Any],
    auth_uid: Optional[str],
    is_service_role: bool,
) -> bool:
    """
    Evaluates RLS UPDATE USING policies.
    """
    if is_service_role:
        return True
    if not auth_uid:
        return False

    if table == "profiles":
        return row.get("id") == auth_uid

    if table == "trainer_profiles":
        # Policy: "Trainers can update own profile" USING ((select auth.uid()) = user_id)
        return row.get("user_id") == auth_uid or row.get("id") == auth_uid

    if table == "payment_transactions":
        # Policy: "Users can update pending transaction" USING ((select auth.uid()) = user_id AND status = 'created')
        return row.get("user_id") == auth_uid and row.get("status") in ("created", "pending")

    if table == "chat_conversations":
        # Policy: "Participants can update conversation"
        if row.get("user_id") == auth_uid:
            return True
        tid = row.get("trainer_id")
        if tid == auth_uid:
            return True
        t_prof = db.trainer_profiles.get(tid)
        if t_prof and (t_prof.get("user_id") == auth_uid or t_prof.get("id") == auth_uid):
            return True
        return False

    if table == "chat_messages":
        # Policy: "Participants can update message read_at"
        cid = row.get("conversation_id")
        conv = db.chat_conversations.get(cid)
        if not conv:
            return False
        if conv.get("user_id") == auth_uid:
            return True
        tid = conv.get("trainer_id")
        if tid == auth_uid:
            return True
        t_prof = db.trainer_profiles.get(tid)
        if t_prof and (t_prof.get("user_id") == auth_uid or t_prof.get("id") == auth_uid):
            return True
        return False

    if table == "encryption_keys":
        # Policy: "Users can update own public key" USING ((select auth.uid()) = user_id)
        return row.get("user_id") == auth_uid or row.get("id") == auth_uid

    if table == "workout_sessions":
        return row.get("user_id") == auth_uid

    if table == "workout_exercises":
        sess_id = row.get("workout_session_id")
        sess = db.workout_sessions.get(sess_id)
        return bool(sess and sess.get("user_id") == auth_uid)

    if table == "workout_sets":
        ex_id = row.get("workout_exercise_id")
        ex = db.workout_exercises.get(ex_id)
        if not ex:
            return False
        sess = db.workout_sessions.get(ex.get("workout_session_id"))
        return bool(sess and sess.get("user_id") == auth_uid)

    if table in ("ai_recommendations", "exercises"):
        return False

    return False

def check_row_update_check(
    table: str,
    row: Dict[str, Any],
    auth_uid: Optional[str],
    is_service_role: bool,
) -> bool:
    """
    Evaluates RLS UPDATE WITH CHECK policies matching supabase_schema.sql.
    Ensures tenant ownership cannot be reassigned across tenants.
    """
    if is_service_role:
        return True
    if not auth_uid:
        return False

    if table in ("workout_sessions", "ai_recommendations"):
        if "user_id" in row and row.get("user_id") != auth_uid:
            return False

    if table == "profiles":
        if "id" in row and row.get("id") != auth_uid:
            return False

    if table == "trainer_profiles":
        if "user_id" in row and row.get("user_id") != auth_uid:
            return False

    if table == "payment_transactions":
        if "user_id" in row and row.get("user_id") != auth_uid:
            return False
        if row.get("status") != "created":
            return False

    if table == "encryption_keys":
        if "user_id" in row and row.get("user_id") != auth_uid:
            return False

    return check_row_update(table, row, auth_uid, is_service_role)

def check_row_delete(
    table: str,
    row: Dict[str, Any],
    auth_uid: Optional[str],
    is_service_role: bool,
) -> bool:
    """
    Evaluates RLS DELETE policies matching supabase_schema.sql.
    """
    if is_service_role:
        return True
    if not auth_uid:
        return False

    if table == "trainer_profiles":
        # Policy: "Trainers can delete own profile" USING ((select auth.uid()) = user_id)
        return row.get("user_id") == auth_uid or row.get("id") == auth_uid

    if table == "encryption_keys":
        # Policy: "Users can delete own public key" USING ((select auth.uid()) = user_id)
        return row.get("user_id") == auth_uid or row.get("id") == auth_uid

    if table == "chat_messages":
        # Sender can delete message
        return row.get("sender_id") == auth_uid

    if table == "chat_conversations":
        return row.get("user_id") == auth_uid

    if table == "workout_sessions":
        return row.get("user_id") == auth_uid

    if table == "workout_exercises":
        sess_id = row.get("workout_session_id")
        sess = db.workout_sessions.get(sess_id)
        return bool(sess and sess.get("user_id") == auth_uid)

    if table == "workout_sets":
        ex_id = row.get("workout_exercise_id")
        ex = db.workout_exercises.get(ex_id)
        if not ex:
            return False
        sess = db.workout_sessions.get(ex.get("workout_session_id"))
        return bool(sess and sess.get("user_id") == auth_uid)

    # profiles, payment_transactions, ai_recommendations, exercises
    return False

# ---------------------------------------------------------------------------
# Filter Operator Evaluation Helper
# ---------------------------------------------------------------------------

def compare_values(field_val: Any, op: str, filter_val: str) -> bool:
    """Evaluates PostgREST comparison operators on a row value with type normalization."""
    # IS operator: null, not.null, true, false
    if op == "is":
        f_lower = filter_val.lower()
        if f_lower == "null":
            return field_val is None
        if f_lower == "not.null":
            return field_val is not None
        if f_lower in ("true", "false"):
            if field_val is None:
                return False
            return str(field_val).lower() == f_lower
        return False

    if field_val is None:
        return False

    # EQ and NEQ operators: boolean normalization and numerical equality fallback
    if op in ("eq", "neq"):
        # 1. Boolean comparison (case-insensitive)
        if isinstance(field_val, bool) or filter_val.lower() in ("true", "false"):
            f_lower = str(field_val).lower()
            t_lower = filter_val.lower()
            if f_lower in ("true", "false") and t_lower in ("true", "false"):
                matches = (f_lower == t_lower)
                return matches if op == "eq" else not matches
            if isinstance(field_val, bool) or t_lower in ("true", "false"):
                return False if op == "eq" else True

        # 2. Numerical equality fallback (e.g. 5000.0 == 5000)
        if not isinstance(field_val, bool):
            try:
                f_num = float(field_val)
                t_num = float(filter_val)
                matches = (f_num == t_num)
                return matches if op == "eq" else not matches
            except (ValueError, TypeError):
                pass

        # 3. String comparison fallback
        matches = (str(field_val) == filter_val)
        return matches if op == "eq" else not matches

    # IN operator: in.(val1,val2,val3)
    if op == "in":
        clean = filter_val.strip("()")
        options = [v.strip() for v in clean.split(",") if v.strip()]
        if isinstance(field_val, bool):
            options_lower = [v.lower() for v in options]
            return str(field_val).lower() in options_lower
        if not isinstance(field_val, bool):
            try:
                f_num = float(field_val)
                for opt in options:
                    try:
                        if float(opt) == f_num:
                            return True
                    except (ValueError, TypeError):
                        pass
            except (ValueError, TypeError):
                pass
        return str(field_val) in options

    # CS operator: contains (for arrays or lists, e.g. specialties=cs.{Strength})
    if op == "cs":
        if isinstance(field_val, list):
            target = filter_val.strip("{}()\"'")
            targets = [t.strip().strip("\"'").lower() for t in target.split(",") if t.strip()]
            field_val_lower = [str(x).strip().strip("\"'").lower() for x in field_val]
            return all(t in field_val_lower for t in targets)
        return filter_val.lower() in str(field_val).lower()

    # Numerical / Datetime ordering operators
    try:
        f_num = float(field_val)
        t_num = float(filter_val)
        if op == "gt":
            return f_num > t_num
        if op == "gte":
            return f_num >= t_num
        if op == "lt":
            return f_num < t_num
        if op == "lte":
            return f_num <= t_num
    except (ValueError, TypeError):
        pass

    # String comparison fallback (works for ISO datetime strings)
    f_str = str(field_val)
    t_str = str(filter_val)
    if op == "gt":
        return f_str > t_str
    if op == "gte":
        return f_str >= t_str
    if op == "lt":
        return f_str < t_str
    if op == "lte":
        return f_str <= t_str

    return False

# ---------------------------------------------------------------------------
# FastAPI Application
# ---------------------------------------------------------------------------

app = FastAPI(
    title="PulseFit Mock Supabase Server",
    description="Offline staging environment for Supabase GoTrue Auth, PostgREST CRUD, and RLS validation.",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ---------------------------------------------------------------------------
# GoTrue Auth Endpoints (/auth/v1/*)
# ---------------------------------------------------------------------------

@app.post("/auth/v1/signup")
async def auth_signup(request: Request) -> Dict[str, Any]:
    body: Dict[str, Any] = {}
    if await request.body():
        try:
            body = await request.json()
        except Exception:
            pass

    email = body.get("email")
    is_anon = not bool(email)
    if is_anon:
        email = f"anon-{uuid.uuid4().hex[:8]}@pulsefit.test"

    user_id = str(uuid.uuid4())
    now_iso = get_now_iso()

    async with db.lock:
        user_record = {
            "id": user_id,
            "aud": "authenticated",
            "role": "authenticated",
            "email": email,
            "email_confirmed_at": now_iso,
            "created_at": now_iso,
            "updated_at": now_iso,
            "app_metadata": {"provider": "email", "providers": ["email"]},
            "user_metadata": body.get("data", {}),
            "is_anonymous": is_anon,
        }
        db.auth_users[user_id] = user_record

        # Automatically provision profiles row matching Supabase trigger
        db.profiles[user_id] = {
            "id": user_id,
            "display_name": body.get("data", {}).get("display_name", email.split("@")[0]),
            "experience_level": body.get("data", {}).get("experience_level", "intermediate"),
            "preferred_training_goal": body.get("data", {}).get("preferred_training_goal", "hypertrophy"),
            "created_at": now_iso,
        }

    token = create_mock_jwt(user_id, email)
    return {
        "access_token": token,
        "token_type": "bearer",
        "expires_in": 86400,
        "expires_at": int(time.time()) + 86400,
        "refresh_token": f"mock-refresh-{uuid.uuid4()}",
        "user": user_record,
    }

@app.post("/auth/v1/token")
async def auth_token(request: Request) -> Dict[str, Any]:
    body: Dict[str, Any] = {}
    if await request.body():
        try:
            body = await request.json()
        except Exception:
            pass

    grant_type = request.query_params.get("grant_type") or body.get("grant_type", "password")
    email = body.get("email")

    async with db.lock:
        target_user = None
        if email:
            for u in db.auth_users.values():
                if u.get("email") == email:
                    target_user = u
                    break

        if not target_user:
            # Auto-provision on test logins for frictionless testing
            user_id = str(uuid.uuid4())
            now_iso = get_now_iso()
            target_user = {
                "id": user_id,
                "aud": "authenticated",
                "role": "authenticated",
                "email": email or f"user-{user_id[:8]}@pulsefit.test",
                "email_confirmed_at": now_iso,
                "created_at": now_iso,
                "updated_at": now_iso,
                "app_metadata": {"provider": "email", "providers": ["email"]},
                "user_metadata": {},
                "is_anonymous": False,
            }
            db.auth_users[user_id] = target_user
            db.profiles[user_id] = {
                "id": user_id,
                "display_name": (email or "user").split("@")[0],
                "experience_level": "intermediate",
                "preferred_training_goal": "hypertrophy",
                "created_at": now_iso,
            }

    token = create_mock_jwt(target_user["id"], target_user["email"])
    return {
        "access_token": token,
        "token_type": "bearer",
        "expires_in": 86400,
        "expires_at": int(time.time()) + 86400,
        "refresh_token": f"mock-refresh-{uuid.uuid4()}",
        "user": target_user,
    }

@app.get("/auth/v1/user")
async def auth_get_user(
    authorization: Optional[str] = Header(None),
    apikey: Optional[str] = Header(None),
) -> Dict[str, Any]:
    is_admin, user_id = extract_auth_context(authorization, apikey)
    if not user_id and not is_admin:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or missing Supabase authentication token",
        )

    target_id = user_id or "00000000-0000-0000-0000-000000000001"
    async with db.lock:
        user_record = db.auth_users.get(target_id)
        if not user_record:
            now_iso = get_now_iso()
            user_record = {
                "id": target_id,
                "aud": "authenticated",
                "role": "authenticated",
                "email": f"user-{target_id[:8]}@pulsefit.test",
                "email_confirmed_at": now_iso,
                "created_at": now_iso,
                "updated_at": now_iso,
                "app_metadata": {"provider": "email", "providers": ["email"]},
                "user_metadata": {},
                "is_anonymous": False,
            }
            db.auth_users[target_id] = user_record
    return user_record

@app.post("/auth/v1/admin/users")
async def auth_admin_create_user(
    request: Request,
    authorization: Optional[str] = Header(None),
    apikey: Optional[str] = Header(None),
) -> Dict[str, Any]:
    is_admin, _ = extract_auth_context(authorization, apikey)
    if not is_admin:
        raise HTTPException(status_code=403, detail="Service role key required for admin user creation")

    body = await request.json()
    user_id = body.get("id") or str(uuid.uuid4())
    email = body.get("email") or f"user-{user_id[:8]}@pulsefit.test"
    password = body.get("password")
    now_iso = get_now_iso()

    async with db.lock:
        user_record = {
            "id": user_id,
            "aud": "authenticated",
            "role": "authenticated",
            "email": email,
            "password": password,
            "email_confirmed_at": now_iso,
            "created_at": now_iso,
            "updated_at": now_iso,
            "app_metadata": {"provider": "email", "providers": ["email"]},
            "user_metadata": body.get("user_metadata", {}),
            "is_anonymous": False,
        }
        db.auth_users[user_id] = user_record
        db.profiles[user_id] = {
            "id": user_id,
            "display_name": body.get("user_metadata", {}).get("display_name", email.split("@")[0]),
            "experience_level": body.get("user_metadata", {}).get("experience_level", "intermediate"),
            "preferred_training_goal": body.get("user_metadata", {}).get("preferred_training_goal", "hypertrophy"),
            "created_at": now_iso,
        }

    return user_record

# ---------------------------------------------------------------------------
# PostgREST Data API Endpoints (/rest/v1/{table})
# ---------------------------------------------------------------------------

def build_sort_key(col: str, desc: bool, parts: List[str]):
    """
    Constructs a type-safe sorting key function for PostgREST order parameters.
    Handles nulls (nullsfirst/nullslast), booleans, numbers (0/0.0), and strings
    without triggering Python cross-type comparison TypeErrors.
    """
    nullsfirst = "nullsfirst" in parts
    nullslast = "nullslast" in parts

    def sort_key(r: dict) -> tuple:
        val = r.get(col)
        if val is None:
            if nullsfirst:
                null_rank = 1 if desc else 0
            elif nullslast:
                null_rank = 0 if desc else 1
            else:
                # PostgreSQL / PostgREST default:
                # ASC: NULLS LAST (1 in normal sort)
                # DESC: NULLS FIRST (1 in reverse sort)
                null_rank = 1
            return (null_rank, 0, 0.0, "")

        # Determine non-null value rank relative to nulls
        if nullsfirst:
            val_rank = 0 if desc else 1
        elif nullslast:
            val_rank = 1 if desc else 0
        else:
            val_rank = 0

        # Disambiguate types with explicit type code to prevent cross-type comparisons
        if isinstance(val, bool):
            return (val_rank, 1, 1.0 if val else 0.0, "")
        elif isinstance(val, (int, float)):
            return (val_rank, 2, float(val), "")
        else:
            return (val_rank, 3, 0.0, str(val))

    return sort_key

@app.get("/rest/v1/{table}")
async def rest_get(
    table: str,
    request: Request,
    authorization: Optional[str] = Header(None),
    apikey: Optional[str] = Header(None),
    accept: Optional[str] = Header(None),
) -> Any:
    tbl = db.get_table(table)
    if tbl is None:
        raise HTTPException(status_code=404, detail=f"Table {table} not found")

    is_admin, auth_uid = extract_auth_context(authorization, apikey)
    params = dict(request.query_params)

    async with db.lock:
        # Step 1: Apply Row Level Security filter
        accessible_rows = [
            copy.deepcopy(r)
            for r in tbl.values()
            if check_row_select(table, r, auth_uid, is_admin)
        ]

    # Step 2: Apply query filters
    filtered_rows = []
    query_items = request.query_params.multi_items()
    for row in accessible_rows:
        matches = True
        for key, val in query_items:
            if key in ("select", "order", "limit", "offset", "on_conflict"):
                continue

            # Parse operator: e.g. eq.123 or in.(a,b)
            if "." in val:
                op, filter_val = val.split(".", 1)
                row_val = row.get(key)
                if not compare_values(row_val, op, filter_val):
                    matches = False
                    break
            else:
                row_val = row.get(key)
                if isinstance(row_val, bool) or val.lower() in ("true", "false"):
                    if str(row_val).lower() != val.lower():
                        matches = False
                        break
                elif str(row_val if row_val is not None else "") != val:
                    matches = False
                    break

        if matches:
            filtered_rows.append(row)

    # Step 3: Sorting / Ordering
    if "order" in params:
        order_spec = params["order"]
        # order=started_at.desc or order=started_at.desc.nullslast
        parts = order_spec.split(".")
        col = parts[0]
        desc = "desc" in parts
        filtered_rows.sort(
            key=build_sort_key(col, desc, parts),
            reverse=desc,
        )

    # Step 4: Pagination (offset / limit)
    try:
        offset = int(params.get("offset", 0))
        if offset < 0:
            return JSONResponse(
                status_code=400,
                content={"code": "PGRST103", "message": "Invalid offset parameter: must be non-negative integer"},
            )
    except ValueError:
        return JSONResponse(
            status_code=400,
            content={"code": "PGRST103", "message": "Invalid offset parameter: must be an integer"},
        )

    limit = None
    if "limit" in params:
        try:
            limit = int(params["limit"])
            if limit < 0:
                return JSONResponse(
                    status_code=400,
                    content={"code": "PGRST103", "message": "Invalid limit parameter: must be non-negative integer"},
                )
        except ValueError:
            return JSONResponse(
                status_code=400,
                content={"code": "PGRST103", "message": "Invalid limit parameter: must be an integer"},
            )

    if limit is not None:
        result_rows = filtered_rows[offset : offset + limit]
    elif offset > 0:
        result_rows = filtered_rows[offset:]
    else:
        result_rows = filtered_rows

    # Step 5: Resource Embedding (select=*, workout_exercises(*, workout_sets(*)))
    select_param = params.get("select", "")
    if "workout_exercises" in select_param and table == "workout_sessions":
        async with db.lock:
            for s in result_rows:
                sess_id = s.get("id")
                # Find matching workout exercises
                exs = [
                    copy.deepcopy(e)
                    for e in db.workout_exercises.values()
                    if e.get("workout_session_id") == sess_id
                ]
                exs.sort(key=lambda x: x.get("order_index", 0))

                # If workout_sets requested inside workout_exercises
                if "workout_sets" in select_param:
                    for e in exs:
                        eid = e.get("id")
                        sets = [
                            copy.deepcopy(st)
                            for st in db.workout_sets.values()
                            if st.get("workout_exercise_id") == eid
                        ]
                        sets.sort(key=lambda x: x.get("set_number", 0))
                        e["workout_sets"] = sets

                s["workout_exercises"] = exs

    elif "workout_sets" in select_param and table == "workout_exercises":
        async with db.lock:
            for e in result_rows:
                eid = e.get("id")
                sets = [
                    copy.deepcopy(st)
                    for st in db.workout_sets.values()
                    if st.get("workout_exercise_id") == eid
                ]
                sets.sort(key=lambda x: x.get("set_number", 0))
                e["workout_sets"] = sets

    elif table == "chat_conversations":
        async with db.lock:
            for c in result_rows:
                cid = c.get("id")
                if "chat_messages" in select_param:
                    msgs = [
                        copy.deepcopy(m)
                        for m in db.chat_messages.values()
                        if m.get("conversation_id") == cid
                    ]
                    msgs.sort(key=lambda x: str(x.get("created_at", "")))
                    c["chat_messages"] = msgs
                if "trainer_profiles" in select_param:
                    tid = c.get("trainer_id")
                    t_prof = db.trainer_profiles.get(tid)
                    c["trainer_profiles"] = copy.deepcopy(t_prof) if t_prof else None
                if "profiles" in select_param:
                    uid = c.get("user_id")
                    p = db.profiles.get(uid)
                    c["profiles"] = copy.deepcopy(p) if p else None

    elif table == "trainer_profiles" and "profiles" in select_param:
        async with db.lock:
            for tp in result_rows:
                uid = tp.get("user_id") or tp.get("id")
                p = db.profiles.get(uid)
                tp["profiles"] = copy.deepcopy(p) if p else None

    # Step 6: Handle single object request header: Accept: application/vnd.pgrst.object+json
    if accept and "application/vnd.pgrst.object+json" in accept:
        if not result_rows:
            return JSONResponse(status_code=404, content={"message": "JSON object not found"})
        return result_rows[0]

    return result_rows


# ---------------------------------------------------------------------------
# Check Constraints Validation Helper
# ---------------------------------------------------------------------------

def validate_check_constraints(table: str, row: Dict[str, Any]) -> Optional[JSONResponse]:
    """
    Validates SQL CHECK constraints across marketplace tables for both POST and PATCH.
    Returns a 400 Bad Request JSONResponse with code 23514 on violation, or None if valid.
    """
    if table == "trainer_profiles":
        try:
            hr = float(row.get("hourly_rate", 0.0))
            exp = int(row.get("experience_years", 0))
            rating = float(row.get("rating", 5.0))
            pct = float(row.get("platform_fee_pct", 10.0))
        except (ValueError, TypeError):
            return JSONResponse(
                status_code=400,
                content={"code": "23514", "message": "invalid numeric value for check constraint"},
            )
        if hr < 0.0:
            return JSONResponse(status_code=400, content={"code": "23514", "message": "hourly_rate must be non-negative"})
        if exp < 0:
            return JSONResponse(status_code=400, content={"code": "23514", "message": "experience_years must be non-negative"})
        if not (0.0 <= rating <= 5.0):
            return JSONResponse(status_code=400, content={"code": "23514", "message": "rating must be between 0.0 and 5.0"})
        if not (0.0 <= pct <= 100.0):
            return JSONResponse(status_code=400, content={"code": "23514", "message": "platform_fee_pct must be between 0.0 and 100.0"})

    elif table == "payment_transactions":
        try:
            amt = float(row.get("amount", 0.0))
            fee_val = row.get("platform_fee_amount")
            if fee_val is None:
                fee_val = row.get("platform_fee", 0.0)
            fee = float(fee_val)
            tr_amt = float(row.get("trainer_amount", 0.0))
        except (ValueError, TypeError):
            return JSONResponse(
                status_code=400,
                content={"code": "23514", "message": "invalid numeric value for check constraint"},
            )
        status_val = row.get("status", "created")
        if amt <= 0.0:
            return JSONResponse(status_code=400, content={"code": "23514", "message": "amount must be greater than 0"})
        if fee < 0.0 or tr_amt < 0.0:
            return JSONResponse(status_code=400, content={"code": "23514", "message": "fee and trainer_amount must be non-negative"})
        if abs(amt - (fee + tr_amt)) > 0.01:
            return JSONResponse(status_code=400, content={"code": "23514", "message": "amount must equal platform_fee + trainer_amount"})
        if status_val not in ("created", "authorized", "captured", "failed", "refunded"):
            return JSONResponse(status_code=400, content={"code": "23514", "message": "status invalid"})

    elif table == "encryption_keys":
        pk_val = row.get("public_key")
        if not pk_val or len(str(pk_val)) < 40:
            return JSONResponse(status_code=400, content={"code": "23514", "message": "public_key format invalid"})

    elif table == "chat_messages":
        nonce_val = row.get("nonce")
        if not nonce_val or len(str(nonce_val)) < 12:
            return JSONResponse(status_code=400, content={"code": "23514", "message": "nonce format invalid"})

    return None


@app.post("/rest/v1/{table}", status_code=status.HTTP_201_CREATED)
async def rest_post(
    table: str,
    request: Request,
    authorization: Optional[str] = Header(None),
    apikey: Optional[str] = Header(None),
    prefer: Optional[str] = Header(None),
) -> Any:
    tbl = db.get_table(table)
    if tbl is None:
        raise HTTPException(status_code=404, detail=f"Table {table} not found")

    is_admin, auth_uid = extract_auth_context(authorization, apikey)

    try:
        body = await request.json()
    except (json.JSONDecodeError, ValueError):
        return JSONResponse(
            status_code=400,
            content={"code": "PGRST100", "message": "Invalid JSON format in request body"},
        )

    if not isinstance(body, (dict, list)):
        return JSONResponse(
            status_code=400,
            content={"code": "PGRST100", "message": "Request body must be a JSON object or array of objects"},
        )

    items = body if isinstance(body, list) else [body]
    for item in items:
        if not isinstance(item, dict):
            return JSONResponse(
                status_code=400,
                content={"code": "PGRST100", "message": "Request body items must be JSON objects"},
            )

    on_conflict = request.query_params.get("on_conflict")
    is_upsert = (prefer and "resolution=merge-duplicates" in prefer) or bool(on_conflict)
    inserted_rows = []
    now_iso = get_now_iso()

    def resolve_existing_key(table_name: str, item: Dict[str, Any]) -> Optional[str]:
        # 1. Direct PK match
        if item.get("id") and str(item["id"]) in tbl:
            return str(item["id"])

        # 2. encryption_keys: UNIQUE (user_id)
        if table_name == "encryption_keys":
            uid = item.get("user_id") or item.get("id")
            for k, r in tbl.items():
                if r.get("user_id") == uid or k == uid:
                    return k

        # 3. trainer_profiles: UNIQUE (user_id)
        if table_name == "trainer_profiles":
            uid = item.get("user_id") or item.get("id")
            for k, r in tbl.items():
                if r.get("user_id") == uid or k == uid:
                    return k

        # 4. payment_transactions: UNIQUE (idempotency_key)
        if table_name == "payment_transactions":
            idem = item.get("idempotency_key")
            if idem:
                for k, r in tbl.items():
                    if r.get("idempotency_key") == idem:
                        return k

        # 5. chat_conversations: UNIQUE (user_id, trainer_id)
        if table_name == "chat_conversations":
            uid = item.get("user_id")
            tid = item.get("trainer_id")
            if uid and tid:
                for k, r in tbl.items():
                    if r.get("user_id") == uid and r.get("trainer_id") == tid:
                        return k

        # 6. chat_messages: UNIQUE (client_uuid)
        if table_name == "chat_messages":
            cuuid = item.get("client_uuid")
            if cuuid:
                for k, r in tbl.items():
                    if str(r.get("client_uuid")) == str(cuuid):
                        return k

        # 7. Explicit on_conflict parameter
        if on_conflict and on_conflict in item:
            val = item[on_conflict]
            for k, r in tbl.items():
                if r.get(on_conflict) == val:
                    return k

        return None

    async with db.lock:
        # Pre-validate check constraints and RLS on ALL rows before committing
        for item in items:
            # Payment status anti-forgery on INSERT: non-admins can only insert payments with status='created'
            if table == "payment_transactions" and not is_admin:
                if item.get("status", "created") != "created":
                    return JSONResponse(
                        status_code=403,
                        content={
                            "code": "42501",
                            "message": 'new row violates row-level security policy for table "payment_transactions"',
                        },
                    )

            # Check constraints validation
            err = validate_check_constraints(table, item)
            if err:
                return err

            existing_pk = resolve_existing_key(table, item)

            if existing_pk:
                if not is_upsert:
                    # Duplicate key error
                    log.warning("Duplicate key violation in %s on existing row %s: %s", table, existing_pk, item)
                    return JSONResponse(
                        status_code=409,
                        content={"code": "23505", "message": f'duplicate key value violates unique constraint for table "{table}"'},
                    )

                # Upsert: validate UPDATE RLS policies
                if not check_row_update(table, tbl[existing_pk], auth_uid, is_admin):
                    log.warning("RLS VIOLATION: User %s unauthorized to upsert-update %s pk=%s", auth_uid, table, existing_pk)
                    return JSONResponse(
                        status_code=403,
                        content={"code": "42501", "message": f'upsert violates row-level security policy for table "{table}"'},
                    )

                merged = copy.deepcopy(tbl[existing_pk])
                merged.update(item)
                err = validate_check_constraints(table, merged)
                if err:
                    return err
                if not check_row_update_check(table, merged, auth_uid, is_admin):
                    log.warning("RLS VIOLATION: User %s unauthorized WITH CHECK on upsert %s pk=%s", auth_uid, table, existing_pk)
                    return JSONResponse(
                        status_code=403,
                        content={"code": "42501", "message": f'new row violates row-level security policy for table "{table}"'},
                    )
            else:
                # Insert: validate INSERT RLS policies
                if not check_row_insert(table, item, auth_uid, is_admin):
                    log.warning("RLS VIOLATION: User %s unauthorized to insert into %s: %s", auth_uid, table, item)
                    return JSONResponse(
                        status_code=403,
                        content={"code": "42501", "message": f'new row violates row-level security policy for table "{table}"'},
                    )

        # Commit rows
        for item in items:
            existing_pk = resolve_existing_key(table, item)
            row = copy.deepcopy(item)

            if existing_pk and is_upsert:
                row["updated_at"] = now_iso
                if table == "trainer_profiles":
                    if "is_verified" in row and "verified" not in row:
                        row["verified"] = row["is_verified"]
                    elif "verified" in row and "is_verified" not in row:
                        row["is_verified"] = row["verified"]
                elif table == "payment_transactions":
                    if "order_id" in row and "razorpay_order_id" not in row:
                        row["razorpay_order_id"] = row["order_id"]
                    elif "razorpay_order_id" in row and "order_id" not in row:
                        row["order_id"] = row["razorpay_order_id"]
                    if "payment_id" in row and "razorpay_payment_id" not in row:
                        row["razorpay_payment_id"] = row["payment_id"]
                    elif "razorpay_payment_id" in row and "payment_id" not in row:
                        row["payment_id"] = row["razorpay_payment_id"]
                    if "platform_fee" in row and "platform_fee_amount" not in row:
                        row["platform_fee_amount"] = row["platform_fee"]
                    elif "platform_fee_amount" in row and "platform_fee" not in row:
                        row["platform_fee"] = row["platform_fee_amount"]
                elif table == "chat_messages":
                    if "read_at" in row and row["read_at"] and not row.get("is_read"):
                        row["is_read"] = True
                    elif row.get("is_read") and not row.get("read_at"):
                        row["read_at"] = now_iso

                tbl[existing_pk].update(row)
                inserted_rows.append(copy.deepcopy(tbl[existing_pk]))
            else:
                if "id" not in row or not row["id"]:
                    row["id"] = str(uuid.uuid4())
                if "created_at" not in row:
                    row["created_at"] = now_iso
                if "updated_at" not in row:
                    row["updated_at"] = now_iso

                # Defaults & field harmonization
                if table == "trainer_profiles":
                    row.setdefault("hourly_rate", 0.0)
                    row.setdefault("experience_years", 0)
                    row.setdefault("bio", "")
                    row.setdefault("certifications", [])
                    row.setdefault("specialties", [])
                    row.setdefault("availability", {"schedule": [], "active": True})
                    if not is_admin:
                        # Anti-tamper on INSERT: non-admins cannot override platform_fee_pct, rating, or verified
                        row["platform_fee_pct"] = 10.0
                        row["rating"] = 5.0
                        row["verified"] = True
                        row["is_verified"] = True
                    else:
                        row.setdefault("rating", 5.0)
                        row.setdefault("platform_fee_pct", 10.0)
                        if "is_verified" in row and "verified" not in row:
                            row["verified"] = row["is_verified"]
                        elif "verified" in row and "is_verified" not in row:
                            row["is_verified"] = row["verified"]
                        else:
                            row.setdefault("verified", True)
                            row.setdefault("is_verified", True)

                elif table == "payment_transactions":
                    row.setdefault("currency", "INR")
                    row.setdefault("status", "created")
                    row.setdefault("metadata", {})
                    row.setdefault("platform_fee_percent", 10.0)
                    if "order_id" in row and "razorpay_order_id" not in row:
                        row["razorpay_order_id"] = row["order_id"]
                    elif "razorpay_order_id" in row and "order_id" not in row:
                        row["order_id"] = row["razorpay_order_id"]
                    if "payment_id" in row and "razorpay_payment_id" not in row:
                        row["razorpay_payment_id"] = row["payment_id"]
                    elif "razorpay_payment_id" in row and "payment_id" not in row:
                        row["payment_id"] = row["razorpay_payment_id"]
                    if "platform_fee" in row and "platform_fee_amount" not in row:
                        row["platform_fee_amount"] = row["platform_fee"]
                    elif "platform_fee_amount" in row and "platform_fee" not in row:
                        row["platform_fee"] = row["platform_fee_amount"]

                elif table == "chat_messages":
                    row.setdefault("mac", "")
                    row.setdefault("is_read", False)
                    row.setdefault("read_at", None)
                    if "read_at" in row and row["read_at"] and not row.get("is_read"):
                        row["is_read"] = True
                    elif row.get("is_read") and not row.get("read_at"):
                        row["read_at"] = now_iso
                    if not row.get("client_uuid"):
                        row["client_uuid"] = str(uuid.uuid4())

                pk = str(row["id"])
                tbl[pk] = row
                inserted_rows.append(row)

    if prefer and "return=minimal" in prefer:
        return Response(status_code=201)

    return inserted_rows

@app.patch("/rest/v1/{table}")
async def rest_patch(
    table: str,
    request: Request,
    authorization: Optional[str] = Header(None),
    apikey: Optional[str] = Header(None),
    prefer: Optional[str] = Header(None),
) -> Any:
    tbl = db.get_table(table)
    if tbl is None:
        raise HTTPException(status_code=404, detail=f"Table {table} not found")

    is_admin, auth_uid = extract_auth_context(authorization, apikey)
    params = dict(request.query_params)

    try:
        body = await request.json()
    except (json.JSONDecodeError, ValueError):
        return JSONResponse(
            status_code=400,
            content={"code": "PGRST100", "message": "Invalid JSON format in request body"},
        )

    if not isinstance(body, dict):
        return JSONResponse(
            status_code=400,
            content={"code": "PGRST100", "message": "Request body must be a JSON object"},
        )

    updated_rows = []

    async with db.lock:
        target_pks = []
        for pk, r in tbl.items():
            if not check_row_update(table, r, auth_uid, is_admin):
                continue

            matches = True
            for k, v in params.items():
                if k in ("select", "order", "limit", "offset"):
                    continue
                if "." in v:
                    op, filter_val = v.split(".", 1)
                    if not compare_values(r.get(k), op, filter_val):
                        matches = False
                        break
                else:
                    row_val = r.get(k)
                    if isinstance(row_val, bool) or v.lower() in ("true", "false"):
                        if str(row_val).lower() != v.lower():
                            matches = False
                            break
                    elif str(row_val if row_val is not None else "") != v:
                        matches = False
                        break
            if matches:
                target_pks.append(pk)

        # Pre-validate WITH CHECK on ALL matching target rows before applying mutations
        for pk in target_pks:
            proposed = copy.deepcopy(tbl[pk])
            old_row = tbl[pk]

            # Anti-tamper checks for non-admin
            if not is_admin:
                if table == "trainer_profiles":
                    if ("verified" in body) or \
                       ("is_verified" in body) or \
                       ("platform_fee_pct" in body and body["platform_fee_pct"] != old_row.get("platform_fee_pct")) or \
                       ("rating" in body and body["rating"] != old_row.get("rating")):
                        return JSONResponse(
                            status_code=403,
                            content={"code": "42501", "message": "Trainers cannot modify verification, fee, or rating"},
                        )
                elif table == "payment_transactions":
                    # Non-admin cannot transition payment status to captured
                    if body.get("status") == "captured" or ("status" in body and body["status"] != "created"):
                        return JSONResponse(
                            status_code=403,
                            content={"code": "42501", "message": "Users cannot set payment status to captured"},
                        )
                elif table == "chat_messages":
                    tamper_fields = ("ciphertext", "nonce", "mac", "client_uuid", "conversation_id", "sender_id", "created_at")
                    if any(f in body and body[f] != old_row.get(f) for f in tamper_fields):
                        return JSONResponse(
                            status_code=403,
                            content={"code": "42501", "message": "Chat message content and metadata are strictly immutable"},
                        )

            proposed.update(body)
            proposed["updated_at"] = get_now_iso()

            # Harmonize fields
            if table == "trainer_profiles":
                if "is_verified" in body and "verified" not in body:
                    proposed["verified"] = proposed["is_verified"]
                elif "verified" in body and "is_verified" not in body:
                    proposed["is_verified"] = proposed["verified"]
            elif table == "payment_transactions":
                if "order_id" in body and "razorpay_order_id" not in body:
                    proposed["razorpay_order_id"] = proposed["order_id"]
                elif "razorpay_order_id" in body and "order_id" not in body:
                    proposed["order_id"] = proposed["razorpay_order_id"]
                if "payment_id" in body and "razorpay_payment_id" not in body:
                    proposed["razorpay_payment_id"] = proposed["payment_id"]
                elif "razorpay_payment_id" in body and "payment_id" not in body:
                    proposed["payment_id"] = proposed["razorpay_payment_id"]
                if "platform_fee" in body and "platform_fee_amount" not in body:
                    proposed["platform_fee_amount"] = proposed["platform_fee"]
                elif "platform_fee_amount" in body and "platform_fee" not in body:
                    proposed["platform_fee"] = proposed["platform_fee_amount"]
            elif table == "chat_messages":
                if "read_at" in body and body["read_at"] and not body.get("is_read"):
                    proposed["is_read"] = True
                elif body.get("is_read") and not body.get("read_at"):
                    proposed["read_at"] = proposed["updated_at"]

            # Check constraints validation on proposed mutated row
            err = validate_check_constraints(table, proposed)
            if err:
                return err

            if not check_row_update_check(table, proposed, auth_uid, is_admin):
                log.warning(
                    "RLS VIOLATION: User %s unauthorized WITH CHECK update on %s pk=%s: %s",
                    auth_uid,
                    table,
                    pk,
                    body,
                )
                return JSONResponse(
                    status_code=403,
                    content={
                        "code": "42501",
                        "message": f'new row violates row-level security policy for table "{table}"',
                        "details": None,
                        "hint": None,
                    },
                )

        now_patch = get_now_iso()
        for pk in target_pks:
            tbl[pk].update(body)
            tbl[pk]["updated_at"] = now_patch
            if table == "trainer_profiles":
                if "is_verified" in body and "verified" not in body:
                    tbl[pk]["verified"] = tbl[pk]["is_verified"]
                elif "verified" in body and "is_verified" not in body:
                    tbl[pk]["is_verified"] = tbl[pk]["verified"]
            elif table == "payment_transactions":
                if "order_id" in body and "razorpay_order_id" not in body:
                    tbl[pk]["razorpay_order_id"] = tbl[pk]["order_id"]
                elif "razorpay_order_id" in body and "order_id" not in body:
                    tbl[pk]["order_id"] = tbl[pk]["razorpay_order_id"]
                if "payment_id" in body and "razorpay_payment_id" not in body:
                    tbl[pk]["razorpay_payment_id"] = tbl[pk]["payment_id"]
                elif "razorpay_payment_id" in body and "payment_id" not in body:
                    tbl[pk]["payment_id"] = tbl[pk]["razorpay_payment_id"]
                if "platform_fee" in body and "platform_fee_amount" not in body:
                    tbl[pk]["platform_fee_amount"] = tbl[pk]["platform_fee"]
                elif "platform_fee_amount" in body and "platform_fee" not in body:
                    tbl[pk]["platform_fee"] = tbl[pk]["platform_fee_amount"]
            elif table == "chat_messages":
                if "read_at" in body and body["read_at"] and not body.get("is_read"):
                    tbl[pk]["is_read"] = True
                elif body.get("is_read") and not body.get("read_at"):
                    tbl[pk]["read_at"] = now_patch
            updated_rows.append(copy.deepcopy(tbl[pk]))

    if prefer and "return=minimal" in prefer:
        return Response(status_code=204)

    return updated_rows

@app.delete("/rest/v1/{table}")
async def rest_delete(
    table: str,
    request: Request,
    authorization: Optional[str] = Header(None),
    apikey: Optional[str] = Header(None),
    prefer: Optional[str] = Header(None),
) -> Any:
    tbl = db.get_table(table)
    if tbl is None:
        raise HTTPException(status_code=404, detail=f"Table {table} not found")

    is_admin, auth_uid = extract_auth_context(authorization, apikey)
    params = dict(request.query_params)
    deleted_rows = []

    async with db.lock:
        target_pks = []
        for pk, r in tbl.items():
            if not check_row_delete(table, r, auth_uid, is_admin):
                continue

            matches = True
            for k, v in params.items():
                if k in ("select", "order", "limit", "offset"):
                    continue
                if "." in v:
                    op, filter_val = v.split(".", 1)
                    if not compare_values(r.get(k), op, filter_val):
                        matches = False
                        break
                else:
                    row_val = r.get(k)
                    if isinstance(row_val, bool) or v.lower() in ("true", "false"):
                        if str(row_val).lower() != v.lower():
                            matches = False
                            break
                    elif str(row_val if row_val is not None else "") != v:
                        matches = False
                        break
            if matches:
                target_pks.append(pk)

        for pk in target_pks:
            row = tbl.pop(pk)
            deleted_rows.append(row)

            # Cascading deletes
            if table == "workout_sessions":
                child_ex_ids = [
                    eid
                    for eid, ex in list(db.workout_exercises.items())
                    if ex.get("workout_session_id") == pk
                ]
                for eid in child_ex_ids:
                    db.workout_exercises.pop(eid, None)
                    child_set_ids = [
                        sid
                        for sid, st in list(db.workout_sets.items())
                        if st.get("workout_exercise_id") == eid
                    ]
                    for sid in child_set_ids:
                        db.workout_sets.pop(sid, None)

            elif table == "workout_exercises":
                child_set_ids = [
                    sid
                    for sid, st in list(db.workout_sets.items())
                    if st.get("workout_exercise_id") == pk
                ]
                for sid in child_set_ids:
                    db.workout_sets.pop(sid, None)

            elif table == "profiles":
                # Clean up all user workout data
                sess_ids = [sid for sid, s in list(db.workout_sessions.items()) if s.get("user_id") == pk]
                for sid in sess_ids:
                    db.workout_sessions.pop(sid, None)
                rec_ids = [rid for rid, r in list(db.ai_recommendations.items()) if r.get("user_id") == pk]
                for rid in rec_ids:
                    db.ai_recommendations.pop(rid, None)
                # Milestone 1: clean up user marketplace data
                tp_ids = [tid for tid, tp in list(db.trainer_profiles.items()) if tp.get("user_id") == pk]
                for tid in tp_ids:
                    db.trainer_profiles.pop(tid, None)
                ek_ids = [eid for eid, ek in list(db.encryption_keys.items()) if ek.get("user_id") == pk]
                for eid in ek_ids:
                    db.encryption_keys.pop(eid, None)
                conv_ids = [cid for cid, c in list(db.chat_conversations.items()) if c.get("user_id") == pk or c.get("trainer_id") == pk]
                for cid in conv_ids:
                    db.chat_conversations.pop(cid, None)
                    msg_ids = [mid for mid, m in list(db.chat_messages.items()) if m.get("conversation_id") == cid]
                    for mid in msg_ids:
                        db.chat_messages.pop(mid, None)

            elif table == "trainer_profiles":
                conv_ids = [cid for cid, c in list(db.chat_conversations.items()) if c.get("trainer_id") == pk]
                for cid in conv_ids:
                    db.chat_conversations.pop(cid, None)
                    msg_ids = [mid for mid, m in list(db.chat_messages.items()) if m.get("conversation_id") == cid]
                    for mid in msg_ids:
                        db.chat_messages.pop(mid, None)

            elif table == "chat_conversations":
                msg_ids = [mid for mid, m in list(db.chat_messages.items()) if m.get("conversation_id") == pk]
                for mid in msg_ids:
                    db.chat_messages.pop(mid, None)

    if prefer and "return=minimal" in prefer:
        return Response(status_code=204)

    return deleted_rows

# ---------------------------------------------------------------------------
# Utility & Healthcheck Endpoints
# ---------------------------------------------------------------------------

@app.get("/health")
async def health_check() -> Dict[str, Any]:
    return {
        "status": "ok",
        "service": "mock_supabase_server",
        "tables": {
            "auth_users": len(db.auth_users),
            "profiles": len(db.profiles),
            "workout_sessions": len(db.workout_sessions),
            "workout_exercises": len(db.workout_exercises),
            "workout_sets": len(db.workout_sets),
            "ai_recommendations": len(db.ai_recommendations),
            "exercises": len(db.exercises),
            "trainer_profiles": len(db.trainer_profiles),
            "payment_transactions": len(db.payment_transactions),
            "chat_conversations": len(db.chat_conversations),
            "chat_messages": len(db.chat_messages),
            "encryption_keys": len(db.encryption_keys),
        },
    }

@app.post("/mock/reset")
async def mock_reset() -> Dict[str, str]:
    async with db.lock:
        db.reset()
    log.info("Mock database tables reset successfully.")
    return {"status": "ok", "message": "All mock tables reset successfully"}

@app.get("/mock/stats")
async def mock_stats() -> Dict[str, Any]:
    return {
        "auth_users": len(db.auth_users),
        "profiles": len(db.profiles),
        "workout_sessions": len(db.workout_sessions),
        "workout_exercises": len(db.workout_exercises),
        "workout_sets": len(db.workout_sets),
        "ai_recommendations": len(db.ai_recommendations),
        "exercises": len(db.exercises),
        "trainer_profiles": len(db.trainer_profiles),
        "payment_transactions": len(db.payment_transactions),
        "chat_conversations": len(db.chat_conversations),
        "chat_messages": len(db.chat_messages),
        "encryption_keys": len(db.encryption_keys),
    }

# ---------------------------------------------------------------------------
# CLI Entry Point
# ---------------------------------------------------------------------------

def main() -> None:
    parser = argparse.ArgumentParser(description="PulseFit Mock Supabase Server")
    parser.add_argument("--host", default=DEFAULT_HOST, help="Host address to bind (default: 0.0.0.0)")
    parser.add_argument("--port", type=int, default=DEFAULT_PORT, help="Port to listen on (default: 54321)")
    parser.add_argument("--reset", action="store_true", help="Reset all tables on boot")
    parser.add_argument("--log-level", default="info", help="Uvicorn log level (default: info)")
    args = parser.parse_args()

    if args.reset:
        db.reset()

    log.info("Starting PulseFit Mock Supabase Server on http://%s:%d", args.host, args.port)
    uvicorn.run(app, host=args.host, port=args.port, log_level=args.log_level)

if __name__ == "__main__":
    main()
