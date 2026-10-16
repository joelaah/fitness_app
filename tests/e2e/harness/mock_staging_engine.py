r"""
Thread-safe In-Memory Staging Engine simulating Supabase GoTrue Auth & PostgREST.
Implements exact schema and RLS contracts from D:\fitness_app\supabase_schema.sql.
"""

from __future__ import annotations

import copy
import threading
import time
import uuid
from typing import Any, Dict, List, Optional, Tuple


class StagingResponse:
    """Simulated HTTP Response for Staging Engine."""

    def __init__(self, status_code: int, data: Any, headers: Optional[Dict[str, str]] = None):
        self.status_code = status_code
        self._data = data
        self.headers = headers or {}

    def json(self) -> Any:
        return self._data

    @property
    def text(self) -> str:
        if isinstance(self._data, str):
            return self._data
        import json
        return json.dumps(self._data)


class MockStagingEngine:
    """
    In-memory, thread-safe implementation of Supabase PostgREST + GoTrue Auth.
    Enforces Row-Level Security (RLS) matching PostgreSQL policies.
    """

    def __init__(self):
        self._lock = threading.RLock()
        self.users: Dict[str, Dict[str, Any]] = {}  # email -> user_data
        self.users_by_id: Dict[str, Dict[str, Any]] = {}  # user_id -> user_data
        self.tokens: Dict[str, str] = {}  # token -> user_id
        self.refresh_tokens: Dict[str, str] = {}  # refresh_token -> user_id

        # Schema Tables
        self.profiles: Dict[str, Dict[str, Any]] = {}  # id (user_id) -> row
        self.workout_sessions: Dict[str, Dict[str, Any]] = {}  # session_id -> row
        self.workout_exercises: Dict[str, Dict[str, Any]] = {}  # exercise_id -> row
        self.workout_sets: Dict[str, Dict[str, Any]] = {}  # set_id -> row
        self.ai_recommendations: Dict[str, Dict[str, Any]] = {}  # rec_id -> row

    # -------------------------------------------------------------------------
    # Authentication & Identity (GoTrue Simulation)
    # -------------------------------------------------------------------------

    def signup(self, email: str, password: str, metadata: Optional[Dict[str, Any]] = None) -> StagingResponse:
        with self._lock:
            if not email or "@" not in email:
                return StagingResponse(400, {"error": "Invalid email format"})
            if len(password) < 6:
                return StagingResponse(400, {"error": "Password must be at least 6 characters"})
            if email in self.users:
                return StagingResponse(400, {"error": "User already registered"})

            user_id = str(uuid.uuid4())
            token = f"jwt-{user_id}-{int(time.time())}"
            refresh_token = f"ref-{user_id}-{int(time.time())}"

            user_data = {
                "id": user_id,
                "email": email,
                "password": password,
                "created_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                "user_metadata": metadata or {},
            }
            self.users[email] = user_data
            self.users_by_id[user_id] = user_data
            self.tokens[token] = user_id
            self.refresh_tokens[refresh_token] = user_id

            # Initialize profile row
            self.profiles[user_id] = {
                "id": user_id,
                "display_name": (metadata or {}).get("display_name", email.split("@")[0]),
                "experience_level": (metadata or {}).get("experience_level", "intermediate"),
                "preferred_training_goal": (metadata or {}).get("preferred_training_goal", "hypertrophy"),
                "created_at": user_data["created_at"],
            }

            return StagingResponse(
                200,
                {
                    "access_token": token,
                    "refresh_token": refresh_token,
                    "token_type": "bearer",
                    "user": {"id": user_id, "email": email},
                },
            )

    def login(self, email: str, password: str) -> StagingResponse:
        with self._lock:
            user = self.users.get(email)
            if not user or user["password"] != password:
                return StagingResponse(400, {"error": "Invalid login credentials"})

            user_id = user["id"]
            token = f"jwt-{user_id}-{int(time.time())}"
            refresh_token = f"ref-{user_id}-{int(time.time())}"
            self.tokens[token] = user_id
            self.refresh_tokens[refresh_token] = user_id

            return StagingResponse(
                200,
                {
                    "access_token": token,
                    "refresh_token": refresh_token,
                    "token_type": "bearer",
                    "user": {"id": user_id, "email": email},
                },
            )

    def refresh_token(self, refresh_tok: str) -> StagingResponse:
        with self._lock:
            user_id = self.refresh_tokens.get(refresh_tok)
            if not user_id or user_id not in self.users_by_id:
                return StagingResponse(401, {"error": "Invalid or expired refresh token"})

            new_token = f"jwt-{user_id}-{int(time.time())}"
            new_refresh = f"ref-{user_id}-{int(time.time())}"
            self.tokens[new_token] = user_id
            self.refresh_tokens[new_refresh] = user_id

            return StagingResponse(
                200,
                {
                    "access_token": new_token,
                    "refresh_token": new_refresh,
                    "token_type": "bearer",
                    "user": {"id": user_id, "email": self.users_by_id[user_id]["email"]},
                },
            )

    def resolve_user_id(self, auth_header: Optional[str]) -> Optional[str]:
        """Resolves authenticated user_id from Bearer header."""
        if not auth_header:
            return None
        tok = auth_header.replace("Bearer ", "").strip()
        if not tok:
            return None

        # Dev token bypass matching FastAPI RAG microservice
        if tok.startswith("dev-user-"):
            uid = tok.replace("dev-user-", "").strip()
            return uid if uid else "00000000-0000-0000-0000-000000000001"
        if tok == "test-token":
            return "00000000-0000-0000-0000-000000000001"

        return self.tokens.get(tok)

    # -------------------------------------------------------------------------
    # PostgREST Data API & Row-Level Security (RLS)
    # -------------------------------------------------------------------------

    def query(
        self,
        table: str,
        auth_header: Optional[str],
        params: Optional[Dict[str, str]] = None,
    ) -> StagingResponse:
        """PostgREST GET /rest/v1/{table} with RLS enforcement."""
        with self._lock:
            user_id = self.resolve_user_id(auth_header)
            if not user_id:
                return StagingResponse(401, {"error": "Missing or invalid authorization token"})

            params = params or {}
            rows = self._get_table_data(table)
            if rows is None:
                return StagingResponse(404, {"error": f"Table '{table}' does not exist"})

            # Enforce Row-Level Security (auth.uid() = owner)
            filtered: List[Dict[str, Any]] = []
            for row in rows.values():
                if self._can_user_read(table, row, user_id):
                    filtered.append(copy.deepcopy(row))

            # Apply parameter filters
            for k, v in params.items():
                if k.endswith("=eq"):
                    field = k[:-3]
                    filtered = [r for r in filtered if str(r.get(field)) == v]
                elif "=" in k:
                    # Alternative key format
                    pass
                elif k in ("user_id", "workout_session_id", "workout_exercise_id", "id"):
                    val = v.replace("eq.", "") if v.startswith("eq.") else v
                    filtered = [r for r in filtered if str(r.get(k)) == val]

            # Apply ordering
            order = params.get("order")
            if order:
                desc = order.endswith(".desc")
                field = order.replace(".desc", "").replace(".asc", "")
                filtered.sort(key=lambda x: str(x.get(field, "")), reverse=desc)

            # Apply limit
            limit = params.get("limit")
            if limit:
                try:
                    lim = int(limit)
                    filtered = filtered[:lim]
                except ValueError:
                    pass

            return StagingResponse(200, filtered)

    def insert(
        self,
        table: str,
        auth_header: Optional[str],
        payload: Any,
        prefer: Optional[str] = None,
    ) -> StagingResponse:
        """PostgREST POST /rest/v1/{table} with RLS INSERT check."""
        with self._lock:
            user_id = self.resolve_user_id(auth_header)
            if not user_id:
                return StagingResponse(401, {"error": "Missing or invalid authorization token"})

            table_store = self._get_table_data(table)
            if table_store is None:
                return StagingResponse(404, {"error": f"Table '{table}' does not exist"})

            records = payload if isinstance(payload, list) else [payload]
            inserted = []

            for rec in records:
                row = copy.deepcopy(rec)
                if "id" not in row or not row["id"]:
                    row["id"] = str(uuid.uuid4())
                if "created_at" not in row:
                    row["created_at"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())

                # Validate RLS INSERT policy
                if not self._can_user_insert(table, row, user_id):
                    return StagingResponse(403, {"error": "Row-level security violation on insert"})

                # Handle upsert merge-duplicates
                row_id = str(row["id"])
                if row_id in table_store and prefer and "resolution=merge-duplicates" in prefer:
                    table_store[row_id].update(row)
                else:
                    table_store[row_id] = row
                inserted.append(row)

            return StagingResponse(201, inserted)

    def update(
        self,
        table: str,
        auth_header: Optional[str],
        record_id: str,
        updates: Dict[str, Any],
    ) -> StagingResponse:
        """PostgREST PATCH /rest/v1/{table}?id=eq.{id} with RLS UPDATE check."""
        with self._lock:
            user_id = self.resolve_user_id(auth_header)
            if not user_id:
                return StagingResponse(401, {"error": "Missing or invalid authorization token"})

            table_store = self._get_table_data(table)
            if table_store is None:
                return StagingResponse(404, {"error": f"Table '{table}' does not exist"})

            row = table_store.get(record_id)
            if not row:
                return StagingResponse(404, {"error": "Record not found"})

            if not self._can_user_update(table, row, user_id):
                return StagingResponse(403, {"error": "Row-level security violation on update"})

            row.update(updates)
            return StagingResponse(200, [copy.deepcopy(row)])

    def delete(
        self,
        table: str,
        auth_header: Optional[str],
        record_id: str,
    ) -> StagingResponse:
        """PostgREST DELETE /rest/v1/{table}?id=eq.{id} with RLS & CASCADE."""
        with self._lock:
            user_id = self.resolve_user_id(auth_header)
            if not user_id:
                return StagingResponse(401, {"error": "Missing or invalid authorization token"})

            table_store = self._get_table_data(table)
            if table_store is None:
                return StagingResponse(404, {"error": f"Table '{table}' does not exist"})

            row = table_store.get(record_id)
            if not row:
                return StagingResponse(404, {"error": "Record not found"})

            if not self._can_user_delete(table, row, user_id):
                return StagingResponse(403, {"error": "Row-level security violation on delete"})

            # Cascade delete when deleting workout_session
            if table == "workout_sessions":
                self._cascade_delete_session(record_id)

            del table_store[record_id]
            return StagingResponse(204, None)

    # -------------------------------------------------------------------------
    # Internal RLS Policies & Cascades
    # -------------------------------------------------------------------------

    def _get_table_data(self, table: str) -> Optional[Dict[str, Dict[str, Any]]]:
        mapping = {
            "profiles": self.profiles,
            "workout_sessions": self.workout_sessions,
            "workout_exercises": self.workout_exercises,
            "workout_sets": self.workout_sets,
            "ai_recommendations": self.ai_recommendations,
        }
        return mapping.get(table)

    def _can_user_read(self, table: str, row: Dict[str, Any], user_id: str) -> bool:
        if table == "profiles":
            return str(row.get("id")) == str(user_id)
        if table in ("workout_sessions", "ai_recommendations"):
            return str(row.get("user_id")) == str(user_id)
        if table == "workout_exercises":
            session_id = row.get("workout_session_id")
            session = self.workout_sessions.get(str(session_id))
            return session is not None and str(session.get("user_id")) == str(user_id)
        if table == "workout_sets":
            ex_id = row.get("workout_exercise_id")
            exercise = self.workout_exercises.get(str(ex_id))
            if not exercise:
                return False
            session_id = exercise.get("workout_session_id")
            session = self.workout_sessions.get(str(session_id))
            return session is not None and str(session.get("user_id")) == str(user_id)
        return False

    def _can_user_insert(self, table: str, row: Dict[str, Any], user_id: str) -> bool:
        if table == "profiles":
            return str(row.get("id")) == str(user_id)
        if table in ("workout_sessions", "ai_recommendations"):
            return str(row.get("user_id")) == str(user_id)
        if table == "workout_exercises":
            session_id = row.get("workout_session_id")
            session = self.workout_sessions.get(str(session_id))
            return session is not None and str(session.get("user_id")) == str(user_id)
        if table == "workout_sets":
            ex_id = row.get("workout_exercise_id")
            exercise = self.workout_exercises.get(str(ex_id))
            if not exercise:
                return False
            session_id = exercise.get("workout_session_id")
            session = self.workout_sessions.get(str(session_id))
            return session is not None and str(session.get("user_id")) == str(user_id)
        return False

    def _can_user_update(self, table: str, row: Dict[str, Any], user_id: str) -> bool:
        return self._can_user_read(table, row, user_id)

    def _can_user_delete(self, table: str, row: Dict[str, Any], user_id: str) -> bool:
        return self._can_user_read(table, row, user_id)

    def _cascade_delete_session(self, session_id: str) -> None:
        """Cascades session deletion to exercises and their sets."""
        ex_to_delete = [
            ex_id for ex_id, ex in self.workout_exercises.items()
            if str(ex.get("workout_session_id")) == str(session_id)
        ]
        for ex_id in ex_to_delete:
            sets_to_delete = [
                s_id for s_id, s in self.workout_sets.items()
                if str(s.get("workout_exercise_id")) == str(ex_id)
            ]
            for s_id in sets_to_delete:
                self.workout_sets.pop(s_id, None)
            self.workout_exercises.pop(ex_id, None)
