source("utils/cons.R")
source("pre_analysis/pa_data_cleaning.R")

# Load necessary libraries
if (!require("e1071")) install.packages("e1071")
library(e1071)

# Check skewness of quantitative columns and recommend transformations if needed
check_skewness <- function(data, model, threshold = DEFAULT_THRESHOLD_CHECK_SKEWNESS) {
  skewed_columns <- c()
  
  for (col_name in colnames(data)) {
    if (check_column_type(data, col_name) == "QUANTITATIVE") {
      numeric_column <- suppressWarnings(as.numeric(data[[col_name]]))
      numeric_column <- numeric_column[!is.na(numeric_column)]
      
      if (length(numeric_column) == 0) next
      
      skew_value <- skewness(numeric_column, na.rm = TRUE)
      
      if (abs(skew_value) > threshold) {
        skewed_columns <- c(skewed_columns, col_name)
      }
    }
  }
  
  recommendation <- paste0("No skewness detected for ", model, ".")
  
  if (length(skewed_columns) > 0) {
    if (model %in% HANDLES_SKEWNESS_WELL) {
      recommendation <- paste0("Skewness detected but not an issue for tree-based models like ", model, ".")
    } else {
      recommendation <- paste0("Apply transformations to remove skewness for ", model, ".")
    }
  }
  
  return(list(columns = skewed_columns, recommendation = recommendation))
}

# Check if standardization is needed for quantitative columns based on model
check_standardization <- function(data, model) {
  standardized_columns <- c()
  
  for (col_name in colnames(data)) {
    if (check_column_type(data, col_name) == "QUANTITATIVE") {
      standardized_columns <- c(standardized_columns, col_name)
    }
  }
  
  recommendation <- paste0("Standardization not required for ", model, ".")
  
  if (length(standardized_columns) > 0) {
    if (model %in% NEEDS_STANDARDIZATION) {
      recommendation <- paste0("Apply standardization to numeric columns for ", model, ".")
    } else {
      recommendation <- paste0("Standardization not necessary for tree-based models like ", model, ".")
    }
  }
  
  return(list(columns = standardized_columns, recommendation = recommendation))
}

# Check if normalization is needed for quantitative columns based on model
check_normalization <- function(data, model) {
  normalization_columns <- c()
  
  for (col_name in colnames(data)) {
    if (check_column_type(data, col_name) == "QUANTITATIVE") {
      normalization_columns <- c(normalization_columns, col_name)
    }
  }
  
  recommendation <- paste0("Normalization not required for ", model, ".")
  
  if (length(normalization_columns) > 0) {
    if (model %in% NEEDS_NORMALIZATION_SOMETIMES) {
      recommendation <- paste0("Apply normalization to numeric columns for ", model, ".")
    } else {
      recommendation <- paste0("Normalization not required for tree-based models like ", model, ".")
    }
  }
  
  return(list(columns = normalization_columns, recommendation = recommendation))
}

# Aggregate transformation-related checks in one function
pre_analysis_transformation <- function(data, model) {
  skewed_info <- check_skewness(data, model)
  standardization_info <- check_standardization(data, model)
  normalization_info <- check_normalization(data, model)
  
  result <- list(
    skewed_columns = skewed_info,
    columns_require_standardization = standardization_info,
    columns_require_normalization = normalization_info
  )
  
  return(result)
}