library(here)

source("analysis/utils/cons.R")
source("analysis/utils/utils.R")

# Load necessary libraries
# if (!require("dplyr")) install.packages("dplyr")
library(dplyr)
# if (!require("jsonlite")) install.packages("jsonlite")
library(jsonlite)
# if (!require("mlr")) install.packages("mlr")
library(mlr)

get_missing_indexes <- function(
    col
    ) {
  missing_idx <- is.na(col) | is.nan(col) | (col == "")
  return(missing_idx)
}


get_outliers_indexes <- function(col) {
  col_char <- as.character(col)
  invalid_idx <- is.na(col_char) | is.nan(col_char) | (col_char == "")
  numeric_col <- suppressWarnings(as.numeric(col_char))
  valid_values <- numeric_col[!invalid_idx]
  
  if (length(valid_values) == 0) {
    return(rep(FALSE, length(col)))
  }
  
  Q1 <- quantile(valid_values, 0.25, na.rm = TRUE)
  Q3 <- quantile(valid_values, 0.75, na.rm = TRUE)
  IQR <- Q3 - Q1
  lower_bound <- Q1 - 1.5 * IQR
  upper_bound <- Q3 + 1.5 * IQR
  
  outlier_idx <- rep(FALSE, length(col))
  valid_idx <- which(!invalid_idx)
  outlier_idx[valid_idx] <- (numeric_col[valid_idx] < lower_bound) | (numeric_col[valid_idx] > upper_bound)
  
  return(outlier_idx)
}


get_inconsistent_indexes <- function(col, column_type) {
  col_char <- trimws(as.character(col))  # remove leading/trailing spaces
  
  if (column_type == "QUALITATIVE") {
    numeric_like <- grepl("^[0-9]+(\\.[0-9]+)?$", col_char)
    inconsistent_idx <- numeric_like & !is.na(col_char) & col_char != ""
  } else if (column_type == "QUANTITATIVE") {
    numeric_vals <- suppressWarnings(as.numeric(col_char))
    inconsistent_idx <- !is.na(col_char) & is.na(numeric_vals)
  } else {
    inconsistent_idx <- rep(FALSE, length(col))
  }
  
  return(inconsistent_idx)
}


impute_mean <- function(
    col,
    column_type,
    missing_idx
) {
  # Imputes missing numeric values with mean rounded to 1 decimal
  if (column_type != "QUANTITATIVE") {
    warning("impute_mean expects QUANTITATIVE column. Returning column unchanged.")
    return(col)
  }
  
  col_num <- suppressWarnings(as.numeric(as.character(col)))
  
  if (length(col[!missing_idx]) == 0) {
    warning("No non-missing values to compute mean. Returning column unchanged.")
    return(col)
  }
  
  mean_val <- mean(col_num[!missing_idx], na.rm = TRUE)
  col[missing_idx] <- round(mean_val, average_decimal_places(col_num))
  return(col)
}


impute_median <- function(
    col,
    column_type,
    missing_idx
) {
  # Imputes missing numeric values with median rounded to 1 decimal
  if (column_type != "QUANTITATIVE") {
    warning("impute_median expects QUANTITATIVE column. Returning column unchanged.")
    return(col)
  }
  
  col_num <- suppressWarnings(as.numeric(as.character(col)))
  
  if (length(col[!missing_idx]) == 0) {
    warning("Returning column unchanged.")
    return(col)
  }
  
  median_val <- median(col_num[!missing_idx], na.rm = TRUE)
  col[missing_idx] <- round(median_val, average_decimal_places(col_num))
  return(col)
}


impute_mode <- function(
    col,
    column_type,
    missing_idx
) {
  # Imputes missing values with the most frequent value (mode)
  if (!(column_type %in% c("QUALITATIVE", "QUANTITATIVE"))) {
    warning("impute_mode expects QUALITATIVE or QUANTITATIVE column. Returning column unchanged.")
    return(col)
  }
  
  col_char <- as.character(col)
  
  if (length(col_char[!missing_idx]) == 0) {
    warning("Returning column unchanged.")
    return(col)
  }
  
  uniq_vals <- unique(col_char[!missing_idx])
  tab <- tabulate(match(col_char, uniq_vals))
  mode_val <- uniq_vals[which.max(tab)]
  
  col_char[missing_idx] <- mode_val
  
  if (column_type == "QUANTITATIVE") {
    col_num <- suppressWarnings(as.numeric(col_char))
    result <- col_char
    result[!is.na(col_num)] <- as.character(col_num[!is.na(col_num)])
    return(result)
  } else {
    return(col_char)
  }
}


impute_random <- function(
    col,
    column_type,
    missing_idx
) {
  # Imputes missing values by random sampling from existing values
  if (!(column_type %in% c("QUALITATIVE", "QUANTITATIVE"))) {
    warning("impute_random expects QUALITATIVE or QUANTITATIVE column. Returning column unchanged.")
    return(col)
  }
  
  col_char <- as.character(col)
  
  if (length(col_char[!missing_idx]) == 0) {
    warning("Returning column unchanged.")
    return(col)
  }
  
  col_char[missing_idx] <- sample(col_char[!missing_idx], sum(missing_idx), replace = TRUE)
  
  if (column_type == "QUANTITATIVE") {
    col_num <- suppressWarnings(as.numeric(col_char))
    result <- col_char
    result[!is.na(col_num)] <- as.character(col_num[!is.na(col_num)])
    return(result)
  } else {
    return(col_char)
  }
}


impute_constant <- function(
    col,
    column_type,
    missing_idx,
    value
) {
  # Imputes missing values with a constant specified by `value`
  if (!(column_type %in% c("QUALITATIVE", "QUANTITATIVE"))) {
    warning("impute_constant expects QUALITATIVE or QUANTITATIVE column. Returning column unchanged.")
    return(col)
  }
  
  col_char <- as.character(col)
  
  if (length(col_char[!missing_idx]) == 0) {
    warning("Returning column unchanged.")
    return(col)
  }
  
  col_char[missing_idx] <- as.character(value)
  
  
  if (column_type == "QUANTITATIVE") {
    col_num <- suppressWarnings(as.numeric(col_char))
    result <- col_char
    result[!is.na(col_num)] <- as.character(col_num[!is.na(col_num)])
    return(result)
  } else {
    return(col_char)
  }
}

remove <- function(df, col) {
  if (!(col %in% names(df))) {
    stop("Column not found in dataframe")
  }
  
  column_data <- df[[col]]
  keep_rows <- !(is.na(column_data) | is.nan(column_data) | column_data == "")
  
  return(df[keep_rows, ])
}


fix_missing <- function(
    data,
    column_details,
    method
) {
  # Apply imputation steps to columns based on details
  for (detail in column_details) {
    col_name <- detail$column
    col_type <- detail$type
    step_name <- detail$step
    value <- detail$value
    
    missing_idx = get_missing_indexes(data[[col_name]])
    
    if (!is.null(step_name) &&
        nzchar(step_name) &&
        exists(step_name, mode = "function")) {
      func <- get(step_name)
      
      if (step_name == "impute_constant") {
        data[[col_name]] <- func(data[[col_name]], col_type, missing_idx, value)
      }
      else if (step_name == "remove") {
        data <- func(data, col_name)
      }
      else {
        data[[col_name]] <- func(data[[col_name]], col_type, missing_idx) 
      }
    } else {
      warning(paste("Step function", step_name, "for column", col_name, "does not exist or is invalid. Skipping."))
    }
  }
  return(data)
}


fix_outliers <- function(
    data,
    column_details,
    method
) {
  # Apply imputation steps to columns based on details
  for (detail in column_details) {
    col_name <- detail$column
    col_type <- detail$type
    step_name <- detail$step
    value <- detail$value
    
    outlier_idx = get_outliers_indexes(data[[col_name]])
    
    if (!is.null(step_name) &&
        nzchar(step_name) &&
        exists(step_name, mode = "function")) {
      func <- get(step_name)
      
      if (step_name == "impute_constant") {
        data[[col_name]] <- func(data[[col_name]], col_type, outlier_idx, value)
      }
      else if (step_name == "remove") {
        data <- func(data, col_name)
      }
      else {
        data[[col_name]] <- func(data[[col_name]], col_type, outlier_idx) 
      }
    } else {
      warning(paste("Step function", step_name, "for column", col_name, "does not exist or is invalid. Skipping."))
    }
  }
  return(data)
}


fix_inconsistencies <- function(
    data,
    column_details,
    method
) {
  # Apply imputation steps to columns based on details
  for (detail in column_details) {
    col_name <- detail$column
    col_type <- detail$type
    step_name <- detail$step
    value <- detail$value
    
    inconsistent_idx = get_inconsistent_indexes(data[[col_name]], col_type)
    
    if (!is.null(step_name) &&
        nzchar(step_name) &&
        exists(step_name, mode = "function")) {
      func <- get(step_name)
      
      if (step_name == "impute_constant") {
        data[[col_name]] <- func(data[[col_name]], col_type, inconsistent_idx, value)
      }
      else if (step_name == "remove") {
        data <- func(data, col_name)
      }
      else {
        data[[col_name]] <- func(data[[col_name]], col_type, inconsistent_idx) 
      }
    } else {
      warning(paste("Step function", step_name, "for column", col_name, "does not exist or is invalid. Skipping."))
    }
  }
  return(data)
}

# Main pre-analysis cleaning function aggregating checks
pre_processing_cleaning <- function(
    data,
    column_details,
    method
) {
  func = get(method)
  result = func(data, column_details, method)
  return(result)
}
