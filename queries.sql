-- ============================================================
-- Time-Series Business Insights Project — 23 Queries
-- ============================================================
-- Table: activity_readings(ds, y, unique_id)
-- Written & validated on SQLite; see schema.sql for the 4 small
-- dialect adjustments needed to run these on MySQL 8.0+.
-- Techniques used throughout: CTEs, window functions (LAG, LEAD,
-- RANK, NTILE, PERCENT_RANK, SUM/AVG OVER, ROWS BETWEEN),
-- subqueries, and joins (including self-joins).
-- ============================================================


-- ============================================================
-- SECTION 1: DATA OVERVIEW
-- ============================================================

-- Q1. Row count, series count, and date coverage
SELECT COUNT(*) AS total_rows, COUNT(DISTINCT unique_id) AS total_series,
       MIN(ds) AS earliest, MAX(ds) AS latest
FROM activity_readings;

-- Q2. Total and average activity across the whole dataset
SELECT SUM(y) AS total_activity, AVG(y) AS avg_per_hour, MAX(y) AS peak_hour_value
FROM activity_readings;


-- ============================================================
-- SECTION 2: TREND & GROWTH ANALYSIS
-- (equivalent to "monthly revenue growth" for this dataset)
-- ============================================================

-- Q3. Monthly total activity per series with month-over-month growth %
-- (CTE + window function LAG)
WITH monthly AS (
  SELECT unique_id, strftime('%Y-%m', ds) AS month, SUM(y) AS monthly_total
  FROM activity_readings
  GROUP BY unique_id, month
),
growth AS (
  SELECT unique_id, month, monthly_total,
         LAG(monthly_total) OVER (PARTITION BY unique_id ORDER BY month) AS prev_month_total
  FROM monthly
)
SELECT unique_id, month, monthly_total, prev_month_total,
       ROUND(100.0*(monthly_total-prev_month_total)/NULLIF(prev_month_total,0),2) AS mom_growth_pct
FROM growth
ORDER BY unique_id, month;

-- Q4. Weekly total activity overall, with a running cumulative total
-- (window function SUM OVER)
WITH weekly AS (
  SELECT strftime('%Y-%W', ds) AS week, MIN(date(ds)) AS week_start, SUM(y) AS weekly_total
  FROM activity_readings
  GROUP BY week
)
SELECT week, week_start, weekly_total,
       SUM(weekly_total) OVER (ORDER BY week) AS running_total
FROM weekly
ORDER BY week;

-- Q5. Peak month overall by total activity
SELECT strftime('%Y-%m', ds) AS month, SUM(y) AS total_activity
FROM activity_readings
GROUP BY month
ORDER BY total_activity DESC
LIMIT 5;

-- Q6. Fastest-growing series: first 90 days vs. last 90 days average
-- (two CTEs joined together — growth-leaderboard equivalent)
WITH bounds AS (
  SELECT unique_id, MIN(ds) AS min_ds, MAX(ds) AS max_ds FROM activity_readings GROUP BY unique_id
),
early AS (
  SELECT a.unique_id, AVG(a.y) AS early_avg
  FROM activity_readings a JOIN bounds b ON a.unique_id = b.unique_id
  WHERE a.ds < datetime(b.min_ds, '+90 days')
  GROUP BY a.unique_id
),
late AS (
  SELECT a.unique_id, AVG(a.y) AS late_avg
  FROM activity_readings a JOIN bounds b ON a.unique_id = b.unique_id
  WHERE a.ds > datetime(b.max_ds, '-90 days')
  GROUP BY a.unique_id
)
SELECT e.unique_id, e.early_avg, l.late_avg,
       ROUND(100.0*(l.late_avg-e.early_avg)/NULLIF(e.early_avg,0),2) AS growth_pct
FROM early e JOIN late l ON e.unique_id = l.unique_id
ORDER BY growth_pct DESC;

-- Q7. Year-over-year comparison by month, 2020 vs 2021 (self-join on a CTE)
WITH monthly AS (
  SELECT unique_id, strftime('%Y', ds) AS yr, strftime('%m', ds) AS mo, SUM(y) AS total
  FROM activity_readings
  GROUP BY unique_id, yr, mo
)
SELECT m20.unique_id, m20.mo AS month, m20.total AS total_2020, m21.total AS total_2021,
       ROUND(100.0*(m21.total-m20.total)/NULLIF(m20.total,0),2) AS yoy_growth_pct
FROM monthly m20
JOIN monthly m21 ON m20.unique_id = m21.unique_id AND m20.mo = m21.mo
WHERE m20.yr = '2020' AND m21.yr = '2021'
ORDER BY m20.unique_id, month;

-- Q8. Hour-over-hour change per series (window function LEAD)
SELECT unique_id, ds, y,
       LEAD(y) OVER (PARTITION BY unique_id ORDER BY ds) AS next_hour_y,
       LEAD(y) OVER (PARTITION BY unique_id ORDER BY ds) - y AS hour_over_hour_change
FROM activity_readings
ORDER BY unique_id, ds;

-- Q9. 7-day rolling average per series (window function, ROWS BETWEEN)
WITH daily AS (
  SELECT unique_id, date(ds) AS day, SUM(y) AS daily_total
  FROM activity_readings
  GROUP BY unique_id, day
)
SELECT unique_id, day, daily_total,
       AVG(daily_total) OVER (
         PARTITION BY unique_id ORDER BY day
         ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
       ) AS rolling_7d_avg
FROM daily
ORDER BY unique_id, day;

-- Q10. Cumulative running total per series over time (window function)
WITH daily AS (
  SELECT unique_id, date(ds) AS day, SUM(y) AS daily_total
  FROM activity_readings
  GROUP BY unique_id, day
)
SELECT unique_id, day, daily_total,
       SUM(daily_total) OVER (PARTITION BY unique_id ORDER BY day) AS cumulative_total
FROM daily
ORDER BY unique_id, day;


-- ============================================================
-- SECTION 3: SERIES PERFORMANCE & RANKING
-- (equivalent to "regional performance" for this dataset)
-- ============================================================

-- Q11. Top 20 series by total activity
SELECT unique_id, SUM(y) AS total_activity, AVG(y) AS avg_hourly, COUNT(*) AS n_hours
FROM activity_readings
GROUP BY unique_id
ORDER BY total_activity DESC
LIMIT 20;

-- Q12. Rank every series by total activity (window function RANK)
WITH series_totals AS (
  SELECT unique_id, SUM(y) AS total_activity
  FROM activity_readings
  GROUP BY unique_id
)
SELECT unique_id, total_activity,
       RANK() OVER (ORDER BY total_activity DESC) AS activity_rank
FROM series_totals
ORDER BY activity_rank;

-- Q13. Split series into performance quartiles (window function NTILE)
WITH series_totals AS (
  SELECT unique_id, SUM(y) AS total_activity
  FROM activity_readings
  GROUP BY unique_id
)
SELECT unique_id, total_activity,
       NTILE(4) OVER (ORDER BY total_activity DESC) AS performance_quartile
FROM series_totals
ORDER BY total_activity DESC;

-- Q14. Peak single-hour value and timestamp for the top 5 series
-- (CTE + subquery + join back to find the exact timestamp)
WITH top5 AS (
  SELECT unique_id FROM activity_readings GROUP BY unique_id ORDER BY SUM(y) DESC LIMIT 5
),
peak AS (
  SELECT unique_id, MAX(y) AS peak_value
  FROM activity_readings
  WHERE unique_id IN (SELECT unique_id FROM top5)
  GROUP BY unique_id
)
SELECT a.unique_id, a.ds AS peak_timestamp, a.y AS peak_value
FROM activity_readings a
JOIN peak p ON a.unique_id = p.unique_id AND a.y = p.peak_value
ORDER BY a.y DESC;

-- Q15. Percentile rank of each reading within its own series (window function)
SELECT unique_id, ds, y,
       ROUND(PERCENT_RANK() OVER (PARTITION BY unique_id ORDER BY y), 3) AS percentile_rank
FROM activity_readings
ORDER BY unique_id, y DESC;

-- Q16. Most volatile series by coefficient of variation (std dev / mean)
WITH stats AS (
  SELECT unique_id, SUM(y) AS total_activity, AVG(y) AS mean_y,
         SQRT(AVG(y*y) - AVG(y)*AVG(y)) AS std_y
  FROM activity_readings
  GROUP BY unique_id
)
SELECT unique_id, total_activity, ROUND(mean_y,2) AS mean_y, ROUND(std_y,2) AS std_y,
       ROUND(std_y/NULLIF(mean_y,0), 3) AS coeff_of_variation
FROM stats
WHERE mean_y > 5
ORDER BY coeff_of_variation DESC;

-- Q17. First and last active (y > 0) timestamp per series
SELECT unique_id, MIN(ds) AS first_active, MAX(ds) AS last_active
FROM activity_readings
WHERE y > 0
GROUP BY unique_id
ORDER BY unique_id;


-- ============================================================
-- SECTION 4: ACTIVITY / "REPEAT ENGAGEMENT" ANALYSIS
-- (equivalent to "repeat purchase rate" for this dataset)
-- ============================================================

-- Q18. Active-hour rate per series (% of hours with a nonzero reading)
SELECT unique_id,
       COUNT(*) AS total_hours,
       SUM(CASE WHEN y > 0 THEN 1 ELSE 0 END) AS active_hours,
       ROUND(100.0*SUM(CASE WHEN y > 0 THEN 1 ELSE 0 END)/COUNT(*), 2) AS active_rate_pct
FROM activity_readings
GROUP BY unique_id
ORDER BY active_rate_pct DESC;

-- Q19. Series with at least one full zero-activity day (subquery + HAVING)
SELECT COUNT(DISTINCT unique_id) AS series_with_zero_day
FROM (
  SELECT unique_id, date(ds) AS day, SUM(y) AS daily_total
  FROM activity_readings
  GROUP BY unique_id, day
  HAVING daily_total = 0
) AS zero_days;


-- ============================================================
-- SECTION 5: ANOMALY DETECTION
-- ============================================================

-- Q20. Hours where a reading is more than 5 standard deviations from
-- its series' mean (CTE for stats + join + filter)
WITH stats AS (
  SELECT unique_id, AVG(y) AS mean_y, SQRT(AVG(y*y) - AVG(y)*AVG(y)) AS std_y
  FROM activity_readings
  GROUP BY unique_id
)
SELECT a.unique_id, a.ds, a.y, ROUND(s.mean_y,2) AS mean_y, ROUND(s.std_y,2) AS std_y,
       ROUND((a.y - s.mean_y) / NULLIF(s.std_y,0), 2) AS z_score
FROM activity_readings a
JOIN stats s ON a.unique_id = s.unique_id
WHERE ABS((a.y - s.mean_y) / NULLIF(s.std_y,0)) > 5
ORDER BY z_score DESC;

-- Q21. How many distinct series spiked simultaneously at the single
-- biggest anomaly timestamp (2020-03-02 21:00) — tests whether a
-- spike is series-specific or a systemic, dataset-wide event
WITH stats AS (
  SELECT unique_id, AVG(y) AS mean_y, SQRT(AVG(y*y) - AVG(y)*AVG(y)) AS std_y
  FROM activity_readings
  GROUP BY unique_id
)
SELECT COUNT(*) AS series_spiking
FROM activity_readings a
JOIN stats s ON a.unique_id = s.unique_id
WHERE a.ds = '2020-03-02 21:00:00'
  AND (a.y - s.mean_y) / NULLIF(s.std_y,0) > 3;


-- ============================================================
-- SECTION 6: SEASONALITY
-- ============================================================

-- Q22. Average activity by hour of day (0-23) across all series
SELECT CAST(strftime('%H', ds) AS INTEGER) AS hour_of_day, AVG(y) AS avg_activity
FROM activity_readings
GROUP BY hour_of_day
ORDER BY hour_of_day;
-- MySQL: replace CAST(strftime('%H', ds) AS INTEGER) with HOUR(ds)

-- Q23. Average activity by day of week across all series
SELECT CASE CAST(strftime('%w', ds) AS INTEGER)
         WHEN 0 THEN 'Sunday' WHEN 1 THEN 'Monday' WHEN 2 THEN 'Tuesday'
         WHEN 3 THEN 'Wednesday' WHEN 4 THEN 'Thursday'
         WHEN 5 THEN 'Friday' WHEN 6 THEN 'Saturday' END AS day_name,
       CAST(strftime('%w', ds) AS INTEGER) AS dow_num,
       AVG(y) AS avg_activity
FROM activity_readings
GROUP BY dow_num
ORDER BY dow_num;
-- MySQL: replace strftime('%w', ds) with (DAYOFWEEK(ds) - 1)
