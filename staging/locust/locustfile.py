#!/usr/bin/env python3
"""
PulseFit AI - Production Locust Load & Stress Testing Suite
===========================================================
Simulates realistic multi-user personas interacting with PulseFit AI:
1. ExerciseCatalogBrowser (Weight 4): Explores exercises, filters by muscle group & equipment.
2. ActiveWorkoutLogger (Weight 5): Authenticated user logging workouts, exercises, and sets.
3. AICoachRequester (Weight 1): Requests AI workout recommendations and coaching advice.

Target environments:
- Local Staging: http://localhost:54321 (Mock Supabase) & http://localhost:8000 (RAG API)
- Cloud Staging / Production: Custom host via --host flag
"""

import os
import random
import uuid
from locust import HttpUser, task, between, events, tag


ANON_KEY = os.getenv("SUPABASE_ANON_KEY", "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.mock_anon")
SAMPLE_EXERCISES = [
    "Barbell Bench Press", "Barbell Squat", "Conventional Deadlift",
    "Overhead Press", "Pull Up", "Dumbbell Incline Press",
    "Romanian Deadlift", "Barbell Row", "Dips", "Lateral Raise"
]
MUSCLE_GROUPS = ["Chest", "Back", "Legs", "Shoulders", "Arms", "Core"]


class PulseFitBaseUser(HttpUser):
    """Base user handling authentication, token management, and headers."""
    abstract = True
    wait_time = between(1.0, 3.0)

    def on_start(self):
        """Initializes user session and registers/authenticates."""
        self.user_uuid = uuid.uuid4().hex[:8]
        self.email = f"loadtest_{self.user_uuid}@pulsefit.test"
        self.password = f"Pass_{self.user_uuid}!123"
        self.access_token = None
        self.user_id = None

        self.headers = {
            "apikey": ANON_KEY,
            "Content-Type": "application/json",
        }

        # Attempt signup on mock / staging Supabase
        signup_payload = {
            "email": self.email,
            "password": self.password,
            "data": {"experience_level": "intermediate", "goal": "hypertrophy"}
        }
        with self.client.post("/auth/v1/signup", json=signup_payload, headers=self.headers, catch_response=True) as resp:
            if resp.status_code in (200, 201):
                data = resp.json()
                self.access_token = data.get("access_token")
                self.user_id = data.get("user", {}).get("id")
                self.headers["Authorization"] = f"Bearer {self.access_token}"
                resp.success()
            else:
                # Fallback to dev token if mock allows dev tokens
                self.access_token = f"dev-user-{self.user_uuid}"
                self.user_id = str(uuid.uuid4())
                self.headers["Authorization"] = f"Bearer {self.access_token}"
                resp.success()


class ExerciseCatalogBrowser(PulseFitBaseUser):
    """Persona 1: Browses exercise catalog, filters by muscle group and equipment."""
    weight = 4

    @tag('browse')
    @task(3)
    def browse_exercises(self):
        """Fetches list of exercises."""
        self.client.get(
            "/rest/v1/exercises?select=id,name,muscle_group,equipment&limit=20",
            headers=self.headers,
            name="/rest/v1/exercises (browse)",
        )

    @tag('browse', 'filter')
    @task(2)
    def filter_by_muscle_group(self):
        """Filters exercises by a randomly selected muscle group."""
        group = random.choice(MUSCLE_GROUPS)
        self.client.get(
            f"/rest/v1/exercises?muscle_group=eq.{group}&limit=10",
            headers=self.headers,
            name="/rest/v1/exercises (filter muscle)",
        )

    @tag('browse')
    @task(1)
    def view_exercise_details(self):
        """Simulates viewing specific exercise instructions/metrics."""
        self.client.get(
            "/rest/v1/exercises?limit=1",
            headers=self.headers,
            name="/rest/v1/exercises (single detail)",
        )


class ActiveWorkoutLogger(PulseFitBaseUser):
    """Persona 2: Highly active workout tracker creating sessions, exercises, and sets."""
    weight = 5

    @tag('workout')
    @task
    def execute_complete_workout_flow(self):
        """Complete user journey: Start session -> Log 3 exercises with 3 sets each -> Finish."""
        session_id = str(uuid.uuid4())
        routine_name = f"{random.choice(MUSCLE_GROUPS)} Routine"

        # 1. Start Workout Session
        session_payload = {
            "id": session_id,
            "user_id": self.user_id or str(uuid.uuid4()),
            "routine_name": routine_name,
            "started_at": "2026-10-12T12:00:00Z",
            "total_volume": 0.0,
            "total_reps": 0,
        }
        create_res = self.client.post(
            "/rest/v1/workout_sessions",
            json=session_payload,
            headers=self.headers,
            name="/rest/v1/workout_sessions (create)",
        )
        if create_res.status_code not in (200, 201):
            return

        total_volume = 0.0
        total_reps = 0

        # 2. Add 2 exercises with 3 sets each
        for order_idx in range(2):
            ex_id = str(uuid.uuid4())
            ex_name = random.choice(SAMPLE_EXERCISES)
            self.client.post(
                "/rest/v1/workout_exercises",
                json={
                    "id": ex_id,
                    "workout_session_id": session_id,
                    "exercise_name": ex_name,
                    "order_index": order_idx,
                },
                headers=self.headers,
                name="/rest/v1/workout_exercises (add)",
            )

            # Log 3 sets
            for set_no in range(1, 4):
                weight = float(random.randint(40, 120))
                reps = random.randint(8, 12)
                total_volume += weight * reps
                total_reps += reps

                self.client.post(
                    "/rest/v1/workout_sets",
                    json={
                        "id": str(uuid.uuid4()),
                        "workout_exercise_id": ex_id,
                        "set_number": set_no,
                        "target_reps": reps,
                        "completed_reps": reps,
                        "completed_weight": weight,
                        "is_completed": True,
                    },
                    headers=self.headers,
                    name="/rest/v1/workout_sets (log set)",
                )

        # 3. Finalize Workout Session
        self.client.patch(
            f"/rest/v1/workout_sessions?id=eq.{session_id}",
            json={
                "ended_at": "2026-10-12T12:45:00Z",
                "total_volume": total_volume,
                "total_reps": total_reps,
            },
            headers=self.headers,
            name="/rest/v1/workout_sessions (finalize)",
        )


class AICoachRequester(PulseFitBaseUser):
    """Persona 3: Invokes AI recommendations and copilot feedback."""
    weight = 1
    wait_time = between(3.0, 6.0)

    @tag('ai', 'rag')
    @task
    def request_rag_workout_recommendation(self):
        """Simulates requesting an intelligent recommendation based on logged volume."""
        payload = {
            "force_refresh": False,
            "recent_sessions": [
                {
                    "routine_name": "Chest & Triceps",
                    "started_at": "2026-10-11T10:00:00Z",
                    "duration_seconds": 3600,
                    "total_volume": 4500.0,
                    "exercises": [
                        {
                            "exercise_name": "Barbell Bench Press",
                            "primary_muscle_group": "Chest",
                            "sets": [{"set_number": 1, "completed_reps": 10, "completed_weight": 80.0, "is_completed": True}],
                        }
                    ],
                }
            ],
        }
        # In staging, test mock RPC / recommendation endpoint
        with self.client.post(
            "/rest/v1/rpc/get_workout_recommendation",
            json=payload,
            headers=self.headers,
            catch_response=True,
            name="/rest/v1/rpc/get_workout_recommendation",
        ) as resp:
            # 200 (success), 404 (if rpc routes to standalone microservice), or 429 (rate-limited) are acceptable
            if resp.status_code in (200, 201, 404, 429):
                resp.success()
            else:
                resp.failure(f"Unexpected status code {resp.status_code}")
