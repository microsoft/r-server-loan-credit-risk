##########################################################################################################################################
## This R script will do the following:
## 1. Train a logistic regression classification model on the training set and save it to SQL. 
## 2. Score the logisitc regression on the test set.
## 3. Evaluate the tested model.

## Input : Featurized data set Merged_Features.
## Output: Logistic Regression Model, Predictions and Evaluation Metrics. 
##########################################################################################################################################

## Function for training, scoring and evaluating:

training_evaluation <- function()
{ 
  
  # Load the ROCR package (install it if on your own machine). 
  if(!require(ROCR)){
    #install.packages("ROCR")
    library(ROCR)
  }
  
  # Set the compute context to SQL. 
  rxSetComputeContext(sql)
  
  # Point to the input data, specifying that characters should be treated as factors with stringsAsFactors = T. 
  Merged_Features_sql <- RxSqlServerData(table = "Merged_Features", connectionString = connection_string, stringsAsFactors = T)
  
  ##########################################################################################################################################
  
  ## The block below will do the following:
  ## 1. Get the column information and save it ot SQL for production. 
  ## 2. Create pointers to the training and testing sets.
  
  ##########################################################################################################################################
  
  # Get the column information. 
  print("Getting the variable information...")
  column_info <- rxCreateColInfo(Merged_Features_sql, sortLevels = T)
  
  # Set the compute context to local to export the column_info list to SQl. 
  rxSetComputeContext('local')
  
  ## Open an Odbc connection with SQL Server.
  OdbcModel <- RxOdbcData(table = "Column_Info", connectionString = connection_string)
  rxOpen(OdbcModel, "w")
  
  ## Drop the Column Info table if it exists. 
  if(rxSqlServerTableExists(OdbcModel@table, OdbcModel@connectionString)) {
    rxSqlServerDropTable(OdbcModel@table, OdbcModel@connectionString)
  }
  
  ## Create an empty Bins table. 
  rxExecuteSQLDDL(OdbcModel, 
                  sSQLString = paste(" CREATE TABLE [", OdbcModel@table, "] (",
                                     "     [id] varchar(200) not null, ",
                                     "     [value] varbinary(max), ",
                                     "     constraint unique_id2 unique (id))",
                                     sep = "")
  )
  
  ## Write the model to SQL. 
  rxWriteObject(OdbcModel, "Column Info", column_info)
  
  ## Close the Obdc connection used. 
  rxClose(OdbcModel)
  
  # Set the compute context back to SQL. 
  rxSetComputeContext(sql)
  
  # Point to the training set. It will be created on the fly when training models. 
  Train_sql <- RxSqlServerData(sqlQuery = 
                               "SELECT *   
                                FROM Merged_Features 
                                WHERE loanId IN (SELECT loanId from Train_Id)",
                                  connectionString = connection_string, colInfo = column_info)
  
  # Point to the testing set. It will be created on the fly when testing models. 
  Test_sql <- RxSqlServerData(sqlQuery = 
                              "SELECT *   
                               FROM Merged_Features 
                               WHERE loanId NOT IN (SELECT loanId from Train_Id)",
                              connectionString = connection_string, colInfo = column_info)
  
  
  ##########################################################################################################################################
  
  ##	The block below will make the formula used for the training.
  
  ##########################################################################################################################################
  
  # Write the formula after removing variables not used in the modeling.
  ## We remove the id variables, date, residentialState, term, and all the numeric variables that were later bucketed. 
  variables_all <- rxGetVarNames(Train_sql)
  variables_to_remove <- c("loanId", "memberId", "loanStatus", "date", "residentialState", "term",
                           "loanAmount", "interestRate", "monthlyPayment", "annualIncome", "dtiRatio", "lengthCreditHistory",
                           "numTotalCreditLines", "numOpenCreditLines", "numOpenCreditLines1Year", "revolvingBalance",
                           "revolvingUtilizationRate", "numDerogatoryRec", "numDelinquency2Years", "numChargeoff1year", 
                           "numInquiries6Mon")
  
  training_variables <- variables_all[!(variables_all %in% c("isBad", variables_to_remove))]
  formula <- as.formula(paste("isBad ~", paste(training_variables, collapse = "+")))
  
  ##########################################################################################################################################
  
  ## The block below will do the following:
  ## 1. Train a logistic regression model.
  ## 2. Save the trained logistic regression model on SQL Server.
  
  ##########################################################################################################################################
  print("Training the logistic regression model...")
  
  # Train the logistic regression model.
  logistic_model <- rxLogit(formula = formula,
                            data = Train_sql,
                            reportProgress = 0, 
                            initialValues = NA)
  
  # Get the coefficients of the logistic regression formula.
  ## NA means the variable has been dropped while building the model.
  coeff <- logistic_model$coefficients
  Logistic_Coeff <- data.frame(variable = names(coeff), coefficient = coeff, row.names = NULL)
  
  ## Order in decreasing order of absolute value of coefficients. 
  Logistic_Coeff <- Logistic_Coeff[order(abs(Logistic_Coeff$coefficient), decreasing = T),]
  
  # Write the table to SQL. Compute Context should be set to local. 
  rxSetComputeContext('local')
  Logistic_Coeff_sql <- RxSqlServerData(table = "Logistic_Coeff", connectionString = connection_string)
  rxDataStep(inData = Logistic_Coeff, outFile = Logistic_Coeff_sql, overwrite = TRUE)
  
  
  # Save the fitted model to SQL. 
  
  ## Open an Odbc connection with SQL Server.
  OdbcModel <- RxOdbcData(table = "Model", connectionString = connection_string)
  rxOpen(OdbcModel, "w")
  
  ## Drop the Model table if it exists. 
  if(rxSqlServerTableExists(OdbcModel@table, OdbcModel@connectionString)) {
    rxSqlServerDropTable(OdbcModel@table, OdbcModel@connectionString)
  }
  
  ## Create an empty Model table. 
  rxExecuteSQLDDL(OdbcModel, 
                  sSQLString = paste(" CREATE TABLE [", OdbcModel@table, "] (",
                                     "     [id] varchar(200) not null, ",
                                     "     [value] varbinary(max), ",
                                     "     constraint unique_id3 unique (id))",
                                     sep = "")
                  )
  
  ## Write the model to SQL. 
  rxWriteObject(OdbcModel, "Logistic Regression", logistic_model)
  
  # Close the Obdc connection used. 
  rxClose(OdbcModel)

  # Set the compute context back to SQL. 
  rxSetComputeContext(sql)
  
  ##########################################################################################################################################
  
  ## The block below will score the logistic model on the test set and output the prediction table.
  
  ##########################################################################################################################################
  print("Scoring the logistic regression model...")
  
  # Make Predictions and save them to SQL.
  Predictions_Logistic_sql <- RxSqlServerData(table = "Predictions_Logistic", connectionString = connection_string)
  
  rxPredict(logistic_model, 
            data = Test_sql, 
            outData = Predictions_Logistic_sql, 
            overwrite = T, 
            type = "response",
            extraVarsToWrite = c("isBad", "loanId"))
  
  ##########################################################################################################################################
  
  ## The block below will do the following:
  ## 1. Compute the confusion matrix and some classification metrics. 
  ## 2. Compute the AUC and plot the ROC curve.
  ## 3. Compute the KS statistic and draw the KS plot. 
  
  ##########################################################################################################################################
  print("Evaluating the logistic regression model...")
  
  evaluate_model <- function(predictions_table = "Predictions_Logistic") { 
    
    # Import the prediction table and convert isBad to numeric for correct evaluation. 
    Predictions_sql <- RxSqlServerData(table = predictions_table, connectionString = connection_string)
    Predictions <- rxImport(Predictions_sql)
    Predictions$isBad <- as.numeric(as.character(Predictions$isBad))
    
    ## KS PLOT AND STATISTIC.
    # Split the data according to the observed value and get the cumulative distribution of predicted probabilities. 
    Predictions0 <- Predictions[Predictions$isBad ==0,]$isBad_Pred
    Predictions1 <- Predictions[Predictions$isBad ==1,]$isBad_Pred
    
    cdf0 <- ecdf(Predictions0)
    cdf1 <- ecdf(Predictions1)
    
    # Compute the KS statistic and the corresponding points on the KS plot. 
    
    ## Create a sequence of predicted probabilities in its range of values. 
    minMax <- seq(min(Predictions0, Predictions1), max(Predictions0, Predictions1), length.out=length(Predictions0)) 
    
    ## Compute KS, ie. the largest distance between the two cumulative distributions. 
    KS <- max(abs(cdf0(minMax) - cdf1(minMax))) 
    
    ## Find one predicted probability where the cumulative distributions have the biggest difference.  
    x0 <- minMax[which(abs(cdf0(minMax) - cdf1(minMax)) == KS )][1] 
    
    ## Get the corresponding points on the plot. 
    y0 <- cdf0(x0) 
    y1 <- cdf1(x0) 
    
    # Plot the two cumulative distributions with the line between points of greatest distance. 
    plot(cdf0, verticals = T, do.points = F, col = "blue", main = sprintf("KS Plot; KS = %s", round(KS, digits = 3)), ylab = "Cumulative Distribution Functions", xlab = "Predicted Probabilities") 
    plot(cdf1, verticals = T, do.points = F, col = "green", add = T) 
    legend(0.3, 0.8, c("isBad == 0", "isBad == 1"), lty = c(1, 1),lwd = c(2.5, 2.5), col = c("blue", "green"))
    points(c(x0, x0), c(y0, y1), pch = 16, col = "red") 
    segments(x0, y0, x0, y1, col = "red", lty = "dotted") 
    

    ## CONFUSION MATRIX AND VARIOUS METRICS. 
  
    # The cumulative distributions of predicted probabilities given observed values are the farthest apart for a score equal to x0.
    # We can then use x0 as a decision threshold for example. 
    # Note that the choice of a decision threshold can be further optimized.
    
    # Using the x0 point as a threshold, we compute the binary predictions to get the confusion matrix. 
    Predictions$isBad_Pred_Binary <- ifelse(Predictions$isBad_Pred < x0, 0, 1)
    
    confusion <- table(Predictions$isBad, Predictions$isBad_Pred_Binary, dnn = c("Observed", "Predicted"))[c("0", "1"), c("0", "1")]
    print(confusion) 
    tp <- confusion[1, 1] 
    fn <- confusion[1, 2] 
    fp <- confusion[2, 1] 
    tn <- confusion[2, 2] 
    accuracy <- (tp + tn) / (tp + fn + fp + tn) 
    precision <- tp / (tp + fp) 
    recall <- tp / (tp + fn) 
    fscore <- 2 * (precision * recall) / (precision + recall) 
    
    ## ROC PLOT AND AUC.
    ROC <- rxRoc(actualVarName = "isBad", predVarNames = "isBad_Pred", data = Predictions, numBreaks = 1000)
    AUC <- rxAuc(ROC)
    plot(ROC, title = "ROC Curve for Logistic Regression")
    
    ## LIFT CHART. 
    pred <- prediction(predictions = Predictions$isBad_Pred, labels = Predictions$isBad, label.ordering = c("0", "1"))
    perf <- performance(pred,  measure = "lift", x.measure = "rpp") 
    plot(perf, main = c("Lift Chart"))
    abline(h = 1.0, col = "purple")
    
    # Return the computed metrics.
    metrics <- c("Accuracy" = accuracy, 
                 "Precision" = precision, 
                 "Recall" = recall, 
                 "F-Score" = fscore,
                 "AUC" = AUC,
                 "KS" = KS,
                 "Score Threshold" = x0) 
    return(metrics) 
  } 
  
  # Apply model evaluation. 
  ## Set the compute context to local. 
  rxSetComputeContext('local')
  metrics <- evaluate_model()
  
  print("Step 3 Completed.")
  print("Evaluation Metrics:")
  return(list(Logistic_Coeff, metrics))
  
} # end of step 3 function.   






