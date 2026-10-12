# PulseFit AI Staging Environment Guide

This directory houses the staging infrastructure, container configurations, local mock server, and operational runbooks for PulseFit AI.

---

## 1. Architecture & Port Mapping

PulseFit AI supports two primary staging modes:
1. **Containerized Deployment (Docker Compose)**: Multi-container orchestration incorporating the FastAPI RAG backend, PostgreSQL 15, PostgREST, and the local Mock Supabase service.
2. **Native Local Python Processes**: Lightweight zero-container workflow running directly on Windows host via Python (`mock_supabase_server.py` and `uvicorn api:app`).

| Service | Host Port | Internal Port | Description |
|---|---|---|---|
| **RAG Backend API** | `8000` | `8000` | FastAPI service (`api.py`) exposing `/health`, `/recommend`, `/chat` |
| **Mock Supabase Server** | `54321` | `54321` | Emulates GoTrue Auth (`/auth/v1/*`) and PostgREST table APIs with RLS |
| **PostgreSQL 15** | `5432` | `5432` | Relational database preloaded with `01-auth-schema.sql` and `supabase_schema.sql` |
| **PostgREST** | `8080` | `3000` | Direct REST adapter over PostgreSQL |

---

## 2. Mode 1: Docker Compose Quickstart

*Prerequisite: Docker Desktop or Docker Engine installed and running.*

### Step 1: Copy Environment Configuration
```powershell
cp staging\.env.staging.example staging\.env.staging
```

### Step 2: Start Containers in Background
```powershell
docker compose -f staging\docker-compose.staging.yml --env-file staging\.env.staging up -d
```

### Step 3: Verify Container Health
```powershell
docker compose -f staging\docker-compose.staging.yml ps
```
All services (`pulsefit-backend-staging`, `pulsefit-mock-supabase-staging`, `pulsefit-postgres-staging`) will report `healthy`.

### Step 4: Seed Staging Data
```powershell
python scripts\seed_staging.py --target http://localhost:54321 --users 50 --workouts-per-user 10
```

### Step 5: Teardown
```powershell
# Stop and remove containers
docker compose -f staging\docker-compose.staging.yml down

# Stop and wipe persistent PostgreSQL volume
docker compose -f staging\docker-compose.staging.yml down -v
```

---

## 3. Mode 2: Native Local Python Processes (Windows Host without Docker)

*Use this workflow when Docker or WSL is not installed.*

### Prerequisites
Verify Python 3.12 is in your PATH:
```powershell
python --version
```

Install required Python dependencies:
```powershell
pip install fastapi uvicorn pydantic pyjwt requests
```

### Step 1: Launch Local Mock Supabase Server (Terminal 1)
```powershell
python staging\mock_supabase_server.py --port 54321
```
*Output: `Starting PulseFit Mock Supabase Server on http://0.0.0.0:54321`*

### Step 2: Launch RAG Backend (Terminal 2)
```powershell
cd D:\Rag
$env:PORT="8000"
$env:SUPABASE_URL="http://localhost:54321"
$env:SUPABASE_ANON_KEY="mock-anon-key"
$env:SUPABASE_SERVICE_ROLE_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.mock_service_role"
$env:MOCK_LLM_FOR_STRESS_TEST="true"

uvicorn api:app --host 127.0.0.1 --port 8000
```
*Output: `Uvicorn running on http://127.0.0.1:8000`*

### Step 3: Seed Staging Database (Terminal 3)
```powershell
cd D:\fitness_app
python scripts\seed_staging.py --target local --users 50 --workouts-per-user 10
```
This populates:
- 50 synthetic user profiles across 5 distinct archetypes (Powerlifter, Hypertrophy, Beginner, Endurance, Recomp).
- 500 historical workout sessions with realistic progressive overload and fatigue.
- `staging/seeded_users.json` containing credentials, dev tokens (`dev-user-*`), and JWT tokens for load testing.

---

## 4. Mode 3: Remote Cloud Staging

To run against remote cloud staging instances (e.g. Supabase Cloud and Render):
1. In `staging/.env.staging`, configure:
   ```bash
   STAGING_TARGET=remote
   SUPABASE_URL=https://<your-project>.supabase.co
   SUPABASE_ANON_KEY=<your-remote-anon-key>
   SUPABASE_SERVICE_ROLE_KEY=<your-remote-service-role-key>
   RAG_API_URL=https://fitness-rag-api-staging.onrender.com
   ```
2. Run database seed pipeline against remote target:
   ```powershell
   python scripts\seed_staging.py --target https://<your-project>.supabase.co --users 20
   ```

---

## 5. Healthcheck & Verification Commands

Verify operational status of all services:

```powershell
# 1. Mock Supabase Server Health & Table Counts
curl http://localhost:54321/health

# 2. RAG Microservice Health
curl http://localhost:8000/health

# 3. Test Dev-Token Auth on RAG API
curl -H "Authorization: Bearer dev-user-test-01" -H "Content-Type: application/json" -d '{"force_refresh": true, "recent_sessions": []}' http://localhost:8000/recommend

# 4. Verify PostgREST Table Query with RLS Bypass (Service Role)
curl -H "apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.mock_service_role" "http://localhost:54321/rest/v1/workout_sessions?limit=5"
```

---

## 6. Troubleshooting Guide

| Symptom | Root Cause | Resolution |
|---|---|---|
| `Port 8000 or 54321 already in use` | Background process still active | Run `Get-Process python \| Stop-Process` in PowerShell |
| `HTTP 403 Forbidden: 42501` on insert | Cross-tenant RLS policy triggered | Ensure row `user_id` matches the authenticated caller token |
| `HTTP 429 Too Many Requests` during stress tests | Hitting Google Gemini / Cohere limits | Set `MOCK_LLM_FOR_STRESS_TEST=true` in `.env.staging` |
| `relation "auth.users" does not exist` in Postgres | Database initialized without auth schema | Ensure `staging/init-db/01-auth-schema.sql` runs before `supabase_schema.sql` |
| `Missing Authorization header with Bearer token` | Calling `/recommend` or `/chat` without token | Include `Authorization: Bearer dev-user-<uuid>` or valid GoTrue JWT |
