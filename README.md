---
editor_options: 
  markdown: 
    wrap: 72
---

# Estimating Disease Prevalence in LSOAs in the UK

## Overview

This project compares multiple methods for estimating coronary heart
disease (CHD) prevalence at the Lower Layer Super Output Area (LSOA)
level in England, addressing a critical gap in UK public health data
infrastructure.

**Problem:** Accurate local disease prevalence estimates do not
currently exist in the UK, hindering evidence-based decisions about
healthcare site location, capacity planning, and resource allocation —
particularly in deprived areas with the greatest health burden.

**Solution:** We developed and validated five estimation methods ranging
from simple demographic standardisation to hierarchical statistical
models, tested against GP-level validation data across \~33,000 LSOAs
(56.5 million people).

**Key Finding:** Method choice depends critically on deployment context.
Age-sex-IMD standardisation performs best when expanding to new regions;
hierarchical models excel when infilling within regions with existing
data, but their gains do not generalise geographically.

------------------------------------------------------------------------

## Quick Start

### Prerequisites

-   R version 4.0.0 or higher
-   Git

### Installation

1.  **Clone the repository**

    ``` bash
    git clone https://github.com/dooparak-droid/Estimating-disease-prevalence-in-LSOAs-in-the-UK.git
    cd Estimating-disease-prevalence-in-LSOAs-in-the-UK
    ```

2.  **Restore exact package versions**

    ``` r
    renv::restore()
    ```

    This installs all dependencies at the versions used during
    development, ensuring reproducibility.

3.  **Run analysis scripts**

    ``` r
    source("scripts/standardization_calculation.R")
    ```

------------------------------------------------------------------------

## Methods Summary

### Five Estimation Approaches (Increasing Complexity)

#### **Method 1A: Crude Expected Value**

-   Applies national CHD prevalence to total LSOA population
-   **Formula:** E[Y] = N_i × p_national
-   **Assumption:** Homogeneous disease risk across England
-   **Performance:** ρ = 0.415 (poor)

#### **Method 1B: Age-Sex Standardisation**

-   Applies age-sex-stratified national rates to local population
    structure
-   **Formula:** E[Y] = Σ(N_i,a,s × p_a,s)
-   **Captures:** Demographic composition (age, sex)
-   **Ignores:** Deprivation effects
-   **Performance:** ρ = 0.464

#### **Method 1C: Age-Sex-IMD Standardisation** ⭐ *Recommended for new regions*

-   Applies fully stratified national rates (age × sex × IMD quintile)
-   **Formula:** E[Y] = Σ(N_i,a,s,d × p_a,s,d)
-   **Captures:** Demographic composition + socioeconomic gradients
-   **Key advantage:** Transparent, interpretable, no statistical
    modelling required
-   **Performance:** ρ = 0.519 \| Top 10% identification: 42.3%

#### **Method 2A: Hierarchical Model (Random LSOA CV)** ⭐ *Recommended for infilling within regions*

-   Poisson GLMM with LAD-level random intercepts
-   **Formula:** log(μ_i) = log(E[Y_i]) + β·IMD_i + u_LAD(i)
-   **Offset term:** Expected cases (smooths estimates for noisy data)
-   **Validation:** Random LSOA-level cross-validation (test & train
    share LAD membership)
-   **Simulates:** Gap-filling within regions with existing GP data
-   **Performance:** ρ = 0.848 \| Top 10% identification: 69.5%

#### **Method 2B: Hierarchical Model (LAD-Blocked CV)**

-   Same model structure as 2A, but entire LADs held out during
    validation
-   **Simulates:** Geographic expansion to entirely new regions without
    prior data
-   **Finding:** Performance collapses (ρ = 0.417)—reveals spatial
    leakage
-   **Implication:** Hierarchical models learn LAD-specific patterns,
    not generalisable relationships

### Critical Finding: Spatial Leakage

**Performance drop:** 0.431 (51% reduction from random to LAD-blocked
CV)

This massive gap reveals that the hierarchical model's apparent
excellence depends on learning regional patterns rather than demographic
relationships. When deploying to unseen LADs, it cannot generalise and
is outperformed by simple standardisation.

**Why this matters:** Random cross-validation inflates performance
estimates. LAD-blocked validation is the true test of geographic
generalisability.

------------------------------------------------------------------------

## Key Results

### Validation Performance (Primary Metric: Spearman Rank Correlation)

| Method | Spearman ρ | Top 10% Capture | Deployment Context |
|-----------------|-----------------|------------------|--------------------|
| 1A: Crude | 0.415 | 43.0% | ❌ Not recommended |
| 1B: Age-Sex Std | 0.464 | 39.8% | Limited use |
| **1C: Age-Sex-IMD Std** | **0.519** | **42.3%** | ✅ **New regions** |
| **2A: Hierarchical (Random CV)** | **0.848** | **69.5%** | ✅ **Infilling existing regions** |
| 2B: Hierarchical (LAD-Blocked CV) | 0.417 | 42.7% | ❌ Does not generalise |

### Prevalence Estimates (CHD in England, 2021–2022)

| Method             | Mean (%) | Range                     |
|--------------------|----------|---------------------------|
| Observed (GP data) | 3.23     | 0.03–10.29%               |
| 1A: Crude          | 2.97     | 2.97–2.97% (no variation) |
| 1B: Age-Sex        | 3.80     | 0.07–15.34%               |
| 1C: Age-Sex-IMD    | 3.73     | 0.07–14.01%               |
| 2A: Hierarchical   | 3.20     | 1.16–5.54%                |

**Note:** Among expected value models, Method 1C (expected value
standardisation) estimates are closer to the observed mean; hierarchical
models achieve better ranking but through learned regional effects, not
demographic generalisation.

------------------------------------------------------------------------

## Data Sources

All data sourced from 2021/22 where possible;

| Data | Source | Year |
|----------------------|----------------------------|----------------------|
| LSOA population (age × sex) | ONS mid-year estimates | 2022–2025 |
| IMD by LSOA | Ministry of Housing, Communities & Local Government | 2025 |
| CHD national prevalence (stratified) | Clinical Practice Research Datalink (Gutacker et al.) | 2019/2020 |
| CHD validation (GP prevalence) | NHS QOF + NHS Digital crosswalk | 2021/22 |
| LSOA boundaries | ONS geospatial data | 2021 |

------------------------------------------------------------------------

## Project Structure

```         
├── README.md                           # This file
├── README_ANALYSIS.md                  # Detailed methods & workflow
├── renv.lock                          # Exact package versions (reproducibility)
├── .Rprofile                          # Auto-loads renv environment
├── scripts/
│   ├── standardization_calculation.R   # Methods 1A, 1B, 1C (expected value)
│   ├── hierarchical_models.R           # Methods 2A, 2B (GLMMs)
│   ├── validation.R                    # Cross-validation & metrics
│   ├── sensitivity_analysis.R          # Offset comparison & robustness
│   └── visualization.R                 # Maps & figures
├── data/
│   ├── population_estimates_lsoa_2023.csv
│   ├── national_chd_prevalence_rates.csv
│   ├── imd_2025.xlsx
│   └── qof_gp_data_crosswalk.csv
└── results/
    ├── validation_performance.csv      # Table 2: method comparison
    ├── lsoa_estimates.rds              # Full LSOA-level predictions
    ├── spatial_leakage_analysis.csv    # Offset comparison (sensitivity)
    └── figures/
        ├── prevalence_maps_sheffield.pdf
        ├── validation_scatter_plots.pdf
        └── high_need_identification.pdf
```

------------------------------------------------------------------------

## Recommendations for Practice

### 1. **Match Method to Deployment Scenario**

**Scenario A: Infilling within regions with existing GP data** -
**Use:** Hierarchical model (Method 2A, random CV) - **Rationale:** Can
learn local patterns, achieves ρ = 0.848 - **Example:** Dark Peak
expanding coverage in LADs with 70% existing data

**Scenario B: Expanding to entirely new geographic regions** - **Use:**
Age-sex-IMD standardisation (Method 1C) - **Rationale:** Simple,
transparent, generalises (ρ = 0.519) - **Avoid:** Hierarchical models
(they collapse to ρ = 0.417) - **Example:** Dark Peak entering new
market region with no prior data

### 2. **Prioritise High-Quality Demographic Data**

The progression from crude (ρ = 0.415) to age-sex-IMD standardisation (ρ
= 0.519) shows deprivation materially drives local CHD burden. Ensure
your tool has: - Single-year age counts by sex (not age groups) -
Current IMD ranks (IMD 2025 now available) - Stratified national
prevalence rates for target diseases

### 3. **Top 10% High-Need Area Identification**

For site planning decisions, note the performance gap: - Hierarchical
model (infilling): 69.5% of true high-burden LSOAs identified - Simple
methods: \~42% - **Implication:** Combine prevalence estimates with
other data (service provision, travel time, patient feedback) before
final decisions

------------------------------------------------------------------------

## Limitations

1.  **Validation against GP data:** QOF may underestimate true
    prevalence (under-diagnosis, under-recording)
2.  **Disease-specific:** Results focus on CHD; age/sex/deprivation
    gradients differ for other conditions
3.  **Temporal inconsistencies:** Data sources span 2019–2025; COVID-19
    may introduce bias
4.  **Top 10% error rate:** Even the best model misses \~30% of truly
    high-need areas
5.  **Spatial leakage:** Hierarchical models learn geography, not just
    demography—critical for generalisability

------------------------------------------------------------------------

## Reproducibility

This project uses `renv` to lock exact package versions, ensuring
reproducible results across time and machines.

**To reproduce:**

``` r
# Open project in R
setwd("path/to/project")

# Restore exact environment
renv::restore()

# Run analysis
source("scripts/standardization_calculation.R")
source("scripts/hierarchical_models.R")
```

All random seeds are set for deterministic results. Output should match
published results exactly.

------------------------------------------------------------------------

## Citation

If you use this work, please cite:

```         
Oparaku, E., Abbas, H., McCloskey, B., Razmi, R., & Latimer, L. (2026). 
Comparing Methods for Estimating Local Disease Prevalence in England. 
Data Challenge, London School of Hygiene & Tropical Medicine.
```

------------------------------------------------------------------------

## Contact & Support

For questions or issues: - Review `README_ANALYSIS.md` for detailed
workflow - Check the troubleshooting section in `README_ANALYSIS.md` -
Contact: do.oparak\@gmail.com

------------------------------------------------------------------------

## License

This analysis uses publicly available data from ONS, NHS Digital, and
CPRD. Code is provided for research and educational use.

------------------------------------------------------------------------

**Last Updated:** February 2026
