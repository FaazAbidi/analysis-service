library(jsonlite)
library(readr)
library(readxl)

detect_separator <- function(file_path) {
  # Detect the separator in CSV or text files by trying common delimiters
  separators <- c(",", "\t", ";", "|")
  
  for (sep in separators) {
    data_try <- tryCatch({
      read.table(
        file_path,
        sep = sep,
        header = TRUE,
        nrows = 10,
        stringsAsFactors = FALSE
      )
    }, error = function(e) NULL)
    
    if (!is.null(data_try)) {
      return(sep)
    }
  }
  
  return(",")  # Default to comma if none works
}

read_csv_file <- function(file_path) {
  # Read CSV file with automatic separator detection
  separator <- detect_separator(file_path)
  data <- read_csv(file_path, delim = separator, col_types = cols())
  return(data)
}

read_excel_file <- function(file_path) {
  # Read Excel file
  data <- as.data.frame(read_excel(file_path))
  return(data)
}

read_json_file <- function(file_path) {
  # Read JSON file and convert to dataframe
  data <- as.data.frame(fromJSON(file_path))
  return(data)
}

read_text_file <- function(file_path) {
  # Read text file with automatic separator detection
  separator <- detect_separator(file_path)
  data <- read.table(
    file_path,
    header = TRUE,
    sep = separator,
    stringsAsFactors = FALSE
  )
  return(data)
}

write_csv_file <- function(file_path, data) {
  # Write dataframe to CSV
  dir_path <- dirname(file_path)
  if (!dir.exists(dir_path)) {
    dir.create(dir_path, recursive = TRUE)
  }
  write.csv(data, file = file_path, row.names = FALSE)
}

write_json_file <- function(file_path, data) {
  # Write dataframe to JSON file
  dir_path <- dirname(file_path)
  if (!dir.exists(dir_path)) {
    dir.create(dir_path, recursive = TRUE)
  }
  write_json(data, path = file_path, pretty = TRUE, auto_unbox = TRUE)
}

write_json_string <- function(file_path, json_string) {
  # Write JSON string to file
  dir_path <- dirname(file_path)
  if (!dir.exists(dir_path)) {
    dir.create(dir_path, recursive = TRUE)
  }
  writeLines(json_string, file_path)
}

get_dataframe <- function(file_path) {
  # General function to load dataframe based on file extension
  na_columns <- c("NA", "NaN", "Na", "")
  
  if (grepl("\\.csv$", file_path, ignore.case = TRUE)) {
    data <- read.csv(
      file_path,
      na.strings = na_columns,
      stringsAsFactors = FALSE
    )
  } else if (grepl("\\.xlsx$", file_path, ignore.case = TRUE)) {
    data <- read_excel_file(file_path)
  } else if (grepl("\\.json$", file_path, ignore.case = TRUE)) {
    data <- read_json_file(file_path)
  } else if (grepl("\\.txt$", file_path, ignore.case = TRUE)) {
    data <- read_text_file(file_path)
  } else {
    stop("Unsupported file format")
  }
  
  return(data)
}

write_dataframe <- function(data, file_path) {
  # Write dataframe to specified file format based on the extension
  dir_path <- dirname(file_path)
  if (!dir.exists(dir_path)) {
    dir.create(dir_path, recursive = TRUE)
  }
  
  if (grepl("\\.csv$", file_path, ignore.case = TRUE)) {
    write.csv(data, file = file_path, row.names = FALSE)
  } else if (grepl("\\.xlsx$", file_path, ignore.case = TRUE)) {
    write_xlsx(data, path = file_path)
  } else if (grepl("\\.json$", file_path, ignore.case = TRUE)) {
    write_json(data, path = file_path, pretty = TRUE, auto_unbox = TRUE)
  } else if (grepl("\\.txt$", file_path, ignore.case = TRUE)) {
    write.table(data, file = file_path, sep = "\t", row.names = FALSE, quote = FALSE)
  } else {
    stop("Unsupported file format for writing")
  }
}
