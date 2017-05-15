SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- Stored Procedure to compute operational metrics in the Modeling pipeline. It is done in the following way:
-- 1. Apply a sigmoid function to the output scores of the logistic regression, in order to spread them in [0,1].
-- 2. Compute bins for the scores, based on quantiles. 
-- 3. Take each lower bound of each bin as a decision threshold for default loan classification, and compute the rate of bad loans
--    among loans with a score higher than the threshold. 

-- @predictions_table : name of the table that holds the predictions (output of scoring).

-- How to read the output table Operational_Metrics.
-- EXAMPLE: 
-- If the score cutoff of the 91th score percentile is 0.9834, and we read a bad rate of 0.6449.  
-- This means that if 0.9834 is used as a threshold to classify loans as bad, we would have a bad rate of 64.49%.  
-- This bad rate is equal to the number of observed bad loans over the total number of loans with a score greater than the threshold. 



DROP PROCEDURE IF EXISTS [dbo].[compute_operational_metrics]
GO

CREATE PROCEDURE [compute_operational_metrics] @predictions_table varchar(max)

AS 
BEGIN

   	-- Input will be read in-memory. 
	 DECLARE @inquery nvarchar(max)
     SET @inquery =  'SELECT * FROM ' + @predictions_table;

	-- Get the database name. 
	 DECLARE @database_name varchar(max) = db_name();

     EXECUTE sp_execute_external_script @language = N'R',
	                                    @input_data_1 = @inquery,
									    @script = N' 

##########################################################################################################################################
##	Define the connection string
##########################################################################################################################################
   connection_string <- paste("Driver=SQL Server;Server=localhost;Database=", database_name, ";Trusted_Connection=true;", sep="")

 ## Change the names of the variables in the predictions table if you used rxLogisticRegression.
 ## InputDataSet <- InputDataSet[, c(1, 2, 5)]
 ## colnames(InputDataSet) <- c("isBad", "loanId", "isBad_Pred")

##########################################################################################################################################
##	Space out the scores (predicted probability of default) for interpretability with a sigmoid.
##########################################################################################################################################
# Define and apply the sigmoid: it is centered at 1.2*mean score to ensure a good spread of scores. 
  avg <- mean(InputDataSet$isBad_Pred)
  sigmoid <- function(x){
    return(1/(1 + exp(-20*(x-1.2*avg))))
  }

  InputDataSet$transformedScore <- sigmoid(InputDataSet$isBad_Pred)

# Save the Average used for the sigmoid function to a SQL table, so it can be used in the Production pipeline. 
  Scores_Average <- data.frame(avg, row.names = NULL)
  Scores_Average_sql <- RxSqlServerData(table = "Scores_Average", connectionString = connection_string)
  rxDataStep(inData = Scores_Average, outFile = Scores_Average_sql, overwrite = TRUE)

##########################################################################################################################################
##	Get the expected rates of bad loans for every bin taken as a threshold. 
########################################################################################################################################## 
# Convert isBad to numeric. 
  InputDataSet$isBad <- as.numeric(as.character(InputDataSet$isBad))

# Bin the scores based on quantiles. 
  bins <- rxQuantile("transformedScore", InputDataSet, probs = c(seq(0, 0.99, 0.01)))
  bins[["0%"]] <- 0 
  
# We consider 100 decision thresholds: the lower bound of each bin.
# Compute the expected rates of bad loans for loans with scores higher than each decision threshold. 
  badrate <- rep(0, length(bins))
  for(i in 1:length(bins))
  {
    selected <- InputDataSet$isBad[InputDataSet$transformedScore >= bins[i]]
    badrate[i] <- sum(selected)/length(selected) 
  }
  
# Save the percentiles, score cutoffs and bad rates in a SQL table.  
  Operational_Metrics <- data.frame(scorePercentile = names(bins), scoreCutoff = bins, badRate = badrate, row.names = NULL)
  Operational_Metrics_sql <- RxSqlServerData(table = "Operational_Metrics", connectionString = connection_string)
  rxDataStep(inData = Operational_Metrics, outFile = Operational_Metrics_sql, overwrite = TRUE)
'
, @params = N' @database_name varchar(max)'
, @database_name = @database_name
;
END
GO


-- Stored Procedure to transform the scores given by the logistic regression in Modeling or Production. It is done in the following way:
-- 1. Apply a sigmoid function to the output scores of the logistic regression, in order to spread them in [0,1].
-- 2. Asssign each score to a quantile bin with the bad rates given by the Operational Scores table computed in the Modeling pipeline.
--    These bad rates are either observed (Modeling pipeline) or expected (Production pipeline).

-- @predictions_table : name of the table that holds the predictions (output of scoring).
-- @output: name of the table that will hold the final transformed scores. 

DROP PROCEDURE IF EXISTS [dbo].[apply_score_transformation]
GO

CREATE PROCEDURE [apply_score_transformation] @predictions_table varchar(max), @output varchar(max)

AS 
BEGIN

   	-- Input will be read in-memory. 
	 DECLARE @inquery nvarchar(max)
     SET @inquery =  'SELECT * FROM ' + @predictions_table;

	--	Get the average score and the score bins used in the Development pipeline, and the current database name.
	DECLARE @avg float = (select * from [dbo].[Scores_Average]);
	DECLARE @database_name varchar(max) = db_name();

    EXECUTE sp_execute_external_script @language = N'R',
	                                   @input_data_1 = @inquery,
									   @script = N' 

##########################################################################################################################################
##	Define the connection string
##########################################################################################################################################
  connection_string <- paste("Driver=SQL Server;Server=localhost;Database=", database_name, ";Trusted_Connection=true;", sep="")

 ## Change the names of the variables in the predictions table if you used rxLogisticRegression.
 ## InputDataSet <- InputDataSet[, c(1, 2, 5)]
 ## colnames(InputDataSet) <- c("isBad", "loanId", "isBad_Pred")

##########################################################################################################################################
##	Space out the scores (predicted probability of default) for interpretability with a sigmoid. 
##########################################################################################################################################
# Import the average value used in the Modeling pipeline sigmoid. 
  Avg_sql <- RxSqlServerData(sqlQuery = "SELECT * FROM [dbo].[Scores_Average]",
                             connectionString = connection_string)
  avg <- rxImport(Avg_sql)[1,1]


# Define and apply the sigmoid: it is centered at  1.2* the mean score used in the Development pipeline to ensure a good spread of scores. 
  sigmoid <- function(x){
    return(1/(1 + exp(-20*(x-1.2*avg))))
  }

  InputDataSet$transformedScore <- sigmoid(InputDataSet$isBad_Pred)
 
##########################################################################################################################################
##	Apply the score transformation. 
########################################################################################################################################## 
# Import the Bins used during the Development pipeline. 
  Operational_Metrics_sql <- RxSqlServerData(sqlQuery = "SELECT * FROM [dbo].[Operational_Metrics]",
                                            connectionString = connection_string)
  Operational_Metrics <- rxImport(Operational_Metrics_sql)

# Deal with the bottom 1-99 percentiles. 
  for (i in seq(1, (nrow(Operational_Metrics) - 1))){
    rows <- which(InputDataSet$transformedScore <= Operational_Metrics$scoreCutoff[i + 1] & 
                  InputDataSet$transformedScore > Operational_Metrics$scoreCutoff[i])
    InputDataSet[rows, c("scorePercentile")] <- as.character(Operational_Metrics$scorePercentile[i + 1])
    InputDataSet[rows, c("badRate")] <- Operational_Metrics$badRate[i]
    InputDataSet[rows, c("scoreCutoff")] <- Operational_Metrics$scoreCutoff[i]
  }
  
# Deal with the top 1% higher scores (last bucket). 
  rows <- which(InputDataSet$transformedScore > Operational_Metrics$scoreCutoff[100])
  InputDataSet[rows, c("scorePercentile")] <- "Top 1%"
  InputDataSet[rows, c("scoreCutoff")] <- Operational_Metrics$scoreCutoff[100]
  InputDataSet[rows, c("badRate")] <- Operational_Metrics$badRate[100]

##########################################################################################################################################
## Save the transformed scores to SQL. 
##########################################################################################################################################
  Scores_sql <- RxSqlServerData(table = output, connectionString = connection_string)
  rxDataStep(inData = InputDataSet[, c("loanId", "transformedScore", "scorePercentile", "scoreCutoff", "badRate", "isBad")], 
             outFile = Scores_sql, 
             overwrite = TRUE)  
'
, @params = N' @output varchar(max), @database_name varchar(max)'
, @output = @output
, @database_name = @database_name
;
END
GO

-- In the Production pipeline, isBad is unknown and has been artificially created in step 1. It is removed from the table with the statement:--
-- ALTER TABLE Scores_Prod DROP COLUMN isBad;

