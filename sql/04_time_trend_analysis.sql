-- ============================================================
-- 04_time_trend_analysis.sql
-- E-commerce Funnel Analysis
--
-- Purpose:
-- Analyse monthly funnel performance to identify which funnel
-- stage was driving changes in overall purchase performance.
--
-- Important:
-- September 2020 is a partial month because the dataset begins
-- on 2020-09-24, so it is retained for transparency but excluded
-- from direct full-month trend comparisons.
-- ============================================================


-- ------------------------------------------------------------
-- 1. Build monthly session-level funnel metrics
-- ------------------------------------------------------------

CREATE OR REPLACE TABLE monthly_funnel_30 AS

SELECT
    CAST(
        DATE_TRUNC('month', session_start_time)
        AS DATE
    ) AS month_start,

    COUNT(*) AS total_sessions,

    SUM(has_view) AS viewing_sessions,
    SUM(has_cart) AS cart_sessions,
    SUM(has_purchase) AS purchasing_sessions,

    SUM(ordered_view_to_cart)
        AS ordered_view_to_cart_sessions,

    SUM(ordered_cart_to_purchase)
        AS ordered_cart_to_purchase_sessions,

    SUM(complete_ordered_funnel)
        AS complete_ordered_funnel_sessions,

    -- Overall session purchase performance
    100.0 * SUM(has_purchase)
        / NULLIF(COUNT(*), 0)
        AS purchase_session_rate_pct,

    -- Front-funnel progression
    100.0 * SUM(ordered_view_to_cart)
        / NULLIF(SUM(has_view), 0)
        AS ordered_view_to_cart_rate_pct,

    -- Downstream progression
    100.0 * SUM(ordered_cart_to_purchase)
        / NULLIF(SUM(has_cart), 0)
        AS ordered_cart_to_purchase_rate_pct,

    -- Complete ordered funnel
    100.0 * SUM(complete_ordered_funnel)
        / NULLIF(SUM(has_view), 0)
        AS complete_ordered_funnel_rate_pct,

    CASE
        WHEN DATE_TRUNC('month', session_start_time)
             = DATE '2020-09-01'
        THEN TRUE
        ELSE FALSE
    END AS is_partial_month

FROM session_funnel_30

GROUP BY
    DATE_TRUNC('month', session_start_time)

ORDER BY month_start;


-- ------------------------------------------------------------
-- 2. Review monthly results
-- ------------------------------------------------------------

SELECT
    month_start,
    total_sessions,

    ROUND(
        purchase_session_rate_pct,
        2
    ) AS purchase_session_rate_pct,

    ROUND(
        ordered_view_to_cart_rate_pct,
        2
    ) AS ordered_view_to_cart_rate_pct,

    ROUND(
        ordered_cart_to_purchase_rate_pct,
        2
    ) AS ordered_cart_to_purchase_rate_pct,

    is_partial_month

FROM monthly_funnel_30

ORDER BY month_start;


/*
Expected results:

Month       Total Sessions   Purchase    V→C       C→P
----------------------------------------------------------
2020-09       18,198          3.82%      6.23%    49.83%
2020-10      103,537          4.19%      6.83%    49.67%
2020-11      118,377          4.39%      7.10%    50.26%
2020-12       93,596          4.89%      8.08%    49.02%
2021-01      108,546          5.31%      9.17%    46.30%
2021-02       97,558          5.30%      9.09%    46.28%

September is a partial month and is not used for the
October-to-February comparison.
*/


-- ------------------------------------------------------------
-- 3. Compare the first and last full months directly
--
-- This query produces the numbers used in the case-study story.
-- ------------------------------------------------------------

WITH comparison AS (

    SELECT

        MAX(CASE
            WHEN month_start = DATE '2020-10-01'
            THEN purchase_session_rate_pct
        END) AS oct_purchase_rate,

        MAX(CASE
            WHEN month_start = DATE '2021-02-01'
            THEN purchase_session_rate_pct
        END) AS feb_purchase_rate,

        MAX(CASE
            WHEN month_start = DATE '2020-10-01'
            THEN ordered_view_to_cart_rate_pct
        END) AS oct_vtc_rate,

        MAX(CASE
            WHEN month_start = DATE '2021-02-01'
            THEN ordered_view_to_cart_rate_pct
        END) AS feb_vtc_rate,

        MAX(CASE
            WHEN month_start = DATE '2020-10-01'
            THEN ordered_cart_to_purchase_rate_pct
        END) AS oct_ctp_rate,

        MAX(CASE
            WHEN month_start = DATE '2021-02-01'
            THEN ordered_cart_to_purchase_rate_pct
        END) AS feb_ctp_rate

    FROM monthly_funnel_30

)

SELECT
    ROUND(oct_purchase_rate, 2)
        AS oct_purchase_rate_pct,

    ROUND(feb_purchase_rate, 2)
        AS feb_purchase_rate_pct,

    ROUND(
        feb_purchase_rate - oct_purchase_rate,
        2
    ) AS purchase_rate_change_pp,

    ROUND(oct_vtc_rate, 2)
        AS oct_vtc_rate_pct,

    ROUND(feb_vtc_rate, 2)
        AS feb_vtc_rate_pct,

    ROUND(
        feb_vtc_rate - oct_vtc_rate,
        2
    ) AS vtc_rate_change_pp,

    ROUND(oct_ctp_rate, 2)
        AS oct_ctp_rate_pct,

    ROUND(feb_ctp_rate, 2)
        AS feb_ctp_rate_pct,

    ROUND(
        feb_ctp_rate - oct_ctp_rate,
        2
    ) AS ctp_rate_change_pp

FROM comparison;


/*
Expected comparison:

Purchase-session:
4.19% → 5.30% = +1.11 pp

Ordered View-to-Cart:
6.83% → 9.09% = +2.26 pp

Ordered Cart-to-Purchase:
49.67% → 46.28% = -3.39 pp
*/


-- ------------------------------------------------------------
-- 4. Power BI output
--
-- Keep September in the output so the partial-period evidence
-- remains visible in the data model, but Power BI can filter
-- is_partial_month = FALSE for direct trend comparison.
-- ------------------------------------------------------------

CREATE OR REPLACE TABLE pbi_monthly_funnel_30 AS

SELECT
    month_start,
    total_sessions,
    viewing_sessions,
    cart_sessions,
    purchasing_sessions,

    ordered_view_to_cart_sessions,
    ordered_cart_to_purchase_sessions,
    complete_ordered_funnel_sessions,

    purchase_session_rate_pct,
    ordered_view_to_cart_rate_pct,
    ordered_cart_to_purchase_rate_pct,
    complete_ordered_funnel_rate_pct,

    is_partial_month

FROM monthly_funnel_30

ORDER BY month_start;
