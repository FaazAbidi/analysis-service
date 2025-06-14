source("analysis/utils/cons.R")
source("analysis/utils/utils.R")

perform_sampling <- function(df, sample_size) {
  # Check if the sample_size is greater than the number of rows in the dataframe
  if (sample_size > nrow(df)) {
    stop("Sample size cannot be greater than the number of rows in the dataframe")
  }
  
  # Perform random sampling with the specified sample size
  sampled_df <- df[sample(nrow(df), size = sample_size), ]
  
  return(sampled_df)
}

perform_drop_columns <- function(data, column_details) {
  # Drop columns specified in column_details
  for (detail in column_details) {
    col_name <- detail$column
    # Check if the column exists in the data and drop it
    if (col_name %in% colnames(data)) {
      data[[col_name]] <- NULL
    }
  }
  return(data)
}

perform_pca <- function(df, target, top) {
  # Check if the target column exists
  if (!(target %in% names(df))) {
    stop("Target column not found in the dataframe")
  }
  
  # Separate the target column from the rest of the data
  target_column <- df[[target]]
  df_without_target <- df[, setdiff(names(df), target), drop = FALSE]
  
  # Scale the data (standardize)
  scaled_df <- scale(df_without_target)
  
  # Perform PCA
  pca_result <- prcomp(scaled_df, center = TRUE, scale. = TRUE)
  
  # Ensure 'top' value is valid
  if (top > ncol(pca_result$x)) {
    stop("Top value must be less than or equal to the number of components")
  }
  
  # Get the transformed data with the top principal components
  pca_data <- pca_result$x[, 1:top]
  
  # Combine the PCA results with the target column
  result_df <- cbind(pca_data, target = target_column)
  
  return(result_df)
}




data_reduction <- function(data,
                           column_details,
                           method,
                           step,
                           value,
                           target) {
  # Main function to apply transformations based on the selected method
  func = get(method)
  if (method == "perform_pca") {
    result = func(data, target, value)
  }
  else if (method == "perform_drop_columns") {
    result = func(data, column_details)
  }
  else {
    result = func(data, value)
  }
  
  return(result)
}
