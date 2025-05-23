setwd(Sys.getenv("R_CWD"))

# Load all necessary scripts for data processing steps
source("pre_processing/pp_data_collection.R")
source("pre_analysis/pa_data_cleaning.R")
source("pre_analysis/pa_data_transformation.R")
source("pre_analysis/pa_feature_engineering.R")
source("pre_analysis/pa_data_reduction.R")

library(jsonlite)
library(here)# Ensure jsonlite is loaded for toJSON()

# Main function to perform the full pre-analysis workflow
pre_analysis <- function(file_path, relevant_columns, target_variable, model) {
  
  # Load data from file using your get_dataframe function
  data <- get_dataframe(file_path)
  
  # Subset relevant columns safely (drop=FALSE keeps dataframe structure if single column)
  data <- data[, relevant_columns, drop = FALSE]
  
  # 1. Data Cleaning analysis
  pa_cleaning <- pre_analysis_cleaning(data, model)
  
  # 2. Data Transformation analysis
  pa_transformation <- pre_analysis_transformation(data, model)
  
  # 3. Feature Engineering analysis
  pa_feature_engineering <- pre_analysis_feature_engineering(data, model)
  
  # 4. Data Reduction analysis (requires target variable)
  pa_reduction <- pre_analysis_reduction(data, target_variable)
  
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

# Example usage (replace file_path and columns with actual data)
current_dir <- getwd()
file_path <- file.path(current_dir, "input", "raw_data_new.csv")
relevant_columns <- c('Name', 'Age', 'Salary', 'Department', 'Gender', 'Performance_Score', 'Promoted')
target_variable <- 'Promoted'
model <- 'Linear Regression'


# Run the pre-analysis and print the JSON result
result <- pre_analysis(file_path, relevant_columns, target_variable, model)
cat(result)
cat(typeof(result))
