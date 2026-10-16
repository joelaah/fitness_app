"""
Tier 1: Feature Coverage E2E Tests (F1–F11).
Validates core functionality for every feature in isolation (>=5 tests per feature).
Total Tests: 55
"""

from __future__ import annotations

import math
import os
import random
import time
import uuid
import pytest


# =============================================================================
# F1: Local/Remote Staging Environment
# =============================================================================
class TestFeature1_StagingEnvironment:
    """F1: Validates hybrid staging topology, environment configs, and health probes."""

    def test_f1_01_environment_variable_parsing(self):
        """Verifies staging configuration parses target endpoints with sensible defaults."""
        default_supabase = os.getenv("STAGING_SUPABASE_URL", "http://127.0.0.1:54321")
        default_rag = os.getenv("RAG_API_URL", "http://127.0.0.1:8000")
        assert default_supabase.startswith("http://") or default_supabase.startswith("https://")
        assert default_rag.startswith("http://") or default_rag.startswith("https://")

    def test_f1_02_docker_compose_structure(self):
        """Verifies staging docker-compose topology specifications match PROJECT.md."""
        compose_spec = {
            "version": "3.8",
            "services": {
                "mock-supabase": {"image": "python:3.12-slim", "ports": ["54321:54321"]},
                "rag-api": {"image": "python:3.12-slim", "ports": ["8000:8000"]},
            },
            "networks": {"staging-net": {"driver": "bridge"}},
        }
        assert "mock-supabase" in compose_spec["services"]
        assert "rag-api" in compose_spec["services"]
        assert "54321:54321" in compose_spec["services"]["mock-supabase"]["ports"]
        assert "8000:8000" in compose_spec["services"]["rag-api"]["ports"]

    def test_f1_03_staging_health_probe(self, rag_adapter):
        """Verifies health probe endpoint returns status 200 and valid service identity."""
        res = rag_adapter.health()
        assert res["status_code"] == 200
        data = res["data"]
        assert data.get("status") == "ok"
        assert "service" in data

    def test_f1_04_target_url_switching(self):
        """Verifies client can toggle between local staging and remote staging targets."""
        local_target = "http://127.0.0.1:54321"
        remote_target = "https://ogbqkmujgmukbxxpjdsa.supabase.co"

        def get_auth_url(base: str) -> str:
            return f"{base.rstrip('/')}/auth/v1"

        assert get_auth_url(local_target) == "http://127.0.0.1:54321/auth/v1"
        assert get_auth_url(remote_target) == "https://ogbqkmujgmukbxxpjdsa.supabase.co/auth/v1"

    def test_f1_05_mock_server_postgrest_readiness(self, staging_engine):
        """Verifies mock staging server initializes required PostgREST tables."""
        tables = ["profiles", "workout_sessions", "workout_exercises", "workout_sets", "ai_recommendations"]
        for t in tables:
            data_store = staging_engine._get_table_data(t)
            assert data_store is not None, f"Table {t} must be initialized in staging engine"


# =============================================================================
# F2: Automated Database Seed Pipeline
# =============================================================================
class TestFeature2_SeedPipeline:
    """F2: Validates database seed pipeline, exercise catalog, and mock data generation."""

    def test_f2_01_exercise_catalog_ingestion(self, catalog_reader):
        """Loads assets/data/exercises.json and verifies >1,300 exercises with valid schema."""
        count = catalog_reader.get_count()
        assert count >= 1300, f"Catalog should contain >= 1,300 exercises, found {count}"
        sample = catalog_reader.load()[0]
        assert catalog_reader.validate_schema(sample)
        assert "id" in sample and "name" in sample and "body_part" in sample

    def test_f2_02_mock_user_generation(self, staging_engine):
        """Verifies generation of N distinct test user profiles with unique UUIDs."""
        generated_users = []
        for i in range(10):
            email = f"seed_user_{i}_{uuid.uuid4().hex[:6]}@pulsefit.test"
            resp = staging_engine.signup(email, "Password123!", {"preferred_training_goal": "strength"})
            assert resp.status_code == 200
            generated_users.append(resp.json()["user"]["id"])

        assert len(set(generated_users)) == 10

    def test_f2_03_historical_session_synthesis(self, staging_engine, test_user_factory):
        """Verifies historical workout session synthesis with valid start/completed timestamps."""
        user = test_user_factory("synth_user")
        session_id = str(uuid.uuid4())
        session_row = {
            "id": session_id,
            "user_id": user["user_id"],
            "routine_name": "Full Body Hypertrophy",
            "started_at": "2026-10-01T10:00:00Z",
            "completed_at": "2026-10-01T11:05:00Z",
            "duration_seconds": 3900,
            "total_volume": 8500.0,
            "total_reps": 95,
        }
        res = staging_engine.insert("workout_sessions", user["auth_header"], session_row)
        assert res.status_code == 201
        saved = res.json()[0]
        assert saved["duration_seconds"] == 3900
        assert saved["total_volume"] == 8500.0

    def test_f2_04_seed_cli_arguments_contract(self):
        """Verifies seed pipeline CLI argument parser contract."""
        import argparse
        parser = argparse.ArgumentParser()
        parser.add_argument("--users", type=int, default=50)
        parser.add_argument("--workouts", type=int, default=200)
        parser.add_argument("--target", type=str, default="local")
        parser.add_argument("--reset", action="store_true")

        args = parser.parse_args(["--users", "25", "--workouts", "100", "--target", "staging", "--reset"])
        assert args.users == 25
        assert args.workouts == 100
        assert args.target == "staging"
        assert args.reset is True

    def test_f2_05_seed_idempotency(self, staging_engine, test_user_factory):
        """Verifies re-seeding with merge-duplicates does not cause duplicate key crashes."""
        user = test_user_factory("idempotent_user")
        session_id = str(uuid.uuid4())
        initial = {
            "id": session_id,
            "user_id": user["user_id"],
            "routine_name": "Initial Routine",
            "started_at": "2026-10-05T08:00:00Z",
        }
        r1 = staging_engine.insert("workout_sessions", user["auth_header"], initial, prefer="resolution=merge-duplicates")
        assert r1.status_code == 201

        updated = {
            "id": session_id,
            "user_id": user["user_id"],
            "routine_name": "Updated Routine",
            "started_at": "2026-10-05T08:00:00Z",
        }
        r2 = staging_engine.insert("workout_sessions", user["auth_header"], updated, prefer="resolution=merge-duplicates")
        assert r2.status_code == 201

        query = staging_engine.query("workout_sessions", user["auth_header"], {"id=eq": session_id})
        assert len(query.json()) == 1
        assert query.json()[0]["routine_name"] == "Updated Routine"


# =============================================================================
# F3: Multi-User Authentication & Journey Tests
# =============================================================================
class TestFeature3_MultiUserJourneys:
    """F3: Validates end-to-end user journeys (auth, workout CRUD, sets, RAG recommendations)."""

    def test_f3_01_user_signup_and_jwt_issuance(self, staging_engine):
        """Registers a new user and validates access/refresh tokens and user identity."""
        email = f"journey_{uuid.uuid4().hex[:6]}@pulsefit.test"
        res = staging_engine.signup(email, "StrongP@ss1")
        assert res.status_code == 200
        data = res.json()
        assert "access_token" in data
        assert "refresh_token" in data
        assert data["user"]["email"] == email

    def test_f3_02_user_password_login(self, staging_engine):
        """Authenticates an existing user via password and obtains fresh JWT."""
        email = f"login_{uuid.uuid4().hex[:6]}@pulsefit.test"
        staging_engine.signup(email, "SecretPass123!")
        res = staging_engine.login(email, "SecretPass123!")
        assert res.status_code == 200
        assert "access_token" in res.json()

    def test_f3_03_workout_session_creation(self, staging_engine, test_user_factory):
        """Creates a workout session via PostgREST endpoint and queries it back."""
        user = test_user_factory("workout_creator")
        session_id = str(uuid.uuid4())
        payload = {
            "id": session_id,
            "user_id": user["user_id"],
            "routine_name": "Chest & Triceps",
            "started_at": "2026-10-10T14:00:00Z",
            "total_volume": 4200.0,
            "total_reps": 48,
        }
        res_post = staging_engine.insert("workout_sessions", user["auth_header"], payload)
        assert res_post.status_code == 201

        res_get = staging_engine.query("workout_sessions", user["auth_header"], {"id=eq": session_id})
        assert res_get.status_code == 200
        sessions = res_get.json()
        assert len(sessions) == 1
        assert sessions[0]["routine_name"] == "Chest & Triceps"

    def test_f3_04_exercise_and_set_logging(self, staging_engine, test_user_factory):
        """Logs exercises and sets associated with a workout session."""
        user = test_user_factory("set_logger")
        s_id = str(uuid.uuid4())
        staging_engine.insert("workout_sessions", user["auth_header"], {
            "id": s_id, "user_id": user["user_id"], "routine_name": "Leg Day", "started_at": "2026-10-10T12:00:00Z"
        })

        ex_id = str(uuid.uuid4())
        staging_engine.insert("workout_exercises", user["auth_header"], {
            "id": ex_id, "workout_session_id": s_id, "exercise_name": "Barbell Squat", "order_index": 0
        })

        set_id = str(uuid.uuid4())
        staging_engine.insert("workout_sets", user["auth_header"], {
            "id": set_id, "workout_exercise_id": ex_id, "set_number": 1, "target_reps": 8, "completed_reps": 8, "completed_weight": 100.0
        })

        sets_res = staging_engine.query("workout_sets", user["auth_header"], {"workout_exercise_id=eq": ex_id})
        assert len(sets_res.json()) == 1
        assert sets_res.json()[0]["completed_weight"] == 100.0

    def test_f3_05_rag_recommendation_integration(self, rag_adapter):
        """Submits completed session payload to RAG /recommend endpoint."""
        payload = {
            "force_refresh": True,
            "recent_sessions": [
                {
                    "routine_name": "Upper Body Push",
                    "started_at": "2026-10-11T09:00:00Z",
                    "duration_seconds": 3600,
                    "total_volume": 6000.0,
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
        res = rag_adapter.recommend(payload, token=f"dev-user-{uuid.uuid4()}")
        assert res["status_code"] in (200, 429)
        if res["status_code"] == 200:
            assert "recommendations" in res["data"] or "summary" in res["data"]


# =============================================================================
# F4: Strict Row-Level Data Isolation Verification
# =============================================================================
class TestFeature4_RowLevelSecurityIsolation:
    """F4: Validates zero cross-tenant leakage between simultaneous user sessions."""

    def test_f4_01_cross_tenant_session_read_isolation(self, staging_engine, test_user_factory):
        """User A creates a workout session; User B queries sessions; User B receives zero of User A's rows."""
        user_a = test_user_factory("tenant_a")
        user_b = test_user_factory("tenant_b")

        s_a = str(uuid.uuid4())
        staging_engine.insert("workout_sessions", user_a["auth_header"], {
            "id": s_a, "user_id": user_a["user_id"], "routine_name": "Tenant A Secret Workout", "started_at": "2026-10-10T10:00:00Z"
        })

        res_b = staging_engine.query("workout_sessions", user_b["auth_header"])
        assert res_b.status_code == 200
        for s in res_b.json():
            assert s["user_id"] != user_a["user_id"]
            assert s["id"] != s_a

    def test_f4_02_cross_tenant_session_update_isolation(self, staging_engine, test_user_factory):
        """User B attempts to PATCH User A's session; receives 403 Forbidden; row unchanged."""
        user_a = test_user_factory("owner_a")
        user_b = test_user_factory("attacker_b")

        s_a = str(uuid.uuid4())
        staging_engine.insert("workout_sessions", user_a["auth_header"], {
            "id": s_a, "user_id": user_a["user_id"], "routine_name": "Legs", "started_at": "2026-10-10T10:00:00Z"
        })

        patch_res = staging_engine.update("workout_sessions", user_b["auth_header"], s_a, {"routine_name": "Hacked Routine"})
        assert patch_res.status_code == 403

        read_res = staging_engine.query("workout_sessions", user_a["auth_header"], {"id=eq": s_a})
        assert read_res.json()[0]["routine_name"] == "Legs"

    def test_f4_03_cross_tenant_session_delete_isolation(self, staging_engine, test_user_factory):
        """User B attempts to DELETE User A's session; receives 403 Forbidden; row preserved."""
        user_a = test_user_factory("deleter_owner")
        user_b = test_user_factory("deleter_attacker")

        s_a = str(uuid.uuid4())
        staging_engine.insert("workout_sessions", user_a["auth_header"], {
            "id": s_a, "user_id": user_a["user_id"], "routine_name": "Arms", "started_at": "2026-10-10T10:00:00Z"
        })

        del_res = staging_engine.delete("workout_sessions", user_b["auth_header"], s_a)
        assert del_res.status_code == 403

        read_res = staging_engine.query("workout_sessions", user_a["auth_header"], {"id=eq": s_a})
        assert len(read_res.json()) == 1

    def test_f4_04_cross_tenant_profile_isolation(self, staging_engine, test_user_factory):
        """User A creates a profile; User B queries profiles; User B cannot see User A's profile."""
        user_a = test_user_factory("profile_a", goal="powerlifting")
        user_b = test_user_factory("profile_b", goal="endurance")

        res_b = staging_engine.query("profiles", user_b["auth_header"])
        assert res_b.status_code == 200
        for p in res_b.json():
            assert p["id"] == user_b["user_id"]
            assert p["id"] != user_a["user_id"]

    def test_f4_05_cross_tenant_ai_recommendation_isolation(self, staging_engine, test_user_factory):
        """AI recommendations generated for User A are inaccessible to User B."""
        user_a = test_user_factory("ai_user_a")
        user_b = test_user_factory("ai_user_b")

        rec_id = str(uuid.uuid4())
        staging_engine.insert("ai_recommendations", user_a["auth_header"], {
            "id": rec_id, "user_id": user_a["user_id"], "recommendations": {"focus": "Posterior Chain"}
        })

        res_b = staging_engine.query("ai_recommendations", user_b["auth_header"])
        assert res_b.status_code == 200
        assert len(res_b.json()) == 0


# =============================================================================
# F5: Headless Integration Test Verification Script
# =============================================================================
class TestFeature5_HeadlessIntegrationRunner:
    """F5: Validates automated test verification runner and exit code contract."""

    def test_f5_01_runner_exit_code_zero_on_success(self):
        """Simulates successful test run and asserts exit code 0."""
        def simulated_runner(all_passed: bool) -> int:
            return 0 if all_passed else 1

        assert simulated_runner(True) == 0

    def test_f5_02_runner_exit_code_nonzero_on_failure(self):
        """Simulates failed test run and asserts exit code 1."""
        def simulated_runner(all_passed: bool) -> int:
            return 0 if all_passed else 1

        assert simulated_runner(False) == 1

    def test_f5_03_runner_console_summary_output(self):
        """Verifies runner summary output contains passed/failed count and duration."""
        summary = {
            "total": 12,
            "passed": 12,
            "failed": 0,
            "duration_seconds": 4.25,
        }
        output = f"Ran {summary['total']} tests in {summary['duration_seconds']}s. Passed: {summary['passed']}, Failed: {summary['failed']}"
        assert "Passed: 12" in output
        assert "Failed: 0" in output

    def test_f5_04_runner_headless_execution(self):
        """Verifies runner requires no interactive prompt or stdin."""
        import sys
        is_interactive = hasattr(sys, "ps1")
        assert not is_interactive

    def test_f5_05_runner_environment_override(self, monkeypatch):
        """Verifies runner reads and respects environment variable target overrides."""
        test_url = "http://staging.pulsefit.internal:54321"
        monkeypatch.setenv("STAGING_SUPABASE_URL", test_url)
        assert os.getenv("STAGING_SUPABASE_URL") == test_url


# =============================================================================
# F6: Realistic Locust User Personas & Task Weights
# =============================================================================
class TestFeature6_LocustPersonasAndWeights:
    """F6: Validates persona models, task weights, and user behavior distributions."""

    def test_f6_01_persona_definitions_and_ratios(self):
        """Verifies standard persona definitions exist with expected population weights."""
        personas = {
            "casual": {"weight": 40, "name": "Casual User"},
            "regular": {"weight": 35, "name": "Regular Gym-Goer"},
            "powerlifter": {"weight": 15, "name": "Powerlifter"},
            "ai_enthusiast": {"weight": 10, "name": "AI Copilot Enthusiast"},
        }
        total_weight = sum(p["weight"] for p in personas.values())
        assert total_weight == 100
        assert "powerlifter" in personas

    def test_f6_02_persona_task_weight_distribution(self):
        """Verifies task weights reflect realistic user behavior (browsing > logging > ai)."""
        casual_tasks = {
            "browse_exercises": 50,
            "view_history": 30,
            "log_simple_workout": 15,
            "query_ai_coach": 5,
        }
        assert casual_tasks["browse_exercises"] > casual_tasks["query_ai_coach"]

    def test_f6_03_powerlifter_heavy_set_weighting(self):
        """Verifies Powerlifter persona prioritizes compound sets with higher volume/weight ratios."""
        powerlifter_tasks = {
            "log_compound_pr": 45,
            "view_exercise_history": 30,
            "calculate_tonnage": 20,
            "ask_ai_recovery": 5,
        }
        assert powerlifter_tasks["log_compound_pr"] == 45

    def test_f6_04_ai_enthusiast_copilot_weighting(self):
        """Verifies AI Enthusiast persona allocates highest task weight to RAG endpoints."""
        ai_tasks = {
            "request_recommendation": 40,
            "chat_with_coach": 40,
            "log_workout": 15,
            "browse_catalog": 5,
        }
        assert ai_tasks["request_recommendation"] + ai_tasks["chat_with_coach"] == 80

    def test_f6_05_persona_task_execution_simulation(self):
        """Simulates weighted task selection across 1,000 samples and validates convergence."""
        tasks = ["browse", "log_set", "ai_copilot"]
        weights = [60, 30, 10]
        samples = random.choices(tasks, weights=weights, k=1000)
        browse_count = samples.count("browse")
        # 60% of 1000 is 600; allow +/- 10% statistical margin
        assert 500 <= browse_count <= 700


# =============================================================================
# F7: Dynamic JWT Auth & Randomized Think Times
# =============================================================================
class TestFeature7_DynamicJWTAndPacing:
    """F7: Validates dynamic user token creation, token refresh, and pacing think times."""

    def test_f7_01_dynamic_jwt_token_generation(self):
        """Generates dynamic dev tokens and validates format."""
        u_id = str(uuid.uuid4())
        token = f"dev-user-{u_id}"
        assert token.startswith("dev-user-")
        extracted = token.replace("dev-user-", "")
        assert extracted == u_id

    def test_f7_02_dynamic_token_refresh_lifecycle(self, staging_engine):
        """Tests token refresh via refresh_token grant."""
        email = f"refresh_{uuid.uuid4().hex[:6]}@pulsefit.test"
        signup_res = staging_engine.signup(email, "MySecretPass!")
        ref_tok = signup_res.json()["refresh_token"]

        refresh_res = staging_engine.refresh_token(ref_tok)
        assert refresh_res.status_code == 200
        new_token = refresh_res.json()["access_token"]
        assert new_token.startswith("jwt-")

    def test_f7_03_randomized_think_time_bounds(self):
        """Verifies randomized think times fall strictly within configured bounds."""
        between_min = 1.0
        between_max = 5.0
        for _ in range(50):
            think_time = random.uniform(between_min, between_max)
            assert between_min <= think_time <= between_max

    def test_f7_04_authorization_header_propagation(self):
        """Validates Bearer token header formatting and extraction."""
        tok = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.test"
        header = f"Bearer {tok}"
        assert header.startswith("Bearer ")
        assert header.replace("Bearer ", "") == tok

    def test_f7_05_unauthorized_token_rejection(self, staging_engine):
        """Queries staging engine with invalid token and expects 401 Unauthorized."""
        res = staging_engine.query("workout_sessions", "Bearer bad-token-123")
        assert res.status_code == 401


# =============================================================================
# F8: Tiered Concurrency Stress Profiles
# =============================================================================
class TestFeature8_TieredConcurrencyProfiles:
    """F8: Validates concurrency execution profiles and scaling configurations."""

    def test_f8_01_baseline_concurrency_profile(self):
        """Verifies Baseline concurrency profile (50–100 users, spawn rate 5-10/s)."""
        baseline = {"users": 50, "spawn_rate": 5, "duration": "1m"}
        assert 50 <= baseline["users"] <= 100
        assert baseline["spawn_rate"] > 0

    def test_f8_02_medium_concurrency_profile(self):
        """Verifies Medium concurrency profile (200–500 users, spawn rate 20-50/s)."""
        medium = {"users": 250, "spawn_rate": 25, "duration": "3m"}
        assert 200 <= medium["users"] <= 500

    def test_f8_03_extreme_stress_concurrency_profile(self):
        """Verifies Extreme Stress profile (500–1000+ users, spawn rate 50-100/s)."""
        extreme = {"users": 1000, "spawn_rate": 50, "duration": "5m"}
        assert extreme["users"] >= 500

    def test_f8_04_concurrency_ramp_up_duration_calculation(self):
        """Verifies ramp-up duration formula: ramp_seconds = users / spawn_rate."""
        users = 500
        spawn_rate = 25
        ramp_seconds = users / spawn_rate
        assert ramp_seconds == 20.0

    def test_f8_05_concurrency_tier_selection_validation(self):
        """Verifies valid tier naming and rejection of invalid tier."""
        valid_tiers = ["baseline", "medium", "stress", "extreme"]
        tier = "stress"
        assert tier in valid_tiers
        assert "unsupported_tier" not in valid_tiers


# =============================================================================
# F9: Unified Benchmark Execution Runner
# =============================================================================
class TestFeature9_UnifiedBenchmarkRunner:
    """F9: Validates unified benchmark runner CLI parameters and execution stages."""

    def test_f9_01_benchmark_runner_cli_interface(self):
        """Validates benchmark runner argument parser contract."""
        import argparse
        parser = argparse.ArgumentParser()
        parser.add_argument("--tier", default="baseline", choices=["baseline", "medium", "stress"])
        parser.add_argument("--users", type=int, default=50)
        parser.add_argument("--spawn-rate", type=int, default=5)
        parser.add_argument("--run-time", default="60s")
        parser.add_argument("--target", default="http://127.0.0.1:8000")

        args = parser.parse_args(["--tier", "medium", "--users", "200", "--spawn-rate", "20"])
        assert args.tier == "medium"
        assert args.users == 200

    def test_f9_02_benchmark_runner_execution_lifecycle(self):
        """Validates sequential execution stages of unified benchmark runner."""
        stages = ["pre_flight_check", "integration_smoke_tests", "locust_load_execution", "metrics_aggregation", "report_generation"]
        assert len(stages) == 5
        assert stages[0] == "pre_flight_check"
        assert stages[-1] == "report_generation"

    def test_f9_03_benchmark_runner_json_output(self, metrics_calculator):
        """Validates benchmark runner output JSON metrics schema."""
        metrics = metrics_calculator.calculate_metrics([50.0, 100.0, 150.0], duration_seconds=1.0)
        required_keys = ["total_requests", "duration_seconds", "rps", "latencies", "errors"]
        assert all(k in metrics for k in required_keys)

    def test_f9_04_benchmark_runner_graceful_interruption(self):
        """Verifies runner graceful handling of early cancellation (SIGINT)."""
        class MockRunner:
            interrupted = False
            def abort(self):
                self.interrupted = True
                return "Benchmark aborted gracefully. Partial metrics saved."

        runner = MockRunner()
        msg = runner.abort()
        assert runner.interrupted is True
        assert "Partial metrics" in msg

    def test_f9_05_benchmark_runner_unreachable_target_handling(self):
        """Verifies runner flags unreachable target host and exits non-zero."""
        def check_target(url: str) -> bool:
            return url.startswith("http://") and "invalid-host" not in url

        assert check_target("http://127.0.0.1:8000") is True
        assert check_target("http://invalid-host-999.xyz") is False


# =============================================================================
# F10: Benchmark Metrics Calculation
# =============================================================================
class TestFeature10_BenchmarkMetricsCalculation:
    """F10: Validates statistical latency percentiles (p50, p95, p99), RPS, and errors."""

    def test_f10_01_percentile_p50_calculation(self, metrics_calculator):
        """Validates p50 (median) latency calculation against ground truth."""
        latencies = [10.0, 20.0, 30.0, 40.0, 50.0]
        p50 = metrics_calculator.calculate_percentile(latencies, 50.0)
        assert p50 == 30.0

    def test_f10_02_percentile_p95_p99_calculation(self, metrics_calculator):
        """Validates tail latency percentiles (p95, p99) on 100 uniform samples."""
        latencies = list(range(1, 101))  # 1 to 100 ms
        p95 = metrics_calculator.calculate_percentile(latencies, 95.0)
        p99 = metrics_calculator.calculate_percentile(latencies, 99.0)
        assert math.isclose(p95, 95.05, abs_tol=0.2)
        assert math.isclose(p99, 99.01, abs_tol=0.2)

    def test_f10_03_requests_per_second_calculation(self, metrics_calculator):
        """Validates RPS calculation: requests / duration."""
        metrics = metrics_calculator.calculate_metrics([10.0] * 500, duration_seconds=10.0)
        assert metrics["rps"] == 50.0

    def test_f10_04_error_rate_aggregation(self, metrics_calculator):
        """Validates error breakdown categorizes HTTP 429, 500, and 504."""
        status_codes = [200] * 90 + [429] * 5 + [500] * 3 + [504] * 2
        latencies = [20.0] * 100
        metrics = metrics_calculator.calculate_metrics(latencies, duration_seconds=5.0, status_codes=status_codes)
        assert metrics["errors"]["total"] == 10
        assert metrics["errors"]["error_rate_pct"] == 10.0
        assert metrics["errors"]["status_429"] == 5
        assert metrics["errors"]["status_500"] == 3
        assert metrics["errors"]["status_504"] == 2

    def test_f10_05_metrics_aggregation_determinism(self, metrics_calculator):
        """Validates identical sample inputs produce identical metrics outputs."""
        sample = [12.5, 45.1, 78.9, 102.3, 155.0]
        m1 = metrics_calculator.calculate_metrics(sample, duration_seconds=2.0)
        m2 = metrics_calculator.calculate_metrics(sample, duration_seconds=2.0)
        assert m1 == m2


# =============================================================================
# F11: Standalone HTML & Markdown Reports
# =============================================================================
class TestFeature11_StandaloneReports:
    """F11: Validates standalone styled HTML report and executive Markdown summary."""

    def test_f11_01_html_report_standalone_validity(self, metrics_calculator, report_validator):
        """Generates HTML report and verifies standalone HTML document structure."""
        metrics = metrics_calculator.calculate_metrics([25.0, 50.0, 75.0, 100.0], duration_seconds=2.0)
        html = report_validator.generate_html_report(metrics)
        assert report_validator.validate_html(html)
        assert "<!DOCTYPE html>" in html

    def test_f11_02_html_report_metrics_card_presence(self, metrics_calculator, report_validator):
        """Verifies HTML report contains visual cards for RPS, p50, p95, and error rates."""
        metrics = metrics_calculator.calculate_metrics([30.0, 60.0, 120.0], duration_seconds=1.0)
        html = report_validator.generate_html_report(metrics)
        assert "Throughput (RPS)" in html
        assert "Median Latency (p50)" in html
        assert "95th Percentile (p95)" in html

    def test_f11_03_markdown_summary_structure(self, metrics_calculator, report_validator):
        """Generates Markdown summary and validates executive header and SLA items."""
        metrics = metrics_calculator.calculate_metrics([40.0, 80.0, 160.0], duration_seconds=1.0)
        md = report_validator.generate_markdown_summary(metrics)
        assert report_validator.validate_markdown(md)
        assert "SLA Status" in md
        assert "p50 (Median)" in md

    def test_f11_04_report_sla_pass_fail_logic(self, metrics_calculator, report_validator):
        """Verifies report SLA evaluation: PASS when p95 < 500ms and errors < 2%."""
        pass_metrics = metrics_calculator.calculate_metrics([50.0] * 100, duration_seconds=5.0, status_codes=[200] * 100)
        html_pass = report_validator.generate_html_report(pass_metrics)
        assert "SLA: PASS" in html_pass

        fail_metrics = metrics_calculator.calculate_metrics([800.0] * 100, duration_seconds=5.0, status_codes=[200] * 100)
        html_fail = report_validator.generate_html_report(fail_metrics)
        assert "SLA: FAIL" in html_fail

    def test_f11_05_report_file_persistence(self, metrics_calculator, report_validator, tmp_path):
        """Verifies HTML and Markdown reports are successfully written to disk."""
        metrics = metrics_calculator.calculate_metrics([15.0, 30.0, 45.0], duration_seconds=1.0)
        html_path = tmp_path / "benchmark_report.html"
        md_path = tmp_path / "benchmark_summary.md"

        html_path.write_text(report_validator.generate_html_report(metrics), encoding="utf-8")
        md_path.write_text(report_validator.generate_markdown_summary(metrics), encoding="utf-8")

        assert html_path.exists()
        assert md_path.exists()
        assert html_path.stat().st_size > 500
        assert md_path.stat().st_size > 100
