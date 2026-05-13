"""
Main platform dashboard — KPIs, charts, recent activity.
"""

import streamlit as st
from components.sidebar import render_sidebar
from core.database import (
    get_platform_stats, get_revenue_stats, get_bookings_trend,
    get_bookings_by_status, get_daily_revenue, get_recent_activity,
    get_top_providers, is_connected,
)
from components.styles import (
    page_header, fmt_currency, fmt_number, fmt_datetime,
    status_badge, empty_state, section_header, kpi_card,
    PRIMARY, SECONDARY, ACCENT, WARNING, SUCCESS, TEXT_SEC, CARD_BG, BORDER,
)
from components.charts import (
    bookings_line_chart, revenue_line_chart, status_donut,
    top_providers_bar,
)

st.set_page_config(page_title="Dashboard · Haulistry Admin", page_icon="📊", layout="wide")
render_sidebar()

page_header("Dashboard", "Platform-wide KPIs and real-time activity overview", "📊")

# ── Trend window selector ─────────────────────────────────────────────────────
col_title, col_ctrl = st.columns([5, 1])
with col_ctrl:
    trend_days = st.selectbox(
        "Period",
        [7, 14, 30, 60, 90],
        index=2,
        format_func=lambda d: f"Last {d}d",
    )

# ── Data loaders ──────────────────────────────────────────────────────────────
@st.cache_data(ttl=60, show_spinner=False)
def _stats():       return get_platform_stats()

@st.cache_data(ttl=60, show_spinner=False)
def _rev():         return get_revenue_stats()

@st.cache_data(ttl=120, show_spinner=False)
def _trend(d):      return get_bookings_trend(d)

@st.cache_data(ttl=120, show_spinner=False)
def _daily_rev(d):  return get_daily_revenue(d)

@st.cache_data(ttl=60, show_spinner=False)
def _status_data(): return get_bookings_by_status()

@st.cache_data(ttl=120, show_spinner=False)
def _activity():    return get_recent_activity(20)

@st.cache_data(ttl=120, show_spinner=False)
def _top_prov():    return get_top_providers(8)

with st.spinner("Loading dashboard…"):
    stats = _stats()
    rev   = _rev()

# ── DB offline notice ─────────────────────────────────────────────────────────
if not is_connected():
    st.warning("Database is offline — metrics may be stale or empty.")

# ── KPI Row 1 ─────────────────────────────────────────────────────────────────
c1, c2, c3, c4 = st.columns(4)
kpi_data = [
    (c1, "Total Users",          fmt_number(stats.get("totalUsers", 0)),      PRIMARY,   "👥"),
    (c2, "Total Providers",      fmt_number(stats.get("totalProviders", 0)),   ACCENT,    "👷"),
    (c3, "Total Seekers",        fmt_number(stats.get("totalSeekers", 0)),     SECONDARY, "👤"),
    (c4, "Pending Verifications",fmt_number(stats.get("pendingVerifications", 0)), WARNING, "⏳"),
]
for col, label, value, color, icon in kpi_data:
    with col:
        st.markdown(kpi_card(label, value, icon=icon, color=color), unsafe_allow_html=True)

st.markdown("<div style='height:12px'></div>", unsafe_allow_html=True)

# ── KPI Row 2 ─────────────────────────────────────────────────────────────────
c5, c6, c7, c8 = st.columns(4)
kpi_data2 = [
    (c5, "Total Bookings",    fmt_number(stats.get("totalBookings", 0)),     "#6C5CE7", "📋"),
    (c6, "Completed Bookings",fmt_number(stats.get("completedBookings", 0)), SUCCESS,   "✅"),
    (c7, "Total Revenue",     fmt_currency(rev.get("totalRevenue", 0)),      SECONDARY, "💰"),
    (c8, "Avg Booking Value", fmt_currency(rev.get("avgBookingValue", 0)),   PRIMARY,   "📈"),
]
for col, label, value, color, icon in kpi_data2:
    with col:
        st.markdown(kpi_card(label, value, icon=icon, color=color), unsafe_allow_html=True)

st.markdown("<div style='height:20px'></div>", unsafe_allow_html=True)

# ── Charts Row ────────────────────────────────────────────────────────────────
ch1, ch2 = st.columns([3, 2])

with ch1:
    st.markdown(
        f'<div style="background:{CARD_BG};border:1px solid {BORDER};'
        f'border-radius:14px;padding:20px 22px;box-shadow:0 1px 4px rgba(0,0,0,.04);">',
        unsafe_allow_html=True,
    )
    booking_trend = _trend(trend_days)
    fig = bookings_line_chart(booking_trend)
    st.plotly_chart(fig, use_container_width=True, config={"displayModeBar": False})
    st.markdown("</div>", unsafe_allow_html=True)

with ch2:
    st.markdown(
        f'<div style="background:{CARD_BG};border:1px solid {BORDER};'
        f'border-radius:14px;padding:20px 22px;box-shadow:0 1px 4px rgba(0,0,0,.04);">',
        unsafe_allow_html=True,
    )
    status_data = _status_data()
    fig2 = status_donut(status_data, "Booking Status Distribution")
    st.plotly_chart(fig2, use_container_width=True, config={"displayModeBar": False})
    st.markdown("</div>", unsafe_allow_html=True)

st.markdown("<div style='height:12px'></div>", unsafe_allow_html=True)

# ── Revenue chart ─────────────────────────────────────────────────────────────
st.markdown(
    f'<div style="background:{CARD_BG};border:1px solid {BORDER};'
    f'border-radius:14px;padding:20px 22px;box-shadow:0 1px 4px rgba(0,0,0,.04);">',
    unsafe_allow_html=True,
)
daily_rev = _daily_rev(trend_days)
fig3 = revenue_line_chart(daily_rev)
st.plotly_chart(fig3, use_container_width=True, config={"displayModeBar": False})
st.markdown("</div>", unsafe_allow_html=True)

st.markdown("<div style='height:20px'></div>", unsafe_allow_html=True)

# ── Top Providers + Recent Activity ──────────────────────────────────────────
left, right = st.columns([5, 6])

with left:
    st.markdown(
        f'<div style="background:{CARD_BG};border:1px solid {BORDER};'
        f'border-radius:14px;padding:20px 22px;box-shadow:0 1px 4px rgba(0,0,0,.04);">',
        unsafe_allow_html=True,
    )
    top_prov = _top_prov()
    fig4 = top_providers_bar(top_prov)
    st.plotly_chart(fig4, use_container_width=True, config={"displayModeBar": False})
    st.markdown("</div>", unsafe_allow_html=True)

with right:
    st.markdown(
        f'<div style="background:{CARD_BG};border:1px solid {BORDER};'
        f'border-radius:14px;padding:20px 22px;box-shadow:0 1px 4px rgba(0,0,0,.04);">',
        unsafe_allow_html=True,
    )
    st.markdown(
        f'<div style="font-size:14px;font-weight:700;color:#1A202C;margin-bottom:14px;">'
        f'Recent Activity</div>',
        unsafe_allow_html=True,
    )
    activity = _activity()
    if activity:
        for item in activity:
            ts     = fmt_datetime(item.get("timestamp"))
            actor  = item.get("actor", "—")
            detail = item.get("detail", "—")
            status = item.get("status", "")
            badge  = status_badge(status) if status else ""
            st.markdown(
                f"""
                <div style="display:flex;align-items:center;gap:12px;
                            padding:9px 0;border-bottom:1px solid #EDF2F7;">
                  <div style="font-size:11px;color:{TEXT_SEC};white-space:nowrap;
                              min-width:70px;">{ts}</div>
                  <div style="flex:1;min-width:0;">
                    <div style="font-weight:600;color:#1A202C;font-size:13px;
                                white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">
                      {actor}
                    </div>
                    <div style="color:{TEXT_SEC};font-size:12px;margin-top:1px;
                                white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">
                      {detail}
                    </div>
                  </div>
                  {badge}
                </div>
                """,
                unsafe_allow_html=True,
            )
    else:
        empty_state("No recent activity", "Booking activity will appear here", "📭")
    st.markdown("</div>", unsafe_allow_html=True)
