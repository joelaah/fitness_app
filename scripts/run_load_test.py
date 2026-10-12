#!/usr/bin/env python3
"""
PulseFit AI - Automated Load & Stress Test Runner
=================================================
Automates end-to-end load testing:
1. Verifies/boots staging server (mock Supabase on port 54321).
2. Seeds staging catalog & historical data if required.
3. Launches Locust in headless mode with configurable users & spawn rate.
4. Generates HTML, CSV, and Markdown performance benchmark reports.
"""

import argparse
import os
import subprocess
import sys
import time
import urllib.request
import json
from datetime import datetime

# Ensure utf-8 stdout on Windows
if sys.platform == "win32":
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")



DEFAULT_HOST = "http://127.0.0.1:54321"
REPORTS_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "reports")


def is_server_healthy(host: str) -> bool:
    """Checks if the target server is alive and responding."""
    try:
        url = f"{host.rstrip('/')}/mock/stats"
        req = urllib.request.Request(url, headers={"User-Agent": "PulseFitLoadRunner/1.0"})
        with urllib.request.urlopen(req, timeout=2.0) as resp:
            return resp.status in (200, 204)
    except Exception:
        # Check basic health fallback
        try:
            url = f"{host.rstrip('/')}/health"
            req = urllib.request.Request(url, headers={"User-Agent": "PulseFitLoadRunner/1.0"})
            with urllib.request.urlopen(req, timeout=2.0) as resp:
                return resp.status in (200, 204)
        except Exception:
            return False


def start_local_mock_server() -> subprocess.Popen:
    """Starts local mock Supabase server in a background process."""
    print("⏳ Booting local mock staging server on port 54321...")
    server_script = os.path.join(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
        "staging",
        "mock_supabase_server.py"
    )
    proc = subprocess.Popen(
        [sys.executable, server_script, "--port", "54321"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL
    )
    # Wait for server to become healthy
    for _ in range(25):
        if is_server_healthy(DEFAULT_HOST):
            print("✅ Staging server is healthy and responding.")
            return proc
        time.sleep(0.3)
    print("⚠️ Staging server startup timed out, proceeding anyway...")
    return proc


def seed_staging_database():
    """Runs database seed script."""
    print("🌱 Populating staging database with exercise catalog & test cohorts...")
    seed_script = os.path.join(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
        "scripts",
        "seed_staging.py"
    )
    subprocess.run([sys.executable, seed_script, "--users", "10", "--sessions", "3"], check=False)


def run_locust_benchmark(users: int, spawn_rate: int, run_time: str, host: str, tag: str = None) -> str:
    """Runs Locust in headless mode and records metrics."""
    os.makedirs(REPORTS_DIR, exist_ok=True)
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    prefix = f"loadtest_{timestamp}_u{users}"
    html_path = os.path.join(REPORTS_DIR, f"{prefix}.html")
    csv_prefix = os.path.join(REPORTS_DIR, prefix)

    locustfile_path = os.path.join(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
        "staging",
        "locust",
        "locustfile.py"
    )

    cmd = [
        sys.executable, "-m", "locust",
        "-f", locustfile_path,
        "--headless",
        "--users", str(users),
        "--spawn-rate", str(spawn_rate),
        "--run-time", run_time,
        "--host", host,
        "--html", html_path,
        "--csv", csv_prefix,
        "--only-summary"
    ]
    if tag:
        cmd.extend(["--tags", tag])

    print(f"\n🚀 Launching Locust load test: {users} users @ {spawn_rate}/s for {run_time} against {host}...")
    start_time = time.time()
    result = subprocess.run(cmd)
    elapsed = time.time() - start_time

    # Generate Markdown Summary Report
    stats_csv = f"{csv_prefix}_stats.csv"
    md_report_path = os.path.join(REPORTS_DIR, f"{prefix}_summary.md")
    generate_markdown_report(md_report_path, stats_csv, users, spawn_rate, run_time, host, elapsed)

    print(f"\n📊 Benchmark Complete in {elapsed:.1f}s!")
    print(f"📄 HTML Report: {html_path}")
    print(f"📝 Markdown Summary: {md_report_path}")
    return md_report_path


def generate_markdown_report(md_path: str, csv_path: str, users: int, spawn_rate: int, run_time: str, host: str, elapsed: float):
    """Parses Locust CSV stats and compiles a markdown executive report."""
    rows = []
    if os.path.exists(csv_path):
        import csv
        with open(csv_path, "r", encoding="utf-8") as f:
            reader = csv.DictReader(f)
            for row in reader:
                rows.append(row)

    total_reqs = 0
    total_fails = 0
    avg_rps = 0.0

    table_rows = []
    for r in rows:
        name = r.get("Name", "Total")
        reqs = int(r.get("Request Count", 0))
        fails = int(r.get("Failure Count", 0))
        med = r.get("Median Response Time", "0")
        p95 = r.get("95%", "0")
        p99 = r.get("99%", "0")
        rps = float(r.get("Requests/s", 0.0))

        if name == "Aggregated":
            total_reqs = reqs
            total_fails = fails
            avg_rps = rps
        else:
            table_rows.append(f"| `{name}` | {reqs} | {fails} | {med}ms | {p95}ms | {p99}ms | {rps:.1f} |")

    fail_rate = (total_fails / total_reqs * 100) if total_reqs > 0 else 0.0

    content = f"""# 🏋️ PulseFit AI — Load & Stress Test Benchmark Report

> **Execution Time:** {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}  
> **Target Host:** `{host}`  
> **Virtual Users:** `{users}`  
> **Spawn Rate:** `{spawn_rate} users/sec`  
> **Duration:** `{run_time}`  

---

## 📈 Executive Summary

| Metric | Measured Value | Health Indicator |
|---|---|---|
| **Total Requests** | {total_reqs:,} | {'✅ Passed' if total_reqs > 0 else '⚠️ Empty'} |
| **Failed Requests** | {total_fails:,} ({fail_rate:.2f}%) | {'✅ Optimal (<1%)' if fail_rate < 1.0 else '⚠️ High Failures'} |
| **Throughput (RPS)** | {avg_rps:.1f} req/s | {'⚡ High Performance' if avg_rps > 100 else 'Normal'} |
| **Simulated Concurrency** | {users} concurrent personas | {'🔥 Extreme Stress' if users >= 500 else 'Target Load'} |

---

## 🔬 Detailed Endpoint Latency & Failure Breakdown

| Endpoint / Action | Requests | Failures | Median | p95 | p99 | Req/s |
|---|---|---|---|---|---|---|
{chr(10).join(table_rows) if table_rows else "| *No individual rows captured* | - | - | - | - | - | - |"}

---

## 🎯 Findings & Stability Assessment
- **Concurrency Resilience**: Under `{users}` simulated users, the server handled `{total_reqs:,}` requests with an overall error rate of `{fail_rate:.2f}%`.
- **Latency Distribution**: Check HTML report for the full percentiles curve and response distribution charts.
"""
    with open(md_path, "w", encoding="utf-8") as f:
        f.write(content)


def main():
    parser = argparse.ArgumentParser(description="PulseFit AI Load & Stress Test Automator")
    parser.add_argument("--users", type=int, default=50, help="Number of concurrent virtual users (default: 50)")
    parser.add_argument("--spawn-rate", type=int, default=10, help="User ramp-up rate per second (default: 10)")
    parser.add_argument("--run-time", default="20s", help="Duration of test e.g. 30s, 2m, 5m (default: 20s)")
    parser.add_argument("--host", default=DEFAULT_HOST, help=f"Target URL (default: {DEFAULT_HOST})")
    parser.add_argument("--seed", action="store_true", help="Seed database before running benchmark")
    parser.add_argument("--stress", action="store_true", help="Run heavy stress test profile (500 users, 50 spawn-rate)")
    parser.add_argument("--extreme", action="store_true", help="Run extreme stress test profile (1000 users, 100 spawn-rate)")
    args = parser.parse_args()

    if args.extreme:
        args.users = 1000
        args.spawn_rate = 100
        if args.run_time == "20s":
            args.run_time = "45s"
    elif args.stress:
        args.users = 500
        args.spawn_rate = 50
        if args.run_time == "20s":
            args.run_time = "30s"

    server_proc = None
    try:
        # Check if local host needs to be booted
        if "127.0.0.1" in args.host or "localhost" in args.host:
            if not is_server_healthy(args.host):
                server_proc = start_local_mock_server()

        if args.seed:
            seed_staging_database()

        # Execute Locust test
        run_locust_benchmark(
            users=args.users,
            spawn_rate=args.spawn_rate,
            run_time=args.run_time,
            host=args.host
        )

    finally:
        if server_proc:
            print("🛑 Stopping background staging server...")
            server_proc.terminate()
            server_proc.wait()


if __name__ == "__main__":
    main()
