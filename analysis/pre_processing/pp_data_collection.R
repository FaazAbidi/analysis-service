library(jsonlite)
library(rio)

detect_separator <- function(file_path,
                             candidates = c(",", ";", "\t", "|"),
                             lines_to_test = 5) {
  # Read the first few lines of the file
  lines <- readLines(file_path, n = lines_to_test)
  
  # For each candidate separator compute average field count
  scores <- sapply(candidates, function(sep) {
    counts <- sapply(lines, function(line) {
      length(strsplit(line, sep, fixed = TRUE)[[1]])
    })
    mean(counts)
  })
  
  # Pick the separator with the highest average count
  candidates[which.max(scores)]
}

get_dataframe <- function(file_path) {
  na_columns <- c("NA", "na", "Na", "Nan", "NaN", "nan", "", " ", "NULL", "NONE")
  ext        <- tolower(tools::file_ext(file_path))
  sep        <- detect_separator(file_path)
  
  if (ext == "csv") {
    if (sep == ",") {
      data <- read.csv(
        file_path,
        na.strings     = na_columns,
        stringsAsFactors = FALSE,
        sep            = sep
      )
    } else {
      data <- import(
        file_path,
        na       = na_columns,
        setclass = "data.frame"
      )
    }
  } else if (ext %in% c("xlsx", "xls", "ods", "txt", "json")) {
    # For all other formats rio guesses correctly from extension
    data <- import(
      file_path,
      na       = na_columns,
      setclass = "data.frame"
    )
  } else {
    stop("Unsupported file format: ", ext)
  }
  
  data
}

# Export data
write_dataframe <- function(data, file_path) {
  if (!is.data.frame(data)) {
    stop("data must be a data.frame or tibble")
  }
  if (!is.character(file_path) || length(file_path) != 1) {
    stop("file_path must be a single character string")
  }
  dir <- dirname(file_path)
  if (!dir.exists(dir)) {
    dir.create(dir, recursive = TRUE)
  }
  export(data, file_path)
  invisible(TRUE)
}

# Write a JSON string to file
write_json_string <- function(file_path, json_string) {
  dir_path <- dirname(file_path)
  if (!dir.exists(dir_path)) {
    dir.create(dir_path, recursive = TRUE)
  }
  writeLines(json_string, file_path)
}