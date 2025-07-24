source("analysis/utils/cons.R")

library(jsonlite)

check_categorical_columns <- function(
    data,
    model,
    column_types = NULL,
    encoding_type,
    threshold_check_categorical = DEFAULT_PERCENTAGE_CHECK_CATEGORICAL
) {
  
  if (is.null(threshold_check_categorical)) {
    threshold_check_categorical <- DEFAULT_PERCENTAGE_CHECK_CATEGORICAL
  }
  
  if (!is.null(column_types) && is.character(column_types)) {
    parsed <- fromJSON(column_types)
    if (is.data.frame(parsed)) {
      column_types <- lapply(seq_len(nrow(parsed)), function(i) {
        list(column = parsed$column[[i]], type = parsed$type[[i]])
      })
    }
  }
  
  qualitative_indices <- c()
  
  num_pattern <- "^[+-]?[0-9]*\\.?[0-9]+$"
  
  for (idx in seq_along(colnames(data))) {
    col_name <- colnames(data)[idx]
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
      col_values <- as.character(data[[col_name]])
      if (any(!is.na(col_values) & grepl(num_pattern, col_values))) next
    }
    
    qualitative_indices <- c(qualitative_indices, idx)
  }
  
  cat_cols_indices <- Filter(function(idx) {
    col <- data[[colnames(data)[idx]]]
    (is.character(col) || is.factor(col)) &&
      length(unique(col)) < threshold_check_categorical * nrow(data)
  }, qualitative_indices)
  
  cat_cols <- lapply(cat_cols_indices, function(idx) {
    paste0(colnames(data)[idx], "$", idx)
  })
  
  recommendation <- paste0("No categorical columns requiring encoding for ", model, ".")
  
  if (length(cat_cols) > 0 && encoding_type == "one_hot") {
    if (is.null(model)) {
      recommendation <- "One hot encoding required for columns."
    } else if (model %in% NEEDS_ONE_HOT_ENCODING) {
      recommendation <- paste0("One hot encoding required for columns for ", model, ".")
    } else {
      recommendation <- paste0("Categorical columns detected but not an issue for tree based models like ", model, ".")
    }
  }
  
  if (length(cat_cols) > 0 && encoding_type == "label") {
    if (is.null(model)) {
      recommendation <- "Label encoding required for columns."
    } else if (model %in% NEEDS_ONE_HOT_ENCODING) {
      recommendation <- paste0("Label encoding required for columns for ", model, ".")
    } else {
      recommendation <- paste0("Categorical columns detected but not an issue for tree based models like ", model, ".")
    }
  }
  
  return(list(columns = cat_cols, recommendation = recommendation))
}

pre_analysis_feature_engineering <- function(
    data,
    model,
    column_types,
    threshold_check_categorical
) {
  categorical_columns_one_hot <- check_categorical_columns(
    data,
    model,
    column_types,
    "one_hot",
    threshold_check_categorical
  )
  
  categorical_columns_label <- check_categorical_columns(
    data,
    model,
    column_types,
    "label",
    threshold_check_categorical
  )
  
  result <- list(
    columns_require_one_hot_encoding = categorical_columns_one_hot,
    columns_require_label_encoding = categorical_columns_label
  )
  
  return(result)
}
