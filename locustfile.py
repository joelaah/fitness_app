# Re-export from staging/locust/locustfile.py
from staging.locust.locustfile import (
    PulseFitBaseUser,
    ExerciseCatalogBrowser,
    ActiveWorkoutLogger,
    AICoachRequester,
)

__all__ = [
    "PulseFitBaseUser",
    "ExerciseCatalogBrowser",
    "ActiveWorkoutLogger",
    "AICoachRequester",
]
