"""
Pytest configuration and fixtures for PulseFit AI E2E Test Suite.
"""

from __future__ import annotations

import os
import sys
import uuid
import pytest

# Ensure tests directory is importable
TESTS_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_DIR = os.path.dirname(os.path.dirname(TESTS_DIR))
if PROJECT_DIR not in sys.path:
    sys.path.insert(0, PROJECT_DIR)

from tests.e2e.harness.catalog_reader import ExerciseCatalogReader
from tests.e2e.harness.metrics_engine import BenchmarkMetricsCalculator
from tests.e2e.harness.mock_staging_engine import MockStagingEngine
from tests.e2e.harness.rag_test_adapter import RAGTestAdapter
from tests.e2e.harness.report_validator import ReportValidator


@pytest.fixture
def staging_engine() -> MockStagingEngine:
    """Provides a fresh, isolated MockStagingEngine for every test."""
    return MockStagingEngine()


@pytest.fixture
def test_user_factory(staging_engine: MockStagingEngine):
    """Factory fixture generating unique authenticated users with JWTs."""
    def _create_user(email_prefix: str = "testuser", goal: str = "hypertrophy"):
        unique_id = str(uuid.uuid4())[:8]
        email = f"{email_prefix}_{unique_id}@pulsefit.test"
        password = "Password123!"
        resp = staging_engine.signup(
            email=email,
            password=password,
            metadata={"preferred_training_goal": goal, "experience_level": "intermediate"},
        )
        data = resp.json()
        return {
            "user_id": data["user"]["id"],
            "email": email,
            "password": password,
            "access_token": data["access_token"],
            "refresh_token": data["refresh_token"],
            "auth_header": f"Bearer {data['access_token']}",
        }
    return _create_user


@pytest.fixture(scope="session")
def rag_adapter() -> RAGTestAdapter:
    """Provides RAGTestAdapter connected to local or staging RAG microservice."""
    return RAGTestAdapter()


@pytest.fixture(scope="session")
def catalog_reader() -> ExerciseCatalogReader:
    """Provides reader for exercises.json catalog."""
    return ExerciseCatalogReader()


@pytest.fixture
def metrics_calculator() -> type[BenchmarkMetricsCalculator]:
    """Provides benchmark statistical metrics calculator."""
    return BenchmarkMetricsCalculator


@pytest.fixture
def report_validator() -> type[ReportValidator]:
    """Provides HTML & Markdown report validator."""
    return ReportValidator
