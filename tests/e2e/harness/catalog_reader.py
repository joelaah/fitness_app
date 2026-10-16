r"""
Exercise Catalog Reader & Validator for Feature F2.
Reads and inspects D:\fitness_app\assets\data\exercises.json.
"""

from __future__ import annotations

import json
import os
from typing import Any, Dict, List, Optional

EXERCISES_PATH = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))),
    "assets",
    "data",
    "exercises.json",
)


class ExerciseCatalogReader:
    """Loads and validates the 1,300+ exercise dataset."""

    def __init__(self, path: Optional[str] = None):
        self.path = path or EXERCISES_PATH
        self._data: Optional[List[Dict[str, Any]]] = None

    def load(self) -> List[Dict[str, Any]]:
        if self._data is None:
            if not os.path.exists(self.path):
                # Fallback to empty if path doesn't exist
                return []
            with open(self.path, "r", encoding="utf-8") as f:
                self._data = json.load(f)
        return self._data

    def get_count(self) -> int:
        return len(self.load())

    def filter_by_muscle(self, muscle: str) -> List[Dict[str, Any]]:
        return [
            e for e in self.load()
            if str(e.get("body_part", "")).lower() == muscle.lower()
            or str(e.get("category", "")).lower() == muscle.lower()
        ]

    def validate_schema(self, exercise: Dict[str, Any]) -> bool:
        required = ["id", "name", "category", "body_part", "equipment"]
        return all(k in exercise for k in required)
