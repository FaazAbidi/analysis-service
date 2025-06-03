


get_column_details_from_json <- function(data) {
  column_names <- names(data$columns)
  
  column_info <- lapply(column_names, function(col) {
    list(column = col, type = data$columns[[col]]$type,
         step = data$columns[[col]]$step,
         value = data$columns[[col]]$value)
  })
  
  return(column_info)
}


average_decimal_places <- function(column) {
  count_decimals <- function(x) {
    s <- format(x, scientific = FALSE, trim = TRUE)
    s <- sub("0+$", "", s)
    decimal_part <- sub("^[+-]?[0-9]+\\.", "", s)
    if (grepl("\\.", s)) {
      nchar(decimal_part)
    } else {
      0
    }
  }
  
  n <- length(column)
  sample_size <- max(1, ceiling(n * 0.05))
  column_sample <- sample(column, sample_size)
  
  mean(vapply(column_sample, count_decimals, numeric(1)))
}