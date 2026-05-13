"""
Notification management — view all platform notifications sent to users.
"""

import streamlit as st
import pandas as pd
from components.sidebar import render_sidebar
from core.database import get_notifications_all
from components.styles import (
    page_header, fmt_date, status_badge,
    empty_state, kpi_card, pagination,
    PRIMARY, SUCCESS, WARNING, TEXT_SEC, TEXT_PRIMARY, CARD_BG, BORDER,
)

st.set_page_config(
    page_title="Notifications · Haulistry Admin",
    page_icon="📣",
    layout="wide",
)
render_sidebar()

page_header("Notifications", "All platform notifications sent to users", "📣")

# ── Filters ───────────────────────────────────────────────────────────────────
col_search, col_type, col_read = st.columns([3, 1, 1])
with col_search:
    search = st.text_input("Search notifications", placeholder="Title or body…",
                           label_visibility="collapsed")
with col_type:
    type_filter = st.selectbox(
        "Type",
        ["All", "booking_update", "new_booking", "payment", "system", "promo"],
        label_visibility="collapsed",
        format_func=lambda x: x.replace("_", " ").title(),
    )
with col_read:
    read_filter = st.selectbox("Read", ["All", "Read", "Unread"],
                               label_visibility="collapsed")

@st.cache_data(ttl=30, show_spinner=False)
def _notifs():
    return get_notifications_all(limit=300)

all_notifs = _notifs()

rows = all_notifs
if search:
    q = search.lower()
    rows = [n for n in rows if (q in str(n.get("title", "")).lower()
                                or q in str(n.get("body", "")).lower())]
if type_filter != "All":
    rows = [n for n in rows if n.get("type", "") == type_filter]
if read_filter == "Read":
    rows = [n for n in rows if n.get("isRead")]
elif read_filter == "Unread":
    rows = [n for n in rows if not n.get("isRead")]

# ── Summary KPIs ──────────────────────────────────────────────────────────────
total    = len(all_notifs)
unread_ct = sum(1 for n in all_notifs if not n.get("isRead"))

sc1, sc2 = st.columns(2)
with sc1:
    st.markdown(kpi_card("Total Notifications", str(total),     color=PRIMARY),  unsafe_allow_html=True)
with sc2:
    st.markdown(kpi_card("Unread",              str(unread_ct), color=WARNING),  unsafe_allow_html=True)

st.markdown("<div style='height:16px'></div>", unsafe_allow_html=True)
st.markdown(
    f'<div style="font-size:13px;color:{TEXT_SEC};margin-bottom:12px;">'
    f'Showing <b style="color:{TEXT_PRIMARY};">{len(rows)}</b> of {total} notifications</div>',
    unsafe_allow_html=True,
)

if not rows:
    empty_state("No notifications found", "Try adjusting your filters.", "🔔")
    st.stop()

# ── Table ─────────────────────────────────────────────────────────────────────
table_rows = [
    {
        "Title":   n.get("title", "—"),
        "Body":    str(n.get("body", "—"))[:90] + ("…" if len(str(n.get("body", ""))) > 90 else ""),
        "Type":    (n.get("type") or "—").replace("_", " ").title(),
        "User ID": (str(n.get("userId", "—")) or "")[:14] + "…",
        "Read":    "✅ Read" if n.get("isRead") else "📩 Unread",
        "Sent":    fmt_date(n.get("createdAt")),
    }
    for n in rows
]
st.dataframe(pd.DataFrame(table_rows), use_container_width=True, hide_index=True)
