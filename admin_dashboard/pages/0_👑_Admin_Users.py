"""
Admin user management — view, deactivate, or delete other admin accounts.
"""

import streamlit as st
from components.sidebar import render_sidebar
from core.database import (
    get_all_admin_users, toggle_admin_user, delete_admin_user, admin_user_count,
)
from core.firebase_auth import delete_firebase_user, firebase_configured
from components.styles import (
    page_header, status_badge, fmt_date,
    empty_state, kpi_card,
    PRIMARY, SUCCESS, DANGER, TEXT_SEC, TEXT_PRIMARY, CARD_BG, BORDER,
)

st.set_page_config(
    page_title="Admin Users · Haulistry Admin",
    page_icon="👑",
    layout="wide",
)
render_sidebar()

page_header("Admin Users", "Manage admin accounts for this dashboard", "👑")

current_user = st.session_state.get("admin_user", "")

@st.cache_data(ttl=30, show_spinner=False)
def _admins():
    return get_all_admin_users()

admins = _admins()
count  = len(admins)

# ── Summary ───────────────────────────────────────────────────────────────────
active_ct = sum(1 for a in admins if a.get("isActive", True))
sc1, sc2 = st.columns(2)
with sc1:
    st.markdown(kpi_card("Total Admins",  str(count),     color=PRIMARY),  unsafe_allow_html=True)
with sc2:
    st.markdown(kpi_card("Active Admins", str(active_ct), color=SUCCESS),  unsafe_allow_html=True)

st.markdown("<div style='height:16px'></div>", unsafe_allow_html=True)

if not admins:
    empty_state(
        "No admin accounts yet",
        "Create an account via the Sign Up tab on the login page.",
        "👑",
    )
    st.stop()

# ── Header ────────────────────────────────────────────────────────────────────
st.markdown(
    f'<div style="display:flex;padding:8px 0;border-bottom:2px solid {BORDER};'
    f'font-size:11px;font-weight:700;color:{TEXT_SEC};'
    f'text-transform:uppercase;letter-spacing:.5px;">'
    f'<div style="flex:2;">Account</div>'
    f'<div style="flex:2.5;">Email</div>'
    f'<div style="flex:1;">Status</div>'
    f'<div style="flex:2;text-align:right;">Actions</div>'
    f'</div>',
    unsafe_allow_html=True,
)

for a in admins:
    aid       = a.get("id", "")
    uname     = a.get("username", "—")
    email     = a.get("email", "—")
    role      = a.get("role", "admin")
    is_active = a.get("isActive", True)
    created   = fmt_date(a.get("createdAt"))
    is_self   = (uname == current_user)

    c_name, c_email, c_badge, c_actions = st.columns([2, 2.5, 1, 2])

    with c_name:
        you_tag = (
            f'<span style="font-size:11px;background:{PRIMARY}22;color:{PRIMARY};'
            f'border-radius:20px;padding:1px 8px;font-weight:700;margin-left:6px;">you</span>'
            if is_self else ""
        )
        st.markdown(
            f'<div style="padding:10px 0;">'
            f'<div style="font-weight:700;color:{TEXT_PRIMARY};font-size:13.5px;">'
            f'{uname}{you_tag}</div>'
            f'<div style="font-size:11.5px;color:{TEXT_SEC};margin-top:2px;">'
            f'{role.title()} · since {created}</div>'
            f'</div>',
            unsafe_allow_html=True,
        )
    with c_email:
        st.markdown(
            f'<div style="padding:12px 0;font-size:13px;color:{TEXT_PRIMARY};">{email}</div>',
            unsafe_allow_html=True,
        )
    with c_badge:
        st.markdown(
            f'<div style="padding:12px 0;">'
            f'{status_badge("active_user" if is_active else "inactive")}</div>',
            unsafe_allow_html=True,
        )
    with c_actions:
        if is_self:
            st.markdown(
                f'<div style="padding:12px 0;font-size:12px;color:{TEXT_SEC};">'
                f'Your account</div>',
                unsafe_allow_html=True,
            )
        else:
            st.markdown("<div style='padding-top:8px;'></div>", unsafe_allow_html=True)
            act_col, del_col = st.columns(2)
            with act_col:
                lbl = "Deactivate" if is_active else "Activate"
                if st.button(lbl, key=f"tog_{aid}", use_container_width=True):
                    ok = toggle_admin_user(aid, not is_active)
                    if ok:
                        st.toast(f"{'Deactivated' if is_active else 'Activated'} {uname}", icon="✅")
                        st.cache_data.clear()
                        st.rerun()
                    else:
                        st.warning("Action failed.")
            with del_col:
                if st.button("Delete", key=f"del_{aid}", use_container_width=True):
                    if count <= 1:
                        st.warning("Cannot delete the last admin account.")
                    else:
                        ok = delete_admin_user(aid)
                        if ok:
                            st.toast(f"Deleted {uname}", icon="🗑️")
                            st.cache_data.clear()
                            st.rerun()
                        else:
                            st.warning("Deletion failed.")

    st.markdown(f'<div style="border-bottom:1px solid {BORDER};"></div>', unsafe_allow_html=True)

