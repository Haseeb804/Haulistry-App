"""
Seeker / customer management.
"""

import streamlit as st
from components.sidebar import render_sidebar
from core.database import get_all_users, get_user_detail, toggle_user_status
from components.styles import (
    page_header, status_badge, fmt_date,
    fmt_number, empty_state, section_header, kpi_card, pagination,
    PRIMARY, SECONDARY, SUCCESS, WARNING, TEXT_SEC, TEXT_PRIMARY, CARD_BG, BORDER,
)

st.set_page_config(page_title="Seekers · Haulistry Admin", page_icon="👤", layout="wide")
render_sidebar()

# ── State ─────────────────────────────────────────────────────────────────────
if "selected_seeker" not in st.session_state:
    st.session_state.selected_seeker = None

# ── Detail view ───────────────────────────────────────────────────────────────
if st.session_state.selected_seeker:
    sid = st.session_state.selected_seeker

    if st.button("← Back to Seekers"):
        st.session_state.selected_seeker = None
        st.rerun()

    @st.cache_data(ttl=30, show_spinner=False)
    def _detail(uid):
        return get_user_detail(uid)

    with st.spinner("Loading seeker…"):
        detail = _detail(sid)

    if not detail:
        st.warning("Seeker not found.")
        st.stop()

    name      = detail.get("name", "—")
    email     = detail.get("email", "—")
    phone     = detail.get("phone", "—")
    is_active = detail.get("isActive", False)

    initials = (name[:2].upper()) if name and name != "—" else "??"
    st.markdown(
        f"""
        <div style="background:{CARD_BG};border:1px solid {BORDER};border-radius:14px;
                    padding:22px 24px;margin-bottom:20px;
                    display:flex;align-items:center;justify-content:space-between;
                    box-shadow:0 1px 4px rgba(0,0,0,.04);">
          <div style="display:flex;align-items:center;gap:14px;">
            <div style="width:50px;height:50px;border-radius:12px;
                        background:linear-gradient(135deg,{SECONDARY},{PRIMARY});
                        display:flex;align-items:center;justify-content:center;
                        font-size:20px;font-weight:700;color:#fff;">{initials}</div>
            <div>
              <div style="font-size:20px;font-weight:800;color:{TEXT_PRIMARY};
                          letter-spacing:-.3px;">{name}</div>
              <div style="font-size:13px;color:{TEXT_SEC};margin-top:2px;">
                {email} &nbsp;·&nbsp; {phone}
              </div>
              <div style="margin-top:8px;">
                {status_badge("active_user" if is_active else "inactive")}
              </div>
            </div>
          </div>
        </div>
        """,
        unsafe_allow_html=True,
    )

    btn_label = "Deactivate" if is_active else "Activate"
    if st.button(btn_label, type="primary" if not is_active else "secondary"):
        ok = toggle_user_status(sid, not is_active)
        if ok:
            st.toast(f"{'Deactivated' if is_active else 'Activated'} {name}", icon="✅")
            st.cache_data.clear()
            st.rerun()
        else:
            st.warning("Action failed — please try again.")

    st.markdown("<div style='height:16px'></div>", unsafe_allow_html=True)

    t1, t2 = st.tabs(["  Profile  ", "  Details  "])

    with t1:
        rows = [
            ("Email",        email),
            ("Phone",        phone),
            ("Joined",       fmt_date(detail.get("createdAt"))),
            ("Last Updated", fmt_date(detail.get("updatedAt"))),
        ]
        st.markdown(
            f'<div style="background:{CARD_BG};border:1px solid {BORDER};'
            f'border-radius:12px;padding:20px 24px;">'
            + "".join(
                f'<div style="display:flex;padding:9px 0;border-bottom:1px solid #EDF2F7;">'
                f'<div style="width:160px;font-size:12.5px;font-weight:600;color:{TEXT_SEC};">{k}</div>'
                f'<div style="font-size:13px;color:{TEXT_PRIMARY};">{v}</div>'
                f'</div>'
                for k, v in rows
            )
            + "</div>",
            unsafe_allow_html=True,
        )

    with t2:
        st.markdown(
            f'<div style="background:#FFFBEB;border:1px solid #FEFCBF;border-radius:10px;'
            f'padding:12px 16px;font-size:13px;color:#744210;">'
            f'Seeker ID: <code>{sid}</code></div>',
            unsafe_allow_html=True,
        )

    st.stop()

# ── List view ─────────────────────────────────────────────────────────────────
page_header("Seekers", "Manage service customers on the platform", "👤")

# ── Filters ────────────────────────────────────────────────────────────────────
col_search, col_active = st.columns([4, 1])
with col_search:
    search = st.text_input("Search seekers", placeholder="Name, email or phone…",
                           label_visibility="collapsed")
with col_active:
    filter_active = st.selectbox("Status", ["All", "Active", "Inactive"],
                                 label_visibility="collapsed")

@st.cache_data(ttl=60, show_spinner=False)
def _seekers():
    return get_all_users(role="seeker", size=200)

all_seekers = _seekers()

rows = all_seekers
if search:
    q = search.lower()
    rows = [s for s in rows if (q in str(s.get("name", "")).lower()
                                or q in str(s.get("email", "")).lower()
                                or q in str(s.get("phone", "")).lower())]
if filter_active == "Active":
    rows = [s for s in rows if s.get("isActive")]
elif filter_active == "Inactive":
    rows = [s for s in rows if not s.get("isActive")]

# ── Summary KPIs ──────────────────────────────────────────────────────────────
total     = len(all_seekers)
active_ct = sum(1 for s in all_seekers if s.get("isActive"))

sk1, sk2, sk3 = st.columns(3)
with sk1:
    st.markdown(kpi_card("Total Seekers", str(total),     color=PRIMARY),   unsafe_allow_html=True)
with sk2:
    st.markdown(kpi_card("Active",        str(active_ct), color=SUCCESS),   unsafe_allow_html=True)
with sk3:
    st.markdown(kpi_card("Inactive",      str(total - active_ct), color=WARNING), unsafe_allow_html=True)

st.markdown("<div style='height:16px'></div>", unsafe_allow_html=True)

st.markdown(
    f'<div style="font-size:13px;color:{TEXT_SEC};margin-bottom:12px;">'
    f'Showing <b style="color:{TEXT_PRIMARY};">{len(rows)}</b> of {total} seekers</div>',
    unsafe_allow_html=True,
)

if not rows:
    empty_state("No seekers match your filters", "Try adjusting your search criteria.", "🔍")
    st.stop()

# ── Header row ────────────────────────────────────────────────────────────────
st.markdown(
    f'<div style="display:flex;padding:8px 0;border-bottom:2px solid {BORDER};'
    f'font-size:11px;font-weight:700;color:{TEXT_SEC};'
    f'text-transform:uppercase;letter-spacing:.5px;">'
    f'<div style="flex:2;">Seeker</div>'
    f'<div style="flex:2;">Contact</div>'
    f'<div style="flex:1;">Status</div>'
    f'<div style="flex:1;text-align:right;">Action</div>'
    f'</div>',
    unsafe_allow_html=True,
)

# ── Rows ──────────────────────────────────────────────────────────────────────
PAGE_SIZE = 20
page_key  = "seekers_page"
if page_key not in st.session_state:
    st.session_state[page_key] = 0
current_page = st.session_state[page_key]
paged = rows[current_page * PAGE_SIZE: (current_page + 1) * PAGE_SIZE]

for s in paged:
    sid       = s.get("id", "")
    name      = s.get("name", "Unknown")
    email     = s.get("email", "—")
    phone     = s.get("phone", "—")
    is_active = s.get("isActive", False)
    joined    = fmt_date(s.get("createdAt"))

    c_name, c_contact, c_badge, c_action = st.columns([2, 2, 1, 1])
    with c_name:
        initials = (name[:2].upper()) if name != "Unknown" else "??"
        st.markdown(
            f'<div style="display:flex;align-items:center;gap:10px;padding:10px 0;">'
            f'<div style="width:36px;height:36px;border-radius:9px;flex-shrink:0;'
            f'background:linear-gradient(135deg,{SECONDARY}22,{PRIMARY}22);'
            f'display:flex;align-items:center;justify-content:center;'
            f'font-size:13px;font-weight:700;color:{SECONDARY};">{initials}</div>'
            f'<div>'
            f'<div style="font-weight:600;color:{TEXT_PRIMARY};font-size:13.5px;">{name}</div>'
            f'<div style="font-size:11.5px;color:{TEXT_SEC};">Joined {joined}</div>'
            f'</div></div>',
            unsafe_allow_html=True,
        )
    with c_contact:
        st.markdown(
            f'<div style="padding:10px 0;">'
            f'<div style="font-size:13px;color:{TEXT_PRIMARY};">{email}</div>'
            f'<div style="font-size:12px;color:{TEXT_SEC};margin-top:2px;">{phone}</div>'
            f'</div>',
            unsafe_allow_html=True,
        )
    with c_badge:
        st.markdown(
            f'<div style="padding:12px 0;">'
            f'{status_badge("active_user" if is_active else "inactive")}</div>',
            unsafe_allow_html=True,
        )
    with c_action:
        st.markdown("<div style='padding-top:8px;'></div>", unsafe_allow_html=True)
        if st.button("View →", key=f"view_{sid}", use_container_width=True):
            st.session_state.selected_seeker = sid
            st.session_state[page_key] = current_page
            st.rerun()

    st.markdown(f'<div style="border-bottom:1px solid {BORDER};"></div>', unsafe_allow_html=True)

pagination(page_key, len(rows), PAGE_SIZE)
