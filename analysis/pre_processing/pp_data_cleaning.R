source("analysis/utils/cons.R")
source("analysis/utils/utils.R")

library(dplyr)
library(jsonlite)
library(mlr)
library(here)

get_missing_indexes <- function(col) {
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
  col_char <- trimws(as.character(col))  # Remove leading/trailing spaces
  
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

impute_mean <- function(col, column_type, missing_idx) {
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

impute_median <- function(col, column_type, missing_idx) {
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
  
  median_val <- median(col_num[!missing_idx], na.rm = TRUE)
  col[missing_idx] <- round(median_val, average_decimal_places(col_num))
  return(col)
}

impute_mode <- function(col, column_type, missing_idx) {
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
  
  col[missing_idx] <- mode_val
  
  return(col)
}

impute_random <- function(col, column_type, missing_idx) {
  # Imputes missing values by random sampling from the distribution of existing values
  if (!(column_type %in% c("QUALITATIVE", "QUANTITATIVE"))) {
    warning("impute_random expects QUALITATIVE or QUANTITATIVE column. Returning column unchanged.")
    return(col)
  }
  
  col_char <- as.character(col)
  
  # Check if there are non-missing values to sample from
  if (length(col_char[!missing_idx]) == 0) {
    warning("Returning column unchanged.")
    return(col)
  }
  
  # Calculate the frequency of each unique value
  value_freq <- table(col_char[!missing_idx])
  
  # Create a probability distribution based on the frequency of each value
  prob_dist <- value_freq / sum(value_freq)
  
  # Sample from the values based on the computed probability distribution
  sampled_values <- sample(names(value_freq), size = sum(missing_idx), replace = TRUE, prob = prob_dist)
  
  # Assign the sampled values to the missing positions
  col_char[missing_idx] <- sampled_values
  
  if (column_type == "QUANTITATIVE") {
    col_num <- suppressWarnings(as.numeric(col_char))
    result <- col_char
    result[!is.na(col_num)] <- as.character(col_num[!is.na(col_num)])
    return(result)
  } else {
    return(col_char)
  }
}


impute_constant <- function(col, column_type, missing_idx, value) {
  if (!(column_type %in% c("QUALITATIVE", "QUANTITATIVE"))) {
    warning("impute_constant expects QUALITATIVE or QUANTITATIVE column. Returning column unchanged.")
    return(col)
  }
  
  if (length(col[!missing_idx]) == 0) {
    warning("Returning column unchanged.")
    return(col)
  }
  
  if (column_type == "QUANTITATIVE") {
    # For numeric columns, ensure numeric output
    result <- as.numeric(as.character(col))
    result[missing_idx] <- as.numeric(value)
    return(result)
  } else {
    # For qualitative columns
    col_char <- as.character(col)
    col_char[missing_idx] <- as.character(value)
    return(col_char)
  }
}

remove <- function(df, col, idx) {
  if (!(col %in% names(df))) {
    stop("Column not found in dataframe")
  }
  
  if (length(idx) != nrow(df)) {
    stop("The length of Idx must match the number of rows in the dataframe")
  }
  
  return(df[!idx, ])
}

fix_missing <- function(data, column_details, method) {
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
        data <- func(data, col_name, missing_idx)
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

fix_outliers <- function(data, column_details, method) {
  # Apply imputation steps to columns based on details
  for (detail in column_details) {
    col_name <- detail$column
    col_type <- detail$type
    step_name <- detail$step
    value <- detail$value
    
    if (col_type == "QUANTITATIVE") {
      outlier_idx = get_outliers_indexes(data[[col_name]])
    } else {
      next
    }
    
    if (!is.null(step_name) &&
        nzchar(step_name) &&
        exists(step_name, mode = "function")) {
      func <- get(step_name)
      
      if (step_name == "impute_constant") {
        data[[col_name]] <- func(data[[col_name]], col_type, outlier_idx, value)
      }
      else if (step_name == "remove") {
        data <- func(data, col_name, outlier_idx)
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

fix_inconsistencies <- function(data, column_details, method) {
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
        data <- func(data, col_name, inconsistent_idx)
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

data_cleaning <- function(data,
                          column_details,
                          method,
                          step,
                          value,
                          target) {
  func = get(method)
  result = func(data, column_details, method)
  return(result)
}
