# ================================================================
# DARK PEAK ANALYTICS - FINAL PREVALENCE ESTIMATION ANALYSIS
# ================================================================
#
# This script evaluates 5 methods for estimating CHD prevalence at LSOA level:
#
# EXPECTED VALUE MODELS (increasing complexity):
#   1A: Crude estimates (population × national rate)
#   1B: Age-sex standardized estimates
#   1C: Age-sex-IMD standardized estimates
#
# REGRESSION MODELS:
#   2A: Hierarchical GLM with random CV at LSOA level (infilling)
#   2B: Hierarchical GLM with blocked CV at LAD level (new regions)
#
# All models use crude offset + IMD predictor for consistency.
# Sensitivity analysis (standardized offset) in separate script.
# ================================================================

library(dplyr)
library(lme4)
library(ggplot2)
library(tidyr)
library(gridExtra)
library(scales)
library(epiR)

# ================================================================
# SECTION 1: DATA SUMMARY
# ================================================================

cat("\n========================================\n")
cat("DARK PEAK ANALYTICS - FINAL ANALYSIS\n")
cat("CHD Prevalence Estimation Methods\n")
cat("========================================\n\n")

cat("Dataset summary:\n")
cat("  Total LSOAs:         ", nrow(model_table), "\n")
cat("  Total LADs:          ", length(unique(model_table$lad_code)), "\n")
cat("  Total population:    ", format(sum(model_table$total_pop, na.rm = TRUE), big.mark = ","), "\n")
cat("  Observed CHD cases:  ", format(round(sum(model_table$observed_gp_cases, na.rm = TRUE)), big.mark = ","), "\n\n")

# National rate diagnostics
national_rate_observed <- sum(model_table$observed_gp_cases, na.rm = TRUE) /
                         sum(model_table$total_pop, na.rm = TRUE) * 100

cat("National CHD prevalence:\n")
cat("  Published (QOF):     2.970%\n")
cat("  Observed (GP data):  ", round(national_rate_observed, 3), "%\n\n")

# ================================================================
# SECTION 2: METHOD 1A - CRUDE EXPECTED VALUES
# ================================================================

cat("========================================\n")
cat("METHOD 1A: CRUDE EXPECTED VALUES\n")
cat("========================================\n\n")

model_table <- model_table %>%
  mutate(
    method1a_crude_cases = total_pop * 0.0297,
    method1a_crude_prev  = 2.97
  )

cat("Using published QOF national rate: 2.97%\n")
cat("Total expected cases: ", format(round(sum(model_table$method1a_crude_cases)), big.mark = ","), "\n")
cat("Method 1A complete\n\n")

# ================================================================
# SECTION 3: METHOD 1B - AGE-SEX STANDARDIZATION
# ================================================================

cat("========================================\n")
cat("METHOD 1B: AGE-SEX STANDARDIZATION\n")
cat("========================================\n\n")

cat("Deriving age-sex rates by averaging across IMD quintiles...\n")

# Create age-sex only rates by averaging across IMD quintiles
nat_rates_age_sex <- nat_rates_1 %>%
  group_by(age_group) %>%
  summarise(
    male_prev_rate   = mean(as.numeric(male_prev_pct), na.rm = TRUE),
    female_prev_rate = mean(as.numeric(female_prev_pct), na.rm = TRUE),
    .groups = "drop"
  )

# Reshape to long format
nat_rates_age_sex_long <- nat_rates_age_sex %>%
  pivot_longer(
    cols = c(male_prev_rate, female_prev_rate),
    names_to = "sex_type",
    values_to = "prevalence_rate"
  ) %>%
  mutate(
    sex = case_when(
      sex_type == "male_prev_rate"   ~ "Male",
      sex_type == "female_prev_rate" ~ "Female"
    )
  ) %>%
  select(age_group, sex, prevalence_rate) %>%
  filter(!is.na(prevalence_rate))

cat("Age-sex rates derived (averaged across",
    length(unique(nat_rates_1$imd_quintile)), "IMD quintiles)\n")

# Join population data with age-sex rates (no IMD)
pop_age_sex <- pop_by_age_group_2 %>%
  select(lad_code, lsoa_code, sex, age_group, population) %>%
  left_join(
    nat_rates_age_sex_long,
    by = c("age_group" = "age_group", "sex" = "sex")
  )

# Check for missing rates
missing_rates_1b <- sum(is.na(pop_age_sex$prevalence_rate))
cat("Missing prevalence rates: ", missing_rates_1b, "\n")

if(missing_rates_1b > 0) {
  cat("Note: Missing rates typically due to Welsh LSOAs (no IMD data)\n")
}

# Calculate expected cases for each stratum
pop_age_sex <- pop_age_sex %>%
  filter(!is.na(prevalence_rate)) %>%
  mutate(
    expected_cases_stratum = population * (prevalence_rate)
  )

# Aggregate to LSOA level
lsoa_age_sex_std <- pop_age_sex %>%
  group_by(lad_code, lsoa_code) %>%
  summarise(
    method1b_age_sex_cases = sum(expected_cases_stratum, na.rm = TRUE),
    .groups = "drop"
  )

# Join with total population for prevalence calculation
lsoa_age_sex_std <- lsoa_age_sex_std %>%
  left_join(
    model_table %>% select(lsoa_code, total_pop),
    by = "lsoa_code"
  ) %>%
  mutate(
    method1b_age_sex_prev = (method1b_age_sex_cases / total_pop) * 100
  )

# Add to model table
model_table <- model_table %>%
  left_join(
    lsoa_age_sex_std %>% select(lsoa_code, method1b_age_sex_cases, method1b_age_sex_prev),
    by = "lsoa_code"
  )

cat("Method 1B complete\n")
cat("  Mean prevalence: ", round(mean(model_table$method1b_age_sex_prev, na.rm = TRUE), 3), "%\n")
cat("  SD prevalence:   ", round(sd(model_table$method1b_age_sex_prev, na.rm = TRUE), 3), "%\n\n")

# ================================================================
# SECTION 4: METHOD 1C - AGE-SEX-IMD STANDARDIZATION
# ================================================================

cat("========================================\n")
cat("METHOD 1C: AGE-SEX-IMD STANDARDIZATION\n")
cat("========================================\n\n")

# This was calculated in a previous script and joined earlier
# Just join to the table
model_table <- model_table %>%
  left_join(
    lsoa_standardized %>% select(lsoa_code, method1b_standardized_cases, method1b_standardized_prev),
    by = "lsoa_code"
  )

# Rename to method1c for consistency
model_table <- model_table %>%
  rename(
    method1c_age_sex_imd_cases = method1b_standardized_cases,
    method1c_age_sex_imd_prev  = method1b_standardized_prev
  )

cat("Method 1C using pre-calculated age-sex-IMD standardization\n")
cat("  Mean prevalence: ", round(mean(model_table$method1c_age_sex_imd_prev, na.rm = TRUE), 3), "%\n")
cat("  SD prevalence:   ", round(sd(model_table$method1c_age_sex_imd_prev, na.rm = TRUE), 3), "%\n\n")

# ================================================================
# SECTION 5: METHOD 2A - RANDOM CV HIERARCHICAL MODEL
# ================================================================

cat("========================================\n")
cat("METHOD 2A: HIERARCHICAL MODEL\n")
cat("Random Cross-Validation at LSOA Level\n")
cat("Scenario: Infilling within known regions\n")
cat("========================================\n\n")

set.seed(123)
folds_random <- createFolds(1:nrow(model_table), k = 10, returnTrain = FALSE)

cv_predictions_2a <- rep(NA, nrow(model_table))

for(i in 1:10) {
  cat("  Processing fold", i, "of 10...\r")

  train_idx <- which(!(1:nrow(model_table) %in% folds_random[[i]]))
  test_idx  <- folds_random[[i]]

  model_2a <- glmer(
    round(observed_gp_cases) ~ as.numeric(IMD_decile) +
      offset(log(method1a_crude_cases)) + (1 | lad_code),
    data    = model_table[train_idx, ],
    family  = poisson(link = "log"),
    control = glmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 2e5))
  )

  cv_predictions_2a[test_idx] <- predict(
    model_2a,
    newdata = model_table[test_idx, ],
    type = "response",
    allow.new.levels = TRUE
  )
}

model_table$method2a_random_cv_cases <- cv_predictions_2a
model_table$method2a_random_cv_prev  <- (cv_predictions_2a / model_table$total_pop) * 100

cat("\nMethod 2A complete\n\n")

# ================================================================
# SECTION 6: METHOD 2B - LAD-BLOCKED CV HIERARCHICAL MODEL
# ================================================================

cat("========================================\n")
cat("METHOD 2B: HIERARCHICAL MODEL\n")
cat("LAD-Blocked Cross-Validation\n")
cat("Scenario: Predicting entirely new regions\n")
cat("========================================\n\n")

# Get unique LADs
unique_lads <- unique(model_table$lad_code)
n_lads      <- length(unique_lads)

cat("Total LADs: ", n_lads, "\n")

# Create LAD-level folds
set.seed(123)
folds_lad <- createFolds(1:n_lads, k = 10, returnTrain = FALSE)

cv_predictions_2b <- rep(NA, nrow(model_table))

for(i in 1:10) {
  cat("  Processing fold", i, "of 10 (LAD-blocked)...\r")

  # Get LADs in test fold
  test_lad_indices <- folds_lad[[i]]
  test_lads        <- unique_lads[test_lad_indices]

  # Get LSOA indices
  test_idx  <- which(model_table$lad_code %in% test_lads)
  train_idx <- which(!(model_table$lad_code %in% test_lads))

  # Fit model on training LADs only
  model_2b <- glmer(
    round(observed_gp_cases) ~ as.numeric(IMD_decile) +
      offset(log(method1a_crude_cases)) + (1 | lad_code),
    data    = model_table[train_idx, ],
    family  = poisson(link = "log"),
    control = glmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 2e5))
  )

  # Predict for entirely unseen LADs
  cv_predictions_2b[test_idx] <- predict(
    model_2b,
    newdata = model_table[test_idx, ],
    type = "response",
    allow.new.levels = TRUE
  )
}

model_table$method2b_lad_blocked_cv_cases <- cv_predictions_2b
model_table$method2b_lad_blocked_cv_prev  <- (cv_predictions_2b / model_table$total_pop) * 100

cat("\nMethod 2B complete\n\n")

# ================================================================
# SECTION 7: VALIDATION METRICS
# ================================================================

cat("========================================\n")
cat("VALIDATION AGAINST OBSERVED GP DATA\n")
cat("========================================\n\n")

# Define method labels
method_labels <- c(
  "1A: Crude",
  "1B: Age-Sex Standardized",
  "1C: Age-Sex-IMD Standardized",
  "2A: Hierarchical (Random CV)",
  "2B: Hierarchical (LAD-Blocked CV)"
)

# Define complexity tiers
complexity_tier <- c(
  "Simple",
  "Simple",
  "Simple",
  "Complex",
  "Complex"
)

# Define scenarios
scenario <- c(
  "Baseline (no demographic adjustment)",
  "Demographic adjustment (age, sex)",
  "Demographic adjustment (age, sex, deprivation)",
  "Infilling within known regions",
  "Predicting entirely new regions"
)

# List of prediction vectors
pred_list <- list(
  model_table$method1a_crude_cases,
  model_table$method1b_age_sex_cases,
  model_table$method1c_age_sex_imd_cases,
  model_table$method2a_random_cv_cases,
  model_table$method2b_lad_blocked_cv_cases
)

obs <- model_table$observed_gp_cases

# Calculate validation metrics
validation_results <- data.frame(
  Method     = method_labels,
  Complexity = complexity_tier,
  Scenario   = scenario,

  Spearman = sapply(pred_list, function(p)
    round(cor(p, obs, method = "spearman", use = "complete.obs"), 3)),

  Pearson = sapply(pred_list, function(p)
    round(cor(p, obs, method = "pearson", use = "complete.obs"), 3)),

  MAE = sapply(pred_list, function(p)
    round(mean(abs(p - obs), na.rm = TRUE), 2)),

  RMSE = sapply(pred_list, function(p)
    round(sqrt(mean((p - obs)^2, na.rm = TRUE)), 2)),

  Median_AE = sapply(pred_list, function(p)
    round(median(abs(p - obs), na.rm = TRUE), 2))
)

# Calculate concordance correlation coefficients
cat("Calculating concordance correlation coefficients...\n")
ccc_results <- data.frame(
  Method = method_labels,
  CCC    = NA,
  CCC_LB = NA,
  CCC_UB = NA
)

for(i in seq_along(pred_list)) {
  complete_idx <- complete.cases(data.frame(pred_list[[i]], obs))
  if(sum(complete_idx) > 10) {
    ccc_obj <- epi.ccc(pred_list[[i]][complete_idx], obs[complete_idx])
    ccc_results$CCC[i]    <- round(ccc_obj$rho.c[1,1], 3)
    ccc_results$CCC_LB[i] <- round(ccc_obj$rho.c[1,2], 3)
    ccc_results$CCC_UB[i] <- round(ccc_obj$rho.c[1,3], 3)
  }
}

# Combine results
validation_full <- validation_results %>%
  left_join(ccc_results, by = "Method")

# Print results
cat("\n")
print(validation_full)
cat("\n")

# Calculate top 10% overlap
cat("Calculating high-need area identification (Top 10%)...\n")

obs_threshold <- quantile(obs, 0.9, na.rm = TRUE)

model_table <- model_table %>%
  mutate(
    observed_top10    = observed_gp_cases >= obs_threshold,
    m1a_top10         = method1a_crude_cases >= quantile(method1a_crude_cases, 0.9, na.rm = TRUE),
    m1b_top10         = method1b_age_sex_cases >= quantile(method1b_age_sex_cases, 0.9, na.rm = TRUE),
    m1c_top10         = method1c_age_sex_imd_cases >= quantile(method1c_age_sex_imd_cases, 0.9, na.rm = TRUE),
    m2a_top10         = method2a_random_cv_cases >= quantile(method2a_random_cv_cases, 0.9, na.rm = TRUE),
    m2b_top10         = method2b_lad_blocked_cv_cases >= quantile(method2b_lad_blocked_cv_cases, 0.9, na.rm = TRUE)
  )

top10_flags <- list(
  model_table$m1a_top10,
  model_table$m1b_top10,
  model_table$m1c_top10,
  model_table$m2a_top10,
  model_table$m2b_top10
)

top10_results <- data.frame(
  Method      = method_labels,
  # Change the denominator to the count of TRUE observed_top10 values
  Overlap_Pct = sapply(top10_flags, function(flag) {
    matches <- sum(flag & model_table$observed_top10, na.rm = TRUE)
    total_targets <- sum(model_table$observed_top10, na.rm = TRUE)
    round((matches / total_targets) * 100, 1)
  })
)

cat("\n")
print(top10_results)
cat("\n")

# ================================================================
# SECTION 8: KEY FINDINGS SUMMARY
# ================================================================

cat("========================================\n")
cat("KEY FINDINGS SUMMARY\n")
cat("========================================\n\n")

cat("1. EXPECTED VALUE MODELS (Simple Methods):\n")
cat("   1A: Crude                    ρ = ", validation_full$Spearman[1], "\n")
cat("   1B: Age-Sex                  ρ = ", validation_full$Spearman[2],
    " (+", round(validation_full$Spearman[2] - validation_full$Spearman[1], 3), ")\n")
cat("   1C: Age-Sex-IMD              ρ = ", validation_full$Spearman[3],
    " (+", round(validation_full$Spearman[3] - validation_full$Spearman[1], 3), ")\n\n")

cat("2. HIERARCHICAL MODELS:\n")
cat("   2A: Random CV (infilling)    ρ = ", validation_full$Spearman[4], "\n")
cat("   2B: LAD-blocked (new regions) ρ = ", validation_full$Spearman[5], "\n\n")

spatial_leakage <- validation_full$Spearman[4] - validation_full$Spearman[5]
cat("3. SPATIAL LEAKAGE:\n")
cat("   Performance drop (2A → 2B):  ", round(spatial_leakage, 3), "\n")
if(spatial_leakage > 0.15) {
  cat("   Assessment: SEVERE spatial autocorrelation\n")
  cat("   Random CV substantially inflated by geographic memorization\n")
} else if(spatial_leakage > 0.10) {
  cat("   Assessment: SUBSTANTIAL spatial autocorrelation\n")
  cat("   Random CV inflated by learning LAD-specific patterns\n")
} else if(spatial_leakage > 0.05) {
  cat("   Assessment: MODERATE spatial autocorrelation\n")
  cat("   Some inflation from LAD knowledge in random CV\n")
} else {
  cat("   Assessment: MINIMAL spatial autocorrelation\n")
  cat("   Model generalizes well to unseen regions\n")
}
cat("\n")

cat("4. TOP 10% HIGH-NEED AREA IDENTIFICATION:\n")
for(i in 1:nrow(top10_results)) {
  cat(sprintf("   %-32s %5.1f%%\n",
              top10_results$Method[i],
              top10_results$Overlap_Pct[i]))
}
cat("\n")

cat("5. RECOMMENDATIONS:\n")
cat("   For infilling (LSOAs in known regions):\n")
cat("     → Method 2A: Hierarchical Random CV\n")
cat("     → Performance: ρ = ", validation_full$Spearman[4], "\n")
cat("     → Top 10% identification: ", top10_results$Overlap_Pct[4], "%\n\n")

cat("   For predicting entirely new regions:\n")
if(validation_full$Spearman[5] > validation_full$Spearman[3] + 0.02) {
  cat("     → Method 2B: Hierarchical LAD-Blocked CV\n")
  cat("     → Performance: ρ = ", validation_full$Spearman[5], "\n")
} else {
  cat("     → Method 1C: Age-Sex-IMD Standardization\n")
  cat("     → Performance: ρ = ", validation_full$Spearman[3], "\n")
  cat("     → Note: Hierarchical model (2B) offers no improvement\n")
  cat("            over simple standardization for new regions\n")
}
cat("\n")

# ================================================================
# SECTION 9: PROFESSIONAL VISUALIZATIONS
# ================================================================

cat("========================================\n")
cat("CREATING VISUALIZATIONS\n")
cat("========================================\n\n")

# Define consistent color palette
method_colors <- c(
  "#E57373",  # 1A: Light red (crude)
  "#FFB74D",  # 1B: Light orange (age-sex)
  "#81C784",  # 1C: Light green (age-sex-imd)
  "#64B5F6",  # 2A: Light blue (random cv)
  "#9575CD"   # 2B: Light purple (lad-blocked cv)
)

# ----------------------------------------------------------------
# PLOT 1: MAIN PERFORMANCE COMPARISON
# ----------------------------------------------------------------

cat("Creating main performance comparison plot...\n")

pdf("1_Performance_Comparison.pdf", width = 10, height = 6)

# Create data for plotting
plot_data <- data.frame(
  Method     = factor(method_labels, levels = method_labels),
  Spearman   = validation_full$Spearman,
  Complexity = factor(complexity_tier, levels = c("Simple", "Complex")),
  Color      = method_colors
)

p1 <- ggplot(plot_data, aes(x = Method, y = Spearman, fill = Method)) +
  geom_bar(stat = "identity", width = 0.7, alpha = 0.9) +
  geom_hline(yintercept = c(0.4, 0.6, 0.8), linetype = "dashed",
             color = "gray50", alpha = 0.5) +
  geom_text(aes(label = sprintf("%.3f", Spearman)),
            vjust = -0.5, size = 4, fontface = "bold") +
  scale_fill_manual(values = method_colors) +
  scale_y_continuous(limits = c(0, 1.0), breaks = seq(0, 1, 0.2),
                    labels = scales::number_format(accuracy = 0.1)) +
  labs(
    title = "Prevalence Estimation Methods: Validation Performance",
    subtitle = "Spearman rank correlation with observed GP data",
    x = NULL,
    y = "Spearman ρ (rank correlation)",
    caption = "Higher values indicate better agreement with observed data"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", size = 14, hjust = 0),
    plot.subtitle = element_text(size = 11, hjust = 0, color = "gray30"),
    axis.text.x = element_text(angle = 45, hjust = 1, size = 10),
    axis.text.y = element_text(size = 10),
    axis.title.y = element_text(size = 11, face = "bold"),
    panel.grid.major.x = element_blank(),
    panel.grid.minor = element_blank(),
    legend.position = "none",
    plot.caption = element_text(size = 9, color = "gray50", hjust = 1)
  )

print(p1)
dev.off()

cat("  Saved: 1_Performance_Comparison.pdf\n")

# ----------------------------------------------------------------
# PLOT 2: SCATTER PLOT GRID
# ----------------------------------------------------------------

cat("Creating scatter plot grid...\n")

pdf("2_Scatter_Plot_Grid.pdf", width = 14, height = 10)

par(mfrow = c(2, 3), mar = c(4.5, 4.5, 3, 1))

for(i in 1:5) {
  p   <- pred_list[[i]]
  rho <- validation_full$Spearman[i]

  complete_idx <- complete.cases(data.frame(p, obs))
  p_c   <- p[complete_idx]
  obs_c <- obs[complete_idx]

  # Scatter plot
  plot(obs_c, p_c,
       xlab = "Observed GP Cases",
       ylab = "Predicted Cases",
       main = method_labels[i],
       pch = 16,
       col = adjustcolor(method_colors[i], alpha.f = 0.3),
       cex = 0.6,
       cex.main = 1.1,
       cex.lab = 1.0)

  # Perfect agreement line
  abline(0, 1, col = "red", lwd = 2, lty = 2)

  # Fitted line
  fit <- lm(p_c ~ obs_c)
  abline(fit, col = "blue", lwd = 2, lty = 1)

  # Calculate R2 and Rho for the legend
  r_squared <- summary(fit)$r.squared

  # Unified Legend with integrated Stats and Background masking
  legend("topleft",
         legend = c(
           sprintf("ρ = %.3f", rho),
           sprintf("R² = %.3f", r_squared), # Integrated R2
           "Perfect agreement",
           "Fitted relationship"
         ),
         col = c("black", "gray30", "red", "blue"),
         lty = c(NA, NA, 2, 1),
         lwd = c(NA, NA, 2, 2),
         pch = c(16, NA, NA, NA),
         bty = "n",                # "o" adds a box/background
         cex = 0.85)          # Adds vertical space for clarity
}

dev.off()

cat("  Saved: 2_Scatter_Plot_Grid.pdf\n")

# ----------------------------------------------------------------
# PLOT 3: SPATIAL LEAKAGE ANALYSIS
# ----------------------------------------------------------------

cat("Creating spatial leakage analysis plot...\n")

pdf("3_Spatial_Leakage_Analysis.pdf", width = 10, height = 6)

leakage_data <- data.frame(
  CV_Type = c("Random CV\n(Infilling)", "LAD-Blocked CV\n(New Regions)"),
  Spearman = c(validation_full$Spearman[4], validation_full$Spearman[5]),
  Color = c(method_colors[4], method_colors[5])
)

p3 <- ggplot(leakage_data, aes(x = CV_Type, y = Spearman, fill = CV_Type)) +
  geom_bar(stat = "identity", width = 0.6, alpha = 0.9) +
  geom_hline(yintercept = validation_full$Spearman[3],
             linetype = "dashed", color = "darkgreen", linewidth = 1) +
  geom_text(aes(label = sprintf("%.3f", Spearman)),
            vjust = -0.5, size = 5, fontface = "bold") +
  annotate("text", x = 1.5, y = validation_full$Spearman[3] + 0.03,
           label = sprintf("Age-Sex-IMD Standardization (ρ = %.3f)",
                          validation_full$Spearman[3]),
           color = "darkgreen", size = 3.5, fontface = "italic") +
  annotate("segment",
           x = 1, xend = 2,
           y = validation_full$Spearman[4],
           yend = validation_full$Spearman[5],
           arrow = arrow(length = unit(0.3, "cm")),
           color = "red", linewidth = 1) +
  annotate("text", x = 1.5,
           y = mean(c(validation_full$Spearman[4], validation_full$Spearman[5])),
           label = sprintf("Drop: %.3f\n(Spatial leakage)", spatial_leakage),
           color = "red", size = 3.5, fontface = "bold", vjust = -0.5) +
  scale_fill_manual(values = c(method_colors[4], method_colors[5])) +
  scale_y_continuous(limits = c(0, 1), breaks = seq(0, 1, 0.2)) +
  labs(
    title = "Spatial Leakage in Hierarchical Models",
    subtitle = "Performance drop reveals dependence on geographic context",
    x = NULL,
    y = "Spearman ρ (rank correlation)",
    caption = paste0("Large performance drop (", round(spatial_leakage, 3),
                    ") indicates Random CV inflated by learning LAD-specific patterns")
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", size = 14, hjust = 0),
    plot.subtitle = element_text(size = 11, hjust = 0, color = "gray30"),
    axis.text.x = element_text(size = 11, face = "bold"),
    axis.text.y = element_text(size = 10),
    axis.title.y = element_text(size = 11, face = "bold"),
    panel.grid.major.x = element_blank(),
    legend.position = "none",
    plot.caption = element_text(size = 9, color = "gray50", hjust = 0)
  )

print(p3)
dev.off()

cat("  Saved: 3_Spatial_Leakage_Analysis.pdf\n")

# ----------------------------------------------------------------
# PLOT 4: TOP 10% IDENTIFICATION
# ----------------------------------------------------------------

cat("Creating top 10% identification plot...\n")

pdf("4_Top10_Identification.pdf", width = 10, height = 6)

top10_plot_data <- data.frame(
  Method      = factor(method_labels, levels = method_labels),
  Overlap_Pct = top10_results$Overlap_Pct,
  Color       = method_colors
)

p4 <- ggplot(top10_plot_data, aes(x = Method, y = Overlap_Pct, fill = Method)) +
  geom_bar(stat = "identity", width = 0.7, alpha = 0.9) +
  geom_hline(yintercept = 50, linetype = "dashed", color = "red", linewidth = 0.8) +
  geom_text(aes(label = sprintf("%.1f%%", Overlap_Pct)),
            vjust = -0.5, size = 4, fontface = "bold") +
  annotate("text", x = 5, y = 52,
           label = "Chance level (50%)",
           color = "red", size = 3.5, hjust = 1) +
  scale_fill_manual(values = method_colors) +
  scale_y_continuous(limits = c(0, 100), breaks = seq(0, 100, 20),
                    labels = function(x) paste0(x, "%")) +
  labs(
    title = "High-Need Area Identification Performance",
    subtitle = "Percentage of true top 10% high-prevalence LSOAs correctly identified",
    x = NULL,
    y = "Overlap with Observed Top 10% (%)",
    caption = "Critical metric for site planning decisions: identifies LSOAs requiring intervention"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", size = 14, hjust = 0),
    plot.subtitle = element_text(size = 11, hjust = 0, color = "gray30"),
    axis.text.x = element_text(angle = 45, hjust = 1, size = 10),
    axis.text.y = element_text(size = 10),
    axis.title.y = element_text(size = 11, face = "bold"),
    panel.grid.major.x = element_blank(),
    panel.grid.minor = element_blank(),
    legend.position = "none",
    plot.caption = element_text(size = 9, color = "gray50", hjust = 0)
  )

print(p4)
dev.off()

cat("  Saved: 4_Top10_Identification.pdf\n")

# ----------------------------------------------------------------
# PLOT 5: METHOD PROGRESSION
# ----------------------------------------------------------------

cat("Creating method progression plot...\n")

pdf("5_Method_Progression.pdf", width = 10, height = 6)

progression_data <- data.frame(
  Step     = 1:5,
  Method   = method_labels,
  Spearman = validation_full$Spearman,
  Type     = c("Simple", "Simple", "Simple", "Complex", "Complex")
)

p5 <- ggplot(progression_data, aes(x = Step, y = Spearman)) +
  geom_line(linewidth = 1.2, color = "gray40") +
  geom_point(aes(color = Method), size = 5, alpha = 0.9) +
  geom_text(aes(label = Method),
            vjust = -1, hjust = 0.5, size = 3.5, fontface = "bold") +
  geom_text(aes(label = sprintf("ρ = %.3f", Spearman)),
            vjust = 1.8, size = 3.5, color = "gray30") +
  scale_color_manual(values = method_colors) +
  scale_x_continuous(breaks = 1:5, labels = paste("Step", 1:5)) +
  scale_y_continuous(limits = c(0.3, 1.0), breaks = seq(0.3, 1.0, 0.1)) +
  labs(
    title = "Method Complexity vs. Performance",
    subtitle = "Progression from simple to complex estimation approaches",
    x = "Increasing Complexity →",
    y = "Spearman ρ (rank correlation)",
    caption = "Note: Step 5 (LAD-blocked CV) shows performance for entirely new regions only"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", size = 14, hjust = 0),
    plot.subtitle = element_text(size = 11, hjust = 0, color = "gray30"),
    axis.text = element_text(size = 10),
    axis.title = element_text(size = 11, face = "bold"),
    panel.grid.minor = element_blank(),
    legend.position = "none",
    plot.caption = element_text(size = 9, color = "gray50", hjust = 0)
  )

print(p5)
dev.off()

cat("  Saved: 5_Method_Progression.pdf\n\n")

# ================================================================
# SECTION 10: EXPORT RESULTS
# ================================================================

cat("========================================\n")
cat("EXPORTING RESULTS\n")
cat("========================================\n\n")

# Main validation results
write.csv(validation_full, "Validation_Results.csv", row.names = FALSE)
cat("  Saved: Validation_Results.csv\n")

# Top 10% results
write.csv(top10_results, "Top10_Identification.csv", row.names = FALSE)
cat("  Saved: Top10_Identification.csv\n")

# Full predictions dataset
predictions_export <- model_table %>%
  select(
    lad_code,
    lsoa_code,
    total_pop,
    observed_gp_cases,
    method1a_crude_cases,
    method1b_age_sex_cases,
    method1c_age_sex_imd_cases,
    method2a_random_cv_cases,
    method2b_lad_blocked_cv_cases
  )

write.csv(predictions_export, "All_Method_Predictions.csv", row.names = FALSE)
cat("  Saved: All_Method_Predictions.csv\n\n")

# ================================================================
# SECTION 11: FINAL SUMMARY
# ================================================================

cat("========================================\n")
cat("ANALYSIS COMPLETE\n")
cat("========================================\n\n")

cat("Output files created:\n")
cat("  CSV files:\n")
cat("    - Validation_Results.csv\n")
cat("    - Top10_Identification.csv\n")
cat("    - All_Method_Predictions.csv\n\n")

cat("  Visualization PDFs:\n")
cat("    - 1_Performance_Comparison.pdf\n")
cat("    - 2_Scatter_Plot_Grid.pdf\n")
cat("    - 3_Spatial_Leakage_Analysis.pdf\n")
cat("    - 4_Top10_Identification.pdf\n")
cat("    - 5_Method_Progression.pdf\n\n")

cat("For sensitivity analysis (standardized offset), run:\n")
cat("  Dark_Peak_Sensitivity_Analysis.R\n\n")

cat("========================================\n")
