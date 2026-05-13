"""
Global design system for Haulistry Admin Dashboard.
Call inject_global_css() once at the top of every page.
"""

import streamlit as st
from typing import Any

# ─── Brand tokens ──────────────────────────────────────────────────────────────
PRIMARY      = "#FF6B35"
PRIMARY_DARK = "#E55A2B"
SECONDARY    = "#00B894"
ACCENT       = "#6C5CE7"
DANGER       = "#E74C3C"
WARNING      = "#F39C12"
INFO         = "#3498DB"
SUCCESS      = "#27AE60"

DARK_BG      = "#1A1A2E"
DARK_SURFACE = "#16213E"
CARD_BG      = "#FFFFFF"
PAGE_BG      = "#F4F6FB"
TEXT_PRIMARY = "#1A202C"
TEXT_SEC     = "#718096"
TEXT_MUTED   = "#A0AEC0"
BORDER       = "#E2E8F0"
BORDER_LIGHT = "#EDF2F7"

STATUS_COLORS = {
    "pending":           ("#FFF8F0", "#C05621", "●"),
    "accepted":          ("#F0FFF4", "#276749", "●"),
    "active":            ("#EBF8FF", "#2B6CB0", "●"),
    "provider_arriving": ("#FFFBEB", "#975A16", "●"),
    "provider_arrived":  ("#F0FFF4", "#276749", "●"),
    "in_progress":       ("#EBF4FF", "#2C5282", "●"),
    "completed":         ("#F0FFF4", "#1A4731", "✓"),
    "cancelled":         ("#FFF5F5", "#742A2A", "✗"),
    "rejected":          ("#FFF5F5", "#742A2A", "✗"),
    "verified":          ("#F0FFF4", "#1A4731", "✓"),
    "unverified":        ("#FFF8F0", "#C05621", "⚠"),
    "active_user":       ("#F0FFF4", "#276749", "●"),
    "inactive":          ("#FFF5F5", "#742A2A", "●"),
    "scheduled":         ("#F0F4FF", "#3730A3", "◷"),
    "confirmed":         ("#ECFDF5", "#065F46", "✓"),
}

_STATUS_BADGE_DOT = {
    "completed":  "#27AE60",
    "active":     "#3498DB",
    "accepted":   "#27AE60",
    "confirmed":  "#27AE60",
    "pending":    "#F39C12",
    "scheduled":  "#6C5CE7",
    "cancelled":  "#E74C3C",
    "rejected":   "#E74C3C",
    "inactive":   "#E74C3C",
    "unverified": "#F39C12",
    "verified":   "#27AE60",
    "in_progress":"#3498DB",
}


def status_badge(status: str) -> str:
    s = str(status).lower()
    cfg = STATUS_COLORS.get(s, ("#F7FAFC", "#4A5568", "•"))
    bg, color, icon = cfg
    dot_color = _STATUS_BADGE_DOT.get(s, "#718096")
    label = str(status).replace("_", " ").title()
    return (
        f'<span style="display:inline-flex;align-items:center;gap:5px;'
        f'background:{bg};color:{color};padding:3px 10px;'
        f'border-radius:20px;font-size:11.5px;font-weight:600;'
        f'white-space:nowrap;letter-spacing:.2px;">'
        f'<span style="width:6px;height:6px;border-radius:50%;'
        f'background:{dot_color};flex-shrink:0;"></span>{label}</span>'
    )


def inject_global_css():
    st.markdown(
        f"""
        <style>
        @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap');

        /* ── Reset & page ── */
        html, body, [data-testid="stAppViewContainer"],
        [data-testid="stAppViewContainer"] > .main {{
            background-color: {PAGE_BG} !important;
            font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif !important;
        }}
        [data-testid="stHeader"] {{
            background-color: {PAGE_BG} !important;
            border-bottom: 1px solid {BORDER} !important;
            box-shadow: 0 1px 3px rgba(0,0,0,.05) !important;
        }}
        [data-testid="stDecoration"] {{ display: none !important; }}
        #MainMenu, footer {{ visibility: hidden !important; }}
        [data-testid="stMainBlockContainer"] {{
            padding-top: 20px !important;
            padding-bottom: 48px !important;
            max-width: 1400px !important;
        }}

        /* ── Sidebar ── */
        [data-testid="stSidebarNav"] {{ display: none !important; }}
        [data-testid="stSidebar"] {{
            background: linear-gradient(180deg, {DARK_BG} 0%, {DARK_SURFACE} 100%) !important;
            border-right: 1px solid rgba(255,255,255,.06) !important;
        }}
        [data-testid="stSidebar"] p,
        [data-testid="stSidebar"] span,
        [data-testid="stSidebar"] li,
        [data-testid="stSidebar"] label,
        [data-testid="stSidebar"] a {{
            color: rgba(255,255,255,.75) !important;
        }}
        [data-testid="stSidebar"] .stMarkdown p {{
            color: rgba(255,255,255,.75) !important;
            font-size: 13px !important;
        }}

        /* ── Metric cards ── */
        [data-testid="stMetric"] {{
            background    : {CARD_BG} !important;
            border        : 1px solid {BORDER} !important;
            border-radius : 14px !important;
            padding       : 20px 22px !important;
            box-shadow    : 0 1px 4px rgba(0,0,0,.04),0 4px 12px rgba(0,0,0,.04) !important;
            transition    : box-shadow .2s, transform .2s !important;
        }}
        [data-testid="stMetric"]:hover {{
            box-shadow: 0 4px 16px rgba(0,0,0,.08) !important;
            transform: translateY(-1px) !important;
        }}
        [data-testid="stMetricValue"] {{
            font-size   : 30px !important;
            font-weight : 800 !important;
            color       : {TEXT_PRIMARY} !important;
            line-height : 1.15 !important;
            letter-spacing: -.5px !important;
        }}
        [data-testid="stMetricLabel"] {{
            font-size   : 11.5px !important;
            color       : {TEXT_SEC} !important;
            font-weight : 600 !important;
            text-transform: uppercase !important;
            letter-spacing: .6px !important;
        }}
        [data-testid="stMetricDelta"] {{
            font-size: 12.5px !important;
            font-weight: 600 !important;
        }}
        [data-testid="stMetricDelta"] svg {{ display: none !important; }}

        /* ── Buttons ── */
        .stButton > button[kind="primary"] {{
            background    : linear-gradient(135deg,{PRIMARY} 0%,{PRIMARY_DARK} 100%) !important;
            border        : none !important;
            border-radius : 10px !important;
            font-weight   : 600 !important;
            font-size     : 13.5px !important;
            padding       : 9px 20px !important;
            box-shadow    : 0 3px 12px rgba(255,107,53,.30) !important;
            transition    : transform .15s, box-shadow .15s !important;
            color         : #fff !important;
            letter-spacing: .2px !important;
        }}
        .stButton > button[kind="primary"]:hover {{
            transform  : translateY(-1px) !important;
            box-shadow : 0 6px 20px rgba(255,107,53,.40) !important;
        }}
        .stButton > button {{
            border-radius : 10px !important;
            font-weight   : 500 !important;
            font-size     : 13px !important;
            border        : 1.5px solid {BORDER} !important;
            background    : {CARD_BG} !important;
            color         : {TEXT_PRIMARY} !important;
            transition    : border-color .15s, box-shadow .15s, background .15s !important;
            padding       : 9px 16px !important;
        }}
        .stButton > button:hover {{
            border-color : {PRIMARY} !important;
            box-shadow   : 0 0 0 3px rgba(255,107,53,.10) !important;
            background   : #FFF8F5 !important;
        }}

        /* ── Inputs ── */
        .stTextInput > label,
        .stSelectbox > label,
        .stTextArea > label,
        .stNumberInput > label,
        .stMultiSelect > label {{
            font-size    : 12.5px !important;
            font-weight  : 600 !important;
            color        : {TEXT_SEC} !important;
            margin-bottom: 5px !important;
            letter-spacing: .3px !important;
        }}
        .stTextInput input,
        .stNumberInput input {{
            border        : 1.5px solid {BORDER} !important;
            border-radius : 10px !important;
            font-size     : 13.5px !important;
            color         : {TEXT_PRIMARY} !important;
            background    : #FAFBFF !important;
            padding       : 10px 14px !important;
            transition    : border-color .2s, box-shadow .2s, background .2s !important;
        }}
        .stTextInput input:focus,
        .stNumberInput input:focus {{
            border-color : {PRIMARY} !important;
            box-shadow   : 0 0 0 3px rgba(255,107,53,.10) !important;
            background   : {CARD_BG} !important;
            outline      : none !important;
        }}
        .stTextArea textarea {{
            border        : 1.5px solid {BORDER} !important;
            border-radius : 10px !important;
            font-size     : 13.5px !important;
            color         : {TEXT_PRIMARY} !important;
            background    : #FAFBFF !important;
            transition    : border-color .2s, box-shadow .2s !important;
            padding       : 10px 14px !important;
        }}
        .stTextArea textarea:focus {{
            border-color : {PRIMARY} !important;
            box-shadow   : 0 0 0 3px rgba(255,107,53,.10) !important;
        }}
        [data-testid="stSelectbox"] > div > div,
        [data-testid="stMultiSelect"] > div > div {{
            border        : 1.5px solid {BORDER} !important;
            border-radius : 10px !important;
            font-size     : 13.5px !important;
            background    : #FAFBFF !important;
        }}
        [data-testid="stSelectbox"] > div > div:focus-within,
        [data-testid="stMultiSelect"] > div > div:focus-within {{
            border-color : {PRIMARY} !important;
            box-shadow   : 0 0 0 3px rgba(255,107,53,.10) !important;
        }}

        /* ── Tabs ── */
        .stTabs [data-baseweb="tab-list"] {{
            background    : {CARD_BG} !important;
            border-radius : 12px !important;
            padding       : 4px !important;
            border        : 1px solid {BORDER} !important;
            gap           : 3px !important;
            box-shadow    : 0 1px 3px rgba(0,0,0,.04) !important;
        }}
        .stTabs [data-baseweb="tab"] {{
            border-radius : 9px !important;
            font-weight   : 600 !important;
            font-size     : 13px !important;
            color         : {TEXT_SEC} !important;
            padding       : 8px 18px !important;
            transition    : all .18s !important;
        }}
        .stTabs [aria-selected="true"] {{
            background : linear-gradient(135deg,{PRIMARY},{PRIMARY_DARK}) !important;
            color      : #fff !important;
            box-shadow : 0 3px 10px rgba(255,107,53,.25) !important;
        }}
        [data-testid="stTabContent"] {{
            padding-top: 20px !important;
        }}

        /* ── Dataframe ── */
        [data-testid="stDataFrame"] {{
            border-radius : 12px !important;
            overflow      : hidden !important;
            border        : 1px solid {BORDER} !important;
            box-shadow    : 0 1px 4px rgba(0,0,0,.04) !important;
        }}

        /* ── Expander ── */
        [data-testid="stExpander"] {{
            border        : 1px solid {BORDER} !important;
            border-radius : 12px !important;
            background    : {CARD_BG} !important;
            box-shadow    : 0 1px 4px rgba(0,0,0,.04) !important;
            margin-bottom : 8px !important;
        }}
        [data-testid="stExpander"] summary {{
            border-radius : 12px !important;
            font-weight   : 600 !important;
            font-size     : 13.5px !important;
            padding       : 14px 18px !important;
            color         : {TEXT_PRIMARY} !important;
        }}
        [data-testid="stExpander"] summary:hover {{
            background: #F7F9FC !important;
        }}

        /* ── Alerts ── */
        [data-testid="stAlert"] {{
            border-radius : 12px !important;
            font-size     : 13px !important;
            font-weight   : 500 !important;
            border-left-width: 4px !important;
        }}
        [data-testid="stAlert"][data-baseweb="notification"] {{
            border-radius : 12px !important;
        }}

        /* ── Divider ── */
        hr {{
            border: none !important;
            border-top: 1px solid {BORDER_LIGHT} !important;
            margin: 20px 0 !important;
        }}

        /* ── Scrollbar ── */
        ::-webkit-scrollbar {{ width: 5px; height: 5px; }}
        ::-webkit-scrollbar-track {{ background: transparent; }}
        ::-webkit-scrollbar-thumb {{
            background    : {BORDER};
            border-radius : 10px;
        }}
        ::-webkit-scrollbar-thumb:hover {{ background: #CBD5E0; }}

        /* ── Spinner ── */
        [data-testid="stSpinner"] > div {{
            border-color  : {PRIMARY} transparent transparent transparent !important;
        }}

        /* ── Progress bar ── */
        [data-testid="stProgressBar"] > div > div {{
            background: linear-gradient(90deg,{PRIMARY},{PRIMARY_DARK}) !important;
            border-radius: 10px !important;
        }}

        /* ── Checkbox ── */
        [data-testid="stCheckbox"] label span {{
            font-size: 13px !important;
            color: {TEXT_PRIMARY} !important;
        }}

        /* ── Toast notifications ── */
        [data-testid="stToast"] {{
            border-radius : 14px !important;
            font-size     : 13.5px !important;
            font-weight   : 500 !important;
        }}
        </style>
        """,
        unsafe_allow_html=True,
    )


# ─── Page header ──────────────────────────────────────────────────────────────

def page_header(title: str, subtitle: str = "", icon: str = "", actions_html: str = ""):
    actions_block = (
        f'<div style="margin-top:4px;">{actions_html}</div>' if actions_html else ""
    )
    st.markdown(
        f"""
        <div style="display:flex;align-items:flex-start;justify-content:space-between;
                    margin-bottom:24px;padding-bottom:18px;
                    border-bottom:1.5px solid {BORDER_LIGHT};">
          <div>
            <div style="display:flex;align-items:center;gap:10px;margin-bottom:3px;">
              <div style="width:4px;height:30px;border-radius:3px;
                          background:linear-gradient(180deg,{PRIMARY},{PRIMARY_DARK});
                          flex-shrink:0;"></div>
              <h1 style="font-size:24px;font-weight:800;color:{TEXT_PRIMARY};
                          margin:0;letter-spacing:-.4px;line-height:1.2;">
                {(icon + "&nbsp;") if icon else ""}{title}
              </h1>
            </div>
            {'<p style="font-size:13.5px;color:' + TEXT_SEC + ';margin:0 0 0 14px;">' + subtitle + '</p>' if subtitle else ''}
          </div>
          {actions_block}
        </div>
        """,
        unsafe_allow_html=True,
    )


# ─── KPI card ─────────────────────────────────────────────────────────────────

def kpi_card(label: str, value: Any, delta: str = "", icon: str = "",
             color: str = PRIMARY, subtitle: str = ""):
    delta_html = ""
    if delta:
        is_pos = not delta.startswith("-")
        dc = "#27AE60" if is_pos else "#E74C3C"
        arrow = "↑" if is_pos else "↓"
        delta_html = (
            f'<div style="margin-top:8px;font-size:12px;font-weight:600;color:{dc};">'
            f'{arrow} {delta}</div>'
        )
    sub_html = (
        f'<div style="font-size:11.5px;color:{TEXT_MUTED};margin-top:4px;">{subtitle}</div>'
        if subtitle else ""
    )
    return (
        f'<div style="background:{CARD_BG};border:1px solid {BORDER};border-radius:14px;'
        f'padding:20px 22px;box-shadow:0 1px 4px rgba(0,0,0,.04),'
        f'0 4px 12px rgba(0,0,0,.04);position:relative;overflow:hidden;">'
        f'<div style="position:absolute;top:0;left:0;width:4px;height:100%;'
        f'background:{color};border-radius:14px 0 0 14px;"></div>'
        f'<div style="padding-left:4px;">'
        f'<div style="display:flex;align-items:flex-start;justify-content:space-between;">'
        f'<div>'
        f'<div style="font-size:11.5px;font-weight:600;color:{TEXT_SEC};'
        f'text-transform:uppercase;letter-spacing:.6px;margin-bottom:8px;">{label}</div>'
        f'<div style="font-size:30px;font-weight:800;color:{TEXT_PRIMARY};'
        f'letter-spacing:-.5px;line-height:1.1;">{value}</div>'
        f'{delta_html}{sub_html}'
        f'</div>'
        + (f'<div style="font-size:28px;opacity:.15;">{icon}</div>' if icon else "")
        + '</div></div></div>'
    )


# ─── Empty state ──────────────────────────────────────────────────────────────

def empty_state(title: str, subtitle: str = "", icon: str = "📭"):
    st.markdown(
        f"""
        <div style="text-align:center;padding:60px 20px;
                    background:{CARD_BG};border:1px solid {BORDER};
                    border-radius:16px;margin:16px 0;">
          <div style="font-size:48px;margin-bottom:14px;opacity:.6;">{icon}</div>
          <div style="font-size:16px;font-weight:700;color:{TEXT_PRIMARY};
                      margin-bottom:6px;">{title}</div>
          {'<div style="font-size:13.5px;color:' + TEXT_SEC + ';">' + subtitle + '</div>' if subtitle else ''}
        </div>
        """,
        unsafe_allow_html=True,
    )


# ─── Section header ───────────────────────────────────────────────────────────

def section_header(title: str, subtitle: str = ""):
    st.markdown(
        f"""
        <div style="margin:24px 0 14px;">
          <div style="font-size:15px;font-weight:700;color:{TEXT_PRIMARY};
                      margin-bottom:2px;">{title}</div>
          {'<div style="font-size:12.5px;color:' + TEXT_SEC + ';">' + subtitle + '</div>' if subtitle else ''}
        </div>
        """,
        unsafe_allow_html=True,
    )


# ─── Info card ────────────────────────────────────────────────────────────────

def info_card(rows: list[tuple[str, str]], title: str = ""):
    rows_html = "".join(
        f'<tr>'
        f'<td style="padding:7px 0;color:{TEXT_SEC};font-size:12.5px;'
        f'font-weight:600;white-space:nowrap;width:140px;">{k}</td>'
        f'<td style="padding:7px 0;color:{TEXT_PRIMARY};font-size:13px;">{v}</td>'
        f'</tr>'
        for k, v in rows
    )
    title_html = (
        f'<div style="font-size:13px;font-weight:700;color:{TEXT_PRIMARY};'
        f'margin-bottom:12px;">{title}</div>'
        if title else ""
    )
    st.markdown(
        f'<div style="background:{CARD_BG};border:1px solid {BORDER};'
        f'border-radius:12px;padding:18px 20px;">'
        f'{title_html}'
        f'<table style="width:100%;border-collapse:collapse;">{rows_html}</table>'
        f'</div>',
        unsafe_allow_html=True,
    )


# ─── Inline alert banners ─────────────────────────────────────────────────────

def alert_success(text: str):
    st.markdown(
        f'<div style="background:#F0FFF4;border:1px solid #C6F6D5;border-left:4px solid {SUCCESS};'
        f'border-radius:10px;padding:11px 16px;font-size:13px;color:#276749;'
        f'font-weight:500;margin-bottom:12px;display:flex;align-items:center;gap:8px;">'
        f'<span>✓</span>{text}</div>',
        unsafe_allow_html=True,
    )


def alert_error(text: str):
    st.markdown(
        f'<div style="background:#FFF5F5;border:1px solid #FED7D7;border-left:4px solid {DANGER};'
        f'border-radius:10px;padding:11px 16px;font-size:13px;color:#742A2A;'
        f'font-weight:500;margin-bottom:12px;display:flex;align-items:center;gap:8px;">'
        f'<span>✕</span>{text}</div>',
        unsafe_allow_html=True,
    )


def alert_warning(text: str):
    st.markdown(
        f'<div style="background:#FFFBEB;border:1px solid #FEFCBF;border-left:4px solid {WARNING};'
        f'border-radius:10px;padding:11px 16px;font-size:13px;color:#744210;'
        f'font-weight:500;margin-bottom:12px;display:flex;align-items:center;gap:8px;">'
        f'<span>⚠</span>{text}</div>',
        unsafe_allow_html=True,
    )


def alert_info(text: str):
    st.markdown(
        f'<div style="background:#EBF8FF;border:1px solid #BEE3F8;border-left:4px solid {INFO};'
        f'border-radius:10px;padding:11px 16px;font-size:13px;color:#2C5282;'
        f'font-weight:500;margin-bottom:12px;display:flex;align-items:center;gap:8px;">'
        f'<span>ℹ</span>{text}</div>',
        unsafe_allow_html=True,
    )


# ─── Card wrapper ─────────────────────────────────────────────────────────────

def card(content_html: str, padding: str = "22px 26px"):
    st.markdown(
        f'<div style="background:{CARD_BG};border:1px solid {BORDER};'
        f'border-radius:14px;padding:{padding};'
        f'box-shadow:0 1px 4px rgba(0,0,0,.04);">'
        f'{content_html}</div>',
        unsafe_allow_html=True,
    )


# ─── Pagination controls ──────────────────────────────────────────────────────

def pagination(page_key: str, total: int, page_size: int) -> int:
    """Returns the current 0-based page index. Renders Prev/Next buttons."""
    total_pages = max(1, -(-total // page_size))
    if page_key not in st.session_state:
        st.session_state[page_key] = 0
    current = st.session_state[page_key]

    col_info, col_prev, col_next = st.columns([4, 1, 1])
    with col_info:
        start = current * page_size + 1
        end   = min((current + 1) * page_size, total)
        st.markdown(
            f'<div style="font-size:12.5px;color:{TEXT_SEC};padding-top:10px;">'
            f'Showing <b>{start}–{end}</b> of <b>{total}</b></div>',
            unsafe_allow_html=True,
        )
    with col_prev:
        if st.button("← Prev", key=f"{page_key}_prev", disabled=(current == 0)):
            st.session_state[page_key] -= 1
            st.rerun()
    with col_next:
        if st.button("Next →", key=f"{page_key}_next", disabled=(current >= total_pages - 1)):
            st.session_state[page_key] += 1
            st.rerun()
    return st.session_state[page_key]


# ─── Metric row shorthand ─────────────────────────────────────────────────────

def metric_row(items: list[tuple[str, Any, str | None]]):
    cols = st.columns(len(items))
    for col, (label, value, delta) in zip(cols, items):
        with col:
            if delta is not None:
                st.metric(label, value, delta)
            else:
                st.metric(label, value)


# ─── Formatters ───────────────────────────────────────────────────────────────

def fmt_currency(v) -> str:
    try:
        return f"Rs {float(v):,.0f}"
    except Exception:
        return "Rs 0"


def fmt_number(v) -> str:
    try:
        return f"{int(v):,}"
    except Exception:
        return "0"


def fmt_date(v) -> str:
    if v is None:
        return "—"
    try:
        from neo4j.time import DateTime as Neo4jDT
        if isinstance(v, Neo4jDT):
            v = v.to_native()
        return str(v)[:10]
    except Exception:
        return str(v)[:10] if v else "—"


def fmt_datetime(v) -> str:
    if v is None:
        return "—"
    try:
        from neo4j.time import DateTime as Neo4jDT
        if isinstance(v, Neo4jDT):
            v = v.to_native()
        s = str(v)
        return s[:16].replace("T", " ")
    except Exception:
        return str(v)[:16].replace("T", " ") if v else "—"


def fmt_bool(v, true_label="Yes", false_label="No") -> str:
    if v is True or v == "true" or v == 1:
        return f'<span style="color:{SUCCESS};font-weight:600;">{true_label}</span>'
    return f'<span style="color:{TEXT_MUTED};font-weight:600;">{false_label}</span>'
