---
editor_options: 
  markdown: 
    wrap: 72
---

# CHD Prevalence Estimation Analysis Pipeline

## Overview

This analysis pipeline estimates coronary heart disease (CHD) prevalence
at Lower Layer Super Output Area (LSOA) level using multiple estimation
methods, including age-sex-IMD standardization.

------------------------------------------------------------------------

## Table of Contents

1.  [Prerequisites](#prerequisites)
2.  [Required Input Data](#required-input-data)
3.  [Data Structure Requirements](#data-structure-requirements)
4.  [Analysis Scripts](#analysis-scripts)
5.  [Workflow](#workflow)
6.  [Output Variables](#output-variables)
7.  [Troubleshooting](#troubleshooting)
8.  [Quality Checks](#quality-checks)

------------------------------------------------------------------------

## Prerequisites {#prerequisites}

### R Version

-   R version 4.0.0 or higher

### Required R Packages

``` r
install.packages(c(
  "tidyverse",    # Data manipulation and visualization
  "readxl",       # Reading Excel files
  "sf",           # Spatial data (if using geographic analysis)
  "spdep"         # Spatial statistics (if using spatial models)
))
```

------------------------------------------------------------------------

## Required Input Data {#required-input-data}

The analysis requires the following data objects to be loaded into your
R environment **before** running the standardization script:

### 1. Population Data (`pop_data`)

**Source:** Office for National Statistics (ONS) mid-year population
estimates

**Description:** LSOA-level population counts by single year of age
(0-90+) and sex

**Required columns:** - `LAD 2023 Code` - Local Authority District code
(character) - `LSOA 2021 Code` - Lower Layer Super Output Area code
(character) - `Total` - Total population (numeric) - `F0` to `F90` -
Female population counts by single year of age (numeric) - `M0` to
`M90` - Male population counts by single year of age (numeric)

**Example structure:**

```         
LAD 2023 Code  LSOA 2021 Code    Total  F0  F1  F2  ... F90  M0  M1  M2  ... M90
E07000008      E01000001         1500   8   7   6   ...  1   9   8   7   ...  0
E07000008      E01000002         1800  10   9   8   ...  2  11  10   9   ...  1
```

**How to load:**

``` r
pop_data <- read_csv("population_estimates_lsoa_2023.csv")
```

------------------------------------------------------------------------

### 2. National Prevalence Rates (`nat_rates_1`)

**Source:** Health Survey for England or Quality and Outcomes Framework
(QOF)

**Description:** National CHD prevalence rates stratified by age group,
sex, and IMD quintile

**Required columns:** - `age_group` - Age group category (character) -
Valid values: "18 to 24", "25 to 29", "30 to 34", "35 to 39", "40 to
44", "45 to 49", "50 to 54", "55 to 59", "60 to 64", "65 to 69", "70 to
74", "75 to 79", "80 to 84", "85 to 89", "90+" - `imd_quintile` - Index
of Multiple Deprivation quintile (character) - Valid values: "1", "2",
"3", "4", "5" (where 1 = most deprived) - `male_prev_pct` - CHD
prevalence for males (%) (numeric) - `female_prev_pct` - CHD prevalence
for females (%) (numeric)

**Example structure:**

```         
age_group   imd_quintile  male_prev_pct  female_prev_pct
18 to 24    1             0.2            0.1
18 to 24    2             0.15           0.08
18 to 24    3             0.12           0.06
...
90+         5             15.5           12.3
```

**How to load:**

``` r
nat_rates_1 <- read_csv("national_chd_prevalence_rates.csv")
```

**CRITICAL:** - All combinations of age_group × imd_quintile × sex must
be present - No missing values in prevalence columns - Prevalence rates
should be in **percentage** format (e.g., 2.97 for 2.97%, not 0.0297)

------------------------------------------------------------------------

### 3. Index of Multiple Deprivation Data (IMD File)

**Source:** Ministry of Housing, Communities & Local Government

**Description:** IoD 2025 Index of Multiple Deprivation at LSOA level

**File format:** Excel file (.xlsx)

**File name:** `File_1_IoD2025_Index_of_Multiple_Deprivation (1).xlsx`

**Required sheet:** Sheet 2 (main IMD data)

**Required columns:** - `LSOA code (2021)` - LSOA code (character) -
`Local Authority District code (2024)` - LAD code (character) -
`Index of Multiple Deprivation (IMD) Rank (where 1 is most deprived)` -
IMD rank (numeric) -
`Index of Multiple Deprivation (IMD) Decile (where 1 is most deprived 10% of LSOA` -
IMD decile (numeric, 1-10)

**How to specify:** - Place the file in your working directory OR -
Update the file path in the script (line 24)

**Note:** IMD data covers England only. Welsh LSOAs will have missing
values and will be excluded from standardization.

------------------------------------------------------------------------

### 4. Model Table (`model_table`) [Optional]

**Description:** Main analysis table containing LSOA-level data and
estimates

**Minimum required columns:** - `lsoa_code` - LSOA code matching
population and IMD data (character)

**Optional columns:** - `lad_code` - Local Authority District code
(character) - `total_pop` - Total population (numeric) - `chd_cases` -
Observed CHD cases (numeric) - `method1a_crude_prev` - Crude prevalence
estimate (%) (numeric) - Any other existing estimation methods

**How to create:** If `model_table` doesn't exist, the script will
create a basic version. However, for full analysis, you should have a
pre-existing table with observed CHD cases.

``` r
# Example: Basic model table creation
model_table <- pop_data %>%
  select(lsoa_code = `LSOA 2021 Code`, 
         lad_code = `LAD 2023 Code`,
         total_pop = Total) %>%
  mutate(total_pop = as.numeric(total_pop))
```

------------------------------------------------------------------------

## Data Structure Requirements {#data-structure-requirements}

### Column Name Matching

The scripts are **case-sensitive** and expect exact column name matches.
Ensure your data uses the exact column names specified above.

### Data Types

-   **Character columns:** LSOA codes, LAD codes, age groups, IMD
    quintiles, sex categories
-   **Numeric columns:** Population counts, prevalence rates, case
    counts

### Missing Values

-   **Population data:** Should have no missing values for core columns
-   **National rates:** Must have complete coverage (no missing
    prevalence rates)
-   **IMD data:** Missing values expected for Welsh LSOAs (will be
    handled automatically)

### Age Group Standardization

Ensure your national prevalence rates use these exact age group labels:

```         
"18 to 24"
"25 to 29"
"30 to 34"
"35 to 39"
"40 to 44"
"45 to 49"
"50 to 54"
"55 to 59"
"60 to 64"
"65 to 69"
"70 to 74"
"75 to 79"
"80 to 84"
"85 to 89"
"90+"
```

------------------------------------------------------------------------

## Analysis Scripts {#analysis-scripts}

### Main Scripts

1.  **`standardization_calculation.R`**
    -   Calculates age-sex-IMD standardized prevalence estimates
    -   Requires: `pop_data`, `nat_rates_1`, IMD Excel file
    -   Outputs: Updated `model_table` with standardized estimates
2.  **`main_analysis.R`** (to be created)
    -   Full analysis pipeline including all estimation methods
    -   Model fitting and validation
3.  **`sensitivity_analysis.R`** (to be created)
    -   Sensitivity analyses for robustness checking
    -   Alternative specifications

------------------------------------------------------------------------

## Workflow {#workflow}

### Step 1: Prepare Your Environment

``` r
# Set working directory
setwd("path/to/your/project")

# Load required packages
library(tidyverse)
library(readxl)

# Set random seed for reproducibility (if applicable)
set.seed(123)
```

### Step 2: Load Input Data

``` r
# Load population data
pop_data <- read_csv("population_estimates_lsoa_2023.csv")

# Load national prevalence rates
nat_rates_1 <- read_csv("national_chd_prevalence_rates.csv")

# IMD data will be loaded automatically by the script
# Just ensure the file is in your working directory

# (Optional) Load or create model_table
model_table <- read_csv("model_table_base.csv")
```

### Step 3: Verify Data Structure

``` r
# Check population data
cat("Population data columns:\n")
print(names(pop_data))
cat("\nDimensions:", nrow(pop_data), "rows\n")

# Check national rates
cat("\nNational rates columns:\n")
print(names(nat_rates_1))
cat("Unique age groups:", length(unique(nat_rates_1$age_group)), "\n")
cat("Unique IMD quintiles:", length(unique(nat_rates_1$imd_quintile)), "\n")

# Verify age groups match expected format
expected_age_groups <- c("18 to 24", "25 to 29", "30 to 34", "35 to 39", 
                        "40 to 44", "45 to 49", "50 to 54", "55 to 59",
                        "60 to 64", "65 to 69", "70 to 74", "75 to 79",
                        "80 to 84", "85 to 89", "90+")
actual_age_groups <- sort(unique(nat_rates_1$age_group))

if (all(expected_age_groups %in% actual_age_groups)) {
  cat("✓ Age groups verified\n")
} else {
  cat("✗ Age group mismatch detected\n")
  cat("Missing:", setdiff(expected_age_groups, actual_age_groups), "\n")
}
```

### Step 4: Run Standardization

``` r
# Source the standardization script
source("standardization_calculation.R")

# The script will:
# 1. Load and process IMD data
# 2. Process population data by age-sex groups
# 3. Match population with prevalence rates
# 4. Calculate expected cases
# 5. Aggregate to LSOA level
# 6. Update model_table with results
```

### Step 5: Verify Output

``` r
# Check results
cat("Standardization complete!\n")
cat("LSOAs with estimates:", 
    sum(!is.na(model_table$method1b_standardized_prev)), "\n")

# View summary
summary(model_table$method1b_standardized_prev)

# View first few rows
head(model_table %>% 
  select(lsoa_code, method1b_standardized_cases, method1b_standardized_prev))
```

------------------------------------------------------------------------

## Output Variables {#output-variables}

The standardization script adds the following columns to `model_table`:

### `method1b_standardized_cases`

-   **Type:** Numeric
-   **Description:** Expected number of CHD cases based on age-sex-IMD
    standardization
-   **Units:** Count (number of cases)
-   **Range:** Typically 0.5 to 200+ depending on LSOA population

### `method1b_standardized_prev`

-   **Type:** Numeric
-   **Description:** Age-sex-IMD standardized CHD prevalence
-   **Units:** Percentage (%)
-   **Range:** Typically 1.5% to 5.5%
-   **Interpretation:** Higher values indicate higher expected CHD
    burden after accounting for demographic differences

### `diff_crude_vs_standardized` (if crude method exists)

-   **Type:** Numeric
-   **Description:** Difference between standardized and crude
    prevalence
-   **Units:** Percentage points
-   **Interpretation:**
    -   Positive values: Standardized estimate higher than crude (e.g.,
        older population)
    -   Negative values: Standardized estimate lower than crude (e.g.,
        younger population)

------------------------------------------------------------------------

## Quality Checks {#quality-checks}

### Automatic Checks Performed

The script automatically performs the following quality checks:

1.  **Data Completeness**
    -   Identifies missing IMD values (expected for Welsh LSOAs)
    -   Identifies missing prevalence rate matches
    -   Reports coverage statistics
2.  **National-Level Validation**
    -   Calculates national prevalence from standardized estimates
    -   Should approximate the population-weighted national rate
3.  **Extreme Value Detection**
    -   Flags LSOAs with prevalence \< 1% (unusually low)
    -   Flags LSOAs with prevalence \> 6% (unusually high)
    -   Lists top/bottom LSOAs for review
4.  **Distribution Summary**
    -   Mean, SD, median, quartiles of standardized prevalence
    -   Should show reasonable variation (SD typically 0.3-0.6%)

### Manual Validation Steps

After running the script, perform these additional checks:

``` r
# 1. Check coverage
coverage_stats <- model_table %>%
  summarise(
    total_lsoas = n(),
    with_standardized = sum(!is.na(method1b_standardized_prev)),
    coverage_pct = (with_standardized / total_lsoas) * 100
  )
print(coverage_stats)
# Expected: ~95-98% coverage (excluding Welsh LSOAs)

# 2. Check for impossible values
impossible_values <- model_table %>%
  filter(method1b_standardized_prev < 0 | method1b_standardized_prev > 20)
cat("Impossible values found:", nrow(impossible_values), "\n")
# Expected: 0 rows

# 3. Compare with observed data (if available)
if ("chd_cases" %in% names(model_table)) {
  comparison <- model_table %>%
    filter(!is.na(chd_cases) & !is.na(method1b_standardized_cases)) %>%
    summarise(
      observed_total = sum(chd_cases),
      expected_total = sum(method1b_standardized_cases),
      ratio = observed_total / expected_total
    )
  print(comparison)
  # Expected: Ratio close to 1.0 (e.g., 0.95-1.05)
}

# 4. Check spatial patterns (if using geographic data)
library(sf)
library(ggplot2)

# Load LSOA boundaries
lsoa_boundaries <- st_read("LSOA_boundaries.shp")

# Join with estimates
lsoa_map_data <- lsoa_boundaries %>%
  left_join(model_table, by = c("LSOA21CD" = "lsoa_code"))

# Map standardized prevalence
ggplot(lsoa_map_data) +
  geom_sf(aes(fill = method1b_standardized_prev), color = NA) +
  scale_fill_viridis_c(name = "CHD Prevalence (%)") +
  theme_minimal() +
  labs(title = "Age-Sex-IMD Standardized CHD Prevalence by LSOA")
# Look for: Sensible geographic patterns, no strange artifacts
```

------------------------------------------------------------------------

## Troubleshooting {#troubleshooting}

### Common Issues and Solutions

#### Issue 1: "Error: 'pop_data' object not found"

**Solution:** Load the population data before running the script

``` r
pop_data <- read_csv("population_estimates_lsoa_2023.csv")
```

#### Issue 2: "Error: 'nat_rates_1' object not found"

**Solution:** Load the national prevalence rates

``` r
nat_rates_1 <- read_csv("national_chd_prevalence_rates.csv")
```

#### Issue 3: "Error in read_excel: path does not exist"

**Solutions:** 1. Check the IMD file is in your working directory 2.
Update the file path in the script (line 24) 3. Verify the exact
filename (including spaces and version numbers)

#### Issue 4: Many rows with missing prevalence rates

**Possible causes:** 1. **Age group mismatch** - Check age group labels
match exactly
`r    # Check your age groups    unique(nat_rates_1$age_group)    # Should match: "18 to 24", "25 to 29", etc.`

2.  **IMD quintile format** - Ensure quintiles are "1", "2", "3", "4",
    "5" (character)

    ``` r
    # Check quintile format
    unique(nat_rates_1$imd_quintile)
    # Should be: "1" "2" "3" "4" "5"
    ```

3.  **Sex label mismatch** - Must be "Male" and "Female" (capitalized)

    ``` r
    # Check sex categories in your data
    unique(nat_rates_long$sex)
    ```

#### Issue 5: Standardized prevalence is constant across LSOAs

**Cause:** Likely using a single national rate instead of stratified
rates **Solution:** Ensure `nat_rates_1` has multiple rows with
different rates for different age-sex-IMD combinations

#### Issue 6: Negative prevalence values

**Cause:** Data quality issue or calculation error **Solution:** 1.
Check for negative population values 2. Check for negative prevalence
rates in input data 3. Review any data transformations

#### Issue 7: National-level estimate doesn't match expected value

**Possible causes:** 1. **Denominator issue** - Using adult population
instead of total population - The script correctly uses total population
(all ages) as denominator 2. **Missing data** - Welsh LSOAs excluded 3.
**Prevalence rate format** - Should be in % not decimal
`r    # Check if rates are in correct format    summary(nat_rates_1$male_prev_pct)    # Should be: typically 0.2 to 15%, NOT 0.002 to 0.15`

------------------------------------------------------------------------

## Expected Runtime

-   **Standardization calculation:** 2-5 minutes
    -   Depends on number of LSOAs (typically \~32,000 in England)
    -   Most time spent on data reshaping and joins

------------------------------------------------------------------------

## File Organization

Recommended project structure:

```         
project/
├── data/
│   ├── population_estimates_lsoa_2023.csv
│   ├── national_chd_prevalence_rates.csv
│   ├── File_1_IoD2025_Index_of_Multiple_Deprivation (1).xlsx
│   └── model_table_base.csv (optional)
├── scripts/
│   ├── standardization_calculation.R
│   ├── main_analysis.R
│   └── sensitivity_analysis.R
├── outputs/
│   ├── model_table_updated.rds
│   └── results/
└── README.md
```

------------------------------------------------------------------------

## Additional Resources

### Key Concepts

**Indirect Standardization:** - Applies national age-sex-IMD-specific
rates to local population structure - Expected cases = Σ(local
population × national rate) across all strata - Standardized prevalence
= (total expected cases / total population) × 100

**Why Standardize?** - Controls for differences in age, sex, and
deprivation composition - Allows fair comparison between areas with
different demographics - Separates true disease risk from population
structure effects

### References

-   Office for National Statistics: Population Estimates
-   Ministry of Housing, Communities & Local Government: English Indices
    of Deprivation
-   NHS Digital: Quality and Outcomes Framework

------------------------------------------------------------------------

## Support

For issues not covered in this README: 1. Check your data matches the
required structure exactly 2. Review the console output from the script
for specific error messages 3. Verify all required objects exist before
running the script 4. Check the "Quality Checks" section for validation
steps

------------------------------------------------------------------------

**Last Updated:** [Date] **Version:** 1.0
