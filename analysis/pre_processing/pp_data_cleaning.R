source("analysis/utils/cons.R")
source("analysis/utils/utils.R")

library(dplyr)
library(jsonlite)
library(mlr)
library(here)

get_missing_indexes <- function(col) {
  is.na(col) | is.nan(col) | (col == "")
}

get_outliers_indexes <- function(col) {
  col_char <- as.character(col)
  invalid_idx <- is.na(col_char) | is.nan(col_char) | (col_char == "")
  numeric_col <- suppressWarnings(as.numeric(col_char))
  valid_values <- numeric_col[!invalid_idx]
  
  if (length(valid_values) == 0) return(rep(FALSE, length(col)))
  
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
  col_char <- trimws(as.character(col))
  
  if (column_type == "QUALITATIVE") {
    numeric_like <- grepl("^[0-9]+(\\.[0-9]+)?$", col_char)
    return(numeric_like & !is.na(col_char) & col_char != "")
  } else if (column_type == "QUANTITATIVE") {
    numeric_vals <- suppressWarnings(as.numeric(col_char))
    return(!is.na(col_char) & is.na(numeric_vals))
  }
  
  return(rep(FALSE, length(col)))
}

impute_mean <- function(col, column_type, missing_idx) {
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
  col[missing_idx] <- mean_val
  return(col)
}

impute_median <- function(col, column_type, missing_idx) {
  if (column_type != "QUANTITATIVE") {
    warning("impute_median expects QUANTITATIVE column. Returning column unchanged.")
    return(col)
  }
  
  col_num <- suppressWarnings(as.numeric(as.character(col)))
  if (length(col[!missing_idx]) == 0) {
    warning("No non-missing values to compute median. Returning column unchanged.")
    return(col)
  }
  
  median_val <- median(col_num[!missing_idx], na.rm = TRUE)
  col[missing_idx] <- median_val
  return(col)
}

impute_mode <- function(col, column_type, missing_idx) {
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
  if (!(column_type %in% c("QUALITATIVE", "QUANTITATIVE"))) {
    warning("impute_random expects QUALITATIVE or QUANTITATIVE column. Returning column unchanged.")
    return(col)
  }
  
  col_char <- as.character(col)
  if (length(col_char[!missing_idx]) == 0) {
    warning("Returning column unchanged.")
    return(col)
  }
  
  value_freq <- table(col_char[!missing_idx])
  prob_dist <- value_freq / sum(value_freq)
  sampled_values <- sample(names(value_freq), size = sum(missing_idx), replace = TRUE, prob = prob_dist)
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
    result <- as.numeric(as.character(col))
    result[missing_idx] <- as.numeric(value)
    return(result)
  } else {
    col_char <- as.character(col)
    col_char[missing_idx] <- as.character(value)
    return(col_char)
  }
}

remove <- function(df, col, idx) {
  if (!(col %in% names(df))) stop("Column not found in dataframe")
  if (length(idx) != nrow(df)) stop("The length of Idx must match the number of rows in the dataframe")
  return(df[!idx, ])
}

fix_missing <- function(data, column_details, method) {
  for (detail in column_details) {
    split_string <- strsplit(detail$column, "\\$")[[1]]
    col_name <- split_string[1]
    col_index <- as.integer(split_string[2])
    col_type <- detail$type
    step_name <- detail$step
    value <- detail$value
    
    missing_idx = get_missing_indexes(data[[col_index]])
    
    if (!is.null(step_name) && nzchar(step_name) && exists(step_name, mode = "function")) {
      func <- get(step_name)
      if (step_name == "impute_constant") {
        data[[col_index]] <- func(data[[col_index]], col_type, missing_idx, value)
      } else if (step_name == "remove") {
        data <- func(data, col_name, missing_idx)
      } else {
        data[[col_index]] <- func(data[[col_index]], col_type, missing_idx)
      }
    } else {
      warning(paste("Step function", step_name, "for column", col_name, "does not exist or is invalid. Skipping."))
    }
  }
  return(data)
}

fix_outliers <- function(data, column_details, method) {
  for (detail in column_details) {
    split_string <- strsplit(detail$column, "\\$")[[1]]
    col_name <- split_string[1]
    col_index <- as.integer(split_string[2])
    col_type <- detail$type
    step_name <- detail$step
    value <- detail$value
    
    if (col_type == "QUANTITATIVE") {
      outlier_idx = get_outliers_indexes(data[[col_index]])
    } else {
      next
    }
    
    if (!is.null(step_name) && nzchar(step_name) && exists(step_name, mode = "function")) {
      func <- get(step_name)
      if (step_name == "impute_constant") {
        data[[col_index]] <- func(data[[col_index]], col_type, outlier_idx, value)
      } else if (step_name == "remove") {
        data <- func(data, col_name, outlier_idx)
      } else {
        data[[col_index]] <- func(data[[col_index]], col_type, outlier_idx)
      }
    } else {
      warning(paste("Step function", step_name, "for column", col_name, "does not exist or is invalid. Skipping."))
    }
  }
  return(data)
}

fix_inconsistencies <- function(data, column_details, method) {
  for (detail in column_details) {
    split_string <- strsplit(detail$column, "\\$")[[1]]
    col_name <- split_string[1]
    col_index <- as.integer(split_string[2])
    col_type <- detail$type
    step_name <- detail$step
    value <- detail$value
    
    inconsistent_idx = get_inconsistent_indexes(data[[col_index]], col_type)
    
    if (!is.null(step_name) && nzchar(step_name) && exists(step_name, mode = "function")) {
      func <- get(step_name)
      if (step_name == "impute_constant") {
        data[[col_index]] <- func(data[[col_index]], col_type, inconsistent_idx, value)
      } else if (step_name == "remove") {
        data <- func(data, col_name, inconsistent_idx)
      } else {
        data[[col_index]] <- func(data[[col_index]], col_type, inconsistent_idx)
      }
    } else {
      warning(paste("Step function", step_name, "for column", col_name, "does not exist or is invalid. Skipping."))
    }
  }
  return(data)
}

perform_drop_duplicates <- function(df, by = c("row", "column")) {
  by <- match.arg(by)
  if (by == "row") {
    df <- df[!duplicated(df), ]
  } else if (by == "column") {
    df <- df[, !duplicated(colnames(df))]
  }
  return(df)
}

data_cleaning <- function(data, column_details, method, step, value, target) {
  func = get(method)
  if (method == "perform_drop_duplicates") {
    result = func(data, value)
  } else {
    result = func(data, column_details, method)
  }
  return(result)
}