##########################################################################################################################################
## This R script will do the following:
## 1. Specify parameters for main function.
## 2. Define the main function for production batch scoring. 
## 3. Invoke the main function.

## Input : 1. Full path of the two input tables on HDFS (for scoring with Spark) 
##            OR the two tables as data frames (for in-memory scoring).
##         2. Working directories on local edge node and HDFS.
##         3. Stage: "Prod" for batch scoring.
## Output: The directory on HDFS which contains the Scores (Spark version) or The Scores table (in-memory version).

##########################################################################################################################################

##########################################################################################################################################
## Load the RevoScaleR library and Open Spark Connection
##########################################################################################################################################

library(RevoScaleR)
rxSparkConnect(consoleOutput = TRUE, reset = TRUE)

##########################################################################################################################################
## Directories
##########################################################################################################################################

# Local (edge node) working directory. We assume it already exists. 
LocalWorkDir <- paste("/var/RevoShare/", Sys.info()[["user"]], "/LoanCreditRisk/prod", sep="") 
#dir.create(LocalWorkDir, recursive = TRUE)

# HDFS directory for user calculation. We assume it already exists. 
HDFSWorkDir <- paste("/",Sys.info()[["user"]],"/LoanCreditRisk/prod", sep="")
#rxHadoopMakeDir(HDFSWorkDir)

# Current working directory should be set with setwd() to the location of the .R files.

##########################################################################################################################################
## Data sets full path
##########################################################################################################################################

# We assume the data already exists on HDFS, and write the full path to the 2 data sets.
Loan_str <- "/Loans/Data/Loan_Prod.csv"
Borrower_str <- "/Loans/Data/Borrower_Prod.csv"

# Import the .csv files as data frames. 
Loan_df <- rxImport(RxTextData(file = Loan_str, fileSystem = RxHdfsFileSystem()), stringsAsFactors = T)
Borrower_df <- rxImport(RxTextData(file = Borrower_str, fileSystem = RxHdfsFileSystem()), stringsAsFactors = T)


##############################################################################################################################
## Define main function
##############################################################################################################################

## If Loan and Borrower are data frames, the web scoring is done in_memory. 
## Use paths to csv files on HDFS for large data sets that do not fit in-memory. 

loan_prod <- function(Loan,
                      Borrower,
                      LocalWorkDir, 
                      HDFSWorkDir,
                      Stage = "Prod"){
  
  # Directory that holds the tables and model from the Development stage.
  LocalModelsDir <- file.path(LocalWorkDir, "model")
  
  # Intermediate directories creation.
  print("Creating Intermediate Directories on Local and HDFS...")
  source(paste(getwd(),"/step0_directories_creation.R", sep =""))
  
  if((class(Loan) == "data.frame") & (class(Borrower) == "data.frame")){ # In-memory scoring. 
    source(paste(getwd(),"/in_memory_scoring.R", sep =""))
    print("Scoring in-memory...")
    return(in_memory_scoring(Loan, Borrower, Stage = Stage))
    
  } else{ # Using Spark for scoring. 
    
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
    ## splitting_ratio is not used in Production stage. 
    
    feature_engineer(LocalWorkDir,
                     HDFSWorkDir,
                     splitting_ratio = 0.7,
                     Stage = Stage)
    
    # step3: making predictions. 
    source(paste(getwd(),"/step3_train_score_evaluate.R", sep =""))
    print("Step 3: Making Predictions.")
    ## splitting_ratio is not used in Production stage. 
    training_evaluation (LocalWorkDir,
                         HDFSWorkDir,
                         splitting_ratio = 0.7,
                         Stage = Stage)
    
    # Step 4: scores transformation.  
    source(paste(getwd(),"/step4_operational_metrics.R", sep =""))
    print("Step 4: Scores Transformation.")
    
    ## Transform the scores using the computed thresholds. 
    apply_score_transformation (LocalWorkDir,
                                HDFSWorkDir,
                                Stage = Stage)
    
    # Return the directory storing the final scores. 
    return(file.path(HDFSWorkDir,"temp", "Scores"))
    
  }
}

##############################################################################################################################
## Apply the main function
##############################################################################################################################

# Case 1: Input are data frames. Scoring is performed in-memory. 
Scores <- loan_prod (Loan_df, Borrower_df, LocalWorkDir, HDFSWorkDir, Stage = "Prod")

# Write the Merged and Scores to a Hive table for visualizations in PowerBI.
## The 2 data frames should be converted to xdf first. 
rxSetComputeContext('local')
Merged <- rxMerge(Loan_df, Borrower_df, type = "inner", matchVars = "memberId")

Scores_xdf <- RxXdfData(file.path(HDFSWorkDir,"temp", "ScoresPBI"), fileSystem = RxHdfsFileSystem(), createCompositeSet = T)
Merged_xdf <- RxXdfData(file.path(HDFSWorkDir,"temp", "MergedPBI"), fileSystem = RxHdfsFileSystem(), createCompositeSet = T)

rxDataStep(inData = Scores, outFile = Scores_xdf, overwrite = TRUE)
rxDataStep(inData = Merged, outFile = Merged_xdf, overwrite = TRUE)

## The xdf files are then converted to Hive tables.
rxSparkConnect(consoleOutput = TRUE, reset = FALSE)

ScoresData_hive <- RxHiveData(table = "ScoresData_Prod")  
Merged_hive <- RxHiveData(table = "Merged_Prod")  
rxDataStep(inData = Scores_xdf, outFile = ScoresData_hive, overwrite = TRUE)
rxDataStep(inData = Merged_xdf, outFile = Merged_hive, overwrite = TRUE)


# Case 2: Input are paths to csv files. Scoring using Spark. 
## This alternative is slow and should only be used if the data set to score is too large to fit in memory.
# scores_directory <- loan_prod (Loan_str, Borrower_str, LocalWorkDir, HDFSWorkDir, Stage = "Prod")

# Warning: in case you get the following error: "Error: file.exists(inData1) is not TRUE", 
# you should reset your R session with Ctrl + Shift + F10 (or Session -> Restart R) and try running it again.
