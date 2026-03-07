"""
Vercel entry point for Haulistry FastAPI backend.
Vercel Python runtime detects the `app` ASGI object automatically.

Push notifications are handled via Firebase Cloud Messaging (FCM).
"""

from app.main import app  # noqa: F401  — re-exported as the ASGI handler
