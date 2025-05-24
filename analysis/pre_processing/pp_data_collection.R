# Install and load necessary packages
if (!require("jsonlite")) install.packages("jsonlite")
library(jsonlite)

if (!require("readr")) install.packages("readr")
library(readr)

if (!require("readxl")) install.packages("readxl")
library(readxl)

# Detect the separator in CSV or text files by trying common delimiters
detect_separator <- function(file_path) {
  # Read first line (not currently used but could be for heuristics)
  # first_line <- readLines(file_path, n = 1)
  
  # Common separators to test
  separators <- c(",", "\t", ";", "|")
  
  for (sep in separators) {
    data_try <- tryCatch({
      read.table(file_path, sep = sep, header = TRUE, nrows = 10, stringsAsFactors = FALSE)
    }, error = function(e) NULL)
    
    if (!is.null(data_try)) {
      return(sep)
    }
  }
  
  # Default to comma if none works
  return(",")
}

# Read CSV file with automatic separator detection
read_csv_file <- function(file_path) {
  separator <- detect_separator(file_path)
  data <- read_csv(file_path, delim = separator, col_types = cols())
  return(data)
}

# Read Excel file
read_excel_file <- function(file_path) {
  data <- as.data.frame(read_excel(file_path))
  return(data)
}

# Read JSON file and convert to dataframe
read_json_file <- function(file_path) {
  data <- as.data.frame(fromJSON(file_path))
  return(data)
}

# Read text file with automatic separator detection
read_text_file <- function(file_path) {
  separator <- detect_separator(file_path)
  data <- read.table(file_path, header = TRUE, sep = separator, stringsAsFactors = FALSE)
  return(data)
}



write_csv_file <- function(file_path, data) {
  dir_path <- dirname(file_path)
  if (!dir.exists(dir_path)) {
    dir.create(dir_path, recursive = TRUE)
  }
  write.csv(data, file = file_path, row.names = FALSE)
}

write_json_file <- function(file_path, data) {
  dir_path <- dirname(file_path)
  if (!dir.exists(dir_path)) {
    dir.create(dir_path, recursive = TRUE)
  }
  write_json(data, path = file_path, pretty = TRUE, auto_unbox = TRUE)
}

write_json_string <- function(file_path, json_string) {
  dir_path <- dirname(file_path)
  if (!dir.exists(dir_path)) {
    dir.create(dir_path, recursive = TRUE)
  }
  writeLines(json_string, file_path)
}


# General function to load dataframe based on file extension
get_dataframe <- function(file_path) {
  na_columns <- c("NA", "NaN", "Na")
  
  if (grepl("\\.csv$", file_path, ignore.case = TRUE)) {
    data <- read.csv(file_path, na.strings = na_columns, stringsAsFactors = FALSE)
    
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
