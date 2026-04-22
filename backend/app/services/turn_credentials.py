from __future__ import annotations

import asyncio
import json
import logging
from typing import Any
from urllib.parse import urlencode
from urllib.request import Request, urlopen

from ..config import settings

logger = logging.getLogger(__name__)

# Hardcoded Metered TURN credentials — used when the dynamic API call fails.
# TURN is required for symmetric NAT (most mobile carriers); STUN-only will not work.
_METERED_TURN_ICE_SERVERS: list[dict[str, Any]] = [
    {"urls": "stun:stun.relay.metered.ca:80"},
    {
        "urls": "turn:global.relay.metered.ca:80",
        "username": "55ebcd964c2936d0dc1db8d2",
        "credential": "WIir6zhTPXOiW156",
    },
    {
        "urls": "turn:global.relay.metered.ca:80?transport=tcp",
        "username": "55ebcd964c2936d0dc1db8d2",
        "credential": "WIir6zhTPXOiW156",
    },
    {
        "urls": "turn:global.relay.metered.ca:443",
        "username": "55ebcd964c2936d0dc1db8d2",
        "credential": "WIir6zhTPXOiW156",
    },
    {
        "urls": "turns:global.relay.metered.ca:443?transport=tcp",
        "username": "55ebcd964c2936d0dc1db8d2",
        "credential": "WIir6zhTPXOiW156",
    },
]


def _default_ice_servers() -> list[dict[str, Any]]:
    fallback = settings.TURN_FALLBACK_ICE_SERVERS
    if isinstance(fallback, list) and fallback:
        return fallback
    return _METERED_TURN_ICE_SERVERS


def _fetch_json(url: str) -> Any:
    request = Request(url, headers={"Accept": "application/json"}, method="GET")
    with urlopen(request, timeout=8) as response:
        body = response.read().decode("utf-8")
    return json.loads(body)


async def fetch_turn_credentials(region: str | None = None) -> tuple[list[dict[str, Any]], str]:
    """
    Returns tuple(ice_servers, source).
    source is one of: metered, fallback
    """
    api_key = (settings.METERED_API_KEY or "").strip()
    domain = (settings.METERED_TURN_DOMAIN or "").strip()

    if not api_key or not domain:
        return _default_ice_servers(), "fallback"

    params = {"apiKey": api_key}
    chosen_region = (region or settings.TURN_REGION or "").strip()
    if chosen_region:
        params["region"] = chosen_region

    url = f"https://{domain}/api/v1/turn/credentials?{urlencode(params)}"

    try:
        data = await asyncio.to_thread(_fetch_json, url)
        if isinstance(data, list) and data:
            normalized = []
            for item in data:
                if not isinstance(item, dict):
                    continue
                if not item.get("urls"):
                    continue
                normalized.append(item)
            if normalized:
                return normalized, "metered"
    except Exception:
        logger.exception("Failed fetching TURN credentials from Metered")

    return _default_ice_servers(), "fallback"
