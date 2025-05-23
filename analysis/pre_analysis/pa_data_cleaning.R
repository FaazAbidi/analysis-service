source("utils/cons.R")

# Load necessary libraries
if (!require("dplyr")) install.packages("dplyr")
library(dplyr)

if (!require("jsonlite")) install.packages("jsonlite")
library(jsonlite)

# Function to determine column type: QUANTITATIVE if >50% numeric, else QUALITATIVE
check_column_type <- function(df, col_name) {
  numeric_count <- sum(!is.na(suppressWarnings(as.numeric(df[[col_name]]))) & !is.nan(suppressWarnings(as.numeric(df[[col_name]]))))
  total_count <- length(df[[col_name]])
  
  if (numeric_count / total_count > 0.5) {
    return("QUANTITATIVE")
  } else {
    return("QUALITATIVE")
  }
}

# Check for duplicates in the whole dataframe
check_duplicates <- function(df) {
  dup_flags <- duplicated(df)
  exists <- any(dup_flags)
  count <- sum(dup_flags)
  
  recommendation <- "No duplicates found."
  if (exists) {
    recommendation <- "Duplicates detected: all duplicate rows should be removed."
  }
  
  return(list(exists = exists, count = count, recommendation = recommendation))
}

# Check if missing values exist anywhere in data, provide recommendation based on model
has_missing <- function(data, model) {
  missing_counts <- sapply(data, function(x) {
    sum(is.na(x) | is.nan(x) | x == "" | grepl("^\\s*$", x))
  })
  
  total_missing <- sum(missing_counts)
  exists <- total_missing > 0
  
  recommendation <- paste0("No missing values found for ", model, ".")
  if (exists) {
    if (model %in% HANDLES_MISSING_VALUES) {
      recommendation <- paste0("Missing values detected but not an issue for tree-based models like ", model, ".")
    } else {
      recommendation <- paste0("Missing values detected: either remove or impute missing values for  ", model, ".")
    }
  }
  
  return(list(exists = exists, count = total_missing, recommendation = recommendation))
}

# Check which columns have missing values and counts, with recommendations
check_missing <- function(data, model) {
  missing_info <- sapply(data, function(x) {
    sum(is.na(x) | is.nan(x) | x == "" | grepl("^\\s*$", x))
  })
  
  missing_cols <- names(missing_info[missing_info > 0])
  missing_counts <- missing_info[missing_info > 0]
  
  recommendation <- paste0("No missing values in any column for ", model, ".")
  if (length(missing_cols) > 0) {
    if (model %in% HANDLES_MISSING_VALUES) {
      recommendation <- paste0("Missing values found but not an issue for tree-based models like ", model, ".")
    } else {
      recommendation <- paste0("Missing values found in columns: remove or impute them for  ", model, ".")
    }
  }
  
  return(list(columns = missing_cols, counts = missing_counts, recommendation = recommendation))
}

# Detect outliers based on IQR method, provide counts and recommendation
check_outliers <- function(data, model) {
  outlier_columns <- c()
  outlier_counts <- c()
  
  for (col_name in colnames(data)) {
    if (check_column_type(data, col_name) == "QUANTITATIVE") {
      numeric_column <- suppressWarnings(as.numeric(data[[col_name]]))
      valid_values <- numeric_column[!is.na(numeric_column)]
      
      if (length(valid_values) == 0) next
      
      Q1 <- quantile(valid_values, 0.25)
      Q3 <- quantile(valid_values, 0.75)
      IQR <- Q3 - Q1
      
      lower_bound <- Q1 - 1.5 * IQR
      upper_bound <- Q3 + 1.5 * IQR
      
      count_outliers <- sum(valid_values < lower_bound | valid_values > upper_bound)
      
      if (count_outliers > 0) {
        outlier_columns <- c(outlier_columns, col_name)
        outlier_counts <- c(outlier_counts, count_outliers)
      }
    }
  }
  
  recommendation <- paste0("No outliers detected for ", model, ".")
  if (length(outlier_columns) > 0) {
    if (model %in% HANDLES_OUTLIERS_WELL) {
      recommendation <- paste0("Outliers detected but not an issue for tree-based models like ", model, ".")
    } else {
      recommendation <- paste0("Outliers detected: consider removing or replacing outliers for ", model, ".")
    }
  }
  
  return(list(columns = outlier_columns, counts = outlier_counts, recommendation = recommendation))
}

# Check inconsistencies in data (numeric-like strings in qualitative columns or non-numeric in quantitative columns)
check_inconsistencies <- function(data, model) {
  inconsistent_columns <- c()
  inconsistent_counts <- c()
  
  for (col_name in colnames(data)) {
    col_data <- data[[col_name]]
    col_type <- check_column_type(data, col_name)
    
    if (col_type == "QUALITATIVE") {
      col_as_char <- as.character(col_data)
      numeric_like <- grepl("^[0-9]+(\\.[0-9]+)?$", col_as_char)
      numeric_like_count <- sum(numeric_like & !is.na(col_as_char) & col_as_char != "")
      
      if (numeric_like_count > 0) {
        inconsistent_columns <- c(inconsistent_columns, col_name)
        inconsistent_counts <- c(inconsistent_counts, numeric_like_count)
      }
    } 
    
    if (col_type == "QUANTITATIVE") {
      col_char <- as.character(col_data)
      numeric_vals <- suppressWarnings(as.numeric(col_char))
      inconsistent_count <- sum(!is.na(col_char) & is.na(numeric_vals))
      
      if (inconsistent_count > 0) {
        inconsistent_columns <- c(inconsistent_columns, col_name)
        inconsistent_counts <- c(inconsistent_counts, inconsistent_count)
      }
    }
  }
  
  recommendation <- paste0("No inconsistent values detected for ", model, ".")
  if (length(inconsistent_columns) > 0) {
    if (model %in% HANDLES_INCONSISTENT_VALUES) {
      recommendation <- paste0("Inconsistent values detected but not an issue for tree-based models like ", model, ".")
    } else {
      recommendation <- paste0("Inconsistent values detected: consider removing or replacing them for ", model, ".")
    }
  }
  
  return(list(columns = inconsistent_columns, counts = inconsistent_counts, recommendation = recommendation))
}

# Count values in a column that cannot be converted to numeric
count_non_convertible <- function(data, col_name) {
  if (!(col_name %in% colnames(data))) {
    stop("Column not found in dataframe.")
  }
  
  col_char <- as.character(data[[col_name]])
  numeric_vals <- suppressWarnings(as.numeric(col_char))
  
  count <- sum(!is.na(col_char) & is.na(numeric_vals))
  return(count)
}

# Main pre-analysis cleaning function aggregating checks
pre_analysis_cleaning <- function(data, model) {
  duplicates <- check_duplicates(data)
  missing <- has_missing(data, model)
  missing_columns <- check_missing(data, model)
  outliers <- check_outliers(data, model)
  inconsistencies <- check_inconsistencies(data, model)
  
  result <- list(
    duplicates = duplicates,
    missing_overall = missing,
    missing_columns = missing_columns,
    outliers = outliers,
    inconsistencies = inconsistencies
  )
  
  return(result)
}
