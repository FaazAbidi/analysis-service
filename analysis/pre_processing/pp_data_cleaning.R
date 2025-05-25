source("utils/cons.R")
source("utils/utils.R")

# Load necessary libraries
if (!require("dplyr")) install.packages("dplyr")
library(dplyr)
if (!require("jsonlite")) install.packages("jsonlite")
library(jsonlite)


impute_mean <- function(
    col,
    column_type
) {
  # Imputes missing numeric values with mean rounded to 1 decimal
  if (column_type != "QUANTITATIVE") {
    warning("impute_mean expects QUANTITATIVE column. Returning column unchanged.")
    return(col)
  }
  
  col_num <- suppressWarnings(as.numeric(as.character(col)))
  missing_idx <- is.na(col) | is.nan(col) | (col == "")
  non_missing_vals <- col[!missing_idx]
  
  if (length(non_missing_vals) == 0) {
    warning("No non-missing values to compute mean. Returning column unchanged.")
    return(col)
  }
  
  mean_val <- mean(col_num[!missing_idx], na.rm = TRUE)
  col[missing_idx] <- round(mean_val, average_decimal_places(col_num))
  return(col)
}


impute_median <- function(
    col,
    column_type
) {
  # Imputes missing numeric values with median rounded to 1 decimal
  if (column_type != "QUANTITATIVE") {
    warning("impute_median expects QUANTITATIVE column. Returning column unchanged.")
    return(col)
  }
  
  col_num <- suppressWarnings(as.numeric(as.character(col)))
  missing_idx <- is.na(col) | is.nan(col) | (col == "")
  non_missing_vals <- col[!missing_idx]
  
  if (length(non_missing_vals) == 0) {
    warning("Returning column unchanged.")
    return(col)
  }
  
  median_val <- median(col_num[!missing_idx], na.rm = TRUE)
  col[missing_idx] <- round(median_val, average_decimal_places(col_num))
  return(col)
}


impute_mode <- function(
    col,
    column_type
) {
  # Imputes missing values with the most frequent value (mode)
  if (!(column_type %in% c("QUALITATIVE", "QUANTITATIVE"))) {
    warning("impute_mode expects QUALITATIVE or QUANTITATIVE column. Returning column unchanged.")
    return(col)
  }
  
  col_char <- as.character(col)
  
  missing_idx <- is.na(col_char) | is.nan(col_char) | (col_char == "")
  non_missing_vals <- col_char[!missing_idx]
  
  if (length(non_missing_vals) == 0) {
    warning("Returning column unchanged.")
    return(col)
  }
  
  uniq_vals <- unique(non_missing_vals)
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
    column_type
) {
  # Imputes missing values by random sampling from existing values
  if (!(column_type %in% c("QUALITATIVE", "QUANTITATIVE"))) {
    warning("impute_random expects QUALITATIVE or QUANTITATIVE column. Returning column unchanged.")
    return(col)
  }
  
  col_char <- as.character(col)
  
  missing_idx <- is.na(col_char) | is.nan(col_char) | (col_char == "")
  non_missing_vals <- col_char[!missing_idx]
  
  if (length(non_missing_vals) == 0) {
    warning("Returning column unchanged.")
    return(col)
  }
  
  col_char[missing_idx] <- sample(non_missing_vals, sum(missing_idx), replace = TRUE)
  
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
    value
) {
  # Imputes missing values with a constant specified by `value`
  if (!(column_type %in% c("QUALITATIVE", "QUANTITATIVE"))) {
    warning("impute_constant expects QUALITATIVE or QUANTITATIVE column. Returning column unchanged.")
    return(col)
  }
  
  col_char <- as.character(col)
  missing_idx <- is.na(col_char) | is.nan(col_char) | (col_char == "")
  non_missing_vals <- col[!missing_idx]
  
  if (length(non_missing_vals) == 0) {
    warning("Returning column unchanged.")
    return(col)
  }
  
  col_char[missing_idx] <- as.character(value)
  
  if (column_type == "QUANTITATIVE") {
    return(as.numeric(col_char))
  } else {
    return(col_char)
  }
}


fix_missing <- function(
    data,
    column_details
) {
  # Apply imputation steps to columns based on details
  for (detail in column_details) {
    col_name <- detail$column
    col_type <- detail$type
    step_name <- detail$step
    
    if (!is.null(step_name) &&
        nzchar(step_name) &&
        exists(step_name, mode = "function")) {
      func <- get(step_name)
      data[[col_name]] <- func(data[[col_name]], col_type)
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
  result = func(data, column_details)
  return(result)
}
