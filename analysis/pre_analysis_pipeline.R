source("analysis/utils/utils.R")
source("analysis/pre_processing/pp_data_collection.R")
source("analysis/pre_analysis/pa_data_cleaning.R")
source("analysis/pre_analysis/pa_data_transformation.R")
source("analysis/pre_analysis/pa_feature_engineering.R")
source("analysis/pre_analysis/pa_data_reduction.R")

library(jsonlite)
library(here)

# Main function to perform the full pre-analysis workflow
pre_analysis <- function(
    file_path,
    relevant_columns,
    target,
    model,
    column_details,
    threshold_check_categorical,
    threshold_check_skewness,
    threshold_sampling,
    threshold_check_dimensionality,
    threshold_check_multicollinearity
) {
  # Load data and subset relevant columns
  data <- get_dataframe(file_path)
  
  if (length(relevant_columns) > 0) {
    all_indices <- seq_along(data)
    relevant_indices <- as.integer(sapply(strsplit(relevant_columns, "\\$"), function(x) x[2]))
    indices_to_remove <- sort(setdiff(all_indices, relevant_indices), decreasing = TRUE)
    for (index_del in indices_to_remove) {
      data[[index_del]] <- NULL
    }
  }
  
  # Perform analysis steps
  pa_cleaning <- pre_analysis_cleaning(data, model, column_details)
  pa_transformation <- pre_analysis_transformation(data, model,column_details, threshold_check_skewness)
  pa_feature_engineering <- pre_analysis_feature_engineering(data, model, column_details, threshold_check_categorical)
  pa_reduction <- pre_analysis_reduction(data, target, column_details, threshold_sampling, threshold_check_dimensionality, threshold_check_multicollinearity)
  
  # Combine results
  result <- list(
    pa_cleaning = pa_cleaning,
    pa_transformation = pa_transformation,
    pa_feature_engineering = pa_feature_engineering,
    pa_reduction = pa_reduction
  )
  
  return(toJSON(result, pretty = TRUE, auto_unbox = TRUE))
}

main <- function(
    params_path,
    input_data_path,
    output_params_path
) {
  params <- fromJSON(params_path)
  relevant_columns <- names(params$columns)
  column_details <- get_column_details_from_json(params)
  model <- params$model
  target <- params$target
  
  threshold_check_categorical <- params$threshold_check_categorical
  threshold_check_skewness <- params$threshold_check_skewness
  threshold_sampling <- params$threshold_sampling
  threshold_check_dimensionality <- params$threshold_check_dimensionality
  threshold_check_multicollinearity <- params$threshold_check_multicollinearity
  
  result <- pre_analysis(
    input_data_path,
    relevant_columns,
    target,
    model,
    column_details,
    threshold_check_categorical,
    threshold_check_skewness,
    threshold_sampling,
    threshold_check_dimensionality,
    threshold_check_multicollinearity
  )
  
  write_json_string(output_params_path, result)
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
# cwd = "C:/Users/ahsan/Documents/My_Data_Local/analysis-service"
# cat("Current working directory:", getwd(), "\n")
# start_time <- Sys.time()
# main(
#   file.path(cwd,"analysis", "input", "input_for_pre_analysis_synthetic.json"),
#   file.path(cwd,"analysis", "input", "synthetic_dataset.csv"),
#   file.path(cwd,"analysis", "output", "pre_analysis_output.json")
# )
# end_time <- Sys.time()
# elapsed_time <- end_time - start_time
# print(elapsed_time)
# ################################################################################
