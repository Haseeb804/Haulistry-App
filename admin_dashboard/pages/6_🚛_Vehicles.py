"""
Vehicle fleet registry — all registered vehicles + post-verification monitoring.
"""

import streamlit as st
from components.sidebar import render_sidebar
from core.database import (
    get_all_vehicles,
    get_post_verification_vehicles,
    mark_vehicle_reviewed,
)
from components.styles import (
    page_header, status_badge, fmt_date,
    empty_state, kpi_card, pagination,
    PRIMARY, SECONDARY, ACCENT, SUCCESS, WARNING, DANGER,
    TEXT_SEC, TEXT_PRIMARY, CARD_BG, BORDER,
)

st.set_page_config(page_title="Vehicles · Haulistry Admin", page_icon="🚛", layout="wide")
render_sidebar()

page_header("Vehicles", "Fleet registry — all registered vehicles", "🚛")

# ── Tabs ──────────────────────────────────────────────────────────────────────
@st.cache_data(ttl=30, show_spinner=False)
def _post_verification_vehicles():
    return get_post_verification_vehicles()

_post_veh = _post_verification_vehicles()
_pending_review = [v for v in _post_veh if not v.get("adminReviewed", False)]

tab_label_all    = "🚛  All Vehicles"
tab_label_review = (
    f"🔔  Post-Verification Additions  ({len(_pending_review)} pending)"
    if _pending_review else
    "✅  Post-Verification Additions"
)

tab_all, tab_review = st.tabs([tab_label_all, tab_label_review])


# ══════════════════════════════════════════════════════════════════════════════
# TAB 1 — ALL VEHICLES
# ══════════════════════════════════════════════════════════════════════════════
with tab_all:
    # ── Filters ───────────────────────────────────────────────────────────────
    col_search, col_type, col_avail, col_ver = st.columns([3, 1, 1, 1])
    with col_search:
        search = st.text_input(
            "Search vehicles",
            placeholder="Provider name, vehicle number or model…",
            label_visibility="collapsed",
            key="all_search",
        )
    with col_type:
        TYPES = ["All", "towing_truck", "crane", "bulldozer", "dumper",
                 "forklift", "harvester", "excavator", "sand_trolley"]
        type_filter = st.selectbox(
            "Type", TYPES, label_visibility="collapsed",
            format_func=lambda x: x.replace("_", " ").title(),
            key="all_type",
        )
    with col_avail:
        avail_filter = st.selectbox(
            "Availability", ["All", "Available", "Unavailable"],
            label_visibility="collapsed", key="all_avail",
        )
    with col_ver:
        ver_filter = st.selectbox(
            "Verification", ["All", "Verified", "Unverified"],
            label_visibility="collapsed", key="all_ver",
        )

    @st.cache_data(ttl=60, show_spinner=False)
    def _all_vehicles():
        return get_all_vehicles(size=500)

    all_vehicles = _all_vehicles()

    # Apply filters
    rows = all_vehicles
    if search:
        q = search.lower()
        rows = [v for v in rows if (
            q in str(v.get("providerName", "")).lower()
            or q in str(v.get("vehicleNumber", "")).lower()
            or q in str(v.get("vehicleModel", "")).lower()
        )]
    if type_filter != "All":
        rows = [v for v in rows if v.get("vehicleType", "") == type_filter]
    if avail_filter == "Available":
        rows = [v for v in rows if v.get("isAvailable")]
    elif avail_filter == "Unavailable":
        rows = [v for v in rows if not v.get("isAvailable")]
    if ver_filter == "Verified":
        rows = [v for v in rows if v.get("isVerified")]
    elif ver_filter == "Unverified":
        rows = [v for v in rows if not v.get("isVerified")]

    # ── KPIs ──────────────────────────────────────────────────────────────────
    total      = len(all_vehicles)
    available  = sum(1 for v in all_vehicles if v.get("isAvailable"))
    verified   = sum(1 for v in all_vehicles if v.get("isVerified"))
    post_ver   = sum(1 for v in all_vehicles if v.get("addedAfterVerification"))

    sc1, sc2, sc3, sc4 = st.columns(4)
    with sc1:
        st.markdown(kpi_card("Total Vehicles", str(total),    color=PRIMARY),   unsafe_allow_html=True)
    with sc2:
        st.markdown(kpi_card("Available",      str(available),color=SUCCESS),   unsafe_allow_html=True)
    with sc3:
        st.markdown(kpi_card("Verified",       str(verified), color=SECONDARY), unsafe_allow_html=True)
    with sc4:
        st.markdown(kpi_card("Post-Verification", str(post_ver), color=WARNING), unsafe_allow_html=True)

    st.markdown("<div style='height:16px'></div>", unsafe_allow_html=True)
    st.markdown(
        f'<div style="font-size:13px;color:{TEXT_SEC};margin-bottom:12px;">'
        f'Showing <b style="color:{TEXT_PRIMARY};">{len(rows)}</b> of {total} vehicles</div>',
        unsafe_allow_html=True,
    )

    if not rows:
        empty_state("No vehicles match your filters",
                    "Try adjusting the type or availability filter.", "🔍")
        st.stop()

    # ── Header row ────────────────────────────────────────────────────────────
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

    PAGE_SIZE = 25
    page_key  = "vehicles_page"
    if page_key not in st.session_state:
        st.session_state[page_key] = 0
    current_page = st.session_state[page_key]
    paged = rows[current_page * PAGE_SIZE: (current_page + 1) * PAGE_SIZE]

    VEHICLE_ICONS = {
        "towing_truck": "🚛", "crane": "🏗️", "bulldozer": "🚜",
        "dumper": "🚚", "forklift": "🏭", "harvester": "🌾",
        "excavator": "⛏️", "sand_trolley": "🚛",
    }

    for v in paged:
        vtype      = v.get("vehicleType", "unknown")
        number     = v.get("vehicleNumber", "—")
        model      = v.get("vehicleModel", "—")
        year       = v.get("vehicleYear", "—")
        capacity   = v.get("capacity", "—")
        provider   = v.get("providerName", "—")
        is_avail   = v.get("isAvailable", False)
        is_ver     = v.get("isVerified", False)
        post_v     = v.get("addedAfterVerification", False)
        added      = fmt_date(v.get("createdAt"))
        icon       = VEHICLE_ICONS.get(vtype, "🚗")
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
            post_badge = (
                f'<span style="background:#FFF3CD;color:#856404;font-size:10px;'
                f'font-weight:700;border-radius:4px;padding:2px 6px;margin-left:6px;">'
                f'POST-VER</span>'
            ) if post_v else ""
            st.markdown(
                f'<div style="padding:10px 0;">'
                f'<div style="font-size:13px;color:{TEXT_PRIMARY};">{model}{post_badge}</div>'
                f'<div style="font-size:12px;color:{TEXT_SEC};margin-top:3px;">'
                f'Year: {year} &nbsp;·&nbsp; Cap: {capacity}</div>'
                f'<div style="font-size:11px;color:#A0AEC0;margin-top:2px;">Added {added}</div>'
                f'</div>',
                unsafe_allow_html=True,
            )
        with c_provider:
            prov_ver = v.get("providerIsVerified", False)
            prov_badge = (
                f'<span style="background:#D4EDDA;color:#155724;font-size:10px;'
                f'font-weight:700;border-radius:4px;padding:1px 5px;margin-left:4px;">✓</span>'
            ) if prov_ver else ""
            st.markdown(
                f'<div style="padding:12px 0;font-size:13px;color:{TEXT_PRIMARY};'
                f'font-weight:600;">{provider}{prov_badge}</div>',
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


# ══════════════════════════════════════════════════════════════════════════════
# TAB 2 — POST-VERIFICATION ADDITIONS
# ══════════════════════════════════════════════════════════════════════════════
with tab_review:

    # ── Explanation banner ────────────────────────────────────────────────────
    st.markdown(
        f'<div style="background:linear-gradient(135deg,#EBF8FF,#E6F4FF);'
        f'border:1px solid #BEE3F8;border-radius:12px;padding:14px 20px;'
        f'margin-bottom:20px;display:flex;align-items:flex-start;gap:12px;">'
        f'<div style="width:38px;height:38px;border-radius:10px;flex-shrink:0;'
        f'background:rgba(49,130,206,.12);display:flex;align-items:center;'
        f'justify-content:center;font-size:18px;">ℹ️</div>'
        f'<div>'
        f'<div style="font-size:14px;font-weight:700;color:#1A365D;margin-bottom:3px;">'
        f'Auto-Verified — Monitoring Required</div>'
        f'<div style="font-size:12.5px;color:#2B6CB0;line-height:1.5;">'
        f'These vehicles were added by providers who were already verified at signup. '
        f'They have been <b>automatically marked as verified</b> — no re-verification is needed. '
        f'Review the vehicle and document photos below for your records, then click '
        f'<b>"Mark as Reviewed"</b> to acknowledge.</div>'
        f'</div></div>',
        unsafe_allow_html=True,
    )

    if not _post_veh:
        empty_state(
            "No post-verification additions",
            "All vehicle additions by verified providers will appear here for monitoring.",
            "✅",
        )
    else:
        # ── Summary ───────────────────────────────────────────────────────────
        total_post   = len(_post_veh)
        reviewed     = sum(1 for v in _post_veh if v.get("adminReviewed", False))
        pending_cnt  = total_post - reviewed

        p1, p2, p3 = st.columns(3)
        with p1:
            st.markdown(kpi_card("Total Added",   str(total_post), color=PRIMARY),   unsafe_allow_html=True)
        with p2:
            st.markdown(kpi_card("Pending Review", str(pending_cnt), color=WARNING), unsafe_allow_html=True)
        with p3:
            st.markdown(kpi_card("Reviewed",       str(reviewed),   color=SUCCESS),  unsafe_allow_html=True)

        st.markdown("<div style='height:20px'></div>", unsafe_allow_html=True)

        # ── Filter ────────────────────────────────────────────────────────────
        review_filter = st.radio(
            "Show",
            ["Pending Review", "Reviewed", "All"],
            horizontal=True,
            key="review_filter",
        )

        display = _post_veh
        if review_filter == "Pending Review":
            display = [v for v in _post_veh if not v.get("adminReviewed", False)]
        elif review_filter == "Reviewed":
            display = [v for v in _post_veh if v.get("adminReviewed", False)]

        if not display:
            empty_state("Nothing to show", "Change the filter above to see other entries.", "🔍")
        else:
            for v in display:
                vid        = v.get("id", "")
                vtype      = v.get("vehicleType", "unknown")
                number     = v.get("vehicleNumber", "—")
                model      = v.get("vehicleModel", "—")
                year       = v.get("vehicleYear", "—")
                capacity   = v.get("capacity", "—")
                provider   = v.get("providerName", "—")
                email      = v.get("providerEmail", "—")
                phone      = v.get("providerPhone", "—")
                added      = fmt_date(v.get("createdAt"))
                is_reviewed = v.get("adminReviewed", False)
                type_label = vtype.replace("_", " ").title()

                reviewed_icon = "✅" if is_reviewed else "🔔"
                expander_title = (
                    f"{reviewed_icon}  {type_label} — {number}  ·  Provider: {provider}"
                    + ("  ·  [Reviewed]" if is_reviewed else "  ·  [Pending Review]")
                )

                with st.expander(expander_title, expanded=(not is_reviewed)):
                    col_info, col_docs, col_act = st.columns([2, 3, 1])

                    with col_info:
                        st.markdown(
                            f'<div style="background:#FAFBFF;border:1px solid {BORDER};'
                            f'border-radius:10px;padding:16px;">'
                            f'<div style="font-size:12px;font-weight:700;color:{TEXT_SEC};'
                            f'text-transform:uppercase;letter-spacing:.5px;margin-bottom:12px;">'
                            f'Vehicle Details</div>'
                            f'<table style="width:100%;border-collapse:collapse;">'
                            f'<tr><td style="color:{TEXT_SEC};font-size:12px;font-weight:600;'
                            f'padding:5px 0;width:110px;">Type</td>'
                            f'<td style="color:{TEXT_PRIMARY};font-size:13px;padding:5px 0;font-weight:600;">'
                            f'{type_label}</td></tr>'
                            f'<tr><td style="color:{TEXT_SEC};font-size:12px;font-weight:600;padding:5px 0;">Number</td>'
                            f'<td style="color:{TEXT_PRIMARY};font-size:13px;padding:5px 0;">{number}</td></tr>'
                            f'<tr><td style="color:{TEXT_SEC};font-size:12px;font-weight:600;padding:5px 0;">Model</td>'
                            f'<td style="color:{TEXT_PRIMARY};font-size:13px;padding:5px 0;">{model}</td></tr>'
                            f'<tr><td style="color:{TEXT_SEC};font-size:12px;font-weight:600;padding:5px 0;">Year</td>'
                            f'<td style="color:{TEXT_PRIMARY};font-size:13px;padding:5px 0;">{year}</td></tr>'
                            f'<tr><td style="color:{TEXT_SEC};font-size:12px;font-weight:600;padding:5px 0;">Capacity</td>'
                            f'<td style="color:{TEXT_PRIMARY};font-size:13px;padding:5px 0;">{capacity}</td></tr>'
                            f'<tr><td style="color:{TEXT_SEC};font-size:12px;font-weight:600;padding:5px 0;">Added</td>'
                            f'<td style="color:{TEXT_PRIMARY};font-size:13px;padding:5px 0;">{added}</td></tr>'
                            f'<tr><td colspan="2" style="padding-top:12px;'
                            f'font-size:12px;font-weight:700;color:{TEXT_SEC};'
                            f'text-transform:uppercase;letter-spacing:.4px;">Provider</td></tr>'
                            f'<tr><td style="color:{TEXT_SEC};font-size:12px;font-weight:600;padding:5px 0;">Name</td>'
                            f'<td style="color:{TEXT_PRIMARY};font-size:13px;padding:5px 0;font-weight:600;">{provider}</td></tr>'
                            f'<tr><td style="color:{TEXT_SEC};font-size:12px;font-weight:600;padding:5px 0;">Email</td>'
                            f'<td style="color:{TEXT_PRIMARY};font-size:13px;padding:5px 0;">{email}</td></tr>'
                            f'<tr><td style="color:{TEXT_SEC};font-size:12px;font-weight:600;padding:5px 0;">Phone</td>'
                            f'<td style="color:{TEXT_PRIMARY};font-size:13px;padding:5px 0;">{phone}</td></tr>'
                            f'</table></div>',
                            unsafe_allow_html=True,
                        )

                    with col_docs:
                        st.markdown(
                            f'<div style="font-size:12px;font-weight:700;color:{TEXT_SEC};'
                            f'text-transform:uppercase;letter-spacing:.5px;margin-bottom:10px;">'
                            f'Documents</div>',
                            unsafe_allow_html=True,
                        )

                        def _show_img(label: str, value: str | None) -> bool:
                            if not value:
                                return False
                            val = value.strip()
                            st.caption(label)
                            if val.startswith("data:"):
                                st.image(val, use_column_width=True)
                            elif val.startswith(("http://", "https://")):
                                st.image(val, use_column_width=True)
                            else:
                                st.image(f"data:image/jpeg;base64,{val}", use_column_width=True)
                            return True

                        shown = 0
                        shown += _show_img("Vehicle Photo",        v.get("vehicleImageBase64"))
                        shown += _show_img("Vehicle Registration / License", v.get("vehicleLicenseImageBase64"))

                        if shown == 0:
                            st.markdown(
                                f'<div style="background:#F7FAFC;border:1px dashed {BORDER};'
                                f'border-radius:10px;padding:24px;text-align:center;color:{TEXT_SEC};'
                                f'font-size:13px;">No document images uploaded</div>',
                                unsafe_allow_html=True,
                            )

                    with col_act:
                        st.markdown(
                            f'<div style="font-size:12px;font-weight:700;color:{TEXT_SEC};'
                            f'text-transform:uppercase;letter-spacing:.5px;margin-bottom:12px;">'
                            f'Action</div>',
                            unsafe_allow_html=True,
                        )

                        if is_reviewed:
                            st.markdown(
                                f'<div style="background:#F0FFF4;border:1px solid #C6F6D5;'
                                f'border-radius:8px;padding:10px 12px;text-align:center;">'
                                f'<span style="font-size:18px;">✅</span>'
                                f'<div style="font-size:12px;color:#276749;font-weight:600;margin-top:4px;">'
                                f'Reviewed</div></div>',
                                unsafe_allow_html=True,
                            )
                        else:
                            st.markdown(
                                f'<div style="background:#FFFBF0;border:1px solid #FAD689;'
                                f'border-radius:8px;padding:8px 12px;text-align:center;'
                                f'margin-bottom:10px;">'
                                f'<span style="font-size:16px;">🔔</span>'
                                f'<div style="font-size:11px;color:#975A16;font-weight:600;margin-top:3px;">'
                                f'Needs Review</div></div>',
                                unsafe_allow_html=True,
                            )
                            st.markdown(
                                '<div style="font-size:11px;color:#718096;margin-bottom:8px;'
                                'line-height:1.4;">Vehicle is already auto-verified. '
                                'Click to acknowledge you have reviewed it.</div>',
                                unsafe_allow_html=True,
                            )
                            if st.button(
                                "✓  Mark Reviewed",
                                key=f"review_{vid}",
                                type="primary",
                                use_container_width=True,
                            ):
                                ok = mark_vehicle_reviewed(vid)
                                if ok:
                                    st.toast("Marked as reviewed!", icon="✅")
                                    st.cache_data.clear()
                                    st.rerun()
                                else:
                                    st.warning("Action failed — please try again.")
