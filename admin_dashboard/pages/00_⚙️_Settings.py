"""
Admin profile settings — update display name, change password.
"""

import streamlit as st
from core.auth import logout
from components.sidebar import render_sidebar
from core.database import get_admin_user_by_email, run_query
from core.firebase_auth import update_firebase_password, firebase_configured
from components.styles import (
    page_header, section_header,
    alert_success, alert_error, alert_info, alert_warning,
    PRIMARY, TEXT_SEC, TEXT_PRIMARY, CARD_BG, BORDER,
)
import bcrypt

st.set_page_config(
    page_title="Settings · Haulistry Admin",
    page_icon="⚙️",
    layout="wide",
)
render_sidebar()

page_header("Settings", "Manage your admin profile and account security", "⚙️")

current_user  = st.session_state.get("admin_user", "")
current_email = st.session_state.get("admin_email", "")

# ── Load current profile ──────────────────────────────────────────────────────
@st.cache_data(ttl=30, show_spinner=False)
def _profile(email):
    return get_admin_user_by_email(email) if email else None

profile = _profile(current_email)

left_col, right_col = st.columns([2, 3])

# ── Profile card (left) ───────────────────────────────────────────────────────
with left_col:
    initials = (current_user[:2].upper()) if current_user else "A"
    auth_tag = (
        f'<div style="display:inline-flex;align-items:center;gap:5px;'
        f'font-size:11.5px;color:#27AE60;margin-top:4px;">'
        f'<span>🔒</span><span>Firebase-secured</span></div>'
        if firebase_configured() and (profile or {}).get("firebaseUid")
        else f'<div style="font-size:11.5px;color:{TEXT_SEC};margin-top:4px;">'
             f'🔑 Local auth</div>'
    )
    st.markdown(
        f"""
        <div style="background:{CARD_BG};border:1px solid {BORDER};border-radius:14px;
                    padding:28px 24px;text-align:center;
                    box-shadow:0 1px 4px rgba(0,0,0,.04);">
          <div style="width:72px;height:72px;border-radius:18px;
                      background:linear-gradient(135deg,{PRIMARY},#E55A2B);
                      display:flex;align-items:center;justify-content:center;
                      font-size:28px;font-weight:800;color:#fff;
                      margin:0 auto 16px;">
            {initials}
          </div>
          <div style="font-size:20px;font-weight:800;color:{TEXT_PRIMARY};
                      letter-spacing:-.3px;">{current_user}</div>
          <div style="font-size:13px;color:{TEXT_SEC};margin-top:4px;">{current_email}</div>
          {auth_tag}
          <div style="background:#F7FAFC;border:1px solid {BORDER};border-radius:10px;
                      padding:12px;margin-top:16px;text-align:left;">
            <div style="font-size:11px;font-weight:700;color:{TEXT_SEC};
                        text-transform:uppercase;letter-spacing:.5px;
                        margin-bottom:8px;">Account Info</div>
            <div style="font-size:12.5px;color:{TEXT_PRIMARY};">
              Role: <b>Administrator</b>
            </div>
          </div>
        </div>
        """,
        unsafe_allow_html=True,
    )

# ── Settings forms (right) ────────────────────────────────────────────────────
with right_col:
    section_header("Change Password", "Update your account password")

    st.markdown(
        f'<div style="background:{CARD_BG};border:1px solid {BORDER};'
        f'border-radius:14px;padding:24px;box-shadow:0 1px 4px rgba(0,0,0,.04);">',
        unsafe_allow_html=True,
    )

    if not firebase_configured():
        alert_info("Firebase is not configured. Password changes use local bcrypt only.")

    pw_msg_key = "settings_pw_msg"
    if pw_msg_key in st.session_state:
        msg_type, msg_text = st.session_state.pop(pw_msg_key)
        if msg_type == "success":
            alert_success(msg_text)
        elif msg_type == "error":
            alert_error(msg_text)

    current_pw  = st.text_input("Current Password",     type="password", key="cpw")
    new_pw      = st.text_input("New Password",         type="password",
                                placeholder="Min. 8 characters", key="npw")
    confirm_pw  = st.text_input("Confirm New Password", type="password", key="cnpw")

    if st.button("Update Password", type="primary", key="update_pw_btn"):
        if not current_pw or not new_pw or not confirm_pw:
            alert_error("All password fields are required.")
        elif len(new_pw) < 8:
            alert_error("New password must be at least 8 characters.")
        elif new_pw != confirm_pw:
            alert_error("New passwords do not match.")
        else:
            # Verify current password
            ph = (profile or {}).get("passwordHash", "")
            try:
                valid = bool(ph and bcrypt.checkpw(current_pw.encode(), ph.encode()))
            except Exception:
                valid = False

            # Also try Firebase (best effort)
            fb_valid = False
            if firebase_configured() and current_email:
                try:
                    from core.firebase_auth import sign_in_with_firebase
                    result = sign_in_with_firebase(current_email, current_pw)
                    fb_valid = result is not None
                except ValueError:
                    pass

            if not valid and not fb_valid:
                alert_error("Current password is incorrect.")
            else:
                new_hash = bcrypt.hashpw(new_pw.encode(), bcrypt.gensalt(rounds=12)).decode()

                # Update Neo4j hash
                upd_q = """
                MATCH (a:AdminUser {email: $email})
                SET a.passwordHash = $hash, a.updatedAt = datetime()
                RETURN a.id AS id
                """
                rows = run_query(upd_q,
                                 {"email": current_email, "hash": new_hash},
                                 write=True)

                if not rows:
                    alert_error("Failed to update password in database.")
                else:
                    # Update Firebase password
                    fb_uid = (profile or {}).get("firebaseUid", "")
                    if fb_uid and firebase_configured():
                        fb_ok = update_firebase_password(fb_uid, new_pw)
                        if not fb_ok:
                            alert_warning("Password updated locally but Firebase sync failed.")
                        else:
                            st.session_state[pw_msg_key] = ("success", "Password changed successfully.")
                            st.rerun()
                    else:
                        st.session_state[pw_msg_key] = ("success", "Password changed successfully.")
                        st.rerun()

    st.markdown("</div>", unsafe_allow_html=True)

    st.markdown("<div style='height:20px'></div>", unsafe_allow_html=True)

    # ── Session info ──────────────────────────────────────────────────────────
    section_header("Session", "Current session information")
    st.markdown(
        f'<div style="background:{CARD_BG};border:1px solid {BORDER};'
        f'border-radius:14px;padding:20px 24px;box-shadow:0 1px 4px rgba(0,0,0,.04);">',
        unsafe_allow_html=True,
    )

    from datetime import datetime
    login_time = st.session_state.get("login_time")
    if login_time:
        elapsed = datetime.now() - login_time
        mins    = int(elapsed.total_seconds() / 60)
        lt_str  = login_time.strftime("%Y-%m-%d %H:%M")
    else:
        lt_str, mins = "—", 0

    from core.config import settings
    timeout = settings.session_timeout_minutes
    remaining = max(0, timeout - mins)

    st.markdown(
        f"""
        <div style="display:flex;flex-direction:column;gap:8px;">
          <div style="display:flex;justify-content:space-between;padding:8px 0;
                      border-bottom:1px solid #EDF2F7;">
            <span style="font-size:12.5px;font-weight:600;color:{TEXT_SEC};">Signed In At</span>
            <span style="font-size:13px;color:{TEXT_PRIMARY};">{lt_str}</span>
          </div>
          <div style="display:flex;justify-content:space-between;padding:8px 0;
                      border-bottom:1px solid #EDF2F7;">
            <span style="font-size:12.5px;font-weight:600;color:{TEXT_SEC};">Session Duration</span>
            <span style="font-size:13px;color:{TEXT_PRIMARY};">{mins} minutes</span>
          </div>
          <div style="display:flex;justify-content:space-between;padding:8px 0;">
            <span style="font-size:12.5px;font-weight:600;color:{TEXT_SEC};">Session Expires In</span>
            <span style="font-size:13px;color:{'#E74C3C' if remaining < 15 else TEXT_PRIMARY};">
              {remaining} minutes
            </span>
          </div>
        </div>
        """,
        unsafe_allow_html=True,
    )

    if st.button("Sign Out", use_container_width=True, key="settings_logout"):
        logout()
        st.rerun()

    st.markdown("</div>", unsafe_allow_html=True)
