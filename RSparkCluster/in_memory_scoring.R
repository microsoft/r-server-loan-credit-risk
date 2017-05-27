##########################################################################################################################################
## This R script will perform in-memory scoring for batch scoring or for scoring remotely with a web service. 
##########################################################################################################################################
# Inputs of the function: 
## Loan_df: data frame with the Loan data.
## Borrower_df: data frame with the Borrower data.
## Stage: "Prod" for batch scoring, or "Web" for scoring remotely with web service.


in_memory_scoring <- function(Loan_df, 
                              Borrower_df,
                              Stage)
{
  # Load library. 
  library(RevoScaleR)
  library(MicrosoftML)
  
  # Set the compute context to local. 
  rxSetComputeContext('local')
  
  # Convert the binary variables to factors. 
  Loan_df$isJointApplication <- factor(Loan_df$isJointApplication)
  Borrower_df$incomeVerified <- factor(Borrower_df$incomeVerified)
  
  # Load variables from Development Stage. 
  if(Stage == "Web"){
    Numeric_Means <- model_objects$Numeric_Means
    Categorical_Modes <- model_objects$Categorical_Modes
    bins <- model_objects$bins
    logistic_model <- model_objects$logistic_model
    dev_test_avg_score <- model_objects$dev_test_avg_score
    Operational_Metrics <- model_objects$Operational_Metrics
  }
  
  if(Stage == "Prod"){
    Numeric_Means <- readRDS(file.path(LocalModelsDir, "Numeric_Means.rds"))
    Categorical_Modes <- readRDS(file.path(LocalModelsDir, "Categorical_Modes.rds"))
    bins <- readRDS(file.path(LocalModelsDir, "bins.rds"))
    logistic_model <- readRDS(file.path(LocalModelsDir, "logistic_model.rds"))
    dev_test_avg_score <- readRDS(file.path(LocalModelsDir, "dev_test_avg_score.rds"))
    Operational_Metrics <- readRDS(file.path(LocalModelsDir, "Operational_Metrics.rds"))
  }
  
  ############################################################################################################################################
  ## The block below will do the following:
  ## 1. Merge the input tables.
  ## 2. Determine if there are missing values. 
  ## 3. If applicable, clean the merged data set: replace NAs with the global mean or global mode.
  ############################################################################################################################################
  # Merge the input tables on memberId. 
  Merged <- rxMerge(Loan_df, Borrower_df, type = "inner", matchVars = "memberId")
  
  # Get the variables types. 
  var_all <- colnames(Merged)[!colnames(Merged) %in% c("loanId", "memberId", "loanStatus", "date")]
  types <- sapply(Merged[, var_all], function(x) class(x))
  categorical_all <- names(types[types %in% c("factor")])
  numeric_all <- setdiff(var_all, categorical_all)
  
  # Look for variables missing values, per type.
  no_of_NA <- sapply(Merged, function(x) sum(is.na(x)))
  var_with_NA <- names(no_of_NA[no_of_NA > 0])
  num_with_NA <- intersect(numeric_all, var_with_NA)
  cat_with_NA <- intersect(categorical_all, var_with_NA)
  
  # If there are no missing values, we go to the next step. 
  if(length(var_with_NA) == 0){
    MergedCleaned <- Merged
    
    # If there are missing values, we replace them with the mode or mean.    
  }else{
    
    # Global means and modes from the development stage. 
    num_NA_mean <- round(Numeric_Means[Numeric_Means$Name %in% num_with_NA,]$Mean)
    cat_NA_mode <- as.character(Categorical_Modes[Categorical_Modes$Name %in% cat_with_NA,]$Mode)
    
    # Function to replace missing values with mean or mode. It will be wrapped into rxDataStep. 
    Mean_Mode_Replace <- function(data) {
      # Replace numeric variables with the mean. 
      if(length(num_with_NA) > 0){
        for(i in 1:length(num_with_NA)){
          row_na <- which(is.na(data[, num_with_NA[i]]) == TRUE) 
          data[row_na, num_with_NA[i]] <- num_NA_mean[i]
        }
      }
      # Replace categorical variables with the mode. 
      if(length(cat_with_NA) > 0){
        for(i in 1:length(cat_with_NA)){
          data[, cat_with_NA[i]] <- as.character(data[, cat_with_NA[i]])
          row_na <- which(is.na(data[, cat_with_NA[i]]) == TRUE) 
          data[row_na, cat_with_NA[i]] <- cat_NA_mode[i]
          data[, cat_with_NA[i]] <- factor(data[, cat_with_NA[i]])
        }
      }
      return(data)  
    }
    
    MergedCleaned <- Mean_Mode_Replace(Merged)
  }
  
  ############################################################################################################################################
  ## The block below will perform feature engineering on the cleaned data set. 
  ############################################################################################################################################
  # Create an artificial target variable isBad. This is for rxPredict to work. 
  MergedCleaned$isBad <- sample(c("0", "1"), size = nrow(MergedCleaned), replace = T)
  
  # Bucketize variables.
  buckets_names <- c("loanAmount", "interestRate", "monthlyPayment", "annualIncome", "dtiRatio", "lengthCreditHistory",
                     "numTotalCreditLines", "numOpenCreditLines", "numOpenCreditLines1Year", "revolvingBalance",
                     "revolvingUtilizationRate", "numDerogatoryRec", "numDelinquency2Years", "numChargeoff1year", 
                     "numInquiries6Mon")
  
  bucketize <- function(data) {
    for(name in  buckets_names){
      # Deal with the last bin.
      name2 <- paste(name, "Bucket", sep = "")
      data[, name2] <- as.character(length(bins[[name]]) + 1)
      # Deal with the first bin. 
      rows <- which(data[, name] <= bins[[name]][[1]])
      data[rows, name2] <- "1"
      # Deal with the rest.
      if(length(bins[[name]]) > 1){
        for(i in seq(1, (length(bins[[name]]) - 1))){
          rows <- which(data[, name] <= bins[[name]][[i + 1]] & data[, name] > bins[[name]][[i]])
          data[rows, name2] <- as.character(i + 1)
        }
      }
      # Factorize the new variable. 
      data[, name2] <- factor(data[, name2], levels = as.character(seq(1, (length(bins[[name]]) + 1))))
    }
    return(data)  
  }
  
  MergedFeaturesFactors <- bucketize(MergedCleaned)
  
  ############################################################################################################################################
  ## The block below will score the featurized data set.
  ############################################################################################################################################
  Predictions <- rxPredict(logistic_model, 
                           data = MergedFeaturesFactors, 
                           extraVarsToWrite = c("loanId"))
  
  # Change the names of the variables in the predictions table for clarity.
  Predictions <- Predictions[, c(1, 4)]
  colnames(Predictions) <- c("loanId", "isBad_Pred")
  
  ############################################################################################################################################
  ## The block below will transform the scores based on Operational Metrics computed in the Development stage. 
  ############################################################################################################################################
  
  # Space out the scores (predicted probability of default) for interpretability with a sigmoid.
  sigmoid <- function(x){
    return(1/(1 + exp(-20*(x-1.2*dev_test_avg_score))))
  }
  Predictions$transformedScore <- sigmoid(Predictions$isBad_Pred)
  
  # Deal with the bottom 1-99 percentiles. 
  for (i in seq(1, (nrow(Operational_Metrics) - 1))){
    rows <- which(Predictions$transformedScore <= Operational_Metrics$scoreCutoff[i + 1] & 
                    Predictions$transformedScore > Operational_Metrics$scoreCutoff[i])
    Predictions[rows, c("scorePercentile")] <- as.character(Operational_Metrics$scorePercentile[i + 1])
    Predictions[rows, c("badRate")] <- Operational_Metrics$badRate[i]
    Predictions[rows, c("scoreCutoff")] <- Operational_Metrics$scoreCutoff[i]
  }
  
  # Deal with the top 1% higher scores (last bucket). 
  rows <- which(Predictions$transformedScore > Operational_Metrics$scoreCutoff[100])
  Predictions[rows, c("scorePercentile")] <- "Top 1%"
  Predictions[rows, c("scoreCutoff")] <- Operational_Metrics$scoreCutoff[100]
  Predictions[rows, c("badRate")] <- Operational_Metrics$badRate[100]
  
  # Output the final scores. 
  Scores <- Predictions[, c("loanId", "transformedScore", "scorePercentile", "scoreCutoff", "badRate")]
  
  return(Scores)
  
}

