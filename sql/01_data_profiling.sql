-- ============================================================
-- 01_data_profiling.sql
-- E-commerce Funnel Analysis
--
-- Purpose:
-- Profile the raw ecommerce event data before building
-- session-level funnel metrics.
--
-- Raw grain:
-- One row represents one observed user-product event.
-- ============================================================


-- ------------------------------------------------------------
-- 1. Dataset size
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS total_event_rows
FROM raw_events;


-- ------------------------------------------------------------
-- 2. Event type distribution
-- ------------------------------------------------------------

SELECT
    event_type,
    COUNT(*) AS event_rows
FROM raw_events
GROUP BY event_type
ORDER BY event_rows DESC;


-- ------------------------------------------------------------
-- 3. Date coverage
-- ------------------------------------------------------------

SELECT
    MIN(event_time) AS first_event_time,
    MAX(event_time) AS last_event_time
FROM raw_events;


-- ------------------------------------------------------------
-- 4. Missing-value profile
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS total_rows,

    SUM(CASE WHEN user_id IS NULL THEN 1 ELSE 0 END)
        AS missing_user_id_rows,

    SUM(CASE WHEN user_session IS NULL THEN 1 ELSE 0 END)
        AS missing_user_session_rows,

    SUM(CASE WHEN category_id IS NULL THEN 1 ELSE 0 END)
        AS missing_category_id_rows,

    SUM(CASE
        WHEN category_code IS NULL
          OR TRIM(category_code) = ''
        THEN 1 ELSE 0
    END) AS missing_category_code_rows,

    SUM(CASE
        WHEN brand IS NULL
          OR TRIM(brand) = ''
        THEN 1 ELSE 0
    END) AS missing_brand_rows,

    SUM(CASE WHEN price IS NULL THEN 1 ELSE 0 END)
        AS missing_price_rows

FROM raw_events;


-- ------------------------------------------------------------
-- 5. Category mapping coverage
-- ------------------------------------------------------------

SELECT
    COUNT(DISTINCT category_id) AS total_category_ids,

    COUNT(DISTINCT CASE
        WHEN category_code IS NOT NULL
         AND TRIM(category_code) <> ''
        THEN category_id
    END) AS category_ids_with_known_code

FROM raw_events;


-- ------------------------------------------------------------
-- 6. Check whether one category ID maps to multiple codes
-- ------------------------------------------------------------

SELECT
    category_id,
    COUNT(DISTINCT category_code) AS distinct_category_codes
FROM raw_events
WHERE category_code IS NOT NULL
  AND TRIM(category_code) <> ''
GROUP BY category_id
HAVING COUNT(DISTINCT category_code) > 1
ORDER BY distinct_category_codes DESC;


-- ------------------------------------------------------------
-- 7. Price distribution
-- ------------------------------------------------------------

SELECT
    MIN(price) AS min_price,
    QUANTILE_CONT(price, 0.25) AS p25_price,
    MEDIAN(price) AS median_price,
    QUANTILE_CONT(price, 0.75) AS p75_price,
    QUANTILE_CONT(price, 0.90) AS p90_price,
    QUANTILE_CONT(price, 0.99) AS p99_price,
    MAX(price) AS max_price
FROM raw_events
WHERE price > 0;
