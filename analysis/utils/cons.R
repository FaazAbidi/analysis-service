# setwd("C:/Users/ahsan/Documents/My Data/MS HIS/4 Summer Semester 2025/HIS Project/cleanify_pre_processing")

# THIS FILE CONTAINS ALL CONSTANTS & DEFAULTS USED IN THE PROJECT

DEFAULT_PERCENTAGE_CHECK_CATEGORICAL <- 0.3
DEFAULT_THRESHOLD_CHECK_SKEWNESS <- 1
DEFAULT_THRESHOLD_FOR_SAMPLING <- 100
DEFAULT_THRESHOLD_CHECK_DIMENSIONALITY <- 0.5  # fixed typo: DIMMENSIONALITY -> DIMENSIONALITY

ALL_MODELS <- c(
  "Linear Regression",
  "Logistic Regression",
  "Decision Trees",
  "Support Vector Machines",
  "K-Nearest Neighbors",
  "Random Forests",
  "Gradient Boosting",
  "Neural Networks",
  "Linear Discriminant Analysis"
)

HANDLES_MISSING_VALUES <- c(
  "Decision Trees",
  "Random Forests",
  "Gradient Boosting"  # Partial support included
)

HANDLES_OUTLIERS_WELL <- c(
  "Decision Trees",
  "Random Forests",
  "Gradient Boosting"  # fixed capitalization
)

HANDLES_INCONSISTENT_VALUES <- c(
  "Decision Trees",
  "Random Forests",
  "Gradient Boosting"
)

HANDLES_SKEWNESS_WELL <- c(
  "Decision Trees",
  "Random Forests",
  "Gradient Boosting"
)

NEEDS_STANDARDIZATION <- c(
  "Linear Regression",
  "Logistic Regression",
  "Support Vector Machines",
  "K-Nearest Neighbors",
  "Neural Networks",
  "Linear Discriminant Analysis"
)

NEEDS_NORMALIZATION_SOMETIMES <- c(
  "Linear Regression",
  "Logistic Regression",
  "Linear Discriminant Analysis"
)

NEEDS_ONE_HOT_ENCODING <- c(
  "Linear Regression",
  "Logistic Regression",
  "Support Vector Machines",
  "K-Nearest Neighbors",
  "Neural Networks",
  "Linear Discriminant Analysis"
)