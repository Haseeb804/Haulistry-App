"""
Provider management — browse, filter, view detail, toggle active status.
"""

import streamlit as st
import pandas as pd
from components.sidebar import render_sidebar
from core.database import (
    get_all_users, get_user_detail, get_provider_performance,
    toggle_user_status, verify_provider, reject_provider, delete_user,
)
from core.api_client import notify_provider_approved, notify_provider_rejected
from components.styles import (
    page_header, status_badge, fmt_date, fmt_datetime,
    fmt_currency, fmt_number, empty_state, section_header, kpi_card, pagination,
    PRIMARY, SECONDARY, ACCENT, SUCCESS, WARNING, TEXT_SEC, TEXT_PRIMARY, CARD_BG, BORDER,
)

st.set_page_config(page_title="Providers · Haulistry Admin", page_icon="👷", layout="wide")
render_sidebar()


def _show_doc(label: str, value: str | None) -> bool:
    """Render one document image from raw base64, data-URI, or HTTP URL."""
    if not value:
        return False
    v = value.strip()
    st.caption(label)
    if v.startswith("data:"):
        st.image(v, use_container_width=True)
    elif v.startswith(("http://", "https://")):
        st.image(v, use_container_width=True)
    else:
        st.image(f"data:image/jpeg;base64,{v}", use_container_width=True)
    return True

# ── State ─────────────────────────────────────────────────────────────────────
if "selected_provider" not in st.session_state:
    st.session_state.selected_provider = None

# ── Detail view ───────────────────────────────────────────────────────────────
if st.session_state.selected_provider:
    pid = st.session_state.selected_provider

    if st.button("← Back to Providers"):
        st.session_state.selected_provider = None
        st.rerun()

    @st.cache_data(ttl=30, show_spinner=False)
    def _detail(uid):
        return get_user_detail(uid)

    @st.cache_data(ttl=30, show_spinner=False)
    def _perf(uid):
        return get_provider_performance(uid)

    with st.spinner("Loading provider…"):
        detail = _detail(pid)
        perf   = _perf(pid)

    if not detail:
        st.warning("Provider not found.")
        st.stop()

    name        = detail.get("name", "—")
    email       = detail.get("email", "—")
    phone       = detail.get("phone", "—")
    cnic        = detail.get("cnic", "—")
    is_active   = detail.get("isActive", False)
    is_verified = detail.get("isVerified", False)
    vehicles    = [v for v in detail.get("vehicles", []) if v.get("id")]
    services    = [s for s in detail.get("services", []) if s.get("id")]
    rejection   = detail.get("rejectionReason")

    # ── Header ────────────────────────────────────────────────────────────────
    initials = (name[:2].upper()) if name and name != "—" else "??"
    st.markdown(
        f"""
        <div style="background:{CARD_BG};border:1px solid {BORDER};border-radius:14px;
                    padding:22px 24px;margin-bottom:20px;
                    display:flex;align-items:center;justify-content:space-between;
                    box-shadow:0 1px 4px rgba(0,0,0,.04);">
          <div style="display:flex;align-items:center;gap:14px;">
            <div style="width:50px;height:50px;border-radius:12px;
                        background:linear-gradient(135deg,{PRIMARY},{ACCENT});
                        display:flex;align-items:center;justify-content:center;
                        font-size:20px;font-weight:700;color:#fff;">{initials}</div>
            <div>
              <div style="font-size:20px;font-weight:800;color:{TEXT_PRIMARY};
                          letter-spacing:-.3px;">{name}</div>
              <div style="font-size:13px;color:{TEXT_SEC};margin-top:2px;">
                {email} &nbsp;·&nbsp; {phone}
              </div>
              <div style="margin-top:8px;display:flex;gap:6px;">
                {status_badge("verified" if is_verified else "unverified")}
                {status_badge("active_user" if is_active else "inactive")}
              </div>
            </div>
          </div>
        </div>
        """,
        unsafe_allow_html=True,
    )

    # ── Action buttons ────────────────────────────────────────────────────────
    act_cols = st.columns([1, 1, 2])

    with act_cols[0]:
        btn_label = "Deactivate" if is_active else "Activate"
        if st.button(btn_label, type="secondary" if is_active else "primary",
                     use_container_width=True):
            ok = toggle_user_status(pid, not is_active)
            if ok:
                st.toast(f"{'Deactivated' if is_active else 'Activated'} {name}", icon="✅")
                st.cache_data.clear()
                st.rerun()
            else:
                st.warning("Action failed — please try again.")

    with act_cols[1]:
        if not is_verified:
            if st.button("✅ Approve", type="primary", use_container_width=True):
                ok = verify_provider(pid)
                if ok:
                    notify_provider_approved(pid)
                    st.toast(f"{name} has been approved!", icon="✅")
                    st.cache_data.clear()
                    st.rerun()
                else:
                    st.warning("Action failed — please try again.")
        else:
            st.button("✅ Verified", disabled=True, use_container_width=True)

    # ── Reject / re-reject section (only for unverified providers) ────────────
    if not is_verified:
        st.markdown("<div style='height:6px'></div>", unsafe_allow_html=True)
        with st.expander("✗  Reject / set rejection reason", expanded=bool(rejection)):
            reason_val = rejection or ""
            reason_input = st.text_area(
                "Rejection reason",
                value=reason_val,
                placeholder="Explain why the account is not approved…",
                key=f"reject_reason_{pid}",
                label_visibility="collapsed",
            )
            if st.button("Confirm Rejection", key=f"do_reject_{pid}"):
                reason = reason_input.strip() or "Application rejected by admin."
                ok = reject_provider(pid, reason)
                if ok:
                    notify_provider_rejected(pid, reason)
                    st.toast(f"{name} has been rejected.", icon="❌")
                    st.cache_data.clear()
                    st.rerun()
                else:
                    st.warning("Action failed — please try again.")

    # ── Performance metrics ───────────────────────────────────────────────────
    st.markdown("<div style='height:16px'></div>", unsafe_allow_html=True)
    pc1, pc2, pc3, pc4 = st.columns(4)
    with pc1:
        st.markdown(kpi_card("Completed Jobs",  fmt_number(perf.get("completedJobs", 0)),  color=PRIMARY),   unsafe_allow_html=True)
    with pc2:
        st.markdown(kpi_card("Total Earnings",  fmt_currency(perf.get("totalEarnings", 0)), color=SECONDARY), unsafe_allow_html=True)
    with pc3:
        avg_r = perf.get("avgRating") or 0
        st.markdown(kpi_card("Avg Rating",       f"{avg_r:.1f} ⭐",                           color=ACCENT),    unsafe_allow_html=True)
    with pc4:
        st.markdown(kpi_card("Total Reviews",   fmt_number(perf.get("reviewCount", 0)),     color=SUCCESS),   unsafe_allow_html=True)

    st.markdown("<div style='height:16px'></div>", unsafe_allow_html=True)

    # ── Detail tabs ───────────────────────────────────────────────────────────
    t1, t2, t3, t4 = st.tabs(["  Profile  ", "  Vehicles & Services  ", "  Documents  ", "  Details  "])

    with t1:
        rows = [
            ("Email",         email),
            ("Phone",         phone),
            ("CNIC",          cnic),
            ("Joined",        fmt_date(detail.get("createdAt"))),
            ("Last Updated",  fmt_date(detail.get("updatedAt"))),
        ]
        if rejection:
            rows.append(("Rejection Reason", rejection))

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
        v_col, s_col = st.columns(2)
        with v_col:
            section_header("Registered Vehicles")
            if vehicles:
                for v in vehicles:
                    av = status_badge("active" if v.get("isAvailable") else "inactive")
                    st.markdown(
                        f'<div style="background:#FAFBFF;border:1px solid {BORDER};'
                        f'border-radius:10px;padding:12px 16px;margin-bottom:8px;">'
                        f'<div style="font-weight:600;color:{TEXT_PRIMARY};font-size:13px;">'
                        f'{v.get("type","Unknown")}</div>'
                        f'<div style="font-size:12px;color:{TEXT_SEC};margin-top:3px;">'
                        f'{v.get("number","—")}</div>'
                        f'<div style="margin-top:6px;">{av}</div>'
                        f'</div>',
                        unsafe_allow_html=True,
                    )
            else:
                st.markdown(
                    f'<div style="color:{TEXT_SEC};font-size:13px;padding:12px 0;">No vehicles registered.</div>',
                    unsafe_allow_html=True,
                )

        with s_col:
            section_header("Offered Services")
            if services:
                for s in services:
                    act = status_badge("active" if s.get("isActive") else "inactive")
                    st.markdown(
                        f'<div style="background:#FAFBFF;border:1px solid {BORDER};'
                        f'border-radius:10px;padding:12px 16px;margin-bottom:8px;">'
                        f'<div style="font-weight:600;color:{TEXT_PRIMARY};font-size:13px;">'
                        f'{s.get("name","Unknown")}</div>'
                        f'<div style="font-size:12px;color:{TEXT_SEC};margin-top:3px;">'
                        f'{s.get("category","—")}</div>'
                        f'<div style="margin-top:6px;">{act}</div>'
                        f'</div>',
                        unsafe_allow_html=True,
                    )
            else:
                st.markdown(
                    f'<div style="color:{TEXT_SEC};font-size:13px;padding:12px 0;">No services registered.</div>',
                    unsafe_allow_html=True,
                )

    with t3:
        profile_img   = detail.get("profileImageUrl")
        cnic_front    = detail.get("cnicFrontImageBase64")
        cnic_back     = detail.get("cnicBackImageBase64")
        license_img   = detail.get("licenseImageBase64")
        vehicle_img   = detail.get("vehicleImageBase64") or detail.get("vehicleImageUrl")

        docs = [
            ("Profile Photo",   profile_img),
            ("CNIC — Front",    cnic_front),
            ("CNIC — Back",     cnic_back),
            ("Driving License", license_img),
            ("Vehicle Photo",   vehicle_img),
        ]
        present = [(lbl, val) for lbl, val in docs if val]

        if not present:
            st.markdown(
                f'<div style="background:#F7FAFC;border:1px dashed {BORDER};'
                f'border-radius:10px;padding:32px;text-align:center;color:{TEXT_SEC};'
                f'font-size:14px;margin-top:8px;">No document images on file for this provider.</div>',
                unsafe_allow_html=True,
            )
        else:
            # Lay out docs in a 2-column grid
            cols = st.columns(2)
            for i, (lbl, val) in enumerate(present):
                with cols[i % 2]:
                    st.markdown(
                        f'<div style="background:{CARD_BG};border:1px solid {BORDER};'
                        f'border-radius:10px;padding:12px;margin-bottom:12px;">'
                        f'<div style="font-size:11px;font-weight:700;color:{TEXT_SEC};'
                        f'text-transform:uppercase;letter-spacing:.5px;margin-bottom:8px;">'
                        f'{lbl}</div></div>',
                        unsafe_allow_html=True,
                    )
                    _show_doc(lbl, val)

    with t4:
        st.markdown(
            f'<div style="background:#FFFBEB;border:1px solid #FEFCBF;border-radius:10px;'
            f'padding:12px 16px;font-size:13px;color:#744210;">'
            f'Provider ID: <code>{pid}</code></div>',
            unsafe_allow_html=True,
        )

    # ── Danger zone ──────────────────────────────────────────────────────────
    st.markdown("<div style='height:32px'></div>", unsafe_allow_html=True)
    st.markdown(
        f'<div style="border:1px solid #FC8181;border-radius:12px;padding:20px 24px;'
        f'background:#FFF5F5;">'
        f'<div style="font-size:14px;font-weight:700;color:#C53030;margin-bottom:6px;">'
        f'Danger Zone</div>'
        f'<div style="font-size:13px;color:#742A2A;">Permanently delete this provider and '
        f'all related data — vehicles, services, bookings, messages, calls, fare offers, '
        f'feedback, notifications, and location history. This cannot be undone.</div>'
        f'</div>',
        unsafe_allow_html=True,
    )
    st.markdown("<div style='height:10px'></div>", unsafe_allow_html=True)
    confirm_key = f"confirm_delete_provider_{pid}"
    confirm_val = st.text_input(
        "Type **DELETE** to confirm permanent deletion",
        key=confirm_key,
        placeholder="DELETE",
    )
    if st.button("🗑️ Delete Provider Permanently",
                 type="secondary",
                 disabled=(confirm_val.strip() != "DELETE"),
                 key=f"delete_provider_{pid}"):
        with st.spinner("Deleting provider and all related data…"):
            ok = delete_user(pid)
        if ok:
            st.success(f"{name} and all related data have been permanently deleted.")
            st.cache_data.clear()
            st.session_state.selected_provider = None
            st.rerun()
        else:
            st.error("Deletion failed — please try again or check the database connection.")

    st.stop()

# ── List view ─────────────────────────────────────────────────────────────────
page_header("Providers", "Manage service providers on the platform", "👷")

# ── Filters ───────────────────────────────────────────────────────────────────
col_search, col_verified, col_active = st.columns([3, 1, 1])
with col_search:
    search = st.text_input("Search providers", placeholder="Name, email or phone…",
                           label_visibility="collapsed")
with col_verified:
    filter_verified = st.selectbox("Verified", ["All", "Verified", "Unverified"],
                                   label_visibility="collapsed")
with col_active:
    filter_active = st.selectbox("Status", ["All", "Active", "Inactive"],
                                 label_visibility="collapsed")

@st.cache_data(ttl=60, show_spinner=False)
def _providers():
    return get_all_users(role="provider", size=200)

all_providers = _providers()

# Apply filters
rows = all_providers
if search:
    q = search.lower()
    rows = [p for p in rows if (q in str(p.get("name", "")).lower()
                                or q in str(p.get("email", "")).lower()
                                or q in str(p.get("phone", "")).lower())]
if filter_verified == "Verified":
    rows = [p for p in rows if p.get("isVerified")]
elif filter_verified == "Unverified":
    rows = [p for p in rows if not p.get("isVerified")]
if filter_active == "Active":
    rows = [p for p in rows if p.get("isActive")]
elif filter_active == "Inactive":
    rows = [p for p in rows if not p.get("isActive")]

# ── Count bar ─────────────────────────────────────────────────────────────────
total_all      = len(all_providers)
total_verified = sum(1 for p in all_providers if p.get("isVerified"))
total_active   = sum(1 for p in all_providers if p.get("isActive"))

sc1, sc2, sc3, sc4 = st.columns(4)
with sc1:
    st.markdown(kpi_card("Total Providers", str(total_all),     color=PRIMARY),   unsafe_allow_html=True)
with sc2:
    st.markdown(kpi_card("Verified",        str(total_verified), color=SUCCESS),   unsafe_allow_html=True)
with sc3:
    st.markdown(kpi_card("Active",          str(total_active),   color=SECONDARY), unsafe_allow_html=True)
with sc4:
    pending = sum(1 for p in all_providers if not p.get("isVerified") and not p.get("rejectionReason"))
    st.markdown(kpi_card("Pending",         str(pending),        color=WARNING),   unsafe_allow_html=True)

st.markdown("<div style='height:16px'></div>", unsafe_allow_html=True)

# ── Results count ──────────────────────────────────────────────────────────────
st.markdown(
    f'<div style="font-size:13px;color:{TEXT_SEC};margin-bottom:12px;">'
    f'Showing <b style="color:{TEXT_PRIMARY};">{len(rows)}</b> of {total_all} providers</div>',
    unsafe_allow_html=True,
)

if not rows:
    empty_state("No providers match your filters", "Try adjusting your search criteria.", "🔍")
    st.stop()

# ── Header row ─────────────────────────────────────────────────────────────────
st.markdown(
    f'<div style="display:flex;padding:8px 0;border-bottom:2px solid {BORDER};'
    f'font-size:11px;font-weight:700;color:{TEXT_SEC};'
    f'text-transform:uppercase;letter-spacing:.5px;margin-bottom:2px;">'
    f'<div style="flex:2;">Provider</div>'
    f'<div style="flex:2;">Contact</div>'
    f'<div style="flex:2;">Status</div>'
    f'<div style="flex:1;text-align:right;">Action</div>'
    f'</div>',
    unsafe_allow_html=True,
)

# ── Rows ──────────────────────────────────────────────────────────────────────
PAGE_SIZE = 20
page_key  = "providers_page"
if page_key not in st.session_state:
    st.session_state[page_key] = 0
current_page = st.session_state[page_key]
paged = rows[current_page * PAGE_SIZE: (current_page + 1) * PAGE_SIZE]

for p in paged:
    pid         = p.get("id", "")
    name        = p.get("name", "Unknown")
    email       = p.get("email", "—")
    phone       = p.get("phone", "—")
    rating      = p.get("rating") or 0
    is_active   = p.get("isActive", False)
    is_verified = p.get("isVerified", False)
    joined      = fmt_date(p.get("createdAt"))

    c_name, c_contact, c_badges, c_action = st.columns([2, 2, 2, 1])
    with c_name:
        initials = (name[:2].upper()) if name != "Unknown" else "??"
        st.markdown(
            f'<div style="display:flex;align-items:center;gap:10px;padding:10px 0;">'
            f'<div style="width:36px;height:36px;border-radius:9px;flex-shrink:0;'
            f'background:linear-gradient(135deg,{PRIMARY}22,{ACCENT}22);'
            f'display:flex;align-items:center;justify-content:center;'
            f'font-size:13px;font-weight:700;color:{PRIMARY};">{initials}</div>'
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
    with c_badges:
        vb = status_badge("verified" if is_verified else "unverified")
        ab = status_badge("active_user" if is_active else "inactive")
        rat_str = f'<span style="font-size:12px;color:{TEXT_SEC};">⭐ {rating:.1f}</span>' if rating else ""
        st.markdown(
            f'<div style="padding:10px 0;display:flex;align-items:center;gap:6px;flex-wrap:wrap;">'
            f'{vb} {ab} {rat_str}</div>',
            unsafe_allow_html=True,
        )
    with c_action:
        st.markdown("<div style='padding-top:8px;'></div>", unsafe_allow_html=True)
        if st.button("View →", key=f"view_{pid}", use_container_width=True):
            st.session_state.selected_provider = pid
            st.session_state[page_key] = current_page
            st.rerun()

    st.markdown(f'<div style="border-bottom:1px solid {BORDER};"></div>', unsafe_allow_html=True)

# ── Pagination ────────────────────────────────────────────────────────────────
pagination(page_key, len(rows), PAGE_SIZE)
