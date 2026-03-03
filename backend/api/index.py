"""
Vercel entry point for Haulistry FastAPI backend.
Vercel Python runtime detects the `app` ASGI object automatically.

NOTE: WebSocket endpoint (/ws/{user_id}) is NOT supported on Vercel's
serverless infrastructure. All REST API and GraphQL routes work normally.
"""

from app.main import app  # noqa: F401  — re-exported as the ASGI handler
