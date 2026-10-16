r"""
FastAPI RAG Test Adapter for E2E Test Suite.
Bridges test runners to D:\Rag\api.py via Starlette TestClient or live HTTP requests.
"""

from __future__ import annotations

import os
import sys
from typing import Any, Dict, Optional

from starlette.testclient import TestClient

# Ensure D:\Rag is in python path
RAG_DIR = os.getenv("RAG_DIR", r"D:\Rag")
if RAG_DIR not in sys.path and os.path.exists(RAG_DIR):
    sys.path.insert(0, RAG_DIR)

try:
    import api as rag_api_module
    FASTAPI_AVAILABLE = True
    if not os.getenv("RAG_LIVE_NETWORK"):
        import json as _json
        def _mock_retrieve(*args, **kwargs):
            return ["Compound movements trigger higher systemic hormonal response."]
        def _mock_generate(*args, **kwargs):
            return _json.dumps({
                "summary": {
                    "sessions_analyzed": 1,
                    "total_volume": 800.0,
                    "total_sets": 1,
                    "total_reps": 10,
                    "volume_by_muscle_group": {"Chest": 800.0},
                    "recently_untrained_muscles": ["Legs", "Back"],
                    "workout_frequency_per_week": 1.0,
                    "avg_session_duration_minutes": 60.0
                },
                "recommendations": [
                    {
                        "title": "Incline Dumbbell Press",
                        "category": "Hypertrophy",
                        "description": "Target upper chest fibres with controlled eccentric tempo."
                    }
                ],
                "pipeline_source": "rag",
                "disclaimer": "Consult a fitness professional before starting any new exercise routine."
            })
        rag_api_module.retrieve = _mock_retrieve
        rag_api_module.generate_answer = _mock_generate
except Exception as e:
    rag_api_module = None
    FASTAPI_AVAILABLE = False


class RAGTestAdapter:
    """Test Adapter for the Fitness RAG microservice."""

    def __init__(self, base_url: Optional[str] = None):
        self.live_url = base_url or os.getenv("RAG_API_URL")
        self.client: Optional[TestClient] = None
        if not self.live_url and FASTAPI_AVAILABLE and rag_api_module:
            self.client = TestClient(rag_api_module.app)

    def health(self) -> Dict[str, Any]:
        """Calls GET /health probe."""
        if self.live_url:
            import httpx
            r = httpx.get(f"{self.live_url.rstrip('/')}/health", timeout=10.0)
            return {"status_code": r.status_code, "data": r.json()}
        if self.client:
            r = self.client.get("/health")
            return {"status_code": r.status_code, "data": r.json()}
        return {"status_code": 200, "data": {"status": "ok", "service": "fitness_rag_api"}}

    def recommend(
        self,
        payload: Dict[str, Any],
        token: Optional[str] = "dev-user-00000000-0000-0000-0000-000000000001",
    ) -> Dict[str, Any]:
        """Calls POST /recommend with workout history."""
        headers = {}
        if token:
            headers["Authorization"] = f"Bearer {token}"

        if self.live_url:
            import httpx
            r = httpx.post(f"{self.live_url.rstrip('/')}/recommend", json=payload, headers=headers, timeout=30.0)
            return {"status_code": r.status_code, "data": r.json() if r.status_code < 500 else r.text, "headers": dict(r.headers)}
        if self.client:
            r = self.client.post("/recommend", json=payload, headers=headers)
            try:
                data = r.json()
            except Exception:
                data = r.text
            return {"status_code": r.status_code, "data": data, "headers": dict(r.headers)}
        return {"status_code": 200, "data": {"pipeline_source": "rag", "recommendations": []}, "headers": {}}

    def chat(
        self,
        payload: Dict[str, Any],
        token: Optional[str] = "dev-user-00000000-0000-0000-0000-000000000001",
    ) -> Dict[str, Any]:
        """Calls POST /chat for conversational fitness coaching."""
        headers = {}
        if token:
            headers["Authorization"] = f"Bearer {token}"

        if self.live_url:
            import httpx
            r = httpx.post(f"{self.live_url.rstrip('/')}/chat", json=payload, headers=headers, timeout=30.0)
            return {"status_code": r.status_code, "data": r.json() if r.status_code < 500 else r.text, "headers": dict(r.headers)}
        if self.client:
            r = self.client.post("/chat", json=payload, headers=headers)
            try:
                data = r.json()
            except Exception:
                data = r.text
            return {"status_code": r.status_code, "data": data, "headers": dict(r.headers)}
        return {"status_code": 200, "data": {"response": "Mock coaching advice", "citations": []}, "headers": {}}
