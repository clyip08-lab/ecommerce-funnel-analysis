# Power BI Dashboard Design Notes

This document explains the design logic behind the Power BI dashboard used in the E-commerce Funnel Analysis project.

The dashboard was designed around a decision-making flow rather than around individual charts:

**What happened? → Where is the problem? → What may explain it? → How reliable is the evidence?**

---

## Dashboard Structure

The report contains four pages:

| Page | Main question | Purpose |
|---|---|---|
| Executive Overview | What is happening overall? | Summarise funnel performance and highlight the largest investigation priorities |
| Category Diagnosis | Where in the funnel is each category underperforming? | Compare category performance against relevant peers |
| Driver Deep Dive | What signals may help explain selected category gaps? | Explore price and brand patterns |
| Methodology & Data Quality | How reliable are the results? | Make assumptions, thresholds and limitations transparent |

The page order follows the way a decision-maker would normally consume the analysis:

**summary → diagnosis → investigation → evidence quality**

---

# Page 1 — Executive Overview

## Design objective

The first page was designed to answer three questions quickly:

**How large is the funnel?**

**Is performance improving or weakening?**

**Which categories deserve attention first?**

### KPI Cards

The page begins with four KPI cards:

- Total Sessions
- Purchase-session Rate
- Ordered View-to-Cart Rate
- Ordered Cart-to-Purchase Rate

Cards were used because these are high-level reference metrics rather than trends or comparisons.

They allow the reader to establish the scale and current overall funnel performance before interpreting the charts below.

### Why use line charts for monthly performance?

Line charts were selected because the analytical question concerns **change over time**.

The main trend chart contains:

- Purchase-session Rate
- Ordered View-to-Cart Rate

Both metrics operate on relatively similar percentage ranges, so their movement can be compared without heavily distorting the visual scale.

Cart-to-Purchase is displayed separately.

This was intentional because Cart-to-Purchase operates around 46–50%, while the other rates are approximately 4–9%.

Putting all three metrics on one shared axis would compress the lower-rate lines and make meaningful changes difficult to see.

A dual-axis chart was also avoided because two different scales can make unrelated movements appear visually comparable.

### Why use horizontal bar charts for opportunity rankings?

Horizontal bars were used for the category opportunity rankings because the question is:

**Which categories have the largest estimated gaps?**

Bar length makes magnitude easy to compare, while horizontal orientation leaves enough space for longer category names.

Only the largest reliable opportunities are displayed to reduce visual clutter.

The charts therefore function as a prioritisation view rather than a complete category report.

### Why separate the TV signal?

TV showed a large estimated opportunity gap, but the peer sample was below the reliability threshold.

Instead of mixing TV into the reliable Top 5 ranking, it was presented as a separate directional callout.

This preserves a potentially important signal without presenting weaker evidence as equally reliable.

---

# Page 2 — Category Diagnosis

## Design objective

The second page answers:

**Which funnel stage is responsible for each category's underperformance?**

A scatter plot was selected because each category has two independent peer-relative performance dimensions:

- View-to-Cart gap versus peers
- Cart-to-Purchase gap versus peers

A bar chart would rank only one dimension at a time.

The scatter plot allows both funnel stages to be diagnosed simultaneously.

## Why are the axes centred on zero?

Both axes show the category's rate minus its peer benchmark.

Therefore:

**0 = equal to peers**

Negative values indicate underperformance.

Positive values indicate performance above peers.

Constant reference lines at zero divide the chart into four analytical regions.

| Position | Interpretation |
|---|---|
| Left / Upper | Front-funnel weakness |
| Left / Lower | Both stages below peers |
| Right / Lower | Downstream weakness |
| Right / Upper | At or above peers |

This makes chart position itself meaningful.

For example:

- Cooler appears in the area where both funnel stages require attention.
- Monitor shows a much stronger downstream issue.
- Drill is approximately in line with peers at View-to-Cart but weaker downstream.
- Videocards is above peers at both stages.

### Why not make bubble size represent traffic?

Bubble size was intentionally kept fixed.

Using traffic as bubble size would combine two separate concepts:

- severity of the peer-relative rate gap
- business scale

This could make large categories appear analytically worse simply because they have more traffic.

Volume-based opportunity is therefore shown separately on Page 1.

### Why use tooltips?

The scatter plot needs to remain visually simple.

Detailed information such as:

- category rates
- peer rates
- viewing sessions
- cart sessions
- peer confidence

is therefore available through tooltips instead of being displayed permanently on the chart.

This follows a simple design principle:

**overview first, detail on demand**

### Why label only selected categories?

Labelling every category would create overlapping text and reduce readability.

Only categories that illustrate important analytical cases are labelled directly.

TV also carries an asterisk because its peer comparison is directional rather than fully reliable.

---

# Page 3 — Driver Deep Dive

## Design objective

The third page asks:

**What observable signals may help explain selected category gaps?**

The page focuses on TV and Monitor because both had useful brand coverage and sufficient driver-level evidence for further investigation.

## Why use a category slicer?

The same analytical framework applies to both TV and Monitor.

A category slicer allows the reader to switch between categories without creating separate pages.

This keeps the report compact and makes direct comparison easier.

The slicer is connected through a shared category dimension so that one selection filters both:

- price analysis
- brand analysis

## Why use separate price charts for View-to-Cart and Cart-to-Purchase?

Price may affect different stages differently.

Combining both funnel stages into one chart would make it harder to see whether the pattern is mainly:

- pre-cart
- post-cart
- or present at both stages

Separate charts preserve the distinction between funnel stages.

## Why compare Lower Half and Upper Half?

The price distribution contained a long tail with extreme values.

The main visual therefore compares:

- Lower half: <= P50
- Upper half: P50–P99

Products above P99 are retained in the data but excluded from the primary visual comparison because the extreme groups contain very small samples.

This avoids allowing a few extreme products to dominate the interpretation.

## Why use a grouped brand bar chart?

For selected brands, the analytical question is:

**How does the brand's conversion compare with the benchmark for other eligible brands in the same category?**

Displaying Brand Conversion Rate and Brand Peer Rate side by side makes the gap directly visible.

A funnel-stage slicer allows the same visual to switch between:

- View-to-Cart
- Cart-to-Purchase

### Why use Top N filtering?

Some categories contain many brands.

Displaying every brand would reduce readability and distract from the investigation objective.

The visual therefore focuses on selected underperforming brands with meaningful opportunity gaps.

## Why include the evidence statement at the bottom?

The page deliberately distinguishes:

**Observed association**

from

**Confirmed root cause**

The available data shows that higher-price groups and selected brands are associated with weaker conversion.

However, the dataset does not contain enough information to prove that price or brand caused the differences.

The evidence box prevents exploratory driver signals from being presented as causal conclusions.

---

# Page 4 — Methodology & Data Quality

## Design objective

The final page answers:

**Why should the reader trust the analysis, and what should they remain cautious about?**

Methodology and limitations were placed on a separate page so the executive pages could remain concise without hiding important analytical assumptions.

### Why use cards again?

Four numbers deserve immediate attention:

- Primary session count
- 60-minute sensitivity session count
- Known categories
- Unmapped category IDs

Cards make these high-level validation indicators easy to scan.

### Why show sample thresholds as a table?

The thresholds differ by funnel stage and analytical grain.

A table communicates the exact rule more clearly than a chart.

The dashboard explicitly states that these are practical stability thresholds rather than statistical significance tests.

### Why include data-quality metrics?

Incomplete mapping and missing brands directly affect which analyses can be trusted.

For example, brand missingness is low for TV and Monitor but substantially higher for Cooler and Videoregister.

Making this visible prevents the dashboard from implying equal evidence quality across all categories.

---

# Power BI Features Used

| Feature | How it was used | Why it was needed |
|---|---|---|
| DAX Measures | Funnel rates and driver conversion rates | Calculate ratios using the correct numerator and denominator |
| Dimension Tables | Shared category filtering | Allow one category selection to filter multiple fact tables |
| Relationships | Dimension-to-fact connections | Propagate filters consistently across visuals |
| Slicers | Category and funnel-stage selection | Allow interactive investigation without duplicating pages |
| Visual-level Filters | Reliable results, selected driver scope | Control what evidence appears in each visual |
| Top N Filters | Opportunity and brand rankings | Focus attention on the most relevant items |
| Scatter Plot | Category peer diagnosis | Show two funnel-stage gaps simultaneously |
| Constant Lines | Zero peer-gap reference | Define the four diagnostic regions |
| Tooltips | Category details | Provide detail without overcrowding the scatter plot |
| Data Labels | Opportunity and conversion values | Reduce the need to estimate values from axes |
| Cards | Executive KPIs and validation metrics | Highlight high-level reference values |
| Line Charts | Monthly funnel trends | Show change over time |
| Horizontal Bar Charts | Opportunity rankings | Compare magnitude across categories |

---

# Data Model Design

The dashboard uses several purpose-built analytical tables rather than importing only one large raw-event table.

Different tables operate at different grains:

| Table | Analytical grain |
|---|---|
| Monthly Funnel | Month |
| Category Peer | Category |
| Category Opportunity | Category × Funnel Stage |
| Price Driver | Category × Funnel Stage × Price Band |
| Brand Driver | Category × Funnel Stage × Brand |
| Data Quality | Validation Metric |

Shared dimension tables are used where multiple fact tables require the same filtering context.

For example:

`Dim Driver Category`

filters both:

`Price Driver`

and:

`Brand Driver`

through one-to-many relationships.

This avoids direct many-to-many relationships between fact tables and makes filter behaviour easier to control.

---

# Design Principle

The dashboard was not designed to maximise the number of visuals.

Each visual was selected based on the analytical question it needed to answer:

**Cards → current state**

**Lines → change over time**

**Bars → ranking and magnitude**

**Scatter → two-dimensional diagnosis**

**Slicers → interactive investigation**

**Tooltips → detail without clutter**

The goal was to create a report that supports a sequence of business decisions rather than simply display available metrics.
