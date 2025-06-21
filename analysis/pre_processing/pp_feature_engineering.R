source("analysis/utils/cons.R")
source("analysis/utils/utils.R")

equal_width <- function(col, col_name, bin_size) {
  min_val <- min(col, na.rm = TRUE)
  max_val <- max(col, na.rm = TRUE)
  bin_width <- (max_val - min_val) / bin_size
  
  # Ensure the last bin includes max_val
  bin_breaks <- seq(min_val, max_val + bin_width * 0.01, by = bin_width)
  
  # Generate bin labels (e.g., "12 ≤ age < 24")
  bin_labels <- sapply(1:(length(bin_breaks) - 1), function(i) {
    if (i == length(bin_breaks) - 1) {
      paste(bin_breaks[i], "≤", col_name, "≤", bin_breaks[i + 1])
    } else {
      paste(bin_breaks[i], "≤", col_name, "<", bin_breaks[i + 1])
    }
  })
  
  bins <- cut(col, 
              breaks = bin_breaks, 
              include.lowest = TRUE, 
              right = FALSE, 
              labels = bin_labels)
  
  return(as.character(bins))
}

equal_depth <- function(col, col_name, bin_size) {
  # Calculate quantile breaks (handle duplicates)
  bin_boundaries <- unique(
    quantile(col, probs = seq(0, 1, length.out = bin_size + 1), 
             na.rm = TRUE)
  )
  
  # Regenerate bin_size if duplicates reduced it
  if (length(bin_boundaries) - 1 < bin_size) {
    warning("Reduced bin size due to duplicate quantiles.")
    bin_size <- length(bin_boundaries) - 1
  }
  
  # Generate bin labels (last bin includes upper bound)
  bin_labels <- sapply(1:(length(bin_boundaries) - 1), function(i) {
    if (i == length(bin_boundaries) - 1) {
      paste(bin_boundaries[i], "≤", col_name, "≤", bin_boundaries[i + 1])
    } else {
      paste(bin_boundaries[i], "≤", col_name, "<", bin_boundaries[i + 1])
    }
  })
  
  # Assign bins based on quantile breaks
  bins <- cut(col, 
              breaks = bin_boundaries, 
              include.lowest = TRUE, 
              right = FALSE, 
              labels = bin_labels)
  
  return(as.character(bins))
}

perform_combine_features <- function(df, column_details, step, value) {
  # Extract column names and their types from column_details
  cols <- sapply(column_details, function(x) x$column)
  column_types <- sapply(column_details, function(x) x$type)
  operation <- step
  
  # Check if all the provided columns exist in the dataframe
  if (!all(cols %in% names(df))) {
    stop("One or more columns are not found in the dataframe")
  }
  
  # Check if all columns are of type 'QUANTITATIVE'
  if (!all(column_types == "QUANTITATIVE")) {
    stop("All columns must be of type 'QUANTITATIVE' for this operation.")
  }
  
  # Extract the columns from the dataframe
  selected_cols <- df[, cols, drop = FALSE]
  
  # Create a new column name based on the columns and operation (without pipe symbol)
  new_col_name <- paste(cols, collapse = paste(" ", operation, " "))
  
  # Dynamically get the function for the operation
  operation_func <- get(operation)
  
  # Perform the operation using Reduce with the dynamic operation function
  combined_column <- Reduce(operation_func, selected_cols)
  
  # Add the combined column to the dataframe
  df$combined_features <- combined_column
  colnames(df)[ncol(df)] <- paste0("Combined Features (", new_col_name, ")")
  
  return(df)
}

perform_one_hot_encoding <- function(data, column_details, step, value) {
  # Applies one-hot encoding to specified columns
  for (detail in column_details) {
    col_name <- detail$column
    col_type <- detail$type
    
    if (col_type == "QUALITATIVE") {
      unique_vals <- unique(data[[col_name]])
      
      for (val in unique_vals) {
        new_col_name <- paste0(col_name, " (", val, ")")
        data[[new_col_name]] <- ifelse(data[[col_name]] == val, 1, 0)
      }
      # Drop the original column after encoding
      data[[col_name]] <- NULL
    }
  }
  return(data)
}

perform_binning <- function(data, column_details, step, value) {
  # Apply imputation steps to columns based on details
  for (detail in column_details) {
    col_name <- detail$column
    col_type <- detail$type
    step_name <- detail$step
    value <- detail$value
    
    if (!is.null(step_name) &&
        nzchar(step_name) &&
        exists(step_name, mode = "function")) {
      func <- get(step_name)
      
      data[[paste("Bin (", col_name, ")", sep = "")]] <- as.character(func(data[[col_name]], col_name, value))
    }
  }
  return(data)
}


perform_label_encoding <- function(data, column_details, step, value) {
  # Applies label encoding to specified columns
  for (detail in column_details) {
    col_name <- detail$column
    col_type <- detail$type
    
    if (col_type == "QUALITATIVE") {
      # Get unique values from the column
      unique_vals <- unique(data[[col_name]])
      
      # Create a mapping from the unique values to labels (0, 1, 2, ...)
      label_map <- setNames(seq_along(unique_vals) - 1, unique_vals)
      
      # Create a new column for label encoding
      new_col_name <- paste0("Label Encoded (", col_name, ")")
      
      # Apply the label encoding using match to handle unknown values
      data[[new_col_name]] <- as.integer(sapply(data[[col_name]], function(x) match(x, names(label_map)) - 1))
      
      # Drop the original column after encoding
      data[[col_name]] <- NULL
    }
  }
  return(data)
}



feature_engineering <- function(data,
                                column_details,
                                method,
                                step,
                                value,
                                target) {
  # Main function to apply transformations based on the selected method
  func = get(method)
  result = func(data, column_details, step, value)
  return(result)
}
