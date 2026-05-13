"""
Admin authentication.

Sign-up flow:
  1. Create user in Firebase Auth  (password stored in Firebase)
  2. Create AdminUser node in Neo4j Aura  (profile + Firebase UID + bcrypt hash)

Sign-in flow (when Firebase Web API Key is configured):
  1. Resolve email from username via Neo4j
  2. Verify password against Firebase Auth REST API
  3. Check isActive flag in Neo4j before granting access

Sign-in flow (fallback — no Web API Key yet):
  Uses bcrypt hash stored in Neo4j (backward compatible).
"""

import streamlit as st
import bcrypt
from datetime import datetime, timedelta
from .config import settings


# ── Password helpers ──────────────────────────────────────────────────────────

def _hash_password(plain: str) -> str:
    return bcrypt.hashpw(plain.encode(), bcrypt.gensalt(rounds=12)).decode()


def _check_password(plain: str, hashed: str) -> bool:
    try:
        return bcrypt.checkpw(plain.encode(), hashed.encode())
    except Exception:
        return False


# ── Session helpers ───────────────────────────────────────────────────────────

def is_authenticated() -> bool:
    if not st.session_state.get("authenticated"):
        return False
    if "login_time" not in st.session_state:
        return False
    if datetime.now() - st.session_state.login_time > timedelta(
        minutes=settings.session_timeout_minutes
    ):
        logout()
        return False
    return True


def logout():
    for key in ["authenticated", "login_time", "admin_user", "admin_email"]:
        st.session_state.pop(key, None)


def _do_login(username: str, email: str = ""):
    st.session_state.authenticated = True
    st.session_state.login_time    = datetime.now()
    st.session_state.admin_user    = username
    st.session_state.admin_email   = email


# ── Core auth logic ───────────────────────────────────────────────────────────

def _try_login(identifier: str, password: str) -> tuple[bool, str]:
    """
    Accepts username OR email. Checks Firebase first, bcrypt fallback, then env superadmin.
    """
    from .database import get_admin_user, get_admin_user_by_email
    from .firebase_auth import sign_in_with_firebase, firebase_configured

    identifier = identifier.strip()

    # ── 1. Find the admin record — try username first, then email ─────────────
    db_admin = (
        get_admin_user_by_email(identifier.lower())
        if "@" in identifier
        else get_admin_user(identifier)
    )
    # If not found by username, also try treating it as email (no @, but maybe stored differently)
    if not db_admin and "@" not in identifier:
        db_admin = get_admin_user_by_email(identifier.lower())

    if db_admin:
        if not db_admin.get("isActive", True):
            return False, "This admin account has been deactivated."

        username = db_admin.get("username", identifier)
        email    = db_admin.get("email", "")

        # ── 2a. Firebase REST API ─────────────────────────────────────────────
        if firebase_configured() and email:
            try:
                result = sign_in_with_firebase(email, password)
                if result:
                    _do_login(username, email)
                    return True, ""
            except ValueError as e:
                return False, str(e)

        # ── 2b. bcrypt fallback ───────────────────────────────────────────────
        ph = db_admin.get("passwordHash", "")
        if ph and _check_password(password, ph):
            _do_login(username, email)
            return True, ""

        return False, "Invalid credentials."

    # ── 3. Env-var superadmin fallback ────────────────────────────────────────
    if (identifier in (settings.admin_username, settings.admin_username)
            and _check_password(password, settings.admin_password_hash)):
        _do_login(identifier)
        return True, ""

    return False, "Invalid credentials."


def _try_signup(
    username: str, email: str,
    password: str, confirm: str,
    setup_code: str,
) -> tuple[bool, str]:
    """
    Creates the user in both Firebase Auth and Neo4j Aura.
    Returns (success, error_message).
    """
    from .database import (
        get_admin_user, get_admin_user_by_email,
        create_admin_user, admin_user_count,
    )
    from .firebase_auth import create_firebase_user, firebase_configured

    # ── Validation ────────────────────────────────────────────────────────────
    username = username.strip()
    email    = email.strip().lower()

    if not username or not email or not password:
        return False, "All fields are required."
    if len(username) < 3:
        return False, "Username must be at least 3 characters."
    if "@" not in email or "." not in email.split("@")[-1]:
        return False, "Enter a valid email address."
    if len(password) < 8:
        return False, "Password must be at least 8 characters."
    if password != confirm:
        return False, "Passwords do not match."

    count = admin_user_count()
    if count > 0 and setup_code.strip() != settings.admin_setup_code:
        return False, "Invalid setup code."

    if get_admin_user(username):
        return False, f"Username '{username}' is already taken."
    if get_admin_user_by_email(email):
        return False, f"An admin account with this email already exists."

    # ── Firebase signup ───────────────────────────────────────────────────────
    firebase_uid: str | None = None
    if firebase_configured():
        try:
            firebase_uid = create_firebase_user(email, password, username)
        except ValueError as e:
            return False, str(e)
    # If Firebase is not yet configured, we skip it and rely on bcrypt only

    # ── Neo4j Aura — store profile + Firebase UID + bcrypt hash ──────────────
    password_hash = _hash_password(password)
    ok = create_admin_user(username, email, password_hash, firebase_uid)
    if not ok:
        return False, "Failed to save account — database error."

    _do_login(username, email)
    return True, ""


# ── Page CSS ──────────────────────────────────────────────────────────────────

_CSS = """
<style>
/* ── Base & background ── */
[data-testid="stAppViewContainer"],
[data-testid="stAppViewContainer"] > .main {
    background: #13132B !important;
    min-height: 100vh;
}
[data-testid="stAppViewContainer"]::before {
    content: '';
    position: fixed;
    top: -180px; right: -180px;
    width: 520px; height: 520px;
    background: radial-gradient(circle, rgba(255,107,53,.18) 0%, transparent 68%);
    border-radius: 50%;
    pointer-events: none; z-index: 0;
}
[data-testid="stAppViewContainer"]::after {
    content: '';
    position: fixed;
    bottom: -120px; left: -120px;
    width: 440px; height: 440px;
    background: radial-gradient(circle, rgba(108,92,231,.14) 0%, transparent 68%);
    border-radius: 50%;
    pointer-events: none; z-index: 0;
}
[data-testid="stHeader"]     { background: transparent !important; border: none !important; }
[data-testid="stDecoration"] { display: none !important; }
#MainMenu, footer, header    { visibility: hidden !important; }
[data-testid="stMainBlockContainer"] {
    padding-top: 0 !important;
    position: relative; z-index: 1;
}

/* ── Tab switcher ── */
.stTabs [data-baseweb="tab-list"] {
    background    : #0D0D22 !important;
    border        : 1px solid rgba(255,255,255,.10) !important;
    border-radius : 14px !important;
    padding       : 5px !important;
    gap           : 5px !important;
}
.stTabs [data-baseweb="tab"] {
    border-radius   : 10px !important;
    font-weight     : 600 !important;
    font-size       : 13.5px !important;
    color           : rgba(255,255,255,.38) !important;
    padding         : 9px 0 !important;
    flex            : 1 !important;
    justify-content : center !important;
    letter-spacing  : .2px !important;
    transition      : color .2s !important;
}
.stTabs [aria-selected="true"] {
    background  : linear-gradient(135deg,#FF6B35,#E04E20) !important;
    color       : #fff !important;
    box-shadow  : 0 4px 16px rgba(255,107,53,.38) !important;
}
[data-testid="stTabContent"] { padding-top: 18px !important; }

/* ── Input labels ── */
.stTextInput > label,
.stTextInput p {
    color          : rgba(255,255,255,.55) !important;
    font-size      : 12.5px !important;
    font-weight    : 600 !important;
    letter-spacing : .3px !important;
    text-transform : uppercase !important;
    margin-bottom  : 5px !important;
}
.stTextInput > div,
.stTextInput > div > div { background: transparent !important; }

/* ── Input fields ── */
.stTextInput input {
    background    : rgba(255,255,255,.06) !important;
    border        : 1.5px solid rgba(255,255,255,.12) !important;
    border-radius : 12px !important;
    color         : #fff !important;
    font-size     : 14px !important;
    padding       : 13px 16px !important;
    transition    : border-color .2s, box-shadow .2s, background .2s !important;
    caret-color   : #FF6B35 !important;
    letter-spacing: .1px !important;
}
.stTextInput input:focus {
    border-color : #FF6B35 !important;
    box-shadow   : 0 0 0 3px rgba(255,107,53,.16) !important;
    background   : rgba(255,255,255,.09) !important;
    outline      : none !important;
}
.stTextInput input::placeholder { color: rgba(255,255,255,.2) !important; }
.stTextInput button             { color: rgba(255,255,255,.3) !important; background: transparent !important; }
.stTextInput button:hover       { color: rgba(255,255,255,.65) !important; }

/* ── Submit button ── */
.stButton > button {
    width          : 100% !important;
    background     : linear-gradient(135deg,#FF6B35 0%,#E04E20 100%) !important;
    border         : none !important;
    border-radius  : 13px !important;
    color          : #fff !important;
    font-size      : 15px !important;
    font-weight    : 700 !important;
    padding        : 14px 0 !important;
    letter-spacing : .3px !important;
    box-shadow     : 0 8px 24px rgba(255,107,53,.38) !important;
    transition     : transform .15s, box-shadow .15s !important;
    margin-top     : 12px !important;
}
.stButton > button:hover {
    transform  : translateY(-2px) !important;
    box-shadow : 0 12px 32px rgba(255,107,53,.50) !important;
}
.stButton > button:active { transform: translateY(0) !important; }

/* ── Override Streamlit alert boxes ── */
[data-testid="stAlert"] {
    border-radius : 10px !important;
    font-size     : 13px !important;
}
</style>
"""

# Inline banner helpers (replace generic st.success / st.info)
def _banner(text: str, color: str, bg: str, icon: str) -> str:
    return (
        f'<div style="background:{bg};border:1px solid {color}33;'
        f'border-radius:10px;padding:10px 14px;font-size:13px;'
        f'color:{color};font-weight:500;margin-bottom:14px;'
        f'display:flex;align-items:center;gap:8px;">'
        f'<span style="font-size:15px;">{icon}</span>{text}</div>'
    )


# ── Render ────────────────────────────────────────────────────────────────────

def render_login_page():
    from .database import admin_user_count
    from .firebase_auth import firebase_configured

    st.markdown(_CSS, unsafe_allow_html=True)

    _, mid, _ = st.columns([1, 1.05, 1])
    with mid:
        st.markdown("<div style='height:56px'></div>", unsafe_allow_html=True)

        # ── Brand ─────────────────────────────────────────────────────────────
        st.markdown(
            """
            <div style="text-align:center;margin-bottom:32px;">
              <div style="
                  display:inline-flex;align-items:center;justify-content:center;
                  width:82px;height:82px;border-radius:24px;
                  background:linear-gradient(145deg,#FF7A45,#FF5A1F);
                  font-size:42px;margin-bottom:16px;
                  box-shadow:0 12px 40px rgba(255,107,53,.50),
                             0 0 0 1px rgba(255,255,255,.08);">
                🚛
              </div>
              <div style="font-size:28px;font-weight:800;color:#fff;
                          letter-spacing:-.6px;line-height:1;">Haulistry</div>
              <div style="margin-top:8px;font-size:13px;color:rgba(255,255,255,.45);
                          letter-spacing:.2px;">
                Book the best in the Hauling
              </div>
            </div>
            """,
            unsafe_allow_html=True,
        )

        tab_in, tab_up = st.tabs(["  Sign In  ", "  Create Account  "])

        # ── Sign In ───────────────────────────────────────────────────────────
        with tab_in:
            username = st.text_input(
                "Username or Email",
                placeholder="Enter username or email",
                key="li_user",
            )
            password = st.text_input(
                "Password", type="password",
                placeholder="Enter your password", key="li_pass"
            )

            if firebase_configured():
                st.markdown(
                    '<div style="display:flex;align-items:center;justify-content:flex-end;'
                    'gap:5px;margin-top:-4px;margin-bottom:6px;">'
                    '<svg width="10" height="12" viewBox="0 0 10 12" fill="none">'
                    '<rect x="1" y="5" width="8" height="7" rx="1.5" fill="rgba(255,107,53,.7)"/>'
                    '<path d="M3 5V3.5a2 2 0 014 0V5" stroke="rgba(255,107,53,.7)" stroke-width="1.5" stroke-linecap="round"/>'
                    '</svg>'
                    '<span style="font-size:11px;color:rgba(255,255,255,.28);letter-spacing:.2px;">'
                    'Secured with Firebase</span></div>',
                    unsafe_allow_html=True,
                )

            if st.button("Sign In →", key="li_btn"):
                if not username or not password:
                    st.error("Please enter your username and password.")
                else:
                    ok, err = _try_login(username, password)
                    if ok:
                        st.rerun()
                    else:
                        st.error(err)

        # ── Create Account ────────────────────────────────────────────────────
        with tab_up:
            first = admin_user_count() == 0

            if first:
                st.markdown(
                    _banner(
                        "First account",
                        "#00B894", "rgba(0,184,148,.1)", "✓"
                    ),
                    unsafe_allow_html=True,
                )
            elif not firebase_configured():
                st.markdown(
                    _banner(
                        "Firebase key not set — local auth only.",
                        "#74B9FF", "rgba(116,185,255,.1)", "ℹ"
                    ),
                    unsafe_allow_html=True,
                )

            su_user  = st.text_input(
                "Username", placeholder="Choose a username (min. 3 chars)", key="su_user"
            )
            su_email = st.text_input(
                "Email", placeholder="admin@example.com", key="su_email"
            )
            su_pass  = st.text_input(
                "Password", type="password",
                placeholder="Min. 8 characters", key="su_pass"
            )
            su_conf  = st.text_input(
                "Confirm Password", type="password",
                placeholder="Repeat password", key="su_conf"
            )
            su_code  = "" if first else st.text_input(
                "Setup Code", type="password",
                placeholder="From ADMIN_SETUP_CODE in backend/.env",
                key="su_code",
            )

            if st.button("Create Account →", key="su_btn"):
                ok, err = _try_signup(
                    su_user, su_email, su_pass, su_conf, su_code
                )
                if ok:
                    st.session_state["_signup_ok"] = True
                    st.rerun()
                else:
                    st.error(err)

        st.markdown(
            "<p style='text-align:center;color:rgba(255,255,255,.16);"
            "font-size:11px;margin-top:20px;letter-spacing:.5px;'>"
            "HAULISTRY ADMIN v1.0 &nbsp;·&nbsp; SECURED</p>",
            unsafe_allow_html=True,
        )
