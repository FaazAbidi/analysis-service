source("analysis/utils/cons.R")
source("analysis/pre_analysis/pa_data_cleaning.R")

library(e1071)

check_skewness <- function(
    data,
    model,
    column_types = NULL,
    threshold_check_skewness = DEFAULT_THRESHOLD_CHECK_SKEWNESS
) {
  skewed_indices <- c()
  skewed_values <- c()
  
  if (is.null(threshold_check_skewness)) {
    threshold_check_skewness <- DEFAULT_THRESHOLD_CHECK_SKEWNESS
  }
  
  if (!is.null(column_types) && is.character(column_types)) {
    parsed <- fromJSON(column_types)
    if (is.data.frame(parsed)) {
      column_types <- lapply(seq_len(nrow(parsed)), function(i) {
        list(column = parsed$column[[i]], type = parsed$type[[i]])
      })
    }
  }
  
  for (idx in seq_along(colnames(data))) {
    col_name <- colnames(data)[idx]
    col_type <- NULL
    
    if (!is.null(column_types)) {
      matched <- Filter(function(entry) {
        is.list(entry) && !is.null(entry[["column"]]) && entry[["column"]] == col_name
      }, column_types)
      if (length(matched) > 0) {
        col_type <- matched[[1]][["type"]]
        if (col_type != "QUANTITATIVE") next
      }
    }
    
    if (is.null(col_type)) {
      col_type <- check_column_type(data, col_name)
      if (col_type != "QUANTITATIVE") next
    }
    
    numeric_column <- suppressWarnings(as.numeric(data[[col_name]]))
    numeric_column <- numeric_column[!is.na(numeric_column)]
    
    if (length(numeric_column) == 0) next
    
    skew_value <- skewness(numeric_column, na.rm = TRUE)
    if (is.na(skew_value) || is.nan(skew_value)) next
    
    if (abs(skew_value) > threshold_check_skewness) {
      skewed_indices <- c(skewed_indices, idx)
      skewed_values <- c(skewed_values, skew_value)
    }
  }
  
  skewed_columns <- lapply(seq_along(skewed_indices), function(i) {
    idx <- skewed_indices[i]
    col_name <- colnames(data)[idx]
    list(column = paste0(col_name, "$", idx), skewness = skewed_values[i])
  })
  
  recommendation <- paste0("No skewness detected for ", model, ".")
  if (length(skewed_columns) > 0) {
    if (is.null(model)) {
      recommendation <- "Apply transformations to remove skewness."
    } else if (model %in% HANDLES_SKEWNESS_WELL) {
      recommendation <- paste0("Skewness detected but not an issue for tree-based models like ", model, ".")
    } else {
      recommendation <- paste0("Apply transformations to remove skewness for ", model, ".")
    }
  }
  
  return(list(
    columns = skewed_columns,
    recommendation = recommendation
  ))
}

check_standardization <- function(
    data,
    model,
    column_types = NULL
) {
  standardize_indices <- c()
  
  if (!is.null(column_types) && is.character(column_types)) {
    parsed <- fromJSON(column_types)
    if (is.data.frame(parsed)) {
      column_types <- lapply(seq_len(nrow(parsed)), function(i) {
        list(column = parsed$column[[i]], type = parsed$type[[i]])
      })
    }
  }
  
  for (idx in seq_along(colnames(data))) {
    col_name <- colnames(data)[idx]
    col_type <- NULL
    
    if (!is.null(column_types)) {
      matched <- Filter(function(entry) {
        is.list(entry) && !is.null(entry[["column"]]) && entry[["column"]] == col_name
      }, column_types)
      if (length(matched) > 0) {
        col_type <- matched[[1]][["type"]]
        if (col_type != "QUANTITATIVE") next
      }
    }
    if (is.null(col_type)) {
      col_type <- check_column_type(data, col_name)
      if (col_type != "QUANTITATIVE") next
    }
    standardize_indices <- c(standardize_indices, idx)
  }
  
  standardized_columns <- lapply(seq_along(standardize_indices), function(i) {
    idx <- standardize_indices[i]
    col_name <- colnames(data)[idx]
    paste0(col_name, "$", idx)
  })
  
  recommendation <- paste0("Standardization not required for ", model, ".")
  if (length(standardized_columns) > 0) {
    if (model %in% NEEDS_STANDARDIZATION) {
      recommendation <- paste0("Apply standardization to numeric columns for ", model, ".")
    } else {
      recommendation <- paste0("Standardization not necessary for tree-based models like ", model, ".")
    }
  }
  
  return(list(
    columns = standardized_columns,
    recommendation = recommendation
  ))
}

check_normalization <- function(
    data,
    model,
    column_types = NULL
) {
  normalization_indices <- c()
  
  if (!is.null(column_types) && is.character(column_types)) {
    parsed <- fromJSON(column_types)
    if (is.data.frame(parsed)) {
      column_types <- lapply(seq_len(nrow(parsed)), function(i) {
        list(column = parsed$column[[i]], type = parsed$type[[i]])
      })
    }
  }
  
  for (idx in seq_along(colnames(data))) {
    col_name <- colnames(data)[idx]
    col_type <- NULL
    
    if (!is.null(column_types)) {
      matched <- Filter(function(entry) {
        is.list(entry) && !is.null(entry[["column"]]) && entry[["column"]] == col_name
      }, column_types)
      if (length(matched) > 0) {
        col_type <- matched[[1]][["type"]]
        if (col_type != "QUANTITATIVE") next
      }
    }
    if (is.null(col_type)) {
      col_type <- check_column_type(data, col_name)
      if (col_type != "QUANTITATIVE") next
    }
    normalization_indices <- c(normalization_indices, idx)
  }
  
  normalization_columns <- lapply(seq_along(normalization_indices), function(i) {
    idx <- normalization_indices[i]
    col_name <- colnames(data)[idx]
    paste0(col_name, "$", idx)
  })
  
  recommendation <- paste0("Normalization not required for ", model, ".")
  if (length(normalization_columns) > 0) {
    if (model %in% NEEDS_NORMALIZATION_SOMETIMES) {
      recommendation <- paste0("Apply normalization to numeric columns for ", model, ".")
    } else {
      recommendation <- paste0("Normalization not required for tree-based models like ", model, ".")
    }
  }
  
  return(list(
    columns = normalization_columns,
    recommendation = recommendation
  ))
}

pre_analysis_transformation <- function(
    data,
    model,
    columns_types,
    threshold_check_skewness
) {
  skewed_info <- check_skewness(data, model, columns_types, threshold_check_skewness)
  standardization_info <- check_standardization(data, model, columns_types)
  normalization_info <- check_normalization(data, model, columns_types)
  
  result <- list(
    skewed_columns = skewed_info,
    columns_require_standardization = standardization_info,
    columns_require_normalization = normalization_info
  )
  
  return(result)
}
