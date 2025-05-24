


get_column_types_from_json <- function(data) {
  column_names <- names(data$columns)
  
  column_info <- lapply(column_names, function(col) {
    list(column = col, type = data$columns[[col]]$type)
  })
  
  return(column_info)
}
