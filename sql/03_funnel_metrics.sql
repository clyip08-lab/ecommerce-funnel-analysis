-- ============================================================
-- 03_funnel_metrics.sql
--
-- Purpose:
-- Build session-level funnel metrics using the reconstructed
-- 30-minute analytical sessions.
--
-- Funnel progression is evaluated using the earliest observed
-- timestamp for each stage.
--
-- A transition is retained when the next-stage timestamp is
-- equal to or later than the previous-stage timestamp.
--
-- Same-second transitions are retained because the source
-- timestamps have second-level precision only.
-- ============================================================


-- ------------------------------------------------------------
-- 1. Summarise each analytical session
--
-- MAX(CASE WHEN...) creates session-level event-presence flags.
-- MIN(CASE WHEN...event_time_utc) records the earliest observed
-- timestamp for View, Cart and Purchase within each session.
-- ------------------------------------------------------------

CREATE OR REPLACE TABLE session_summary_30 AS

SELECT
    analytical_session_id,

    MIN(event_time_utc) AS session_start_time,
    MAX(event_time_utc) AS session_end_time,

    MAX(
        CASE WHEN event_type = 'view'
        THEN 1 ELSE 0 END
    ) AS has_view,

    MAX(
        CASE WHEN event_type = 'cart'
        THEN 1 ELSE 0 END
    ) AS has_cart,

    MAX(
        CASE WHEN event_type = 'purchase'
        THEN 1 ELSE 0 END
    ) AS has_purchase,

    MIN(
        CASE WHEN event_type = 'view'
        THEN event_time_utc END
    ) AS first_view_time,

    MIN(
        CASE WHEN event_type = 'cart'
        THEN event_time_utc END
    ) AS first_cart_time,

    MIN(
        CASE WHEN event_type = 'purchase'
        THEN event_time_utc END
    ) AS first_purchase_time

FROM analysis_events_30

GROUP BY analytical_session_id;


-- ------------------------------------------------------------
-- 2. Build ordered funnel flags
--
-- Event presence alone is not enough to establish funnel
-- progression. The earliest observed stage timestamps must also
-- be compatible with the expected View → Cart → Purchase order.
--
-- Same-second transitions are retained because the source data
-- does not provide sub-second timestamp precision.
-- ------------------------------------------------------------

CREATE OR REPLACE TABLE session_funnel_30 AS

SELECT
    *,

    CASE
        WHEN first_view_time IS NOT NULL
         AND first_cart_time IS NOT NULL
         AND first_view_time <= first_cart_time
        THEN 1 ELSE 0
    END AS ordered_view_to_cart,

    CASE
        WHEN first_cart_time IS NOT NULL
         AND first_purchase_time IS NOT NULL
         AND first_cart_time <= first_purchase_time
        THEN 1 ELSE 0
    END AS ordered_cart_to_purchase,

    CASE
        WHEN first_view_time IS NOT NULL
         AND first_cart_time IS NOT NULL
         AND first_purchase_time IS NOT NULL
         AND first_view_time <= first_cart_time
         AND first_cart_time <= first_purchase_time
        THEN 1 ELSE 0
    END AS complete_ordered_funnel

FROM session_summary_30;


-- ============================================================
-- VALIDATION AND CORE FUNNEL METRICS
-- ============================================================


-- ------------------------------------------------------------
-- 3. Session-level funnel counts
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS total_sessions,

    SUM(has_view) AS viewing_sessions,
    SUM(has_cart) AS cart_sessions,
    SUM(has_purchase) AS purchasing_sessions,

    SUM(ordered_view_to_cart)
        AS ordered_view_to_cart_sessions,

    SUM(ordered_cart_to_purchase)
        AS ordered_cart_to_purchase_sessions,

    SUM(complete_ordered_funnel)
        AS complete_ordered_funnel_sessions

FROM session_funnel_30;


/*
Expected primary results:

total_sessions                      539,812
viewing_sessions                    536,672
cart_sessions                        43,615
purchasing_sessions                  25,747

ordered_view_to_cart_sessions        42,745
ordered_cart_to_purchase_sessions    21,022
complete_ordered_funnel_sessions     20,575
*/


-- ------------------------------------------------------------
-- 4. Final dashboard funnel rates
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS total_sessions,

    ROUND(
        100.0 * SUM(has_purchase)
        / COUNT(*),
        2
    ) AS purchase_session_rate_pct,

    ROUND(
        100.0 * SUM(ordered_view_to_cart)
        / NULLIF(SUM(has_view), 0),
        2
    ) AS ordered_view_to_cart_rate_pct,

    ROUND(
        100.0 * SUM(ordered_cart_to_purchase)
        / NULLIF(SUM(has_cart), 0),
        2
    ) AS ordered_cart_to_purchase_rate_pct,

    ROUND(
        100.0 * SUM(complete_ordered_funnel)
        / NULLIF(SUM(has_view), 0),
        2
    ) AS complete_ordered_funnel_rate_pct

FROM session_funnel_30;


/*
Expected results:

Total Sessions                     539,812
Purchase-session Rate                 4.77%
Ordered View-to-Cart Rate             7.96%
Ordered Cart-to-Purchase Rate        48.20%
Complete Ordered Funnel Rate          3.83%
*/


-- ------------------------------------------------------------
-- 5. Compare event co-occurrence with ordered progression
--
-- This shows why event presence alone is insufficient.
-- Funnel progression also considers the relative timing of the
-- earliest observed stage timestamps.
-- ------------------------------------------------------------

SELECT

    SUM(CASE
        WHEN has_view = 1
         AND has_cart = 1
        THEN 1 ELSE 0
    END) AS sessions_with_view_and_cart,

    SUM(ordered_view_to_cart)
        AS ordered_view_to_cart_sessions,

    SUM(CASE
        WHEN has_cart = 1
         AND has_purchase = 1
        THEN 1 ELSE 0
    END) AS sessions_with_cart_and_purchase,

    SUM(ordered_cart_to_purchase)
        AS ordered_cart_to_purchase_sessions,

    SUM(CASE
        WHEN has_view = 1
         AND has_cart = 1
         AND has_purchase = 1
        THEN 1 ELSE 0
    END) AS sessions_with_all_three_events,

    SUM(complete_ordered_funnel)
        AS complete_ordered_funnel_sessions

FROM session_funnel_30;


/*
Expected comparison:

View + Cart co-occurrence           43,097
Ordered View → Cart                 42,745

Cart + Purchase co-occurrence       21,226
Ordered Cart → Purchase             21,022

All three events                    20,962
Ordered View → Cart → Purchase      20,575
*/
-- ============================================================
-- 6. Timestamp precision diagnostic
-- ============================================================

SELECT
    COUNT(*) FILTER (
        WHERE first_view_time IS NOT NULL
          AND first_cart_time IS NOT NULL
          AND first_view_time = first_cart_time
    ) AS view_cart_same_second_sessions,

    COUNT(*) FILTER (
        WHERE first_cart_time IS NOT NULL
          AND first_purchase_time IS NOT NULL
          AND first_cart_time = first_purchase_time
    ) AS cart_purchase_same_second_sessions

FROM session_summary_30;

/*
Expected results:

View–Cart same-second sessions         50
Cart–Purchase same-second sessions      1
*/
