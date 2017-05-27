##########################################################################################################################################
## This R script will do the following:
## 1. Combine the different text files into 1 XDF file. 
## 2. Development: Split the featurized data set into a training and a testing set.  
## 3. Development: Train a logistic regression classification model on the training set.
## 4. Production/ Web Scoring: Load the logistic regression model and variable information from Development. 
## 5. Score the logisitc regression on the test set or Production/ Web Scoring data.
## 6. Development: Evaluate the model. 

## Input : Data set MergedFeaturesFactors.
## Output: Logistic Regression Model (Development) and Predictions.  
##########################################################################################################################################

## Function for splitting, training, scoring and evaluating:

# LocalWorkDir: the working directory on the edge node.
# HDFSWorkDir: the working directory on HDFS.
# splitting_ratio: the proportion (in ]0,1]) of observations that will end in the training set. Should be the same as in step 2.
# Stage: "Dev" for development, "Prod" for batch scoring, or "Web" for scoring remotely with web service.

training_evaluation <- function(LocalWorkDir,
                                HDFSWorkDir,
                                splitting_ratio = 0.7,
                                Stage)
{ 
  # Load the MicrosoftML library to use rxLogisticRegression and rxPredict. 
  library(MicrosoftML)
  
  # Define the intermediate directory holding the input data. 
  HDFSIntermediateDir <- file.path(HDFSWorkDir,"temp")
  
  # Define the directory where the model will be saved in the Development stage or loaded from in Production.
  LocalModelsDir <- file.path(LocalWorkDir, "model")
  
  # Point to the input data (both Development and Production/ Web Scoring).
  MergedFeaturesFactors_xdf <- RxXdfData(file.path(HDFSIntermediateDir, "MergedFeaturesFactors"), fileSystem = RxHdfsFileSystem())
  
  if(Stage == "Dev"){ # Splitting and Training are only performed for the Development stage. 
    
    ##########################################################################################################################################
    ## The block below will split the data into training and testing set 
    ##########################################################################################################################################
    
    print("Randomly Splitting into a training and a testing set using the hashCode created in step 2...")
    
    # Split the analytical data set into a training and a testing set. 
    ## Note that the training set in step 2 was used only to compute the bins.
    ## The training set here is augmented with the new features compared to the one in step 2.
    Train_xdf <- RxXdfData(file.path(HDFSIntermediateDir, "Train"), fileSystem = RxHdfsFileSystem())
    Test_xdf <- RxXdfData(file.path(HDFSIntermediateDir, "Test"), fileSystem = RxHdfsFileSystem())
    
    rxDataStep(inData = MergedFeaturesFactors_xdf,
               outFile = Train_xdf,
               overwrite = TRUE,
               rowSelection = (hashCode %% 100 < 100*splitting_ratio), 
               transformObjects = list(splitting_ratio = splitting_ratio),
               varsToDrop = c("hashCode") 
    )
    
    rxDataStep(inData = MergedFeaturesFactors_xdf,
               outFile = Test_xdf,
               overwrite = TRUE,
               rowSelection = (hashCode %% 100 >= 100*splitting_ratio), 
               transformObjects = list(splitting_ratio = splitting_ratio),
               varsToDrop = c("hashCode") 
    )
    
    ##########################################################################################################################################
    ##	The block below will write the formula used for the training
    ##########################################################################################################################################
    print("Writing the formula for training...")
    
    # Write the formula after removing variables not used in the Development.
    variables_all <- rxGetVarNames(Train_xdf)
    variables_to_remove <- c("loanId", "memberId", "date", "residentialState", "term")
    training_variables <- variables_all[!(variables_all %in% c("isBad", variables_to_remove))]
    formula <- as.formula(paste("isBad ~", paste(training_variables, collapse = "+")))
    
    ##########################################################################################################################################
    ## The block below will do the following:
    ## 1. Train a logistic regression model.
    ## 2. Save the trained logistic regression model on the local edge node.
    ##########################################################################################################################################
    print("Training the logistic regression model...")
    
    # Train the logistic regression model.
    ## The regularization weights (l1Weight and l2Weight) can be modified for further optimization.
    ## The included selectFeatures function can select a certain number of optimal features based on a specified method.
    ## the number of variables to select and the method can be further optimized.
    logistic_model <- rxLogisticRegression(formula = formula,
                                           data = Train_xdf,
                                           type = "binary",
                                           l1Weight = 0.7,
                                           l2Weight = 0.7,
                                           mlTransforms = list(selectFeatures(formula, mode = mutualInformation(numFeaturesToKeep = 10))))
    
    
    # Save the fitted model to the local edge node for use in Production.
    saveRDS(logistic_model, file = paste(LocalModelsDir, "/logistic_model.rds", sep = ""))
    
    # Get the coefficients of the logistic regression formula.
    ## NA means the variable has been dropped while building the model.
    coeff <- logistic_model$coefficients
    Logistic_Coeff <- data.frame(variable = names(coeff), coefficient = coeff, row.names = NULL)
    
    ## Order in decreasing order of absolute value of coefficients. 
    Logistic_Coeff <- Logistic_Coeff[order(abs(Logistic_Coeff$coefficient), decreasing = T),]
    
    # Save the coefficients table to the local edge node.
    saveRDS(Logistic_Coeff, file = paste(LocalModelsDir, "/Logistic_Coeff.rds", sep = ""))
    
  } # end of Stage == "Dev"
  
  ##########################################################################################################################################
  ## The block below will do the following load the logistic regression model created during Development. 
  ##########################################################################################################################################
  if(Stage == "Prod"){ 
    print("Importing the logistic regression model and variable information...")
    logistic_model <- readRDS(file = file.path(LocalModelsDir, "logistic_model.rds"))
    # Rename the pointer to the Production data to be scored. 
    Test_xdf <- MergedFeaturesFactors_xdf
  }
  
  if(Stage == "Web"){ 
    print("Importing the logistic regression model and variable information...")
    logistic_model <- model_objects$logistic_model
    # Rename the pointer to the Production data to be scored. 
    Test_xdf <- MergedFeaturesFactors_xdf
  }
  
  ##########################################################################################################################################
  ## The block below will score the test set or Production/ Web Scoring data on the logistic model and output the prediction table.
  ##########################################################################################################################################
  print("Scoring the logistic regression model...")
  
  # Make Predictions.
  PredictionsLogistic_xdf <- RxXdfData(file.path(HDFSIntermediateDir, "PredictionsLogistic"), fileSystem = RxHdfsFileSystem())
  
  rxPredict(logistic_model, 
            data = Test_xdf, 
            outData = PredictionsLogistic_xdf, 
            overwrite = T, 
            extraVarsToWrite = c("isBad", "loanId"))
  
  
  # Development: Perform model evaluation.  
  if(Stage == "Dev"){
    
    ##########################################################################################################################################
    ## The block below will do the following:
    ## 1. Compute the confusion matrix and some classification metrics. 
    ## 2. Compute the AUC and plot the ROC curve.
    ## 3. Compute the KS statistic and draw the KS plot. 
    ##########################################################################################################################################
    print("Evaluating the logistic regression model...")
    
    # Evaluation function. 
    evaluate_model <- function(predictions_table = PredictionsLogistic_xdf) { 
      
      # Import the prediction table and convert isBad to numeric for correct evaluation. 
      Predictions <- rxImport(predictions_table, varsToDrop = c("loanId"))
      Predictions$isBad <- as.numeric(as.character(Predictions$isBad))
      
      # Change the names of the variables in the predictions table for clarity.
      Predictions <- Predictions[, c(1, 4)]
      colnames(Predictions) <- c("isBad", "isBad_Pred")
      
      ## KS PLOT AND STATISTIC.
      # Split the data according to the observed value.
      Predictions0 <- Predictions[Predictions$isBad ==0,]$isBad_Pred
      Predictions1 <- Predictions[Predictions$isBad ==1,]$isBad_Pred
      
      # Get the cumulative distribution of predicted probabilities (on a subset for faster computations). 
      cdf0 <- ecdf(Predictions0[base::sample(seq(1, length(Predictions0)), replace = F, size = min(300000, length(Predictions0)))])
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
      ROC <- rxRoc(actualVarName = "isBad", predVarNames = "isBad_Pred", data = Predictions, numBreaks = 100)
      AUC <- rxAuc(ROC)
      plot(ROC, title = "ROC Curve for Logistic Regression")
      
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
    
    # Apply model evaluation in local compute context. 
    rxSetComputeContext('local')
    metrics <- evaluate_model()
    
    print("Step 3 Completed.")
    print("Evaluation Metrics:")
    print(metrics)
    return(metrics)
    
  } # end of model evaluation when Stage == "Dev". 
  
  print("Step 3 Completed.")
} # end of step 3 function.   


