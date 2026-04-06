---
editor_options: 
  markdown: 
    wrap: 72
---

# Study Results: Disease Prevalence Estimation in England

## Executive Summary

This analysis compared five methods for estimating coronary heart
disease (CHD) prevalence at LSOA level across England (n = 32,844 LSOAs,
56.5M population). **Method choice critically depends on deployment
context.**

**For new regions:** Age-sex-IMD standardisation (ρ = 0.519) is
optimal—simple, transparent, and generalisable.

**For infilling within existing regions:** Hierarchical models (ρ =
0.848) substantially outperform, but **gains do not transfer to new
geography** (ρ = 0.417 under geographic blocking).

------------------------------------------------------------------------

## Validation Performance

### Primary Metric: Spearman Rank Correlation

Ranking agreement is the critical metric for identifying high-need areas
for site planning.

```         
Method 1A: Crude                     ρ = 0.415  [lowest]
Method 1B: Age-Sex Standardised      ρ = 0.464
Method 1C: Age-Sex-IMD Standardised  ρ = 0.519  ⭐ Best for new regions
Method 2A: Hierarchical (Random CV)  ρ = 0.848  ⭐⭐ Best for infilling
Method 2B: Hierarchical (LAD-Block)  ρ = 0.417  [does not generalise]
```

**Key insight:** The 0.431 performance drop between random and
region-blocked CV (51% reduction) reveals **spatial leakage**—the
hierarchical model memorises regional patterns rather than learning
generalisable demographic relationships.

------------------------------------------------------------------------

## High-Need Area Identification

For operational relevance, we assessed each method's ability to
correctly identify the **top 10% of LSOAs by observed CHD burden**
(metric: % of true high-need areas captured).

| Method                            | Capture Rate |
|-----------------------------------|--------------|
| 1A: Crude                         | 43.0%        |
| 1B: Age-Sex Std                   | 39.8%        |
| 1C: Age-Sex-IMD Std               | 42.3%        |
| **2A: Hierarchical (Random CV)**  | **69.5%** ✅ |
| 2B: Hierarchical (LAD-Blocked CV) | 42.7%        |

**Interpretation:** - Within regions with existing data, hierarchical
models identify \~70% of true priority LSOAs - For new regions,
hierarchical models collapse to 43%—equivalent to crude methods -
**Simple methods perform similarly on highest-burden areas** (39–43%),
suggesting demographic adjustment improves overall ranking but not
extreme value identification

------------------------------------------------------------------------

## Prevalence Estimates: Summary Statistics

### Observed (GP-Derived) Validation Data

-   **number of LSOAs:** 32,844
-   **Mean prevalence:** 3.23%
-   **Range:** 0.03–10.29%
-   **SD:** 1.42%

### Method Performance: Mean Prevalence & Distribution

| Method           | Mean  | Median | Range       | SD   |
|------------------|-------|--------|-------------|------|
| Observed (GP)    | 3.23% | 2.98%  | 0.03–10.29% | 1.42 |
| 1A: Crude        | 2.97% | 2.97%  | 2.97–2.97%  | 0.00 |
| 1B: Age-Sex      | 3.80% | 3.42%  | 0.07–15.34% | 1.09 |
| 1C: Age-Sex-IMD  | 3.73% | 3.44%  | 0.07–14.01% | 0.87 |
| 2A: Hierarchical | 3.20% | 3.16%  | 1.16–5.54%  | 0.59 |

**Observations:**

\- Among the exppected value models, **Method 1C (expected value
standardisation)** estimates are closest to the observed mean (3.73% vs
3.23%), but slightly overestimated.

\- **Method 2A (hierarchical, random CV)** achieves both accurate mean
(3.20%) and the best ranking (ρ = 0.848).

\- **Hierarchical model ranges are narrowest** (1.16–5.54%) — mostly
because it regresses extremes toward LAD means, which improves
prediction but masks true variation.

\- **Method 1A (crude)** produces constant 2.97% for all LSOAs — showing
zero geographic variation

------------------------------------------------------------------------

## Secondary Validation Metrics

### Concordance Correlation Coefficient (CCC)

Measures agreement between predicted and observed, combining correlation
and calibration.

| Method                     | CCC                                            |
|---------------------------|--------------------------------------------|
| 1A: Crude                  | 0.227                                          |
| 1B: Age-Sex                | 0.302                                          |
| 1C: Age-Sex-IMD            | **0.484** (best among standardisation methods) |
| 2A: Hierarchical           | 0.812                                          |
| 2B: Hierarchical (Blocked) | 0.218                                          |

### Mean Absolute Error (MAE) & Root Mean Squared Error (RMSE)

| Method                     | MAE      | RMSE     |
|----------------------------|----------|----------|
| 1A: Crude                  | 1.84     | 2.47     |
| 1B: Age-Sex                | 1.12     | 1.61     |
| 1C: Age-Sex-IMD            | 1.06     | 1.52     |
| **2A: Hierarchical**       | **0.63** | **0.94** |
| 2B: Hierarchical (Blocked) | 1.82     | 2.45     |

**Interpretation:** Hierarchical models with random CV show lowest
absolute error, but these gains vanish under geographic blocking —
indicating region-specific optimisation rather than generalisable
improvement.

------------------------------------------------------------------------

## Spatial Leakage Analysis

**Definition:** Performance inflation in random CV is due to spatial
autocorrelation (as the test and training sets share geographic
proximity).

### Sensitivity Analysis: Offset Comparison

We tested whether using age-sex-IMD standardised expected values as the
offset (rather than crude) would reduce spatial leakage.

| Offset Type | Random CV | LAD-Blocked CV | Spatial Leakage (drop) |
|------------------|------------------|------------------|-------------------|
| Crude + IMD predictor (main model) | 0.848 | 0.417 | **0.431 (severe)** |
| Std (no IMD) | 0.578 | 0.519 | 0.059 (minimal) |

**Finding:** Using standardised offset reduces spatial leakage from
0.431 to 0.059. However, even with this improvement: - Standardised
offset + hierarchical: ρ = 0.519 under blocking - Pure standardisation
(1C): ρ = 0.519 (equivalent)

**Conclusion:** For new regions, simple standardisation achieves the
same performance as hierarchical models at far lower complexity.

------------------------------------------------------------------------

## Interpretation: Why Methods Perform as They Do

### Age-Sex-IMD Standardisation (1C) ✅ Robust Foundation

Local CHD burden is substantially driven by demographic composition: -
Older populations → higher CHD - Higher male proportion → higher CHD\
- Greater deprivation (lower IMD rank) → higher CHD

By applying stratified national rates to local population structure,
Method 1C captures this variation **without statistical modelling**.
This transparency and simplicity make it ideal for new regions where
only population data and national rates are available.

### Hierarchical Models: Excellent Within-Region, Poor Across-Region

Under random LSOA CV, the model encounters test LSOAs in LADs where it
has already learned from 90% of other LSOAs. LAD-level random effects
transfer perfectly to nearby held-out areas.

Under LAD-blocked CV, unseen LADs receive u_LAD = 0 (population
average), leaving only crude offset + IMD term. This is a weaker
strategy than embedding demographics in the offset from the start.

**Formula revealing the problem:**

```         
Random CV: log(μ) = log(crude) + β·IMD + u_LAD(learned LAD patterns)
LAD-Blocked CV: log(μ) = log(crude) + β·IMD + 0   [u_LAD unavailable]
                        = crude estimate + IMD adjustment (weaker than standardisation)

vs.

Method 1C: Direct stratification embeds age, sex, AND IMD simultaneously
```

------------------------------------------------------------------------

## Recommendations by Deployment Scenario

### Scenario 1: Infilling Within Existing Regions

**Context:** Dark Peak expanding coverage in LADs where 50–80% of LSOAs
already have GP data.

**Method:** Hierarchical (Method 2A, random LSOA CV) - **Spearman ρ:**
0.848 - **Top 10% capture:** 69.5% - **Rationale:** Can learn
LAD-specific patterns; excellent ranking agreement - **Implementation:**
Fit GLMM with LAD random intercepts; use for interpolation only within
known LADs

### Scenario 2: Expanding to New Regions

**Context:** Dark Peak entering new geographic market (e.g., new county)
with minimal or no GP data.

**Method:** Age-Sex-IMD Standardisation (Method 1C) - **Spearman ρ:**
0.519 - **Top 10% capture:** 42.3% - **Rationale:** Simple, transparent,
truly generalisable - **Avoid:** Hierarchical models (ρ collapses to
0.417) - **Implementation:** Apply stratified national prevalence rates;
requires only ONS population data + IMD ranks + national rates

### Scenario 3: Mixed Geography (Some Regions Covered, Some New)

**Hybrid approach:** 1. Use hierarchical models for LADs with existing
GP data coverage ≥ 50% 2. Use standardisation for LADs with \< 50%
coverage or new regions 3. Combine predictions transparently; document
which method was used where

------------------------------------------------------------------------

## High-Need Area Identification: Caveats

While the random CV hierarchical model identifies 69.5% of true
high-burden LSOAs: - **30.5% of priority areas are missed** - For
critical site planning decisions, this error rate may be unacceptable

**Recommended approach:** Combine prevalence estimates with: - Existing
service provision & catchment capacity - Travel time / transport
access - Patient feedback & unmet need surveys - Deprivation indices
(IMD) - Local health intelligence

Prevalence alone should not determine site locations.

------------------------------------------------------------------------

## Study Limitations

### 1. Validation Data Quality

-   **GP QOF data** may underestimate true prevalence (under-diagnosis,
    recording variation)
-   **GP-to-LSOA crosswalk** introduces minor imprecision (though
    affects all methods equally)

### 2. Disease-Specific

-   Results focus on CHD; other conditions have different
    age/sex/deprivation gradients
-   Hierarchical findings may not generalise to conditions with weaker
    deprivation signal

### 3. Temporal Inconsistencies

-   Population data: 2022–2025
-   National prevalence rates: 2019/2020
-   Validation (GP data): 2021/22
-   IMD: 2025 (previous: 2019)
-   **COVID-19 impact:** May bias estimates (healthcare access,
    mortality)

### 4. Geographic Scope

-   Analysis restricted to England (Welsh LSOAs excluded due to
    different IMD methodology)

### 5. Model Assumptions

-   **Poisson model:** Assumes log-linear relationship; strong
    assumptions about expected value
-   **Offset term:** Assumes observed cases scale proportionally to
    expected—may not hold for rare diseases

------------------------------------------------------------------------

## Data & Code Availability

All analysis performed in **R 4.5.2** using: - `lme4` (v1.1.38) –
hierarchical models - `caret` (v7.0.1) – cross-validation - `tidyverse`
(data manipulation) - `sf` (geospatial)

**Reproducibility:** Exact package versions locked in `renv.lock`;
set.seed(123) for deterministic results.

**Input data:** All sources publicly available from ONS, NHS Digital,
CPRD.

------------------------------------------------------------------------

## Key Takeaways

| Finding | Implication |
|-------------------------------|-----------------------------------------|
| Age-sex-IMD standardisation (ρ=0.519) beats crude (ρ=0.415) | Deprivation materially drives local disease burden |
| Hierarchical (random CV) ρ=0.848 collapses to 0.417 (LAD-blocked) | Models learn geography, not just demography; spatial leakage is severe |
| Top 10% capture: 69.5% (hierarchical, random) vs 42.3% (standardisation) | Within-region gains are substantial; new-region performance is equivalent |
| Both ranking and calibration matter | MAE/RMSE don't predict generalisability; Spearman ρ + blocking are better tests |
| Standardised offset reduces leakage from 0.431 to 0.059 | Using stratified offset is good practice; still doesn't improve new-region performance |

------------------------------------------------------------------------

## Contact & Questions

For details on methodology, validation approach, or sensitivity
analyses, see `README_ANALYSIS.md`.

**Date:** February 2026\
