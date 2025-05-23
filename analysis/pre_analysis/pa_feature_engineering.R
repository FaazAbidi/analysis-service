source("utils/cons.R")

# Check categorical columns based on heuristic: character or factor with low cardinality
check_categorical_columns <- function(data, model) {
  cat_cols <- names(Filter(function(col) {
    (is.character(col) || is.factor(col)) &&
      length(unique(col)) < DEFAULT_PERCENTAGE_CHECK_CATEGORICAL * nrow(data)  # heuristic for low cardinality
  }, data))
  
  recommendation <- paste0("No categorical columns requiring encoding for ", model, ".")
  
  if (length(cat_cols) > 0) {
    if (model %in% NEEDS_ONE_HOT_ENCODING) {
      recommendation <- paste0("One-hot encoding required for columns for ", model, ".")
    } else {
      recommendation <- paste0("Categorical columns detected but not an issue for tree-based models like ", model, ".")
    }
  }
  
  return(list(columns = cat_cols, recommendation = recommendation))
}

# Aggregate feature engineering checks
pre_analysis_feature_engineering <- function(data, model) {
  categorical_columns <- check_categorical_columns(data, model)
  
  result <- list(
    columns_require_one_hot_encoding = categorical_columns
  )
  
  return(result)
}