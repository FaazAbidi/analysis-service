source("analysis/utils/utils.R")
source("analysis/pre_processing/pp_data_collection.R")
source("analysis/pre_processing/pp_data_cleaning.R")
source("analysis/pre_processing/pp_data_transformation.R")
source("analysis/pre_processing/pp_feature_engineering.R")
source("analysis/pre_processing/pp_data_reduction.R")

library(jsonlite)
library(here)

# Main function to perform the full pre-analysis workflow
pre_processing <- function(
    file_path,
    column_details,
    technique,
    method,
    step,
    value,
    target
) {
  # Load data from file using get_dataframe
  data <- get_dataframe(file_path)
  
  # Perform data cleaning analysis
  main_method = get(technique)
  processes_data <- main_method(data,
                                column_details,
                                method,
                                step,
                                value,
                                target)
  return(processes_data)
}

main <- function(
    params_path,
    input_data_path,
    output_data_path
) {
  
  # === R SCRIPT JSON DEBUGGING ===
  cat("=== R SCRIPT JSON DEBUG INFO ===\n")
  cat("Params file path received:", params_path, "\n")
  cat("Current working directory:", getwd(), "\n")
  cat("File exists:", file.exists(params_path), "\n")
  
  if (file.exists(params_path)) {
    # Get file info
    file_info <- file.info(params_path)
    cat("File size:", file_info$size, "bytes\n")
    cat("File permissions:", sprintf("%o", file_info$mode), "\n")
    
    # Try to read raw content
    tryCatch({
      raw_content <- readLines(params_path, warn = FALSE)
      cat("Raw content lines:", length(raw_content), "\n")
      full_content <- paste(raw_content, collapse = "")
      cat("Full content length:", nchar(full_content), "characters\n")
      cat("Full content:", full_content, "\n")
      
      # Check for common JSON issues
      if (nchar(full_content) == 0) {
        cat("ERROR: File is empty!\n")
      } else if (!grepl("^\\s*\\{", full_content)) {
        cat("ERROR: Content doesn't start with '{'\n")
      } else if (!grepl("\\}\\s*$", full_content)) {
        cat("ERROR: Content doesn't end with '}'\n")
      } else {
        cat("Content appears to be valid JSON format\n")
      }
    }, error = function(e) {
      cat("ERROR reading raw content:", e$message, "\n")
    })
  } else {
    cat("ERROR: File does not exist!\n")
    
    # List contents of directory containing the file
    parent_dir <- dirname(params_path)
    cat("Parent directory:", parent_dir, "\n")
    cat("Parent directory exists:", dir.exists(parent_dir), "\n")
    
    if (dir.exists(parent_dir)) {
      cat("Contents of parent directory:\n")
      files <- list.files(parent_dir, full.names = TRUE, all.files = TRUE)
      for (f in files) {
        if (file.exists(f)) {
          info <- file.info(f)
          cat("  -", basename(f), "(", info$size, "bytes )\n")
        }
      }
    }
  }
  
  cat("=== ATTEMPTING JSON PARSING ===\n")
  
  params <- tryCatch({
    result <- fromJSON(params_path)
    cat("JSON parsing successful!\n")
    cat("JSON keys:", paste(names(result), collapse = ", "), "\n")
    result
  }, error = function(e) {
    cat("JSON parsing ERROR:", e$message, "\n")
    stop("Failed to parse JSON: ", e$message)
  })
  
  cat("=== END R SCRIPT JSON DEBUG INFO ===\n")
  
  relevant_columns <- names(params$columns)
  column_details <- get_column_details_from_json(params)
  technique <- params$technique
  method <- params$method
  step <- params$step
  value <- params$value
  target <- params$target
  
  result <- pre_processing(
    input_data_path,
    column_details,
    technique,
    method,
    step,
    value,
    target)
  
  write_dataframe(replace_na_nan_with_empty(result), output_data_path)
}


# Main execution logic to read command-line arguments and run the workflow
cli_main <- function() {
  args <- commandArgs(trailingOnly = TRUE)

  # Check if we have the right number of arguments
  if (length(args) < 3) {
    cat("Usage: Rscript pre_processing_pipeline.R params_file.json input_data_file.csv output_data_file.csv\n")
    return(1) # Return a non-zero status code for error
  }

  params_path <- args[1]
  input_data_path <- args[2]
  output_data_path <- args[3]

  # Call the main workflow function
  # The main function currently prints elapsed time, we can keep this or modify as needed
  main(params_path, input_data_path, output_data_path)

  # Return a zero status code for success
  return(0)
}

# Run the command-line main function
cat("Current working directory:", getwd(), "\n")
start_time <- Sys.time()

# Run the CLI main function and capture the status for quitting
status <- cli_main()

end_time <- Sys.time()
elapsed_time <- end_time - start_time
cat("Total elapsed time:", format(elapsed_time), "\n")

# Exit with the status code returned by cli_main
quit(status = status)


# ############################## FOR TESTING LOCALLY #############################
# ################################ WILL BE REMOVED ###############################
# cwd = "C:/Users/ahsan/Documents/My Data (without drive)/analysis-service"
# cat("Current working directory:", getwd(), "\n")
# start_time <- Sys.time()
# main(
#   file.path(cwd,"analysis", "input", "params_pca.json"),
#   file.path(cwd,"analysis", "output", "processed_data_new_7.csv"),
#   file.path(cwd,"analysis", "output", "processed_data_new_8.csv")
# )
# end_time <- Sys.time()
# elapsed_time <- end_time - start_time
# print(elapsed_time)
# ################################################################################
