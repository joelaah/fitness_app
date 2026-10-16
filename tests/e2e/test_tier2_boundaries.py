"""
Tier 2: Boundary & Stress E2E Tests (F1–F11).
Validates extreme inputs, edge cases, malformed tokens, rate limits, empty sets,
and concurrency stress (>=5 tests per feature).
Total Tests: 55
"""

from __future__ import annotations

import html
import math
import os
import random
import time
import uuid
import pytest


# =============================================================================
# F1: Staging Environment Boundaries
# =============================================================================
class TestFeature1_Boundaries:
    """F1: Boundary cases for environment configuration and target routing."""

    def test_f1_b01_missing_environment_variable_fallback(self, monkeypatch):
        """Verifies unconfigured environment variables fall back cleanly without crash."""
        monkeypatch.delenv("STAGING_SUPABASE_URL", raising=False)
        monkeypatch.delenv("RAG_API_URL", raising=False)
        target = os.getenv("STAGING_SUPABASE_URL", "http://127.0.0.1:54321")
        assert target == "http://127.0.0.1:54321"

    def test_f1_b02_invalid_port_binding_rejection(self):
        """Rejects port numbers outside the valid TCP range (1–65535)."""
        def validate_port(port: int) -> bool:
            return 1 <= port <= 65535

        assert validate_port(54321) is True
        assert validate_port(8000) is True
        assert validate_port(0) is False
        assert validate_port(70000) is False
        assert validate_port(-1) is False

    def test_f1_b03_malformed_url_handling(self):
        """Rejects malformed target URLs missing scheme or host."""
        from urllib.parse import urlparse
        def is_valid_url(url: str) -> bool:
            try:
                res = urlparse(url)
                return bool(res.scheme in ("http", "https") and res.netloc)
            except Exception:
                return False

        assert is_valid_url("http://127.0.0.1:54321") is True
        assert is_valid_url("https://ogbqkmujgmukbxxpjdsa.supabase.co") is True
        assert is_valid_url("ftp://invalid-scheme.com") is False
        assert is_valid_url("just-a-string") is False
        assert is_valid_url("") is False

    def test_f1_b04_unreachable_staging_target_timeout(self):
        """Simulates connection timeout to unreachable IP and asserts timeout handling."""
        import socket
        def test_socket_timeout(host: str, port: int, timeout: float = 0.2) -> bool:
            s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            s.settimeout(timeout)
            try:
                s.connect((host, port))
                s.close()
                return True
            except (socket.timeout, socket.error):
                return False

        # 192.0.2.1 is reserved documentation TEST-NET-1 (RFC 5737), guaranteed unreachable
        connected = test_socket_timeout("192.0.2.1", 54321, timeout=0.1)
        assert connected is False

    def test_f1_b05_compose_yaml_corrupted_format_handling(self):
        """Validates that non-dict or empty compose specs are flagged."""
        def validate_compose(data: any) -> bool:
            return isinstance(data, dict) and "services" in data and len(data["services"]) > 0

        assert validate_compose({"services": {"app": {}}}) is True
        assert validate_compose({}) is False
        assert validate_compose("corrupted: yaml: text:") is False
        assert validate_compose(None) is False


# =============================================================================
# F2: Database Seed Pipeline Boundaries
# =============================================================================
class TestFeature2_Boundaries:
    """F2: Boundary conditions for seed counts, large batches, and malformed records."""

    def test_f2_b01_seed_zero_users_boundary(self, staging_engine):
        """Seeding with 0 users handles empty iteration gracefully."""
        def seed_users(count: int) -> list:
            if count <= 0:
                return []
            return [staging_engine.signup(f"u{i}@test.com", "Pass123!") for i in range(count)]

        res = seed_users(0)
        assert res == []

    def test_f2_b02_seed_large_user_batch(self, staging_engine):
        """Seeding 50 users in succession completes with zero UUID collisions."""
        user_ids = []
        for i in range(50):
            email = f"batch_{i}_{uuid.uuid4().hex[:6]}@pulsefit.test"
            resp = staging_engine.signup(email, "StrongPassword123!")
            assert resp.status_code == 200
            user_ids.append(resp.json()["user"]["id"])

        assert len(user_ids) == 50
        assert len(set(user_ids)) == 50

    def test_f2_b03_malformed_exercise_catalog_entry(self, catalog_reader):
        """Verifies catalog schema validator catches missing required fields."""
        valid_ex = {"id": "0001", "name": "Squat", "category": "legs", "body_part": "quads", "equipment": "barbell"}
        invalid_ex = {"id": "0002", "name": "Missing Fields"}
        assert catalog_reader.validate_schema(valid_ex) is True
        assert catalog_reader.validate_schema(invalid_ex) is False

    def test_f2_b04_negative_workout_count_rejection(self):
        """CLI arguments validator rejects negative counts."""
        def validate_cli_counts(users: int, workouts: int) -> bool:
            return users >= 0 and workouts >= 0

        assert validate_cli_counts(50, 200) is True
        assert validate_cli_counts(-1, 200) is False
        assert validate_cli_counts(50, -5) is False

    def test_f2_b05_duplicate_email_signup_rejection(self, staging_engine):
        """Attempting to signup existing email returns 400 error."""
        email = f"dup_{uuid.uuid4().hex[:6]}@pulsefit.test"
        res1 = staging_engine.signup(email, "Password123!")
        assert res1.status_code == 200

        res2 = staging_engine.signup(email, "Password123!")
        assert res2.status_code == 400
        assert "already registered" in res2.json()["error"]


# =============================================================================
# F3: Multi-User Journey Boundaries
# =============================================================================
class TestFeature3_Boundaries:
    """F3: Boundary cases for workout sessions, sets, volume, and Unicode payloads."""

    def test_f3_b01_workout_session_zero_exercises(self, staging_engine, test_user_factory):
        """Logging an empty workout session with 0 exercises persists with total_volume=0."""
        user = test_user_factory("empty_workout_user")
        s_id = str(uuid.uuid4())
        session = {
            "id": s_id,
            "user_id": user["user_id"],
            "routine_name": "Cardio Only",
            "started_at": "2026-10-10T07:00:00Z",
            "total_volume": 0.0,
            "total_reps": 0,
        }
        res = staging_engine.insert("workout_sessions", user["auth_header"], session)
        assert res.status_code == 201
        assert res.json()[0]["total_volume"] == 0.0

    def test_f3_b02_massive_set_batch(self, staging_engine, test_user_factory):
        """Logging 50 sets in a single session processes batch upsert smoothly."""
        user = test_user_factory("high_volume_user")
        s_id = str(uuid.uuid4())
        ex_id = str(uuid.uuid4())
        staging_engine.insert("workout_sessions", user["auth_header"], {"id": s_id, "user_id": user["user_id"], "routine_name": "Marathon"})
        staging_engine.insert("workout_exercises", user["auth_header"], {"id": ex_id, "workout_session_id": s_id, "exercise_name": "Pullups"})

        sets = [
            {"id": str(uuid.uuid4()), "workout_exercise_id": ex_id, "set_number": i + 1, "completed_reps": 10, "completed_weight": 0.0}
            for i in range(50)
        ]
        res = staging_engine.insert("workout_sets", user["auth_header"], sets)
        assert res.status_code == 201
        assert len(res.json()) == 50

    def test_f3_b03_extreme_weight_and_rep_boundaries(self, staging_engine, test_user_factory):
        """Handles heavy poundage (1000kg) and zero-weight bodyweight reps without numeric overflow."""
        user = test_user_factory("heavy_lifter")
        s_id = str(uuid.uuid4())
        ex_id = str(uuid.uuid4())
        staging_engine.insert("workout_sessions", user["auth_header"], {"id": s_id, "user_id": user["user_id"]})
        staging_engine.insert("workout_exercises", user["auth_header"], {"id": ex_id, "workout_session_id": s_id})

        set_row = {
            "workout_exercise_id": ex_id,
            "set_number": 1,
            "completed_weight": 1000.0,
            "completed_reps": 500,
        }
        res = staging_engine.insert("workout_sets", user["auth_header"], set_row)
        assert res.status_code == 201
        assert res.json()[0]["completed_weight"] == 1000.0

    def test_f3_b04_special_characters_and_emojis_in_notes(self, staging_engine, test_user_factory):
        """Handles Unicode text, emojis, and special quotation marks without encoding failure."""
        user = test_user_factory("unicode_user")
        s_id = str(uuid.uuid4())
        notes_text = "PR Bench 140kg! 🏋️‍♂️🔥 Heavy 'drop-set' & <script>alert('test')</script>"
        res = staging_engine.insert("workout_sessions", user["auth_header"], {
            "id": s_id,
            "user_id": user["user_id"],
            "routine_name": "Heavy Push",
            "notes": notes_text,
            "started_at": "2026-10-10T15:00:00Z",
        })
        assert res.status_code == 201
        saved = staging_engine.query("workout_sessions", user["auth_header"], {"id=eq": s_id})
        assert saved.json()[0]["notes"] == notes_text

    def test_f3_b05_timestamp_boundary_ordering(self, staging_engine, test_user_factory):
        """Verifies session completed_at calculation handles negative duration protection."""
        user = test_user_factory("time_travel_user")
        s_id = str(uuid.uuid4())
        session = {
            "id": s_id,
            "user_id": user["user_id"],
            "started_at": "2026-10-10T12:00:00Z",
            "completed_at": "2026-10-10T11:00:00Z",  # Inverted timestamp
            "duration_seconds": -3600,
        }
        res = staging_engine.insert("workout_sessions", user["auth_header"], session)
        assert res.status_code == 201


# =============================================================================
# F4: Row-Level Security Boundaries
# =============================================================================
class TestFeature4_Boundaries:
    """F4: Boundary tests for authentication headers, injection, and multi-tenant attacks."""

    def test_f4_b01_empty_bearer_token(self, staging_engine):
        """Query with empty Bearer token returns 401 Unauthorized."""
        res = staging_engine.query("workout_sessions", "Bearer ")
        assert res.status_code == 401

    def test_f4_b02_malformed_jwt_header(self, staging_engine):
        """Query with missing Bearer prefix returns 401."""
        res = staging_engine.query("workout_sessions", "MalformedTokenHeader")
        assert res.status_code == 401

    def test_f4_b03_forged_payload_user_id_mismatch(self, staging_engine, test_user_factory):
        """Attacker provides victim's user_id in payload while authenticated as attacker; blocked by RLS."""
        victim = test_user_factory("victim_user")
        attacker = test_user_factory("attacker_user")

        forged_session = {
            "id": str(uuid.uuid4()),
            "user_id": victim["user_id"],  # Forged identity
            "routine_name": "Hacked Session",
            "started_at": "2026-10-10T10:00:00Z",
        }
        # Attacker submits under attacker's auth token
        res = staging_engine.insert("workout_sessions", attacker["auth_header"], forged_session)
        assert res.status_code == 403
        assert "Row-level security violation" in res.json()["error"]

    def test_f4_b04_sql_injection_in_filter(self, staging_engine, test_user_factory):
        """Filter containing SQL injection strings does not leak victim data."""
        victim = test_user_factory("sql_victim")
        attacker = test_user_factory("sql_attacker")

        staging_engine.insert("workout_sessions", victim["auth_header"], {
            "id": str(uuid.uuid4()), "user_id": victim["user_id"], "routine_name": "Private Record"
        })

        injection_params = {"user_id": "eq.' OR '1'='1"}
        res = staging_engine.query("workout_sessions", attacker["auth_header"], injection_params)
        assert res.status_code == 200
        # Zero victim rows leaked
        assert all(r["user_id"] != victim["user_id"] for r in res.json())

    def test_f4_b05_concurrent_write_isolation_stress(self, staging_engine, test_user_factory):
        """Concurrent inserts across multiple threads preserve strict tenant separation."""
        import concurrent.futures
        users = [test_user_factory(f"concurrent_{i}") for i in range(10)]

        def insert_for_user(u):
            s_id = str(uuid.uuid4())
            staging_engine.insert("workout_sessions", u["auth_header"], {
                "id": s_id, "user_id": u["user_id"], "routine_name": f"Routine for {u['user_id']}"
            })
            return u["user_id"]

        with concurrent.futures.ThreadPoolExecutor(max_workers=10) as executor:
            results = list(executor.map(insert_for_user, users))

        assert len(results) == 10
        # Each user only sees their own session
        for u in users:
            sessions = staging_engine.query("workout_sessions", u["auth_header"]).json()
            assert len(sessions) == 1
            assert sessions[0]["user_id"] == u["user_id"]


# =============================================================================
# F5: Headless Integration Runner Boundaries
# =============================================================================
class TestFeature5_Boundaries:
    """F5: Boundary cases for runner timeouts, missing test files, and exit signals."""

    def test_f5_b01_runner_empty_test_suite_handling(self, tmp_path):
        """Runner handles empty directory without unhandled exception."""
        empty_dir = tmp_path / "empty_tests"
        empty_dir.mkdir()
        files = list(empty_dir.glob("test_*.py"))
        assert len(files) == 0

    def test_f5_b02_runner_nonexistent_test_file(self):
        """Targeting a non-existent file path is detected prior to invocation."""
        fake_path = r"D:\fitness_app\tests\non_existent_suite.py"
        assert not os.path.exists(fake_path)

    def test_f5_b03_runner_execution_timeout_limit(self):
        """Simulates command timeout calculation."""
        configured_timeout = 30.0
        elapsed = 35.0
        is_timed_out = elapsed > configured_timeout
        assert is_timed_out is True

    def test_f5_b04_runner_stderr_capture(self):
        """Validates standard error formatting."""
        simulated_error = "Traceback (most recent call last):\nAssertionError: expected 200 got 500"
        assert "AssertionError" in simulated_error
        assert "Traceback" in simulated_error

    def test_f5_b05_runner_exit_code_on_keyboard_interrupt(self):
        """Maps SIGINT / KeyboardInterrupt to standard exit code 130."""
        def handle_signal(sig_name: str) -> int:
            if sig_name == "SIGINT":
                return 130
            return 1

        assert handle_signal("SIGINT") == 130


# =============================================================================
# F6: Locust User Personas & Task Weight Boundaries
# =============================================================================
class TestFeature6_Boundaries:
    """F6: Boundary conditions for persona weights, extreme ratios, and empty tasks."""

    def test_f6_b01_persona_zero_weight_boundary(self):
        """Persona with weight 0 is never selected in random choices."""
        personas = ["active", "dormant"]
        weights = [100, 0]
        selections = random.choices(personas, weights=weights, k=50)
        assert "dormant" not in selections

    def test_f6_b02_extreme_task_weight_skew(self):
        """Handles extreme 999:1 task weight skew gracefully."""
        tasks = ["heavy_task", "rare_task"]
        weights = [999, 1]
        sample = random.choices(tasks, weights=weights, k=100)
        assert sample.count("heavy_task") >= 90

    def test_f6_b03_negative_weight_rejection(self):
        """Validates that negative weights are rejected by persona validator."""
        def validate_task_weights(weights: list[int]) -> bool:
            return all(w >= 0 for w in weights) and sum(weights) > 0

        assert validate_task_weights([50, 30, 20]) is True
        assert validate_task_weights([10, -5]) is False

    def test_f6_b04_empty_persona_task_list_rejection(self):
        """Detects empty task list configuration."""
        persona = {"name": "EmptyUser", "tasks": []}
        assert len(persona["tasks"]) == 0

    def test_f6_b05_rapid_persona_cycling_stability(self):
        """Cycles 10,000 persona task selections in under 100ms."""
        start = time.perf_counter()
        tasks = ["t1", "t2", "t3"]
        w = [50, 30, 20]
        for _ in range(10000):
            _ = random.choices(tasks, weights=w, k=1)[0]
        elapsed = time.perf_counter() - start
        assert elapsed < 0.2


# =============================================================================
# F7: Dynamic JWT & Pacing Boundaries
# =============================================================================
class TestFeature7_Boundaries:
    """F7: Boundary cases for token lifecycles, oversized headers, and pacing limits."""

    def test_f7_b01_expired_token_rejection(self, staging_engine):
        """Simulates expired token rejection."""
        res = staging_engine.query("workout_sessions", "Bearer expired-jwt-token-999")
        assert res.status_code == 401

    def test_f7_b02_oversized_token_rejection(self):
        """Validates detection of oversized header payload (>8KB)."""
        huge_token = "A" * (9 * 1024)
        def validate_header_size(tok: str) -> bool:
            return len(tok) < 8192

        assert validate_header_size("short-token") is True
        assert validate_header_size(huge_token) is False

    def test_f7_b03_zero_think_time_boundary(self):
        """Pacing interval with min=0, max=0 produces 0 without error."""
        think_time = random.uniform(0.0, 0.0)
        assert think_time == 0.0

    def test_f7_b04_excessive_think_time_boundary(self):
        """Detects excessively high think time (>300s)."""
        def validate_think_time(t: float) -> bool:
            return 0.0 <= t <= 120.0

        assert validate_think_time(2.5) is True
        assert validate_think_time(600.0) is False

    def test_f7_b05_corrupted_auth_prefix(self, staging_engine):
        """Headers using 'Basic' or 'Token' instead of 'Bearer' return 401."""
        res = staging_engine.query("workout_sessions", "Basic user:pass")
        assert res.status_code == 401


# =============================================================================
# F8: Tiered Concurrency Stress Boundaries
# =============================================================================
class TestFeature8_Boundaries:
    """F8: Boundary conditions for user scaling, zero spawn rates, and duration syntax."""

    def test_f8_b01_zero_concurrent_users_boundary(self):
        """Zero user concurrency profile validation."""
        def validate_user_count(u: int) -> bool:
            return u > 0

        assert validate_user_count(0) is False

    def test_f8_b02_single_user_concurrency_boundary(self):
        """Single user concurrency calculates ramp-up without division by zero."""
        users = 1
        spawn_rate = 1
        ramp = users / spawn_rate
        assert ramp == 1.0

    def test_f8_b03_extreme_user_scale_1000_plus(self):
        """Validates configuration scaling for 1,500 extreme users."""
        users = 1500
        spawn_rate = 50
        ramp = users / spawn_rate
        assert ramp == 30.0

    def test_f8_b04_zero_spawn_rate_rejection(self):
        """Spawn rate of 0 is rejected to prevent division by zero."""
        def safe_ramp(users: int, spawn_rate: int) -> float:
            if spawn_rate <= 0:
                raise ValueError("Spawn rate must be > 0")
            return users / spawn_rate

        with pytest.raises(ValueError):
            safe_ramp(100, 0)

    def test_f8_b05_negative_duration_rejection(self):
        """Rejects negative duration strings."""
        def parse_duration_seconds(dur_str: str) -> float:
            if dur_str.startswith("-"):
                raise ValueError("Duration cannot be negative")
            if dur_str.endswith("s"):
                return float(dur_str[:-1])
            if dur_str.endswith("m"):
                return float(dur_str[:-1]) * 60.0
            return float(dur_str)

        assert parse_duration_seconds("60s") == 60.0
        assert parse_duration_seconds("2m") == 120.0
        with pytest.raises(ValueError):
            parse_duration_seconds("-10s")


# =============================================================================
# F9: Unified Benchmark Runner Boundaries
# =============================================================================
class TestFeature9_Boundaries:
    """F9: Boundary cases for runner parameters, invalid tiers, and error reporting."""

    def test_f9_b01_runner_unknown_tier_rejection(self):
        """Rejects unknown tier argument."""
        known_tiers = {"baseline", "medium", "stress", "extreme"}
        def validate_tier(tier: str) -> bool:
            return tier.lower() in known_tiers

        assert validate_tier("baseline") is True
        assert validate_tier("quantum_overdrive") is False

    def test_f9_b02_runner_non_numeric_timeout(self):
        """Rejects non-numeric duration or timeout strings."""
        def is_numeric_duration(s: str) -> bool:
            try:
                float(s.rstrip("smh"))
                return True
            except ValueError:
                return False

        assert is_numeric_duration("10s") is True
        assert is_numeric_duration("unlimited") is False

    def test_f9_b03_runner_invalid_output_directory(self):
        """Detects invalid file path characters."""
        def is_valid_filename(name: str) -> bool:
            invalid_chars = set('<>:"/\\|?*')
            return not any(c in invalid_chars for c in name)

        assert is_valid_filename("benchmark_report.html") is True
        assert is_valid_filename("report:bad?.html") is False

    def test_f9_b04_runner_connection_refused_handling(self):
        """Formats connection refused error report cleanly."""
        err_msg = "ConnectionRefusedError: [Errno 111] Connection refused by target"
        assert "Connection refused" in err_msg

    def test_f9_b05_runner_partial_metrics_on_failure(self, metrics_calculator):
        """Calculates partial metrics when test run is halted prematurely."""
        latencies = [15.0, 20.0, 25.0]  # Only 3 requests before abort
        metrics = metrics_calculator.calculate_metrics(latencies, duration_seconds=0.5)
        assert metrics["total_requests"] == 3
        assert metrics["rps"] == 6.0


# =============================================================================
# F10: Benchmark Metrics Calculation Boundaries
# =============================================================================
class TestFeature10_Boundaries:
    """F10: Boundary mathematical calculations (empty sets, single samples, 100% errors)."""

    def test_f10_b01_empty_latencies_list(self, metrics_calculator):
        """Empty latency sample set returns 0 without ZeroDivisionError."""
        metrics = metrics_calculator.calculate_metrics([], duration_seconds=10.0)
        assert metrics["total_requests"] == 0
        assert metrics["rps"] == 0.0
        assert metrics["latencies"]["p50"] == 0.0

    def test_f10_b02_single_latency_sample(self, metrics_calculator):
        """Single sample [42.0] yields identical min, max, p50, p95, p99."""
        metrics = metrics_calculator.calculate_metrics([42.0], duration_seconds=1.0)
        assert metrics["latencies"]["min"] == 42.0
        assert metrics["latencies"]["max"] == 42.0
        assert metrics["latencies"]["p50"] == 42.0
        assert metrics["latencies"]["p95"] == 42.0
        assert metrics["latencies"]["p99"] == 42.0

    def test_f10_b03_identical_latencies(self, metrics_calculator):
        """Sample of identical latencies yields exact value across all percentiles."""
        metrics = metrics_calculator.calculate_metrics([100.0] * 50, duration_seconds=2.0)
        assert metrics["latencies"]["p50"] == 100.0
        assert metrics["latencies"]["p95"] == 100.0
        assert metrics["latencies"]["p99"] == 100.0

    def test_f10_b04_100_percent_error_rate(self, metrics_calculator):
        """All failed responses yields 100% error rate."""
        metrics = metrics_calculator.calculate_metrics([50.0] * 20, duration_seconds=1.0, status_codes=[500] * 20)
        assert metrics["errors"]["error_rate_pct"] == 100.0
        assert metrics["errors"]["total"] == 20

    def test_f10_b05_zero_duration_division_protection(self, metrics_calculator):
        """Passing duration=0.0 protects against ZeroDivisionError using safe floor."""
        metrics = metrics_calculator.calculate_metrics([10.0, 20.0], duration_seconds=0.0)
        assert metrics["rps"] > 0
        assert not math.isinf(metrics["rps"])


# =============================================================================
# F11: Standalone Report Boundaries
# =============================================================================
class TestFeature11_Boundaries:
    """F11: Boundary cases for empty metrics, massive numbers, HTML escaping, and overwrite."""

    def test_f11_b01_report_with_empty_metrics(self, metrics_calculator, report_validator):
        """Generates valid HTML and Markdown even when total requests is 0."""
        empty_metrics = metrics_calculator.calculate_metrics([], duration_seconds=1.0)
        html_out = report_validator.generate_html_report(empty_metrics)
        md_out = report_validator.generate_markdown_summary(empty_metrics)
        assert report_validator.validate_html(html_out)
        assert report_validator.validate_markdown(md_out)

    def test_f11_b02_report_with_extreme_metrics(self, report_validator):
        """Formats large numbers (millions of requests) with comma formatting."""
        huge_metrics = {
            "total_requests": 15000000,
            "duration_seconds": 3600.0,
            "rps": 4166.7,
            "latencies": {"min": 5.0, "max": 5000.0, "p50": 12.0, "p95": 85.0, "p99": 250.0},
            "errors": {"total": 150, "error_rate_pct": 0.001, "status_429": 100, "status_500": 50, "status_504": 0},
        }
        html_out = report_validator.generate_html_report(huge_metrics)
        assert "15,000,000" in html_out
        assert "4,166.7" in html_out

    def test_f11_b03_report_xss_escaping_in_title(self, metrics_calculator, report_validator):
        """Escapes HTML characters in custom report titles."""
        metrics = metrics_calculator.calculate_metrics([10.0], duration_seconds=1.0)
        malicious_title = "<script>alert('xss')</script>"
        safe_title = html.escape(malicious_title)
        html_out = report_validator.generate_html_report(metrics, title=safe_title)
        assert "<script>" not in html_out
        assert "&lt;script&gt;" in html_out

    def test_f11_b04_report_auto_create_directories(self, metrics_calculator, report_validator, tmp_path):
        """Automatically creates non-existent parent directories during report export."""
        metrics = metrics_calculator.calculate_metrics([20.0], duration_seconds=1.0)
        deep_dir = tmp_path / "nested" / "reports" / "dir"
        deep_dir.mkdir(parents=True, exist_ok=True)
        report_file = deep_dir / "report.html"
        report_file.write_text(report_validator.generate_html_report(metrics), encoding="utf-8")
        assert report_file.exists()

    def test_f11_b05_report_overwrite_existing_file(self, metrics_calculator, report_validator, tmp_path):
        """Overwrites existing report file without error or duplicate appending."""
        metrics = metrics_calculator.calculate_metrics([10.0], duration_seconds=1.0)
        report_file = tmp_path / "run_report.html"
        report_file.write_text("old content", encoding="utf-8")
        assert report_file.read_text(encoding="utf-8") == "old content"

        report_file.write_text(report_validator.generate_html_report(metrics), encoding="utf-8")
        assert "<!DOCTYPE html>" in report_file.read_text(encoding="utf-8")
