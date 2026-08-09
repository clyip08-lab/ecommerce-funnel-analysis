-- ============================================================
-- 05_category_peer_analysis.sql
-- E-commerce Funnel Analysis
--
-- Purpose:
-- Diagnose category-level funnel performance using:
--
-- 1. session + category grain
-- 2. weighted site benchmarks
-- 3. leave-one-out peer benchmarks
-- 4. practical sample-size thresholds
-- 5. volume-adjusted opportunity gaps
--
-- Important:
-- A category can look weak versus the whole site while still
-- performing normally or strongly relative to comparable peers.
-- ============================================================


-- ------------------------------------------------------------
-- 1. Build known business-category event base
--
-- Only mapped category_code values are used for named-category
-- diagnosis. Unmapped categories remain in overall site metrics
-- but are not merged into one artificial "Unknown" category.
-- ------------------------------------------------------------

CREATE OR REPLACE TABLE category_events_known_30 AS

SELECT
    analytical_session_id,
    event_time_utc,
    source_event_id,
    event_type,
    category_code,

    -- Peer family = first two levels of category hierarchy
    -- Example:
    -- computers.components.cooler
    -- -> computers.components
    CONCAT(
        SPLIT_PART(category_code, '.', 1),
        '.',
        SPLIT_PART(category_code, '.', 2)
    ) AS category_family

FROM analysis_events_30

WHERE category_code IS NOT NULL
  AND TRIM(category_code) <> '';


-- ------------------------------------------------------------
-- 2. Assign event sequence within session + category
--
-- A session may touch multiple categories, so the analytical
-- grain here is NOT simply one row per session.
-- ------------------------------------------------------------

CREATE OR REPLACE TABLE category_event_sequence_30 AS

SELECT
    *,

    ROW_NUMBER() OVER (
        PARTITION BY
            analytical_session_id,
            category_code
        ORDER BY
            event_time_utc,
            source_event_id
    ) AS category_event_sequence

FROM category_events_known_30;


-- ------------------------------------------------------------
-- 3. Collapse to one row per session + category
-- ------------------------------------------------------------

CREATE OR REPLACE TABLE session_category_code_summary_30 AS

SELECT
    analytical_session_id,
    category_code,
    category_family,

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
        THEN category_event_sequence
    END) AS first_view_sequence,

    MIN(CASE
        WHEN event_type = 'cart'
        THEN category_event_sequence
    END) AS first_cart_sequence,

    MIN(CASE
        WHEN event_type = 'purchase'
        THEN category_event_sequence
    END) AS first_purchase_sequence

FROM category_event_sequence_30

GROUP BY
    analytical_session_id,
    category_code,
    category_family;


/*
Validation from the project:

session + category_code rows        393,134
represented analytical sessions     383,455
known category codes                    107
*/


-- ------------------------------------------------------------
-- 4. Add ordered category-level funnel flags
-- ------------------------------------------------------------

CREATE OR REPLACE TABLE session_category_funnel_30 AS

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
         AND first_purchase_sequence IS NOT NULL
         AND first_view_sequence < first_purchase_sequence
        THEN 1 ELSE 0
    END AS ordered_view_to_purchase

FROM session_category_code_summary_30;


-- ------------------------------------------------------------
-- 5. Aggregate category performance
-- ------------------------------------------------------------

CREATE OR REPLACE TABLE category_performance_30 AS

SELECT
    category_code,
    category_family,

    SUM(has_view) AS viewing_sessions,
    SUM(has_cart) AS cart_sessions,
    SUM(has_purchase) AS purchasing_sessions,

    SUM(ordered_view_to_cart)
        AS ordered_view_to_cart_sessions,

    SUM(ordered_cart_to_purchase)
        AS ordered_cart_to_purchase_sessions,

    SUM(ordered_view_to_purchase)
        AS ordered_view_to_purchase_sessions,

    100.0 * SUM(ordered_view_to_cart)
        / NULLIF(SUM(has_view), 0)
        AS view_to_cart_rate_pct,

    100.0 * SUM(ordered_cart_to_purchase)
        / NULLIF(SUM(has_cart), 0)
        AS cart_to_purchase_rate_pct,

    100.0 * SUM(ordered_view_to_purchase)
        / NULLIF(SUM(has_view), 0)
        AS view_to_purchase_rate_pct

FROM session_category_funnel_30

GROUP BY
    category_code,
    category_family;


/*
Known-category weighted totals from the project:

Viewing category sessions      390,280
Cart category sessions          37,217
Purchasing category sessions    21,518

Weighted View-to-Cart             9.35%
Weighted Cart-to-Purchase        46.77%
Weighted View-to-Purchase         4.69%
*/


-- ------------------------------------------------------------
-- 6. Calculate weighted site-level benchmark
--
-- IMPORTANT:
-- This is weighted by session denominator.
--
-- It is NOT:
-- AVG(category conversion rates)
-- ------------------------------------------------------------

CREATE OR REPLACE TABLE category_site_benchmark_30 AS

SELECT

    100.0 * SUM(ordered_view_to_cart_sessions)
        / NULLIF(SUM(viewing_sessions), 0)
        AS site_view_to_cart_rate_pct,

    100.0 * SUM(ordered_cart_to_purchase_sessions)
        / NULLIF(SUM(cart_sessions), 0)
        AS site_cart_to_purchase_rate_pct

FROM category_performance_30;


/*
Expected approximately:

Site View-to-Cart       9.35%
Site Cart-to-Purchase  46.77%
*/


-- ------------------------------------------------------------
-- 7. Review denominator distributions
--
-- These percentiles were used to choose practical thresholds.
-- They are NOT performance benchmarks.
-- ------------------------------------------------------------

SELECT
    QUANTILE_CONT(viewing_sessions, 0.50)
        AS median_viewing_sessions,

    QUANTILE_CONT(viewing_sessions, 0.75)
        AS p75_viewing_sessions,

    QUANTILE_CONT(viewing_sessions, 0.90)
        AS p90_viewing_sessions

FROM category_performance_30
WHERE viewing_sessions > 0;


SELECT
    QUANTILE_CONT(cart_sessions, 0.50)
        AS median_cart_sessions,

    QUANTILE_CONT(cart_sessions, 0.75)
        AS p75_cart_sessions,

    QUANTILE_CONT(cart_sessions, 0.90)
        AS p90_cart_sessions

FROM category_performance_30
WHERE cart_sessions > 0;


/*
Practical thresholds selected:

Category View-to-Cart:
>= 2,643 viewing sessions

Category Cart-to-Purchase:
>= 196 cart sessions

These thresholds improve stability but are NOT formal
statistical-significance tests.
*/


-- ------------------------------------------------------------
-- 8. Build leave-one-out category peer benchmarks
--
-- For every target category:
--
-- Peer benchmark =
-- performance of OTHER categories in the same family
--
-- The target category is excluded so it does not influence
-- its own benchmark.
-- ------------------------------------------------------------

CREATE OR REPLACE TABLE category_peer_benchmark_30 AS

SELECT
    target.category_code,
    target.category_family,

    target.viewing_sessions,
    target.cart_sessions,
    target.purchasing_sessions,

    target.ordered_view_to_cart_sessions,
    target.ordered_cart_to_purchase_sessions,

    target.view_to_cart_rate_pct,
    target.cart_to_purchase_rate_pct,

    COUNT(peer.category_code)
        AS peer_category_count,

    SUM(peer.viewing_sessions)
        AS peer_viewing_sessions,

    SUM(peer.cart_sessions)
        AS peer_cart_sessions,

    SUM(peer.ordered_view_to_cart_sessions)
        AS peer_ordered_view_to_cart_sessions,

    SUM(peer.ordered_cart_to_purchase_sessions)
        AS peer_ordered_cart_to_purchase_sessions,

    100.0 * SUM(peer.ordered_view_to_cart_sessions)
        / NULLIF(SUM(peer.viewing_sessions), 0)
        AS peer_view_to_cart_rate_pct,

    100.0 * SUM(peer.ordered_cart_to_purchase_sessions)
        / NULLIF(SUM(peer.cart_sessions), 0)
        AS peer_cart_to_purchase_rate_pct

FROM category_performance_30 AS target

LEFT JOIN category_performance_30 AS peer

    ON target.category_family = peer.category_family

    -- Leave-one-out:
    AND target.category_code <> peer.category_code

GROUP BY
    target.category_code,
    target.category_family,
    target.viewing_sessions,
    target.cart_sessions,
    target.purchasing_sessions,
    target.ordered_view_to_cart_sessions,
    target.ordered_cart_to_purchase_sessions,
    target.view_to_cart_rate_pct,
    target.cart_to_purchase_rate_pct;


-- ------------------------------------------------------------
-- 9. Add peer-relative gaps and reliability classification
-- ------------------------------------------------------------

CREATE OR REPLACE TABLE category_peer_diagnosis_30 AS

SELECT
    *,

    view_to_cart_rate_pct
        - peer_view_to_cart_rate_pct
        AS view_to_cart_gap_pp,

    cart_to_purchase_rate_pct
        - peer_cart_to_purchase_rate_pct
        AS cart_to_purchase_gap_pp,

    CASE

        WHEN peer_category_count < 2
          OR peer_view_to_cart_rate_pct IS NULL
        THEN 'Insufficient peers'

        WHEN viewing_sessions >= 2643
         AND peer_viewing_sessions >= 2643
        THEN 'Reliable'

        ELSE 'Directional'

    END AS view_to_cart_peer_confidence,

    CASE

        WHEN peer_category_count < 2
          OR peer_cart_to_purchase_rate_pct IS NULL
        THEN 'Insufficient peers'

        WHEN cart_sessions >= 196
         AND peer_cart_sessions >= 196
        THEN 'Reliable'

        ELSE 'Directional'

    END AS cart_to_purchase_peer_confidence

FROM category_peer_benchmark_30;


-- ------------------------------------------------------------
-- 10. Classify which funnel stage needs attention
-- ------------------------------------------------------------

CREATE OR REPLACE TABLE category_peer_classification_30 AS

SELECT
    *,

    CASE

        WHEN view_to_cart_gap_pp < 0
         AND cart_to_purchase_gap_pp < 0
        THEN 'Both stages below peers'

        WHEN view_to_cart_gap_pp < 0
         AND cart_to_purchase_gap_pp >= 0
        THEN 'Front funnel below peers'

        WHEN view_to_cart_gap_pp >= 0
         AND cart_to_purchase_gap_pp < 0
        THEN 'Downstream below peers'

        WHEN view_to_cart_gap_pp >= 0
         AND cart_to_purchase_gap_pp >= 0
        THEN 'At / above peers'

        ELSE 'Insufficient peer comparison'

    END AS performance_classification

FROM category_peer_diagnosis_30;


-- ------------------------------------------------------------
-- 11. Calculate opportunity gaps
--
-- Formula:
--
-- denominator × (peer rate - actual rate)
--
-- Only positive underperformance creates an opportunity gap.
--
-- IMPORTANT:
-- This is a mathematical sizing metric for prioritisation.
-- It is NOT a forecast of guaranteed incremental conversions.
-- ------------------------------------------------------------

CREATE OR REPLACE TABLE category_opportunity_30 AS

SELECT
    category_code,
    category_family,

    'View to Cart' AS funnel_stage,

    viewing_sessions AS denominator_sessions,

    view_to_cart_rate_pct AS category_rate_pct,
    peer_view_to_cart_rate_pct AS peer_rate_pct,

    peer_view_to_cart_rate_pct
        - view_to_cart_rate_pct
        AS rate_gap_pp,

    CASE
        WHEN peer_view_to_cart_rate_pct
             > view_to_cart_rate_pct
        THEN ROUND(
            viewing_sessions
            * (
                peer_view_to_cart_rate_pct
                - view_to_cart_rate_pct
              )
            / 100.0
        )
        ELSE 0
    END AS opportunity_gap_sessions,

    view_to_cart_peer_confidence
        AS peer_confidence

FROM category_peer_classification_30


UNION ALL


SELECT
    category_code,
    category_family,

    'Cart to Purchase' AS funnel_stage,

    cart_sessions AS denominator_sessions,

    cart_to_purchase_rate_pct AS category_rate_pct,
    peer_cart_to_purchase_rate_pct AS peer_rate_pct,

    peer_cart_to_purchase_rate_pct
        - cart_to_purchase_rate_pct
        AS rate_gap_pp,

    CASE
        WHEN peer_cart_to_purchase_rate_pct
             > cart_to_purchase_rate_pct
        THEN ROUND(
            cart_sessions
            * (
                peer_cart_to_purchase_rate_pct
                - cart_to_purchase_rate_pct
              )
            / 100.0
        )
        ELSE 0
    END AS opportunity_gap_sessions,

    cart_to_purchase_peer_confidence
        AS peer_confidence

FROM category_peer_classification_30;


-- ------------------------------------------------------------
-- 12. Largest RELIABLE View-to-Cart opportunities
-- ------------------------------------------------------------

SELECT
    category_code,
    ROUND(view_to_cart_rate_pct, 2)
        AS category_rate_pct,

    ROUND(peer_view_to_cart_rate_pct, 2)
        AS peer_rate_pct,

    ROUND(view_to_cart_gap_pp, 2)
        AS gap_vs_peers_pp,

    viewing_sessions

FROM category_peer_classification_30

WHERE view_to_cart_peer_confidence = 'Reliable'
  AND view_to_cart_gap_pp < 0

ORDER BY
    viewing_sessions
    * ABS(view_to_cart_gap_pp)
    DESC;


/*
Reliable dashboard priorities included:

Cooler         609 estimated cart-session gap
Motherboard    406
CPU            291
HDD            175
Mouse          166
*/


-- ------------------------------------------------------------
-- 13. Largest RELIABLE Cart-to-Purchase opportunities
-- ------------------------------------------------------------

SELECT
    category_code,
    ROUND(cart_to_purchase_rate_pct, 2)
        AS category_rate_pct,

    ROUND(peer_cart_to_purchase_rate_pct, 2)
        AS peer_rate_pct,

    ROUND(cart_to_purchase_gap_pp, 2)
        AS gap_vs_peers_pp,

    cart_sessions

FROM category_peer_classification_30

WHERE cart_to_purchase_peer_confidence = 'Reliable'
  AND cart_to_purchase_gap_pp < 0

ORDER BY
    cart_sessions
    * ABS(cart_to_purchase_gap_pp)
    DESC;


/*
Reliable dashboard priorities included:

CPU              120 estimated purchase-session gap
Monitor           49
Acoustic audio    44
Drill             26
Videoregister     24
*/


-- ------------------------------------------------------------
-- 14. Example: why peer benchmark changes interpretation
-- ------------------------------------------------------------

SELECT
    category_code,

    ROUND(cart_to_purchase_rate_pct, 2)
        AS category_ctp_rate_pct,

    ROUND(peer_cart_to_purchase_rate_pct, 2)
        AS peer_ctp_rate_pct,

    ROUND(cart_to_purchase_gap_pp, 2)
        AS gap_vs_peers_pp,

    cart_to_purchase_peer_confidence

FROM category_peer_classification_30

WHERE category_code = 'computers.components.videocards';


/*
Expected:

Videocards Cart-to-Purchase:
Category rate       40.98%
Peer rate           37.64%
Gap vs peers        +3.34 pp

Site benchmark:
46.77%

Interpretation:

Against the whole site:
40.98% < 46.77%
-> looks weak

Against comparable peers:
40.98% > 37.64%
-> actually above peer performance

This is why benchmark choice matters.
*/


-- ------------------------------------------------------------
-- 15. Power BI category peer output
-- ------------------------------------------------------------

CREATE OR REPLACE TABLE pbi_category_peer_30 AS

SELECT
    category_code,
    category_family,

    viewing_sessions,
    cart_sessions,
    purchasing_sessions,

    view_to_cart_rate_pct,
    cart_to_purchase_rate_pct,

    peer_view_to_cart_rate_pct,
    peer_cart_to_purchase_rate_pct,

    view_to_cart_gap_pp,
    cart_to_purchase_gap_pp,

    peer_viewing_sessions,
    peer_cart_sessions,
    peer_category_count,

    view_to_cart_peer_confidence,
    cart_to_purchase_peer_confidence,

    performance_classification

FROM category_peer_classification_30;


-- ------------------------------------------------------------
-- 16. Power BI opportunity output
-- ------------------------------------------------------------

CREATE OR REPLACE TABLE pbi_category_opportunity_30 AS

SELECT
    category_code,
    category_family,
    funnel_stage,

    denominator_sessions,
    category_rate_pct,
    peer_rate_pct,
    rate_gap_pp,

    opportunity_gap_sessions,
    peer_confidence

FROM category_opportunity_30;
