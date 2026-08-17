"""Cache Redis (solde et stats du dashboard) avec repli transparent.

Si Redis est indisponible (non déployé, erreur réseau), les opérations sont
des no-op : le service continue de fonctionner sans cache.
"""
import json
import logging

from app.config import settings

logger = logging.getLogger(__name__)

try:
    import redis as redis_lib

    HAS_REDIS = True
except ImportError:  # pragma: no cover
    HAS_REDIS = False

_client = None


def _get_client() -> "redis_lib.Redis | None":
    global _client
    if not HAS_REDIS or not settings.REDIS_URL:
        return None
    if _client is None:
        try:
            _client = redis_lib.from_url(
                settings.REDIS_URL,
                socket_connect_timeout=2,
                socket_timeout=2,
                decode_responses=True,
            )
            _client.ping()
        except Exception:
            logger.warning("Redis indisponible, cache desactive")
            _client = None
    return _client


def _key(user_id: int, name: str) -> str:
    return f"afi:dashboard:{user_id}:{name}"


def get(user_id: int, name: str):
    """Renvoie la valeur JSON mise en cache ou None."""
    client = _get_client()
    if client is None:
        return None
    try:
        raw = client.get(_key(user_id, name))
        return json.loads(raw) if raw else None
    except Exception:
        return None


def set_cache(user_id: int, name: str, value, ttl: int = 60) -> None:
    client = _get_client()
    if client is None:
        return
    try:
        client.set(_key(user_id, name), json.dumps(value), ex=ttl)
    except Exception:
        pass


def invalidate(user_id: int, name: str) -> None:
    client = _get_client()
    if client is None:
        return
    try:
        client.delete(_key(user_id, name))
    except Exception:
        pass