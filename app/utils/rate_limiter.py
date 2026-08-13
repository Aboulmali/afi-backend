"""Limiteur de débit en mémoire (anti brute-force)"""
import threading
import time
from collections import defaultdict

from fastapi import HTTPException, status


class RateLimiter:
    """Fenêtre glissante par clé (IP + email, ...)"""

    def __init__(self, max_attempts: int = 5, window_seconds: int = 300):
        self.max_attempts = max_attempts
        self.window_seconds = window_seconds
        self._hits: dict[str, list[float]] = defaultdict(list)
        self._lock = threading.Lock()

    def reset(self) -> None:
        """Vide l'historique (utile pour les tests)"""
        with self._lock:
            self._hits.clear()

    def check(self, key: str) -> None:
        """Vérifie si la clé peut faire une nouvelle tentative (sinon 429)"""
        now = time.time()
        with self._lock:
            window = [t for t in self._hits[key] if now - t < self.window_seconds]
            if len(window) >= self.max_attempts:
                self._hits[key] = window
                retry_after = int(self.window_seconds - (now - window[0]))
                raise HTTPException(
                    status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                    detail="Trop de tentatives. Réessayez plus tard.",
                    headers={"Retry-After": str(max(retry_after, 1))},
                )
            window.append(now)
            self._hits[key] = window


# 5 tentatives de login toutes les 5 minutes par IP + email
login_limiter = RateLimiter(max_attempts=5, window_seconds=300)