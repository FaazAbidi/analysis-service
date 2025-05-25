


get_column_details_from_json <- function(data) {
  column_names <- names(data$columns)
  
  column_info <- lapply(column_names, function(col) {
    list(column = col, type = data$columns[[col]]$type, step = data$columns[[col]]$step)
  })
  
  return(column_info)
}
