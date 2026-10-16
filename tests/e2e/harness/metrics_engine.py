"""
Benchmark Metrics Engine for E2E Test Suite.
Calculates and validates statistical latency percentiles (p50, p95, p99),
Requests Per Second (RPS), and error rate distributions (HTTP 429, 500, 504).
"""

from __future__ import annotations

import math
from typing import Any, Dict, List, Optional


class BenchmarkMetricsCalculator:
    """Statistical calculator for benchmark execution results."""

    @staticmethod
    def calculate_percentile(data: List[float], percentile: float) -> float:
        """
        Calculates percentile using standard nearest-rank / linear interpolation.
        percentile: 0.0 to 100.0
        """
        if not data:
            return 0.0
        if len(data) == 1:
            return round(data[0], 2)

        sorted_data = sorted(data)
        k = (len(sorted_data) - 1) * (percentile / 100.0)
        f = math.floor(k)
        c = math.ceil(k)

        if f == c:
            return round(sorted_data[int(k)], 2)

        d0 = sorted_data[int(f)] * (c - k)
        d1 = sorted_data[int(c)] * (k - f)
        return round(d0 + d1, 2)

    @classmethod
    def calculate_metrics(
        cls,
        latencies_ms: List[float],
        duration_seconds: float,
        status_codes: Optional[List[int]] = None,
    ) -> Dict[str, Any]:
        """Aggregates latency list and status codes into comprehensive benchmark metrics."""
        total_requests = len(latencies_ms)
        if total_requests == 0:
            return {
                "total_requests": 0,
                "duration_seconds": max(0.001, duration_seconds),
                "rps": 0.0,
                "latencies": {"min": 0.0, "max": 0.0, "mean": 0.0, "p50": 0.0, "p95": 0.0, "p99": 0.0},
                "errors": {"total": 0, "error_rate_pct": 0.0, "status_429": 0, "status_500": 0, "status_504": 0},
            }

        safe_duration = max(0.001, duration_seconds)
        rps = round(total_requests / safe_duration, 2)

        p50 = cls.calculate_percentile(latencies_ms, 50.0)
        p95 = cls.calculate_percentile(latencies_ms, 95.0)
        p99 = cls.calculate_percentile(latencies_ms, 99.0)
        min_lat = round(min(latencies_ms), 2)
        max_lat = round(max(latencies_ms), 2)
        mean_lat = round(sum(latencies_ms) / total_requests, 2)

        # Status code error breakdown
        status_codes = status_codes or [200] * total_requests
        err_429 = sum(1 for c in status_codes if c == 429)
        err_500 = sum(1 for c in status_codes if c == 500)
        err_504 = sum(1 for c in status_codes if c == 504)
        total_errors = sum(1 for c in status_codes if c >= 400)
        error_rate = round((total_errors / total_requests) * 100.0, 2)

        return {
            "total_requests": total_requests,
            "duration_seconds": round(safe_duration, 2),
            "rps": rps,
            "latencies": {
                "min": min_lat,
                "max": max_lat,
                "mean": mean_lat,
                "p50": p50,
                "p95": p95,
                "p99": p99,
            },
            "errors": {
                "total": total_errors,
                "error_rate_pct": error_rate,
                "status_429": err_429,
                "status_500": err_500,
                "status_504": err_504,
            },
        }
