"""
Reusable Plotly chart builders matching the Haulistry brand palette.
"""

import plotly.graph_objects as go
import plotly.express as px
import pandas as pd
from .styles import PRIMARY, SECONDARY, ACCENT, DANGER, WARNING, INFO

BRAND_COLORS = [PRIMARY, SECONDARY, ACCENT, WARNING, INFO, DANGER,
                "#A29BFE", "#FD79A8", "#55EFC4", "#FDCB6E"]

CHART_LAYOUT = dict(
    paper_bgcolor="rgba(0,0,0,0)",
    plot_bgcolor="rgba(0,0,0,0)",
    font=dict(family="sans-serif", size=12, color="#636E72"),
    margin=dict(l=10, r=10, t=30, b=10),
    legend=dict(
        orientation="h",
        yanchor="bottom",
        y=1.02,
        xanchor="right",
        x=1,
    ),
    xaxis=dict(showgrid=False, zeroline=False),
    yaxis=dict(gridcolor="#F0F0F0", zeroline=False),
)


def bookings_line_chart(data: list[dict]) -> go.Figure:
    if not data:
        return _empty_figure("No booking trend data")
    df = pd.DataFrame(data)
    if "date" not in df.columns or "bookings" not in df.columns:
        return _empty_figure("Unexpected data format")
    fig = go.Figure()
    fig.add_trace(
        go.Scatter(
            x=df["date"].astype(str),
            y=df["bookings"],
            mode="lines+markers",
            name="Bookings",
            line=dict(color=PRIMARY, width=3),
            marker=dict(size=6, color=PRIMARY),
            fill="tozeroy",
            fillcolor=f"rgba(255,107,53,0.08)",
        )
    )
    fig.update_layout(
        **CHART_LAYOUT,
        title="Booking Trend",
        xaxis_title="Date",
        yaxis_title="Bookings",
    )
    return fig


def revenue_line_chart(data: list[dict]) -> go.Figure:
    if not data:
        return _empty_figure("No revenue data")
    df = pd.DataFrame(data)
    fig = go.Figure()
    fig.add_trace(
        go.Scatter(
            x=df.get("date", pd.Series()).astype(str),
            y=df.get("revenue", pd.Series()),
            mode="lines+markers",
            name="Revenue",
            line=dict(color=SECONDARY, width=3),
            marker=dict(size=6, color=SECONDARY),
            fill="tozeroy",
            fillcolor="rgba(0,184,148,0.08)",
        )
    )
    fig.update_layout(
        **CHART_LAYOUT,
        title="Daily Revenue (Rs.)",
        xaxis_title="Date",
        yaxis_title="Revenue",
    )
    return fig


def status_donut(data: list[dict], title: str = "Booking Status") -> go.Figure:
    if not data:
        return _empty_figure("No status data")
    df = pd.DataFrame(data)
    fig = go.Figure(
        go.Pie(
            labels=df.get("status", df.iloc[:, 0]).str.replace("_", " ").str.title(),
            values=df.get("count", df.iloc[:, 1]),
            hole=0.55,
            marker=dict(colors=BRAND_COLORS, line=dict(color="#fff", width=2)),
            textinfo="percent",
            hoverinfo="label+value+percent",
        )
    )
    # Merge CHART_LAYOUT and override legend — avoids "multiple values" error
    layout = {
        **CHART_LAYOUT,
        "legend": dict(orientation="v", yanchor="middle", y=0.5, xanchor="right", x=1.2),
    }
    fig.update_layout(
        **layout,
        title=title,
        annotations=[
            dict(
                text=f"<b>{sum(df.get('count', [0]))}</b>",
                x=0.5, y=0.5,
                font_size=20,
                showarrow=False,
            )
        ],
    )
    return fig


def category_bar(data: list[dict], x_col: str, y_col: str, title: str) -> go.Figure:
    if not data:
        return _empty_figure(f"No {title} data")
    df = pd.DataFrame(data)
    if x_col not in df.columns or y_col not in df.columns:
        return _empty_figure("Unexpected data format")
    fig = go.Figure(
        go.Bar(
            x=df[x_col].str.replace("_", " ").str.title() if df[x_col].dtype == object else df[x_col],
            y=df[y_col],
            marker=dict(
                color=df[y_col],
                colorscale=[[0, f"rgba(255,107,53,.3)"], [1, PRIMARY]],
                showscale=False,
            ),
            text=df[y_col],
            textposition="auto",
        )
    )
    fig.update_layout(**CHART_LAYOUT, title=title, bargap=0.35)
    return fig


def revenue_by_category_bar(data: list[dict]) -> go.Figure:
    if not data:
        return _empty_figure("No revenue by category data")
    df = pd.DataFrame(data)
    fig = px.bar(
        df,
        x="category",
        y="revenue",
        color="bookings",
        color_continuous_scale=[[0, "rgba(0,184,148,.3)"], [1, SECONDARY]],
        title="Revenue by Service Category",
        labels={"category": "Category", "revenue": "Revenue (Rs.)", "bookings": "Bookings"},
        text_auto=True,
    )
    fig.update_layout(**CHART_LAYOUT)
    fig.update_traces(texttemplate="Rs. %{y:,.0f}", textposition="outside")
    return fig


def top_providers_bar(data: list[dict]) -> go.Figure:
    if not data:
        return _empty_figure("No provider data")
    df = pd.DataFrame(data)
    fig = go.Figure(
        go.Bar(
            y=df.get("name", df.iloc[:, 0]),
            x=df.get("completedJobs", df.iloc[:, 1]),
            orientation="h",
            marker=dict(color=ACCENT),
            text=df.get("completedJobs"),
            textposition="auto",
        )
    )
    # Merge yaxis override to avoid "multiple values" conflict with CHART_LAYOUT
    layout = {
        **CHART_LAYOUT,
        "yaxis": dict(gridcolor="#F0F0F0", zeroline=False, autorange="reversed"),
    }
    fig.update_layout(
        **layout,
        title="Top Providers by Completed Jobs",
        xaxis_title="Jobs Completed",
    )
    return fig


def _empty_figure(msg: str = "No data available") -> go.Figure:
    fig = go.Figure()
    fig.add_annotation(
        text=msg,
        xref="paper", yref="paper",
        x=0.5, y=0.5,
        showarrow=False,
        font=dict(size=14, color="#B2BEC3"),
    )
    fig.update_layout(**CHART_LAYOUT, height=200)
    return fig
