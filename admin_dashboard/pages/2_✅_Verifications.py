"""
Provider verification workflow — approve or reject pending providers.
Also shows a monitoring panel for vehicles added by already-verified providers.
"""

import streamlit as st
from components.sidebar import render_sidebar
from core.database import (
    get_pending_providers, verify_provider, reject_provider,
    get_post_verification_vehicles, mark_vehicle_reviewed,
)
from core.api_client import notify_provider_approved, notify_provider_rejected
from components.styles import (
    page_header, status_badge, fmt_date,
    empty_state, kpi_card, PRIMARY, SECONDARY, DANGER, WARNING, SUCCESS,
    TEXT_SEC, CARD_BG, BORDER, TEXT_PRIMARY,
)

st.set_page_config(
    page_title="Verifications · Haulistry Admin",
    page_icon="✅",
    layout="wide",
)
render_sidebar()

page_header(
    "Provider Verifications",
    "Review and approve or reject pending provider applications",
    "✅",
)

def _show_doc(label: str, value: str | None) -> bool:
    """Render one document image. Handles raw base64, data-URI, and HTTP URL.
    Returns True when an image was displayed."""
    if not value:
        return False
    v = value.strip()
    st.caption(label)
    if v.startswith("data:"):
        st.image(v, use_column_width=True)
    elif v.startswith(("http://", "https://")):
        st.image(v, use_column_width=True)
    else:
        st.image(f"data:image/jpeg;base64,{v}", use_column_width=True)
    return True


@st.cache_data(ttl=30, show_spinner=False)
def _pending():
    return get_pending_providers()

pending = _pending()

if not pending:
    empty_state(
        "All caught up!",
        "No providers are currently awaiting verification.",
        "🎉",
    )
else:
    # ── Summary bar ───────────────────────────────────────────────────────────
    st.markdown(
        f'<div style="background:linear-gradient(135deg,#FFF8F0,#FFF3E6);'
        f'border:1px solid #FDDCB5;border-radius:12px;padding:14px 20px;'
        f'margin-bottom:20px;display:flex;align-items:center;gap:12px;">'
        f'<div style="width:38px;height:38px;border-radius:10px;'
        f'background:rgba(255,107,53,.15);display:flex;align-items:center;'
        f'justify-content:center;font-size:18px;">⏳</div>'
        f'<div>'
        f'<div style="font-size:14px;font-weight:700;color:#7B341E;">'
        f'{len(pending)} provider{"s" if len(pending) != 1 else ""} awaiting review</div>'
        f'<div style="font-size:12.5px;color:#C05621;margin-top:1px;">'
        f'Review each application carefully before approving.</div>'
        f'</div></div>',
        unsafe_allow_html=True,
    )

# ── Provider cards ────────────────────────────────────────────────────────────
for p in pending:
    pid    = p.get("id", "")
    name   = p.get("name", "Unknown")
    email  = p.get("email", "—")
    phone  = p.get("phone", "—")
    cnic   = p.get("cnic", "—")
    vcount = p.get("vehicleCount", 0)
    joined = fmt_date(p.get("createdAt"))
    badge  = status_badge("unverified")

    with st.expander(f"🧑‍🔧 {name}   ·   {email}", expanded=False):
        st.markdown("<div style='height:4px'></div>", unsafe_allow_html=True)

        col_info, col_docs, col_actions = st.columns([2, 2, 1])

        with col_info:
            st.markdown(
                f"""
                <div style="background:#FAFBFF;border:1px solid {BORDER};
                            border-radius:10px;padding:16px;">
                  <div style="font-size:12px;font-weight:700;color:{TEXT_SEC};
                              text-transform:uppercase;letter-spacing:.5px;
                              margin-bottom:12px;">Applicant Details</div>
                  <table style="width:100%;border-collapse:collapse;">
                    <tr>
                      <td style="color:{TEXT_SEC};font-size:12px;font-weight:600;
                                 padding:5px 0;width:110px;">Status</td>
                      <td style="padding:5px 0;">{badge}</td>
                    </tr>
                    <tr>
                      <td style="color:{TEXT_SEC};font-size:12px;font-weight:600;padding:5px 0;">Email</td>
                      <td style="color:{TEXT_PRIMARY};font-size:13px;font-weight:600;padding:5px 0;">{email}</td>
                    </tr>
                    <tr>
                      <td style="color:{TEXT_SEC};font-size:12px;font-weight:600;padding:5px 0;">Phone</td>
                      <td style="color:{TEXT_PRIMARY};font-size:13px;padding:5px 0;">{phone}</td>
                    </tr>
                    <tr>
                      <td style="color:{TEXT_SEC};font-size:12px;font-weight:600;padding:5px 0;">CNIC</td>
                      <td style="color:{TEXT_PRIMARY};font-size:13px;padding:5px 0;">{cnic}</td>
                    </tr>
                    <tr>
                      <td style="color:{TEXT_SEC};font-size:12px;font-weight:600;padding:5px 0;">Vehicles</td>
                      <td style="color:{TEXT_PRIMARY};font-size:13px;padding:5px 0;">{vcount}</td>
                    </tr>
                    <tr>
                      <td style="color:{TEXT_SEC};font-size:12px;font-weight:600;padding:5px 0;">Joined</td>
                      <td style="color:{TEXT_PRIMARY};font-size:13px;padding:5px 0;">{joined}</td>
                    </tr>
                  </table>
                </div>
                """,
                unsafe_allow_html=True,
            )

        with col_docs:
            st.markdown(
                f'<div style="font-size:12px;font-weight:700;color:{TEXT_SEC};'
                f'text-transform:uppercase;letter-spacing:.5px;margin-bottom:10px;">'
                f'Documents</div>',
                unsafe_allow_html=True,
            )

            shown = 0
            shown += _show_doc("Profile Photo",    p.get("profileImageUrl"))
            shown += _show_doc("CNIC — Front",     p.get("cnicFrontImageBase64"))
            shown += _show_doc("CNIC — Back",      p.get("cnicBackImageBase64"))
            shown += _show_doc("Driving License",  p.get("licenseImageBase64"))
            # Vehicle photo: prefer base64, fall back to URL
            shown += _show_doc(
                "Vehicle Photo",
                p.get("vehicleImageBase64") or p.get("vehicleImageUrl"),
            )

            if shown == 0:
                st.markdown(
                    f'<div style="background:#F7FAFC;border:1px dashed {BORDER};'
                    f'border-radius:10px;padding:24px;text-align:center;color:{TEXT_SEC};'
                    f'font-size:13px;">No documents uploaded</div>',
                    unsafe_allow_html=True,
                )

        with col_actions:
            st.markdown(
                f'<div style="font-size:12px;font-weight:700;color:{TEXT_SEC};'
                f'text-transform:uppercase;letter-spacing:.5px;margin-bottom:12px;">'
                f'Decision</div>',
                unsafe_allow_html=True,
            )

            if st.button("✅  Approve", key=f"approve_{pid}", type="primary",
                         use_container_width=True):
                ok = verify_provider(pid)
                if ok:
                    notify_provider_approved(pid)
                    st.toast(f"{name} has been approved!", icon="✅")
                    st.cache_data.clear()
                    st.rerun()
                else:
                    st.warning("Action failed — please try again.")

            st.markdown("<div style='height:8px'></div>", unsafe_allow_html=True)

            reason_text = st.text_area(
                "Reason (optional)",
                key=f"reason_{pid}",
                placeholder="Reason for rejection…",
                height=80,
            )
            if st.button("✗  Reject", key=f"reject_{pid}", use_container_width=True):
                reason = reason_text.strip() or "Application rejected by admin."
                ok = reject_provider(pid, reason)
                if ok:
                    notify_provider_rejected(pid, reason)
                    st.toast(f"{name} has been rejected.", icon="❌")
                    st.cache_data.clear()
                    st.rerun()
                else:
                    st.warning("Action failed — please try again.")

        st.markdown("<div style='height:4px'></div>", unsafe_allow_html=True)


# ── Post-Verification Vehicle Additions ───────────────────────────────────────

st.markdown("<div style='height:32px'></div>", unsafe_allow_html=True)
st.markdown(
    f'<div style="border-top:2px solid {BORDER};margin-bottom:24px;"></div>',
    unsafe_allow_html=True,
)

page_header(
    "Post-Verification Vehicle Additions",
    "Vehicles added by already-verified providers — auto-verified, monitoring only",
    "🔔",
)


@st.cache_data(ttl=30, show_spinner=False)
def _post_veh():
    return get_post_verification_vehicles()


post_vehicles = _post_veh()
pending_review = [v for v in post_vehicles if not v.get("adminReviewed", False)]

if not post_vehicles:
    empty_state(
        "No post-verification additions yet",
        "When a verified provider adds a new vehicle it will appear here automatically.",
        "🚛",
    )
else:
    # Summary KPIs
    p1, p2, p3 = st.columns(3)
    with p1:
        st.markdown(kpi_card("Total Added",    str(len(post_vehicles)), color=PRIMARY),  unsafe_allow_html=True)
    with p2:
        st.markdown(kpi_card("Pending Review", str(len(pending_review)), color=WARNING), unsafe_allow_html=True)
    with p3:
        st.markdown(kpi_card("Reviewed",       str(len(post_vehicles) - len(pending_review)), color=SUCCESS), unsafe_allow_html=True)

    if not pending_review:
        st.success("All post-verification vehicle additions have been reviewed. ✅")
    else:
        st.markdown("<div style='height:12px'></div>", unsafe_allow_html=True)
        st.markdown(
            f'<div style="background:linear-gradient(135deg,#FFFBF0,#FFF8E6);'
            f'border:1px solid #FAD689;border-radius:12px;padding:14px 20px;'
            f'margin-bottom:16px;display:flex;align-items:center;gap:12px;">'
            f'<div style="font-size:22px;">🔔</div>'
            f'<div>'
            f'<div style="font-size:14px;font-weight:700;color:#744210;">'
            f'{len(pending_review)} vehicle{"s" if len(pending_review) != 1 else ""} '
            f'awaiting your acknowledgement</div>'
            f'<div style="font-size:12.5px;color:#975A16;margin-top:1px;">'
            f'These are already auto-verified — no approval needed. '
            f'Review the details and click "Mark Reviewed".</div>'
            f'</div></div>',
            unsafe_allow_html=True,
        )

        for v in pending_review:
            vid        = v.get("id", "")
            vtype      = v.get("vehicleType", "unknown")
            number     = v.get("vehicleNumber", "—")
            model      = v.get("vehicleModel", "—")
            provider   = v.get("providerName", "—")
            email      = v.get("providerEmail", "—")
            added      = fmt_date(v.get("createdAt"))
            type_label = vtype.replace("_", " ").title()

            with st.expander(
                f"🔔  {type_label} — {number}  ·  {provider}  ·  Added {added}",
                expanded=True,
            ):
                c_info, c_docs, c_act = st.columns([2, 3, 1])

                with c_info:
                    st.markdown(
                        f'<div style="background:#FAFBFF;border:1px solid {BORDER};'
                        f'border-radius:10px;padding:14px;">'
                        f'<table style="width:100%;border-collapse:collapse;">'
                        f'<tr><td style="color:{TEXT_SEC};font-size:12px;font-weight:600;padding:4px 0;width:90px;">Type</td>'
                        f'<td style="color:{TEXT_PRIMARY};font-size:13px;font-weight:600;padding:4px 0;">{type_label}</td></tr>'
                        f'<tr><td style="color:{TEXT_SEC};font-size:12px;font-weight:600;padding:4px 0;">Reg No.</td>'
                        f'<td style="color:{TEXT_PRIMARY};font-size:13px;padding:4px 0;">{number}</td></tr>'
                        f'<tr><td style="color:{TEXT_SEC};font-size:12px;font-weight:600;padding:4px 0;">Model</td>'
                        f'<td style="color:{TEXT_PRIMARY};font-size:13px;padding:4px 0;">{model}</td></tr>'
                        f'<tr><td style="color:{TEXT_SEC};font-size:12px;font-weight:600;padding:4px 0;">Provider</td>'
                        f'<td style="color:{TEXT_PRIMARY};font-size:13px;font-weight:600;padding:4px 0;">{provider}</td></tr>'
                        f'<tr><td style="color:{TEXT_SEC};font-size:12px;font-weight:600;padding:4px 0;">Email</td>'
                        f'<td style="color:{TEXT_PRIMARY};font-size:13px;padding:4px 0;">{email}</td></tr>'
                        f'<tr><td style="color:{TEXT_SEC};font-size:12px;font-weight:600;padding:4px 0;">Added</td>'
                        f'<td style="color:{TEXT_PRIMARY};font-size:13px;padding:4px 0;">{added}</td></tr>'
                        f'</table></div>',
                        unsafe_allow_html=True,
                    )

                with c_docs:
                    st.markdown(
                        f'<div style="font-size:12px;font-weight:700;color:{TEXT_SEC};'
                        f'text-transform:uppercase;letter-spacing:.5px;margin-bottom:8px;">'
                        f'Documents</div>',
                        unsafe_allow_html=True,
                    )

                    def _show(label: str, val: str | None) -> bool:
                        if not val:
                            return False
                        v2 = val.strip()
                        st.caption(label)
                        if v2.startswith("data:"):
                            st.image(v2, use_column_width=True)
                        elif v2.startswith(("http://", "https://")):
                            st.image(v2, use_column_width=True)
                        else:
                            st.image(f"data:image/jpeg;base64,{v2}", use_column_width=True)
                        return True

                    shown = 0
                    shown += _show("Vehicle Photo",        v.get("vehicleImageBase64"))
                    shown += _show("Registration Document", v.get("vehicleLicenseImageBase64"))
                    if shown == 0:
                        st.markdown(
                            f'<div style="background:#F7FAFC;border:1px dashed {BORDER};'
                            f'border-radius:10px;padding:20px;text-align:center;'
                            f'color:{TEXT_SEC};font-size:13px;">'
                            f'No images uploaded</div>',
                            unsafe_allow_html=True,
                        )

                with c_act:
                    st.markdown(
                        f'<div style="font-size:12px;font-weight:700;color:{TEXT_SEC};'
                        f'text-transform:uppercase;letter-spacing:.5px;margin-bottom:10px;">'
                        f'Action</div>',
                        unsafe_allow_html=True,
                    )
                    st.info("Auto-verified ✅\nNo approval needed.", icon="ℹ️")
                    if st.button(
                        "✓  Mark Reviewed",
                        key=f"ver_review_{vid}",
                        type="primary",
                        use_container_width=True,
                    ):
                        ok = mark_vehicle_reviewed(vid)
                        if ok:
                            st.toast("Marked as reviewed!", icon="✅")
                            st.cache_data.clear()
                            st.rerun()
                        else:
                            st.warning("Action failed.")
