##########################################################################################################################################
## This R script will do the following:
## 1. Remote login to the edge node for authentication purpose.
## 2. Load model related files as a list which will be used when publishing web service.
## 3. Define the main web scoring function.
## 4. Publish the web service.
## 3. Verify the webservice locally.

## Input : 1. Full path of the two input tables on HDFS (for processing with Spark) 
##            OR the two tables as data frames (for in-memory processing).
##         2. Working directories on local edge node and HDFS.
##         3. Stage: "Web" for scoring remotely with web service.
## Output: The directory on HDFS which contains the Scores (Spark version) or The Scores table (in-memory version).

##########################################################################################################################################

##############################################################################################################################
## Setup
##############################################################################################################################

# Load mrsdeploy package.
library(mrsdeploy)

# Remote login for authentication purpose.
## This would only work if the edge node was configured to host web services. 
remoteLogin(
  "http://localhost:12800",
  username = "admin",
  password = "XXYOURSQLPW",
  session = FALSE
)

##########################################################################################################################################
## Directories
##########################################################################################################################################

# Local (edge node) working directory. We assume it already exists. 
LocalWorkDir <- paste("/var/RevoShare/", Sys.info()[["user"]], "/LoanCreditRisk/prod", sep="") 
#dir.create(LocalWorkDir, recursive = TRUE)

# HDFS directory for user calculation. We assume it already exists. 
HDFSWorkDir <- paste("/",Sys.info()[["user"]],"/LoanCreditRisk/prod", sep="")
#rxHadoopMakeDir(HDFSWorkDir)

# Local directory holding data and model from the Development Stage. 
ProdModelDir <- paste(LocalWorkDir, "/model", sep ="")

##########################################################################################################################################
## Load data from the Development stage. 
##########################################################################################################################################

# Load .rds files saved from the Development stage and that will be used for web-scoring.

## Numeric_Means and Categorical_Modes: global means and modes of the dev data, for missing values replacement.
## bins: list of cutoffs to bucketize numeric variables. 
## column_factor_info: factor variables and their levels in the dev data set.
## logistic_model: logistic regression model trained in the dev stage. 
## dev_test_avg_score: average score on the dev testing set; used for score transformation. 
## Operational_Metrics: scores mapping (percentiles, cutoffs and expected bad rates).

Numeric_Means <- readRDS(file.path(ProdModelDir,"/Numeric_Means.rds"))
Categorical_Modes <- readRDS(file.path(ProdModelDir,"/Categorical_Modes.rds"))
bins <- readRDS(file.path(ProdModelDir,"/bins.rds"))
column_factor_info <- readRDS(file.path(ProdModelDir,"/column_factor_info.rds"))
logistic_model <- readRDS(file.path(ProdModelDir,"/logistic_model.rds"))
dev_test_avg_score <- readRDS(file.path(ProdModelDir,"/dev_test_avg_score.rds"))
Operational_Metrics <- readRDS(file.path(ProdModelDir,"/Operational_Metrics.rds"))

# They are packed in a list to be published along with the scoring function.
model_objects <- list(Numeric_Means = Numeric_Means, 
                      Categorical_Modes = Categorical_Modes,
                      bins  = bins,
                      column_factor_info = column_factor_info,
                      logistic_model = logistic_model,
                      dev_test_avg_score = dev_test_avg_score,
                      Operational_Metrics = Operational_Metrics)

##############################################################################################################################
## Define main function
##############################################################################################################################

## If Loan and Borrower are data frames, the web scoring is done in_memory. 
## Use paths to csv files on HDFS for large data sets that do not fit in-memory. 

loan_web_scoring <- function(Loan, 
                             Borrower, 
                             LocalWorkDir,
                             HDFSWorkDir,
                             Stage = "Web",
                             Username = Sys.info()[["user"]])
{
  
  if((class(Loan) == "data.frame") & (class(Borrower) == "data.frame")){ # In-memory scoring. 
    source(paste("/home/", Username,"/in_memory_scoring.R", sep=""))
    print("Scoring in-memory...")
    return(in_memory_scoring(Loan, Borrower, Stage = Stage))
    
  } else{ # Using Spark for scoring. 
    
    library(RevoScaleR)
    rxSparkConnect(consoleOutput = TRUE, reset = TRUE)
    
    # step0: intermediate directories creation.
    print("Creating Intermediate Directories on Local and HDFS...")
    source(paste("/home/", Username,"/step0_directories_creation.R", sep=""))
    
    # step1: data processing
    source(paste("/home/", Username,"/step1_preprocessing.R", sep=""))
    print("Step 1: Data Processing.")
    
    data_preprocess(Loan, 
                    Borrower, 
                    LocalWorkDir,
                    HDFSWorkDir,
                    Stage = Stage)
    
    # step2: feature engineering
    source(paste("/home/", Username,"/step2_feature_engineering.R", sep=""))
    print("Step 2: Feature Engineering.")
    ## splitting_ratio is not used in this stage. 
    
    feature_engineer(LocalWorkDir,
                     HDFSWorkDir,
                     splitting_ratio = 0.7,
                     Stage = Stage)
    
    # step3: making predictions. 
    source(paste("/home/", Username,"/step3_train_score_evaluate.R", sep=""))
    print("Step 3: Making Predictions.")
    ## splitting_ratio is not used in this stage. 
    training_evaluation (LocalWorkDir,
                         HDFSWorkDir,
                         splitting_ratio = 0.7,
                         Stage = Stage)
    
    # Step 4: scores transformation.  
    source(paste("/home/", Username,"/step4_operational_metrics.R", sep=""))
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
## Publish as a Web Service  
##############################################################################################################################

# Specify the version of the web service
version <- "v1.2.287"

# Publish the api for the character input case (ie. Loan and Borrower are data paths.)
api_string <- publishService(
  "loan_scoring_string_input",
  code = loan_web_scoring,
  model = model_objects,
  inputs = list(Loan = "character",
                Borrower = "character",
                LocalWorkDir = "character",
                HDFSWorkDir = "character",
                Stage = "character",
                Username = "character"),
  outputs = list(answer = "character"),
  v = version
)


# Publish the api for the data frame input case (ie. Web scoring is done in-memory.)
api_frame <- publishService(
  "loan_scoring_dframe_input",
  code = loan_web_scoring,
  model = model_objects,
  inputs = list(Loan = "data.frame",
                Borrower = "data.frame",
                LocalWorkDir = "character",
                HDFSWorkDir = "character",
                Stage = "character",
                Username = "character"),
  outputs = list(answer = "data.frame"),
  v = version
)

##############################################################################################################################
## Verify The Published API  
##############################################################################################################################

# Specify the full path of input .csv files on HDFS
Loan_str <- "/Loans/Data/Loan_Prod.csv"
Borrower_str <- "/Loans/Data/Borrower_Prod.csv"

# Import the .csv files as data frame. 
Loan_df <- rxImport(RxTextData(file = Loan_str, fileSystem = RxHdfsFileSystem()), stringsAsFactors = T)
Borrower_df <- rxImport(RxTextData(file = Borrower_str, fileSystem = RxHdfsFileSystem()), stringsAsFactors = T)

# Verify the string input case.
result_string <- api_string$loan_web_scoring(
  Loan = Loan_str,
  Borrower = Borrower_str,
  LocalWorkDir = LocalWorkDir,
  HDFSWorkDir = HDFSWorkDir,
  Stage = "Web",
  Username = Sys.info()[["user"]]
)

# Verify the data frame input case.
result_frame <- api_frame$loan_web_scoring(
  Loan = Loan_df,
  Borrower = Borrower_df,
  LocalWorkDir = LocalWorkDir,
  HDFSWorkDir = HDFSWorkDir,
  Stage = "Web",
  Username = Sys.info()[["user"]]
)

## To get the data frame result in a readable format: 
rows_number <- length(result_frame$outputParameters$answer$badRate)
Scores <- data.frame(matrix(unlist(result_frame$outputParameters$answer), nrow = rows_number), stringsAsFactors = F)
colnames(Scores) <- names(result_frame$outputParameters$answer)