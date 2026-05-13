"""
Live booking tracker with status filters, search, and pagination.
"""

import streamlit as st
from components.sidebar import render_sidebar
from core.database import get_all_bookings
from components.styles import (
    page_header, status_badge, fmt_date, fmt_datetime,
    fmt_currency, empty_state, kpi_card, pagination,
    PRIMARY, SECONDARY, ACCENT, SUCCESS, WARNING, DANGER,
    TEXT_SEC, TEXT_PRIMARY, CARD_BG, BORDER,
)

st.set_page_config(page_title="Bookings · Haulistry Admin", page_icon="📋", layout="wide")
render_sidebar()

STATUS_OPTIONS = [
    "All", "pending", "accepted", "active",
    "provider_arriving", "provider_arrived",
    "in_progress", "completed", "cancelled", "rejected",
]

# ── Filters ───────────────────────────────────────────────────────────────────
page_header("Bookings", "Monitor all platform bookings in real time", "📋")

col_search, col_status = st.columns([4, 1])
with col_search:
    search = st.text_input("Search bookings",
                           placeholder="Seeker, provider or service type…",
                           label_visibility="collapsed")
with col_status:
    status_filter = st.selectbox(
        "Status", STATUS_OPTIONS, label_visibility="collapsed",
        format_func=lambda s: s.replace("_", " ").title(),
    )

@st.cache_data(ttl=30, show_spinner=False)
def _bookings(s):
    return get_all_bookings(status=s if s != "All" else None, size=300)

with st.spinner("Loading bookings…"):
    all_bookings = _bookings(status_filter)

if search:
    q = search.lower()
    all_bookings = [b for b in all_bookings
                    if (q in str(b.get("seekerName", "")).lower()
                        or q in str(b.get("providerName", "")).lower()
                        or q in str(b.get("serviceType", "")).lower())]

# ── Summary KPIs ──────────────────────────────────────────────────────────────
@st.cache_data(ttl=30, show_spinner=False)
def _all_for_stats():
    return get_all_bookings(size=500)

stats_data = _all_for_stats()
total_ct     = len(stats_data)
pending_ct   = sum(1 for b in stats_data if b.get("status") == "pending")
active_ct    = sum(1 for b in stats_data if b.get("status") in ("active", "in_progress", "provider_arriving", "provider_arrived"))
completed_ct = sum(1 for b in stats_data if b.get("status") == "completed")

sc1, sc2, sc3, sc4 = st.columns(4)
with sc1:
    st.markdown(kpi_card("Total Bookings",    str(total_ct),     color=PRIMARY),  unsafe_allow_html=True)
with sc2:
    st.markdown(kpi_card("Pending",           str(pending_ct),   color=WARNING),  unsafe_allow_html=True)
with sc3:
    st.markdown(kpi_card("Active Now",        str(active_ct),    color=ACCENT),   unsafe_allow_html=True)
with sc4:
    st.markdown(kpi_card("Completed",         str(completed_ct), color=SUCCESS),  unsafe_allow_html=True)

st.markdown("<div style='height:16px'></div>", unsafe_allow_html=True)

st.markdown(
    f'<div style="font-size:13px;color:{TEXT_SEC};margin-bottom:12px;">'
    f'Showing <b style="color:{TEXT_PRIMARY};">{len(all_bookings)}</b> bookings</div>',
    unsafe_allow_html=True,
)

if not all_bookings:
    empty_state("No bookings found", "Try a different status filter or search term.", "📭")
    st.stop()

# ── Header ────────────────────────────────────────────────────────────────────
st.markdown(
    f'<div style="display:flex;padding:8px 0;border-bottom:2px solid {BORDER};'
    f'font-size:11px;font-weight:700;color:{TEXT_SEC};'
    f'text-transform:uppercase;letter-spacing:.5px;">'
    f'<div style="flex:2;">Seeker / Date</div>'
    f'<div style="flex:2;">Provider</div>'
    f'<div style="flex:2;">Service</div>'
    f'<div style="flex:1.5;">Status</div>'
    f'<div style="flex:1;text-align:right;">Price</div>'
    f'</div>',
    unsafe_allow_html=True,
)

# ── Rows ──────────────────────────────────────────────────────────────────────
PAGE_SIZE = 25
page_key  = "bookings_page"
if page_key not in st.session_state:
    st.session_state[page_key] = 0

# Reset page if filter changed
filter_cache_key = f"bookings_filter_{status_filter}_{search}"
if st.session_state.get("_bookings_last_filter") != filter_cache_key:
    st.session_state[page_key] = 0
    st.session_state["_bookings_last_filter"] = filter_cache_key

current_page = st.session_state[page_key]
paged = all_bookings[current_page * PAGE_SIZE: (current_page + 1) * PAGE_SIZE]

for b in paged:
    bid     = b.get("id", "")
    seeker  = b.get("seekerName", "—")
    prov    = b.get("providerName", "—")
    stype   = b.get("serviceType", "—")
    status  = b.get("status", "—")
    price   = b.get("estimatedPrice") or b.get("finalPrice") or 0
    created = fmt_datetime(b.get("createdAt"))

    c_seeker, c_prov, c_svc, c_badge, c_price = st.columns([2, 2, 2, 1.5, 1])

    with c_seeker:
        bid_short = bid[:8] if bid else "—"
        st.markdown(
            f'<div style="padding:10px 0;">'
            f'<div style="font-weight:600;color:{TEXT_PRIMARY};font-size:13px;">{seeker}</div>'
            f'<div style="font-size:11px;color:#A0AEC0;margin-top:2px;">'
            f'{created} &nbsp;·&nbsp; <code style="font-size:10px;">{bid_short}…</code>'
            f'</div></div>',
            unsafe_allow_html=True,
        )
    with c_prov:
        st.markdown(
            f'<div style="padding:12px 0;font-size:13px;color:{TEXT_PRIMARY};">{prov}</div>',
            unsafe_allow_html=True,
        )
    with c_svc:
        stype_label = stype.replace("_", " ").title() if stype and stype != "—" else "—"
        st.markdown(
            f'<div style="padding:12px 0;font-size:13px;color:{TEXT_SEC};">{stype_label}</div>',
            unsafe_allow_html=True,
        )
    with c_badge:
        st.markdown(
            f'<div style="padding:12px 0;">{status_badge(status)}</div>',
            unsafe_allow_html=True,
        )
    with c_price:
        st.markdown(
            f'<div style="padding:12px 0;font-weight:700;font-size:13px;'
            f'color:{TEXT_PRIMARY};text-align:right;">{fmt_currency(price)}</div>',
            unsafe_allow_html=True,
        )

    st.markdown(f'<div style="border-bottom:1px solid {BORDER};"></div>', unsafe_allow_html=True)

pagination(page_key, len(all_bookings), PAGE_SIZE)
