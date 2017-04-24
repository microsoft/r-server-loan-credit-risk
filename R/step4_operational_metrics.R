##########################################################################################################################################
## This R script will do the following:
## I. Compute Operational Metrics: expected bad rate for various classification decision thresholds.  
## II. Apply a score transformation based on operational metrics. 

## Input : Predictions table.
## Output: Operational Metrics and Transformed Scores. 
#########################################################################################################################################


##########################################################################################################################################
## The function below computes operational metrics in the following way:
## 1. Apply a sigmoid function to the output scores of the logistic regression, in order to spread them in [0,1].
## 2. Compute bins for the scores, based on quantiles. 
## 3. Take each lower bound of each bin as a decision threshold for default loan classification, and compute the rate of bad loans
##    among loans with a score higher than the threshold. 
##########################################################################################################################################


compute_operational_metrics <- function(){
  
  print("Computing operational metrics...")
  
  # Set the compute context to Local. 
  rxSetComputeContext('local')
  
  ##########################################################################################################################################
  ## Import the predictions table and convert isBad to numeric for correct computations.
  ##########################################################################################################################################
  
  Predictions_sql <- RxSqlServerData(table = "Predictions_Logistic", connectionString = connection_string)
  Predictions <- rxImport(Predictions_sql)
  Predictions$isBad <- as.numeric(as.character(Predictions$isBad))
  
  ##########################################################################################################################################
  ## Space out the scores (predicted probability of default) for interpretability with a sigmoid.
  ##########################################################################################################################################
  
  # Define the sigmoid: it is centered at 1.2*mean score to ensure a good spread of scores.  
  ## The sigmoid parameters can be changed for a new data set. 
  avg <- mean(Predictions$isBad_Pred)
  sigmoid <- function(x){
    return(1/(1 + exp(-20*(x-1.2*avg))))
  }
  
  # Apply the function.
  Predictions$transformedScore <- sigmoid(Predictions$isBad_Pred)
  
  # Changes can be observed with the histograms and summary statistics.
  ##summary(Predictions$isBad_Pred)
  ##hist(Predictions$isBad_Pred)
  ##summary(Predictions$transformedScore)
  ##hist(Predictions$transformedScore)
  
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
  
  # Save the data points to a data frame and load it to SQL.  
  Operational_Scores <- data.frame(scorePercentile = names(bins), scoreCutoff = bins, badRate = badrate, row.names = NULL)
  Operational_Scores_sql <- RxSqlServerData(table = "Operational_Scores", connectionString = connection_string)
  rxDataStep(inData = Operational_Scores, outFile = Operational_Scores_sql, overwrite = TRUE)
  
  return(Operational_Scores)
}


##########################################################################################################################################
## The function below transforms the scores given by the logistic regression on the testing set in the following way:
## 1. Apply a sigmoid function to the output scores of the logistic regression, in order to spread them in [0,1].
## 2. Asssign each score to a quantile bin with the bad rates given by the Operational Scores table.
##########################################################################################################################################

apply_score_transformation <- function(Operational_Scores){
  
  print("Transforming scores based on operational metrics...")
  
  # Set the compute context to Local. 
  rxSetComputeContext('local')
  
  ##########################################################################################################################################
  ## Import the predictions table and convert isBad to numeric for correct computations.
  ##########################################################################################################################################
  
  Predictions_sql <- RxSqlServerData(table = "Predictions_Logistic", connectionString = connection_string)
  Predictions <- rxImport(Predictions_sql)
  Predictions$isBad <- as.numeric(as.character(Predictions$isBad))
  
  ##########################################################################################################################################
  ## Space out the scores (predicted probability of default) for interpretability with a sigmoid.
  ##########################################################################################################################################
  
  # Define the sigmoid: it is centered at the mean score to ensure a good spread around a 0.5 score. 
  avg <- mean(Predictions$isBad_Pred)
  sigmoid <- function(x){
    return(1/(1 + exp(-20*(x-1.5*avg))))
  }
  
  # Apply the function.
  Predictions$transformedScore <- sigmoid(Predictions$isBad_Pred)
  
  ##########################################################################################################################################
  ## Apply the score transformation. 
  ##########################################################################################################################################
  
  # Deal with the bottom 1-99 percentiles. 
  for (i in seq(1, (nrow(Operational_Scores) - 1))){
    rows <- which(Predictions$transformedScore <= Operational_Scores$scoreCutoff[i + 1] & 
                  Predictions$transformedScore > Operational_Scores$scoreCutoff[i])
    Predictions[rows, c("scorePercentile")] <- as.character(Operational_Scores$scorePercentile[i + 1])
    Predictions[rows, c("badRate")] <- Operational_Scores$badRate[i]
    Predictions[rows, c("scoreCutoff")] <- Operational_Scores$scoreCutoff[i]
  }
  
  # Deal with the top 1% higher scores (last bucket). 
  rows <- which(Predictions$transformedScore > Operational_Scores$scoreCutoff[100])
  Predictions[rows, c("scorePercentile")] <- "Top 1%"
  Predictions[rows, c("scoreCutoff")] <- Operational_Scores$scoreCutoff[100]
  Predictions[rows, c("badRate")] <- Operational_Scores$badRate[100]

  
  ##########################################################################################################################################
  ## Save the transformed scores to SQL. 
  ##########################################################################################################################################
  
  Scores_sql <- RxSqlServerData(table = "Scores", connectionString = connection_string)
  rxDataStep(inData = Predictions[, c("loanId", "transformedScore", "scorePercentile", "scoreCutoff", "badRate", "isBad")], 
             outFile = Scores_sql, 
             overwrite = TRUE)
}



