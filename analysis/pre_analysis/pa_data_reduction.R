source("utils/cons.R")

# Load necessary libraries
if (!require("car")) install.packages("car")
library(car)

# Check if sampling is needed based on row count threshold
is_sampling_required <- function(
    df,
    threshold_sampling = DEFAULT_THRESHOLD_FOR_SAMPLING
) {
  return(nrow(df) > threshold_sampling)
}

# Check multicollinearity using VIF, returns TRUE if any VIF > threshold
check_multicollinearity <- function(
    data,
    target,
    column_types = NULL,
    threshold_check_vif = DEFAULT_THRESHOLD_CHECK_VIF
) {
  if (is.null(target)) return(NULL)
  
  data <- na.omit(data)
  
  if (!(target %in% names(data))) stop("Target variable not found in data.")
  
  # Parse column_types JSON string if necessary
  if (!is.null(column_types) && is.character(column_types)) {
    parsed <- fromJSON(column_types)
    if (is.data.frame(parsed)) {
      column_types <- lapply(seq_len(nrow(parsed)), function(i) {
        list(column = parsed$column[[i]], type = parsed$type[[i]])
      })
    }
  }
  
  quantitative_cols <- c()
  
  for (col_name in names(data)) {
    col_type <- NULL
    
    if (!is.null(column_types)) {
      matched <- Filter(function(entry) {
        is.list(entry) && !is.null(entry[["column"]]) && entry[["column"]] == col_name
      }, column_types)
      if (length(matched) > 0) {
        col_type <- matched[[1]][["type"]]
      }
    }
    
    if (is.null(col_type)) {
      if (is.numeric(data[[col_name]])) {
        quantitative_cols <- c(quantitative_cols, col_name)
      }
    } else if (col_type == "QUANTITATIVE") {
      quantitative_cols <- c(quantitative_cols, col_name)
    }
  }
  
  numeric_data <- data[, quantitative_cols, drop = FALSE]
  
  formula <- as.formula(paste(target, "~ ."))
  model <- lm(formula, data = numeric_data)
  vif_vals <- vif(model)
  
  return(any(vif_vals > threshold_check_vif))
}

# Check if data is high dimensional: ratio of numeric features to rows > threshold
check_high_dimensionality <- function(
    data,
    threshold_check_dimensionality = DEFAULT_THRESHOLD_CHECK_DIMENSIONALITY
) {
  data <- na.omit(data)
  numeric_data <- data[sapply(data, is.numeric)]
  ratio <- ncol(numeric_data) / nrow(numeric_data)
  return(ratio > threshold_check_dimensionality)
}

# Aggregate reduction checks to decide on sampling, multicollinearity, dimensionality, and PCA
pre_analysis_reduction <- function(
    data,
    target,
    column_types,
    threshold_sampling,
    threshold_check_dimensionality,
    threshold_check_vif
) {
  sampling_needed <- is_sampling_required(data, threshold_sampling)
  multicollinearity_exists <- check_multicollinearity(data, target, column_types, threshold_check_vif)
  high_dimensionality_exists <- check_high_dimensionality(data, threshold_check_dimensionality)
  
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
