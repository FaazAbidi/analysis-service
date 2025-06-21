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
  
  # First read the column names directly from the file
  first_line <- readLines(file_path, n = 1)
  col_names <- unlist(strsplit(first_line, separator))
  
  # Read the data
  data <- read_csv(file_path, delim = separator, col_types = cols())
  
  # Ensure column names match the originals
  names(data) <- col_names
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
  
  # First read the column names directly from the file
  first_line <- readLines(file_path, n = 1)
  col_names <- unlist(strsplit(first_line, separator))
  
  # Read the data
  data <- read.table(
    file_path,
    header = TRUE,
    sep = separator,
    stringsAsFactors = FALSE
  )
  
  # Ensure column names match the originals
  names(data) <- col_names
  return(data)
}

write_csv_file <- function(file_path, data) {
  dir_path <- dirname(file_path)
  if (!dir.exists(dir_path)) {
    dir.create(dir_path, recursive = TRUE)
  }
  # Preserve original column names
  orig_names <- names(data)
  # Write with temporary names
  write.csv(data, file = file_path, row.names = FALSE, quote = FALSE)
  # Read the file and replace the header line
  lines <- readLines(file_path)
  if (length(lines) > 0) {
    lines[1] <- paste(orig_names, collapse = ",")
    writeLines(lines, file_path)
  }
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
    # Read the column names from the first line
    first_line <- readLines(file_path, n = 1)
    col_names <- unlist(strsplit(first_line, ","))
    
    # Read the data
    data <- read.csv(
      file_path,
      na.strings = na_columns,
      stringsAsFactors = FALSE
    )
    
    # Restore original column names
    names(data) <- col_names
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
    # Preserve original column names
    orig_names <- names(data)
    # Write file
    write.csv(data, file = file_path, row.names = FALSE, quote = FALSE)
    # Read the file and replace the header line
    lines <- readLines(file_path)
    if (length(lines) > 0) {
      lines[1] <- paste(orig_names, collapse = ",")
      writeLines(lines, file_path)
    }
  } else if (grepl("\\.xlsx$", file_path, ignore.case = TRUE)) {
    write_xlsx(data, path = file_path)
  } else if (grepl("\\.json$", file_path, ignore.case = TRUE)) {
    write_json(data, path = file_path, pretty = TRUE, auto_unbox = TRUE)
  } else if (grepl("\\.txt$", file_path, ignore.case = TRUE)) {
    # For text files, we'll use a similar approach
    orig_names <- names(data)
    write.table(data, file = file_path, sep = "\t", row.names = FALSE, quote = FALSE)
    lines <- readLines(file_path)
    if (length(lines) > 0) {
      lines[1] <- paste(orig_names, collapse = "\t")
      writeLines(lines, file_path)
    }
  } else {
    stop("Unsupported file format for writing")
  }
}
