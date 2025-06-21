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


perform_pca_reduction <- function(df, target, threshold) {
  target_column <- df[[target]]
  df_without_target <- df[, setdiff(names(df), target), drop = FALSE]
  numeric_data <- df_without_target[, sapply(df_without_target, is.numeric), drop = FALSE]
  
  if (any(is.na(numeric_data))) {
    message("Cannot perform PCA: missing values detected in numeric features.")
    return(NULL)
  }
  
  pca_model <- prcomp(numeric_data, center = TRUE, scale. = TRUE)
  var_explained <- cumsum(pca_model$sdev^2 / sum(pca_model$sdev^2))
  num_components <- which(var_explained >= threshold)[1]
  
  pca_data <- as.data.frame(pca_model$x[, 1:num_components])
  colnames(pca_data) <- paste0("PC", 1:num_components)
  
  message(sprintf("PCA retained %d components explaining %.2f%% variance.",
                  num_components, var_explained[num_components] * 100))
  
  non_numeric_data <- df_without_target[, !names(df_without_target) %in% names(numeric_data), drop = FALSE]
  return(cbind(pca_data, non_numeric_data, setNames(data.frame(target_column), target)))
}


data_reduction <- function(data,
                           column_details,
                           method,
                           step,
                           value,
                           target) {
  # Main function to apply transformations based on the selected method
  func = get(method)
  if (method == "perform_pca_reduction") {
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
