"""
PulseFit AI Headless E2E Test Runner.
Executes the comprehensive 4-tier E2E test suite and outputs formatted execution metrics.
Exit Code 0: All tests passed.
Exit Code 1: One or more test failures.
"""

from __future__ import annotations

import argparse
import os
import sys
import time
import pytest


def main() -> int:
    parser = argparse.ArgumentParser(description="PulseFit AI Headless E2E Test Runner")
    parser.add_argument(
        "--tier",
        choices=["all", "tier1", "tier2", "tier3", "tier4"],
        default="all",
        help="Test tier to execute (default: all)",
    )
    parser.add_argument(
        "-v", "--verbose",
        action="store_true",
        default=True,
        help="Verbose test execution output",
    )
    parser.add_argument(
        "-k", "--keyword",
        type=str,
        default="",
        help="Keyword expression to filter tests by name",
    )
    args = parser.parse_args()

    tests_dir = os.path.dirname(os.path.abspath(__file__))

    tier_files = {
        "tier1": os.path.join(tests_dir, "test_tier1_feature_coverage.py"),
        "tier2": os.path.join(tests_dir, "test_tier2_boundaries.py"),
        "tier3": os.path.join(tests_dir, "test_tier3_interactions.py"),
        "tier4": os.path.join(tests_dir, "test_tier4_scenarios.py"),
    }

    pytest_args = []
    if args.verbose:
        pytest_args.append("-v")

    if args.keyword:
        pytest_args.extend(["-k", args.keyword])

    if args.tier == "all":
        pytest_args.append(tests_dir)
    else:
        pytest_args.append(tier_files[args.tier])

    print("=" * 80)
    print(" PULSEFIT AI HEADLESS END-TO-END TEST SUITE RUNNER")
    print("=" * 80)
    print(f"Target Scope: {args.tier.upper()}")
    print(f"Execution Directory: {tests_dir}")
    print(f"Pytest Arguments: {' '.join(pytest_args)}")
    print("=" * 80)

    start_time = time.perf_counter()
    exit_code = pytest.main(pytest_args)
    elapsed = time.perf_counter() - start_time

    print("\n" + "=" * 80)
    print(f"EXECUTION COMPLETED in {elapsed:.2f} seconds")
    if exit_code == 0:
        print("RESULT: ALL TESTS PASSED (Exit Code: 0)")
    else:
        print(f"RESULT: TEST RUN FAILED (Exit Code: {exit_code})")
    print("=" * 80)

    return exit_code


if __name__ == "__main__":
    sys.exit(main())
