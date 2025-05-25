setwd(Sys.getenv("R_CWD"))

# Load necessary scripts for data processing
source("utils/utils.R")
source("pre_processing/pp_data_collection.R")
source("pre_processing/pp_data_cleaning.R")

if (!require("jsonlite")) install.packages("jsonlite")
library(jsonlite)
if (!require("here")) install.packages("here")
library(here)

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


cat("Current working directory:", getwd(), "\n")
start_time <- Sys.time()
main(
  file.path(Sys.getenv("R_CWD"), "input", "input_for_pre_processing_synthetic.json"),
  file.path(Sys.getenv("R_CWD"), "input", "synthetic_dataset.csv"),
  file.path(Sys.getenv("R_CWD"), "output", "imputed_missing_synthetic.csv")
)
end_time <- Sys.time()
elapsed_time <- end_time - start_time
print(elapsed_time)
