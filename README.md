# E-commerce Funnel Diagnosis & Category Opportunity Prioritisation

**SQL · DuckDB · Power BI · Funnel Analysis · Peer Benchmarking**

An end-to-end e-commerce analytics case study that transforms **885K raw customer events** into reliable session-level funnel metrics, identifies where conversion friction occurs, and prioritises categories for further investigation.

## Dataset

This project uses the **eCommerce Events History in Electronics Store** dataset.

The raw dataset contains approximately **885K ecommerce events** covering:

- `view`
- `cart`
- `purchase`

Key fields include:

`event_time`, `event_type`, `product_id`, `category_id`, `category_code`, `brand`, `price`, `user_id`, and `user_session`.

The source data is event-level, where one row represents one observed user-product interaction rather than one customer, session or order.

**Source:** [eCommerce events history in electronics store — Kaggle](https://www.kaggle.com/datasets/mkechinov/ecommerce-events-history-in-electronics-store)

The raw dataset is not redistributed in this repository. The SQL scripts document the transformation from raw events to the analytical tables used in the case study.

## Business Question

**How can an e-commerce business identify where funnel performance is improving, where meaningful friction remains, and which categories should be investigated first?**

## Executive Summary

The analysis reconstructed **539,812 analytical sessions** from raw view, cart and purchase events and built ordered View-to-Cart and Cart-to-Purchase funnel metrics.

Key findings:

- Purchase-session rate increased from **4.19% to 5.30%**.
- Ordered View-to-Cart improved from **6.83% to 9.09%**.
- Ordered Cart-to-Purchase weakened from **49.67% to 46.28%**.
- Category peer benchmarking showed that low absolute conversion did **not always mean category-specific underperformance**.
- Opportunity prioritisation combined **performance gaps with denominator volume**, rather than ranking categories by conversion rate alone.
- Brand and price analysis identified investigation signals, but the available data was not sufficient to establish direct root causes.

![Executive Overview](images/executive_overview.png)


---

## Analytical Challenge

The raw event data could not be used directly for reliable funnel analysis.

Three analytical issues had to be addressed before interpreting conversion performance.

### 1. Raw session IDs were not sufficient for analysis

The supplied session identifiers could span unusually long periods or be reused. I therefore reconstructed analytical sessions using:

- `user_id`
- the original session ID
- a **30-minute inactivity rule**

This produced **539,812 analytical sessions**.

A **60-minute sensitivity check** produced **531,421 sessions**, only about **1.55% fewer**, indicating that the main conclusions were not highly sensitive to the session timeout assumption.

### 2. Event presence does not necessarily mean funnel progression

A session containing both a view and a cart does not automatically mean that the view happened before the cart.

I therefore defined **ordered funnel metrics** that required the observed events to occur in sequence:

`View → Cart → Purchase`

This reduced the risk of treating simple event co-occurrence as genuine funnel progression.

### 3. One site-wide benchmark could misclassify categories

Different product families can have naturally different customer journeys.

I therefore used two benchmark levels:

- **Weighted overall benchmark** — to understand site-level performance.
- **Leave-one-out category peer benchmark** — to compare each category with other categories in the same category family.

This helped distinguish true category-specific underperformance from broader category-family behaviour.

---

## Methodology

The analysis followed six main stages:

1. **Profile the raw event data**  
   Checked event types, date coverage, category mapping, missing values, brand coverage and price distributions.

2. **Reconstruct analytical sessions**  
   Applied the 30-minute inactivity rule and validated the result with a 60-minute sensitivity check.

3. **Define ordered funnel metrics**  
   Built session-level View-to-Cart, Cart-to-Purchase and Purchase-session metrics using event sequence.

4. **Analyse performance over time**  
   Compared monthly funnel performance to identify which stage was driving overall change.

5. **Benchmark and prioritise categories**  
   Compared categories with relevant peers and combined performance gaps with denominator volume to identify investigation priorities.

6. **Investigate possible drivers**  
   Analysed brand and price patterns for selected categories while keeping causal limitations explicit.

---

## Key Findings

### Finding 1 — Overall purchase performance improved

From October 2020 to February 2021:

| Metric | Oct 2020 | Feb 2021 | Change |
|---|---:|---:|---:|
| Purchase-session rate | 4.19% | **5.30%** | +1.11 pp |
| Ordered View-to-Cart | 6.83% | **9.09%** | +2.26 pp |
| Ordered Cart-to-Purchase | 49.67% | **46.28%** | -3.39 pp |

The improvement in purchase-session performance was primarily driven by stronger **View-to-Cart conversion**.

At the same time, **Cart-to-Purchase weakened**, indicating that the downstream stage was moving in the opposite direction.

This means the business should not interpret the overall improvement as evidence that every part of the funnel was improving.

---

### Finding 2 — Low absolute conversion did not always mean a category problem

A key example was **computers.components.videocards**.

Its Cart-to-Purchase rate was:

**40.98%**

Compared with the overall known-category benchmark of **46.77%**, this initially appeared weak.

However, when compared with other categories in the same computer-components peer group, videocards performed:

**+3.34 percentage points above peers**

This changed the interpretation.

A site-wide benchmark would have incorrectly flagged videocards as an underperforming category.

The peer benchmark showed that its lower absolute conversion reflected broader category-family behaviour rather than a category-specific problem.

![Category Diagnosis](images/category_diagnosis.png)
---

### Finding 3 — Different categories showed friction at different funnel stages

Peer-relative performance showed that category problems were not uniform.

| Category | View→Cart vs peers | Cart→Purchase vs peers | Diagnosis |
|---|---:|---:|---|
| Cooler | **-9.86 pp** | -6.01 pp | Strong front-funnel and downstream weakness |
| Monitor | -1.70 pp | **-13.85 pp** | Mainly downstream weakness |
| CPU | -1.98 pp | **-5.91 pp** | High downstream investigation priority |
| Drill | +0.15 pp | **-7.84 pp** | Downstream-specific weakness |
| Videocards | +7.50 pp | +3.34 pp | Above peers at both stages |

This showed that a single site-wide “conversion optimisation” strategy would not be appropriate.

For example:

- **Cooler** showed a particularly large View-to-Cart gap and also weaker downstream performance.
- **Monitor** was much closer to peers at View-to-Cart, but showed a much larger Cart-to-Purchase gap.
- **Drill** performed approximately in line with peers at View-to-Cart, while underperforming downstream.
- **Videocards** provided a useful positive reference because it outperformed its peer group at both stages.

The appropriate investigation therefore depends on **where in the funnel the category diverges from comparable peers**.

---

### Finding 4 — Business priority depended on both conversion gap and volume

Ranking categories by conversion rate alone can over-prioritise small categories with unstable or commercially limited impact.

I therefore combined:

**denominator volume × performance gap versus peers**

to estimate the size of the observed opportunity gap.

#### Largest reliable View-to-Cart opportunity gaps

| Category | Estimated cart-session gap |
|---|---:|
| Cooler | **609** |
| Motherboard | 406 |
| CPU | 291 |
| HDD | 175 |
| Mouse | 166 |

#### Largest reliable Cart-to-Purchase opportunity gaps

| Category | Estimated purchase-session gap |
|---|---:|
| CPU | **120** |
| Monitor | 49 |
| Acoustic audio | 44 |
| Drill | 26 |
| Videoregister | 24 |

This shifted the analysis from:

> “Which category has the lowest conversion rate?”

to:

> “Which category combines a meaningful performance gap with enough customer volume to justify investigation?”

These opportunity estimates are **mathematical prioritisation gaps**, not forecasts of guaranteed incremental carts or purchases.

A separate directional signal was retained for TV, where the estimated gaps were large but peer sample sizes were below the reliability thresholds.

---

## Driver Deep Dive — Price and Brand Signals

After identifying category-level gaps, I investigated whether product price and brand patterns could help explain selected opportunities.

TV and Monitor were chosen for deeper analysis because they had relatively strong driver-level data coverage compared with other priority categories.

### Price signals

Products were grouped into broader price bands for a more stable comparison:

- Lower half: `<= P50`
- Upper half: `P50–P99`

Extreme prices above P99 were retained for review but excluded from the main comparison because of limited sessions and potential price anomalies.

#### TV

| Funnel stage | Lower-price half | Upper-price half | Difference |
|---|---:|---:|---:|
| View→Cart | **4.62%** | **1.01%** | -3.61 pp |
| Cart→Purchase | **37.43%** | **31.58%** | -5.85 pp |

The strongest signal appeared in TV View-to-Cart, where higher-priced products converted substantially less often than lower-priced products.

#### Monitor

| Funnel stage | Lower-price half | Upper-price half | Difference |
|---|---:|---:|---:|
| View→Cart | **8.60%** | **6.34%** | -2.26 pp |
| Cart→Purchase | **38.56%** | **33.54%** | -5.02 pp |

Monitor showed weaker conversion in the higher-price group at both funnel stages.

However, these results show **association rather than causation**.

Higher price may also correlate with:

- product specifications
- brand mix
- customer intent
- inventory availability
- promotions
- shipping conditions

For this reason, the analysis does not conclude that price directly caused the conversion gaps.

---

### Brand signals

Brand-level peer comparisons provided additional investigation signals.

Examples included:

- **LG TV View→Cart:** 0.89% vs **4.35%** peer rate
- **Philips Monitor Cart→Purchase:** 32.14% vs **42.53%** peer rate

Selected brands underperformed comparable brands within the same category, but brand differences explained only part of the overall category-level opportunity.

The available data was not sufficient to determine whether the observed differences were driven by the brand itself or by associated factors such as product mix, price, inventory or customer preferences.

![Driver Deep Dive](images/driver_deep_dive.png)

---

### Evidence boundary

**Confirmed from the available data:**

- Higher-price groups were associated with weaker conversion in TV and Monitor.
- Selected brands showed measurable gaps versus category peers.

**Not confirmed:**

- Price directly caused the conversion gaps.
- Brand directly caused the conversion gaps.
- A specific operational or product issue was the root cause.

Additional data would be required to test these hypotheses reliably.
---

## Recommendations

The analysis supports **targeted follow-up investigation rather than immediate prescriptive actions**.

| Priority area | Recommended investigation |
|---|---|
| CPU | Check inventory availability, product compatibility information, delivery conditions and checkout friction |
| Cooler | Review assortment, price positioning and product-page quality |
| Monitor | Investigate downstream completion, price competitiveness and brand differences |
| TV | Validate high-price product positioning, promotions and value communication |
| Videoregister | Improve brand and category data coverage before deeper attribution |

These recommendations are investigation priorities rather than confirmed solutions because the available dataset does not contain enough information to establish root causes.

Additional data that would strengthen the diagnosis includes:

- inventory availability
- promotions and discounts
- shipping fees
- delivery lead time
- product-page completeness
- ratings and reviews
- checkout error events

---

## Data Quality & Limitations

Several data-quality constraints affected how the analysis was designed and interpreted.

### Category mapping

The dataset contained:

| Metric | Result |
|---|---:|
| Total category IDs | 718 |
| Known category IDs | 281 |
| Unmapped category IDs | 437 |
| Known business category codes | 107 |
| Unmapped category event rows | 236,172 |

Unmapped categories were retained in overall funnel metrics but excluded from named-category rankings.

### Brand coverage

Brand completeness varied significantly across categories:

| Category | Missing-brand rate |
|---|---:|
| TV | 2.42% |
| Monitor | 4.70% |
| Cooler | 22.34% |
| Videoregister | 35.43% |

This was one reason TV and Monitor were more suitable for brand-level deep dives, while conclusions for Cooler and Videoregister required greater caution.

### Sample-size thresholds

Practical minimum sample thresholds were applied to reduce unstable comparisons:

| Analysis | Minimum sample |
|---|---:|
| Category View-to-Cart | 2,643 viewing sessions |
| Category Cart-to-Purchase | 196 cart sessions |
| Brand View-to-Cart | 150 viewing sessions |
| Brand Cart-to-Purchase | 30 cart sessions |

These thresholds are **practical stability rules based on the observed sample distributions**, not statistical significance tests.

### Evidence limitations

The dataset did not contain:

- order IDs or quantities
- inventory status
- promotions or discounts
- shipping fees or delivery promises
- product-page quality measures
- checkout-error events

Purchase events therefore represent **observed purchase activity rather than confirmed order volume**.

Brand and price results should be interpreted as **association and investigation signals rather than causal proof**.

![Methodology and Data Quality](images/methodology_data_quality.png)

---

## Dashboard Structure

The Power BI report contains four pages:

1. **Executive Overview**  
   Overall funnel performance, monthly trends and category opportunity priorities.

2. **Category Diagnosis**  
   Peer-relative View-to-Cart and Cart-to-Purchase performance used to identify which funnel stage requires attention.

3. **Driver Deep Dive**  
   Price and brand investigation signals for TV and Monitor.

4. **Methodology & Data Quality**  
   Session reconstruction, sample thresholds, validation checks and evidence limitations.

---

## Technical Implementation

### Tools

- **DuckDB / SQL** — data profiling, session reconstruction, funnel calculation, category benchmarking and driver analysis
- **Power BI / DAX** — KPI measures, visual-level filters, slicers, relationships and interactive dashboard design
- **GitHub** — project documentation and reproducible analysis structure

### Analytical grain

The analysis moved through several levels of grain depending on the business question:

`Event → Session → Session + Category → Session + Brand / Product`

Using the correct grain helped avoid misleading results caused by repeated raw events or inappropriate denominators.

### Key analytical techniques

- inactivity-based session reconstruction
- SQL window functions
- ordered funnel metrics
- weighted benchmarks
- leave-one-out peer benchmarks
- sample-size thresholds
- sensitivity checks
- opportunity-gap prioritisation
- brand and price segmentation
- Power BI DAX measures and dimensional filtering

---

## Outcome

Built an end-to-end analytical framework that transformed approximately **885K raw ecommerce events** into reliable funnel metrics, identified category-specific versus peer-group performance patterns, prioritised investigation opportunities, and translated the findings into an interactive Power BI decision dashboard.

The project demonstrates the ability to move from:

**raw data → metric design → validation → diagnosis → prioritisation → business communication**

rather than simply producing descriptive charts.


---

## Repository Guide

### SQL Analysis

The SQL workflow follows the analytical process from raw-data validation to Power BI outputs:

| File | Purpose |
|---|---|
| [`01_data_profiling.sql`](sql/01_data_profiling.sql) | Profile raw events, missing values, category mapping and price distributions |
| [`02_session_reconstruction.sql`](sql/02_session_reconstruction.sql) | Reconstruct 30-minute analytical sessions and perform the 60-minute sensitivity check |
| [`03_funnel_metrics.sql`](sql/03_funnel_metrics.sql) | Build session-level ordered funnel metrics |
| [`04_time_trend_analysis.sql`](sql/04_time_trend_analysis.sql) | Analyse monthly funnel performance |
| [`05_category_peer_analysis.sql`](sql/05_category_peer_analysis.sql) | Build peer benchmarks and prioritise category opportunity gaps |
| [`06_brand_price_drivers.sql`](sql/06_brand_price_drivers.sql) | Investigate brand and price signals |
| [`07_powerbi_output_tables.sql`](sql/07_powerbi_output_tables.sql) | Build and validate Power BI semantic output tables |

### Documentation

- [Detailed Methodology](docs/methodology.md) — session rules, funnel definitions, peer benchmarking, thresholds and evidence boundaries
- [Data Dictionary](docs/data_dictionary.md) — definitions of key raw, derived and Power BI fields
- [Power BI Design Notes](powerbi/README.md) — why each chart, layout and Power BI feature was selected

### Dashboard Pages

- [Executive Overview](images/executive_overview.png)
- [Category Diagnosis](images/category_diagnosis.png)
- [Driver Deep Dive](images/driver_deep_dive.png)
- [Methodology & Data Quality](images/methodology_data_quality.png)
