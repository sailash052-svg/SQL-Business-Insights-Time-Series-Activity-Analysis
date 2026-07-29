# SQL Business Insights: Time-Series Activity Analysis

A SQL analytics portfolio project: **23 advanced SQL queries** (CTEs, window functions, subqueries, and joins) applied to 3.05 million hourly activity readings across 235 series (Amazon product / Google location review-activity streams), Jan 2020 – Jun 2021.

**[▶ View the interactive dashboard](./index.html)** &nbsp;|&nbsp; **[📄 Read the full report](./SQL_Insights_Report.docx)** &nbsp;|&nbsp; **[🗄️ Browse the queries](./queries.sql)**

> Tip: host `index.html` on **GitHub Pages** (Settings → Pages → deploy from this repo) to get a clickable live link.

---

## What's in this project

| File | Description |
|---|---|
| `schema.sql` | Table definition (MySQL + SQLite), load statement, and dialect notes |
| `queries.sql` | All 23 queries, organized into 6 categories, fully commented |
| `query_results/` | Small CSV exports of each query's output — lets you review results without needing the full 115MB dataset |
| `SQL_Insights_Report.docx` | Full written report — 6 charts, methodology, and business recommendations |
| `index.html` | Self-contained interactive dashboard (Chart.js), built from the query result exports |
| `charts/` | Individual PNG charts used in the report |

**Note on the raw data:** the source dataset (3.05M rows, ~115MB CSV / ~310MB as a SQLite file) is **not included** in this repo — it exceeds GitHub's file size limits. `query_results/` contains the aggregated output of every query so the findings are fully reviewable without it. To reproduce from scratch, load your own copy of the source CSV using `schema.sql`, then run `queries.sql`.

## What the 23 queries cover

| Category | Retail KPI equivalent | Techniques used |
|---|---|---|
| Data overview (Q1-2) | — | Aggregates |
| Trend & growth (Q3-10) | Monthly revenue growth | CTEs, `LAG`/`LEAD`, `SUM() OVER`, `ROWS BETWEEN`, self-joins |
| Series performance & ranking (Q11-17) | Customer lifetime value | `RANK()`, `NTILE()`, `PERCENT_RANK()`, subqueries |
| Engagement rate (Q18-19) | Repeat purchase rate | `CASE`, `HAVING`, subqueries |
| Anomaly detection (Q20-21) | — | CTEs + joins, manual z-score calculation |
| Seasonality (Q22-23) | Regional performance (segment comparison) | Date-part aggregation |

## Key findings

- Activity is heavily concentrated: **series 187 alone accounts for 31.1M of 571.8M total activity** — over 4x the next-largest series.
- A massive, simultaneous spike hit **176 of 235 series (75%)** at exactly **2020-03-02 21:00** — a systemic event, not an isolated one.
- **2,037 anomalous readings** (z-score > 5) were found across 194 of 235 series, clustering heavily in Feb-Mar 2020 and on weekends.
- Activity follows a strong daily rhythm — **~8x higher in the evening (19:00-23:00)** than mid-morning (8-10 AM).
- Growth is highly uneven: the fastest-growing series gained **139%** (first 90 days vs. last 90 days), while the fastest-declining series fell **87.5%** over the same comparison.

See the full report for methodology, all six charts, and recommendations.

## Tools used

`SQLite` (validation engine, since no MySQL server was available) · `SQL` — CTEs, window functions, subqueries, joins, written to be MySQL 8.0+ compatible (see `schema.sql` for the 4 small dialect notes) · `Python (pandas, matplotlib)` for exports and charts · `Chart.js` for the interactive dashboard.

## Data source

Hourly activity time series (Amazon product / Google location review-activity streams), 235 series, Jan 2020 – Jun 2021.

## About this project

Built as a self-guided data analyst portfolio project to demonstrate advanced SQL technique (CTEs, window functions, subqueries, joins) applied to a large (3M+ row) real-world time-series dataset — reframing standard retail KPIs (revenue growth, CLV, repeat purchase rate, regional performance) onto a non-retail data structure.
