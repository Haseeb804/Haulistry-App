"""
Haulistry Admin Dashboard — main entry point.
Run with: streamlit run app.py
"""

import streamlit as st

st.set_page_config(
    page_title="Haulistry Admin",
    page_icon="🚛",
    layout="wide",
    initial_sidebar_state="expanded",
)

from core.auth import is_authenticated, render_login_page
from components.styles import inject_global_css, TEXT_SEC, CARD_BG, BORDER
from components.sidebar import render_sidebar

inject_global_css()

if not is_authenticated():
    render_login_page()
    st.stop()

if st.session_state.pop("_signup_ok", False):
    st.toast("Account created! Welcome to Haulistry Admin.", icon="✅")

render_sidebar()

# ── Home landing ───────────────────────────────────────────────────────────────
st.markdown(
    f"""
    <div style="text-align:center;padding:52px 0 36px;">
      <div style="display:inline-flex;align-items:center;justify-content:center;
                  width:76px;height:76px;border-radius:22px;
                  background:linear-gradient(135deg,#FF7A45,#FF4500);
                  font-size:36px;margin-bottom:18px;
                  box-shadow:0 12px 40px rgba(255,107,53,.35);">🚛</div>
      <h1 style="font-size:30px;font-weight:800;color:#1A202C;
                  margin:0 0 10px;letter-spacing:-.5px;">
        Welcome to Haulistry Admin
      </h1>
      <p style="font-size:15px;color:{TEXT_SEC};margin:0;">
        Select a section from the sidebar to get started.
      </p>
    </div>
    """,
    unsafe_allow_html=True,
)

_HOME_NAV = [
    ("📊", "Dashboard",      "Platform overview & KPIs"),
    ("✅", "Verifications",   "Review pending providers"),
    ("👷", "Providers",       "Manage service providers"),
    ("👤", "Seekers",         "Manage customers"),
    ("🔧", "Services",        "Service catalogue"),
    ("🚛", "Vehicles",        "Fleet registry"),
    ("📋", "Bookings",        "Live booking tracker"),
    ("💰", "Transactions",    "Financial overview"),
    ("📈", "Analytics",       "Reports & trends"),
    ("📣", "Notifications",   "Push notification log"),
    ("🚨", "Complaints",      "Disputes & low ratings"),
    ("📜", "Audit Logs",      "Admin action history"),
    ("👑", "Admin Users",     "Admin accounts"),
]

cols = st.columns(4)
for i, (icon, name, desc) in enumerate(_HOME_NAV):
    with cols[i % 4]:
        st.markdown(
            f"""
            <div style="background:{CARD_BG};border:1px solid {BORDER};
                        border-radius:14px;padding:20px 18px;text-align:center;
                        margin-bottom:12px;
                        box-shadow:0 1px 4px rgba(0,0,0,.04);">
              <div style="font-size:26px;margin-bottom:8px;">{icon}</div>
              <div style="font-weight:700;font-size:14px;color:#1A202C;
                          margin-bottom:4px;">{name}</div>
              <div style="font-size:12px;color:#718096;">{desc}</div>
            </div>
            """,
            unsafe_allow_html=True,
        )
