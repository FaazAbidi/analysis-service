setwd(Sys.getenv("R_CWD"))

# Load necessary scripts for data processing steps
source("utils/utils.R")
source("pre_processing/pp_data_collection.R")
source("pre_analysis/pa_data_cleaning.R")
source("pre_analysis/pa_data_transformation.R")
source("pre_analysis/pa_feature_engineering.R")
source("pre_analysis/pa_data_reduction.R")

if (!require("jsonlite")) install.packages("jsonlite")
library(jsonlite)
if (!require("here")) install.packages("here")
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
    threshold_check_vif
) {
  # Load data and subset relevant columns
  data <- get_dataframe(file_path)
  if (length(relevant_columns) > 0) {
    data <- data[, relevant_columns, drop = FALSE]
  }
  
  # Perform analysis steps
  pa_cleaning <- pre_analysis_cleaning(data, model, column_details)
  pa_transformation <- pre_analysis_transformation(data, model,column_details, threshold_check_skewness)
  pa_feature_engineering <- pre_analysis_feature_engineering(data, model, column_details, threshold_check_categorical)
  pa_reduction <- pre_analysis_reduction(data, target, column_details, threshold_sampling, threshold_check_dimensionality, threshold_check_vif)
  
  # Combine results
  result <- list(
    pa_cleaning = pa_cleaning,
    pa_transformation = pa_transformation,
    pa_feature_engineering = pa_feature_engineering,
    pa_reduction = pa_reduction
  )
  
  # Return JSON string of results
  return(toJSON(result, pretty = TRUE, auto_unbox = TRUE))
  # Alternatively, return raw list if preferred:
  # return(result)
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
  threshold_check_vif <- params$threshold_check_vif
  
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
    threshold_check_vif
  )
  
  write_json_string(output_params_path, result)
}

cat("Current working directory:", getwd(), "\n")

main(
  file.path(Sys.getenv("R_CWD"), "input", "input_for_pre_analysis.json"),
  file.path(Sys.getenv("R_CWD"), "input", "raw_data_new.csv"),
  file.path(Sys.getenv("R_CWD"), "output", "pre_analysis_output.json")
)
