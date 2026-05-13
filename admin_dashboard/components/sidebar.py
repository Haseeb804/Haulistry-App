"""
components/sidebar.py — Single source of truth for the admin sidebar.

Call render_sidebar() immediately after st.set_page_config() on every page.
It handles:
  - Global page CSS injection
  - Sidebar-specific CSS (dark theme, nav links, active highlighting)
  - Authentication guard (redirects to login if session expired)
  - Persistent sidebar content (brand, nav, profile footer, sign-out)
"""

import streamlit as st
from core.auth import is_authenticated, logout
from core.database import is_connected
from components.styles import inject_global_css, PRIMARY

# ── Navigation registry ───────────────────────────────────────────────────────
_NAV = [
    ("pages/1_📊_Dashboard.py",      "📊", "Dashboard"),
    ("pages/2_✅_Verifications.py",   "✅", "Verifications"),
    ("pages/3_👷_Providers.py",       "👷", "Providers"),
    ("pages/4_👤_Seekers.py",         "👤", "Seekers"),
    ("pages/5_🔧_Services.py",        "🔧", "Services"),
    ("pages/6_🚛_Vehicles.py",        "🚛", "Vehicles"),
    ("pages/7_📋_Bookings.py",        "📋", "Bookings"),
    ("pages/8_💰_Transactions.py",    "💰", "Transactions"),
    ("pages/9_📈_Analytics.py",       "📈", "Analytics"),
    ("pages/10_📣_Notifications.py",  "📣", "Notifications"),
    ("pages/11_🚨_Complaints.py",     "🚨", "Complaints"),
    ("pages/12_📜_Audit_Logs.py",     "📜", "Audit Logs"),
    ("pages/0_👑_Admin_Users.py",     "👑", "Admin Users"),
]

# ── Sidebar CSS ───────────────────────────────────────────────────────────────
_SIDEBAR_CSS = """
<style>
/* Hide Streamlit's auto-generated page nav */
[data-testid="stSidebarNav"] { display: none !important; }

/* Sidebar base */
[data-testid="stSidebar"] {
    background: linear-gradient(180deg, #0D0D22 0%, #13132B 100%) !important;
    border-right: 1px solid rgba(255,255,255,.06) !important;
    min-width: 240px !important;
}
[data-testid="stSidebar"] > div:first-child { padding: 0 !important; }

/* Force all sidebar text white — covers every element st.page_link may render */
[data-testid="stSidebar"] p,
[data-testid="stSidebar"] span,
[data-testid="stSidebar"] li,
[data-testid="stSidebar"] label,
[data-testid="stSidebar"] a,
[data-testid="stSidebar"] [data-testid="stPageLink"] *,
[data-testid="stSidebar"] [data-testid="stPageLink-NavLink"] * {
    color: rgba(255,255,255,.75) !important;
}

/* Nav link items (st.page_link) */
[data-testid="stSidebar"] [data-testid="stPageLink"] a,
[data-testid="stSidebar"] [data-testid="stPageLink-NavLink"],
[data-testid="stSidebar"] [data-testid="stPageLink"] > div,
[data-testid="stSidebar"] [data-testid="stPageLink"] > a {
    display: flex !important;
    align-items: center !important;
    gap: 10px !important;
    padding: 10px 14px !important;
    border-radius: 10px !important;
    margin: 2px 10px !important;
    font-size: 13.5px !important;
    font-weight: 600 !important;
    color: rgba(255,255,255,.75) !important;
    text-decoration: none !important;
    transition: background .18s, color .18s !important;
    background: transparent !important;
    border: none !important;
}
[data-testid="stSidebar"] [data-testid="stPageLink"] a:hover,
[data-testid="stSidebar"] [data-testid="stPageLink-NavLink"]:hover,
[data-testid="stSidebar"] [data-testid="stPageLink"]:hover > div,
[data-testid="stSidebar"] [data-testid="stPageLink"]:hover > a {
    background: rgba(255,255,255,.07) !important;
    color: #fff !important;
}
[data-testid="stSidebar"] [data-testid="stPageLink"]:hover *,
[data-testid="stSidebar"] [data-testid="stPageLink-NavLink"]:hover * {
    color: #fff !important;
}

/* Active / current page */
[data-testid="stSidebar"] [data-testid="stPageLink"] a[aria-current="page"],
[data-testid="stSidebar"] [aria-selected="true"] [data-testid="stPageLink-NavLink"],
[data-testid="stSidebar"] [data-testid="stPageLink"] a[aria-current="page"] *,
[data-testid="stSidebar"] [aria-selected="true"] [data-testid="stPageLink-NavLink"] * {
    background: linear-gradient(135deg, rgba(255,107,53,.25), rgba(255,107,53,.12)) !important;
    color: #FF6B35 !important;
    border-left: 3px solid #FF6B35 !important;
}

/* Collapse button */
[data-testid="stSidebarCollapseButton"] button {
    background: rgba(255,255,255,.08) !important;
    border-radius: 8px !important;
    color: rgba(255,255,255,.5) !important;
    border: 1px solid rgba(255,255,255,.1) !important;
}
[data-testid="stSidebarCollapseButton"] button:hover {
    background: rgba(255,107,53,.2) !important;
    color: #FF6B35 !important;
    border-color: rgba(255,107,53,.4) !important;
}

/* Sign-out button in sidebar */
[data-testid="stSidebar"] .stButton > button,
[data-testid="stSidebar"] .stButton > button *,
[data-testid="stSidebar"] [data-testid="stBaseButton-secondary"],
[data-testid="stSidebar"] [data-testid="stBaseButton-secondary"] *,
[data-testid="stSidebar"] [data-testid="stBaseButton-secondary"] button,
[data-testid="stSidebar"] [data-testid="stBaseButton-secondary"] button * {
    background: #0D0D22 !important;
    color: #FF6B35 !important;
    border: 1.5px solid rgba(255,107,53,.45) !important;
    border-radius: 10px !important;
    font-size: 12.5px !important;
    font-weight: 700 !important;
    transition: background .18s, color .18s !important;
    width: 100% !important;
}
[data-testid="stSidebar"] .stButton > button:hover,
[data-testid="stSidebar"] .stButton > button:hover *,
[data-testid="stSidebar"] [data-testid="stBaseButton-secondary"] button:hover,
[data-testid="stSidebar"] [data-testid="stBaseButton-secondary"] button:hover * {
    background: rgba(255,107,53,.15) !important;
    color: #FF8C5A !important;
    border-color: rgba(255,107,53,.7) !important;
}

/* Divider */
[data-testid="stSidebar"] hr {
    border-color: rgba(255,255,255,.07) !important;
    margin: 6px 0 !important;
}
</style>
"""


@st.cache_data(ttl=30, show_spinner=False)
def _db_status() -> bool:
    return is_connected()


def render_sidebar() -> None:
    """
    Render the persistent admin sidebar on any page.

    Injects global CSS, enforces auth (redirects to login if session is
    expired), and draws the full sidebar — brand header, navigation links,
    settings, admin profile, and sign-out.
    """
    inject_global_css()
    st.markdown(_SIDEBAR_CSS, unsafe_allow_html=True)

    if not is_authenticated():
        logout()
        st.switch_page("app.py")
        st.stop()

    db_ok    = _db_status()
    dot      = "🟢" if db_ok else "🔴"
    db_label = "Database Online" if db_ok else "Database Offline"

    with st.sidebar:
        # ── Brand header ──────────────────────────────────────────────────────
        st.markdown(
            f"""
            <div style="padding:20px 16px 14px;
                        border-bottom:1px solid rgba(255,255,255,.07);
                        margin-bottom:4px;">
              <div style="display:flex;align-items:center;gap:11px;">
                <div style="width:42px;height:42px;border-radius:12px;flex-shrink:0;
                            background:linear-gradient(145deg,#FF7A45,#FF4500);
                            display:flex;align-items:center;justify-content:center;
                            font-size:22px;
                            box-shadow:0 6px 20px rgba(255,107,53,.45);">🚛</div>
                <div>
                  <div style="font-size:17px;font-weight:800;color:#fff;
                              letter-spacing:-.4px;line-height:1.1;">Haulistry</div>
                  <div style="font-size:10px;color:rgba(255,255,255,.3);
                              letter-spacing:1.2px;text-transform:uppercase;
                              margin-top:1px;">Admin Panel</div>
                </div>
              </div>
              <div style="display:flex;align-items:center;gap:5px;margin-top:10px;">
                <span style="font-size:8px;">{dot}</span>
                <span style="font-size:11px;color:rgba(255,255,255,.35);">{db_label}</span>
              </div>
            </div>
            """,
            unsafe_allow_html=True,
        )

        # ── Section label ─────────────────────────────────────────────────────
        st.markdown(
            '<div style="padding:8px 16px 4px;">'
            '<span style="font-size:10px;font-weight:700;color:rgba(255,255,255,.22);'
            'letter-spacing:1.2px;text-transform:uppercase;">Main Menu</span></div>',
            unsafe_allow_html=True,
        )

        # ── Nav links ─────────────────────────────────────────────────────────
        for path, icon, label in _NAV:
            st.page_link(path, label=label, icon=icon)

        # ── Divider ───────────────────────────────────────────────────────────
        st.markdown(
            '<div style="min-height:16px;"></div>'
            '<hr style="border:none;border-top:1px solid rgba(255,255,255,.07);'
            'margin:4px 0 8px;">',
            unsafe_allow_html=True,
        )

        # ── Account section ───────────────────────────────────────────────────
        st.markdown(
            '<div style="padding:0 16px 4px;">'
            '<span style="font-size:10px;font-weight:700;color:rgba(255,255,255,.22);'
            'letter-spacing:1.2px;text-transform:uppercase;">Account</span></div>',
            unsafe_allow_html=True,
        )
        st.page_link("pages/00_⚙️_Settings.py", label="Settings", icon="⚙️")

        # ── Admin profile footer ──────────────────────────────────────────────
        admin_user  = st.session_state.get("admin_user", "Admin")
        admin_email = st.session_state.get("admin_email", "")
        initials    = (admin_user[:2].upper()) if admin_user else "A"

        st.markdown(
            f"""
            <div style="border-top:1px solid rgba(255,255,255,.07);
                        padding:14px 16px 10px;margin-top:4px;">
              <div style="display:flex;align-items:center;gap:10px;margin-bottom:10px;">
                <div style="width:34px;height:34px;border-radius:9px;flex-shrink:0;
                            background:linear-gradient(135deg,{PRIMARY},#E55A2B);
                            display:flex;align-items:center;justify-content:center;
                            font-size:13px;font-weight:800;color:#fff;">{initials}</div>
                <div style="min-width:0;flex:1;">
                  <div style="font-size:13px;font-weight:700;color:#fff;
                              white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">
                    {admin_user}</div>
                  <div style="font-size:11px;color:rgba(255,255,255,.3);
                              white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">
                    {admin_email or "Administrator"}</div>
                </div>
              </div>
            </div>
            """,
            unsafe_allow_html=True,
        )

        if st.button("↪  Sign Out", use_container_width=True, key="sidebar_signout"):
            logout()
            st.rerun()
