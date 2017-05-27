##########################################################################################################################################
## This R script will do the following:
## 1. Convert the 2 raw data sets Loan and Borrower to xdf.
## 2. Merge the 2 tables into one.
## 3. Clean the merged data set: replace NAs with the global mean (numeric variables) or global mode (categorical variables).

## Input : 2 Data Tables: Loan and Borrower.
## Output: Cleaned data set MergedCleaned.

##########################################################################################################################################

## Function of data processing:

# Loan: full name of the Loan table in .csv format.
# Borrower: full name of the Borrower table in .csv format.
# LocalWorkDir: the working directory on the edge node.
# HDFSWorkDir: the working directory on HDFS.
# Stage: "Dev" for development, "Prod" for batch scoring, or "Web" for scoring remotely with web service.

data_preprocess <- function(Loan, 
                            Borrower, 
                            LocalWorkDir,
                            HDFSWorkDir,
                            Stage)
{ 
  
  
  # Define the intermediate directory holding the input data.  
  HDFSIntermediateDir <- file.path(HDFSWorkDir,"temp")
  
  # Define the directory where summary statistics will be saved in the Development stage or loaded from in Production.
  LocalModelsDir <- file.path(LocalWorkDir, "model")
  
  ##############################################################################################################################
  ## The block below will convert the data format to xdf in order to increase the efficiency of rx functions. 
  ##############################################################################################################################
  
  print("Converting the input data to xdf on HDFS...")
  
  # Create XDF pointers for the 2 data sets on HDFS. 
  Loan_xdf <- RxXdfData(paste(HDFSIntermediateDir,"/Loan",sep=""), fileSystem = RxHdfsFileSystem())
  Borrower_xdf <- RxXdfData(paste(HDFSIntermediateDir,"/Borrower",sep=""), fileSystem = RxHdfsFileSystem())
  
  # Check the input format. Return an error if it is not a path. 
  if((class(Loan) == "character") & (class(Borrower) == "character")){
    
    # Text pointers to the inputs. 
    Loan_txt <- RxTextData(Loan, firstRowIsColNames = T, fileSystem = RxHdfsFileSystem(), stringsAsFactors = T)
    Borrower_txt <- RxTextData(Borrower, firstRowIsColNames = T, fileSystem = RxHdfsFileSystem(), stringsAsFactors = T) 
    
    # Conversion to xdf. 
    rxDataStep(inData = Loan_txt, outFile = Loan_xdf, overwrite = T)
    rxDataStep(inData = Borrower_txt, outFile = Borrower_xdf, overwrite = T)
    
  } else {
    stop("invalid input format")
  }
  
  ##############################################################################################################################
  ## The block below will merge the two xdf files. 
  ##############################################################################################################################
  
  print("Merging Loan and Borrower...")
  
  # Create an XDF pointer for the output merged table.
  # Merged_xdf <- RxXdfData(file.path(HDFSIntermediateDir, "Merged"), fileSystem = RxHdfsFileSystem())
  
  # Create a Hive Table pointer for the output merged table. We use a hive table to preserve column information for factors. 
  colInfo1 = rxCreateColInfo(Loan_xdf)
  colInfo2 = rxCreateColInfo(Borrower_xdf)
  colInfo <- list()
  for(name in names(colInfo1)){
    colInfo[[name]] <- colInfo1[[name]]
  }
  for(name in names(colInfo2)){
    colInfo[[name]] <- colInfo2[[name]]
  }
  
  # Convert the two binary variables from integer to factor.
  colInfo$isJointApplication$type <- "factor"
  colInfo$isJointApplication$levels <- c("0", "1")
  colInfo$incomeVerified$type <- "factor"
  colInfo$incomeVerified$levels <- c("0", "1")
  
  Merged_hive <- RxHiveData(table = "Merged", colInfo = colInfo) 
  
  # Merge Loan and Borrower on memberId. 
  rxMerge(inData1 = Loan_xdf, 
          inData2 = Borrower_xdf, 
          outFile = Merged_hive, 
          matchVars = "memberId",
          type = "inner",
          overwrite = TRUE)
  
  # Convert back to xdf. 
  Merged_xdf <- RxXdfData(file.path(HDFSIntermediateDir, "Merged"), fileSystem = RxHdfsFileSystem())
  rxDataStep(inData = Merged_hive, outFile = Merged_xdf, overwrite = T)
  
  ############################################################################################################################################
  ## The block below will do the following:
  ## 1. Use rxSummary to get the names of the variables with missing values.
  ## Then, only if there are missing values: 
  ## 2. Compute the global mean (numeric variables) or global mode (categorical variables) of variables with missing values.
  ## 3. Clean the merged data set: replace NAs with the global mean or global mode.
  ############################################################################################################################################
  print("Looking for variables with missing values...")
  
  # Use rxSummary function to get the names of the variables with missing values.
  ## Assumption: no NAs in the id variables (loan_id and member_id) and loan_status or the date.
  colnames <- names(Merged_xdf)
  var <- colnames[!colnames %in% c("loanId", "memberId", "loanStatus", "date")]
  formula <- as.formula(paste("~", paste(var, collapse = "+")))
  summary <- rxSummary(formula, Merged_xdf , byTerm = TRUE)
  
  ## Get the variables types.
  categorical_all <- unlist(lapply(summary$categorical, FUN = function(x){colnames(x)[1]}))
  numeric_all <- setdiff(var, categorical_all)
  
  ## Get the variables names with NA. 
  var_with_NA <- summary$sDataFrame[summary$sDataFrame$MissingObs > 0, 1]
  categorical_NA <- intersect(categorical_all, var_with_NA)
  numeric_NA <- intersect(numeric_all, var_with_NA)
  
  ## For the Development stage, we get and store the summary statistics for Production and Web Scoring use. 
  if(Stage == "Dev"){
    
    # Compute the global means. 
    Summary_DF <- summary$sDataFrame
    Numeric_Means <- Summary_DF[Summary_DF$Name %in% numeric_all, c("Name", "Mean")]
    
    # Compute the global modes. 
    ## Get the counts tables.
    Summary_Counts <- summary$categorical
    names(Summary_Counts) <- lapply(Summary_Counts, FUN = function(x){colnames(x)[1]})
    
    ## Compute for each count table the value with the highest count. 
    modes <- unlist(lapply(Summary_Counts, FUN = function(x){as.character(x[which.max(x[,2]),1])}), use.names = F)
    Categorical_Modes <- data.frame(Name = categorical_all, Mode = modes)
    
    # Save the statistics for Production or Web Scoring use. 
    saveRDS(Numeric_Means, file.path(LocalModelsDir, "Numeric_Means.rds"))
    saveRDS(Categorical_Modes, file.path(LocalModelsDir, "Categorical_Modes.rds"))
  }  
  
  ## For the Production stage, we load the summary statistics computed in the Development stage. 
  if(Stage == "Prod"){
    Numeric_Means <- readRDS(file.path(LocalModelsDir, "Numeric_Means.rds"))
    Categorical_Modes <- readRDS(file.path(LocalModelsDir, "Categorical_Modes.rds"))
  }
  
  ## For the Web Scoring, we directly read the summary statistics computed in the Development stage. 
  ## They are included in the list model_objects, defined in "deployment.R". It can be used when calling the published web service.
  if(Stage == "Web"){
    Numeric_Means <- model_objects$Numeric_Means
    Categorical_Modes <- model_objects$Categorical_Modes
  }
  
  # If no missing values, we copy and rename the files to the cleaned data folder.
  if(length(var_with_NA) == 0){
    print("No missing values: no treatment will be applied.")
    rxHadoopCopy(source = file.path(HDFSIntermediateDir, "Merged"),
                 dest = file.path(HDFSIntermediateDir, "MergedCleaned"))
    
    
    # If there are missing values, we replace them with the mode or mean.    
  }else{
    print("Variables containing missing values are:")
    print(var_with_NA)
    print("Replacing missing values with the global mean or mode...")
    
    # Get the global means of the numeric variables with missing values.
    numeric_NA_mean <- round(Numeric_Means[Numeric_Means$Name %in% numeric_NA,]$Mean)
    
    # Get the global modes of the categorical variables with missing values. 
    categorical_NA_mode <- as.character(Categorical_Modes[Categorical_Modes$Name %in% categorical_NA,]$Mode)
    
    # Function to replace missing values with mean or mode. It will be wrapped into rxDataStep. 
    Mean_Mode_Replace <- function(data) {
      data <- data.frame(data, stringsAsFactors = F)
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
          row_na <- which(is.na(data[, cat_with_NA[i]]) == TRUE) 
          data[row_na, cat_with_NA[i]] <- cat_NA_mode[i]
        }
      }
      return(data)  
    }
    
    
    # Point to the output partial data. 
    MergedCleaned_xdf <- RxXdfData(file.path(HDFSIntermediateDir, "MergedCleaned"), fileSystem = RxHdfsFileSystem())
    
    # Perform the data cleaning with rxDataStep. 
    rxDataStep(inData = Merged_xdf, 
               outFile = MergedCleaned_xdf, 
               overwrite = T, 
               transformFunc = Mean_Mode_Replace,
               transformObjects = list(num_with_NA = numeric_NA , num_NA_mean = numeric_NA_mean,
                                       cat_with_NA = categorical_NA, cat_NA_mode = categorical_NA_mode))  
    
    ## Check if data cleaned:
    ## summary_cleaned <- rxSummary(formula, MergedCleaned_xdf , byTerm = TRUE)
    ## Summary_Cleaned_DF <- summary_cleaned$sDataFrame
    ## length(Summary_Cleaned_DF[Summary_Cleaned_DF$MissingObs > 0,2]) == 0
    
    print("Step 1 Completed.")
    
  }
  
}# end of step 1 function. 