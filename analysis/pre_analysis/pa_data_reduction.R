source("analysis/utils/cons.R")

is_sampling_required <- function(
    df,
    threshold_sampling = DEFAULT_THRESHOLD_FOR_SAMPLING
) {
  if (is.null(threshold_sampling)) {
    threshold_sampling <- DEFAULT_THRESHOLD_FOR_SAMPLING
  }
  
  return(nrow(df) > threshold_sampling)
}

check_multicollinearity <- function(
    data,
    target,
    column_types = NULL,
    threshold_multicollinearity = DEFAULT_THRESHOLD_CHECK_MULTICOLLINEARITY
) {
  if (is.null(target)) return(FALSE)
  
  if (is.null(threshold_multicollinearity)) {
    threshold_multicollinearity <- DEFAULT_THRESHOLD_CHECK_MULTICOLLINEARITY
  }
  
  data <- na.omit(data)
  if (nrow(data) == 0) return(FALSE)
  if (!(target %in% names(data))) stop("Target variable not found in data.")
  
  if (!is.null(column_types) && is.character(column_types)) {
    parsed <- jsonlite::fromJSON(column_types)
    if (is.data.frame(parsed)) {
      column_types <- lapply(seq_len(nrow(parsed)), function(i) {
        list(column = parsed$column[[i]], type = parsed$type[[i]])
      })
    }
  }
  
  quantitative_indices <- c()
  for (idx in seq_along(names(data))) {
    col_name <- names(data)[idx]
    col_type <- NULL
    if (!is.null(column_types)) {
      matched <- Filter(function(entry) {
        is.list(entry) && !is.null(entry[["column"]]) && entry[["column"]] == col_name
      }, column_types)
      if (length(matched) > 0) {
        col_type <- matched[[1]][["type"]]
      }
    }
    if (is.null(col_type) && is.numeric(data[[col_name]])) {
      quantitative_indices <- c(quantitative_indices, idx)
    } else if (!is.null(col_type) && col_type == "QUANTITATIVE") {
      quantitative_indices <- c(quantitative_indices, idx)
    }
  }
  
  quantitative_columns <- lapply(quantitative_indices, function(idx) {
    paste0(names(data)[idx], "$", idx)
  })
  
  numeric_data <- data[, unlist(names(data)[quantitative_indices]), drop = FALSE]
  if (ncol(numeric_data) < 2) {
    return(list(
      exists = FALSE,
      columns = quantitative_columns
    ))
  }
  
  corr_mat <- cor(numeric_data, use = "pairwise.complete.obs")
  abs_vals <- abs(corr_mat[upper.tri(corr_mat)])
  
  exists <- any(abs_vals > threshold_multicollinearity)
  return(list(
    exists = exists,
    columns = quantitative_columns
  ))
}

check_high_dimensionality <- function(
    data,
    threshold_check_dimensionality = DEFAULT_THRESHOLD_CHECK_DIMENSIONALITY
) {
  if (is.null(threshold_check_dimensionality)) {
    threshold_check_dimensionality <- DEFAULT_THRESHOLD_CHECK_DIMENSIONALITY
  }
  
  data <- na.omit(data)
  numeric_data <- data[sapply(data, is.numeric)]
  ratio <- ncol(numeric_data) / nrow(numeric_data)
  return(ratio > threshold_check_dimensionality)
}

pre_analysis_reduction <- function(
    data,
    target,
    column_types,
    threshold_sampling,
    threshold_check_dimensionality,
    threshold_check_multicollinearity
) {
  sampling_needed <- is_sampling_required(data, threshold_sampling)
  multicollinearity_result <- check_multicollinearity(data, target, column_types, threshold_check_multicollinearity)
  high_dimensionality_exists <- check_high_dimensionality(data, threshold_check_dimensionality)
  
  multicollinearity_exists <- if (is.list(multicollinearity_result)) multicollinearity_result$exists else multicollinearity_result
  multicollinearity_columns <- if (is.list(multicollinearity_result)) multicollinearity_result$columns else NULL
  
  pca_required <- ifelse(multicollinearity_exists, TRUE, FALSE)
  
  result <- list(
    is_sampling_required = sampling_needed,
    multicollinearity_exists = multicollinearity_exists,
    multicollinearity_columns = multicollinearity_columns,
    high_dimensionality_exists = high_dimensionality_exists,
    is_pca_required = pca_required
  )
  
  return(result)
}
