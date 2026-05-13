"""
Provider verification workflow — approve or reject pending providers.
"""

import streamlit as st
from components.sidebar import render_sidebar
from core.database import get_pending_providers, verify_provider, reject_provider
from core.api_client import notify_provider_approved, notify_provider_rejected
from components.styles import (
    page_header, status_badge, fmt_date,
    empty_state, PRIMARY, SECONDARY, DANGER, WARNING,
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
    st.stop()

# ── Summary bar ───────────────────────────────────────────────────────────────
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
            vehicle_img    = p.get("vehicleImageBase64")
            cnic_front_img = p.get("cnicFrontImageBase64")
            cnic_back_img  = p.get("cnicBackImageBase64")
            license_img    = p.get("licenseImageBase64")

            st.markdown(
                f'<div style="font-size:12px;font-weight:700;color:{TEXT_SEC};'
                f'text-transform:uppercase;letter-spacing:.5px;margin-bottom:10px;">'
                f'Documents</div>',
                unsafe_allow_html=True,
            )

            any_doc = False
            if vehicle_img:
                any_doc = True
                st.caption("Vehicle Photo")
                st.image(f"data:image/jpeg;base64,{vehicle_img}", use_container_width=True)
            if cnic_front_img:
                any_doc = True
                st.caption("CNIC — Front")
                st.image(f"data:image/jpeg;base64,{cnic_front_img}", use_container_width=True)
            if cnic_back_img:
                any_doc = True
                st.caption("CNIC — Back")
                st.image(f"data:image/jpeg;base64,{cnic_back_img}", use_container_width=True)
            if license_img:
                any_doc = True
                st.caption("Driving License")
                st.image(f"data:image/jpeg;base64,{license_img}", use_container_width=True)
            if not any_doc:
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
