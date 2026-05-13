"""
Transactions — Platform revenue overview and per-provider earnings tracker.
"""

import streamlit as st
import pandas as pd
from components.sidebar import render_sidebar
from components.styles import (
    page_header, fmt_currency, fmt_number, fmt_date, fmt_datetime,
    section_header, kpi_card, empty_state, status_badge, alert_info,
    PRIMARY, SECONDARY, ACCENT, SUCCESS, WARNING, DANGER, INFO,
    TEXT_SEC, TEXT_PRIMARY, CARD_BG, BORDER, BORDER_LIGHT, TEXT_MUTED,
)
from components.charts import revenue_line_chart, revenue_by_category_bar
from core.database import (
    get_revenue_stats, get_daily_revenue, get_revenue_by_category,
    get_all_bookings,
    get_all_providers_earnings, get_provider_earnings_summary,
    get_provider_transactions, get_provider_monthly_earnings,
    count_provider_transactions,
    PLATFORM_COMMISSION_RATE,
)

st.set_page_config(
    page_title="Transactions · Haulistry Admin",
    page_icon="💰",
    layout="wide",
)
render_sidebar()

page_header("Transactions", "Platform revenue & per-provider earnings", "💰")

tab_global, tab_providers = st.tabs([
    "  📊 Platform Overview  ",
    "  👷 Provider Earnings  ",
])

# ═══════════════════════════════════════════════════════════════════════════════
# TAB 1 — PLATFORM OVERVIEW
# ═══════════════════════════════════════════════════════════════════════════════
with tab_global:

    col_days, _ = st.columns([2, 3])
    with col_days:
        days = st.selectbox(
            "Period",
            [7, 14, 30, 60, 90],
            index=2,
            format_func=lambda d: f"Last {d} days",
            label_visibility="collapsed",
            key="global_days",
        )

    @st.cache_data(ttl=60, show_spinner=False)
    def _rev():         return get_revenue_stats()

    @st.cache_data(ttl=120, show_spinner=False)
    def _daily(d):      return get_daily_revenue(d)

    @st.cache_data(ttl=120, show_spinner=False)
    def _by_cat():      return get_revenue_by_category()

    @st.cache_data(ttl=60, show_spinner=False)
    def _completed():   return get_all_bookings(status="completed", size=300)

    with st.spinner("Loading financial data…"):
        rev       = _rev()
        daily     = _daily(days)
        by_cat    = _by_cat()
        completed = _completed()

    gross_rev  = float(rev.get("totalRevenue", 0) or 0)
    commission = gross_rev * PLATFORM_COMMISSION_RATE
    net_rev    = gross_rev * (1 - PLATFORM_COMMISSION_RATE)
    avg_val    = float(rev.get("avgBookingValue", 0) or 0)
    comp_count = int(rev.get("completedCount", 0) or 0)

    # ── KPIs ─────────────────────────────────────────────────────────────────
    c1, c2, c3, c4 = st.columns(4)
    kpis = [
        (c1, "Gross Revenue",      fmt_currency(gross_rev),  SECONDARY, "💰"),
        (c2, "Platform Commission", fmt_currency(commission), PRIMARY,   "🏛"),
        (c3, "Net to Providers",   fmt_currency(net_rev),    SUCCESS,   "👷"),
        (c4, "Avg Booking Value",  fmt_currency(avg_val),    ACCENT,    "📊"),
    ]
    for col, label, value, color, icon in kpis:
        with col:
            st.markdown(kpi_card(label, value, icon=icon, color=color),
                        unsafe_allow_html=True)

    st.markdown("<div style='height:20px'></div>", unsafe_allow_html=True)

    # ── Revenue charts ────────────────────────────────────────────────────────
    ch1, ch2 = st.columns([3, 2])

    with ch1:
        st.markdown(
            f'<div style="background:{CARD_BG};border:1px solid {BORDER};'
            f'border-radius:14px;padding:20px 22px;'
            f'box-shadow:0 1px 4px rgba(0,0,0,.04);">',
            unsafe_allow_html=True,
        )
        from components.charts import revenue_line_chart
        st.plotly_chart(revenue_line_chart(daily), use_container_width=True,
                        config={"displayModeBar": False})
        st.markdown("</div>", unsafe_allow_html=True)

    with ch2:
        st.markdown(
            f'<div style="background:{CARD_BG};border:1px solid {BORDER};'
            f'border-radius:14px;padding:20px 22px;'
            f'box-shadow:0 1px 4px rgba(0,0,0,.04);">',
            unsafe_allow_html=True,
        )
        st.plotly_chart(revenue_by_category_bar(by_cat), use_container_width=True,
                        config={"displayModeBar": False})
        st.markdown("</div>", unsafe_allow_html=True)

    st.markdown("<div style='height:8px'></div>", unsafe_allow_html=True)

    # ── Completed bookings table ──────────────────────────────────────────────
    section_header("Completed Bookings", f"{comp_count} total")

    if not completed:
        empty_state("No completed bookings yet", "", "💰")
    else:
        # ── Search / filter ───────────────────────────────────────────────────
        col_s, col_f = st.columns([3, 1])
        with col_s:
            search = st.text_input("Search", placeholder="Provider or seeker name…",
                                   label_visibility="collapsed", key="global_search")
        with col_f:
            sort_by = st.selectbox("Sort by",
                                   ["Newest first", "Highest amount", "Lowest amount"],
                                   label_visibility="collapsed", key="global_sort")

        rows = [b for b in completed if b.get("status") == "completed"]
        if search:
            q = search.lower()
            rows = [b for b in rows
                    if q in str(b.get("providerName", "")).lower()
                    or q in str(b.get("seekerName", "")).lower()
                    or q in str(b.get("serviceType", "")).lower()]

        if sort_by == "Highest amount":
            rows.sort(key=lambda b: float(b.get("finalPrice") or b.get("estimatedPrice") or 0),
                      reverse=True)
        elif sort_by == "Lowest amount":
            rows.sort(key=lambda b: float(b.get("finalPrice") or b.get("estimatedPrice") or 0))

        # Table header
        st.markdown(
            f'<div style="display:flex;padding:8px 0;border-bottom:2px solid {BORDER};'
            f'font-size:11px;font-weight:700;color:{TEXT_SEC};'
            f'text-transform:uppercase;letter-spacing:.5px;">'
            f'<div style="flex:2;">Booking / Date</div>'
            f'<div style="flex:2;">Provider</div>'
            f'<div style="flex:1.5;">Seeker</div>'
            f'<div style="flex:1;">Service</div>'
            f'<div style="flex:1;text-align:right;">Amount</div>'
            f'<div style="flex:1;text-align:right;">Commission</div>'
            f'<div style="flex:1;text-align:right;">Net</div>'
            f'</div>',
            unsafe_allow_html=True,
        )

        PAGE_SIZE = 20
        pkey = "global_tx_page"
        if pkey not in st.session_state:
            st.session_state[pkey] = 0
        page_idx = st.session_state[pkey]
        paged = rows[page_idx * PAGE_SIZE: (page_idx + 1) * PAGE_SIZE]

        for b in paged:
            amt  = float(b.get("finalPrice") or b.get("estimatedPrice") or 0)
            comm = amt * PLATFORM_COMMISSION_RATE
            net  = amt * (1 - PLATFORM_COMMISSION_RATE)
            st.markdown(
                f'<div style="display:flex;padding:11px 0;'
                f'border-bottom:1px solid {BORDER_LIGHT};align-items:center;">'
                f'<div style="flex:2;">'
                f'  <div style="font-size:12px;font-weight:600;color:{TEXT_PRIMARY};">'
                f'    {str(b.get("id",""))[:12]}…</div>'
                f'  <div style="font-size:11px;color:{TEXT_SEC};">'
                f'    {fmt_datetime(b.get("updatedAt"))}</div>'
                f'</div>'
                f'<div style="flex:2;font-size:13px;color:{TEXT_PRIMARY};">'
                f'  {b.get("providerName","—")}</div>'
                f'<div style="flex:1.5;font-size:13px;color:{TEXT_PRIMARY};">'
                f'  {b.get("seekerName","—")}</div>'
                f'<div style="flex:1;font-size:12px;color:{TEXT_SEC};">'
                f'  {str(b.get("serviceType","—")).replace("_"," ").title()}</div>'
                f'<div style="flex:1;text-align:right;font-size:13px;'
                f'font-weight:600;color:{TEXT_PRIMARY};">'
                f'  {fmt_currency(amt)}</div>'
                f'<div style="flex:1;text-align:right;font-size:12px;color:{DANGER};">'
                f'  -{fmt_currency(comm)}</div>'
                f'<div style="flex:1;text-align:right;font-size:13px;'
                f'font-weight:600;color:{SUCCESS};">'
                f'  {fmt_currency(net)}</div>'
                f'</div>',
                unsafe_allow_html=True,
            )

        # Pagination
        total_pages = max(1, -(-len(rows) // PAGE_SIZE))
        if total_pages > 1:
            pg_info, pg_prev, pg_next = st.columns([4, 1, 1])
            with pg_info:
                st.markdown(
                    f'<div style="font-size:12.5px;color:{TEXT_SEC};padding-top:10px;">'
                    f'Showing <b>{page_idx * PAGE_SIZE + 1}–'
                    f'{min((page_idx + 1) * PAGE_SIZE, len(rows))}</b> of <b>{len(rows)}</b>'
                    f'</div>',
                    unsafe_allow_html=True,
                )
            with pg_prev:
                if st.button("← Prev", key="global_prev",
                             disabled=(page_idx == 0)):
                    st.session_state[pkey] -= 1
                    st.rerun()
            with pg_next:
                if st.button("Next →", key="global_next",
                             disabled=(page_idx >= total_pages - 1)):
                    st.session_state[pkey] += 1
                    st.rerun()


# ═══════════════════════════════════════════════════════════════════════════════
# TAB 2 — PROVIDER EARNINGS
# ═══════════════════════════════════════════════════════════════════════════════
with tab_providers:

    @st.cache_data(ttl=60, show_spinner=False)
    def _all_earnings():
        return get_all_providers_earnings(size=200)

    with st.spinner("Loading provider earnings…"):
        all_earnings = _all_earnings()

    if not all_earnings:
        empty_state("No provider earnings data",
                    "Earnings are calculated from completed bookings.", "👷")
        st.stop()

    # ── Platform totals ───────────────────────────────────────────────────────
    total_gross = sum(float(p.get("grossEarnings") or 0) for p in all_earnings)
    total_comm  = total_gross * PLATFORM_COMMISSION_RATE
    total_net   = total_gross * (1 - PLATFORM_COMMISSION_RATE)
    total_pend  = sum(float(p.get("pendingValue") or 0) for p in all_earnings)

    pt1, pt2, pt3, pt4 = st.columns(4)
    platform_kpis = [
        (pt1, "Total Gross (all providers)", fmt_currency(total_gross), SECONDARY, "💰"),
        (pt2, "Total Commission (10%)",       fmt_currency(total_comm),  DANGER,    "🏛"),
        (pt3, "Total Net to Providers",       fmt_currency(total_net),   SUCCESS,   "✅"),
        (pt4, "Pending Payouts",              fmt_currency(total_pend),  WARNING,   "⏳"),
    ]
    for col, label, value, color, icon in platform_kpis:
        with col:
            st.markdown(kpi_card(label, value, icon=icon, color=color),
                        unsafe_allow_html=True)

    st.markdown("<div style='height:24px'></div>", unsafe_allow_html=True)

    # ── Provider summary table ────────────────────────────────────────────────
    section_header("All Providers", f"{len(all_earnings)} providers")

    col_search, _ = st.columns([2, 3])
    with col_search:
        prov_search = st.text_input("Search providers",
                                    placeholder="Name or email…",
                                    label_visibility="collapsed",
                                    key="prov_search")

    filtered = all_earnings
    if prov_search:
        q = prov_search.lower()
        filtered = [p for p in all_earnings
                    if q in str(p.get("providerName", "")).lower()
                    or q in str(p.get("providerEmail", "")).lower()]

    # Table header
    st.markdown(
        f'<div style="display:flex;padding:8px 0;border-bottom:2px solid {BORDER};'
        f'font-size:11px;font-weight:700;color:{TEXT_SEC};'
        f'text-transform:uppercase;letter-spacing:.5px;">'
        f'<div style="flex:2.5;">Provider</div>'
        f'<div style="flex:1;">Jobs</div>'
        f'<div style="flex:1.5;text-align:right;">Gross Earnings</div>'
        f'<div style="flex:1.5;text-align:right;">Commission (10%)</div>'
        f'<div style="flex:1.5;text-align:right;">Net Earnings</div>'
        f'<div style="flex:1.5;text-align:right;">Pending</div>'
        f'<div style="flex:1;text-align:center;">Detail</div>'
        f'</div>',
        unsafe_allow_html=True,
    )

    for p in filtered:
        pid         = p.get("providerId", "")
        pname       = p.get("providerName", "—")
        pemail      = p.get("providerEmail", "—")
        is_verified = p.get("isVerified", False)
        jobs        = int(p.get("completedBookings") or 0)
        gross       = float(p.get("grossEarnings") or 0)
        comm        = float(p.get("commission") or 0)
        net         = float(p.get("netEarnings") or 0)
        pend        = float(p.get("pendingValue") or 0)
        initials    = pname[:2].upper() if pname and pname != "—" else "??"

        c_name, c_jobs, c_gross, c_comm, c_net, c_pend, c_btn = st.columns(
            [2.5, 1, 1.5, 1.5, 1.5, 1.5, 1]
        )
        with c_name:
            st.markdown(
                f'<div style="display:flex;align-items:center;gap:10px;padding:10px 0;">'
                f'<div style="width:34px;height:34px;border-radius:8px;flex-shrink:0;'
                f'background:linear-gradient(135deg,{PRIMARY}22,{ACCENT}22);'
                f'display:flex;align-items:center;justify-content:center;'
                f'font-size:12px;font-weight:700;color:{PRIMARY};">{initials}</div>'
                f'<div>'
                f'<div style="font-weight:600;font-size:13px;color:{TEXT_PRIMARY};">'
                f'{pname}</div>'
                f'<div style="font-size:11px;color:{TEXT_SEC};">{pemail}</div>'
                f'</div></div>',
                unsafe_allow_html=True,
            )
        with c_jobs:
            st.markdown(
                f'<div style="padding:14px 0;font-size:13px;font-weight:600;'
                f'color:{TEXT_PRIMARY};">{jobs}</div>',
                unsafe_allow_html=True,
            )
        with c_gross:
            st.markdown(
                f'<div style="padding:14px 0;text-align:right;font-size:13px;'
                f'font-weight:700;color:{SECONDARY};">{fmt_currency(gross)}</div>',
                unsafe_allow_html=True,
            )
        with c_comm:
            st.markdown(
                f'<div style="padding:14px 0;text-align:right;font-size:13px;'
                f'color:{DANGER};">-{fmt_currency(comm)}</div>',
                unsafe_allow_html=True,
            )
        with c_net:
            st.markdown(
                f'<div style="padding:14px 0;text-align:right;font-size:13px;'
                f'font-weight:700;color:{SUCCESS};">{fmt_currency(net)}</div>',
                unsafe_allow_html=True,
            )
        with c_pend:
            pend_color = WARNING if pend > 0 else TEXT_MUTED
            st.markdown(
                f'<div style="padding:14px 0;text-align:right;font-size:13px;'
                f'color:{pend_color};">{fmt_currency(pend)}</div>',
                unsafe_allow_html=True,
            )
        with c_btn:
            st.markdown("<div style='padding-top:8px;'></div>", unsafe_allow_html=True)
            if st.button("View", key=f"pv_{pid}", use_container_width=True):
                st.session_state["tx_provider_id"] = pid
                st.session_state["tx_provider_name"] = pname

        st.markdown(f'<div style="border-bottom:1px solid {BORDER_LIGHT};"></div>',
                    unsafe_allow_html=True)

    # ── Provider detail panel ─────────────────────────────────────────────────
    sel_pid   = st.session_state.get("tx_provider_id")
    sel_pname = st.session_state.get("tx_provider_name", "")

    if not sel_pid:
        st.markdown(
            f'<div style="background:{CARD_BG};border:1px solid {BORDER};'
            f'border-radius:14px;padding:32px;text-align:center;margin-top:24px;">'
            f'<div style="font-size:32px;margin-bottom:12px;">👆</div>'
            f'<div style="font-size:14px;font-weight:600;color:{TEXT_SEC};">'
            f'Click <b>View</b> on any provider above to see their full transaction detail.'
            f'</div></div>',
            unsafe_allow_html=True,
        )
        st.stop()

    # ── Selected provider header ──────────────────────────────────────────────
    st.markdown("<div style='height:28px'></div>", unsafe_allow_html=True)
    st.markdown(
        f'<div style="display:flex;align-items:center;justify-content:space-between;'
        f'margin-bottom:16px;">'
        f'<div style="font-size:18px;font-weight:800;color:{TEXT_PRIMARY};">'
        f'📋 Detail: {sel_pname}</div>'
        f'</div>',
        unsafe_allow_html=True,
    )

    @st.cache_data(ttl=30, show_spinner=False)
    def _summary(pid):   return get_provider_earnings_summary(pid)

    @st.cache_data(ttl=60, show_spinner=False)
    def _monthly(pid):   return get_provider_monthly_earnings(pid, months=12)

    with st.spinner(f"Loading {sel_pname} earnings…"):
        summary = _summary(sel_pid)
        monthly = _monthly(sel_pid)

    if not summary:
        st.warning("Could not load provider data.")
        st.stop()

    gross_p = float(summary.get("grossEarnings") or 0)
    comm_p  = float(summary.get("commission") or 0)
    net_p   = float(summary.get("netEarnings") or 0)
    pend_p  = float(summary.get("pendingValue") or 0)
    jobs_p  = int(summary.get("completedBookings") or 0)
    total_p = int(summary.get("totalBookings") or 0)
    avg_p   = (gross_p / jobs_p) if jobs_p > 0 else 0

    # KPI cards
    dp1, dp2, dp3, dp4, dp5, dp6 = st.columns(6)
    detail_kpis = [
        (dp1, "Gross Earnings",   fmt_currency(gross_p), SECONDARY),
        (dp2, "Commission (10%)", fmt_currency(comm_p),  DANGER),
        (dp3, "Net Earnings",     fmt_currency(net_p),   SUCCESS),
        (dp4, "Pending",          fmt_currency(pend_p),  WARNING),
        (dp5, "Completed Jobs",   fmt_number(jobs_p),    ACCENT),
        (dp6, "Avg per Job",      fmt_currency(avg_p),   INFO),
    ]
    for col, label, value, color in detail_kpis:
        with col:
            st.markdown(kpi_card(label, value, color=color), unsafe_allow_html=True)

    st.markdown("<div style='height:20px'></div>", unsafe_allow_html=True)

    # ── Monthly earnings table ────────────────────────────────────────────────
    if monthly:
        section_header("Monthly Earnings (Last 12 Months)")
        df_m = pd.DataFrame(monthly)
        if "month" in df_m.columns:
            df_m["month"] = df_m["month"].astype(str).str[:7]
            df_m["revenue"] = df_m["revenue"].apply(lambda v: float(v or 0))
            df_m["commission"] = df_m["revenue"] * PLATFORM_COMMISSION_RATE
            df_m["net"] = df_m["revenue"] * (1 - PLATFORM_COMMISSION_RATE)

            st.markdown(
                f'<div style="background:{CARD_BG};border:1px solid {BORDER};'
                f'border-radius:14px;padding:0;overflow:hidden;'
                f'box-shadow:0 1px 4px rgba(0,0,0,.04);">',
                unsafe_allow_html=True,
            )
            hdr = (
                f'<div style="display:flex;padding:10px 20px;'
                f'background:#F7FAFC;border-bottom:1px solid {BORDER};'
                f'font-size:11px;font-weight:700;color:{TEXT_SEC};'
                f'text-transform:uppercase;letter-spacing:.5px;">'
                f'<div style="flex:1.5;">Month</div>'
                f'<div style="flex:1;">Bookings</div>'
                f'<div style="flex:1.5;text-align:right;">Gross</div>'
                f'<div style="flex:1.5;text-align:right;">Commission</div>'
                f'<div style="flex:1.5;text-align:right;">Net</div>'
                f'</div>'
            )
            st.markdown(hdr, unsafe_allow_html=True)

            for _, row in df_m.iterrows():
                st.markdown(
                    f'<div style="display:flex;padding:10px 20px;'
                    f'border-bottom:1px solid {BORDER_LIGHT};">'
                    f'<div style="flex:1.5;font-size:13px;color:{TEXT_PRIMARY};'
                    f'font-weight:600;">{row["month"]}</div>'
                    f'<div style="flex:1;font-size:13px;color:{TEXT_PRIMARY};">'
                    f'{int(row["bookings"])}</div>'
                    f'<div style="flex:1.5;text-align:right;font-size:13px;'
                    f'font-weight:600;color:{SECONDARY};">'
                    f'{fmt_currency(row["revenue"])}</div>'
                    f'<div style="flex:1.5;text-align:right;font-size:13px;'
                    f'color:{DANGER};">-{fmt_currency(row["commission"])}</div>'
                    f'<div style="flex:1.5;text-align:right;font-size:13px;'
                    f'font-weight:600;color:{SUCCESS};">'
                    f'{fmt_currency(row["net"])}</div>'
                    f'</div>',
                    unsafe_allow_html=True,
                )
            st.markdown("</div>", unsafe_allow_html=True)
        st.markdown("<div style='height:20px'></div>", unsafe_allow_html=True)

    # ── Transaction history ───────────────────────────────────────────────────
    section_header("Transaction History", f"All bookings for {sel_pname}")

    col_ts, col_tf = st.columns([3, 1])
    with col_ts:
        tx_search = st.text_input("Search transactions",
                                  placeholder="Seeker name or service…",
                                  label_visibility="collapsed",
                                  key="tx_search")
    with col_tf:
        tx_status = st.selectbox(
            "Filter by status",
            ["All", "completed", "cancelled", "active", "pending", "in_progress"],
            label_visibility="collapsed",
            key="tx_status_filter",
        )

    tx_status_val = None if tx_status == "All" else tx_status
    tx_page_key   = "tx_detail_page"
    if tx_page_key not in st.session_state:
        st.session_state[tx_page_key] = 0

    TX_PAGE_SIZE = 25

    @st.cache_data(ttl=30, show_spinner=False)
    def _txns(pid, status, page):
        return get_provider_transactions(pid, page=page, size=TX_PAGE_SIZE, status=status)

    @st.cache_data(ttl=30, show_spinner=False)
    def _txn_count(pid, status):
        return count_provider_transactions(pid, status=status)

    txns       = _txns(sel_pid, tx_status_val, st.session_state[tx_page_key])
    txn_total  = _txn_count(sel_pid, tx_status_val)

    if tx_search:
        sq = tx_search.lower()
        txns = [t for t in txns
                if sq in str(t.get("seekerName", "")).lower()
                or sq in str(t.get("serviceType", "")).lower()]

    if not txns:
        empty_state("No transactions found", "Try adjusting your filters.", "🔍")
    else:
        st.markdown(
            f'<div style="display:flex;padding:8px 0;border-bottom:2px solid {BORDER};'
            f'font-size:11px;font-weight:700;color:{TEXT_SEC};'
            f'text-transform:uppercase;letter-spacing:.5px;">'
            f'<div style="flex:2;">Date</div>'
            f'<div style="flex:1.5;">Seeker</div>'
            f'<div style="flex:1.5;">Service</div>'
            f'<div style="flex:1;">Status</div>'
            f'<div style="flex:1;text-align:right;">Amount</div>'
            f'<div style="flex:1;text-align:right;">Commission</div>'
            f'<div style="flex:1;text-align:right;">Net</div>'
            f'</div>',
            unsafe_allow_html=True,
        )

        for t in txns:
            amt   = float(t.get("amount") or 0)
            comm  = amt * PLATFORM_COMMISSION_RATE
            net   = amt * (1 - PLATFORM_COMMISSION_RATE)
            stype = str(t.get("serviceType") or "—").replace("_", " ").title()
            st.markdown(
                f'<div style="display:flex;padding:10px 0;'
                f'border-bottom:1px solid {BORDER_LIGHT};align-items:center;">'
                f'<div style="flex:2;">'
                f'  <div style="font-size:12px;color:{TEXT_PRIMARY};">'
                f'    {fmt_datetime(t.get("createdAt"))}</div>'
                f'  <div style="font-size:11px;color:{TEXT_MUTED};">'
                f'    #{str(t.get("id",""))[:10]}</div>'
                f'</div>'
                f'<div style="flex:1.5;font-size:13px;color:{TEXT_PRIMARY};">'
                f'  {t.get("seekerName","—")}</div>'
                f'<div style="flex:1.5;font-size:12px;color:{TEXT_SEC};">'
                f'  {stype}</div>'
                f'<div style="flex:1;">{status_badge(t.get("status",""))}</div>'
                f'<div style="flex:1;text-align:right;font-size:13px;'
                f'font-weight:600;color:{TEXT_PRIMARY};">'
                f'  {fmt_currency(amt)}</div>'
                f'<div style="flex:1;text-align:right;font-size:12px;color:{DANGER};">'
                f'  -{fmt_currency(comm)}</div>'
                f'<div style="flex:1;text-align:right;font-size:13px;'
                f'font-weight:600;color:{SUCCESS if t.get("status")=="completed" else TEXT_MUTED};">'
                f'  {fmt_currency(net) if t.get("status")=="completed" else "—"}</div>'
                f'</div>',
                unsafe_allow_html=True,
            )

        # Pagination
        total_pages = max(1, -(-txn_total // TX_PAGE_SIZE))
        if total_pages > 1:
            pi, pp, pn = st.columns([4, 1, 1])
            pi_idx = st.session_state[tx_page_key]
            with pi:
                st.markdown(
                    f'<div style="font-size:12.5px;color:{TEXT_SEC};padding-top:10px;">'
                    f'Page <b>{pi_idx + 1}</b> of <b>{total_pages}</b> '
                    f'({txn_total} transactions)</div>',
                    unsafe_allow_html=True,
                )
            with pp:
                if st.button("← Prev", key="tx_prev",
                             disabled=(pi_idx == 0)):
                    st.session_state[tx_page_key] -= 1
                    st.rerun()
            with pn:
                if st.button("Next →", key="tx_next",
                             disabled=(pi_idx >= total_pages - 1)):
                    st.session_state[tx_page_key] += 1
                    st.rerun()
