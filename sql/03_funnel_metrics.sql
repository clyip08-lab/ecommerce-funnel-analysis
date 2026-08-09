-- ============================================================
-- 03_funnel_metrics.sql
-- E-commerce Funnel Analysis
--
-- Purpose:
-- Convert reconstructed analytical sessions into session-level
-- funnel metrics.
--
-- Funnel stages:
-- View → Cart → Purchase
--
-- Important:
-- Funnel metrics are calculated at SESSION level, not by
-- dividing raw event-row counts.
-- ============================================================


-- ------------------------------------------------------------
-- 1. Assign a deterministic event sequence inside each session
-- ------------------------------------------------------------

CREATE OR REPLACE TABLE session_event_sequence_30 AS

SELECT
    *,

    ROW_NUMBER() OVER (
        PARTITION BY analytical_session_id
        ORDER BY event_time_utc, source_event_id
    ) AS event_sequence

FROM analysis_events_30;


-- ------------------------------------------------------------
-- 2. Summarise each analytical session
--
-- MAX(CASE WHEN...) creates session-level event-presence flags.
--
-- MIN(event_sequence) records where the first observed
-- view, cart and purchase occurred inside each session.
-- ------------------------------------------------------------

CREATE OR REPLACE TABLE session_summary_30 AS

SELECT
    analytical_session_id,

    MIN(event_time_utc) AS session_start_time,
    MAX(event_time_utc) AS session_end_time,

    MAX(CASE
        WHEN event_type = 'view'
        THEN 1 ELSE 0
    END) AS has_view,

    MAX(CASE
        WHEN event_type = 'cart'
        THEN 1 ELSE 0
    END) AS has_cart,

    MAX(CASE
        WHEN event_type = 'purchase'
        THEN 1 ELSE 0
    END) AS has_purchase,

    MIN(CASE
        WHEN event_type = 'view'
        THEN event_sequence
    END) AS first_view_sequence,

    MIN(CASE
        WHEN event_type = 'cart'
        THEN event_sequence
    END) AS first_cart_sequence,

    MIN(CASE
        WHEN event_type = 'purchase'
        THEN event_sequence
    END) AS first_purchase_sequence

FROM session_event_sequence_30

GROUP BY analytical_session_id;


-- ------------------------------------------------------------
-- 3. Build ordered funnel flags
--
-- Event presence alone is not enough.
--
-- Example:
-- Purchase → View → Cart
--
-- contains all three event types, but is not counted as an
-- observed View → Cart → Purchase sequence.
-- ------------------------------------------------------------

CREATE OR REPLACE TABLE session_funnel_30 AS

SELECT
    *,

    CASE
        WHEN first_view_sequence IS NOT NULL
         AND first_cart_sequence IS NOT NULL
         AND first_view_sequence < first_cart_sequence
        THEN 1 ELSE 0
    END AS ordered_view_to_cart,

    CASE
        WHEN first_cart_sequence IS NOT NULL
         AND first_purchase_sequence IS NOT NULL
         AND first_cart_sequence < first_purchase_sequence
        THEN 1 ELSE 0
    END AS ordered_cart_to_purchase,

    CASE
        WHEN first_view_sequence IS NOT NULL
         AND first_cart_sequence IS NOT NULL
         AND first_purchase_sequence IS NOT NULL
         AND first_view_sequence < first_cart_sequence
         AND first_cart_sequence < first_purchase_sequence
        THEN 1 ELSE 0
    END AS complete_ordered_funnel

FROM session_summary_30;


-- ============================================================
-- VALIDATION AND CORE FUNNEL METRICS
-- ============================================================


-- ------------------------------------------------------------
-- 4. Session-level funnel counts
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
-- 5. Final dashboard funnel rates
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
-- 6. Compare simple event co-occurrence with ordered progression
--
-- This shows why event sequence matters.
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
