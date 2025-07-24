source("analysis/utils/cons.R")
source("analysis/utils/utils.R")

equal_width <- function(col, bin_size) {
  col <- suppressWarnings(as.numeric(col))
  min_val <- min(col, na.rm = TRUE)
  max_val <- max(col, na.rm = TRUE)
  bin_width <- (max_val - min_val) / bin_size
  
  bin_breaks <- seq(min_val, max_val + bin_width * 0.01, by = bin_width)
  
  bin_labels <- sapply(1:(length(bin_breaks) - 1), function(i) {
    if (i == length(bin_breaks) - 1) {
      paste(bin_breaks[i], "<=", "value", "<=", bin_breaks[i + 1])
    } else {
      paste(bin_breaks[i], "<=", "value", "<", bin_breaks[i + 1])
    }
  })
  
  bins <- cut(col, 
              breaks = bin_breaks, 
              include.lowest = TRUE, 
              right = FALSE, 
              labels = bin_labels)
  
  return(as.character(bins))
}

equal_depth <- function(col, bin_size) {
  col <- suppressWarnings(as.numeric(col))
  bin_boundaries <- unique(
    quantile(col, probs = seq(0, 1, length.out = bin_size + 1), 
             na.rm = TRUE)
  )
  
  if (length(bin_boundaries) - 1 < bin_size) {
    warning("Reduced bin size due to duplicate quantiles.")
    bin_size <- length(bin_boundaries) - 1
  }
  
  bin_labels <- sapply(1:(length(bin_boundaries) - 1), function(i) {
    if (i == length(bin_boundaries) - 1) {
      paste(bin_boundaries[i], "<=", "value", "<=", bin_boundaries[i + 1])
    } else {
      paste(bin_boundaries[i], "<=", "value", "<", bin_boundaries[i + 1])
    }
  })
  
  bins <- cut(col, 
              breaks = bin_boundaries, 
              include.lowest = TRUE, 
              right = FALSE, 
              labels = bin_labels)
  
  return(as.character(bins))
}

perform_combine_features <- function(df, column_details, step, value) {
  cols <- sapply(column_details, function(x) x$column)
  split_cols <- strsplit(cols, "\\$")
  col_names <- sapply(split_cols, function(x) x[1])
  col_indices <- sapply(split_cols, function(x) as.integer(x[2]))
  column_types <- sapply(column_details, function(x) x$type)
  operation <- step
  
  if (!all(col_names %in% names(df))) {
    stop("One or more columns are not found in the dataframe")
  }
  
  if (!all(column_types == "QUANTITATIVE")) {
    stop("All columns must be of type 'QUANTITATIVE' for this operation.")
  }
  
  selected_cols <- df[, col_indices, drop = FALSE]
  selected_cols[] <- lapply(selected_cols, function(x) as.numeric(x))
  
  operation_func <- switch(operation,
                           "+" = function(row) sum(row, na.rm = TRUE),
                           "-" = function(row) Reduce(`-`, row[!is.na(row)]),
                           "*" = function(row) prod(row, na.rm = TRUE),
                           "/" = function(row) Reduce(`/`, row[!is.na(row)]),
                           "%%" = function(row) Reduce(`%%`, row[!is.na(row)]),
                           stop("Operation not supported")
  )
  
  combined_column <- apply(selected_cols, 1, function(row) {
    # If all are NA, return NA; else, perform the operation with non-NA values
    if (all(is.na(row))) {
      NA
    } else {
      operation_func(row)
    }
  })
  
  new_col_name <- paste(col_names, collapse = paste(" ", operation, " "))
  df$combined_features <- combined_column
  colnames(df)[ncol(df)] <- paste0("Combined Features (", new_col_name, ")")
  
  return(df)
}



perform_one_hot_encoding <- function(data, column_details, step, value) {
  col_indices_to_delete <- c()
  for (detail in column_details) {
    split_string <- strsplit(detail$column, "\\$")[[1]]
    col_name <- split_string[1]
    col_index <- as.integer(split_string[2])
    col_type <- detail$type
    
    if (col_type == "QUALITATIVE") {
      unique_vals <- unique(data[[col_index]])
      
      for (val in unique_vals) {
        new_col_name <- paste0(col_name, " (", val, ")")
        new_col <- ifelse(data[[col_index]] == val, 1, 0)
        data <- cbind(data, setNames(list(new_col), new_col_name))
      }
      col_indices_to_delete <- c(col_indices_to_delete, col_index)
    }
  }
  
  for (index_del in col_indices_to_delete) {
    data[[index_del]] <- NULL
  }
  
  return(data)
}

perform_binning <- function(data, column_details, step, value) {
  for (detail in column_details) {
    split_string <- strsplit(detail$column, "\\$")[[1]]
    col_name <- split_string[1]
    col_index <- as.integer(split_string[2])
    col_type <- detail$type
    step_name <- detail$step
    value <- detail$value
    
    if (!is.null(step_name) &&
        nzchar(step_name) &&
        exists(step_name, mode = "function")) {
      func <- get(step_name)
      data[[paste("Bin (", col_name, ")", sep = "")]] <- as.character(func(data[[col_index]], value))
    }
  }
  return(data)
}

perform_label_encoding <- function(data, column_details, step, value) {
  for (detail in column_details) {
    split_string <- strsplit(detail$column, "\\$")[[1]]
    col_name <- split_string[1]
    col_index <- as.integer(split_string[2])
    col_type <- detail$type
    
    if (col_type == "QUALITATIVE") {
      unique_vals <- unique(data[[col_index]])
      label_map <- setNames(seq_along(unique_vals) - 1, unique_vals)
      new_col_name <- paste0("Label Encoded (", col_name, ")")
      
      new_col <- as.integer(sapply(data[[col_index]], function(x) match(x, names(label_map)) - 1))
      data[[col_index]] <- new_col
      colnames(data)[col_index] <- new_col_name
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
  func = get(method)
  result = func(data, column_details, step, value)
  return(result)
}