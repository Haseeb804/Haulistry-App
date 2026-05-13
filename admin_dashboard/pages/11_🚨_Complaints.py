"""
Complaints & disputes — low-rated feedback and cancelled/rejected bookings.
"""

import streamlit as st
import pandas as pd
from components.sidebar import render_sidebar
from core.database import get_all_feedback, get_all_bookings
from components.styles import (
    page_header, status_badge, fmt_date, fmt_currency,
    empty_state, kpi_card,
    PRIMARY, DANGER, WARNING, SUCCESS, TEXT_SEC, TEXT_PRIMARY, CARD_BG, BORDER,
)

st.set_page_config(
    page_title="Complaints · Haulistry Admin",
    page_icon="🚨",
    layout="wide",
)
render_sidebar()

page_header("Complaints & Disputes", "Low-rated feedback and cancelled or rejected bookings", "🚨")

@st.cache_data(ttl=60, show_spinner=False)
def _feedback():    return get_all_feedback(size=300)

@st.cache_data(ttl=60, show_spinner=False)
def _cancelled():   return get_all_bookings(status="cancelled", size=200)

@st.cache_data(ttl=60, show_spinner=False)
def _rejected():    return get_all_bookings(status="rejected", size=200)

# ── Summary KPIs ──────────────────────────────────────────────────────────────
all_feedback  = _feedback()
low_ratings   = [f for f in all_feedback if (f.get("rating") or 5) <= 2]
cancelled     = _cancelled()
rejected      = _rejected()

sc1, sc2, sc3 = st.columns(3)
with sc1:
    st.markdown(kpi_card("Low-Rated Reviews",   str(len(low_ratings)), color=DANGER), unsafe_allow_html=True)
with sc2:
    st.markdown(kpi_card("Cancelled Bookings",  str(len(cancelled)),   color=WARNING), unsafe_allow_html=True)
with sc3:
    st.markdown(kpi_card("Rejected Bookings",   str(len(rejected)),    color=WARNING), unsafe_allow_html=True)

st.markdown("<div style='height:16px'></div>", unsafe_allow_html=True)

t1, t2, t3 = st.tabs([
    "  ⭐ Low-Rated Feedback  ",
    "  ❌ Cancelled Bookings  ",
    "  ⛔ Rejected Bookings  ",
])

with t1:
    if not low_ratings:
        empty_state("No low-rated reviews", "All feedback is rated 3 stars or above.", "🌟")
    else:
        st.markdown(
            f'<div style="font-size:13px;color:{TEXT_SEC};margin-bottom:14px;">'
            f'<b style="color:{DANGER};">{len(low_ratings)}</b> low-rated reviews (≤ 2 stars)</div>',
            unsafe_allow_html=True,
        )
        for f in low_ratings:
            rating  = f.get("rating", 0)
            comment = f.get("comment", "No comment provided.")
            pid     = str(f.get("providerId", ""))[:8]
            sid     = str(f.get("seekerId", ""))[:8]
            rtype   = f.get("reviewerType", "—")
            ts      = fmt_date(f.get("createdAt"))
            stars   = "⭐" * int(rating) if isinstance(rating, (int, float)) else ""

            st.markdown(
                f"""
                <div style="background:#FFF5F5;border:1px solid #FED7D7;
                            border-left:4px solid {DANGER};
                            border-radius:12px;padding:16px 20px;margin-bottom:10px;">
                  <div style="display:flex;justify-content:space-between;align-items:center;">
                    <div style="font-size:18px;">{stars or "No rating"}</div>
                    <div style="font-size:11px;color:#A0AEC0;">{ts}</div>
                  </div>
                  <div style="margin-top:10px;color:{TEXT_PRIMARY};font-size:13.5px;
                              line-height:1.5;">{comment}</div>
                  <div style="margin-top:8px;font-size:12px;color:{TEXT_SEC};">
                    Reviewer: <b>{rtype.replace("_"," ").title()}</b>
                    &nbsp;·&nbsp; Provider: <code>{pid}…</code>
                    &nbsp;·&nbsp; Seeker: <code>{sid}…</code>
                  </div>
                </div>
                """,
                unsafe_allow_html=True,
            )

with t2:
    if not cancelled:
        empty_state("No cancelled bookings", "No bookings have been cancelled.", "✅")
    else:
        rows = [
            {
                "ID":       (b.get("id", "") or "")[:8] + "…",
                "Seeker":   b.get("seekerName", "—"),
                "Provider": b.get("providerName", "—"),
                "Service":  (b.get("serviceType") or "—").replace("_", " ").title(),
                "Est. Price": fmt_currency(b.get("estimatedPrice", 0)),
                "Date":     fmt_date(b.get("createdAt")),
            }
            for b in cancelled
        ]
        st.dataframe(pd.DataFrame(rows), use_container_width=True, hide_index=True)

with t3:
    if not rejected:
        empty_state("No rejected bookings", "No bookings have been rejected.", "✅")
    else:
        rows = [
            {
                "ID":       (b.get("id", "") or "")[:8] + "…",
                "Seeker":   b.get("seekerName", "—"),
                "Provider": b.get("providerName", "—"),
                "Service":  (b.get("serviceType") or "—").replace("_", " ").title(),
                "Est. Price": fmt_currency(b.get("estimatedPrice", 0)),
                "Date":     fmt_date(b.get("createdAt")),
            }
            for b in rejected
        ]
        st.dataframe(pd.DataFrame(rows), use_container_width=True, hide_index=True)
