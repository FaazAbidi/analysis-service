source("utils/cons.R")

# Load necessary libraries
if (!require("car")) install.packages("car")
library(car)

# Check if sampling is needed based on row count threshold
is_sampling_required <- function(df, threshold = DEFAULT_THRESHOLD_FOR_SAMPLING) {
  return(nrow(df) > threshold)
}

# Check multicollinearity using VIF, returns TRUE if any VIF > 5
check_multicollinearity <- function(data, target) {
  if (is.null(target)) return(NULL)
  
  data <- na.omit(data)
  
  if (!(target %in% names(data))) stop("Target variable not found in data.")
  
  numeric_data <- data[sapply(data, is.numeric)]
  
  formula <- as.formula(paste(target, "~ ."))
  model <- lm(formula, data = numeric_data)
  vif_vals <- vif(model)
  
  return(any(vif_vals > 5))
}


# Check if data is high dimensional: ratio of numeric features to rows > threshold
check_high_dimensionality <- function(data, threshold = DEFAULT_THRESHOLD_CHECK_DIMENSIONALITY) {
  data <- na.omit(data)
  numeric_data <- data[sapply(data, is.numeric)]
  ratio <- ncol(numeric_data) / nrow(numeric_data)
  return(ratio > threshold)
}


# Aggregate reduction checks to decide on sampling, multicollinearity, dimensionality, and PCA
pre_analysis_reduction <- function(data, target) {
  sampling_needed <- is_sampling_required(data)
  multicollinearity_exists <- check_multicollinearity(data, target)
  high_dimensionality_exists <- check_high_dimensionality(data)
  
  pca_required <- if (is.null(multicollinearity_exists)) {
    "Target is required"
  } else {
    multicollinearity_exists || high_dimensionality_exists
  }
  
  result <- list(
    is_sampling_required = sampling_needed,
    multicollinearity_exists = multicollinearity_exists,
    high_dimensionality_exists = high_dimensionality_exists,
    is_pca_required = pca_required
  )
  
  return(result)
}
