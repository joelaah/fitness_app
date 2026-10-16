"""
HTML & Markdown Benchmark Report Generator and Schema Validator (Feature F11).
"""

from __future__ import annotations

import os
from typing import Any, Dict


class ReportValidator:
    """Generates and validates standalone HTML and Markdown performance reports."""

    @staticmethod
    def generate_html_report(metrics: Dict[str, Any], title: str = "PulseFit AI Benchmark Report") -> str:
        """Renders standalone styled HTML benchmark report."""
        lat = metrics.get("latencies", {})
        err = metrics.get("errors", {})
        rps = metrics.get("rps", 0.0)
        total_reqs = metrics.get("total_requests", 0)
        duration = metrics.get("duration_seconds", 0.0)

        sla_pass = (lat.get("p95", 0.0) < 500.0) and (err.get("error_rate_pct", 0.0) < 2.0)
        sla_badge = "PASS" if sla_pass else "FAIL"
        badge_color = "#28a745" if sla_pass else "#dc3545"

        return f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{title}</title>
    <style>
        body {{ font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; margin: 2rem; background: #f8f9fa; color: #333; }}
        .container {{ max-width: 900px; margin: 0 auto; background: #fff; padding: 2rem; border-radius: 8px; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }}
        h1 {{ margin-top: 0; color: #1a1a1a; border-bottom: 2px solid #eaecef; padding-bottom: 0.5rem; }}
        .badge {{ display: inline-block; padding: 0.25rem 0.6rem; border-radius: 4px; color: #fff; background: {badge_color}; font-weight: bold; font-size: 0.9rem; }}
        .metric-grid {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 1rem; margin: 1.5rem 0; }}
        .card {{ background: #f1f3f5; padding: 1rem; border-radius: 6px; }}
        .card h3 {{ margin: 0 0 0.5rem 0; font-size: 0.9rem; color: #666; }}
        .card p {{ margin: 0; font-size: 1.5rem; font-weight: bold; color: #111; }}
        table {{ width: 100%; border-collapse: collapse; margin-top: 1.5rem; }}
        th, td {{ padding: 0.75rem; text-align: left; border-bottom: 1px solid #dee2e6; }}
        th {{ background: #f8f9fa; font-weight: 600; }}
    </style>
</head>
<body>
    <div class="container">
        <h1>{title} <span class="badge">SLA: {sla_badge}</span></h1>
        <p>Execution duration: {duration}s | Total Requests: {total_reqs:,}</p>

        <div class="metric-grid">
            <div class="card"><h3>Throughput (RPS)</h3><p>{rps:,.1f}</p></div>
            <div class="card"><h3>Median Latency (p50)</h3><p>{lat.get('p50', 0):.1f} ms</p></div>
            <div class="card"><h3>95th Percentile (p95)</h3><p>{lat.get('p95', 0):.1f} ms</p></div>
            <div class="card"><h3>Error Rate</h3><p>{err.get('error_rate_pct', 0):.2f}%</p></div>
        </div>

        <h2>Detailed Latency Percentiles</h2>
        <table>
            <thead><tr><th>Metric</th><th>Latency (ms)</th></tr></thead>
            <tbody>
                <tr><td>Minimum</td><td>{lat.get('min', 0):.1f}</td></tr>
                <tr><td>p50 (Median)</td><td>{lat.get('p50', 0):.1f}</td></tr>
                <tr><td>p95</td><td>{lat.get('p95', 0):.1f}</td></tr>
                <tr><td>p99</td><td>{lat.get('p99', 0):.1f}</td></tr>
                <tr><td>Maximum</td><td>{lat.get('max', 0):.1f}</td></tr>
            </tbody>
        </table>

        <h2>Error Breakdown</h2>
        <table>
            <thead><tr><th>Status Code</th><th>Count</th></tr></thead>
            <tbody>
                <tr><td>HTTP 429 (Rate Limit)</td><td>{err.get('status_429', 0)}</td></tr>
                <tr><td>HTTP 500 (Internal Server Error)</td><td>{err.get('status_500', 0)}</td></tr>
                <tr><td>HTTP 504 (Gateway Timeout)</td><td>{err.get('status_504', 0)}</td></tr>
            </tbody>
        </table>
    </div>
</body>
</html>"""

    @staticmethod
    def generate_markdown_summary(metrics: Dict[str, Any], title: str = "PulseFit AI Benchmark Summary") -> str:
        """Renders executive Markdown summary."""
        lat = metrics.get("latencies", {})
        err = metrics.get("errors", {})
        rps = metrics.get("rps", 0.0)
        total_reqs = metrics.get("total_requests", 0)
        duration = metrics.get("duration_seconds", 0.0)

        sla_pass = (lat.get("p95", 0.0) < 500.0) and (err.get("error_rate_pct", 0.0) < 2.0)
        sla_status = "PASSED" if sla_pass else "FAILED"

        return f"""# {title}

**SLA Status**: {sla_status}  
**Total Requests**: {total_reqs:,}  
**Execution Duration**: {duration}s  
**Throughput (RPS)**: {rps:,.1f}  

## Key Latency Percentiles
- **p50 (Median)**: {lat.get('p50', 0):.1f} ms
- **p95**: {lat.get('p95', 0):.1f} ms
- **p99**: {lat.get('p99', 0):.1f} ms
- **Max Latency**: {lat.get('max', 0):.1f} ms

## Error Breakdown
- **Error Rate**: {err.get('error_rate_pct', 0):.2f}%
- **HTTP 429 (Rate Limited)**: {err.get('status_429', 0)}
- **HTTP 500 (Server Error)**: {err.get('status_500', 0)}
- **HTTP 504 (Timeout)**: {err.get('status_504', 0)}
"""

    @classmethod
    def validate_html(cls, html_content: str) -> bool:
        """Verifies HTML conforms to standalone report contract."""
        required = [
            "<!DOCTYPE html>",
            "<html",
            "<head>",
            "<title>",
            "<body>",
            "p50",
            "p95",
            "p99",
            "Throughput",
            "Error",
        ]
        return all(r in html_content for r in required)

    @classmethod
    def validate_markdown(cls, md_content: str) -> bool:
        """Verifies Markdown conforms to executive summary contract."""
        required = [
            "# ",
            "SLA Status",
            "p50",
            "p95",
            "p99",
            "Error Rate",
        ]
        return all(r in md_content for r in required)
