"""Logging structuré JSON + corrélation par identifiant de requête"""
import json
import logging
import time
import uuid

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request


class JsonFormatter(logging.Formatter):
    """Formatteur produisant une ligne JSON par événement de log"""

    def format(self, record: logging.LogRecord) -> str:
        entry = {
            "timestamp": self.formatTime(record, "%Y-%m-%dT%H:%M:%S"),
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
        }
        if hasattr(record, "request_id"):
            entry["request_id"] = record.request_id
        if record.exc_info:
            entry["exception"] = self.formatException(record.exc_info)
        return json.dumps(entry, ensure_ascii=False)


def setup_logging() -> None:
    root = logging.getLogger()
    root.setLevel(logging.INFO)
    handler = logging.StreamHandler()
    handler.setFormatter(JsonFormatter())
    root.handlers = [handler]


class RequestIdMiddleware(BaseHTTPMiddleware):
    """Ajoute un X-Request-ID et le propage dans les logs"""

    async def dispatch(self, request: Request, call_next):
        request_id = request.headers.get("X-Request-ID") or uuid.uuid4().hex[:12]
        start = time.perf_counter()
        try:
            response = await call_next(request)
        finally:
            duration_ms = (time.perf_counter() - start) * 1000
            logger = logging.getLogger("access")
            logger.info(
                "%s %s -> %s (%.1f ms)",
                request.method,
                request.url.path,
                getattr(response, "status_code", 0),
                duration_ms,
                extra={"request_id": request_id},
            )
        response.headers["X-Request-ID"] = request_id
        return response