"""
Service catalogue management — view, filter, toggle active/inactive.
"""

import streamlit as st
from components.sidebar import render_sidebar
from core.database import get_all_services, toggle_service_status, get_services_by_category
from components.styles import (
    page_header, status_badge, fmt_date,
    fmt_currency, empty_state, kpi_card, pagination,
    PRIMARY, SECONDARY, ACCENT, SUCCESS, WARNING, TEXT_SEC, TEXT_PRIMARY, CARD_BG, BORDER,
)
from components.charts import category_bar

st.set_page_config(page_title="Services · Haulistry Admin", page_icon="🔧", layout="wide")
render_sidebar()

page_header("Services", "Browse and manage the service catalogue", "🔧")

# ── Filters ───────────────────────────────────────────────────────────────────
col_search, col_cat, col_status = st.columns([3, 1, 1])
with col_search:
    search = st.text_input("Search services", placeholder="Service name or provider…",
                           label_visibility="collapsed")
with col_cat:
    CATEGORIES = ["All", "towing", "crane", "bulldozer", "dumper",
                  "forklift", "harvester", "excavator", "other"]
    cat_filter = st.selectbox("Category", CATEGORIES, label_visibility="collapsed")
with col_status:
    status_filter = st.selectbox("Status", ["All", "Active", "Inactive"],
                                 label_visibility="collapsed")

@st.cache_data(ttl=60, show_spinner=False)
def _services():
    return get_all_services(size=200)

@st.cache_data(ttl=120, show_spinner=False)
def _by_cat():
    return get_services_by_category()

all_services = _services()

# Apply filters
rows = all_services
if search:
    q = search.lower()
    rows = [s for s in rows if (q in str(s.get("name", "")).lower()
                                or q in str(s.get("providerName", "")).lower())]
if cat_filter != "All":
    rows = [s for s in rows if s.get("category", "") == cat_filter]
if status_filter == "Active":
    rows = [s for s in rows if s.get("isActive")]
elif status_filter == "Inactive":
    rows = [s for s in rows if not s.get("isActive")]

# ── Summary KPIs ──────────────────────────────────────────────────────────────
total      = len(all_services)
active_ct  = sum(1 for s in all_services if s.get("isActive"))
inactive_ct = total - active_ct
cats_seen  = len({s.get("category", "other") for s in all_services})

sc1, sc2, sc3, sc4 = st.columns(4)
with sc1:
    st.markdown(kpi_card("Total Services", str(total),      color=PRIMARY),  unsafe_allow_html=True)
with sc2:
    st.markdown(kpi_card("Active",         str(active_ct),  color=SUCCESS),  unsafe_allow_html=True)
with sc3:
    st.markdown(kpi_card("Inactive",       str(inactive_ct),color=WARNING),  unsafe_allow_html=True)
with sc4:
    st.markdown(kpi_card("Categories",     str(cats_seen),  color=ACCENT),   unsafe_allow_html=True)

st.markdown("<div style='height:16px'></div>", unsafe_allow_html=True)

# ── Category chart ────────────────────────────────────────────────────────────
with st.expander("Category Distribution", expanded=False):
    cat_data = _by_cat()
    fig = category_bar(cat_data, x_col="category", y_col="count",
                       title="Active Services by Category")
    st.plotly_chart(fig, use_container_width=True, config={"displayModeBar": False})

st.markdown(
    f'<div style="font-size:13px;color:{TEXT_SEC};margin-bottom:12px;">'
    f'Showing <b style="color:{TEXT_PRIMARY};">{len(rows)}</b> of {total} services</div>',
    unsafe_allow_html=True,
)

if not rows:
    empty_state("No services match your filters", "Try adjusting the category or status filter.", "🔍")
    st.stop()

# ── Header ─────────────────────────────────────────────────────────────────────
st.markdown(
    f'<div style="display:flex;padding:8px 0;border-bottom:2px solid {BORDER};'
    f'font-size:11px;font-weight:700;color:{TEXT_SEC};'
    f'text-transform:uppercase;letter-spacing:.5px;">'
    f'<div style="flex:3;">Service / Provider</div>'
    f'<div style="flex:2;">Pricing</div>'
    f'<div style="flex:2;">Category & Status</div>'
    f'<div style="flex:1;text-align:right;">Action</div>'
    f'</div>',
    unsafe_allow_html=True,
)

# ── Rows ──────────────────────────────────────────────────────────────────────
PAGE_SIZE = 20
page_key  = "services_page"
if page_key not in st.session_state:
    st.session_state[page_key] = 0
current_page = st.session_state[page_key]
paged = rows[current_page * PAGE_SIZE: (current_page + 1) * PAGE_SIZE]

for svc in paged:
    sid       = svc.get("id", "")
    name      = svc.get("name", "—")
    category  = svc.get("category", "—")
    provider  = svc.get("providerName", "—")
    vehicle   = svc.get("vehicleType", "—")
    base      = svc.get("basePrice") or 0
    per_km    = svc.get("pricePerKm") or 0
    per_hr    = svc.get("pricePerHour") or 0
    is_active = svc.get("isActive", True)
    created   = fmt_date(svc.get("createdAt"))

    c_info, c_price, c_badge, c_action = st.columns([3, 2, 2, 1])

    with c_info:
        vtype_label = vehicle.replace("_", " ").title() if vehicle and vehicle != "—" else "—"
        st.markdown(
            f'<div style="padding:10px 0;">'
            f'<div style="font-weight:700;color:{TEXT_PRIMARY};font-size:13.5px;">{name}</div>'
            f'<div style="font-size:12px;color:{TEXT_SEC};margin-top:3px;">'
            f'By <b>{provider}</b> &nbsp;·&nbsp; {vtype_label}</div>'
            f'<div style="font-size:11px;color:#A0AEC0;margin-top:2px;">Added {created}</div>'
            f'</div>',
            unsafe_allow_html=True,
        )
    with c_price:
        st.markdown(
            f'<div style="padding:10px 0;">'
            f'<div style="font-weight:700;color:{TEXT_PRIMARY};font-size:13.5px;">'
            f'{fmt_currency(base)}</div>'
            f'<div style="font-size:12px;color:{TEXT_SEC};margin-top:3px;">'
            f'{fmt_currency(per_km)}/km &nbsp;·&nbsp; {fmt_currency(per_hr)}/hr</div>'
            f'</div>',
            unsafe_allow_html=True,
        )
    with c_badge:
        cat_label = category.replace("_", " ").title()
        st.markdown(
            f'<div style="padding:12px 0;display:flex;align-items:center;gap:6px;flex-wrap:wrap;">'
            f'<span style="background:#EBF4FF;color:#2B6CB0;padding:3px 10px;'
            f'border-radius:20px;font-size:11.5px;font-weight:600;">{cat_label}</span>'
            f'{status_badge("active" if is_active else "inactive")}'
            f'</div>',
            unsafe_allow_html=True,
        )
    with c_action:
        st.markdown("<div style='padding-top:8px;'></div>", unsafe_allow_html=True)
        lbl = "Deactivate" if is_active else "Activate"
        if st.button(lbl, key=f"toggle_{sid}", use_container_width=True):
            ok = toggle_service_status(sid, not is_active)
            if ok:
                st.toast(f"Service {'deactivated' if is_active else 'activated'}.", icon="✅")
                st.cache_data.clear()
                st.rerun()
            else:
                st.warning("Action failed.")

    st.markdown(f'<div style="border-bottom:1px solid {BORDER};"></div>', unsafe_allow_html=True)

pagination(page_key, len(rows), PAGE_SIZE)
