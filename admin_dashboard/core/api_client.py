"""
REST API client for operations that go through the existing FastAPI backend.
All errors are silently swallowed — never surfaced raw to the UI.
"""

import httpx
from typing import Any
from .config import settings

_TIMEOUT = 15.0


def _client() -> httpx.Client:
    return httpx.Client(base_url=settings.backend_url, timeout=_TIMEOUT)


def _get(path: str, params: dict | None = None) -> dict | list | None:
    try:
        with _client() as c:
            r = c.get(path, params=params)
            r.raise_for_status()
            return r.json()
    except Exception:
        return None


def _post(path: str, payload: dict) -> dict | None:
    try:
        with _client() as c:
            r = c.post(path, json=payload)
            r.raise_for_status()
            return r.json()
    except Exception:
        return None


def _put(path: str, payload: dict | None = None) -> dict | None:
    try:
        with _client() as c:
            r = c.put(path, json=payload or {})
            r.raise_for_status()
            return r.json()
    except Exception:
        return None


def _delete(path: str) -> bool:
    try:
        with _client() as c:
            r = c.delete(path)
            r.raise_for_status()
            return True
    except Exception:
        return False


# ── Public helpers ────────────────────────────────────────────────────────────

def health_check() -> bool:
    return _get("/health") is not None


def get_available_services(category: str | None = None) -> list[dict]:
    params = {}
    if category:
        params["category"] = category
    result = _get("/api/services", params=params)
    if isinstance(result, dict):
        return result.get("services", [])
    return result or []


def get_provider_services(provider_id: str) -> list[dict]:
    result = _get(f"/api/services/provider/{provider_id}")
    if isinstance(result, dict):
        return result.get("services", [])
    return result or []


def update_service(service_id: str, updates: dict) -> dict | None:
    return _put(f"/api/services/{service_id}", updates)


def delete_service(service_id: str) -> bool:
    return _delete(f"/api/services/{service_id}")


def get_booking(booking_id: str) -> dict | None:
    result = _get(f"/api/bookings/{booking_id}")
    if isinstance(result, dict):
        return result.get("booking", result)
    return None


def cancel_booking(booking_id: str, reason: str = "Admin action") -> dict | None:
    return _put(f"/api/bookings/{booking_id}/cancel", {"reason": reason})


def get_seeker_bookings(seeker_id: str) -> list[dict]:
    result = _get(f"/api/bookings/seeker/{seeker_id}")
    if isinstance(result, dict):
        return result.get("bookings", [])
    return result or []


def get_provider_bookings(provider_id: str) -> list[dict]:
    result = _get(f"/api/bookings/provider/{provider_id}")
    if isinstance(result, dict):
        return result.get("bookings", [])
    return result or []


def get_provider_feedback(provider_id: str) -> list[dict]:
    result = _get(f"/api/feedback/provider/{provider_id}")
    if isinstance(result, dict):
        return result.get("feedback", [])
    return result or []


def get_seeker_feedback(seeker_id: str) -> list[dict]:
    result = _get(f"/api/feedback/seeker/{seeker_id}")
    if isinstance(result, dict):
        return result.get("feedback", [])
    return result or []
