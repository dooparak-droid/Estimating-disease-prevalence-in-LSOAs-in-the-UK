################################################################################
# DATA SPECIFICATION QUICK REFERENCE
# CHD Prevalence Estimation Analysis
################################################################################

# REQUIRED R OBJECTS ===========================================================

# 1. pop_data ------------------------------------------------------------------
#    Description: LSOA-level population by single year of age and sex
#    Source: ONS Mid-Year Population Estimates

# Required columns:
pop_data_columns <- c(
  "LAD 2023 Code",      # Character - Local Authority District code
  "LSOA 2021 Code",     # Character - Lower Layer Super Output Area code
  "Total",              # Numeric - Total population (all ages)
  "F0", "F1", ..., "F90",  # Numeric - Female population by age 0-90
  "M0", "M1", ..., "M90"   # Numeric - Male population by age 0-90
)

# Example loading:
pop_data <- read_csv("population_estimates_lsoa_2023.csv")

# Expected dimensions: ~32,000 rows (LSOAs in England) × ~185 columns


# 2. nat_rates_1 ---------------------------------------------------------------
#    Description: National CHD prevalence rates by age/sex/IMD
#    Source: Health Survey for England or QOF

# Required columns:
nat_rates_required <- data.frame(
  column_name = c("age_group", "imd_quintile", "male_prev_pct", "female_prev_pct"),
  data_type = c("character", "character", "numeric", "numeric"),
  description = c(
    "Age group (e.g., '18 to 24')",
    "IMD quintile ('1' to '5', 1=most deprived)",
    "Male CHD prevalence (%)",
    "Female CHD prevalence (%)"
  ),
  example_value = c("45 to 49", "3", "3.2", "1.8")
)

# Valid age_group values (MUST match exactly):
valid_age_groups <- c(
  "18 to 24", "25 to 29", "30 to 34", "35 to 39", "40 to 44",
  "45 to 49", "50 to 54", "55 to 59", "60 to 64", "65 to 69",
  "70 to 74", "75 to 79", "80 to 84", "85 to 89", "90+"
)

# Valid imd_quintile values:
valid_imd_quintiles <- c("1", "2", "3", "4", "5")

# Example loading:
nat_rates_1 <- read_csv("national_chd_prevalence_rates.csv")

# Expected dimensions: 75 rows (15 age groups × 5 IMD quintiles) × 4 columns

# CRITICAL: Prevalence rates must be in PERCENTAGE format
# Correct:   male_prev_pct = 2.97 (for 2.97%)
# Incorrect: male_prev_pct = 0.0297 (decimal format)


# 3. IMD Excel File ------------------------------------------------------------
#    Description: Index of Multiple Deprivation 2025
#    Source: MHCLG

# File details:
imd_file_spec <- list(
  filename = "File_1_IoD2025_Index_of_Multiple_Deprivation (1).xlsx",
  sheet_number = 2,
  sheet_name = "IoD2025 Scores",
  
  required_columns = c(
    "LSOA code (2021)",
    "Local Authority District code (2024)",
    "Index of Multiple Deprivation (IMD) Rank (where 1 is most deprived)",
    "Index of Multiple Deprivation (IMD) Decile (where 1 is most deprived 10% of LSOA"
  )
)

# Note: File must be in working directory or update path in script
# Covers England only - Welsh LSOAs will have missing values (expected)


# 4. model_table (Optional) ----------------------------------------------------
#    Description: Main analysis table with LSOA-level estimates
#    Source: Created by user or previous analysis steps

# Minimum required columns:
model_table_minimum <- c(
  "lsoa_code"  # Character - LSOA code (must match pop_data and IMD data)
)

# Commonly included columns:
model_table_optional <- c(
  "lad_code",                # Character - LAD code
  "total_pop",               # Numeric - Total population
  "chd_cases",               # Numeric - Observed CHD cases
  "method1a_crude_prev",     # Numeric - Crude prevalence estimate (%)
  # ... other estimation methods
)

# If model_table doesn't exist, script will create a basic version


# DATA VALIDATION CHECKS =======================================================

# Run these checks after loading data:

# 1. Check pop_data structure
cat("=== Population Data Validation ===\n")
cat("Dimensions:", nrow(pop_data), "×", ncol(pop_data), "\n")
cat("Expected: ~32,000 × ~185\n")

# Check for required columns
required_pop_cols <- c("LAD 2023 Code", "LSOA 2021 Code", "Total")
missing_pop_cols <- setdiff(required_pop_cols, names(pop_data))
if(length(missing_pop_cols) > 0) {
  cat("❌ Missing columns:", paste(missing_pop_cols, collapse=", "), "\n")
} else {
  cat("✓ All required columns present\n")
}

# Check for age columns (should have F0-F90 and M0-M90)
female_age_cols <- paste0("F", 0:90)
male_age_cols <- paste0("M", 0:90)
missing_female <- sum(!female_age_cols %in% names(pop_data))
missing_male <- sum(!male_age_cols %in% names(pop_data))
cat("Missing female age columns:", missing_female, "\n")
cat("Missing male age columns:", missing_male, "\n")


# 2. Check nat_rates_1 structure
cat("\n=== National Rates Validation ===\n")
cat("Dimensions:", nrow(nat_rates_1), "×", ncol(nat_rates_1), "\n")
cat("Expected: 75 × 4\n")

# Check column names
required_rate_cols <- c("age_group", "imd_quintile", "male_prev_pct", "female_prev_pct")
missing_rate_cols <- setdiff(required_rate_cols, names(nat_rates_1))
if(length(missing_rate_cols) > 0) {
  cat("❌ Missing columns:", paste(missing_rate_cols, collapse=", "), "\n")
} else {
  cat("✓ All required columns present\n")
}

# Check age groups match expected values
actual_age_groups <- unique(nat_rates_1$age_group)
expected_age_groups <- c("18 to 24", "25 to 29", "30 to 34", "35 to 39", 
                        "40 to 44", "45 to 49", "50 to 54", "55 to 59",
                        "60 to 64", "65 to 69", "70 to 74", "75 to 79",
                        "80 to 84", "85 to 89", "90+")
missing_age_groups <- setdiff(expected_age_groups, actual_age_groups)
extra_age_groups <- setdiff(actual_age_groups, expected_age_groups)

if(length(missing_age_groups) > 0) {
  cat("❌ Missing age groups:", paste(missing_age_groups, collapse=", "), "\n")
}
if(length(extra_age_groups) > 0) {
  cat("⚠ Extra age groups:", paste(extra_age_groups, collapse=", "), "\n")
}
if(length(missing_age_groups) == 0 && length(extra_age_groups) == 0) {
  cat("✓ Age groups validated\n")
}

# Check IMD quintiles
actual_quintiles <- unique(nat_rates_1$imd_quintile)
expected_quintiles <- c("1", "2", "3", "4", "5")
if(all(expected_quintiles %in% actual_quintiles)) {
  cat("✓ IMD quintiles validated\n")
} else {
  cat("❌ IMD quintile issue detected\n")
  cat("  Expected:", paste(expected_quintiles, collapse=", "), "\n")
  cat("  Found:", paste(actual_quintiles, collapse=", "), "\n")
}

# Check prevalence rate format (should be %, not decimal)
rate_summary <- summary(nat_rates_1$male_prev_pct)
if(rate_summary["Mean"] > 1) {
  cat("✓ Prevalence rates in percentage format\n")
} else {
  cat("⚠ WARNING: Prevalence rates may be in decimal format\n")
  cat("  Mean male prevalence:", round(rate_summary["Mean"], 4), "\n")
  cat("  Expected: > 1 (e.g., 2.97 for 2.97%)\n")
}

# Check for missing values
missing_male_prev <- sum(is.na(nat_rates_1$male_prev_pct))
missing_female_prev <- sum(is.na(nat_rates_1$female_prev_pct))
cat("Missing male prevalence values:", missing_male_prev, "\n")
cat("Missing female prevalence values:", missing_female_prev, "\n")


# 3. Check IMD file exists
cat("\n=== IMD File Validation ===\n")
imd_file <- "File_1_IoD2025_Index_of_Multiple_Deprivation (1).xlsx"
if(file.exists(imd_file)) {
  cat("✓ IMD file found:", imd_file, "\n")
  
  # Try to load and check structure
  tryCatch({
    imd_test <- read_excel(imd_file, sheet = 2, n_max = 5)
    cat("✓ File readable\n")
    cat("Sample columns:", paste(head(names(imd_test), 5), collapse=", "), "\n")
  }, error = function(e) {
    cat("❌ Error reading file:", e$message, "\n")
  })
} else {
  cat("❌ IMD file not found in working directory\n")
  cat("  Expected:", imd_file, "\n")
  cat("  Current directory:", getwd(), "\n")
}


# EXAMPLE DATA STRUCTURES ======================================================

# Example nat_rates_1 structure (first 10 rows):
example_nat_rates <- data.frame(
  age_group = c("18 to 24", "18 to 24", "18 to 24", "18 to 24", "18 to 24",
                "25 to 29", "25 to 29", "25 to 29", "25 to 29", "25 to 29"),
  imd_quintile = c("1", "2", "3", "4", "5",
                   "1", "2", "3", "4", "5"),
  male_prev_pct = c(0.3, 0.25, 0.2, 0.15, 0.12,
                    0.5, 0.4, 0.35, 0.28, 0.22),
  female_prev_pct = c(0.15, 0.12, 0.1, 0.08, 0.06,
                      0.25, 0.2, 0.17, 0.14, 0.11)
)

cat("\n=== Example National Rates Structure ===\n")
print(example_nat_rates)


# Example pop_data structure (simplified):
example_pop_data <- data.frame(
  `LAD 2023 Code` = c("E07000008", "E07000008", "E07000009"),
  `LSOA 2021 Code` = c("E01000001", "E01000002", "E01000003"),
  Total = c(1500, 1800, 2000),
  F0 = c(8, 10, 12),
  F1 = c(7, 9, 11),
  # ... F2 to F89 would be here ...
  F90 = c(1, 2, 1),
  M0 = c(9, 11, 13),
  M1 = c(8, 10, 12),
  # ... M2 to M89 would be here ...
  M90 = c(0, 1, 0),
  check.names = FALSE
)

cat("\n=== Example Population Data Structure ===\n")
cat("(Showing first few and last columns only)\n")
print(example_pop_data[, c(1:6, ncol(example_pop_data))])


# COMMON DATA FORMAT ISSUES ====================================================

cat("\n=== Common Data Issues and Solutions ===\n\n")

cat("1. Age group label mismatch\n")
cat("   Problem: 'age_group' has '18-24' instead of '18 to 24'\n")
cat("   Solution: Standardize to 'XX to YY' format with spaces\n")
cat("   Fix: nat_rates_1$age_group <- gsub('-', ' to ', nat_rates_1$age_group)\n\n")

cat("2. IMD quintile as numeric instead of character\n")
cat("   Problem: imd_quintile = 1 instead of '1'\n")
cat("   Solution: Convert to character\n")
cat("   Fix: nat_rates_1$imd_quintile <- as.character(nat_rates_1$imd_quintile)\n\n")

cat("3. Prevalence rates in decimal format\n")
cat("   Problem: male_prev_pct = 0.0297 instead of 2.97\n")
cat("   Solution: Multiply by 100\n")
cat("   Fix: nat_rates_1 <- nat_rates_1 %>% \n")
cat("          mutate(male_prev_pct = male_prev_pct * 100,\n")
cat("                 female_prev_pct = female_prev_pct * 100)\n\n")

cat("4. Missing age groups in national rates\n")
cat("   Problem: Not all 15 age groups are present\n")
cat("   Solution: Ensure complete coverage or use nearest neighbor\n\n")

cat("5. Extra whitespace in character columns\n")
cat("   Problem: age_group = '18 to 24 ' (trailing space)\n")
cat("   Solution: Trim whitespace\n")
cat("   Fix: nat_rates_1 <- nat_rates_1 %>% \n")
cat("          mutate(across(where(is.character), trimws))\n\n")


################################################################################
# SAVE THIS FILE AS: DATA_SPECIFICATION.R
# Run after loading your data to validate structure
################################################################################
