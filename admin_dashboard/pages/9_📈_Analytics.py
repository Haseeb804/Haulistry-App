"""
Advanced analytics — booking trends, revenue, categories, provider performance.
"""

import streamlit as st
import pandas as pd
from components.sidebar import render_sidebar
from core.database import (
    get_bookings_trend, get_bookings_by_status, get_daily_revenue,
    get_revenue_by_category, get_services_by_category, get_top_providers,
    get_platform_stats,
)
from components.styles import (
    page_header, fmt_currency, fmt_number,
    section_header, kpi_card,
    PRIMARY, SECONDARY, ACCENT, SUCCESS, WARNING, CARD_BG, BORDER, TEXT_PRIMARY,
)
from components.charts import (
    bookings_line_chart, revenue_line_chart, status_donut,
    category_bar, revenue_by_category_bar, top_providers_bar,
)

st.set_page_config(page_title="Analytics · Haulistry Admin", page_icon="📈", layout="wide")
render_sidebar()

page_header("Analytics", "Deep-dive platform analytics and trends", "📈")

col_days, _ = st.columns([2, 3])
with col_days:
    days = st.selectbox(
        "Period",
        [7, 14, 30, 60, 90],
        index=2,
        format_func=lambda d: f"Last {d} days",
        label_visibility="collapsed",
    )

@st.cache_data(ttl=120, show_spinner=False)
def _load(d):
    return {
        "trend":     get_bookings_trend(d),
        "status":    get_bookings_by_status(),
        "daily_rev": get_daily_revenue(d),
        "rev_cat":   get_revenue_by_category(),
        "svc_cat":   get_services_by_category(),
        "top_prov":  get_top_providers(10),
        "stats":     get_platform_stats(),
    }

with st.spinner("Loading analytics…"):
    data = _load(days)

stats = data["stats"]

# ── Platform summary KPIs ─────────────────────────────────────────────────────
section_header("Platform Summary")
cols = st.columns(4)
summary_kpis = [
    ("Total Users",    fmt_number(stats.get("totalUsers", 0)),        PRIMARY),
    ("Active Providers",fmt_number(stats.get("activeProviders", 0)),   SUCCESS),
    ("Total Bookings", fmt_number(stats.get("totalBookings", 0)),      ACCENT),
    ("Pending Verif.", fmt_number(stats.get("pendingVerifications", 0)),WARNING),
]
for col, (label, value, color) in zip(cols, summary_kpis):
    with col:
        st.markdown(kpi_card(label, value, color=color), unsafe_allow_html=True)

st.markdown("<div style='height:20px'></div>", unsafe_allow_html=True)

# ── Booking Trends ────────────────────────────────────────────────────────────
section_header("Booking Trends")
col1, col2 = st.columns([3, 2])

def _chart_card(fig, col):
    with col:
        st.markdown(
            f'<div style="background:{CARD_BG};border:1px solid {BORDER};'
            f'border-radius:14px;padding:18px 20px;'
            f'box-shadow:0 1px 4px rgba(0,0,0,.04);">',
            unsafe_allow_html=True,
        )
        st.plotly_chart(fig, use_container_width=True, config={"displayModeBar": False})
        st.markdown("</div>", unsafe_allow_html=True)

_chart_card(bookings_line_chart(data["trend"]), col1)
_chart_card(status_donut(data["status"], "Booking Status"), col2)

st.markdown("<div style='height:12px'></div>", unsafe_allow_html=True)

# ── Revenue ───────────────────────────────────────────────────────────────────
section_header("Revenue")
st.markdown(
    f'<div style="background:{CARD_BG};border:1px solid {BORDER};'
    f'border-radius:14px;padding:18px 20px;margin-bottom:12px;'
    f'box-shadow:0 1px 4px rgba(0,0,0,.04);">',
    unsafe_allow_html=True,
)
st.plotly_chart(revenue_line_chart(data["daily_rev"]), use_container_width=True,
               config={"displayModeBar": False})
st.markdown("</div>", unsafe_allow_html=True)

st.markdown(
    f'<div style="background:{CARD_BG};border:1px solid {BORDER};'
    f'border-radius:14px;padding:18px 20px;margin-bottom:20px;'
    f'box-shadow:0 1px 4px rgba(0,0,0,.04);">',
    unsafe_allow_html=True,
)
st.plotly_chart(revenue_by_category_bar(data["rev_cat"]), use_container_width=True,
               config={"displayModeBar": False})
st.markdown("</div>", unsafe_allow_html=True)

# ── Services & Providers ──────────────────────────────────────────────────────
section_header("Services & Providers")
col3, col4 = st.columns(2)

fig_svc = category_bar(data["svc_cat"], x_col="category", y_col="count",
                        title="Active Services by Category")
_chart_card(fig_svc, col3)
_chart_card(top_providers_bar(data["top_prov"]), col4)

st.markdown("<div style='height:20px'></div>", unsafe_allow_html=True)

# ── Platform summary table ────────────────────────────────────────────────────
section_header("Platform Metrics Table")
summary_df = pd.DataFrame({
    "Metric": [
        "Total Users", "Total Providers", "Active Providers",
        "Total Seekers", "Total Bookings", "Completed Bookings",
        "Total Services", "Total Vehicles", "Pending Verifications",
    ],
    "Value": [
        fmt_number(stats.get("totalUsers", 0)),
        fmt_number(stats.get("totalProviders", 0)),
        fmt_number(stats.get("activeProviders", 0)),
        fmt_number(stats.get("totalSeekers", 0)),
        fmt_number(stats.get("totalBookings", 0)),
        fmt_number(stats.get("completedBookings", 0)),
        fmt_number(stats.get("totalServices", 0)),
        fmt_number(stats.get("totalVehicles", 0)),
        fmt_number(stats.get("pendingVerifications", 0)),
    ],
})
st.dataframe(summary_df, use_container_width=True, hide_index=True)
