-- ============================================================
-- 06_brand_price_drivers.sql
-- E-commerce Funnel Analysis
--
-- Purpose:
-- Investigate whether brand and price patterns provide useful
-- signals behind selected category-level funnel gaps.
--
-- Important:
-- These analyses identify ASSOCIATIONS and investigation
-- signals. They do not establish causal effects.
-- ============================================================


-- ============================================================
-- PART A — BRAND DATA QUALITY
-- ============================================================


-- ------------------------------------------------------------
-- 1. Review brand coverage in priority categories
-- ------------------------------------------------------------

SELECT
    category_code,

    COUNT(*) AS event_rows,

    COUNT(DISTINCT product_id) AS products,

    COUNT(DISTINCT CASE
        WHEN brand IS NOT NULL
         AND TRIM(brand) <> ''
        THEN LOWER(TRIM(brand))
    END) AS known_brands,

    SUM(CASE
        WHEN brand IS NULL
          OR TRIM(brand) = ''
        THEN 1 ELSE 0
    END) AS missing_brand_rows,

    ROUND(
        100.0
        * SUM(CASE
            WHEN brand IS NULL
              OR TRIM(brand) = ''
            THEN 1 ELSE 0
          END)
        / COUNT(*),
        2
    ) AS missing_brand_rate_pct

FROM analysis_events_30

WHERE category_code IN (
    'computers.components.cpu',
    'electronics.video.tv',
    'computers.components.cooler',
    'auto.accessories.videoregister',
    'computers.peripherals.monitor'
)

GROUP BY category_code

ORDER BY category_code;


/*
Validated project results:

Category                         Missing brand
------------------------------------------------
CPU                                  0.04%
TV                                   2.42%
Cooler                              22.34%
Videoregister                       35.43%
Monitor                              4.70%

Brand completeness therefore varied substantially across
priority categories.
*/


-- ============================================================
-- PART B — BRAND-LEVEL FUNNEL PERFORMANCE
-- ============================================================


-- ------------------------------------------------------------
-- 2. Create session + category + brand event sequence
--
-- Brand analysis uses a new grain:
--
-- session + category + brand
--
-- rather than raw event rows.
-- ------------------------------------------------------------

CREATE OR REPLACE TABLE category_brand_event_sequence_30 AS

SELECT
    analytical_session_id,
    category_code,

    COALESCE(
        NULLIF(LOWER(TRIM(brand)), ''),
        'unknown / missing'
    ) AS brand_group,

    event_type,
    event_time_utc,
    source_event_id,

    ROW_NUMBER() OVER (
        PARTITION BY
            analytical_session_id,
            category_code,
            COALESCE(
                NULLIF(LOWER(TRIM(brand)), ''),
                'unknown / missing'
            )
        ORDER BY
            event_time_utc,
            source_event_id
    ) AS brand_event_sequence

FROM analysis_events_30

WHERE category_code IN (
    'computers.components.cpu',
    'electronics.video.tv',
    'computers.components.cooler',
    'auto.accessories.videoregister',
    'computers.peripherals.monitor'
);


-- ------------------------------------------------------------
-- 3. Collapse to one row per session + category + brand
-- ------------------------------------------------------------

CREATE OR REPLACE TABLE session_category_brand_summary_30 AS

SELECT
    analytical_session_id,
    category_code,
    brand_group,

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
        THEN brand_event_sequence
    END) AS first_view_sequence,

    MIN(CASE
        WHEN event_type = 'cart'
        THEN brand_event_sequence
    END) AS first_cart_sequence,

    MIN(CASE
        WHEN event_type = 'purchase'
        THEN brand_event_sequence
    END) AS first_purchase_sequence

FROM category_brand_event_sequence_30

GROUP BY
    analytical_session_id,
    category_code,
    brand_group;


/*
Project validation:

session + category + brand rows      49,237
represented analytical sessions     42,867
*/


-- ------------------------------------------------------------
-- 4. Calculate brand-level ordered funnel performance
-- ------------------------------------------------------------

CREATE OR REPLACE TABLE category_brand_performance_30 AS

SELECT
    category_code,
    brand_group,

    SUM(has_view) AS viewing_sessions,
    SUM(has_cart) AS cart_sessions,
    SUM(has_purchase) AS purchasing_sessions,

    SUM(
        CASE
            WHEN first_view_sequence IS NOT NULL
             AND first_cart_sequence IS NOT NULL
             AND first_view_sequence < first_cart_sequence
            THEN 1 ELSE 0
        END
    ) AS ordered_view_to_cart_sessions,

    SUM(
        CASE
            WHEN first_cart_sequence IS NOT NULL
             AND first_purchase_sequence IS NOT NULL
             AND first_cart_sequence < first_purchase_sequence
            THEN 1 ELSE 0
        END
    ) AS ordered_cart_to_purchase_sessions,

    100.0
    * SUM(
        CASE
            WHEN first_view_sequence IS NOT NULL
             AND first_cart_sequence IS NOT NULL
             AND first_view_sequence < first_cart_sequence
            THEN 1 ELSE 0
        END
      )
    / NULLIF(SUM(has_view), 0)
        AS view_to_cart_rate_pct,

    100.0
    * SUM(
        CASE
            WHEN first_cart_sequence IS NOT NULL
             AND first_purchase_sequence IS NOT NULL
             AND first_cart_sequence < first_purchase_sequence
            THEN 1 ELSE 0
        END
      )
    / NULLIF(SUM(has_cart), 0)
        AS cart_to_purchase_rate_pct

FROM session_category_brand_summary_30

GROUP BY
    category_code,
    brand_group;


-- ------------------------------------------------------------
-- 5. Review practical brand sample coverage
--
-- Thresholds:
--
-- View-to-Cart:
-- >= 150 viewing sessions
--
-- Cart-to-Purchase:
-- >= 30 cart sessions
--
-- These are practical stability rules, not statistical
-- significance tests.
-- ------------------------------------------------------------

SELECT
    category_code,

    COUNT(*) FILTER (
        WHERE brand_group <> 'unknown / missing'
          AND viewing_sessions >= 150
    ) AS eligible_vtc_brands,

    COUNT(*) FILTER (
        WHERE brand_group <> 'unknown / missing'
          AND cart_sessions >= 30
    ) AS eligible_ctp_brands

FROM category_brand_performance_30

GROUP BY category_code

ORDER BY category_code;


/*
Validated project results:

Category          VTC eligible brands    CTP eligible brands
-------------------------------------------------------------
Videoregister             12                     0
Cooler                     8                     4
CPU                        2                     2
Monitor                   10                     5
TV                        14                     5
*/


-- ============================================================
-- PART C — LEAVE-ONE-OUT BRAND PEER BENCHMARK
-- ============================================================


-- ------------------------------------------------------------
-- 6. View-to-Cart eligible brand table
-- ------------------------------------------------------------

CREATE OR REPLACE TABLE brand_vtc_eligible_30 AS

SELECT *
FROM category_brand_performance_30

WHERE brand_group <> 'unknown / missing'
  AND viewing_sessions >= 150;


-- ------------------------------------------------------------
-- 7. Leave-one-out View-to-Cart brand benchmark
-- ------------------------------------------------------------

CREATE OR REPLACE TABLE brand_view_peer_benchmark_30 AS

SELECT
    target.category_code,
    target.brand_group,

    target.viewing_sessions
        AS denominator_sessions,

    target.ordered_view_to_cart_sessions
        AS numerator_sessions,

    target.view_to_cart_rate_pct
        AS brand_rate_pct,

    COUNT(peer.brand_group)
        AS peer_brand_count,

    SUM(peer.viewing_sessions)
        AS peer_denominator_sessions,

    100.0
    * SUM(peer.ordered_view_to_cart_sessions)
    / NULLIF(SUM(peer.viewing_sessions), 0)
        AS peer_rate_pct

FROM brand_vtc_eligible_30 AS target

LEFT JOIN brand_vtc_eligible_30 AS peer

    ON target.category_code = peer.category_code
   AND target.brand_group <> peer.brand_group

GROUP BY
    target.category_code,
    target.brand_group,
    target.viewing_sessions,
    target.ordered_view_to_cart_sessions,
    target.view_to_cart_rate_pct;


-- ------------------------------------------------------------
-- 8. Cart-to-Purchase eligible brand table
-- ------------------------------------------------------------

CREATE OR REPLACE TABLE brand_ctp_eligible_30 AS

SELECT *
FROM category_brand_performance_30

WHERE brand_group <> 'unknown / missing'
  AND cart_sessions >= 30;


-- ------------------------------------------------------------
-- 9. Leave-one-out Cart-to-Purchase brand benchmark
-- ------------------------------------------------------------

CREATE OR REPLACE TABLE brand_cart_peer_benchmark_30 AS

SELECT
    target.category_code,
    target.brand_group,

    target.cart_sessions
        AS denominator_sessions,

    target.ordered_cart_to_purchase_sessions
        AS numerator_sessions,

    target.cart_to_purchase_rate_pct
        AS brand_rate_pct,

    COUNT(peer.brand_group)
        AS peer_brand_count,

    SUM(peer.cart_sessions)
        AS peer_denominator_sessions,

    100.0
    * SUM(peer.ordered_cart_to_purchase_sessions)
    / NULLIF(SUM(peer.cart_sessions), 0)
        AS peer_rate_pct

FROM brand_ctp_eligible_30 AS target

LEFT JOIN brand_ctp_eligible_30 AS peer

    ON target.category_code = peer.category_code
   AND target.brand_group <> peer.brand_group

GROUP BY
    target.category_code,
    target.brand_group,
    target.cart_sessions,
    target.ordered_cart_to_purchase_sessions,
    target.cart_to_purchase_rate_pct;


-- ------------------------------------------------------------
-- 10. Why CPU was NOT used for final brand attribution
--
-- CPU had good brand completeness, but only two eligible
-- brands remained at each funnel stage.
--
-- After leaving the target brand out, only ONE comparable
-- peer brand remained.
--
-- That is not enough for a stable multi-brand peer benchmark.
-- ------------------------------------------------------------

SELECT
    category_code,
    brand_group,
    peer_brand_count,
    brand_rate_pct,
    peer_rate_pct

FROM brand_view_peer_benchmark_30

WHERE category_code = 'computers.components.cpu';


-- ============================================================
-- PART D — FINAL BRAND DRIVER OUTPUT
-- ============================================================


-- ------------------------------------------------------------
-- 11. Create Power BI brand-driver table
--
-- Final dashboard scope:
-- TV and Monitor
--
-- Require at least two OTHER eligible peer brands after
-- excluding the target brand.
-- ------------------------------------------------------------

CREATE OR REPLACE TABLE pbi_brand_driver_30 AS

SELECT
    category_code,
    brand_group,

    'View to Cart' AS funnel_stage,

    denominator_sessions,
    numerator_sessions,

    brand_rate_pct,
    peer_rate_pct,

    brand_rate_pct - peer_rate_pct
        AS gap_vs_peers_pp,

    CASE
        WHEN peer_rate_pct > brand_rate_pct
        THEN ROUND(
            denominator_sessions
            * (peer_rate_pct - brand_rate_pct)
            / 100.0
        )
        ELSE 0
    END AS opportunity_gap_sessions

FROM brand_view_peer_benchmark_30

WHERE category_code IN (
    'electronics.video.tv',
    'computers.peripherals.monitor'
)
  AND peer_brand_count >= 2
  AND brand_rate_pct < peer_rate_pct


UNION ALL


SELECT
    category_code,
    brand_group,

    'Cart to Purchase' AS funnel_stage,

    denominator_sessions,
    numerator_sessions,

    brand_rate_pct,
    peer_rate_pct,

    brand_rate_pct - peer_rate_pct
        AS gap_vs_peers_pp,

    CASE
        WHEN peer_rate_pct > brand_rate_pct
        THEN ROUND(
            denominator_sessions
            * (peer_rate_pct - brand_rate_pct)
            / 100.0
        )
        ELSE 0
    END AS opportunity_gap_sessions

FROM brand_cart_peer_benchmark_30

WHERE category_code IN (
    'electronics.video.tv',
    'computers.peripherals.monitor'
)
  AND peer_brand_count >= 2
  AND brand_rate_pct < peer_rate_pct;


/*
Example signals used in the case study:

LG TV View-to-Cart
Brand rate       0.89%
Peer rate        4.35%

Philips Monitor Cart-to-Purchase
Brand rate      32.14%
Peer rate       42.53%

These are investigation signals, NOT evidence that the
brand itself caused lower conversion.
*/


-- ============================================================
-- PART E — PRICE PROFILING
-- ============================================================


-- ------------------------------------------------------------
-- 12. Validate product-level price stability
--
-- The project found that each product had only one observed
-- positive price in TV and Monitor.
--
-- This means the dataset cannot be used to study how the SAME
-- product responded to price changes over time.
-- ------------------------------------------------------------

SELECT
    category_code,
    COUNT(*) AS products_with_multiple_prices

FROM (

    SELECT
        category_code,
        product_id

    FROM analysis_events_30

    WHERE category_code IN (
        'electronics.video.tv',
        'computers.peripherals.monitor'
    )
      AND price > 0

    GROUP BY
        category_code,
        product_id

    HAVING COUNT(DISTINCT price) > 1

) AS x

GROUP BY category_code;


/*
Expected:
0 products with multiple observed prices
for both TV and Monitor.
*/


-- ------------------------------------------------------------
-- 13. Create one price per product
-- ------------------------------------------------------------

CREATE OR REPLACE TABLE driver_product_price_30 AS

SELECT
    category_code,
    product_id,

    MIN(price) AS product_price

FROM analysis_events_30

WHERE category_code IN (
    'electronics.video.tv',
    'computers.peripherals.monitor'
)
  AND price > 0

GROUP BY
    category_code,
    product_id;


-- ------------------------------------------------------------
-- 14. Calculate product-level P50 and P99 by category
--
-- P50 separates lower and upper halves.
-- P99 identifies the extreme long-tail group.
-- ------------------------------------------------------------

CREATE OR REPLACE TABLE driver_price_threshold_30 AS

SELECT
    category_code,

    QUANTILE_CONT(product_price, 0.50)
        AS p50_price,

    QUANTILE_CONT(product_price, 0.99)
        AS p99_price

FROM driver_product_price_30

GROUP BY category_code;


-- ------------------------------------------------------------
-- 15. Review extreme-price products
--
-- P99 is used as an investigation threshold.
-- A price above P99 is NOT automatically treated as an error.
-- ------------------------------------------------------------

SELECT
    p.category_code,
    p.product_id,
    p.product_price,
    t.p99_price,

    ROUND(
        p.product_price
        / NULLIF(t.p99_price, 0),
        2
    ) AS price_vs_p99_multiple

FROM driver_product_price_30 AS p

JOIN driver_price_threshold_30 AS t
    ON p.category_code = t.category_code

WHERE p.product_price > t.p99_price

ORDER BY
    p.category_code,
    p.product_price DESC;


-- ============================================================
-- PART F — SESSION + PRODUCT FUNNEL ANALYSIS
-- ============================================================


-- ------------------------------------------------------------
-- 16. Sequence events within session + product
--
-- Price analysis uses:
--
-- session + product
--
-- because the question is whether product price groups show
-- different funnel behaviour.
-- ------------------------------------------------------------

CREATE OR REPLACE TABLE driver_product_event_sequence_30 AS

SELECT
    e.analytical_session_id,
    e.category_code,
    e.product_id,
    p.product_price,

    e.event_type,
    e.event_time_utc,
    e.source_event_id,

    ROW_NUMBER() OVER (
        PARTITION BY
            e.analytical_session_id,
            e.category_code,
            e.product_id
        ORDER BY
            e.event_time_utc,
            e.source_event_id
    ) AS product_event_sequence

FROM analysis_events_30 AS e

JOIN driver_product_price_30 AS p

    ON e.category_code = p.category_code
   AND e.product_id = p.product_id

WHERE e.category_code IN (
    'electronics.video.tv',
    'computers.peripherals.monitor'
);


-- ------------------------------------------------------------
-- 17. Collapse to one row per session + product
-- ------------------------------------------------------------

CREATE OR REPLACE TABLE session_product_funnel_30 AS

SELECT
    analytical_session_id,
    category_code,
    product_id,
    product_price,

    MAX(CASE
        WHEN event_type = 'view'
        THEN 1 ELSE 0
    END) AS has_view,

    MAX(CASE
        WHEN event_type = 'cart'
        THEN 1 ELSE 0
    END) AS has_cart,

    MIN(CASE
        WHEN event_type = 'view'
        THEN product_event_sequence
    END) AS first_view_sequence,

    MIN(CASE
        WHEN event_type = 'cart'
        THEN product_event_sequence
    END) AS first_cart_sequence,

    MIN(CASE
        WHEN event_type = 'purchase'
        THEN product_event_sequence
    END) AS first_purchase_sequence

FROM driver_product_event_sequence_30

GROUP BY
    analytical_session_id,
    category_code,
    product_id,
    product_price;


-- ------------------------------------------------------------
-- 18. Assign products to price bands
-- ------------------------------------------------------------

CREATE OR REPLACE TABLE session_product_price_band_30 AS

SELECT
    s.*,

    CASE
        WHEN s.product_price <= t.p50_price
            THEN '1. Lower half: <=P50'

        WHEN s.product_price <= t.p99_price
            THEN '2. Upper half: P50-P99'

        ELSE '3. Extreme: >P99'

    END AS price_band,

    CASE
        WHEN s.product_price <= t.p99_price
        THEN TRUE
        ELSE FALSE
    END AS include_main_comparison,

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
    END AS ordered_cart_to_purchase

FROM session_product_funnel_30 AS s

JOIN driver_price_threshold_30 AS t
    ON s.category_code = t.category_code;


-- ============================================================
-- PART G — PRICE DRIVER OUTPUT
-- ============================================================


-- ------------------------------------------------------------
-- 19. Power BI price-driver table
--
-- Store numerator and denominator rather than only the rate.
-- Power BI can then calculate weighted conversion correctly.
-- ------------------------------------------------------------

CREATE OR REPLACE TABLE pbi_price_driver_30 AS

SELECT
    category_code,
    price_band,
    include_main_comparison,

    'View to Cart' AS funnel_stage,

    SUM(ordered_view_to_cart)
        AS numerator_session_products,

    SUM(has_view)
        AS denominator_session_products,

    100.0
    * SUM(ordered_view_to_cart)
    / NULLIF(SUM(has_view), 0)
        AS conversion_rate_pct

FROM session_product_price_band_30

GROUP BY
    category_code,
    price_band,
    include_main_comparison


UNION ALL


SELECT
    category_code,
    price_band,
    include_main_comparison,

    'Cart to Purchase' AS funnel_stage,

    SUM(ordered_cart_to_purchase)
        AS numerator_session_products,

    SUM(has_cart)
        AS denominator_session_products,

    100.0
    * SUM(ordered_cart_to_purchase)
    / NULLIF(SUM(has_cart), 0)
        AS conversion_rate_pct

FROM session_product_price_band_30

GROUP BY
    category_code,
    price_band,
    include_main_comparison;


-- ------------------------------------------------------------
-- 20. Validate main price comparison
-- ------------------------------------------------------------

SELECT
    category_code,
    funnel_stage,
    price_band,

    numerator_session_products,
    denominator_session_products,

    ROUND(conversion_rate_pct, 2)
        AS conversion_rate_pct

FROM pbi_price_driver_30

WHERE include_main_comparison = TRUE

ORDER BY
    category_code,
    funnel_stage,
    price_band;


/*
Validated project results:

TV
---------------------------------------------------------
View-to-Cart
Lower half        545 / 11,799     = 4.62%
Upper half         56 /  5,556     = 1.01%

Cart-to-Purchase
Lower half        207 /    553     = 37.43%
Upper half         18 /     57     = 31.58%


Monitor
---------------------------------------------------------
View-to-Cart
Lower half        232 / 2,699      = 8.60%
Upper half        160 / 2,522      = 6.34%

Cart-to-Purchase
Lower half         91 /   236      = 38.56%
Upper half         55 /   164      = 33.54%


Interpretation:

Higher-priced groups were ASSOCIATED with weaker conversion
in both categories.

The strongest observed pattern was TV View-to-Cart.

This does NOT establish that higher price caused the gap.
*/
