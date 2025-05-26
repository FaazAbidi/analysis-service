library(jsonlite)
# if (!require("here")) install.packages("here")
library(here)

# Load necessary scripts for data processing
source("analysis/utils/utils.R")
source("analysis/pre_processing/pp_data_collection.R")
source("analysis/pre_processing/pp_data_cleaning.R")

# Main function to perform the full pre-analysis workflow
pre_processing <- function(
    file_path,
    column_details,
    method
) {
  # Load data from file using get_dataframe
  data <- get_dataframe(file_path)
  
  # Perform data cleaning analysis
  pp_cleaning <- pre_processing_cleaning(data, column_details, method)
  return(pp_cleaning)
}


main <- function(
    params_path,
    input_data_path,
    output_data_path
) {
  params <- fromJSON(params_path)
  relevant_columns <- names(params$columns)
  column_details <- get_column_details_from_json(params)
  method <- params$method
  model <- params$model
  target <- params$target
  
  result <- pre_processing(input_data_path, column_details, method)
  write_dataframe(result, output_data_path)
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
