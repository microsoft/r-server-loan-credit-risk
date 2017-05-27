##########################################################################################################################################
## This R script will do the following:
## 1. Specify parameters for main function.
## 2. Define the main function for development. 
## 3. Invoke the main function.

## Input : 1. Full path of the two input tables on HDFS.
##         2. Working directories on local edge node and HDFS
##         3. Stage: "Dev" for development.
## Output: The evaluation metrics of the model. 
##         Tables and model to be used for Production or Web Scoring are copied to the Production directory. 

##########################################################################################################################################

##########################################################################################################################################
## Open Spark Connection and load RevoScaleR library. 
##########################################################################################################################################

rxSparkConnect(consoleOutput = TRUE, reset = TRUE)
library(RevoScaleR)

##########################################################################################################################################
## Directories
##########################################################################################################################################

# Local (edge node) working directory. We assume it already exists. 
LocalWorkDir <- paste("/var/RevoShare/", Sys.info()[["user"]], "/LoanCreditRisk/dev", sep="") 
#dir.create(LocalWorkDir, recursive = TRUE)

# HDFS directory for user calculation. We assume it already exists. 
HDFSWorkDir <- paste("/",Sys.info()[["user"]],"/LoanCreditRisk/dev", sep="")
#rxHadoopMakeDir(HDFSWorkDir)

# Current working directory should be set with setwd() to the location of the .R files.

##########################################################################################################################################
## Data sets full path
##########################################################################################################################################

# We assume the data already exists on HDFS, and write the full path to the 2 data sets.
Loan <- "/Loans/Data/Loan.csv"
Borrower <- "/Loans/Data/Borrower.csv"

##############################################################################################################################
## Define main function
##############################################################################################################################

## The user should replace the directory in "source" function with the directory of his own.
## The directory should be the full path containing the source scripts.

loan_dev <- function(Loan,
                     Borrower,
                     LocalWorkDir,
                     HDFSWorkDir, 
                     Stage = "Dev"){
  
  # step0: intermediate directories creation.
  print("Creating Intermediate Directories on Local and HDFS...")
  source(paste(getwd(),"/step0_directories_creation.R", sep =""))
  
  ## Define and create the directory where summary statistics, models etc. will be saved in the Development stage.
  LocalModelsDir <- file.path(LocalWorkDir, "model")
  if(dir.exists(LocalModelsDir)){
    system(paste("rm -rf ",LocalModelsDir,"/*", sep="")) # clean up the directory if exists
  } else {
    dir.create(LocalModelsDir, recursive = TRUE) # make new directory if doesn't exist
  }
  
  # step1: data processing
  source(paste(getwd(),"/step1_preprocessing.R", sep =""))
  print("Step 1: Data Processing.")
  
  data_preprocess(Loan, 
                  Borrower, 
                  LocalWorkDir,
                  HDFSWorkDir,
                  Stage = Stage)
  
  # step2: feature engineering
  source(paste(getwd(),"/step2_feature_engineering.R", sep =""))
  print("Step 2: Feature Engineering.")
  
  feature_engineer(LocalWorkDir,
                   HDFSWorkDir,
                   splitting_ratio = 0.7,
                   Stage = Stage)
  
  # step3: training, scoring and evaluation of Logistic Regression. 
  source(paste(getwd(),"/step3_train_score_evaluate.R", sep =""))
  print("Step 3: Training, Scoring and Evaluating.")
  
  metrics <- training_evaluation (LocalWorkDir,
                                  HDFSWorkDir,
                                  splitting_ratio = 0.7,
                                  Stage = Stage)
  
  # Step 4: operational metrics computation and scores transformation.  
  source(paste(getwd(),"/step4_operational_metrics.R", sep =""))
  print("Step 4: Operational Metrics Computation and Scores Transformation.")
  
  ## Compute operational metrics and plot the rates of bad loans for various thresholds obtained through binning. 
  Operational_Metrics <- compute_operational_metrics(LocalWorkDir,
                                                     HDFSWorkDir)
  
  plot(Operational_Metrics$badRate, main = c("Rate of Bad Loans Among those with Scores Higher than Decision Thresholds"), xlab = "Default Score Percentiles", ylab = "Expected Rate of Bad Loans")
  
  ## EXAMPLE: 
  ## If the score cutoff of the 91th score percentile is 0.9834, and we read a bad rate of 0.6449.  
  ## This means that if 0.9834 is used as a threshold to classify loans as bad, we would have a bad rate of 64.49%.  
  ## This bad rate is equal to the number of observed bad loans over the total number of loans with a score greater than the threshold. 
  
  ## Transform the scores using the computed thresholds. 
  apply_score_transformation (LocalWorkDir,
                              HDFSWorkDir,
                              Stage = Stage)
  
  
  # Finally, we copy the global means, modes and quantiles and the trained model for use in Production and Web Scoring.
  # You can change the value of update_prod_flag to 0 or comment out the code below to avoid overwriting those currently in use for Production.
 
  update_prod_flag = 1 
  if (update_prod_flag == 1){
    # Production directory that will hold the development data. 
    ProdModelDir <- paste("/var/RevoShare/", Sys.info()[["user"]], "/LoanCreditRisk/prod/model/", sep="") 
    # Development directory that holds data to be used in Production. 
    DevModelDir <- LocalModelsDir
    
    source(paste(getwd(),"/copy_dev_to_prod.R", sep =""))
    copy_dev_to_prod(DevModelDir, ProdModelDir)
  } 
 
  return(metrics)
}

##############################################################################################################################
## Apply the main function
##############################################################################################################################

metrics <- loan_dev (Loan, Borrower, LocalWorkDir, HDFSWorkDir, Stage = "Dev")

