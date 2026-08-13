# Methodology

This document describes the analytical methodology used in the E-commerce Funnel Diagnosis project.

The objective was to build funnel metrics that were reproducible, interpretable and appropriate for the available event-level data.

---

## 1. Raw Data Grain

The original dataset contains approximately **885K ecommerce events**.

Each row represents an observed user-product event such as:

- `view`
- `cart`
- `purchase`

The raw grain is therefore:

**one event involving one product at one timestamp**

A raw row is not equivalent to:

- one customer
- one session
- one order
- one conversion

This distinction is important because directly dividing raw event counts can produce misleading funnel metrics.

---

## 2. Analytical Session Reconstruction

The original `user_session` identifier was not assumed to represent a reliable continuous browsing session.

Analytical sessions were reconstructed using:

- `user_id`
- original `user_session`
- event timestamp
- inactivity gap between consecutive events

A new analytical session begins when:

1. the event is the first event for that `user_id + original user_session` combination; or
2. the inactivity gap from the previous event **exceeds 30 minutes**.

Events separated by **30 minutes or less** remain in the same analytical session.

Crossing midnight alone does not force a new session because the analysis is intended to represent continuous browsing behaviour rather than calendar-day activity.

The primary 30-minute rule produced:

**539,812 analytical sessions**

### Deterministic ordering

When multiple events share the same timestamp, event ordering can become unstable if SQL has no secondary sort key.

A stable `source_event_id` was therefore retained and relevant window functions use:

`ORDER BY event_time_utc, source_event_id`

This ensures deterministic and reproducible technical ordering when timestamps are tied.

However, `source_event_id` is only a technical tie-breaker. It is **not treated as evidence of the true behavioural order of events occurring within the same recorded second**.

### Sensitivity test

The same sessionisation logic was repeated using a **60-minute inactivity threshold**, where a new session begins only when inactivity **exceeds 60 minutes**.

| Session rule | Sessions |
|---|---:|
| 30-minute primary rule | 539,812 |
| 60-minute sensitivity rule | 531,421 |

The difference was approximately **1.55%**.

The sensitivity test does not prove that 30 minutes is the only correct session definition. It shows that the main analytical session volume was not highly sensitive to a reasonable alternative threshold.

---

## 3. Funnel Definition

The primary funnel is:

**View → Cart → Purchase**

Metrics are calculated at session level rather than from raw event counts.

### Event-presence flags

For each analytical session, flags identify whether at least one observed event of each type occurred:

- `has_view`
- `has_cart`
- `has_purchase`

For example:

`has_cart = 1`

means that at least one cart event was observed in the session.

It does not mean that the session contained exactly one cart event.

---

## 4. Ordered Funnel Logic

Simple event co-occurrence is not sufficient to establish funnel progression.

For example, a session may contain:

`Cart → View → Purchase`

All three event types are present, but this does not represent an observed:

`View → Cart → Purchase`

sequence.

Funnel progression is therefore evaluated using the **earliest observed timestamp** for each funnel stage.

Because the source timestamps have second-level precision only, transitions recorded within the same second cannot be reliably ordered further. Same-second transitions are therefore retained as compatible with funnel progression.

### Ordered View-to-Cart

A session is counted when both stages are observed and:

`first_view_time <= first_cart_time`

### Ordered Cart-to-Purchase

A session is counted when both stages are observed and:

`first_cart_time <= first_purchase_time`

### Complete ordered funnel

A session is counted when:

`first_view_time <= first_cart_time <= first_purchase_time`

A same-second transition does not prove that the earlier funnel stage occurred first. It means that the available timestamp resolution cannot establish a conflicting order.

In the source data, 50 sessions had the same earliest View and Cart timestamp, while 1 session had the same earliest Cart and Purchase timestamp.

---

## 5. Core Funnel Metrics

The primary dashboard metrics are:

| Metric | Numerator | Denominator |
|---|---|---|
| Purchase-session Rate | Purchasing sessions | Total analytical sessions |
| Ordered View-to-Cart Rate | Sessions with ordered View→Cart | Viewing sessions |
| Ordered Cart-to-Purchase Rate | Sessions with ordered Cart→Purchase | Cart sessions |
| Complete Ordered Funnel Rate | Sessions with ordered View→Cart→Purchase | Viewing sessions |

Primary results:

| Metric | Result |
|---|---:|
| Total Sessions | 539,812 |
| Purchase-session Rate | 4.77% |
| Ordered View-to-Cart Rate | 7.96% |
| Ordered Cart-to-Purchase Rate | 48.20% |
| Complete Ordered Funnel Rate | 3.83% |

The denominator is chosen based on the funnel question rather than using raw event-row counts.

---

## 6. Monthly Trend Analysis

Monthly funnel performance is assigned using the analytical session start date.

September 2020 is retained in the data but treated as a partial month because the dataset begins on 24 September.

Direct trend comparisons therefore use the full-month period:

**October 2020 → February 2021**

| Metric | Oct 2020 | Feb 2021 | Change |
|---|---:|---:|---:|
| Purchase-session Rate | 4.19% | 5.30% | +1.11 pp |
| Ordered View-to-Cart | 6.83% | 9.09% | +2.26 pp |
| Ordered Cart-to-Purchase | 49.67% | 46.28% | -3.39 pp |

The trend shows that overall purchase-session performance improved from October to February. Over the same period, observed View-to-Cart progression strengthened substantially, while Cart-to-Purchase progression weakened.

These movements are descriptive associations and should not be interpreted as proof that the stronger View-to-Cart rate caused the higher purchase-session rate.

---

## 7. Category Analysis Grain

One analytical session may contain interactions with multiple product categories.

Category analysis therefore uses:

**session + category**

rather than assigning the entire session to only one category.

For named business-category analysis, `category_code` is used as the business-level category grain.

The data contains:

| Metric | Result |
|---|---:|
| Total category IDs | 718 |
| Known category IDs | 281 |
| Unmapped category IDs | 437 |
| Known business category codes | 107 |

Unmapped categories are retained in overall metrics but excluded from named-category rankings.

---

## 8. Site-Level Benchmarks

Weighted known-category benchmarks provide overall context.

The benchmark is calculated using:

**total numerator sessions ÷ total denominator sessions**

rather than averaging individual category conversion rates.

Overall known-category benchmarks were approximately:

| Metric | Weighted benchmark |
|---|---:|
| View-to-Cart | 9.35% |
| Cart-to-Purchase | 46.77% |

These benchmarks answer:

**How does a category compare with known-category performance overall?**

They are not always the best benchmark for determining whether a category-specific problem exists.

---

## 9. Category Peer Benchmarking

Different product families may naturally have different customer journeys.

To reduce inappropriate cross-category comparison, categories were also compared with categories in the same category family.

A **leave-one-out weighted peer benchmark** was used.

For each target category:

1. identify other categories in the same family;
2. exclude the target category itself;
3. aggregate the peer numerators and denominators;
4. calculate the weighted peer conversion rate.

The target is excluded so that it does not influence its own benchmark.

### Example: Videocards

| Comparison | Cart-to-Purchase |
|---|---:|
| Videocards | 40.98% |
| Site benchmark | 46.77% |
| Category-family peer benchmark | 37.64% |

Against the site benchmark, Videocards appears weak.

Against comparable peers:

**40.98% − 37.64% = +3.34 percentage points**

This changes the interpretation from apparent underperformance to above-peer performance.

---

## 10. Sample-Size Thresholds

Small denominators can produce unstable conversion rates.

Practical sample thresholds were therefore applied before treating comparisons as reliable.

| Analysis | Minimum sample |
|---|---:|
| Category View-to-Cart | 2,643 viewing sessions |
| Category Cart-to-Purchase | 196 cart sessions |
| Brand View-to-Cart | 150 viewing sessions |
| Brand Cart-to-Purchase | 30 cart sessions |

The category thresholds were derived from the stage-specific denominator distributions.

For View-to-Cart, the continuous 75th percentile of positive category viewing-session denominators was **2,642.5**, which was rounded upward to **2,643 viewing sessions**.

For Cart-to-Purchase, categories with zero Cart sessions were excluded because they do not have a usable Cart-to-Purchase denominator. The continuous 75th percentile among positive Cart denominators was **195.5**, rounded upward to **196 cart sessions**.

The brand thresholds of 150 viewing sessions and 30 cart sessions were used as practical minimum-volume filters for the deeper brand analysis.
These thresholds are:

**practical stability rules**

They are not:

**formal statistical significance tests**

A category exceeding the threshold is not automatically performing well; it simply has enough observations to support a more stable comparison.

---

## 11. Opportunity Prioritisation

Conversion rate alone was not used to rank business priorities.

A low-rate category may have very little traffic, while a smaller performance gap in a high-volume category may represent a larger investigation opportunity.

Opportunity size is calculated as:

**denominator sessions × (peer rate − category rate)**

when the category performs below peers.

For example, if a category has:

- 6,000 viewing sessions
- 5% View-to-Cart
- 10% peer View-to-Cart

the mathematical opportunity gap would be approximately:

`6,000 × (10% − 5%) = 300`

This should be interpreted as a **mathematical peer-relative gap used for prioritisation**.

It answers:

**How large is the observed performance gap when expressed in session-volume terms?**

It does not predict that the calculated number of additional carts or purchases will actually be generated in the future.

Reliable and directional results are kept separate when peer sample sizes differ in quality.

---

## 12. Brand Analysis

Brand analysis uses the grain:

**session + category + brand**

Missing brand values are quantified during data-quality profiling but excluded from named-brand peer comparisons.
Brand completeness differed substantially across priority categories:

| Category | Missing-brand rate |
|---|---:|
| CPU | 0.04% |
| TV | 2.42% |
| Monitor | 4.70% |
| Cooler | 22.34% |
| Videoregister | 35.43% |

Leave-one-out brand peer benchmarks were used where sufficient eligible brands existed.

CPU had excellent brand completeness but only two eligible brands at the required sample thresholds.

After excluding the target brand, only one eligible peer remained.

CPU was therefore not used for the final brand-comparison deep dive despite being an important category-level opportunity.

This illustrates an important distinction:

**business priority does not automatically imply sufficient evidence for deeper driver analysis.**

---

## 13. Price Analysis

Price analysis uses two analytical grains:

1. **product-level price grain** to define category-specific price thresholds and assign each product to a price band;
2. **session + category + price-band grain** to calculate funnel performance.

The selected categories for the final price deep dive were TV and Monitor.

Each product in these categories had only one observed positive price in the dataset.

Therefore the analysis cannot estimate the effect of changing the price of the same product over time.

It can only compare conversion patterns between different product price groups.

### Price bands

Product-level price percentiles were used:

- Lower: `price <= P50`
- Upper: `P50 < price <= P99`
- Extreme: `price > P99`

Price thresholds were calculated at **product level rather than event-row level** so that frequently viewed products did not receive disproportionate weight in the price distribution.

For example, the TV event-level median price was 191.67, while the product-level median was 300.56, demonstrating how event frequency can materially change the observed price distribution.

The extreme group is retained for transparency but excluded from the primary visual comparison because of very small samples and potential price anomalies.

A price above P99 is not automatically classified as erroneous.

### Main observed pattern

TV:

| Funnel stage | Lower half | Upper half |
|---|---:|---:|
| View-to-Cart | 4.62% | 1.01% |
| Cart-to-Purchase | 37.43% | 31.58% |

Monitor:

| Funnel stage | Lower half | Upper half |
|---|---:|---:|
| View-to-Cart | 8.60% | 6.34% |
| Cart-to-Purchase | 38.56% | 33.54% |

Higher-priced groups were associated with weaker conversion in both categories.

This is an association, not evidence that higher prices caused lower conversion.

---

## 14. Evidence Boundary

The available event dataset supports:

- observed funnel progression
- performance comparisons
- peer-relative gaps
- volume-adjusted opportunity prioritisation
- brand and price associations

It does not directly contain:

- order IDs
- quantities
- inventory availability
- promotions
- shipping fees
- delivery promises
- product-page quality
- checkout errors

Therefore the project distinguishes between:

**diagnosis**

and:

**confirmed root cause**

Price and brand findings are treated as investigation signals rather than causal explanations.

The project therefore uses the term **driver deep dive** as a structured hypothesis-narrowing exercise rather than as proof of causal drivers.
---

## 15. Power BI Semantic Layer

SQL prepares purpose-built analytical tables before visualisation.

The Power BI model uses separate tables at appropriate grains:

| Table | Grain |
|---|---|
| `pbi_monthly_funnel_30` | Month |
| `pbi_category_peer_30` | Category |
| `pbi_category_opportunity_30` | Category × Funnel Stage |
| `pbi_price_driver_30` | Category × Funnel Stage × Price Band |
| `pbi_brand_driver_30` | Category × Funnel Stage × Brand |
| `pbi_data_quality_30` | Validation Metric |

This reduces the risk of accidental double counting and keeps analytical logic separate from presentation logic.

Power BI is then used for:

- measures
- relationships
- slicers
- filtering
- tooltips
- rankings
- interactive visualisation

rather than rebuilding the entire analytical pipeline inside the dashboard.
