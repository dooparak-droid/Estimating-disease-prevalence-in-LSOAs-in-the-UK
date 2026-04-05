# ================================================================
# DARK PEAK ANALYTICS - SENSITIVITY ANALYSIS
# ================================================================
#
# This script examines how hierarchical model performance changes
# when using standardized offset instead of crude offset.
#
# COMPARISON:
#   Main Analysis:    Crude offset + IMD predictor
#   Sensitivity:      Standardized offset (no IMD predictor)
#
# KEY QUESTION:
#   Does using age-sex-IMD standardized expected values as the
#   offset reduce spatial leakage in cross-validation?
#
# ================================================================

library(dplyr)
library(lme4)
library(ggplot2)
library(gridExtra)
library(scales)
library(caret)

# ================================================================
# SECTION 1: OVERVIEW
# ================================================================

cat("\n========================================\n")
cat("SENSITIVITY ANALYSIS\n")
cat("Offset Type Comparison\n")
cat("========================================\n\n")

cat("This analysis compares:\n")
cat("  A) Crude offset + IMD predictor (main analysis)\n")
cat("  B) Standardized offset, no IMD (sensitivity)\n\n")

cat("Expected finding:\n")
cat("  Standardized offset should reduce spatial leakage\n")
cat("  because demographics are already embedded in the offset,\n")
cat("  leaving LAD random effects to capture only residual\n")
cat("  regional variation.\n\n")

# Verify required columns exist
required_cols <- c("method1a_crude_cases", "method1c_age_sex_imd_cases",
                   "method2a_random_cv_cases", "method2b_lad_blocked_cv_cases")

missing_cols <- required_cols[!required_cols %in% names(model_table)]
if(length(missing_cols) > 0) {
  stop("Error: Please run Dark_Peak_Final_Analysis.R first.\n",
       "Missing columns: ", paste(missing_cols, collapse = ", "))
}

# ================================================================
# SECTION 2: RANDOM CV WITH STANDARDIZED OFFSET
# ================================================================

cat("========================================\n")
cat("RANDOM CV - STANDARDIZED OFFSET\n")
cat("========================================\n\n")

set.seed(123)
folds_random <- createFolds(1:nrow(model_table), k = 10, returnTrain = FALSE)

cv_predictions_sens_random <- rep(NA, nrow(model_table))

for(i in 1:10) {
  cat("  Processing fold", i, "of 10...\r")

  train_idx <- which(!(1:nrow(model_table) %in% folds_random[[i]]))
  test_idx  <- folds_random[[i]]

  model_sens <- glmer(
    round(observed_gp_cases) ~
      offset(log(method1c_age_sex_imd_cases)) + (1 | lad_code),
    data    = model_table[train_idx, ],
    family  = poisson(link = "log"),
    control = glmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 2e5))
  )

  cv_predictions_sens_random[test_idx] <- predict(
    model_sens,
    newdata = model_table[test_idx, ],
    type = "response",
    allow.new.levels = TRUE
  )
}

model_table$sens_random_cv_std_cases <- cv_predictions_sens_random

cat("\nRandom CV with standardized offset complete\n\n")

# ================================================================
# SECTION 3: LAD-BLOCKED CV WITH STANDARDIZED OFFSET
# ================================================================

cat("========================================\n")
cat("LAD-BLOCKED CV - STANDARDIZED OFFSET\n")
cat("========================================\n\n")

unique_lads <- unique(model_table$lad_code)
n_lads      <- length(unique_lads)

set.seed(123)
folds_lad <- createFolds(1:n_lads, k = 10, returnTrain = FALSE)

cv_predictions_sens_blocked <- rep(NA, nrow(model_table))

for(i in 1:10) {
  cat("  Processing fold", i, "of 10 (LAD-blocked)...\r")

  test_lad_indices <- folds_lad[[i]]
  test_lads        <- unique_lads[test_lad_indices]

  test_idx  <- which(model_table$lad_code %in% test_lads)
  train_idx <- which(!(model_table$lad_code %in% test_lads))

  model_sens_blocked <- glmer(
    round(observed_gp_cases) ~
      offset(log(method1c_age_sex_imd_cases)) + (1 | lad_code),
    data    = model_table[train_idx, ],
    family  = poisson(link = "log"),
    control = glmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 2e5))
  )

  cv_predictions_sens_blocked[test_idx] <- predict(
    model_sens_blocked,
    newdata = model_table[test_idx, ],
    type = "response",
    allow.new.levels = TRUE
  )
}

model_table$sens_blocked_cv_std_cases <- cv_predictions_sens_blocked

cat("\nLAD-blocked CV with standardized offset complete\n\n")

# ================================================================
# SECTION 4: COMPARISON METRICS
# ================================================================

cat("========================================\n")
cat("PERFORMANCE COMPARISON\n")
cat("========================================\n\n")

obs <- model_table$observed_gp_cases

# Calculate correlations
comparison_results <- data.frame(
  Offset_Type = rep(c("Crude + IMD", "Standardized (no IMD)"), each = 2),
  CV_Strategy = rep(c("Random CV", "LAD-Blocked CV"), times = 2),

  Spearman = c(
    # Crude offset (from main analysis)
    cor(model_table$method2a_random_cv_cases, obs,
        method = "spearman", use = "complete.obs"),
    cor(model_table$method2b_lad_blocked_cv_cases, obs,
        method = "spearman", use = "complete.obs"),

    # Standardized offset (sensitivity)
    cor(model_table$sens_random_cv_std_cases, obs,
        method = "spearman", use = "complete.obs"),
    cor(model_table$sens_blocked_cv_std_cases, obs,
        method = "spearman", use = "complete.obs")
  )
)

comparison_results <- comparison_results %>%
  mutate(Spearman = round(Spearman, 3))

print(comparison_results)
cat("\n")

# Calculate spatial leakage for each offset type
leakage_crude <- comparison_results$Spearman[1] - comparison_results$Spearman[2]
leakage_std   <- comparison_results$Spearman[3] - comparison_results$Spearman[4]

cat("SPATIAL LEAKAGE (Random → Blocked performance drop):\n")
cat("  Crude offset + IMD:      ", round(leakage_crude, 3), "\n")
cat("  Standardized offset:     ", round(leakage_std, 3), "\n")
cat("  Reduction in leakage:    ", round(leakage_crude - leakage_std, 3), "\n\n")

if(leakage_crude - leakage_std > 0.1) {
  cat("FINDING: Standardized offset SUBSTANTIALLY reduces spatial leakage\n")
  cat("  Standardization embeds demographic patterns in the offset,\n")
  cat("  preventing the model from learning them as LAD effects.\n\n")
} else if(leakage_crude - leakage_std > 0.05) {
  cat("FINDING: Standardized offset MODERATELY reduces spatial leakage\n")
  cat("  Some benefit from embedding demographics in the offset.\n\n")
} else {
  cat("FINDING: Standardized offset does NOT substantially reduce leakage\n")
  cat("  Spatial leakage is driven by factors other than demographics.\n\n")
}

# Compare to simple standardization baseline
std_baseline <- cor(model_table$method1c_age_sex_imd_cases, obs,
                   method = "spearman", use = "complete.obs")

cat("COMPARISON TO SIMPLE STANDARDIZATION (Method 1C):\n")
cat("  Baseline (no model):     ρ = ", round(std_baseline, 3), "\n")
cat("  Random CV (std offset):  ρ = ", comparison_results$Spearman[3],
    " (+", round(comparison_results$Spearman[3] - std_baseline, 3), ")\n")
cat("  Blocked CV (std offset): ρ = ", comparison_results$Spearman[4],
    " (+", round(comparison_results$Spearman[4] - std_baseline, 3), ")\n\n")

if(abs(comparison_results$Spearman[4] - std_baseline) < 0.01) {
  cat("FINDING: Hierarchical model adds NO value over simple standardization\n")
  cat("  for predicting new regions. Use Method 1C for simplicity.\n\n")
} else if(comparison_results$Spearman[4] > std_baseline + 0.05) {
  cat("FINDING: Hierarchical model provides meaningful improvement\n")
  cat("  even for new regions (Δρ = ",
      round(comparison_results$Spearman[4] - std_baseline, 3), ").\n\n")
} else {
  cat("FINDING: Hierarchical model provides modest improvement\n")
  cat("  over simple standardization for new regions.\n\n")
}

# ================================================================
# SECTION 5: VISUALIZATIONS
# ================================================================

cat("========================================\n")
cat("CREATING VISUALIZATIONS\n")
cat("========================================\n\n")

pdf("Sensitivity_Analysis_Results.pdf", width = 12, height = 8)

# ----------------------------------------------------------------
# PLOT 1: OFFSET COMPARISON
# ----------------------------------------------------------------

par(mfrow = c(2, 2), mar = c(4, 4, 3, 2))

# Define colors
color_crude <- "#E57373"  # Light red
color_std   <- "#81C784"  # Light green

par(mfrow = c(2, 2), mar = c(4, 4, 3, 5))

# --- Plot 1: Random CV comparison ---
barplot_data_random <- c(comparison_results$Spearman[1],
                         comparison_results$Spearman[3])
bp1 <- barplot(barplot_data_random,
               names.arg = c("Crude + IMD", "Std (no IMD)"),
               main = "Random CV: Offset Comparison",
               ylab = "Spearman ρ",
               col = c(color_crude, color_std),
               ylim = c(0, 1),
               las = 1)

text(bp1, barplot_data_random + 0.05,
     labels = sprintf("%.3f", barplot_data_random),
     cex = 1.1, font = 2)

# FIX: Draw the line
abline(h = std_baseline, lty = 2, col = "darkgreen", lwd = 2)

# FIX: Adjust 'x' to 1.5 (center-ish) and use 'pos=3' (above line)
# or keep 'pos=4' but increase the right margin as we did above.
text(x = 0.2, y = std_baseline + 0.04,
     labels = sprintf("Baseline (1C): %.3f", std_baseline),
     adj = 0, cex = 0.85, col = "darkgreen", font = 2)


# --- Plot 2: LAD-Blocked CV comparison ---
barplot_data_blocked <- c(comparison_results$Spearman[2],
                          comparison_results$Spearman[4])
bp2 <- barplot(barplot_data_blocked,
               names.arg = c("Crude + IMD", "Std (no IMD)"),
               main = "LAD-Blocked CV: Offset Comparison",
               ylab = "Spearman ρ",
               col = c(color_crude, color_std),
               ylim = c(0, 1),
               las = 1)

text(bp2, barplot_data_blocked + 0.05,
     labels = sprintf("%.3f", barplot_data_blocked),
     cex = 1.1, font = 2)

abline(h = std_baseline, lty = 2, col = "darkgreen", lwd = 2)

# FIX: Placing the text at the start of the line (x=0.2)
# ensures it never hits the right edge.
text(x = 0.2, y = std_baseline + 0.04,
     labels = sprintf("Baseline (1C): %.3f", std_baseline),
     adj = 0, cex = 0.85, col = "darkgreen", font = 2)

# Plot 3: Spatial leakage comparison
leakage_data <- c(leakage_crude, leakage_std)
bp3 <- barplot(leakage_data,
               names.arg = c("Crude + IMD", "Std (no IMD)"),
               main = "Spatial Leakage by Offset Type",
               ylab = "Performance Drop (Random → Blocked)",
               col = c(color_crude, color_std),
               ylim = c(0, max(leakage_data) * 1.2),
               las = 1)
text(bp3, leakage_data + max(leakage_data) * 0.05,
     labels = sprintf("%.3f", leakage_data),
     cex = 1.1, font = 2)
abline(h = 0.05, lty = 3, col = "gray50")
text(0.5, 0.05, "Minimal", pos = 3, cex = 0.8, col = "gray50")
abline(h = 0.10, lty = 3, col = "orange")
text(0.5, 0.10, "Substantial", pos = 3, cex = 0.8, col = "orange")
abline(h = 0.15, lty = 3, col = "red")
text(0.5, 0.15, "Severe", pos = 3, cex = 0.8, col = "red")

# Plot 4: Scatter plot comparison (Random CV only)
plot(obs, model_table$method2a_random_cv_cases,
     xlab = "Observed GP Cases",
     ylab = "Predicted Cases",
     main = "Random CV: Crude vs Standardized Offset",
     pch = 16,
     col = adjustcolor(color_crude, alpha.f = 0.3),
     cex = 0.6)
points(obs, model_table$sens_random_cv_std_cases,
       pch = 16,
       col = adjustcolor(color_std, alpha.f = 0.3),
       cex = 0.6)
abline(0, 1, col = "black", lwd = 2, lty = 2)
legend("topleft",
       legend = c(
         sprintf("Crude + IMD (ρ = %.3f)", comparison_results$Spearman[1]),
         sprintf("Std, no IMD (ρ = %.3f)", comparison_results$Spearman[3]),
         "Perfect agreement"
       ),
       pch = c(16, 16, NA),
       lty = c(NA, NA, 2),
       lwd = c(NA, NA, 2),
       col = c(color_crude, color_std, "black"),
       bty = "n",
       cex = 0.9)

dev.off()

cat("  Saved: Sensitivity_Analysis_Results.pdf\n\n")

# ================================================================
# SECTION 6: EXPORT RESULTS
# ================================================================

cat("========================================\n")
cat("EXPORTING RESULTS\n")
cat("========================================\n\n")

write.csv(comparison_results, "Sensitivity_Comparison.csv", row.names = FALSE)
cat("  Saved: Sensitivity_Comparison.csv\n\n")

# Export predictions for further analysis if needed
sensitivity_predictions <- model_table %>%
  select(
    lad_code,
    lsoa_code,
    observed_gp_cases,
    method2a_random_cv_cases,       # Crude offset, random CV
    method2b_lad_blocked_cv_cases,  # Crude offset, blocked CV
    sens_random_cv_std_cases,       # Std offset, random CV
    sens_blocked_cv_std_cases       # Std offset, blocked CV
  )

write.csv(sensitivity_predictions, "Sensitivity_Predictions.csv", row.names = FALSE)
cat("  Saved: Sensitivity_Predictions.csv\n\n")

# ================================================================
# SECTION 7: SUMMARY
# ================================================================

cat("========================================\n")
cat("SENSITIVITY ANALYSIS SUMMARY\n")
cat("========================================\n\n")

cat("KEY FINDINGS:\n\n")

cat("1. OFFSET TYPE IMPACT:\n")
cat("   Crude offset + IMD predictor:\n")
cat("     Random CV:      ρ = ", comparison_results$Spearman[1], "\n")
cat("     LAD-blocked CV: ρ = ", comparison_results$Spearman[2], "\n")
cat("     Spatial leakage:   ", round(leakage_crude, 3), "\n\n")

cat("   Standardized offset (no IMD):\n")
cat("     Random CV:      ρ = ", comparison_results$Spearman[3], "\n")
cat("     LAD-blocked CV: ρ = ", comparison_results$Spearman[4], "\n")
cat("     Spatial leakage:   ", round(leakage_std, 3), "\n\n")

cat("2. SPATIAL LEAKAGE REDUCTION:\n")
cat("   ", round(leakage_crude - leakage_std, 3),
    " (", round((leakage_crude - leakage_std) / leakage_crude * 100, 1), "% reduction)\n\n")

cat("3. COMPARISON TO BASELINE:\n")
cat("   Simple standardization (1C): ρ = ", round(std_baseline, 3), "\n")
cat("   Blocked CV (std offset):     ρ = ", comparison_results$Spearman[4], "\n")
cat("   Added value of model:           ",
    round(comparison_results$Spearman[4] - std_baseline, 3), "\n\n")

cat("INTERPRETATION:\n")
if(leakage_crude - leakage_std > 0.15) {
  cat("  Using a standardized offset dramatically reduces spatial leakage.\n")
  cat("  The crude offset model was learning demographic patterns as\n")
  cat("  LAD-specific effects, which inflated random CV performance.\n")
  cat("  The standardized offset embeds these patterns directly,\n")
  cat("  forcing the model to learn only residual regional variation.\n\n")
} else if(leakage_crude - leakage_std > 0.05) {
  cat("  Using a standardized offset moderately reduces spatial leakage.\n")
  cat("  This suggests demographics explain part, but not all, of the\n")
  cat("  LAD random effects in the crude offset model.\n\n")
} else {
  cat("  Offset type has minimal impact on spatial leakage.\n")
  cat("  This suggests the LAD random effects capture true regional\n")
  cat("  variation rather than demographic patterns.\n\n")
}

if(abs(comparison_results$Spearman[4] - std_baseline) < 0.02) {
  cat("RECOMMENDATION:\n")
  cat("  For predicting new regions, use simple age-sex-IMD\n")
  cat("  standardization (Method 1C). The hierarchical model\n")
  cat("  adds no meaningful value and requires more complexity.\n\n")
}

cat("========================================\n")
cat("SENSITIVITY ANALYSIS COMPLETE\n")
cat("========================================\n\n")

cat("Output files:\n")
cat("  - Sensitivity_Comparison.csv\n")
cat("  - Sensitivity_Predictions.csv\n")
cat("  - Sensitivity_Analysis_Results.pdf\n\n")
