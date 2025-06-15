source("analysis/utils/cons.R")

library(jsonlite)

# Check categorical columns based on heuristic: character or factor with low cardinality
check_categorical_columns <- function(
    data,
    model,
    column_types = NULL,
    threshold_check_categorical = DEFAULT_PERCENTAGE_CHECK_CATEGORICAL
) {
  
  # Use the default threshold if NULL
  if (is.null(threshold_check_categorical)) {
    threshold_check_categorical <- DEFAULT_PERCENTAGE_CHECK_CATEGORICAL
  }
  
  # Parse column_types if it's a JSON string
  if (!is.null(column_types) && is.character(column_types)) {
    parsed <- fromJSON(column_types)
    if (is.data.frame(parsed)) {
      column_types <- lapply(seq_len(nrow(parsed)), function(i) {
        list(column = parsed$column[[i]], type = parsed$type[[i]])
      })
    }
  }
  
  qualitative_cols <- c()
  
  for (col_name in colnames(data)) {
    col_type <- NULL
    
    if (!is.null(column_types)) {
      matched <- Filter(function(entry) {
        is.list(entry) && !is.null(entry[["column"]]) && entry[["column"]] == col_name
      }, column_types)
      
      if (length(matched) > 0) {
        col_type <- matched[[1]][["type"]]
        if (col_type != "QUALITATIVE") next
      }
    }
    
    if (is.null(col_type)) {
      if (!(is.character(data[[col_name]]) || is.factor(data[[col_name]]))) next
    }
    
    qualitative_cols <- c(qualitative_cols, col_name)
  }
  
  cat_cols <- Filter(function(col_name) {
    col <- data[[col_name]]
    (is.character(col) || is.factor(col)) &&
      length(unique(col)) < threshold_check_categorical * nrow(data)
  }, qualitative_cols)
  
  recommendation <- paste0("No categorical columns requiring encoding for ", model, ".")
  
  if (length(cat_cols) > 0) {
    if (is.null(model)) {
      recommendation <- "One-hot encoding required for columns."
    } else if (model %in% NEEDS_ONE_HOT_ENCODING) {
      recommendation <- paste0("One-hot encoding required for columns for ", model, ".")
    } else {
      recommendation <- paste0("Categorical columns detected but not an issue for tree-based models like ", model, ".")
    }
  }
  
  return(list(columns = cat_cols, recommendation = recommendation))
}

# Aggregate feature engineering checks
pre_analysis_feature_engineering <- function(
    data,
    model,
    column_types,
    threshold_check_categorical
) {
  categorical_columns <- check_categorical_columns(
    data,
    model,
    column_types,
    threshold_check_categorical
  )
  
  result <- list(
    columns_require_one_hot_encoding = categorical_columns
  )
  
  return(result)
}
