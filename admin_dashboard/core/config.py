"""
Central configuration — reads from environment variables.
All secrets are loaded here; never hard-coded elsewhere.
"""

import os
from pathlib import Path
from dataclasses import dataclass, field
from dotenv import load_dotenv

# Load from backend/.env (shared with FastAPI backend).
# Falls back to a local .env if one exists alongside app.py.
_backend_env = Path(__file__).resolve().parents[2] / "backend" / ".env"
_local_env   = Path(__file__).resolve().parents[2] / "admin_dashboard" / ".env"
load_dotenv(_backend_env, override=False)
load_dotenv(_local_env, override=True)  # local overrides win if present


@dataclass
class Settings:
    # ── Admin credentials ───────────────────────────────────────────────────
    admin_username: str = field(
        default_factory=lambda: os.getenv("ADMIN_USERNAME", "admin")
    )
    admin_password_hash: str = field(
        default_factory=lambda: os.getenv(
            "ADMIN_PASSWORD_HASH",
            # Default bcrypt hash of "admin123" — CHANGE IN PRODUCTION
            "$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeG6Lruj3vjPGga31lW",
        )
    )

    # ── Neo4j ────────────────────────────────────────────────────────────────
    neo4j_uri: str = field(
        default_factory=lambda: os.getenv("NEO4J_URI", "bolt://localhost:7687")
    )
    neo4j_username: str = field(
        default_factory=lambda: os.getenv("NEO4J_USERNAME", "neo4j")
    )
    neo4j_password: str = field(
        default_factory=lambda: os.getenv("NEO4J_PASSWORD", "")
    )
    neo4j_database: str = field(
        default_factory=lambda: os.getenv("NEO4J_DATABASE", "neo4j")
    )

    # ── Backend REST API ─────────────────────────────────────────────────────
    backend_url: str = field(
        default_factory=lambda: os.getenv(
            "BACKEND_URL", "http://localhost:4000"
        )
    )

    # ── App branding ─────────────────────────────────────────────────────────
    app_name: str = "Haulistry Admin"
    app_version: str = "1.0.0"

    # ── Session ──────────────────────────────────────────────────────────────
    session_timeout_minutes: int = field(
        default_factory=lambda: int(os.getenv("SESSION_TIMEOUT_MINUTES", "120"))
    )

    # ── Firebase ─────────────────────────────────────────────────────────────
    firebase_credentials_path: str = field(
        default_factory=lambda: os.getenv(
            "FIREBASE_CREDENTIALS_PATH",
            "./haulistry-1b835-firebase-adminsdk-fbsvc-6f46165767.json",
        )
    )
    firebase_web_api_key: str = field(
        default_factory=lambda: os.getenv("FIREBASE_WEB_API_KEY", "")
    )

    # ── Admin signup setup code (required to register new admin accounts) ────
    admin_setup_code: str = field(
        default_factory=lambda: os.getenv("ADMIN_SETUP_CODE", "haulistry-setup-2025")
    )

    # ── Pagination ───────────────────────────────────────────────────────────
    default_page_size: int = 50


settings = Settings()
