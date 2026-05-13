"""
Vehicle fleet registry — all registered vehicles with filtering.
"""

import streamlit as st
from components.sidebar import render_sidebar
from core.database import get_all_vehicles
from components.styles import (
    page_header, status_badge, fmt_date,
    empty_state, kpi_card, pagination,
    PRIMARY, SECONDARY, ACCENT, SUCCESS, WARNING, TEXT_SEC, TEXT_PRIMARY, CARD_BG, BORDER,
)

st.set_page_config(page_title="Vehicles · Haulistry Admin", page_icon="🚛", layout="wide")
render_sidebar()

page_header("Vehicles", "Fleet registry — all registered vehicles", "🚛")

# ── Filters ───────────────────────────────────────────────────────────────────
col_search, col_type, col_avail = st.columns([3, 1, 1])
with col_search:
    search = st.text_input("Search vehicles",
                           placeholder="Provider name, vehicle number or model…",
                           label_visibility="collapsed")
with col_type:
    TYPES = ["All", "towing_truck", "crane", "bulldozer", "dumper",
             "forklift", "harvester", "excavator"]
    type_filter = st.selectbox("Type", TYPES, label_visibility="collapsed",
                               format_func=lambda x: x.replace("_", " ").title())
with col_avail:
    avail_filter = st.selectbox("Availability", ["All", "Available", "Unavailable"],
                                label_visibility="collapsed")

@st.cache_data(ttl=60, show_spinner=False)
def _vehicles():
    return get_all_vehicles(size=300)

all_vehicles = _vehicles()

# Apply filters
rows = all_vehicles
if search:
    q = search.lower()
    rows = [v for v in rows if (q in str(v.get("providerName", "")).lower()
                                or q in str(v.get("vehicleNumber", "")).lower()
                                or q in str(v.get("vehicleModel", "")).lower())]
if type_filter != "All":
    rows = [v for v in rows if v.get("vehicleType", "") == type_filter]
if avail_filter == "Available":
    rows = [v for v in rows if v.get("isAvailable")]
elif avail_filter == "Unavailable":
    rows = [v for v in rows if not v.get("isAvailable")]

# ── Summary KPIs ──────────────────────────────────────────────────────────────
total      = len(all_vehicles)
available  = sum(1 for v in all_vehicles if v.get("isAvailable"))
verified   = sum(1 for v in all_vehicles if v.get("isVerified"))
type_count = len({v.get("vehicleType", "unknown") for v in all_vehicles})

sc1, sc2, sc3, sc4 = st.columns(4)
with sc1:
    st.markdown(kpi_card("Total Vehicles", str(total),     color=PRIMARY),   unsafe_allow_html=True)
with sc2:
    st.markdown(kpi_card("Available",      str(available), color=SUCCESS),   unsafe_allow_html=True)
with sc3:
    st.markdown(kpi_card("Verified",       str(verified),  color=SECONDARY), unsafe_allow_html=True)
with sc4:
    st.markdown(kpi_card("Vehicle Types",  str(type_count),color=ACCENT),    unsafe_allow_html=True)

st.markdown("<div style='height:16px'></div>", unsafe_allow_html=True)

st.markdown(
    f'<div style="font-size:13px;color:{TEXT_SEC};margin-bottom:12px;">'
    f'Showing <b style="color:{TEXT_PRIMARY};">{len(rows)}</b> of {total} vehicles</div>',
    unsafe_allow_html=True,
)

if not rows:
    empty_state("No vehicles match your filters", "Try adjusting the type or availability filter.", "🔍")
    st.stop()

# ── Header row ────────────────────────────────────────────────────────────────
st.markdown(
    f'<div style="display:flex;padding:8px 0;border-bottom:2px solid {BORDER};'
    f'font-size:11px;font-weight:700;color:{TEXT_SEC};'
    f'text-transform:uppercase;letter-spacing:.5px;">'
    f'<div style="flex:2;">Vehicle</div>'
    f'<div style="flex:2;">Details</div>'
    f'<div style="flex:2;">Provider</div>'
    f'<div style="flex:2;">Status</div>'
    f'</div>',
    unsafe_allow_html=True,
)

# ── Rows ──────────────────────────────────────────────────────────────────────
PAGE_SIZE = 25
page_key  = "vehicles_page"
if page_key not in st.session_state:
    st.session_state[page_key] = 0
current_page = st.session_state[page_key]
paged = rows[current_page * PAGE_SIZE: (current_page + 1) * PAGE_SIZE]

VEHICLE_ICONS = {
    "towing_truck": "🚛", "crane": "🏗️", "bulldozer": "🚜",
    "dumper": "🚚", "forklift": "🏭", "harvester": "🌾",
    "excavator": "⛏️",
}

for v in paged:
    vtype    = v.get("vehicleType", "unknown")
    number   = v.get("vehicleNumber", "—")
    model    = v.get("vehicleModel", "—")
    year     = v.get("vehicleYear", "—")
    capacity = v.get("capacity", "—")
    provider = v.get("providerName", "—")
    is_avail = v.get("isAvailable", False)
    is_ver   = v.get("isVerified", False)
    added    = fmt_date(v.get("createdAt"))
    icon     = VEHICLE_ICONS.get(vtype, "🚗")
    type_label = vtype.replace("_", " ").title()

    c_vehicle, c_details, c_provider, c_status = st.columns([2, 2, 2, 2])

    with c_vehicle:
        st.markdown(
            f'<div style="display:flex;align-items:center;gap:10px;padding:10px 0;">'
            f'<div style="width:38px;height:38px;border-radius:9px;flex-shrink:0;'
            f'background:linear-gradient(135deg,{PRIMARY}15,{ACCENT}15);'
            f'display:flex;align-items:center;justify-content:center;font-size:18px;">'
            f'{icon}</div>'
            f'<div>'
            f'<div style="font-weight:700;color:{TEXT_PRIMARY};font-size:13.5px;">{number}</div>'
            f'<div style="font-size:12px;color:{TEXT_SEC};margin-top:2px;">{type_label}</div>'
            f'</div></div>',
            unsafe_allow_html=True,
        )
    with c_details:
        st.markdown(
            f'<div style="padding:10px 0;">'
            f'<div style="font-size:13px;color:{TEXT_PRIMARY};">{model}</div>'
            f'<div style="font-size:12px;color:{TEXT_SEC};margin-top:3px;">'
            f'Year: {year} &nbsp;·&nbsp; Cap: {capacity}</div>'
            f'<div style="font-size:11px;color:#A0AEC0;margin-top:2px;">Added {added}</div>'
            f'</div>',
            unsafe_allow_html=True,
        )
    with c_provider:
        st.markdown(
            f'<div style="padding:12px 0;font-size:13px;color:{TEXT_PRIMARY};'
            f'font-weight:600;">{provider}</div>',
            unsafe_allow_html=True,
        )
    with c_status:
        avail_badge = status_badge("active" if is_avail else "inactive")
        ver_badge   = status_badge("verified" if is_ver else "unverified")
        st.markdown(
            f'<div style="padding:12px 0;display:flex;flex-direction:column;gap:5px;">'
            f'{avail_badge}{ver_badge}</div>',
            unsafe_allow_html=True,
        )

    st.markdown(f'<div style="border-bottom:1px solid {BORDER};"></div>', unsafe_allow_html=True)

pagination(page_key, len(rows), PAGE_SIZE)
