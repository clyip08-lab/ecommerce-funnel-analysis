-- ============================================================
-- 07_powerbi_output_tables.sql
-- E-commerce Funnel Analysis
--
-- Purpose:
-- Finalise and validate the semantic tables used by Power BI.
--
-- Power BI does NOT consume one giant raw-event table for this
-- dashboard. SQL prepares purpose-built analytical tables at
-- the correct grain for each business question.
--
-- Final Power BI tables:
--
-- 1. pbi_monthly_funnel_30
-- 2. pbi_category_peer_30
-- 3. pbi_category_opportunity_30
-- 4. pbi_price_driver_30
-- 5. pbi_brand_driver_30
-- 6. pbi_data_quality_30
--
-- Tables 1–5 are created in the preceding analysis scripts.
-- This script builds the data-quality output and validates the
-- complete Power BI semantic layer.
-- ============================================================


-- ============================================================
-- PART A — DATA QUALITY OUTPUT
-- ============================================================


-- ------------------------------------------------------------
-- 1. Category ID mapping status
-- ------------------------------------------------------------

CREATE OR REPLACE TABLE category_mapping_status AS

SELECT
    CAST(category_id AS VARCHAR) AS category_id,

    MAX(
        CASE
            WHEN category_code IS NOT NULL
             AND TRIM(category_code) <> ''
            THEN 1
            ELSE 0
        END
    ) AS has_known_category_code

FROM raw_events

WHERE category_id IS NOT NULL

GROUP BY
    CAST(category_id AS VARCHAR);


-- ------------------------------------------------------------
-- 2. Build reusable data-quality statistics
-- ------------------------------------------------------------

CREATE OR REPLACE TABLE pbi_data_quality_30 AS

WITH statistics AS (

    SELECT

        -- Raw / analytical volume
        (SELECT COUNT(*)
         FROM raw_events)
            AS raw_event_rows,

        (SELECT COUNT(*)
         FROM analysis_events_30)
            AS analysis_event_rows,

        (SELECT COUNT(DISTINCT analytical_session_id)
         FROM analysis_events_30)
            AS sessions_30,

        (SELECT COUNT(DISTINCT analytical_session_id)
         FROM analysis_events_60)
            AS sessions_60,

        -- Category mapping
        (SELECT COUNT(*)
         FROM category_mapping_status)
            AS total_category_ids,

        (SELECT COUNT(*)
         FROM category_mapping_status
         WHERE has_known_category_code = 1)
            AS known_category_ids,

        (SELECT COUNT(*)
         FROM category_mapping_status
         WHERE has_known_category_code = 0)
            AS unmapped_category_ids,

        (SELECT COUNT(
             DISTINCT NULLIF(TRIM(category_code), '')
         )
         FROM raw_events)
            AS known_business_category_codes,

        (SELECT COUNT(*)
         FROM analysis_events_30
         WHERE category_code IS NULL
            OR TRIM(category_code) = '')
            AS unmapped_category_event_rows,

        -- Brand completeness
        (
            SELECT
                100.0
                * COUNT(*) FILTER (
                    WHERE brand IS NULL
                       OR TRIM(brand) = ''
                  )
                / NULLIF(COUNT(*), 0)

            FROM analysis_events_30

            WHERE category_code =
                'electronics.video.tv'
        ) AS tv_missing_brand_pct,

        (
            SELECT
                100.0
                * COUNT(*) FILTER (
                    WHERE brand IS NULL
                       OR TRIM(brand) = ''
                  )
                / NULLIF(COUNT(*), 0)

            FROM analysis_events_30

            WHERE category_code =
                'computers.peripherals.monitor'
        ) AS monitor_missing_brand_pct,

        (
            SELECT
                100.0
                * COUNT(*) FILTER (
                    WHERE brand IS NULL
                       OR TRIM(brand) = ''
                  )
                / NULLIF(COUNT(*), 0)

            FROM analysis_events_30

            WHERE category_code =
                'computers.components.cooler'
        ) AS cooler_missing_brand_pct,

        (
            SELECT
                100.0
                * COUNT(*) FILTER (
                    WHERE brand IS NULL
                       OR TRIM(brand) = ''
                  )
                / NULLIF(COUNT(*), 0)

            FROM analysis_events_30

            WHERE category_code =
                'auto.accessories.videoregister'
        ) AS videoregister_missing_brand_pct
)

SELECT
    1 AS sort_order,
    'Volume' AS metric_group,
    'Raw event rows' AS metric_name,
    CAST(raw_event_rows AS DOUBLE) AS metric_value,
    'rows' AS metric_unit
FROM statistics

UNION ALL

SELECT
    2,
    'Volume',
    'Analysis event rows',
    CAST(analysis_event_rows AS DOUBLE),
    'rows'
FROM statistics

UNION ALL

SELECT
    3,
    'Session validation',
    '30-minute analysis sessions',
    CAST(sessions_30 AS DOUBLE),
    'sessions'
FROM statistics

UNION ALL

SELECT
    4,
    'Session validation',
    '60-minute sensitivity sessions',
    CAST(sessions_60 AS DOUBLE),
    'sessions'
FROM statistics

UNION ALL

SELECT
    5,
    'Session validation',
    'Session sensitivity difference',
    100.0
        * ABS(sessions_30 - sessions_60)
        / NULLIF(sessions_30, 0),
    '%'
FROM statistics

UNION ALL

SELECT
    6,
    'Category mapping',
    'Total category IDs',
    CAST(total_category_ids AS DOUBLE),
    'IDs'
FROM statistics

UNION ALL

SELECT
    7,
    'Category mapping',
    'Known category IDs',
    CAST(known_category_ids AS DOUBLE),
    'IDs'
FROM statistics

UNION ALL

SELECT
    8,
    'Category mapping',
    'Unmapped category IDs',
    CAST(unmapped_category_ids AS DOUBLE),
    'IDs'
FROM statistics

UNION ALL

SELECT
    9,
    'Category mapping',
    'Known business category codes',
    CAST(known_business_category_codes AS DOUBLE),
    'categories'
FROM statistics

UNION ALL

SELECT
    10,
    'Category mapping',
    'Unmapped category event rows',
    CAST(unmapped_category_event_rows AS DOUBLE),
    'rows'
FROM statistics

UNION ALL

SELECT
    11,
    'Brand coverage',
    'TV missing-brand rate',
    tv_missing_brand_pct,
    '%'
FROM statistics

UNION ALL

SELECT
    12,
    'Brand coverage',
    'Monitor missing-brand rate',
    monitor_missing_brand_pct,
    '%'
FROM statistics

UNION ALL

SELECT
    13,
    'Brand coverage',
    'Cooler missing-brand rate',
    cooler_missing_brand_pct,
    '%'
FROM statistics

UNION ALL

SELECT
    14,
    'Brand coverage',
    'Videoregister missing-brand rate',
    videoregister_missing_brand_pct,
    '%'
FROM statistics

UNION ALL

-- Practical sample thresholds.
-- These are analytical rules chosen earlier in the project,
-- not statistical-significance cut-offs.

SELECT
    15,
    'Sample threshold',
    'Category View-to-Cart threshold',
    2643,
    'viewing sessions'

UNION ALL

SELECT
    16,
    'Sample threshold',
    'Category Cart-to-Purchase threshold',
    196,
    'cart sessions'

UNION ALL

SELECT
    17,
    'Sample threshold',
    'Brand View-to-Cart threshold',
    150,
    'viewing sessions'

UNION ALL

SELECT
    18,
    'Sample threshold',
    'Brand Cart-to-Purchase threshold',
    30,
    'cart sessions';


-- ------------------------------------------------------------
-- 3. Review data-quality output
-- ------------------------------------------------------------

SELECT
    metric_group,
    metric_name,
    ROUND(metric_value, 2) AS metric_value,
    metric_unit

FROM pbi_data_quality_30

ORDER BY sort_order;


/*
Expected key results:

Raw event rows                    885,129
Analysis event rows               884,964

30-minute sessions                539,812
60-minute sessions                531,421
Sensitivity difference              ~1.55%

Total category IDs                    718
Known category IDs                    281
Unmapped category IDs                 437
Known business category codes         107
Unmapped category event rows      236,172

TV missing brand                     2.42%
Monitor missing brand                4.70%
Cooler missing brand                22.34%
Videoregister missing brand         35.43%
*/


-- ============================================================
-- PART B — POWER BI OUTPUT VALIDATION
-- ============================================================


-- ------------------------------------------------------------
-- 4. Confirm that all six semantic tables are available
-- ------------------------------------------------------------

SELECT
    'pbi_monthly_funnel_30'
        AS table_name,
    COUNT(*) AS row_count
FROM pbi_monthly_funnel_30

UNION ALL

SELECT
    'pbi_category_peer_30',
    COUNT(*)
FROM pbi_category_peer_30

UNION ALL

SELECT
    'pbi_category_opportunity_30',
    COUNT(*)
FROM pbi_category_opportunity_30

UNION ALL

SELECT
    'pbi_price_driver_30',
    COUNT(*)
FROM pbi_price_driver_30

UNION ALL

SELECT
    'pbi_brand_driver_30',
    COUNT(*)
FROM pbi_brand_driver_30

UNION ALL

SELECT
    'pbi_data_quality_30',
    COUNT(*)
FROM pbi_data_quality_30;


/*
Known validation:

pbi_monthly_funnel_30       6 monthly rows
pbi_category_peer_30      107 category rows
pbi_data_quality_30        18 metric rows

Other table sizes depend on funnel-stage / driver combinations.
*/


-- ------------------------------------------------------------
-- 5. Check uniqueness at expected analytical grains
-- ------------------------------------------------------------


-- Monthly table:
-- one row per month
SELECT
    COUNT(*) AS rows,
    COUNT(DISTINCT month_start)
        AS unique_months

FROM pbi_monthly_funnel_30;


-- Category peer table:
-- one row per category
SELECT
    COUNT(*) AS rows,
    COUNT(DISTINCT category_code)
        AS unique_categories

FROM pbi_category_peer_30;


-- Category opportunity table:
-- one row per category + funnel stage
SELECT
    COUNT(*) AS rows,

    COUNT(
        DISTINCT CONCAT(
            category_code,
            '|',
            funnel_stage
        )
    ) AS unique_category_stage_rows

FROM pbi_category_opportunity_30;


-- Price-driver table:
-- one row per category + funnel stage + price band
SELECT
    COUNT(*) AS rows,

    COUNT(
        DISTINCT CONCAT(
            category_code,
            '|',
            funnel_stage,
            '|',
            price_band
        )
    ) AS unique_driver_rows

FROM pbi_price_driver_30;


-- Brand-driver table:
-- one row per category + funnel stage + brand
SELECT
    COUNT(*) AS rows,

    COUNT(
        DISTINCT CONCAT(
            category_code,
            '|',
            funnel_stage,
            '|',
            brand_group
        )
    ) AS unique_driver_rows

FROM pbi_brand_driver_30;


-- Data-quality table:
-- one row per defined metric
SELECT
    COUNT(*) AS rows,
    COUNT(DISTINCT metric_name)
        AS unique_metrics

FROM pbi_data_quality_30;
