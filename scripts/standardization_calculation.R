################################################################################
# AGE-SEX-IMD STANDARDIZED PREVALENCE ESTIMATION
# 
# This script calculates standardized CHD prevalence estimates at LSOA level
# using national prevalence rates stratified by age, sex, and IMD quintile
#
# Author: [Your Name]
# Date: [Date]
# Version: 1.0
################################################################################

# SETUP ========================================================================

# Load required packages
library(tidyverse)
library(readxl)

# Set options for cleaner output
options(scipen = 999)  # Disable scientific notation


# DATA LOADING =================================================================

cat("=== LOADING DATA ===\n")

## 1. Load IMD Data ------------------------------------------------------------
cat("Loading IMD 2025 data...\n")

# Load Index of Multiple Deprivation 2025 data
# Expected file: Excel file with IoD2025 data
# Expected sheet: Sheet 2 contains LSOA-level IMD data
IMD_updated <- read_excel(
  "File_1_IoD2025_Index_of_Multiple_Deprivation (1).xlsx", 
  sheet = 2
)

cat("  - Loaded", nrow(IMD_updated), "LSOAs with IMD data\n")

## 2. Load Population Data -----------------------------------------------------
cat("Loading population data...\n")

# Population data should already be loaded in your environment as 'pop_data'
# This should contain LSOA-level population by single year of age and sex
# Verify it exists
if (!exists("pop_data")) {
  stop("Error: 'pop_data' object not found. Please load population data first.")
}

cat("  - Loaded", nrow(pop_data), "LSOAs with population data\n")

## 3. Load National Prevalence Rates -------------------------------------------
cat("Loading national prevalence rates...\n")

# National prevalence rates should already be loaded as 'nat_rates_1'
# This should contain prevalence rates by age group, sex, and IMD quintile
if (!exists("nat_rates_1")) {
  stop("Error: 'nat_rates_1' object not found. Please load national prevalence rates first.")
}

cat("  - Loaded", nrow(nat_rates_1), "prevalence rate strata\n")


# DATA PREPARATION =============================================================

cat("\n=== PREPARING IMD DATA ===\n")

## Process IMD data ------------------------------------------------------------
IMD_clean <- IMD_updated %>%
  # Select and rename relevant columns
  select(
    lsoa_code = `LSOA code (2021)`,
    lad_code = `Local Authority District code (2024)`,
    IMD_rank = `Index of Multiple Deprivation (IMD) Rank (where 1 is most deprived)`,
    IMD_decile = `Index of Multiple Deprivation (IMD) Decile (where 1 is most deprived 10% of LSOA`
  ) %>%
  # Convert IMD deciles to quintiles (1 = most deprived, 5 = least deprived)
  mutate(
    imd_quintile = case_when(
      IMD_decile %in% c(1, 2)   ~ "1",  # Most deprived
      IMD_decile %in% c(3, 4)   ~ "2",
      IMD_decile %in% c(5, 6)   ~ "3",
      IMD_decile %in% c(7, 8)   ~ "4",
      IMD_decile %in% c(9, 10)  ~ "5",  # Least deprived
      TRUE ~ NA_character_
    )
  )

cat("  - Processed", nrow(IMD_clean), "LSOAs\n")
cat("  - IMD quintile distribution:\n")
print(table(IMD_clean$imd_quintile, useNA = "ifany"))


cat("\n=== PREPARING POPULATION DATA ===\n")

## Process population data -----------------------------------------------------

# Extract relevant columns and clean
pop_data_clean <- pop_data %>%
  select(`LAD 2023 Code`, `LSOA 2021 Code`, Total, F0:F90, M0:M90) %>%
  rename(
    lad_code = `LAD 2023 Code`,
    lsoa_code = `LSOA 2021 Code`,
    total_pop = Total
  ) %>%
  mutate(total_pop = as.numeric(total_pop))

# Pivot female population to long format
pop_females <- pop_data_clean %>%
  select(lad_code, lsoa_code, F0:F90) %>%
  pivot_longer(
    cols = F0:F90,
    names_to = "age_single",
    values_to = "population"
  ) %>%
  mutate(
    sex = "Female",
    age = as.numeric(gsub("F", "", age_single)),
    population = as.numeric(population)
  ) %>%
  select(lad_code, lsoa_code, sex, age, population)

# Pivot male population to long format
pop_males <- pop_data_clean %>%
  select(lad_code, lsoa_code, M0:M90) %>%
  pivot_longer(
    cols = M0:M90,
    names_to = "age_single",
    values_to = "population"
  ) %>%
  mutate(
    sex = "Male",
    age = as.numeric(gsub("M", "", age_single)),
    population = as.numeric(population)
  ) %>%
  select(lad_code, lsoa_code, sex, age, population)

# Combine male and female populations
pop_combined <- bind_rows(pop_males, pop_females)

cat("  - Combined population data:", nrow(pop_combined), "age-sex-LSOA combinations\n")


## Create age groups to match national prevalence data ------------------------

# Define age groups matching national prevalence data structure
pop_with_age_groups <- pop_combined %>%
  mutate(
    age_group = case_when(
      age >= 18 & age <= 24 ~ "18 to 24",
      age >= 25 & age <= 29 ~ "25 to 29",
      age >= 30 & age <= 34 ~ "30 to 34",
      age >= 35 & age <= 39 ~ "35 to 39",
      age >= 40 & age <= 44 ~ "40 to 44",
      age >= 45 & age <= 49 ~ "45 to 49",
      age >= 50 & age <= 54 ~ "50 to 54",
      age >= 55 & age <= 59 ~ "55 to 59",
      age >= 60 & age <= 64 ~ "60 to 64",
      age >= 65 & age <= 69 ~ "65 to 69",
      age >= 70 & age <= 74 ~ "70 to 74",
      age >= 75 & age <= 79 ~ "75 to 79",
      age >= 80 & age <= 84 ~ "80 to 84",
      age >= 85 & age <= 89 ~ "85 to 89",
      age >= 90             ~ "90+",
      TRUE                  ~ NA_character_  # Ages under 18
    )
  )

# Aggregate to age group level (sum populations within each group)
pop_by_age_group <- pop_with_age_groups %>%
  filter(!is.na(age_group)) %>%  # Keep only ages 18+
  group_by(lad_code, lsoa_code, sex, age_group) %>%
  summarise(
    population = sum(population, na.rm = TRUE),
    .groups = "drop"
  )

cat("  - Created", nrow(pop_by_age_group), "age-group-sex-LSOA strata\n")


## Join with IMD data ----------------------------------------------------------

pop_with_imd <- pop_by_age_group %>%
  left_join(
    IMD_clean %>% select(lsoa_code, lad_code, IMD_decile, imd_quintile),
    by = "lsoa_code"
  )

# Check for missing IMD values
missing_imd <- pop_with_imd %>%
  filter(is.na(imd_quintile))

if (nrow(missing_imd) > 0) {
  # Identify which LSOAs are missing IMD data
  missing_lsoas <- missing_imd %>%
    distinct(lsoa_code, lad_code.x) %>%
    head(20)
  
  cat("\n  WARNING:", nrow(distinct(missing_imd, lsoa_code)), 
      "LSOAs missing IMD data\n")
  cat("  - First 20 missing LSOAs:\n")
  print(missing_lsoas)
  cat("  - These are typically Welsh LSOAs (England-only IMD data)\n")
  cat("  - These will be excluded from standardization\n")
} else {
  cat("  - All LSOAs successfully matched with IMD data\n")
}


# PREPARE NATIONAL PREVALENCE RATES ============================================

cat("\n=== PREPARING NATIONAL PREVALENCE RATES ===\n")

# Reshape national prevalence rates to long format
# One row per age-group × sex × IMD-quintile combination
nat_rates_long <- nat_rates_1 %>%
  pivot_longer(
    cols = c(male_prev_pct, female_prev_pct),
    names_to = "sex_type",
    values_to = "prevalence_rate"
  ) %>%
  mutate(
    sex = case_when(
      sex_type == "male_prev_pct" ~ "Male",
      sex_type == "female_prev_pct" ~ "Female",
      TRUE ~ NA_character_
    )
  ) %>%
  select(age_group, imd_quintile, sex, prevalence_rate) %>%
  filter(!is.na(prevalence_rate))  # Remove any missing values

cat("  - Reshaped to", nrow(nat_rates_long), "age-sex-IMD strata\n")

# Verify coverage
cat("  - Age groups in national rates:", 
    length(unique(nat_rates_long$age_group)), "\n")
cat("  - IMD quintiles in national rates:", 
    length(unique(nat_rates_long$imd_quintile)), "\n")


# CALCULATE EXPECTED CASES =====================================================

cat("\n=== CALCULATING STANDARDIZED ESTIMATES ===\n")

## Join population with prevalence rates ---------------------------------------

pop_with_rates <- pop_with_imd %>%
  left_join(
    nat_rates_long,
    by = c("age_group", "sex", "imd_quintile")
  )

# Check for missing matches
missing_rates <- pop_with_rates %>%
  filter(is.na(prevalence_rate))

if (nrow(missing_rates) > 0) {
  cat("\n  WARNING:", nrow(missing_rates), "rows with missing prevalence rates\n")
  
  # Show unique combinations that failed to match
  missing_combos <- missing_rates %>%
    distinct(age_group, sex, imd_quintile) %>%
    head(20)
  
  cat("  - Missing rate combinations (first 20):\n")
  print(missing_combos)
  
  # Remove rows with missing data
  cat("  - Removing rows with missing prevalence rates\n")
  pop_with_rates <- pop_with_rates %>%
    filter(!is.na(prevalence_rate))
}

cat("  - Successfully matched", nrow(pop_with_rates), "population strata with prevalence rates\n")


## Calculate expected cases per stratum ----------------------------------------

pop_with_expected <- pop_with_rates %>%
  mutate(
    # Expected cases = population × prevalence rate (rate is already in %)
    expected_cases_stratum = population * prevalence_rate / 100
  )


## Aggregate to LSOA level -----------------------------------------------------

# Sum expected cases across all age-sex-IMD strata within each LSOA
lsoa_standardized <- pop_with_expected %>%
  group_by(lad_code.x, lsoa_code) %>%
  summarise(
    # Total expected cases (sum across all strata)
    standardized_cases = sum(expected_cases_stratum, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  rename(lad_code = lad_code.x) %>%
  # Join with total population (all ages, not just 18+)
  left_join(
    pop_data_clean %>% select(lsoa_code, total_pop),
    by = "lsoa_code"
  ) %>%
  # Calculate standardized prevalence per 100 population
  mutate(
    standardized_prev = (standardized_cases / total_pop) * 100
  )

cat("  - Calculated standardized estimates for", nrow(lsoa_standardized), "LSOAs\n")


# QUALITY CHECKS ===============================================================

cat("\n=== QUALITY CHECKS ===\n")

## Summary statistics ----------------------------------------------------------

summary_stats <- lsoa_standardized %>%
  summarise(
    n_lsoas = n(),
    mean_prev = mean(standardized_prev, na.rm = TRUE),
    sd_prev = sd(standardized_prev, na.rm = TRUE),
    min_prev = min(standardized_prev, na.rm = TRUE),
    q25_prev = quantile(standardized_prev, 0.25, na.rm = TRUE),
    median_prev = median(standardized_prev, na.rm = TRUE),
    q75_prev = quantile(standardized_prev, 0.75, na.rm = TRUE),
    max_prev = max(standardized_prev, na.rm = TRUE)
  )

cat("\nStandardized prevalence summary statistics:\n")
print(summary_stats)


## National-level check --------------------------------------------------------

# Calculate national prevalence from standardized estimates
national_standardized <- sum(lsoa_standardized$standardized_cases, na.rm = TRUE) /
  sum(lsoa_standardized$total_pop, na.rm = TRUE) * 100

cat("\nNational prevalence estimate from standardization:", 
    round(national_standardized, 3), "%\n")


## Check for extreme values ----------------------------------------------------

# Identify LSOAs with very high or very low prevalence
extreme_low <- lsoa_standardized %>%
  filter(standardized_prev < 1) %>%
  arrange(standardized_prev)

extreme_high <- lsoa_standardized %>%
  filter(standardized_prev > 6) %>%
  arrange(desc(standardized_prev))

if (nrow(extreme_low) > 0) {
  cat("\nLSOAs with prevalence < 1%:", nrow(extreme_low), "\n")
  cat("  - Lowest 5:\n")
  print(head(extreme_low %>% select(lsoa_code, standardized_prev), 5))
}

if (nrow(extreme_high) > 0) {
  cat("\nLSOAs with prevalence > 6%:", nrow(extreme_high), "\n")
  cat("  - Highest 5:\n")
  print(head(extreme_high %>% select(lsoa_code, standardized_prev), 5))
}


# MERGE WITH MODEL TABLE =======================================================

cat("\n=== MERGING WITH MODEL TABLE ===\n")

# Check if model_table exists
if (!exists("model_table")) {
  cat("WARNING: 'model_table' object not found.\n")
  cat("Creating new table with standardized estimates.\n")
  
  model_table <- lsoa_standardized %>%
    rename(
      method1b_standardized_cases = standardized_cases,
      method1b_standardized_prev = standardized_prev
    )
} else {
  # Remove any existing standardized columns to avoid duplicates
  existing_cols <- names(model_table)
  cols_to_remove <- grep("method1b_standardized", existing_cols, value = TRUE)
  
  if (length(cols_to_remove) > 0) {
    cat("  - Removing existing standardized columns:", 
        paste(cols_to_remove, collapse = ", "), "\n")
    model_table <- model_table %>%
      select(-any_of(cols_to_remove))
  }
  
  # Add new standardized estimates
  model_table <- model_table %>%
    left_join(
      lsoa_standardized %>% 
        select(lsoa_code, 
               method1b_standardized_cases = standardized_cases,
               method1b_standardized_prev = standardized_prev),
      by = "lsoa_code"
    )
}

cat("  - LSOAs with standardized estimates:", 
    sum(!is.na(model_table$method1b_standardized_cases)), "\n")
cat("  - Total LSOAs in model table:", nrow(model_table), "\n")


# COMPARATIVE ANALYSIS =========================================================

cat("\n=== COMPARING METHODS ===\n")

# Compare crude vs standardized estimates (if crude method exists)
if ("method1a_crude_prev" %in% names(model_table)) {
  
  comparison <- model_table %>%
    filter(!is.na(method1a_crude_prev) & !is.na(method1b_standardized_prev)) %>%
    summarise(
      crude_mean = mean(method1a_crude_prev, na.rm = TRUE),
      crude_sd = sd(method1a_crude_prev, na.rm = TRUE),
      standardized_mean = mean(method1b_standardized_prev, na.rm = TRUE),
      standardized_sd = sd(method1b_standardized_prev, na.rm = TRUE),
      correlation = cor(method1a_crude_prev, method1b_standardized_prev, 
                       use = "complete.obs")
    )
  
  cat("\nCrude vs Standardized comparison:\n")
  print(comparison)
  
  # Calculate difference
  model_table <- model_table %>%
    mutate(
      diff_crude_vs_standardized = method1b_standardized_prev - method1a_crude_prev
    )
  
  cat("\nDifference (standardized - crude) summary:\n")
  print(summary(model_table$diff_crude_vs_standardized))
  
} else {
  cat("  - Crude prevalence not found in model_table\n")
  cat("  - Skipping crude vs standardized comparison\n")
}


# SAVE RESULTS =================================================================

cat("\n=== SAVING RESULTS ===\n")

# Save cleaned datasets (optional)
# saveRDS(lsoa_standardized, "lsoa_standardized_estimates.rds")
# saveRDS(model_table, "model_table_updated.rds")

cat("\nStandardization complete!\n")
cat("Results stored in 'model_table' object.\n")
cat("\nKey variables added:\n")
cat("  - method1b_standardized_cases: Expected CHD cases\n")
cat("  - method1b_standardized_prev: Standardized prevalence (%)\n")

# Print final summary
cat("\n=== FINAL SUMMARY ===\n")
final_summary <- model_table %>%
  summarise(
    total_lsoas = n(),
    lsoas_with_standardized = sum(!is.na(method1b_standardized_prev)),
    mean_standardized_prev = mean(method1b_standardized_prev, na.rm = TRUE),
    sd_standardized_prev = sd(method1b_standardized_prev, na.rm = TRUE)
  )
print(final_summary)

################################################################################
# END OF SCRIPT
################################################################################
