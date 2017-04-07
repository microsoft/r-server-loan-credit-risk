SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- Stored Procedure to evaluate the model tested.
-- @predictions_table : name of the table that holds the predictions (output of scoring).

DROP PROCEDURE IF EXISTS [dbo].[evaluate]
GO

CREATE PROCEDURE [evaluate] @predictions_table varchar(max)

AS 
BEGIN
	-- Create an empty table to be filled with the Metrics.
	DROP TABLE if exists [dbo].[Metrics]
	CREATE TABLE [dbo].[Metrics](
		[modelName] [varchar](30) NOT NULL,
		[accuracy] [float] NULL,
		[precision] [float] NULL,
		[recall] [float] NULL,
		[F-score] [float] NULL,
		[AUC] [float] NULL,
		[KS] [float] NULL, 
		[scoreThreshold] [float] NULL 
		)
		
	-- Input will be read in-memory. 
	 DECLARE @inquery nvarchar(max)
     SET @inquery =  'SELECT * FROM ' + @predictions_table;

	-- Evaluate the Logistic Regression. 
	INSERT INTO Metrics 
	EXECUTE sp_execute_external_script @language = N'R',
	                                   @input_data_1 = @inquery,
									   @script = N' 

##########################################################################################################################################
##	Convert isBad to numeric in the imported predictions data set for correct evaluation. 
##########################################################################################################################################
InputDataSet$isBad <- as.numeric(as.character(InputDataSet$isBad))

##########################################################################################################################################
## Model evaluation metrics.
##########################################################################################################################################
evaluate_model <- function(Predictions_Table) {
      
    ## KS STATISTIC.
    # Split the data according to the observed value and get the cumulative distribution of predicted probabilities. 
    Predictions0 <- Predictions_Table[Predictions_Table$isBad == 0,]$isBad_Pred
    Predictions1 <- Predictions_Table[Predictions_Table$isBad == 1,]$isBad_Pred
    
    cdf0 <- ecdf(Predictions0)
    cdf1 <- ecdf(Predictions1)
    
    # Compute the KS statistic. 
    ## Create a sequence of predicted probabilities in its range of values. 
    minMax <- seq(min(Predictions0, Predictions1), max(Predictions0, Predictions1), length.out=length(Predictions0)) 
    
    ## Compute KS, ie. the largest distance between the two cumulative distributions. 
    KS <- max(abs(cdf0(minMax) - cdf1(minMax))) 

	## Find one predicted probability where the cumulative distributions have the biggest difference.  
    x0 <- minMax[which(abs(cdf0(minMax) - cdf1(minMax)) == KS )] [1]
      
    ## CONFUSION MATRIX AND VARIOUS METRICS. 
  
    # The cumulative distributions of predicted probabilities given observed values are the farthest apart for a score equal to x0.
    # We can then use x0 as a decision threshold for example. 
    # Note that the choice of a decision threshold can be further optimized.

    # Using the x0 point as a threshold, we compute the binary predictions to get the confusion matrix. 
    Predictions_Table$isBad_Pred_Binary <- ifelse(Predictions_Table$isBad_Pred < x0, 0, 1)
    
    confusion <- table(Predictions_Table$isBad, Predictions_Table$isBad_Pred_Binary, dnn = c("Observed", "Predicted"))[c("0", "1"), c("0", "1")]
    print(confusion) 
    tp <- confusion[1, 1] 
    fn <- confusion[1, 2] 
    fp <- confusion[2, 1] 
    tn <- confusion[2, 2] 
    accuracy <- (tp + tn) / (tp + fn + fp + tn) 
    precision <- tp / (tp + fp) 
    recall <- tp / (tp + fn) 
    fscore <- 2 * (precision * recall) / (precision + recall) 
    
    ## AUC.
    ROC <- rxRoc(actualVarName = "isBad", predVarNames = "isBad_Pred", data = Predictions_Table, numBreaks = 1000)
    AUC <- rxAuc(ROC)
    
    metrics <- c("Logistic Regression", accuracy, precision, recall, fscore, AUC, KS, x0)
    return(metrics)
 }

##########################################################################################################################################
## Logistic Regression Evaluation 
##########################################################################################################################################
OutputDataSet <- data.frame(rbind(evaluate_model(Predictions_Table = InputDataSet)))					       
'
;
END
GO

