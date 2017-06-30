##########################################################################################################################################
## This R script will do the following:
## I. Development stage: Compute Operational Metrics, ie. expected bad rate for various classification decision thresholds.  
## II. Apply a score transformation based on operational metrics for Development and Production. 

## Input : Predictions table.
## Output: Operational Metrics and Transformed Scores. 
#########################################################################################################################################


##########################################################################################################################################
## The function below computes operational metrics in the Development stage, in the following way:
## 1. Apply a sigmoid function to the output scores of the logistic regression, in order to spread them in [0,1].
## 2. Compute bins for the scores, based on quantiles. 
## 3. Take each lower bound of each bin as a decision threshold for default loan classification, and compute the rate of bad loans
##    among loans with a score higher than the threshold. 
##########################################################################################################################################

# LocalWorkDir: the working directory on the edge node.
# HDFSWorkDir: the working directory on HDFS.

compute_operational_metrics <- function(LocalWorkDir,
                                        HDFSWorkDir)
{
  
  print("Computing operational metrics...")
  
  # Set the compute context to Local. 
  rxSetComputeContext('local')
  
  # Define the intermediate directory holding the input data. 
  HDFSIntermediateDir <- file.path(HDFSWorkDir,"temp")
  
  # Define the directory where the average of the Scores and the Operational Scores will be saved.
  LocalModelsDir <- file.path(LocalWorkDir, "model")
  
  # Point to the input data (Predictions table):
  PredictionsLogistic_xdf <- RxXdfData(file.path(HDFSIntermediateDir, "PredictionsLogistic"), fileSystem = RxHdfsFileSystem())
  
  ##########################################################################################################################################
  ## Import the predictions table and convert isBad to numeric for correct computations.
  ##########################################################################################################################################
  
  Predictions <- rxImport(PredictionsLogistic_xdf, varsToDrop = c("loanId"))
  Predictions$isBad <- as.numeric(as.character(Predictions$isBad))
  
  # Change the names of the variables in the predictions table for clarity.
  Predictions <- Predictions[, c(1, 4)]
  colnames(Predictions) <- c("isBad", "isBad_Pred")
  
  ##########################################################################################################################################
  ## Space out the scores (predicted probability of default) for interpretability with a sigmoid.
  ##########################################################################################################################################
  
  # Define the sigmoid: it is centered at 1.2*mean score to ensure a good spread of scores.  
  ## The sigmoid parameters can be changed for a new data set. 
  dev_test_avg_score <- mean(Predictions$isBad_Pred)
  sigmoid <- function(x){
    return(1/(1 + exp(-20*(x-1.2*dev_test_avg_score))))
  }
  
  # Apply the function.
  Predictions$transformedScore <- sigmoid(Predictions$isBad_Pred)
  
  # Save the average score to the local edge node for use in Production.
  saveRDS(dev_test_avg_score, file = paste(LocalModelsDir, "/dev_test_avg_score.rds", sep = ""))
  
  ##########################################################################################################################################
  ## Get the rates of bad loans for every bin taken as a threshold. 
  ##########################################################################################################################################
  
  # Bin the scores based on quantiles. 
  bins <- rxQuantile("transformedScore", Predictions, probs = c(seq(0, 0.99, 0.01)))
  bins[["0%"]] <- 0 
  
  # We consider 100 decision thresholds: the lower bound of each bin.
  # Compute the expected rates of bad loans for loans with scores higher than each decision threshold. 
  badrate <- rep(0, length(bins))
  for(i in 1:length(bins))
  {
    selected <- Predictions$isBad[Predictions$transformedScore >= bins[i]]
    badrate[i] <- sum(selected)/length(selected) 
  }
  
  # Save the operational metrics to the local edge node and to HDFS.  
  Operational_Metrics <- data.frame(scorePercentile = names(bins), scoreCutoff = bins, badRate = badrate, row.names = NULL)
  saveRDS(Operational_Metrics, file = paste(LocalModelsDir, "/Operational_Metrics.rds", sep = ""))
  
  Operational_Metrics_xdf <- RxXdfData(paste(HDFSIntermediateDir,"/OperationalMetrics",sep=""), fileSystem = RxHdfsFileSystem(), createCompositeSet = T)
  rxDataStep(inData = Operational_Metrics, outFile = Operational_Metrics_xdf, overwrite = T)
  
  # Save the operational metrics to a Hive table for display in PowerBI. 
  rxSparkConnect(consoleOutput = TRUE, reset = FALSE)
  
  Operational_Metrics_hive <- RxHiveData(table = "Operational_Metrics") 
  rxDataStep(inData = Operational_Metrics_xdf, outFile = Operational_Metrics_hive, overwrite = T)
  
  print(paste0("The hive table Operational_Metrics is stored under the folder: ","/hive/warehouse"))
  
  return(Operational_Metrics)
  
}


##########################################################################################################################################
## The function below transforms the scores given by the logistic regression on the testing or Production data in the following way:
## 1. Apply a sigmoid function to the output scores of the logistic regression, in order to spread them in [0,1].
## 2. Asssign each score to a quantile bin with the bad rates given by the Operational Scores table.
##########################################################################################################################################

# LocalWorkDir: the working directory on the edge node.
# HDFSWorkDir: the working directory on HDFS.
# Stage: "Dev" for development, "Prod" for batch scoring, or "Web" for scoring remotely with web service.

apply_score_transformation <- function(LocalWorkDir,
                                       HDFSWorkDir, 
                                       Stage)
{
  
  print("Transforming scores based on operational metrics...")
  
  # Set the compute context to Local. 
  rxSetComputeContext('local')
  
  # Define the intermediate directory holding the input data. 
  HDFSIntermediateDir <- file.path(HDFSWorkDir,"temp")
  
  # Define the directory where the average of the Scores and the Operational_Metrics were saved. 
  LocalModelsDir <- file.path(LocalWorkDir, "model")
  
  # Point to the input data (Predictions table):
  PredictionsLogistic_xdf <- RxXdfData(file.path(HDFSIntermediateDir, "PredictionsLogistic"), fileSystem = RxHdfsFileSystem())
  
  
  # Import the average of the scores and Operational Metrics computed during Development. 
  if(Stage == "Dev" | Stage == "Prod"){
    dev_test_avg_score <- readRDS(file = file.path(LocalModelsDir, "dev_test_avg_score.rds"))
    Operational_Metrics <- readRDS(file = file.path(LocalModelsDir, "Operational_Metrics.rds"))
  }
  
  if(Stage == "Web"){
    dev_test_avg_score <- model_objects$dev_test_avg_score
    Operational_Metrics <- model_objects$Operational_Metrics
  }
  
  ##########################################################################################################################################
  ## Import the predictions table and convert isBad to numeric for correct computations.
  ##########################################################################################################################################
  
  Predictions <- rxImport(PredictionsLogistic_xdf)
  Predictions$isBad <- as.numeric(as.character(Predictions$isBad))
  
  # Change the names of the variables in the predictions table for clarity.
  Predictions <- Predictions[, c(1, 2, 5)]
  colnames(Predictions) <- c("isBad", "loanId", "isBad_Pred")
  
  ##########################################################################################################################################
  ## Space out the scores (predicted probability of default) for interpretability with a sigmoid.
  ##########################################################################################################################################
  
  # Define the sigmoid. 
  sigmoid <- function(x){
    return(1/(1 + exp(-20*(x-1.2*dev_test_avg_score))))
  }
  
  # Apply the function.
  Predictions$transformedScore <- sigmoid(Predictions$isBad_Pred)
  
  ##########################################################################################################################################
  ## Apply the score transformation. 
  ##########################################################################################################################################
  
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
  
  
  ##########################################################################################################################################
  ## Save the transformed scores to HDFS.
  ##########################################################################################################################################
  
  Scores_xdf <- RxXdfData(file.path(HDFSIntermediateDir, "Scores"), fileSystem = RxHdfsFileSystem(), createCompositeSet = T)
  rxDataStep(inData = Predictions[, c("loanId", "transformedScore", "scorePercentile", "scoreCutoff", "badRate", "isBad")], 
             outFile = Scores_xdf, 
             overwrite = TRUE)
  
  
  ##########################################################################################################################################
  ## Save data in hive tables for display in PowerBI. 
  ##########################################################################################################################################
  rxSparkConnect(consoleOutput = TRUE, reset = FALSE)
  
  if(Stage == "Dev"){
    ScoresData_hive <- RxHiveData(table = "ScoresData")  
  } else{
    ScoresData_hive <- RxHiveData(table = "ScoresData_Prod")    
  }
  
  MergedCleaned_xdf <- RxXdfData(file.path(HDFSIntermediateDir, "MergedCleaned"), fileSystem = RxHdfsFileSystem())
  
  rxMerge(inData1 = MergedCleaned_xdf, 
          inData2 = Scores_xdf, 
          outFile = ScoresData_hive, 
          matchVars = "loanId",
          type = "inner",
          overwrite = TRUE)
  
  print("The hive table with the scores and data is stored under the folder /hive/warehouse")
  
}








