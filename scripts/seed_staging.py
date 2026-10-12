#!/usr/bin/env python3
r"""
PulseFit AI - Database Seed Pipeline
====================================
Deterministic, realistic database seeding tool for staging & load testing:
1. Loads 1,324 exercises from assets/data/exercises.json.
2. Generates realistic user personas (Powerlifter, Hypertrophy, Beginner, Endurance, Recomp).
3. Produces multi-week progressive overload workout histories matching D:\Rag\api.py.
4. Supports local mock server (http://127.0.0.1:54321) and remote Supabase Cloud.
5. Saves credential & token roster to staging/seeded_users.json for Locust & integration tests.
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone
import json
import logging
import math
import os
from pathlib import Path
import random
import sys
import time
from typing import Any, Dict, List, Optional, Tuple
import uuid

import jwt
import requests

# ---------------------------------------------------------------------------
# Constants & Defaults
# ---------------------------------------------------------------------------

DEFAULT_LOCAL_TARGET = "http://127.0.0.1:54321"
DEFAULT_SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.mock_service_role"
DEFAULT_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.mock_anon"
DEFAULT_EXERCISES_PATH = Path("assets/data/exercises.json")
DEFAULT_OUTPUT_USERS = Path("staging/seeded_users.json")
JWT_SECRET = os.getenv("JWT_SECRET", "super-secret-jwt-token-with-at-least-32-characters-long")

def create_seed_jwt(user_id: str, email: str, secret: str = JWT_SECRET) -> str:
    now_int = int(time.time())
    payload = {
        "iss": "supabase-mock",
        "sub": user_id,
        "aud": "authenticated",
        "role": "authenticated",
        "email": email,
        "exp": now_int + 86400 * 30,  # 30-day token for test suites
        "iat": now_int,
    }
    return jwt.encode(payload, secret, algorithm="HS256")

UUID_NAMESPACE = uuid.UUID("a3b8c2d1-4e5f-6a7b-8c9d-0e1f2a3b4c5d")

STANDARD_MUSCLE_GROUPS = ["Chest", "Back", "Legs", "Shoulders", "Arms", "Core"]

BODY_PART_TO_STANDARD_GROUP = {
    "chest": "Chest",
    "back": "Back",
    "upper legs": "Legs",
    "lower legs": "Legs",
    "shoulders": "Shoulders",
    "upper arms": "Arms",
    "lower arms": "Arms",
    "waist": "Core",
    "cardio": "Cardio",
    "neck": "Shoulders",
}

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
log = logging.getLogger("seed_staging")

# ---------------------------------------------------------------------------
# Persona Configurations
# ---------------------------------------------------------------------------

PERSONA_ARCHETYPES = [
    {
        "name": "Powerlifter",
        "training_goal": "strength",
        "experience_level": "advanced",
        "weight_range": (85.0, 115.0),
        "height_range": (175, 192),
        "split": "Upper/Lower",
        "rep_range": (3, 6),
        "intensity": 0.85,
        "volume_mult": 1.25,
    },
    {
        "name": "Hypertrophy",
        "training_goal": "hypertrophy",
        "experience_level": "intermediate",
        "weight_range": (70.0, 90.0),
        "height_range": (170, 188),
        "split": "PPL",
        "rep_range": (8, 12),
        "intensity": 0.75,
        "volume_mult": 1.0,
    },
    {
        "name": "Fitness Beginner",
        "training_goal": "general_fitness",
        "experience_level": "beginner",
        "weight_range": (60.0, 85.0),
        "height_range": (160, 185),
        "split": "Full Body",
        "rep_range": (10, 15),
        "intensity": 0.65,
        "volume_mult": 0.75,
    },
    {
        "name": "Endurance Athlete",
        "training_goal": "endurance",
        "experience_level": "intermediate",
        "weight_range": (58.0, 78.0),
        "height_range": (165, 185),
        "split": "Upper/Lower",
        "rep_range": (12, 20),
        "intensity": 0.60,
        "volume_mult": 0.70,
    },
    {
        "name": "Recomp / Fat Loss",
        "training_goal": "fat_loss",
        "experience_level": "intermediate",
        "weight_range": (68.0, 95.0),
        "height_range": (165, 186),
        "split": "PPL",
        "rep_range": (10, 15),
        "intensity": 0.70,
        "volume_mult": 0.85,
    },
]

FIRST_NAMES = [
    "Marcus", "Elena", "Jordan", "Amina", "Chen", "Sophia", "Mateo", "Priya",
    "Lucas", "Zoe", "Dmitri", "Nia", "Gabriel", "Aisha", "Liam", "Hana",
    "Julian", "Chloe", "Tariq", "Fatima", "Devon", "Camila", "Kai", "Sora",
    "Viktor", "Isabella", "Kenji", "Amara", "Oscar", "Maya"
]

LAST_NAMES = [
    "Vance", "Rostova", "Lee", "Diallo", "Wei", "Rossi", "Silva", "Patel",
    "Dubois", "Kim", "Morozov", "Mensah", "Santos", "Khan", "O'Connor", "Sato",
    "Novak", "Moreau", "Haddad", "Al-Mansoor", "Washington", "Flores", "Tanaka",
    "Lindqvist", "Kovacs", "Larsson", "Yamamoto", "Okafor", "Gomez", "Berg"
]

# ---------------------------------------------------------------------------
# Exercise Catalog Model
# ---------------------------------------------------------------------------

class ExerciseCatalog:
    """Loads and categorizes exercises from assets/data/exercises.json."""

    def __init__(self, catalog_path: Path):
        self.catalog_path = catalog_path
        self.exercises: List[Dict[str, Any]] = []
        self.by_group: Dict[str, List[Dict[str, Any]]] = {g: [] for g in STANDARD_MUSCLE_GROUPS}
        self.by_group["Cardio"] = []
        self.anchor_exercises: Dict[str, List[Dict[str, Any]]] = {g: [] for g in STANDARD_MUSCLE_GROUPS}

    def load(self) -> None:
        if not self.catalog_path.exists():
            log.warning("Exercises catalog not found at %s. Using synthetic catalog.", self.catalog_path)
            self._create_fallback_catalog()
            return

        with open(self.catalog_path, "r", encoding="utf-8") as f:
            raw_data = json.load(f)

        log.info("Loaded %d exercises from %s", len(raw_data), self.catalog_path)
        self.exercises = raw_data

        for ex in self.exercises:
            body_part = str(ex.get("body_part", "")).lower()
            std_group = BODY_PART_TO_STANDARD_GROUP.get(body_part, "Core")
            ex["standard_muscle_group"] = std_group

            if std_group in self.by_group:
                self.by_group[std_group].append(ex)

            # Detect compound / anchor lifts
            name = str(ex.get("name", "")).lower()
            if any(compound in name for compound in [
                "bench press", "squat", "deadlift", "overhead press",
                "bent over row", "pull-up", "chin-up", "leg press"
            ]):
                if std_group in self.anchor_exercises:
                    self.anchor_exercises[std_group].append(ex)

        for g in STANDARD_MUSCLE_GROUPS:
            if not self.anchor_exercises[g] and self.by_group[g]:
                self.anchor_exercises[g] = self.by_group[g][:5]

    def _create_fallback_catalog(self) -> None:
        """Fallback in case catalog file is moved or inaccessible."""
        fallback = [
            {"id": "0025", "name": "barbell bench press", "body_part": "chest", "standard_muscle_group": "Chest"},
            {"id": "0314", "name": "dumbbell incline bench press", "body_part": "chest", "standard_muscle_group": "Chest"},
            {"id": "0043", "name": "barbell full squat", "body_part": "upper legs", "standard_muscle_group": "Legs"},
            {"id": "0032", "name": "barbell deadlift", "body_part": "back", "standard_muscle_group": "Back"},
            {"id": "0091", "name": "barbell overhead press", "body_part": "shoulders", "standard_muscle_group": "Shoulders"},
            {"id": "0027", "name": "barbell bent over row", "body_part": "back", "standard_muscle_group": "Back"},
            {"id": "0652", "name": "pull-up", "body_part": "back", "standard_muscle_group": "Back"},
            {"id": "0031", "name": "barbell curl", "body_part": "upper arms", "standard_muscle_group": "Arms"},
            {"id": "0201", "name": "cable pushdown", "body_part": "upper arms", "standard_muscle_group": "Arms"},
            {"id": "0001", "name": "3/4 sit-up", "body_part": "waist", "standard_muscle_group": "Core"},
        ]
        self.exercises = fallback
        for ex in fallback:
            g = ex["standard_muscle_group"]
            self.by_group[g].append(ex)
            self.anchor_exercises[g].append(ex)

    def get_exercises_for_split(self, split_day: str, count: int = 5) -> List[Dict[str, Any]]:
        """Selects a balanced list of exercises for a routine split."""
        selected: List[Dict[str, Any]] = []

        if split_day == "Push":
            groups = ["Chest", "Shoulders", "Arms"]
        elif split_day == "Pull":
            groups = ["Back", "Arms", "Core"]
        elif split_day == "Legs":
            groups = ["Legs", "Legs", "Core"]
        elif split_day == "Upper":
            groups = ["Chest", "Back", "Shoulders", "Arms"]
        elif split_day == "Lower":
            groups = ["Legs", "Legs", "Core"]
        else: # Full Body
            groups = ["Chest", "Legs", "Back", "Shoulders", "Arms"]

        for g in groups:
            pool = self.anchor_exercises.get(g) or self.by_group.get(g)
            if pool:
                chosen = random.choice(pool)
                if chosen not in selected:
                    selected.append(chosen)

        # Fill remaining slots up to count
        while len(selected) < count:
            g = random.choice(STANDARD_MUSCLE_GROUPS)
            pool = self.by_group.get(g)
            if pool:
                chosen = random.choice(pool)
                if chosen not in selected:
                    selected.append(chosen)
                else:
                    break
            else:
                break

        return selected[:count]

# ---------------------------------------------------------------------------
# Synthetic User Generator
# ---------------------------------------------------------------------------

@dataclass
class SyntheticUser:
    id: str
    email: str
    password: str
    display_name: str
    experience_level: str
    preferred_training_goal: str
    weight_kg: float
    height_cm: int
    persona_name: str
    split: str
    dev_token: str
    jwt_token: str
    created_at: str

def generate_users(count: int, seed: int = 42) -> List[SyntheticUser]:
    rng = random.Random(seed)
    users: List[SyntheticUser] = []
    now = datetime.now(timezone.utc)

    for i in range(count):
        user_uuid = str(uuid.uuid5(UUID_NAMESPACE, f"user-{i:04d}"))
        persona = rng.choice(PERSONA_ARCHETYPES)
        first = rng.choice(FIRST_NAMES)
        last = rng.choice(LAST_NAMES)
        display_name = f"{first} {last}"

        short_id = user_uuid[:8]
        email = f"user_{i+1:03d}_{short_id}@staging.pulsefit.io"
        password = "StagingPassword123!"

        weight = round(rng.uniform(*persona["weight_range"]), 1)
        height = rng.randint(*persona["height_range"])

        # Created 90 to 120 days ago
        created_dt = now - timedelta(days=rng.randint(90, 120))
        created_iso = created_dt.isoformat().replace("+00:00", "Z")

        dev_token = f"dev-user-{user_uuid}"
        jwt_token = create_seed_jwt(user_uuid, email)

        users.append(SyntheticUser(
            id=user_uuid,
            email=email,
            password=password,
            display_name=display_name,
            experience_level=persona["experience_level"],
            preferred_training_goal=persona["training_goal"],
            weight_kg=weight,
            height_cm=height,
            persona_name=persona["name"],
            split=persona["split"],
            dev_token=dev_token,
            jwt_token=jwt_token,
            created_at=created_iso,
        ))

    return users

# ---------------------------------------------------------------------------
# Workout History Generator
# ---------------------------------------------------------------------------

def generate_user_workouts(
    user: SyntheticUser,
    catalog: ExerciseCatalog,
    workout_count: int,
    days_history: int,
    rng: random.Random,
) -> Tuple[List[Dict[str, Any]], List[Dict[str, Any]], List[Dict[str, Any]], List[Dict[str, Any]]]:
    """
    Generates historical workout sessions, exercises, sets, and recommendations
    modeling biological progressive overload and fatigue.
    """
    sessions: List[Dict[str, Any]] = []
    exercises_list: List[Dict[str, Any]] = []
    sets_list: List[Dict[str, Any]] = []
    recommendations: List[Dict[str, Any]] = []

    now = datetime.now(timezone.utc)
    # Evenly space sessions backwards across history
    step_days = max(1, days_history // max(1, workout_count))

    # Base strength scale based on user bodyweight
    bw = user.weight_kg
    base_bench = bw * 0.8
    base_squat = bw * 1.1
    base_deadlift = bw * 1.3
    base_accessory = bw * 0.35

    for k in range(workout_count):
        session_id = str(uuid.uuid4())
        session_age_days = (workout_count - 1 - k) * step_days + rng.randint(0, 1)
        started_dt = now - timedelta(days=session_age_days, hours=rng.choice([7, 12, 18]), minutes=rng.randint(0, 45))
        duration_sec = rng.randint(2400, 4800)  # 40 - 80 min
        completed_dt = started_dt + timedelta(seconds=duration_sec)

        # Progression multiplier: +0.5% per session with deload every 4th session
        progression_mult = 1.0 + (0.005 * k)
        is_deload = (k > 0 and k % 4 == 0)
        if is_deload:
            progression_mult *= 0.85

        # Split selection
        if user.split == "PPL":
            split_cycle = ["Push", "Pull", "Legs"]
            routine_day = split_cycle[k % 3]
            routine_name = f"{routine_day} Day (Hypertrophy)"
        elif user.split == "Upper/Lower":
            split_cycle = ["Upper", "Lower"]
            routine_day = split_cycle[k % 2]
            routine_name = f"{routine_day} Power"
        else:
            routine_day = "Full Body"
            routine_name = "Full Body Conditioning"

        routine_id = f"routine_{routine_day.lower()}_{k % 3}"
        day_id = f"day_{k % 7}"

        chosen_exercises = catalog.get_exercises_for_split(routine_day, count=rng.randint(4, 6))

        session_total_volume = 0.0
        session_total_reps = 0

        for order_idx, ex_meta in enumerate(chosen_exercises):
            exercise_row_id = str(uuid.uuid4())
            ex_name = ex_meta.get("name", "Exercise")
            ex_group = ex_meta.get("standard_muscle_group", "Core")

            exercises_list.append({
                "id": exercise_row_id,
                "workout_session_id": session_id,
                "exercise_id": str(ex_meta.get("id", f"ex_{order_idx}")),
                "exercise_name": ex_name,
                "order_index": order_idx,
                "primary_muscle_group": ex_group,
                "secondary_muscle_groups": ex_meta.get("secondary_muscles", []),
                "is_skipped": False,
                "created_at": started_dt.isoformat().replace("+00:00", "Z"),
            })

            # Base weight determination for this exercise
            low_name = ex_name.lower()
            if "bench" in low_name:
                w_base = base_bench
            elif "squat" in low_name or "leg press" in low_name:
                w_base = base_squat
            elif "deadlift" in low_name:
                w_base = base_deadlift
            else:
                w_base = base_accessory

            weight = round(w_base * progression_mult, 1)

            num_sets = rng.randint(3, 4)
            for set_num in range(1, num_sets + 1):
                set_id = str(uuid.uuid4())
                target_reps = rng.randint(8, 12)
                # Fatigue drop-off: last set might lose 1 rep
                if set_num == num_sets and rng.random() < 0.3:
                    comp_reps = max(1, target_reps - 1)
                else:
                    comp_reps = target_reps

                is_comp = True
                set_vol = float(comp_reps) * float(weight)

                session_total_volume += set_vol
                session_total_reps += comp_reps

                sets_list.append({
                    "id": set_id,
                    "workout_exercise_id": exercise_row_id,
                    "set_number": set_num,
                    "target_reps": target_reps,
                    "completed_reps": comp_reps,
                    "target_weight": weight,
                    "completed_weight": weight,
                    "duration_seconds": rng.randint(30, 60),
                    "distance": 0.0,
                    "is_completed": is_comp,
                    "created_at": (started_dt + timedelta(minutes=order_idx * 10 + set_num * 2)).isoformat().replace("+00:00", "Z"),
                })

        sessions.append({
            "id": session_id,
            "user_id": user.id,
            "routine_id": routine_id,
            "routine_name": routine_name,
            "day_id": day_id,
            "started_at": started_dt.isoformat().replace("+00:00", "Z"),
            "completed_at": completed_dt.isoformat().replace("+00:00", "Z"),
            "duration_seconds": duration_sec,
            "total_volume": round(session_total_volume, 1),
            "total_reps": session_total_reps,
            "notes": f"Seeded session {k+1}/{workout_count} - {user.persona_name}",
            "created_at": started_dt.isoformat().replace("+00:00", "Z"),
        })

    # Pre-seed 1 AI recommendation record matching D:\Rag\api.py structure
    if sessions:
        rec_id = str(uuid.uuid4())
        rec_dt = now - timedelta(days=1)
        rec_json = {
            "summary": f"Completed {len(sessions)} sessions over {days_history} days. Consistent volume progression observed.",
            "recommendations": [
                {
                    "title": "Progressive Overload Sustained",
                    "category": "progression",
                    "description": "Maintain progressive weight increments on primary compound lifts.",
                    "priority": "high",
                },
                {
                    "title": "Balanced Recovery",
                    "category": "volume",
                    "description": "Ensure 48h recovery between high volume sessions.",
                    "priority": "normal",
                },
            ],
            "recovery": [
                {
                    "title": "Hydration and Active Mobility",
                    "description": "Perform dynamic stretching between workout days.",
                }
            ],
            "next_workout": {
                "title": f"Upcoming: {user.split} Focus",
                "reason": "Aligns with progressive cycle.",
                "exercises": [
                    {"name": "Barbell Squats", "reason": "Foundation strength."},
                    {"name": "Romanian Deadlifts", "reason": "Posterior chain balance."},
                ],
            },
        }

        recommendations.append({
            "id": rec_id,
            "user_id": user.id,
            "generated_at": rec_dt.isoformat().replace("+00:00", "Z"),
            "analysis_start_date": (now - timedelta(days=days_history)).isoformat().replace("+00:00", "Z"),
            "analysis_end_date": now.isoformat().replace("+00:00", "Z"),
            "sessions_analyzed": len(sessions),
            "recommendation_json": rec_json,
            "summary": rec_json["summary"],
            "model_provider": "gemini-3.6-flash + cohere-rerank",
            "prompt_version": "v1",
            "created_at": rec_dt.isoformat().replace("+00:00", "Z"),
        })

    return sessions, exercises_list, sets_list, recommendations

# ---------------------------------------------------------------------------
# Supabase PostgREST & Auth Client Wrapper
# ---------------------------------------------------------------------------

class SupabaseClientWrapper:
    """Handles batched HTTP PostgREST and Auth operations."""

    def __init__(self, target_url: str, service_key: str):
        self.target_url = target_url.rstrip("/")
        self.service_key = service_key
        self.session = requests.Session()
        self.session.headers.update({
            "apikey": self.service_key,
            "Authorization": f"Bearer {self.service_key}",
            "Content-Type": "application/json",
        })

    def check_health(self) -> bool:
        try:
            r = self.session.get(f"{self.target_url}/health", timeout=5)
            return r.status_code == 200
        except Exception:
            return False

    def reset_database(self) -> None:
        log.info("Resetting staging database...")
        # Try local mock reset endpoint
        try:
            r = self.session.post(f"{self.target_url}/mock/reset", timeout=5)
            if r.status_code == 200:
                log.info("Local mock database reset via /mock/reset endpoint.")
                return
        except Exception:
            pass

        # Otherwise delete from PostgREST tables in reverse dependency order
        for table in ["ai_recommendations", "workout_sets", "workout_exercises", "workout_sessions", "profiles"]:
            try:
                # Delete all rows where id is not null
                self.session.delete(f"{self.target_url}/rest/v1/{table}?id=neq.00000000-0000-0000-0000-000000000000", timeout=10)
            except Exception as e:
                log.warning("Notice on purging %s: %s", table, e)

    def register_auth_users(self, users: List[SyntheticUser]) -> int:
        """
        Registers synthetic users in GoTrue auth.users via POST /auth/v1/admin/users.
        Ensures seeded profiles and workout records match GoTrue login identities.
        """
        if not users:
            return 0

        url = f"{self.target_url}/auth/v1/admin/users"
        success_count = 0
        log.info("Registering %d synthetic users in GoTrue Auth via %s...", len(users), url)

        for u in users:
            payload = {
                "id": u.id,
                "email": u.email,
                "password": u.password,
                "email_confirm": True,
                "user_metadata": {
                    "display_name": u.display_name,
                    "experience_level": u.experience_level,
                    "preferred_training_goal": u.preferred_training_goal,
                },
            }
            try:
                res = self.session.post(url, json=payload, timeout=10)
                if res.status_code in (200, 201):
                    success_count += 1
                elif res.status_code in (400, 409, 422):
                    # User already registered (idempotent seed run without reset)
                    log.debug("User %s already exists in GoTrue (HTTP %d)", u.email, res.status_code)
                    success_count += 1
                else:
                    log.warning(
                        "Unexpected response registering user %s: HTTP %d: %s",
                        u.email,
                        res.status_code,
                        res.text[:150],
                    )
            except Exception as e:
                log.warning("Network error registering user %s: %s", u.email, e)

        log.info("Successfully synchronized %d/%d users with GoTrue Auth.", success_count, len(users))
        return success_count

    def batch_insert(self, table: str, records: List[Dict[str, Any]], batch_size: int = 100) -> None:
        if not records:
            return

        headers = {
            "Prefer": "resolution=merge-duplicates,return=minimal",
        }

        total = len(records)
        num_batches = math.ceil(total / batch_size)
        log.info("Inserting %d records into '%s' in %d batches...", total, table, num_batches)

        for b_idx in range(num_batches):
            chunk = records[b_idx * batch_size : (b_idx + 1) * batch_size]
            url = f"{self.target_url}/rest/v1/{table}"

            for attempt in range(3):
                try:
                    res = self.session.post(url, json=chunk, headers=headers, timeout=30)
                    if res.status_code in (200, 201, 204):
                        break
                    elif res.status_code == 404 and table == "exercises":
                        # Optional catalog table
                        log.info("Table 'exercises' does not exist in schema. Skipping catalog sync.")
                        return
                    else:
                        log.warning(
                            "Batch %d/%d for '%s' returned HTTP %d: %s",
                            b_idx + 1,
                            num_batches,
                            table,
                            res.status_code,
                            res.text[:200],
                        )
                except Exception as e:
                    if attempt == 2:
                        raise
                    time.sleep(1.0)

# ---------------------------------------------------------------------------
# CLI & Execution Orchestrator
# ---------------------------------------------------------------------------

def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="PulseFit Staging Database Seed Pipeline")
    parser.add_argument("--users", type=int, default=50, help="Number of synthetic users to seed (default: 50)")
    parser.add_argument("--workouts-per-user", type=int, default=10, help="Historical workouts per user (default: 10)")
    parser.add_argument("--days-history", type=int, default=60, help="Days of history to span (default: 60)")
    parser.add_argument("--target", default="local", help="Target URL or 'local' (default: 'local' -> http://127.0.0.1:54321)")
    parser.add_argument("--service-key", default=os.getenv("SUPABASE_SERVICE_ROLE_KEY", DEFAULT_SERVICE_KEY))
    parser.add_argument("--anon-key", default=os.getenv("SUPABASE_ANON_KEY", DEFAULT_ANON_KEY))
    parser.add_argument("--reset", action="store_true", help="Wipe staging database before inserting")
    parser.add_argument("--batch-size", type=int, default=100, help="PostgREST batch size (default: 100)")
    parser.add_argument("--output-users-file", default=str(DEFAULT_OUTPUT_USERS), help="Output JSON path for users")
    parser.add_argument("--seed", type=int, default=42, help="Random seed for deterministic data (default: 42)")
    parser.add_argument("--dry-run", action="store_true", help="Simulate data generation without HTTP writes")
    parser.add_argument("--skip-recommendations", action="store_true", help="Skip seeding ai_recommendations")
    return parser.parse_args()

def main() -> None:
    args = parse_args()

    target_url = DEFAULT_LOCAL_TARGET if args.target == "local" else args.target

    log.info("=============================================================")
    log.info("PulseFit AI Staging Seed Pipeline")
    log.info("Target: %s", target_url)
    log.info("Users: %d | Workouts/User: %d | Days History: %d", args.users, args.workouts_per_user, args.days_history)
    log.info("Random Seed: %d", args.seed)
    log.info("=============================================================")

    # 1. Load Exercise Catalog
    catalog = ExerciseCatalog(DEFAULT_EXERCISES_PATH)
    catalog.load()

    # 2. Generate Synthetic Users
    users = generate_users(args.users, seed=args.seed)
    log.info("Generated %d synthetic user profiles.", len(users))

    # 3. Generate Workout Histories
    all_sessions: List[Dict[str, Any]] = []
    all_exercises: List[Dict[str, Any]] = []
    all_sets: List[Dict[str, Any]] = []
    all_recommendations: List[Dict[str, Any]] = []

    rng = random.Random(args.seed + 1)
    for u in users:
        u_sess, u_exs, u_sets, u_recs = generate_user_workouts(
            user=u,
            catalog=catalog,
            workout_count=args.workouts_per_user,
            days_history=args.days_history,
            rng=rng,
        )
        all_sessions.extend(u_sess)
        all_exercises.extend(u_exs)
        all_sets.extend(u_sets)
        if not args.skip_recommendations:
            all_recommendations.extend(u_recs)

    total_volume_sum = sum(s["total_volume"] for s in all_sessions)
    total_reps_sum = sum(s["total_reps"] for s in all_sessions)
    log.info("Generated Workouts Summary:")
    log.info("  Sessions:     %d", len(all_sessions))
    log.info("  Exercises:    %d", len(all_exercises))
    log.info("  Sets:         %d", len(all_sets))
    log.info("  Recommendations: %d", len(all_recommendations))
    log.info("  Total Volume: %s kg", f"{total_volume_sum:,.1f}")
    log.info("  Total Reps:   %s", f"{total_reps_sum:,}")

    # 4. Save User Credentials & Tokens to Output File
    output_path = Path(args.output_users_file)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    users_export = [
        {
            "id": u.id,
            "email": u.email,
            "password": u.password,
            "display_name": u.display_name,
            "experience_level": u.experience_level,
            "preferred_training_goal": u.preferred_training_goal,
            "weight_kg": u.weight_kg,
            "height_cm": u.height_cm,
            "persona_name": u.persona_name,
            "dev_token": u.dev_token,
            "jwt_token": u.jwt_token,
            "created_at": u.created_at,
        }
        for u in users
    ]

    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(users_export, f, indent=2)
    log.info("Exported %d user credentials to %s", len(users_export), output_path)

    if args.dry_run:
        log.info("Dry-run complete. No HTTP requests sent.")
        return

    # 5. Connect and Execute Batched Inserts
    client = SupabaseClientWrapper(target_url, args.service_key)

    if args.reset:
        client.reset_database()

    # Step 0: Synchronize GoTrue Auth Users (Fixes Auth Disconnect)
    client.register_auth_users(users)

    # Step 1: Upsert Profiles
    profiles_data = [
        {
            "id": u.id,
            "display_name": u.display_name,
            "experience_level": u.experience_level,
            "preferred_training_goal": u.preferred_training_goal,
            "created_at": u.created_at,
        }
        for u in users
    ]
    client.batch_insert("profiles", profiles_data, batch_size=args.batch_size)

    # Step 2: Upsert Workout Sessions
    client.batch_insert("workout_sessions", all_sessions, batch_size=args.batch_size)

    # Step 3: Upsert Workout Exercises
    client.batch_insert("workout_exercises", all_exercises, batch_size=args.batch_size)

    # Step 4: Upsert Workout Sets
    client.batch_insert("workout_sets", all_sets, batch_size=args.batch_size)

    # Step 5: Upsert AI Recommendations
    if all_recommendations:
        client.batch_insert("ai_recommendations", all_recommendations, batch_size=args.batch_size)

    log.info("=============================================================")
    log.info("Database seeding successfully completed!")
    log.info("=============================================================")

if __name__ == "__main__":
    main()
