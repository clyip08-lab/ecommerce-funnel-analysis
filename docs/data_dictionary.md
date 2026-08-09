# Data Dictionary

This document defines the main raw, derived and Power BI output fields used in the E-commerce Funnel Diagnosis project.

The analytical model contains multiple grains, so field meaning should always be interpreted together with the table in which the field appears.

---

## 1. Raw Event Fields

Source table: `raw_events`

Raw grain:

**one observed user-product event at one timestamp**

| Field | Definition |
|---|---|
| `event_time` | Original event timestamp from the source dataset |
| `event_type` | Observed customer event: `view`, `cart` or `purchase` |
| `product_id` | Product identifier |
| `category_id` | Raw category identifier |
| `category_code` | Hierarchical business category label when available |
| `brand` | Product brand when available |
| `price` | Observed product price |
| `user_id` | User identifier |
| `user_session` | Session identifier supplied by the raw dataset |

### Important note on `user_session`

The raw `user_session` field is not treated as the final analytical session.

It is combined with:

- `user_id`
- event timing
- inactivity rules

to construct a new `analytical_session_id`.

---

## 2. Clean Event Fields

Main table: `events_clean`

| Field | Definition |
|---|---|
| `source_event_id` | Stable source-row identifier used as a deterministic tie-breaker when timestamps are identical |
| `event_time_utc` | Parsed event timestamp used in analysis |
| `product_id` | Product identifier stored as text |
| `category_id` | Category identifier stored as text |
| `category_code` | Cleaned category code; blank values converted to null |
| `brand` | Cleaned brand value; blank values converted to null |
| `price` | Product price converted to numeric format |
| `user_id` | User identifier stored as text |
| `user_session` | Original raw session identifier |

Rows without usable `user_id`, `user_session` or event timestamp are excluded from analytical session reconstruction.

---

## 3. Analytical Session Fields

Main table: `analysis_events_30`

Grain:

**one event inside one reconstructed analytical session**

| Field | Definition |
|---|---|
| `previous_event_time` | Previous event timestamp within the same user and raw session |
| `new_session_flag` | `1` when the event starts a new analytical session, otherwise `0` |
| `analytical_session_number` | Sequential session number created using the cumulative sum of session-start flags |
| `analytical_session_id` | Reconstructed session identifier combining user, raw session and analytical session number |

### Primary session rule

A new analytical session starts when:

- the event is the first event in the user-session combination;
- the calendar date changes; or
- inactivity is at least 30 minutes.

The primary rule produced:

**539,812 analytical sessions**

A 60-minute sensitivity version produced:

**531,421 sessions**

---

## 4. Session Funnel Fields

Main tables:

- `session_summary_30`
- `session_funnel_30`

Grain:

**one row per analytical session**

| Field | Definition |
|---|---|
| `session_start_time` | Earliest observed event timestamp in the analytical session |
| `session_end_time` | Latest observed event timestamp in the analytical session |
| `has_view` | `1` if at least one view event was observed in the session |
| `has_cart` | `1` if at least one cart event was observed |
| `has_purchase` | `1` if at least one purchase event was observed |
| `first_view_sequence` | Sequence position of the first observed view |
| `first_cart_sequence` | Sequence position of the first observed cart |
| `first_purchase_sequence` | Sequence position of the first observed purchase |
| `ordered_view_to_cart` | `1` when the first view occurs before the first cart |
| `ordered_cart_to_purchase` | `1` when the first cart occurs before the first purchase |
| `complete_ordered_funnel` | `1` when View → Cart → Purchase is observed in sequence |

### Important distinction

`has_cart = 1`

means:

**at least one cart event occurred**

It does not mean:

**exactly one cart event occurred**

Likewise, `ordered_view_to_cart = 1` indicates observed event order rather than the number of carts.

---

## 5. Monthly Funnel Fields

Power BI table:

`pbi_monthly_funnel_30`

Grain:

**one row per month**

| Field | Definition |
|---|---|
| `month_start` | First day of the month used as the monthly period key |
| `total_sessions` | Number of analytical sessions starting in the month |
| `viewing_sessions` | Sessions containing at least one view |
| `cart_sessions` | Sessions containing at least one cart |
| `purchasing_sessions` | Sessions containing at least one purchase |
| `ordered_view_to_cart_sessions` | Sessions with observed View → Cart progression |
| `ordered_cart_to_purchase_sessions` | Sessions with observed Cart → Purchase progression |
| `complete_ordered_funnel_sessions` | Sessions with complete observed View → Cart → Purchase progression |
| `purchase_session_rate_pct` | Purchasing sessions ÷ total sessions × 100 |
| `ordered_view_to_cart_rate_pct` | Ordered View→Cart sessions ÷ viewing sessions × 100 |
| `ordered_cart_to_purchase_rate_pct` | Ordered Cart→Purchase sessions ÷ cart sessions × 100 |
| `complete_ordered_funnel_rate_pct` | Complete ordered funnel sessions ÷ viewing sessions × 100 |
| `is_partial_month` | Indicates whether the dataset contains only part of the month |

### Percentage storage

SQL percentage fields ending in `_pct` are generally stored on a:

**0–100 scale**

For example:

`46.77`

means:

`46.77%`

not:

`0.4677`

This is why some Power BI DAX measures divide the SQL value by 100 before applying percentage formatting.

---

## 6. Category Performance Fields

Main tables:

- `category_performance_30`
- `pbi_category_peer_30`

Primary grain:

**one row per known business category code**

| Field | Definition |
|---|---|
| `category_code` | Named hierarchical business category |
| `category_family` | Comparable peer family derived from the higher category hierarchy |
| `viewing_sessions` | Session-category observations containing a view |
| `cart_sessions` | Session-category observations containing a cart |
| `purchasing_sessions` | Session-category observations containing a purchase |
| `ordered_view_to_cart_sessions` | Ordered View→Cart session-category observations |
| `ordered_cart_to_purchase_sessions` | Ordered Cart→Purchase session-category observations |
| `view_to_cart_rate_pct` | Category ordered View→Cart rate |
| `cart_to_purchase_rate_pct` | Category ordered Cart→Purchase rate |

A single analytical session can interact with multiple categories.

Therefore category analysis uses:

**session + category**

rather than forcing each session into one category.

---

## 7. Peer Benchmark Fields

Main table:

`pbi_category_peer_30`

| Field | Definition |
|---|---|
| `peer_category_count` | Number of other eligible categories contributing to the category's peer benchmark |
| `peer_viewing_sessions` | Total viewing denominator from peer categories |
| `peer_cart_sessions` | Total cart denominator from peer categories |
| `peer_view_to_cart_rate_pct` | Weighted View→Cart rate of other categories in the same peer family |
| `peer_cart_to_purchase_rate_pct` | Weighted Cart→Purchase rate of other categories in the same peer family |
| `view_to_cart_gap_pp` | Category View→Cart rate minus peer View→Cart rate |
| `cart_to_purchase_gap_pp` | Category Cart→Purchase rate minus peer Cart→Purchase rate |
| `view_to_cart_peer_confidence` | Reliability classification for the View→Cart comparison |
| `cart_to_purchase_peer_confidence` | Reliability classification for the Cart→Purchase comparison |
| `performance_classification` | Overall peer-relative funnel classification |

### Interpreting rate gaps

Example:

`view_to_cart_gap_pp = -5`

means:

**the category performs 5 percentage points below its peer benchmark**

A positive value means performance is above peers.

`pp` means:

**percentage points**

and should not be interpreted as relative percentage change.

---

## 8. Peer Confidence Values

Peer comparisons may be classified as:

| Value | Meaning |
|---|---|
| `Reliable` | Target and peer denominators satisfy the practical sample threshold |
| `Directional` | A comparison exists, but the denominator is below the preferred reliability threshold |
| `Insufficient peers` | There are not enough comparable peer categories to build a useful benchmark |

The sample thresholds improve practical stability but do not represent formal statistical significance tests.

---

## 9. Performance Classification

Field:

`performance_classification`

| Value | Interpretation |
|---|---|
| `Both stages below peers` | View→Cart and Cart→Purchase are both below peer benchmarks |
| `Front funnel below peers` | View→Cart is below peers while Cart→Purchase is at or above peers |
| `Downstream below peers` | View→Cart is at or above peers while Cart→Purchase is below peers |
| `At / above peers` | Both funnel stages are at or above peer benchmarks |
| `Insufficient peer comparison` | Peer comparison cannot be interpreted reliably |

These classifications are used in the Power BI category diagnosis scatter plot.

---

## 10. Category Opportunity Fields

Power BI table:

`pbi_category_opportunity_30`

Grain:

**category × funnel stage**

| Field | Definition |
|---|---|
| `category_code` | Business category |
| `category_family` | Peer family |
| `funnel_stage` | `View to Cart` or `Cart to Purchase` |
| `denominator_sessions` | Relevant denominator for the funnel stage |
| `category_rate_pct` | Actual category conversion rate |
| `peer_rate_pct` | Weighted leave-one-out peer conversion rate |
| `rate_gap_pp` | Peer rate minus actual category rate for opportunity sizing |
| `opportunity_gap_sessions` | Estimated session gap if the category mathematically reached the peer rate |
| `peer_confidence` | Reliability classification for the opportunity estimate |

### Opportunity gap formula

When the category performs below peers:

`denominator × (peer rate − category rate)`

Example:

`6,000 × (15% − 10%) = 300`

The result is an estimated mathematical gap used for prioritisation.

It is **not** a forecast of guaranteed incremental conversions.

---

## 11. Brand Driver Fields

Power BI table:

`pbi_brand_driver_30`

Grain:

**category × funnel stage × brand**

| Field | Definition |
|---|---|
| `brand_group` | Normalised brand name |
| `funnel_stage` | View-to-Cart or Cart-to-Purchase |
| `denominator_sessions` | Brand-level denominator for the funnel stage |
| `numerator_sessions` | Brand-level ordered progression count |
| `brand_rate_pct` | Actual brand conversion rate |
| `peer_rate_pct` | Weighted rate of other eligible brands in the same category |
| `gap_vs_peers_pp` | Brand rate minus peer rate |
| `opportunity_gap_sessions` | Mathematical gap versus the eligible brand peer benchmark |

Unknown or missing brand values are retained during profiling but excluded from reliable named-brand peer comparison.

---

## 12. Price Driver Fields

Power BI table:

`pbi_price_driver_30`

Grain:

**category × funnel stage × price band**

| Field | Definition |
|---|---|
| `price_band` | Product price group based on category-specific percentiles |
| `include_main_comparison` | Indicates whether the price band is included in the primary Power BI visual comparison |
| `funnel_stage` | View-to-Cart or Cart-to-Purchase |
| `numerator_session_products` | Ordered progression count at session-product grain |
| `denominator_session_products` | Relevant session-product denominator |
| `conversion_rate_pct` | Numerator ÷ denominator × 100 |

### Price bands

| Price band | Definition |
|---|---|
| `1. Lower half: <=P50` | Product price at or below category median |
| `2. Upper half: P50-P99` | Product price above median and at or below P99 |
| `3. Extreme: >P99` | Product price above the category-specific P99 |

The extreme group is retained in the data but excluded from the main visual comparison because the sample is very small.

---

## 13. Data Quality Fields

Power BI table:

`pbi_data_quality_30`

Grain:

**one row per validation metric**

| Field | Definition |
|---|---|
| `sort_order` | Display ordering for methodology and data-quality metrics |
| `metric_group` | Logical validation group |
| `metric_name` | Name of the data-quality or methodological metric |
| `metric_value` | Numeric value |
| `metric_unit` | Unit such as rows, sessions, IDs, categories or percent |

Examples include:

- raw event rows
- analysis event rows
- 30-minute sessions
- 60-minute sessions
- category mapping coverage
- missing-brand rates
- sample-size thresholds

---

## 14. Main Analytical Grains

The project deliberately uses different grains for different business questions.

| Analysis | Grain |
|---|---|
| Raw behaviour | Event |
| Overall funnel | Session |
| Monthly trend | Month |
| Category diagnosis | Session + Category |
| Category benchmark output | Category |
| Opportunity ranking | Category + Funnel Stage |
| Brand analysis | Session + Category + Brand |
| Price analysis | Session + Product |
| Price Power BI output | Category + Funnel Stage + Price Band |

The grain should always be identified before selecting the numerator, denominator or aggregation method.

Using the wrong grain can create duplicated counts or misleading conversion rates.
