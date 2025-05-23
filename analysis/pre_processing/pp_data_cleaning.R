setwd("C:/Users/ahsan/Documents/My Data/MS HIS/4 Summer Semester 2025/HIS Project/cleanify_pre_processing")

# Install and load 'rio' package for versatile data import/export
if (!require("rio")) install.packages("rio")
library(rio)

# Define file path to import
file_path <- "C:/Users/ahsan/Documents/My Data/MS HIS/4 Summer Semester 2025/HIS Project/R Files/input/sample.txt"

# Import data using rio::import (auto-detects format)
data <- import(file_path)

# View the imported data
print(data)
