source("analysis/utils/cons.R")
source("analysis/utils/utils.R")

standardization <- function(col) {
  # Applies Z-score standardization
  numeric_col <- suppressWarnings(as.numeric(col))
  col_mean <- mean(numeric_col, na.rm = TRUE)
  col_sd <- sd(numeric_col, na.rm = TRUE)
  standardized_col <- (numeric_col - col_mean) / col_sd
  return(standardized_col)
}

normalization <- function(col) {
  # Applies Min-Max normalization
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
    # Log transformation (add 1 to avoid log(0))
    transformed_col <- log(col + 1)
  } else if (step == "sqrt") {
    # Square root transformation
    transformed_col <- sqrt(col)
  } else if (step == "reciprocal") {
    # Reciprocal transformation
    transformed_col <- 1 / col
  } else {
    stop("Unsupported transformation step. Use 'log', 'sqrt', 'box-cox', 'reciprocal', or 'yeo-johnson'.")
  }
  
  return(transformed_col)
}

perform_standarization <- function(data, column_details) {
  # Applies standardization to specified columns
  for (detail in column_details) {
    col_name <- detail$column
    col_type <- detail$type
    step_name <- detail$step
    
    if (col_type == "QUANTITATIVE") {
      data[[col_name]] <- standardization(data[[col_name]])
    }
  }
  return(data)
}

perform_normalization <- function(data, column_details) {
  # Applies normalization to specified columns
  for (detail in column_details) {
    col_name <- detail$column
    col_type <- detail$type
    step_name <- detail$step
    
    if (col_type == "QUANTITATIVE") {
      data[[col_name]] <- normalization(data[[col_name]])
    }
  }
  return(data)
}

fix_skewness <- function(data, column_details) {
  # Applies skewness transformation to specified columns
  for (detail in column_details) {
    col_name <- detail$column
    col_type <- detail$type
    step_name <- detail$step
    
    if (col_type == "QUANTITATIVE") {
      data[[col_name]] <- skewness(data[[col_name]], step_name)
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
  # Main function to apply transformations based on the selected method
  func = get(method)
  result = func(data, column_details)
  return(result)
}