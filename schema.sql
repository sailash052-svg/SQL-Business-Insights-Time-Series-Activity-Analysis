-- ============================================================
-- Time-Series Business Insights Project — Schema
-- ============================================================
-- Source: hourly activity readings across 235 distinct series
-- (product/location review-activity streams), Jan 2020 - Jun 2021.
--
-- Table: activity_readings
--   ds          DATETIME  — hourly timestamp
--   y           DECIMAL   — activity reading for that hour
--   unique_id   INT       — series identifier (product/location)
-- ============================================================

-- MySQL version
CREATE TABLE activity_readings (
    ds          DATETIME NOT NULL,
    y           DECIMAL(10,2) NOT NULL,
    unique_id   INT NOT NULL,
    INDEX idx_series (unique_id),
    INDEX idx_ts (ds),
    INDEX idx_series_ts (unique_id, ds)
);

-- Load data (MySQL) — adjust path/permissions as needed:
-- LOAD DATA INFILE '/path/to/y_amazon-google-large.csv'
-- INTO TABLE activity_readings
-- FIELDS TERMINATED BY ',' ENCLOSED BY '"'
-- LINES TERMINATED BY '\n'
-- IGNORE 1 ROWS
-- (@row_num, ds, y, unique_id);
-- Note: the source CSV has a leading unused index column (@row_num) — ignored above.

-- SQLite equivalent (used to build/validate this project):
-- CREATE TABLE activity_readings (ds TEXT, y REAL, unique_id INTEGER);
-- CREATE INDEX idx_series ON activity_readings(unique_id);
-- CREATE INDEX idx_ts ON activity_readings(ds);
-- CREATE INDEX idx_series_ts ON activity_readings(unique_id, ds);
-- (loaded via pandas.to_sql from the source CSV)

-- ============================================================
-- NOTE ON PORTABILITY
-- ============================================================
-- All queries in queries.sql were written and validated against
-- SQLite (no local MySQL server was available in the build
-- environment) but use only standard SQL + window functions
-- supported identically by MySQL 8.0+. The only dialect
-- differences to adjust when running on MySQL:
--
--   1. Date part extraction:
--        SQLite:  strftime('%Y-%m', ds)
--        MySQL:   DATE_FORMAT(ds, '%Y-%m')
--
--   2. Day-of-week number:
--        SQLite:  strftime('%w', ds)   -- 0=Sunday
--        MySQL:   DAYOFWEEK(ds) - 1    -- to match 0=Sunday
--
--   3. Date arithmetic:
--        SQLite:  datetime(min_ds, '+90 days')
--        MySQL:   DATE_ADD(min_ds, INTERVAL 90 DAY)
--
--   4. Standard deviation:
--        SQLite has no built-in STDDEV, so it's computed manually:
--          SQRT(AVG(y*y) - AVG(y)*AVG(y))
--        MySQL has native STDDEV()/STDDEV_POP() — either works;
--        the manual formula also runs unchanged on MySQL.
--
-- Everything else (CTEs, RANK, NTILE, LAG, LEAD, PERCENT_RANK,
-- window frames with ROWS BETWEEN) is standard SQL:2003 syntax
-- and runs unchanged on both engines.
