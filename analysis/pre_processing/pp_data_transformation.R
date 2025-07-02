source("analysis/utils/cons.R")
source("analysis/utils/utils.R")

standardization <- function(col) {
  numeric_col <- suppressWarnings(as.numeric(col))
  col_mean <- mean(numeric_col, na.rm = TRUE)
  col_sd <- sd(numeric_col, na.rm = TRUE)
  standardized_col <- (numeric_col - col_mean) / col_sd
  return(standardized_col)
}

normalization <- function(col) {
  numeric_col <- suppressWarnings(as.numeric(col))
  col_min <- min(numeric_col, na.rm = TRUE)
  col_max <- max(numeric_col, na.rm = TRUE)
  normalized_col <- (numeric_col - col_min) / (col_max - col_min)
  return(normalized_col)
}

skewness <- function(col, step) {
  col <- suppressWarnings(as.numeric(col))
  transformed_col <- NULL
  
  if (step == "log") {
    transformed_col <- log(col + 1)
  } else if (step == "sqrt") {
    transformed_col <- sqrt(col)
  } else if (step == "reciprocal") {
    transformed_col <- 1 / col
  } else {
    stop("Unsupported transformation step. Use 'log', 'sqrt', reciprocal'.")
  }
  
  return(transformed_col)
}

perform_standarization <- function(data, column_details) {
  for (detail in column_details) {
    split_string <- strsplit(detail$column, "\\$")[[1]]
    col_name <- split_string[1]
    col_index <- as.integer(split_string[2])
    col_type <- detail$type
    step_name <- detail$step
    
    if (col_type == "QUANTITATIVE") {
      data[[col_index]] <- standardization(data[[col_index]])
    }
  }
  return(data)
}

perform_normalization <- function(data, column_details) {
  for (detail in column_details) {
    split_string <- strsplit(detail$column, "\\$")[[1]]
    col_name <- split_string[1]
    col_index <- as.integer(split_string[2])
    col_type <- detail$type
    step_name <- detail$step
    
    if (col_type == "QUANTITATIVE") {
      data[[col_index]] <- normalization(data[[col_index]])
    }
  }
  return(data)
}

fix_skewness <- function(data, column_details) {
  for (detail in column_details) {
    split_string <- strsplit(detail$column, "\\$")[[1]]
    col_name <- split_string[1]
    col_index <- as.integer(split_string[2])
    col_type <- detail$type
    step_name <- detail$step
    
    if (col_type == "QUANTITATIVE") {
      data[[col_index]] <- skewness(data[[col_index]], step_name)
    }
  }
  return(data)
}

data_transformation <- function(data,
                                column_details,
                                method,
                                step,
                                value,
                                target) {
  func = get(method)
  result = func(data, column_details)
  return(result)
}