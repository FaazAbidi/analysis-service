source("analysis/utils/cons.R")
source("analysis/utils/utils.R")

perform_sampling <- function(df, sample_size) {
  if (sample_size > nrow(df)) {
    stop("Sample size cannot be greater than the number of rows in the dataframe")
  }
  
  sampled_df <- df[sample(nrow(df), size = sample_size), ]
  
  return(sampled_df)
}

perform_drop_columns <- function(data, column_details) {
  for (detail in column_details) {
    split_string <- strsplit(detail$column, "\\$")[[1]]
    col_name <- split_string[1]
    col_index <- as.integer(split_string[2])
    
    if (col_name %in% colnames(data)) {
      data[[col_index]] <- NULL
    }
  }
  return(data)
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