source("utils/cons.R")

# Load necessary libraries
if (!require("car")) install.packages("car")
library(car)

# Check if sampling is needed based on row count threshold
is_sampling_required <- function(df, threshold = DEFAULT_THRESHOLD_FOR_SAMPLING) {
  return(nrow(df) > threshold)
}

# Check multicollinearity using VIF, returns TRUE if any VIF > 5
check_multicollinearity <- function(data, target) {
  data <- na.omit(data)
  
  if (!(target %in% names(data))) stop("Target variable not found in data.")
  
  numeric_data <- data[sapply(data, is.numeric)]
  
  formula <- as.formula(paste(target, "~ ."))
  model <- lm(formula, data = numeric_data)
  vif_vals <- vif(model)
  
  return(any(vif_vals > 5))
}

# Check if data is high dimensional: ratio of numeric features to rows > threshold
check_high_dimensionality <- function(data, threshold = DEFAULT_THRESHOLD_CHECK_DIMENSIONALITY) {
  data <- na.omit(data)
  numeric_data <- data[sapply(data, is.numeric)]
  ratio <- ncol(numeric_data) / nrow(numeric_data)
  return(ratio > threshold)
}

# Get free RAM in MB, works for Windows, Linux, macOS
get_free_ram_mb <- function() {
  os <- .Platform$OS.type
  
  if (os == "windows") {
    wmi_out <- try(system("wmic OS get FreePhysicalMemory /Value", intern = TRUE), silent = TRUE)
    if (inherits(wmi_out, "try-error")) stop("Unable to run 'wmic' to get free memory on Windows.")
    
    line <- wmi_out[grep("^FreePhysicalMemory", wmi_out)]
    free_kb <- as.numeric(sub("FreePhysicalMemory=", "", line))
    free_mb <- free_kb / 1024
    return(free_mb)
    
  } else {
    if (file.exists("/proc/meminfo")) {
      meminfo <- readLines("/proc/meminfo")
      availLine <- meminfo[grep("^MemAvailable", meminfo)]
      free_kb <- as.numeric(gsub("\\D", "", availLine))
      return(free_kb / 1024)
    }
    
    free_out <- try(system("free -m", intern = TRUE), silent = TRUE)
    if (!inherits(free_out, "try-error")) {
      mem_line <- grep("^Mem:", free_out, value = TRUE)
      parts <- strsplit(mem_line, "\\s+")[[1]]
      free_mb <- as.numeric(parts[4])  # available memory in MB
      return(free_mb)
    }
    
    vm_out <- try(system("vm_stat", intern = TRUE), silent = TRUE)
    if (!inherits(vm_out, "try-error")) {
      pages_free <- as.numeric(gsub("\\D", "", vm_out[grep("Pages free", vm_out)]))
      page_size <- 4096  # bytes
      free_bytes <- pages_free * page_size
      return(free_bytes / (1024^2))  # Convert bytes to MB
    }
    
    stop("Could not determine available RAM on this system.")
  }
}

# Aggregate reduction checks to decide on sampling, multicollinearity, dimensionality, and PCA
pre_analysis_reduction <- function(data, target) {
  sampling_needed <- is_sampling_required(data)
  multicollinearity_exists <- check_multicollinearity(data, target)
  high_dimensionality_exists <- check_high_dimensionality(data)
  
  pca_required <- multicollinearity_exists || high_dimensionality_exists
  
  result <- list(
    is_sampling_required = sampling_needed,
    multicollinearity_exists = multicollinearity_exists,
    high_dimensionality_exists = high_dimensionality_exists,
    is_pca_required = pca_required
  )
  
  return(result)
}
