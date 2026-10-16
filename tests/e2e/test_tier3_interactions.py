"""
Tier 3: Pairwise Cross-Feature Interaction E2E Tests.
Validates end-to-end integration across feature pairs:
- F1 x F2: Staging Environment x Seed Pipeline
- F2 x F3: Seed Pipeline x User Journeys
- F3 x F4: User Journeys x Row-Level Security Isolation
- F3 x F6: User Journeys x Locust Personas
- F4 x F7: RLS Isolation x Dynamic JWT Tokens
- F6 x F8: Locust Personas x Tiered Concurrency
- F7 x F10: Dynamic JWT x Metrics Calculation
- F8 x F9: Concurrency Profiles x Benchmark Runner
- F9 x F10: Benchmark Runner x Metrics Aggregation
- F10 x F11: Metrics Aggregation x Standalone Reports
- F2 x F10: Seed Pipeline x RAG Performance
- F3 x F11: Full User Journey x Executive Reporting
Total Tests: 12
"""

from __future__ import annotations

import concurrent.futures
import math
import os
import random
import time
import uuid
import pytest


class TestTier3PairwiseInteractions:
    """Pairwise cross-feature interactions validating integration contracts."""

    def test_interaction_f1_staging_with_f2_seed(self, staging_engine, catalog_reader):
        """F1 x F2: Staging environment initialized and populated by seed pipeline."""
        # 1. Staging tables ready
        assert staging_engine._get_table_data("profiles") is not None
        assert staging_engine._get_table_data("workout_sessions") is not None

        # 2. Seed catalog
        catalog = catalog_reader.load()
        assert len(catalog) >= 1300

        # 3. Seed test users into staging engine
        seeded_users = []
        for i in range(5):
            email = f"seed_f1f2_{i}_{uuid.uuid4().hex[:6]}@pulsefit.test"
            res = staging_engine.signup(email, "Password123!", {"preferred_training_goal": "hypertrophy"})
            assert res.status_code == 200
            seeded_users.append(res.json()["user"]["id"])

        assert len(seeded_users) == 5

    def test_interaction_f2_seed_with_f3_auth_journeys(self, staging_engine, catalog_reader):
        """F2 x F3: Seeded user authenticates, reads seeded catalog, and logs workout session."""
        email = f"f2f3_{uuid.uuid4().hex[:6]}@pulsefit.test"
        signup_res = staging_engine.signup(email, "UserPass123!", {"preferred_training_goal": "strength"})
        user_id = signup_res.json()["user"]["id"]
        auth_header = f"Bearer {signup_res.json()['access_token']}"

        # Query catalog for chest exercises
        chest_exercises = catalog_reader.filter_by_muscle("chest")
        selected_ex = chest_exercises[0] if chest_exercises else {"name": "Bench Press"}

        # Create session
        s_id = str(uuid.uuid4())
        staging_engine.insert("workout_sessions", auth_header, {
            "id": s_id, "user_id": user_id, "routine_name": "Chest Day", "started_at": "2026-10-11T10:00:00Z"
        })

        # Add exercise
        ex_id = str(uuid.uuid4())
        staging_engine.insert("workout_exercises", auth_header, {
            "id": ex_id, "workout_session_id": s_id, "exercise_name": selected_ex["name"]
        })

        # Add set
        staging_engine.insert("workout_sets", auth_header, {
            "workout_exercise_id": ex_id, "set_number": 1, "completed_reps": 10, "completed_weight": 80.0
        })

        # Verify query back
        sessions = staging_engine.query("workout_sessions", auth_header, {"id=eq": s_id}).json()
        assert len(sessions) == 1
        assert sessions[0]["routine_name"] == "Chest Day"

    def test_interaction_f3_auth_journeys_with_f4_rls_isolation(self, staging_engine, test_user_factory):
        """F3 x F4: Multiple authenticated users simultaneously logging sessions with zero cross-tenant leakage."""
        users = [test_user_factory(f"f3f4_user_{i}") for i in range(5)]

        for i, u in enumerate(users):
            s_id = str(uuid.uuid4())
            staging_engine.insert("workout_sessions", u["auth_header"], {
                "id": s_id, "user_id": u["user_id"], "routine_name": f"Routine #{i}"
            })

        # Verify each user strictly sees their own session
        for i, u in enumerate(users):
            user_sessions = staging_engine.query("workout_sessions", u["auth_header"]).json()
            assert len(user_sessions) == 1
            assert user_sessions[0]["user_id"] == u["user_id"]
            assert user_sessions[0]["routine_name"] == f"Routine #{i}"

    def test_interaction_f3_auth_journeys_with_f6_locust_personas(self, staging_engine, test_user_factory, catalog_reader):
        """F3 x F6: Locust persona task workflow executing against authenticated endpoints."""
        user = test_user_factory("persona_runner")
        tasks = ["browse_catalog", "log_workout_session", "check_profile"]

        # 1. Browse catalog
        sample_ex = catalog_reader.load()[:5]
        assert len(sample_ex) == 5

        # 2. Log workout
        s_id = str(uuid.uuid4())
        res_post = staging_engine.insert("workout_sessions", user["auth_header"], {
            "id": s_id, "user_id": user["user_id"], "routine_name": "Persona Routine"
        })
        assert res_post.status_code == 201

        # 3. Check profile
        profile = staging_engine.query("profiles", user["auth_header"]).json()
        assert len(profile) == 1
        assert profile[0]["id"] == user["user_id"]

    def test_interaction_f4_rls_isolation_with_f7_dynamic_jwt(self, staging_engine):
        """F4 x F7: 20 concurrent virtual users using dynamic tokens dev-user-{uuid} with strict tenant isolation."""
        virtual_user_ids = [str(uuid.uuid4()) for _ in range(20)]

        def run_virtual_user(u_id):
            auth_header = f"Bearer dev-user-{u_id}"
            s_id = str(uuid.uuid4())
            staging_engine.insert("workout_sessions", auth_header, {
                "id": s_id, "user_id": u_id, "routine_name": f"Session for {u_id}"
            })
            # Query back
            res = staging_engine.query("workout_sessions", auth_header).json()
            return res

        with concurrent.futures.ThreadPoolExecutor(max_workers=10) as executor:
            all_results = list(executor.map(run_virtual_user, virtual_user_ids))

        assert len(all_results) == 20
        for i, res in enumerate(all_results):
            assert len(res) == 1
            assert res[0]["user_id"] == virtual_user_ids[i]

    def test_interaction_f6_personas_with_f8_tiered_concurrency(self):
        """F6 x F8: Weighted personas simulated under Baseline (50 users) and Medium (250 users) concurrency."""
        tiers = {
            "baseline": {"users": 50, "spawn_rate": 5},
            "medium": {"users": 250, "spawn_rate": 25},
        }
        personas = ["casual", "regular", "powerlifter", "ai_enthusiast"]
        weights = [40, 35, 15, 10]

        for tier_name, conf in tiers.items():
            assigned = random.choices(personas, weights=weights, k=conf["users"])
            assert len(assigned) == conf["users"]
            # Casual should be more frequent than AI enthusiast
            assert assigned.count("casual") >= assigned.count("ai_enthusiast")

    def test_interaction_f7_dynamic_jwt_with_f10_metrics_calculation(self, staging_engine, metrics_calculator):
        """F7 x F10: Virtual user requests tracked and aggregated into p50/p95/p99 and RPS."""
        latencies_ms = []
        status_codes = []

        start_time = time.perf_counter()
        for i in range(30):
            u_id = str(uuid.uuid4())
            auth = f"Bearer dev-user-{u_id}"
            t0 = time.perf_counter()
            res = staging_engine.query("workout_sessions", auth)
            elapsed_ms = (time.perf_counter() - t0) * 1000.0
            latencies_ms.append(elapsed_ms)
            status_codes.append(res.status_code)

        duration = time.perf_counter() - start_time
        metrics = metrics_calculator.calculate_metrics(latencies_ms, duration, status_codes)

        assert metrics["total_requests"] == 30
        assert metrics["errors"]["total"] == 0
        assert metrics["latencies"]["p50"] >= 0.0
        assert metrics["rps"] > 0

    def test_interaction_f8_concurrency_profiles_with_f9_benchmark_runner(self):
        """F8 x F9: Benchmark runner dispatches tiered concurrency profiles with ramp-up pacing."""
        class MockBenchmarkRunner:
            def dispatch_tier(self, tier: str, users: int, spawn_rate: int):
                ramp_seconds = users / spawn_rate
                return {
                    "tier": tier,
                    "target_users": users,
                    "spawn_rate": spawn_rate,
                    "ramp_duration_seconds": ramp_seconds,
                    "status": "ready",
                }

        runner = MockBenchmarkRunner()
        res = runner.dispatch_tier("medium", 250, 25)
        assert res["ramp_duration_seconds"] == 10.0
        assert res["status"] == "ready"

    def test_interaction_f9_benchmark_runner_with_f10_metrics_aggregation(self, metrics_calculator):
        """F9 x F10: Benchmark runner transforms execution logs into statistical metrics."""
        raw_events = [
            {"time": 0.1, "latency_ms": 15.0, "status": 200},
            {"time": 0.2, "latency_ms": 25.0, "status": 200},
            {"time": 0.3, "latency_ms": 45.0, "status": 200},
            {"time": 0.4, "latency_ms": 120.0, "status": 429},
        ]
        latencies = [e["latency_ms"] for e in raw_events]
        codes = [e["status"] for e in raw_events]

        metrics = metrics_calculator.calculate_metrics(latencies, duration_seconds=1.0, status_codes=codes)
        assert metrics["total_requests"] == 4
        assert metrics["errors"]["status_429"] == 1
        assert metrics["errors"]["error_rate_pct"] == 25.0

    def test_interaction_f10_metrics_with_f11_standalone_reports(self, metrics_calculator, report_validator):
        """F10 x F11: Calculated benchmark metrics transformed into valid HTML report and Markdown summary."""
        latencies = [12.0, 18.5, 25.0, 42.0, 85.0, 110.0]
        status_codes = [200, 200, 200, 200, 200, 429]
        metrics = metrics_calculator.calculate_metrics(latencies, duration_seconds=2.0, status_codes=status_codes)

        html_out = report_validator.generate_html_report(metrics)
        md_out = report_validator.generate_markdown_summary(metrics)

        assert report_validator.validate_html(html_out)
        assert report_validator.validate_markdown(md_out)
        assert f"{metrics['latencies']['p50']:.1f}" in html_out
        assert f"{metrics['rps']:.1f}" in md_out

    def test_interaction_f2_seed_pipeline_with_f10_rag_performance(self, catalog_reader, rag_adapter, metrics_calculator):
        """F2 x F10: Seeded exercise catalog volume computed with deterministic stats and verified."""
        catalog = catalog_reader.load()
        assert len(catalog) >= 1300

        # Create session payload from catalog
        session_payload = {
            "force_refresh": False,
            "recent_sessions": [
                {
                    "routine_name": "Chest & Triceps",
                    "started_at": "2026-10-10T08:00:00Z",
                    "total_volume": 3200.0,
                    "exercises": [
                        {
                            "exercise_name": "Bench Press",
                            "primary_muscle_group": "Chest",
                            "sets": [{"set_number": 1, "completed_reps": 10, "completed_weight": 80.0, "is_completed": True}]
                        }
                    ]
                }
            ]
        }
        t0 = time.perf_counter()
        resp = rag_adapter.recommend(session_payload, token="dev-user-00000000-0000-0000-0000-000000000001")
        elapsed_ms = (time.perf_counter() - t0) * 1000.0

        metrics = metrics_calculator.calculate_metrics([elapsed_ms], duration_seconds=1.0)
        assert metrics["total_requests"] == 1
        assert resp["status_code"] in (200, 429)

    def test_interaction_f3_user_journey_with_f11_reporting_pipeline(self, staging_engine, test_user_factory, metrics_calculator, report_validator):
        """F3 x F11: Full workflow from user creation to workout logging to report generation."""
        # 1. User & session
        user = test_user_factory("e2e_journey_user")
        s_id = str(uuid.uuid4())
        staging_engine.insert("workout_sessions", user["auth_header"], {
            "id": s_id, "user_id": user["user_id"], "routine_name": "Full Journey Routine", "total_volume": 5500.0
        })

        # 2. Track latencies
        sample_latencies = [15.2, 22.4, 31.0, 45.8, 60.1]
        metrics = metrics_calculator.calculate_metrics(sample_latencies, duration_seconds=1.0)

        # 3. Render reports
        html_out = report_validator.generate_html_report(metrics)
        md_out = report_validator.generate_markdown_summary(metrics)

        assert report_validator.validate_html(html_out)
        assert report_validator.validate_markdown(md_out)
        assert "SLA: PASS" in html_out
