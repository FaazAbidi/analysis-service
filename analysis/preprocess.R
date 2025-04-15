#!/usr/bin/env Rscript

# Simplified R script for testing execution

# Function to demonstrate R is running
process_test <- function(input_file, output_file) {

  print('--------------------------------')
  print("preprocess.R is running")
  # Read data from input file
  cat("Reading data from", input_file, "\n")
  data <- read.csv(input_file, header = TRUE)
  
  # Add a delay of 10 seconds
  cat("Starting 10 second delay...\n")
  Sys.sleep(10)
  cat("Delay complete\n")
  
  # Write unmodified data to output file
  write.csv(data, output_file, row.names = FALSE)
  cat("Data written to", output_file, "\n")
  print('--------------------------------')
  
  # Return success code
  return(0)
}

# Main execution logic
main <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  
  # Check if we have the right number of arguments
  if(length(args) < 2) {
    cat("Usage: Rscript preprocess.R input_file.csv output_file.csv\n")
    return(1)
  }
  
  input_file <- args[1]
  output_file <- args[2]
  
  # Call the test function
  result <- process_test(input_file, output_file)
  
  # Exit with the result code
  quit(status = result)
}

# Run the main function
main() 