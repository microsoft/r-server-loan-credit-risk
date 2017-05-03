##########################################################################################################################################
## This R script will do the following:
## 1. Upload the 2 raw data sets Loan and Borrower from disk to the SQL Server.
## 2. Join the 2 tables into one.
## 3. Clean the merged data sets: replace NAs with the global mean (numeric variables) or global mode (character variables).

## Input : 2 Data Tables: Loan and Borrower.
## Output: Cleaned data set Merged_Cleaned.

##########################################################################################################################################

## Function of data processing:

# Loan: full path to the Loan table in .csv format.
# Borrower: full path to the Borrower table in .csv format.

data_process <- function(Loan, 
                         Borrower)
{ 
  
  # Set the compute context to local to upload data to SQL. 
  rxSetComputeContext('local')
  
  ##############################################################################################################################
  ## The block below will do the following:
  ## 1. Specify the column types of the input data sets
  ## 2. Upload the data sets to SQL Server with rxDataStep. 
  ##############################################################################################################################
  
  print("Uploading the data sets to SQL Server...")
  
  # Specify the desired column types. 
  # Character and Factor are converted to nvarchar(255), Integer to Integer and Numeric to Float. 
  column_types_loan <-  c(loanId = "integer",    
                          memberId = "integer",  
                          date = "character",
                          purpose = "character",
                          isJointApplication = "character",
                          loanAmount = "numeric",
                          term = "character",
                          interestRate = "numeric",
                          monthlyPayment = "numeric",
                          grade = "character",
                          loanStatus = "character")
                          
  column_types_borrower <- c(memberId = "integer",  
                             residentialState = "character",
                             yearsEmployment = "character",
                             homeOwnership = "character",
                             annualIncome = "numeric",
                             incomeVerified = "character",
                             dtiRatio = "numeric",
                             lengthCreditHistory = "integer",
                             numTotalCreditLines = "integer",
                             numOpenCreditLines = "integer",
                             numOpenCreditLines1Year = "integer",
                             revolvingBalance = "numeric",
                             revolvingUtilizationRate = "numeric",
                             numDerogatoryRec = "integer",
                             numDelinquency2Years = "integer",
                             numChargeoff1year = "integer",
                             numInquiries6Mon = "integer")
                             
  # Point to the input data sets while specifying the classes.
  Loan_text <- RxTextData(file = Loan, colClasses = column_types_loan)
  Borrower_text <- RxTextData(file = Borrower, colClasses = column_types_borrower)
  
  # Upload the data to SQL tables. 
  Loan_sql <- RxSqlServerData(table = "Loan", connectionString = connection_string)
  Borrower_sql <- RxSqlServerData(table = "Borrower", connectionString = connection_string)
  
  rxDataStep(inData = Loan_text, outFile = Loan_sql, overwrite = TRUE)
  rxDataStep(inData = Borrower_text, outFile = Borrower_sql, overwrite = TRUE)
  
  # Set the compute context to SQL. 
  rxSetComputeContext(sql)
  
  #############################################################################################################################################
  ## The block below will merge the two tables on member_id.
  ############################################################################################################################################
  print("Merging the 2 raw tables...")
  
  # Inner join of the raw tables Loan and Borrower and preprocess a few variables at the same time.
  rxExecuteSQLDDL(outOdbcDS, sSQLString = paste("DROP TABLE if exists Merged;"
                                                  , sep=""))
    
  rxExecuteSQLDDL(outOdbcDS, sSQLString = paste(
    "SELECT loanId, [date], purpose, isJointApplication, loanAmount, term, interestRate, monthlyPayment,
            grade, loanStatus, Borrower.*
     INTO Merged
     FROM Loan JOIN Borrower
     ON Loan.memberId = Borrower.memberId;"
      , sep=""))
  
  ############################################################################################################################################
  ## The block below will do the following:
  ## 1. Use rxSummary to get the summary statistics, and the names of the variables with missing values.
  ## 2. Compute the global means and modes of all the variables and load them to SQL.
  ############################################################################################################################################
  print("Computing summary statistics and looking for variables with missing values...")
  
  # Use rxSummary function to get the names of the variables with missing values.
  # Assumption: no NAs in the id variables (loan_id and member_id), target variable and date.
  # For rxSummary to give correct info on characters, stringsAsFactors = T should be used. 
  Merged_sql <- RxSqlServerData(table = "Merged", connectionString = connection_string, stringsAsFactors = T)
  colnames <- rxGetVarNames(Merged_sql)
  var <- colnames[!colnames %in% c("loanId", "memberId", "loanStatus", "date")]
  formula <- as.formula(paste("~", paste(var, collapse = "+")))
  summary <- rxSummary(formula, Merged_sql, byTerm = TRUE)
  
  # Get the variables types.
  categorical_all <- unlist(lapply(summary$categorical, FUN = function(x){colnames(x)[1]}))
  numeric_all <- setdiff(var, categorical_all)
  
  # Get the variables names with missing values. 
  var_with_NA <- summary$sDataFrame[summary$sDataFrame$MissingObs > 0, 1]
  categorical_NA <- intersect(categorical_all, var_with_NA)
  numeric_NA <- intersect(numeric_all, var_with_NA)

  # Compute the global means. 
  Summary_DF <- summary$sDataFrame
  Numeric_Means <- Summary_DF[Summary_DF$Name %in% numeric_all, c("Name", "Mean")]
  Numeric_Means$Mean  <- round(Numeric_Means$Mean) 
  
  # Compute the global modes. 
  ## Get the counts tables.
  Summary_Counts <- summary$categorical
  names(Summary_Counts) <- lapply(Summary_Counts, FUN = function(x){colnames(x)[1]})
  
  ## Compute for each count table the value with the highest count. 
  modes <- unlist(lapply(Summary_Counts, FUN = function(x){as.character(x[which.max(x[,2]),1])}), use.names = F)
  Categorical_Modes <- data.frame(Name = categorical_all, Mode = modes)
  
  # Set the compute context to local to export the summary statistics to SQL. 
  ## The schema of the Statistics table is adapted to the one created in the SQL code. 
  rxSetComputeContext('local')
  
  Numeric_Means$Mode <- NA
  Numeric_Means$type <- "float" 
  
  Categorical_Modes$Mean <- NA
  Categorical_Modes$type <- "char"
  
  Stats <- rbind(Numeric_Means, Categorical_Modes)[, c("Name", "type", "Mode", "Mean")]
  colnames(Stats) <- c("variableName", "type", "mode", "mean")
  
  # Save the statistics to SQL for Production use. 
  Stats_sql <- RxSqlServerData(table = "Stats", connectionString = connection_string)
  rxDataStep(inData = Stats, outFile = Stats_sql, overwrite = TRUE)
  
  # Set the compute context back to SQL. 
  rxSetComputeContext(sql)
  
  
  # If no missing values, we move the data to a new table Merged_Cleaned. 
  if(length(var_with_NA) == 0){
    print("No missing values: no treatment will be applied.")
   
     rxExecuteSQLDDL(outOdbcDS, sSQLString = paste("DROP TABLE if exists Merged_Cleaned;"
                                                  , sep=""))
    
     rxExecuteSQLDDL(outOdbcDS, sSQLString = paste(
      "SELECT * INTO Merged_Cleaned FROM Merged;"
      , sep=""))

  } else{    
     
     ############################################################################################################################################
     ## Replace missing values with the global mean (numeric) or mode (character). 
     ############################################################################################################################################
     
    # If there are missing values, we replace them with the mode or mean.    
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
    
    # Point to the input table. 
    Merged_sql <- RxSqlServerData(table = "Merged", connectionString = connection_string)
    
    # Point to the output (empty) table. 
    Merged_Cleaned_sql <- RxSqlServerData(table = "Merged_Cleaned", connectionString = connection_string)
    
    ## We drop the Merged_Cleaned view in case the SQL Stored Procedure was executed in the same database before. 
    rxExecuteSQLDDL(outOdbcDS, sSQLString = paste("IF OBJECT_ID ('Merged_Cleaned', 'V') IS NOT NULL DROP VIEW Merged_Cleaned;"
                                                  , sep=""))
      
    # Perform the data cleaning with rxDataStep. 
    rxDataStep(inData = Merged_sql, 
               outFile = Merged_Cleaned_sql, 
               overwrite = T, 
               transformFunc = Mean_Mode_Replace,
               transformObjects = list(num_with_NA = numeric_NA , num_NA_mean = numeric_NA_mean,
                                       cat_with_NA = categorical_NA, cat_NA_mode = categorical_NA_mode))  
    
    ## Check if data cleaned:
    ## summary_cleaned <- rxSummary(formula, Merged_Cleaned_sql, byTerm = TRUE)
    ## Summary_Cleaned_DF <- summary_cleaned$sDataFrame
    ## length(Summary_Cleaned_DF[Summary_Cleaned_DF$MissingObs > 0,2]) == 0

  } # end of case with missing variables. 
  
  print("Step 1 Completed.")
  
} # end of step 1 function. 