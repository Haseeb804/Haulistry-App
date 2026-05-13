"""
Audit log — recent platform-wide activity stream.
"""

import streamlit as st
from components.sidebar import render_sidebar
from core.database import get_recent_activity
from components.styles import (
    page_header, status_badge, fmt_datetime,
    empty_state,
    TEXT_SEC, TEXT_PRIMARY, BORDER,
)

st.set_page_config(
    page_title="Audit Logs · Haulistry Admin",
    page_icon="📜",
    layout="wide",
)
render_sidebar()

page_header("Audit Logs", "Recent platform-wide activity stream", "📜")

col_limit, _ = st.columns([2, 3])
with col_limit:
    limit = st.selectbox(
        "Show last",
        [20, 50, 100, 200],
        index=1,
        format_func=lambda n: f"Last {n} events",
        label_visibility="collapsed",
    )

@st.cache_data(ttl=15, show_spinner=False)
def _activity(n):
    return get_recent_activity(n)

with st.spinner("Loading activity log…"):
    activity = _activity(limit)

if not activity:
    empty_state("No activity found", "Platform activity will appear here as events occur.", "📜")
    st.stop()

ICONS = {
    "booking": "📋",
    "user":    "👤",
    "service": "🔧",
    "vehicle": "🚛",
}

for item in activity:
    event_type = item.get("type", "event")
    actor      = item.get("actor", "—")
    detail     = item.get("detail", "—") or "—"
    status     = item.get("status", "")
    ts         = fmt_datetime(item.get("timestamp"))
    event_id   = str(item.get("id", ""))[:8]
    icon       = ICONS.get(event_type, "📌")
    badge      = status_badge(status) if status else ""

    st.markdown(
        f"""
        <div style="display:flex;align-items:flex-start;gap:14px;
                    padding:12px 0;border-bottom:1px solid {BORDER};">
          <div style="width:36px;height:36px;border-radius:9px;flex-shrink:0;
                      background:#F7FAFC;border:1px solid {BORDER};
                      display:flex;align-items:center;justify-content:center;
                      font-size:16px;">{icon}</div>
          <div style="flex:1;min-width:0;">
            <div style="font-size:13px;color:{TEXT_PRIMARY};">
              <b>{actor}</b>
              <span style="color:{TEXT_SEC};font-weight:400;"> — {detail}</span>
            </div>
            <div style="font-size:11px;color:#A0AEC0;margin-top:3px;">
              {event_type.upper()} &nbsp;·&nbsp; ID: {event_id}… &nbsp;·&nbsp; {ts}
            </div>
          </div>
          <div style="flex-shrink:0;">{badge}</div>
        </div>
        """,
        unsafe_allow_html=True,
    )
