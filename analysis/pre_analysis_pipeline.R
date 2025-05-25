setwd(Sys.getenv("R_CWD"))

# Load all necessary scripts for data processing steps
source("utils/utils.R")
source("pre_processing/pp_data_collection.R")
source("pre_analysis/pa_data_cleaning.R")
source("pre_analysis/pa_data_transformation.R")
source("pre_analysis/pa_feature_engineering.R")
source("pre_analysis/pa_data_reduction.R")

library(jsonlite)
library(here)# Ensure jsonlite is loaded for toJSON()

# Main function to perform the full pre-analysis workflow
pre_analysis <- function(
    file_path,
    relevant_columns,
    target,
    model,
    column_types,
    threshold_check_categorical,
    threshold_check_skewness,
    threshold_sampling,
    threshold_check_dimensionality,
    threshold_check_vif) {
  
  # Load data from file using your get_dataframe function
  data <- get_dataframe(file_path)
  
  # Subset relevant columns safely (drop=FALSE keeps dataframe structure if single column)
  if (length(relevant_columns) > 0) {
    data <- data[, relevant_columns, drop = FALSE]
  }
  
  # 1. Data Cleaning analysis
  pa_cleaning <- pre_analysis_cleaning(data, model, column_types)
  
  # 2. Data Transformation analysis
  pa_transformation <- pre_analysis_transformation(data, model, column_types, threshold_check_skewness)
  
  # 3. Feature Engineering analysis
  pa_feature_engineering <- pre_analysis_feature_engineering(data, model, column_types, threshold_check_categorical)
  
  # 4. Data Reduction analysis (requires target variable)
  pa_reduction <- pre_analysis_reduction(data, target, column_types, threshold_sampling, threshold_check_dimensionality, threshold_check_vif)
  
  # Combine all results into a single list
  result <- list(
    pa_cleaning = pa_cleaning,
    pa_transformation = pa_transformation,
    pa_feature_engineering = pa_feature_engineering,
    pa_reduction = pa_reduction
  )
  
  # Return results as a pretty-printed JSON string
  return(toJSON(result, pretty = TRUE, auto_unbox = TRUE))
  
  # Alternatively, return the raw list (uncomment if preferred)
  # return(result)
}


main <- function(params_path, input_data_path, output_params_path) {
  params = fromJSON(params_path)
  relevant_columns = names(params$columns)
  column_details = get_column_details_from_json(params)
  model = params$model
  target = params$target
  
  threshold_check_categorical = params$threshold_check_categorical
  threshold_check_skewness = params$threshold_check_skewness
  threshold_sampling = params$threshold_sampling
  threshold_check_dimensionality = params$threshold_check_dimensionality
  threshold_check_vif = params$threshold_check_vif
  
  result <- pre_analysis(input_data_path,
                         relevant_columns,
                         target,
                         model,
                         column_details,
                         threshold_check_categorical,
                         threshold_check_skewness,
                         threshold_sampling,
                         threshold_check_dimensionality,
                         threshold_check_vif)
  
  write_json_string(output_params_path, result)
}


cat("Current working directory:", getwd(), "\n")
main(file.path(Sys.getenv("R_CWD"), "input", "input_for_pre_analysis.json"),
     file.path(Sys.getenv("R_CWD"), "input", "raw_data_new.csv"),
     file.path(Sys.getenv("R_CWD"), "output", "pre_analysis_output.json"))
