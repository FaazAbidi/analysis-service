source("analysis/utils/cons.R")

library(dplyr)
library(jsonlite)

check_column_type <- function(
    df,
    col_name
) {
  numeric_count <- sum(
    !is.na(suppressWarnings(as.numeric(df[[col_name]]))) & 
      !is.nan(suppressWarnings(as.numeric(df[[col_name]])))
  )
  total_count <- length(df[[col_name]])
  
  if (numeric_count / total_count > 0.5) {
    return("QUANTITATIVE")
  } else {
    return("QUALITATIVE")
  }
}

check_duplicates <- function(
    df
) {
  dup_flags <- duplicated(df)
  exists <- any(dup_flags)
  count <- sum(dup_flags)
  
  recommendation <- "No duplicates found."
  if (exists) {
    recommendation <- "Duplicates detected: all duplicate rows should be removed."
  }
  
  return(list(exists = exists, count = count, recommendation = recommendation))
}

has_missing <- function(
    data,
    model
) {
  missing_counts <- sapply(data, function(x) {
    sum(is.na(x) | is.nan(x) | x == "" | grepl("^\\s*$", x))
  })
  
  total_missing <- sum(missing_counts)
  exists <- total_missing > 0
  
  recommendation <- paste0("No missing values found for ", model, ".")
  if (exists) {
    if (is.null(model)) {
      recommendation <- paste0("Missing values detected: either remove or impute missing values.")
    } else if (model %in% HANDLES_MISSING_VALUES) {
      recommendation <- paste0("Missing values detected but not an issue for tree-based models like ", model, ".")
    } else {
      recommendation <- paste0("Missing values detected: either remove or impute missing values for  ", model, ".")
    }
  }
  
  return(list(exists = exists, count = total_missing, recommendation = recommendation))
}

check_missing <- function(
    data,
    model
) {
  missing_info <- sapply(data, function(x) {
    sum(is.na(x) | is.nan(x) | x == "" | grepl("^\\s*$", x))
  })
  
  # Get indices directly, not by name
  missing_indices <- which(missing_info > 0)
  missing_counts <- missing_info[missing_indices]
  
  missing_list <- lapply(seq_along(missing_indices), function(i) {
    idx <- missing_indices[i]
    col_name <- colnames(data)[idx]
    list(column = paste0(col_name, "$", idx), count = missing_counts[i])
  })
  
  recommendation <- paste0("No missing values in any column for ", model, ".")
  if (length(missing_indices) > 0) {
    if (is.null(model)) {
      recommendation <- paste0("Missing values found in columns: remove or impute them.")
    } else if (model %in% HANDLES_MISSING_VALUES) {
      recommendation <- paste0("Missing values found but not an issue for tree-based models like ", model, ".")
    } else {
      recommendation <- paste0("Missing values found in columns: remove or impute them for ", model, ".")
    }
  }
  
  return(list(
    missing_info = missing_list,
    recommendation = recommendation
  ))
}

check_outliers <- function(
    data,
    model,
    column_types = NULL
) {
  if (!is.null(column_types) && is.character(column_types)) {
    parsed <- fromJSON(column_types)
    if (is.data.frame(parsed)) {
      column_types <- lapply(seq_len(nrow(parsed)), function(i) {
        list(column = parsed$column[[i]], type = parsed$type[[i]])
      })
    }
  }
  
  outlier_indices <- c()
  outlier_counts <- c()
  
  for (idx in seq_along(colnames(data))) {
    col_name <- colnames(data)[idx]
    col_type <- NULL
    if (!is.null(column_types)) {
      matched <- Filter(function(entry) {
        is.list(entry) && !is.null(entry[["column"]]) && entry[["column"]] == col_name
      }, column_types)
      if (length(matched) > 0) {
        col_type <- matched[[1]][["type"]]
        if (col_type == "QUALITATIVE") next
      }
    }
    if (is.null(col_type)) {
      col_type <- check_column_type(data, col_name)
      if (col_type != "QUANTITATIVE") next
    }
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
      outlier_indices <- c(outlier_indices, idx)
      outlier_counts <- c(outlier_counts, count_outliers)
    }
  }
  
  outlier_list <- lapply(seq_along(outlier_indices), function(i) {
    idx <- outlier_indices[i]
    col_name <- colnames(data)[idx]
    list(column = paste0(col_name, "$", idx), count = outlier_counts[i])
  })
  
  recommendation <- paste0("No outliers detected for ", model, ".")
  if (length(outlier_indices) > 0) {
    if (is.null(model)) {
      recommendation <- "Outliers detected: consider removing or replacing outliers."
    } else if (model %in% HANDLES_OUTLIERS_WELL) {
      recommendation <- paste0("Outliers detected but not an issue for tree-based models like ", model, ".")
    } else {
      recommendation <- paste0("Outliers detected: consider removing or replacing outliers for ", model, ".")
    }
  }
  
  return(list(
    outlier_info = outlier_list,
    recommendation = recommendation
  ))
}

check_inconsistencies <- function(
    data,
    model,
    column_types = NULL
) {
  if (!is.null(column_types) && is.character(column_types)) {
    parsed <- fromJSON(column_types)
    if (is.data.frame(parsed)) {
      column_types <- lapply(seq_len(nrow(parsed)), function(i) {
        list(column = parsed$column[[i]], type = parsed$type[[i]])
      })
    }
  }
  
  inconsistent_indices <- c()
  inconsistent_counts <- c()
  
  for (idx in seq_along(colnames(data))) {
    col_name <- colnames(data)[idx]
    col_data <- data[[col_name]]
    col_type <- NULL
    if (!is.null(column_types)) {
      matched <- Filter(function(entry) {
        is.list(entry) && !is.null(entry[["column"]]) && entry[["column"]] == col_name
      }, column_types)
      if (length(matched) > 0) {
        col_type <- matched[[1]][["type"]]
      }
    }
    if (is.null(col_type)) {
      col_type <- check_column_type(data, col_name)
    }
    if (col_type == "QUALITATIVE") {
      col_as_char <- as.character(col_data)
      numeric_like <- grepl("^[0-9]+(\\.[0-9]+)?$", col_as_char)
      numeric_like_count <- sum(numeric_like & !is.na(col_as_char) & col_as_char != "")
      if (numeric_like_count > 0) {
        inconsistent_indices <- c(inconsistent_indices, idx)
        inconsistent_counts <- c(inconsistent_counts, numeric_like_count)
      }
    } 
    if (col_type == "QUANTITATIVE") {
      col_char <- as.character(col_data)
      numeric_vals <- suppressWarnings(as.numeric(col_char))
      inconsistent_count <- sum(!is.na(col_char) & is.na(numeric_vals))
      if (inconsistent_count > 0) {
        inconsistent_indices <- c(inconsistent_indices, idx)
        inconsistent_counts <- c(inconsistent_counts, inconsistent_count)
      }
    }
  }
  
  inconsistent_list <- lapply(seq_along(inconsistent_indices), function(i) {
    idx <- inconsistent_indices[i]
    col_name <- colnames(data)[idx]
    list(column = paste0(col_name, "$", idx), count = inconsistent_counts[i])
  })
  
  recommendation <- paste0("No inconsistent values detected for ", model, ".")
  if (length(inconsistent_indices) > 0) {
    if (is.null(model)) {
      recommendation <- "Inconsistent values detected: consider removing or replacing them."
    } else if (model %in% HANDLES_INCONSISTENT_VALUES) {
      recommendation <- paste0("Inconsistent values detected but not an issue for tree-based models like ", model, ".")
    } else {
      recommendation <- paste0("Inconsistent values detected: consider removing or replacing them for ", model, ".")
    }
  }
  
  return(list(
    inconsistent_info = inconsistent_list,
    recommendation = recommendation
  ))
}

pre_analysis_cleaning <- function(
    data,
    model,
    column_types
) {
  duplicates <- check_duplicates(data)
  missing <- has_missing(data, model)
  missing_columns <- check_missing(data, model)
  outliers <- check_outliers(data, model, column_types)
  inconsistencies <- check_inconsistencies(data, model, column_types)
  
  result <- list(
    duplicates = duplicates,
    missing_overall = missing,
    missing_columns = missing_columns,
    outliers = outliers,
    inconsistencies = inconsistencies
  )
  
  return(result)
}
