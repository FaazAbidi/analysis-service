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
pre_analysis <- function(file_path, relevant_columns, target_variable = NULL, model = NULL, column_types) {
  
  # Load data from file using your get_dataframe function
  data <- get_dataframe(file_path)
  
  # Subset relevant columns safely (drop=FALSE keeps dataframe structure if single column)
  if (length(relevant_columns) > 0) {
    data <- data[, relevant_columns, drop = FALSE]
  }
  
  # 1. Data Cleaning analysis
  pa_cleaning <- pre_analysis_cleaning(data, model, column_types)
  
  # 2. Data Transformation analysis
  pa_transformation <- pre_analysis_transformation(data, model, column_types)
  
  # 3. Feature Engineering analysis
  pa_feature_engineering <- pre_analysis_feature_engineering(data, model, column_types)
  
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

get_column_types_json <- function() {
  columns <- c("Name", "Age", "Salary", "Department", "Join_Date", "Gender", "Performance_Score", "Promoted")
  types <- c("QUALITATIVE", "QUANTITATIVE", "QUANTITATIVE", "QUALITATIVE", "QUALITATIVE", "QUALITATIVE", "QUANTITATIVE", "QUALITATIVE")
  
  column_info <- lapply(seq_along(columns), function(i) {
    list(column = columns[i], type = types[i])
  })
  
  return(toJSON(column_info, pretty = TRUE, auto_unbox = TRUE))
}

# Example usage (replace file_path and columns with actual data)
current_dir <- getwd()
cwd = "C:/Users/ahsan/Documents/My Data/MS HIS/4 Summer Semester 2025/HIS Project/analysis-service/analysis"


file_path <- file.path(current_dir, "input", "raw_data_new.csv")
column_types = get_column_types_json()
relevant_columns <- c('Name', 'Age', 'Salary', 'Department', 'Gender', 'Performance_Score', 'Promoted')
target_variable <- "Promoted"
model <- 'Decision Tree'



# Run the pre-analysis and print the JSON result
result <- pre_analysis(file_path, relevant_columns, target_variable, model, column_types)
print(result)
# write_json_string(file.path(current_dir, "output", "preanalysis.json"), result)
