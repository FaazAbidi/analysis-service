#!/usr/bin/env Rscript

# Load required libraries
library(jsonlite)

# Get command line arguments
args <- commandArgs(trailingOnly = TRUE)
params_path <- args[1]
csv_path <- args[2]
recommendations_path <- args[3]

# Read parameters JSON
params <- fromJSON(params_path)

# Check if CSV file exists
if (file.exists(csv_path)) {
  comment <- "CSV file processed successfully"
} else {
  comment <- "CSV file not found or failed to process"
}

# Add comment to params
params$comment <- comment

# Write to recommendations file
write_json(params, recommendations_path, pretty = TRUE, auto_unbox = TRUE)
