source("analysis/utils/cons.R")
source("analysis/pre_analysis/pa_data_cleaning.R")

# Load necessary libraries
library(e1071)

# Check skewness of quantitative columns and recommend transformations if needed
check_skewness <- function(
    data,
    model,
    column_types = NULL,
    threshold_check_skewness = DEFAULT_THRESHOLD_CHECK_SKEWNESS
) {
  library(jsonlite)
  skewed_columns <- c()
  
  # Parse column_types if it's a JSON string
  if (!is.null(column_types) && is.character(column_types)) {
    parsed <- fromJSON(column_types)
    if (is.data.frame(parsed)) {
      column_types <- lapply(seq_len(nrow(parsed)), function(i) {
        list(column = parsed$column[[i]], type = parsed$type[[i]])
      })
    }
  }
  
  for (col_name in colnames(data)) {
    col_type <- NULL
    
    # Check type from column_types list
    if (!is.null(column_types)) {
      matched <- Filter(function(entry) {
        is.list(entry) && !is.null(entry[["column"]]) && entry[["column"]] == col_name
      }, column_types)
      
      if (length(matched) > 0) {
        col_type <- matched[[1]][["type"]]
        if (col_type != "QUANTITATIVE") next
      }
    }
    
    # Fallback to check_column_type if not in list
    if (is.null(col_type)) {
      col_type <- check_column_type(data, col_name)
      if (col_type != "QUANTITATIVE") next
    }
    
    # Proceed with skewness check
    numeric_column <- suppressWarnings(as.numeric(data[[col_name]]))
    numeric_column <- numeric_column[!is.na(numeric_column)]
    
    if (length(numeric_column) == 0) next
    
    skew_value <- skewness(numeric_column, na.rm = TRUE)
    
    if (abs(skew_value) > threshold_check_skewness) {
      skewed_columns <- c(skewed_columns, col_name)
    }
  }
  
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

# Check if standardization is needed for quantitative columns based on model
check_standardization <- function(
    data,
    model,
    column_types = NULL
) {
  library(jsonlite)
  standardized_columns <- c()
  
  # Parse column_types if it's a JSON string
  if (!is.null(column_types) && is.character(column_types)) {
    parsed <- fromJSON(column_types)
    if (is.data.frame(parsed)) {
      column_types <- lapply(seq_len(nrow(parsed)), function(i) {
        list(column = parsed$column[[i]], type = parsed$type[[i]])
      })
    }
  }
  
  for (col_name in colnames(data)) {
    col_type <- NULL
    
    # Try to get type from column_types
    if (!is.null(column_types)) {
      matched <- Filter(function(entry) {
        is.list(entry) && !is.null(entry[["column"]]) && entry[["column"]] == col_name
      }, column_types)
      
      if (length(matched) > 0) {
        col_type <- matched[[1]][["type"]]
        if (col_type != "QUANTITATIVE") next
      }
    }
    
    # Fallback to check_column_type
    if (is.null(col_type)) {
      col_type <- check_column_type(data, col_name)
      if (col_type != "QUANTITATIVE") next
    }
    
    # If it is QUANTITATIVE, include it
    standardized_columns <- c(standardized_columns, col_name)
  }
  
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

# Check if normalization is needed for quantitative columns based on model
check_normalization <- function(
    data,
    model,
    column_types = NULL
) {
  library(jsonlite)
  normalization_columns <- c()
  
  # Parse JSON string if necessary
  if (!is.null(column_types) && is.character(column_types)) {
    parsed <- fromJSON(column_types)
    if (is.data.frame(parsed)) {
      column_types <- lapply(seq_len(nrow(parsed)), function(i) {
        list(column = parsed$column[[i]], type = parsed$type[[i]])
      })
    }
  }
  
  for (col_name in colnames(data)) {
    col_type <- NULL
    
    # Get type from column_types if provided
    if (!is.null(column_types)) {
      matched <- Filter(function(entry) {
        is.list(entry) && !is.null(entry[["column"]]) && entry[["column"]] == col_name
      }, column_types)
      
      if (length(matched) > 0) {
        col_type <- matched[[1]][["type"]]
        if (col_type != "QUANTITATIVE") next
      }
    }
    
    # Fallback to check_column_type if not in list
    if (is.null(col_type)) {
      col_type <- check_column_type(data, col_name)
      if (col_type != "QUANTITATIVE") next
    }
    
    normalization_columns <- c(normalization_columns, col_name)
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
