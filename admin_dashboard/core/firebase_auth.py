"""
Firebase Admin SDK wrapper for admin user auth.
- Signup  → firebase_admin.auth.create_user()  (stores in Firebase Auth)
- Login   → Firebase REST signInWithPassword API (verifies password server-side)
- Profile → stored in Neo4j AdminUser node alongside Firebase UID
"""

from __future__ import annotations

import httpx
from pathlib import Path
from typing import Optional

# ── Lazy Firebase init ────────────────────────────────────────────────────────

def _get_app():
    import firebase_admin
    from firebase_admin import credentials

    if firebase_admin._apps:
        return firebase_admin.get_app()

    from .config import settings

    raw = settings.firebase_credentials_path
    cred_path = Path(raw) if Path(raw).is_absolute() else (
        Path(__file__).resolve().parents[2] / "backend" / raw.lstrip("./\\")
    )

    if not cred_path.exists():
        return None

    try:
        cred = credentials.Certificate(str(cred_path))
        return firebase_admin.initialize_app(cred)
    except Exception:
        return None


# ── Public helpers ────────────────────────────────────────────────────────────

def create_firebase_user(email: str, password: str, display_name: str) -> Optional[str]:
    """Create a Firebase Auth user. Returns UID on success, None on failure."""
    app = _get_app()
    if app is None:
        return None
    from firebase_admin import auth as fb_auth
    try:
        user = fb_auth.create_user(
            email=email,
            password=password,
            display_name=display_name,
            email_verified=False,
        )
        return user.uid
    except fb_auth.EmailAlreadyExistsError:
        raise ValueError("An account with this email already exists in Firebase.")
    except Exception as e:
        raise ValueError(f"Firebase signup error: {e}")


def sign_in_with_firebase(email: str, password: str) -> Optional[dict]:
    """
    Verify email+password against Firebase Auth REST API.
    Returns the Firebase response dict (contains localId/uid, idToken) or None.
    Raises ValueError with a user-friendly message on auth failure.
    """
    from .config import settings

    api_key = settings.firebase_web_api_key
    if not api_key or api_key.startswith("AIzaSyYOUR"):
        return None  # Firebase not configured — caller falls back to bcrypt

    url = (
        "https://identitytoolkit.googleapis.com/v1/"
        f"accounts:signInWithPassword?key={api_key}"
    )
    try:
        r = httpx.post(
            url,
            json={"email": email, "password": password, "returnSecureToken": True},
            timeout=10.0,
        )
        if r.status_code == 200:
            return r.json()
        data = r.json()
        msg = data.get("error", {}).get("message", "UNKNOWN")
        if msg in ("EMAIL_NOT_FOUND", "INVALID_PASSWORD", "INVALID_LOGIN_CREDENTIALS"):
            raise ValueError("Invalid credentials.")
        if msg == "USER_DISABLED":
            raise ValueError("This account has been disabled.")
        raise ValueError(f"Firebase auth error: {msg}")
    except httpx.RequestError as e:
        raise ValueError(f"Cannot reach Firebase: {e}")


def get_firebase_user_by_email(email: str) -> Optional[object]:
    """Return Firebase UserRecord or None."""
    app = _get_app()
    if app is None:
        return None
    from firebase_admin import auth as fb_auth
    try:
        return fb_auth.get_user_by_email(email)
    except fb_auth.UserNotFoundError:
        return None
    except Exception:
        return None


def get_firebase_user_by_uid(uid: str) -> Optional[object]:
    app = _get_app()
    if app is None:
        return None
    from firebase_admin import auth as fb_auth
    try:
        return fb_auth.get_user(uid)
    except Exception:
        return None


def delete_firebase_user(uid: str) -> bool:
    app = _get_app()
    if app is None:
        return False
    from firebase_admin import auth as fb_auth
    try:
        fb_auth.delete_user(uid)
        return True
    except Exception:
        return False


def update_firebase_password(uid: str, new_password: str) -> bool:
    app = _get_app()
    if app is None:
        return False
    from firebase_admin import auth as fb_auth
    try:
        fb_auth.update_user(uid, password=new_password)
        return True
    except Exception:
        return False


def firebase_configured() -> bool:
    """True if Firebase Web API Key is set (sign-in flow is active)."""
    from .config import settings
    k = settings.firebase_web_api_key
    return bool(k) and not k.startswith("AIzaSyYOUR")
