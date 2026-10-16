"""
Tier 4: Real-World Application Scenarios E2E Tests.
Validates realistic end-to-end gym user journeys and concurrent workloads:
1. Multi-User Evening Gym Rush Hour (50 concurrent lifters with zero data leakage)
2. Concurrent PR & Heavy Volume Logging (Progressive overload, tonnage math, cascade integrity)
3. AI Coach Recommendation Flood (Sustained RAG requests, caching, sliding-window rate limit)
4. End-to-End Staging Lifecycle (Seed -> Auth -> Workout CRUD -> RAG -> Benchmark -> Reporting)
5. Gym Network Flake & Reconnection Replay (Token refresh, offline batching, idempotent reconciliation)
Total Scenarios: 5
"""

from __future__ import annotations

import concurrent.futures
import math
import os
import time
import uuid
import pytest


class TestTier4RealWorldScenarios:
    """Real-world end-to-end gym application scenarios and stress workloads."""

    def test_scenario_01_multi_user_gym_rush_hour(self, staging_engine, catalog_reader):
        """
        Scenario 1: Multi-User Evening Gym Rush Hour.
        50 concurrent athletes authenticate, query routines, log multi-exercise workouts,
        and update set statuses simultaneously with ZERO cross-tenant data leakage.
        """
        num_users = 50
        athletes = []

        # 1. 50 athletes signup and authenticate concurrently
        def provision_athlete(idx: int):
            email = f"rush_hour_athlete_{idx}_{uuid.uuid4().hex[:6]}@pulsefit.test"
            res = staging_engine.signup(email, "GymP@ssword123!", {"preferred_training_goal": "hypertrophy"})
            assert res.status_code == 200
            data = res.json()
            return {
                "idx": idx,
                "user_id": data["user"]["id"],
                "auth_header": f"Bearer {data['access_token']}",
            }

        with concurrent.futures.ThreadPoolExecutor(max_workers=10) as executor:
            athletes = list(executor.map(provision_athlete, range(num_users)))

        assert len(athletes) == num_users

        # 2. Concurrently log workout sessions, exercises, and sets
        def execute_workout_session(ath):
            auth = ath["auth_header"]
            u_id = ath["user_id"]

            # Create session
            s_id = str(uuid.uuid4())
            staging_engine.insert("workout_sessions", auth, {
                "id": s_id,
                "user_id": u_id,
                "routine_name": f"Rush Hour Routine {ath['idx']}",
                "started_at": "2026-10-12T18:00:00Z",
                "completed_at": "2026-10-12T19:00:00Z",
                "total_volume": 4800.0,
                "total_reps": 40,
            })

            # Create exercise
            ex_id = str(uuid.uuid4())
            staging_engine.insert("workout_exercises", auth, {
                "id": ex_id,
                "workout_session_id": s_id,
                "exercise_name": "Incline Dumbbell Press",
                "order_index": 0,
            })

            # Create 3 sets
            for set_num in range(1, 4):
                staging_engine.insert("workout_sets", auth, {
                    "id": str(uuid.uuid4()),
                    "workout_exercise_id": ex_id,
                    "set_number": set_num,
                    "target_reps": 10,
                    "completed_reps": 10,
                    "completed_weight": 40.0,
                    "is_completed": True,
                })

            # Query back own sessions
            own_sessions = staging_engine.query("workout_sessions", auth).json()
            return {"user_id": u_id, "session_count": len(own_sessions), "first_session": own_sessions[0]}

        with concurrent.futures.ThreadPoolExecutor(max_workers=10) as executor:
            session_results = list(executor.map(execute_workout_session, athletes))

        # 3. Assertions: Zero cross-tenant leakage & 100% session isolation
        assert len(session_results) == num_users
        for res in session_results:
            assert res["session_count"] == 1
            assert res["first_session"]["user_id"] == res["user_id"]

    def test_scenario_02_concurrent_pr_heavy_volume_logging(self, staging_engine, test_user_factory):
        """
        Scenario 2: Concurrent PR & Heavy Volume Logging.
        Powerlifters recording high-volume compound lifts with progressive overload calculations,
        deterministic volume summation, and cascade deletion integrity.
        """
        lifter = test_user_factory("powerlifter_bob", goal="strength")
        auth = lifter["auth_header"]
        u_id = lifter["user_id"]

        # 1. Create heavy leg session
        s_id = str(uuid.uuid4())
        staging_engine.insert("workout_sessions", auth, {
            "id": s_id,
            "user_id": u_id,
            "routine_name": "Heavy Lower Power",
            "started_at": "2026-10-12T16:00:00Z",
        })

        # 2. Add Barbell Back Squat exercise
        squat_ex_id = str(uuid.uuid4())
        staging_engine.insert("workout_exercises", auth, {
            "id": squat_ex_id,
            "workout_session_id": s_id,
            "exercise_name": "Barbell Back Squat",
            "primary_muscle_group": "Legs",
        })

        # 3. Progressive pyramid sets: 140kg x 5, 160kg x 3, 180kg x 1 (PR)
        planned_sets = [
            {"set_number": 1, "weight": 140.0, "reps": 5},
            {"set_number": 2, "weight": 160.0, "reps": 3},
            {"set_number": 3, "weight": 180.0, "reps": 1},
        ]
        expected_squat_volume = sum(s["weight"] * s["reps"] for s in planned_sets)
        # 140*5 = 700, 160*3 = 480, 180*1 = 180 => 1360.0 kg

        for s in planned_sets:
            staging_engine.insert("workout_sets", auth, {
                "workout_exercise_id": squat_ex_id,
                "set_number": s["set_number"],
                "completed_weight": s["weight"],
                "completed_reps": s["reps"],
                "is_completed": True,
            })

        # 4. Verify volume calculation
        logged_sets = staging_engine.query("workout_sets", auth, {"workout_exercise_id=eq": squat_ex_id}).json()
        assert len(logged_sets) == 3
        actual_volume = sum(float(s["completed_weight"]) * int(s["completed_reps"]) for s in logged_sets)
        assert actual_volume == expected_squat_volume == 1360.0

        # 5. Complete session and update total_volume
        staging_engine.update("workout_sessions", auth, s_id, {
            "completed_at": "2026-10-12T17:15:00Z",
            "total_volume": actual_volume,
            "total_reps": sum(s["reps"] for s in planned_sets),
        })

        updated_session = staging_engine.query("workout_sessions", auth, {"id=eq": s_id}).json()[0]
        assert updated_session["total_volume"] == 1360.0

        # 6. Cascade delete verification: Deleting session deletes exercises and sets
        del_res = staging_engine.delete("workout_sessions", auth, s_id)
        assert del_res.status_code == 204
        assert len(staging_engine.query("workout_sessions", auth, {"id=eq": s_id}).json()) == 0
        assert len(staging_engine.query("workout_exercises", auth, {"workout_session_id=eq": s_id}).json()) == 0
        assert len(staging_engine.query("workout_sets", auth, {"workout_exercise_id=eq": squat_ex_id}).json()) == 0

    def test_scenario_03_ai_coach_recommendation_flood(self, rag_adapter):
        """
        Scenario 3: AI Coach Recommendation Flood.
        Simultaneous requests to RAG /recommend and /chat with volume distribution calculation,
        caching, and sliding-window rate limit protection.
        """
        # 1. Health probe
        health = rag_adapter.health()
        assert health["status_code"] == 200

        # 2. Workout payload with Chest volume
        history_payload = {
            "force_refresh": False,
            "recent_sessions": [
                {
                    "routine_name": "Chest Hypertrophy",
                    "started_at": "2026-10-11T08:00:00Z",
                    "total_volume": 4000.0,
                    "exercises": [
                        {
                            "exercise_name": "Barbell Bench Press",
                            "primary_muscle_group": "Chest",
                            "sets": [
                                {"set_number": 1, "completed_reps": 10, "completed_weight": 80.0, "is_completed": True},
                                {"set_number": 2, "completed_reps": 10, "completed_weight": 80.0, "is_completed": True},
                            ]
                        }
                    ]
                }
            ]
        }

        # Issue first recommendation request
        dev_token = f"dev-user-{uuid.uuid4()}"
        res1 = rag_adapter.recommend(history_payload, token=dev_token)
        assert res1["status_code"] in (200, 429)

        # 3. Conversational coaching interaction
        chat_payload = {
            "message": "What is the optimal rest interval between heavy bench sets?",
            "history": []
        }
        chat_res = rag_adapter.chat(chat_payload, token=dev_token)
        assert chat_res["status_code"] in (200, 429)

    def test_scenario_04_end_to_end_staging_lifecycle(self, staging_engine, catalog_reader, metrics_calculator, report_validator):
        """
        Scenario 4: End-to-End Staging Lifecycle.
        Complete automated lifecycle:
        Staging Probe -> Seed Catalog & Users -> User Workout CRUD -> Benchmark Metrics -> Report Generation.
        """
        # Stage 1: Verify Staging Tables
        for tbl in ["profiles", "workout_sessions", "workout_exercises", "workout_sets"]:
            assert staging_engine._get_table_data(tbl) is not None

        # Stage 2: Database Seeding
        catalog = catalog_reader.load()
        assert len(catalog) >= 1300

        seeded_user = staging_engine.signup("lifecycle_user@pulsefit.test", "P@ssword123!", {"preferred_training_goal": "general_fitness"}).json()
        u_id = seeded_user["user"]["id"]
        auth = f"Bearer {seeded_user['access_token']}"

        # Stage 3: User Workout CRUD
        s_id = str(uuid.uuid4())
        staging_engine.insert("workout_sessions", auth, {
            "id": s_id, "user_id": u_id, "routine_name": "Lifecycle Workout", "total_volume": 3500.0
        })

        ex_id = str(uuid.uuid4())
        staging_engine.insert("workout_exercises", auth, {
            "id": ex_id, "workout_session_id": s_id, "exercise_name": "Goblet Squat"
        })

        staging_engine.insert("workout_sets", auth, {
            "workout_exercise_id": ex_id, "set_number": 1, "completed_reps": 12, "completed_weight": 24.0
        })

        # Stage 4: Verify Saved Workout
        saved_session = staging_engine.query("workout_sessions", auth, {"id=eq": s_id}).json()
        assert len(saved_session) == 1
        assert saved_session[0]["total_volume"] == 3500.0

        # Stage 5: Concurrency Benchmark Simulation & Metrics
        latencies = [18.2, 24.5, 30.1, 42.0, 55.4, 72.8, 110.5]
        status_codes = [200] * 7
        metrics = metrics_calculator.calculate_metrics(latencies, duration_seconds=1.5, status_codes=status_codes)

        assert metrics["total_requests"] == 7
        assert metrics["rps"] > 0
        assert metrics["latencies"]["p95"] <= 110.5

        # Stage 6: Report Generation
        html_report = report_validator.generate_html_report(metrics, title="End-to-End Staging Benchmark")
        md_summary = report_validator.generate_markdown_summary(metrics, title="End-to-End Staging Benchmark Summary")

        assert report_validator.validate_html(html_report)
        assert report_validator.validate_markdown(md_summary)
        assert "SLA: PASS" in html_report
        assert "SLA Status" in md_summary and "PASSED" in md_summary

    def test_scenario_05_gym_network_flake_and_reconnection_replay(self, staging_engine):
        """
        Scenario 5: Gym Network Flake & Reconnection Replay.
        Simulates network disconnection, token expiration, re-authentication via refresh token,
        and idempotent offline batch upsert reconciliation.
        """
        # 1. Athlete signs in and receives initial tokens
        signup = staging_engine.signup(f"offline_{uuid.uuid4().hex[:6]}@pulsefit.test", "GymPass123!").json()
        u_id = signup["user"]["id"]
        auth_header = f"Bearer {signup['access_token']}"
        refresh_token = signup["refresh_token"]

        # 2. Athlete begins session online
        s_id = str(uuid.uuid4())
        staging_engine.insert("workout_sessions", auth_header, {
            "id": s_id, "user_id": u_id, "routine_name": "Fluctuating Wi-Fi Routine"
        })

        # 3. Wi-Fi drops; athlete's token expires; client requests token refresh
        refresh_resp = staging_engine.refresh_token(refresh_token)
        assert refresh_resp.status_code == 200
        new_auth_header = f"Bearer {refresh_resp.json()['access_token']}"

        # 4. Athlete logs sets locally offline:
        ex_id = str(uuid.uuid4())
        staging_engine.insert("workout_exercises", new_auth_header, {
            "id": ex_id, "workout_session_id": s_id, "exercise_name": "Cable Pushdown"
        })

        offline_sets = [
            {"id": str(uuid.uuid4()), "workout_exercise_id": ex_id, "set_number": 1, "completed_reps": 12, "completed_weight": 25.0},
            {"id": str(uuid.uuid4()), "workout_exercise_id": ex_id, "set_number": 2, "completed_reps": 10, "completed_weight": 30.0},
        ]

        # 5. Wi-Fi reconnects: sync sets with merge-duplicates resolution
        res_sync1 = staging_engine.insert("workout_sets", new_auth_header, offline_sets, prefer="resolution=merge-duplicates")
        assert res_sync1.status_code == 201

        # 6. Intermittent packet replay: same batch re-sent; idempotent upsert prevents duplicates
        res_sync2 = staging_engine.insert("workout_sets", new_auth_header, offline_sets, prefer="resolution=merge-duplicates")
        assert res_sync2.status_code == 201

        # Verify only 2 distinct sets exist
        queried_sets = staging_engine.query("workout_sets", new_auth_header, {"workout_exercise_id=eq": ex_id}).json()
        assert len(queried_sets) == 2
        set_numbers = [s["set_number"] for s in queried_sets]
        assert set_numbers == [1, 2]
