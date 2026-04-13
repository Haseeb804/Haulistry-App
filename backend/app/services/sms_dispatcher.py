"""
SMS dispatcher service.

Supports free/self-hosted Android phone gateway integration so OTP can be
sent to SIM inbox without paid providers.
"""

from __future__ import annotations

import json
import logging
from typing import Tuple
from urllib import request, error

from ..config import settings

logger = logging.getLogger(__name__)


def send_sms(phone: str, message: str) -> Tuple[bool, str]:
    """
    Send SMS through configured provider mode.

    Returns:
        (success, detail)
    """
    mode = (settings.OTP_DELIVERY_MODE or "debug").strip().lower()

    if mode == "debug":
        logger.info(f"[SMS DEBUG MODE] phone={phone} message={message}")
        return False, "debug mode enabled"

    if mode == "android_gateway":
        return _send_via_android_gateway(phone=phone, message=message)

    return False, f"unsupported OTP_DELIVERY_MODE: {mode}"


def _send_via_android_gateway(phone: str, message: str) -> Tuple[bool, str]:
    gateway_url = (settings.ANDROID_SMS_GATEWAY_URL or "").strip()
    if not gateway_url:
        return False, "ANDROID_SMS_GATEWAY_URL is not configured"

    payload = {
        "phone": phone,
        "message": message,
    }

    headers = {
        "Content-Type": "application/json",
    }

    api_key = (settings.ANDROID_SMS_GATEWAY_API_KEY or "").strip()
    auth_header = (settings.ANDROID_SMS_GATEWAY_AUTH_HEADER or "X-API-KEY").strip()
    if api_key:
        headers[auth_header] = api_key

    req = request.Request(
        url=gateway_url,
        data=json.dumps(payload).encode("utf-8"),
        headers=headers,
        method="POST",
    )

    try:
        with request.urlopen(req, timeout=settings.SMS_HTTP_TIMEOUT_SECONDS) as resp:
            body = resp.read().decode("utf-8") if resp else ""
            if 200 <= resp.status < 300:
                return True, body or "sms sent"
            return False, f"gateway returned HTTP {resp.status}: {body}"
    except error.HTTPError as exc:
        body = exc.read().decode("utf-8") if exc.fp else ""
        return False, f"gateway HTTPError {exc.code}: {body}"
    except Exception as exc:
        return False, f"gateway request failed: {exc}"
