##########################################################################################################################################
## This R script will do the following :
## 1. Create the label isBad based on the status of the loan. 
## 2. Split the cleaned data set into a Training and a Testing set. 
## 3. Bucketize all the numeric variables, based on Conditional Inference Trees, using the smbinning package on the Training set. 

## Input : Cleaned data set Merged_Cleaned.
## Output: Data set with new features Merged_Features. 

##########################################################################################################################################

## Function for feature engineering:

feature_engineer <- function()
{ 
  
  # Set the compute context to SQL.
  rxSetComputeContext(sql)
  
  # Load the smbinning package (install it if on your own machine). 
  if(!require(smbinning)){
    #install.packages("smbinning")
    library(smbinning)
  }
  
  # Point to the Input SQL table. 
  Merged_Cleaned_sql <- RxSqlServerData(table = "Merged_Cleaned", connectionString = connection_string)
  
  
  #############################################################################################################################################
  
  ## The block below will Create the label, isBad, based on the loanStatus variable. 
  
  ############################################################################################################################################
  print("Creating the label...")
  
  # Point to the Output SQL table:
  Merged_Labeled_sql <- RxSqlServerData(table = "Merged_Labeled", connectionString = connection_string)
  
  # Create the target variable, isBad, based on loanStatus.
  rxDataStep(inData = Merged_Cleaned_sql ,
             outFile = Merged_Labeled_sql, 
             overwrite = TRUE, 
             transforms = list(
               isBad = ifelse(loanStatus %in% c("Current"), "0", "1") 
             ))

  #############################################################################################################################################
  
  ## The block below will split the labeled data set into a Training and a Testing set.
  
  ############################################################################################################################################
  
  print("Randomly splitting into a training and a testing set...")
  
  # Create the Hash_Id table containing loanId hashed to integers. 
  # The advantage of using a hashing function for splitting is to permit repeatability of the experiment.  
  rxExecuteSQLDDL(outOdbcDS, sSQLString = "DROP TABLE if exists Hash_Id;")
  
  rxExecuteSQLDDL(outOdbcDS, sSQLString = 
    "SELECT loanId, ABS(CAST(CAST(HashBytes('MD5', CAST(loanId AS varchar(20))) AS VARBINARY(64)) AS BIGINT) % 100) AS hashCode  
    INTO Hash_Id
    FROM Merged_Labeled;")
  
  # Point to the training set. 
  Train_sql <- RxSqlServerData(sqlQuery = 
                               "SELECT *   
                                FROM Merged_Labeled 
                                WHERE loanId IN (SELECT loanId from Hash_Id WHERE hashCode <= 70)",
                               connectionString = connection_string)
  
  #############################################################################################################################################
  
  ## The block below will compute optimal bins for numeric variables using the smbinning package on the Training set. 
  
  ############################################################################################################################################
  
  # Compute the bins. 
  print("Computing the bins to be used to create buckets...")
 
  # Using the smbinning has some limitations, such as: 
  # - The variable should have more than 10 unique values. 
  # - If no significant splits are found, it does not output bins. 
  # For this reason, we manually specify default bins based on an analysis of the variables distributions or smbinning on a larger data set. 
  # We then overwrite them with smbinning when it output bins. 
  
  bins <- list()
  
  # Default cutoffs for bins:
  ## EXAMPLE: If the cutoffs are (c1, c2, c3),
  ## Bin 1 = ]- inf, c1], Bin 2 = ]c1, c2], Bin 3 = ]c2, c3], Bin 4 = ]c3, + inf] 
  ## c1 and c3 are NOT the minimum and maximum found in the training set. 
  bins$loanAmount <- c(14953, 18951, 20852, 22122, 24709, 28004)
  bins$interestRate <- c(7.17, 10.84, 12.86, 14.47, 15.75, 18.05)
  bins$monthlyPayment <- c(382, 429, 495, 529, 580, 649, 708, 847)
  bins$annualIncome <- c(49402, 50823, 52089, 52885, 53521, 54881, 55520, 57490)
  bins$dtiRatio <- c(9.01, 13.42, 15.92, 18.50, 21.49, 22.82, 24.67)
  bins$lengthCreditHistory <- c(8)
  bins$numTotalCreditLines <- c(1, 2)
  bins$numOpenCreditLines <- c(3, 5)
  bins$numOpenCreditLines1Year <- c(3, 4, 5, 6, 7, 9)
  bins$revolvingBalance <- c(11912, 12645, 13799, 14345, 14785, 15360, 15883, 16361, 17374, 18877)
  bins$revolvingUtilizationRate <- c(49.88, 60.01, 74.25, 81.96)
  bins$numDerogatoryRec <- c(0, 1)
  bins$numDelinquency2Years <- c(0)
  bins$numChargeoff1year <- c(0)
  bins$numInquiries6Mon <- c(0)

  # Import the training set to be able to apply smbinning. 
  Train_df <- rxImport(Train_sql)
  
  # Set the type of the label to numeric. 
  Train_df$isBad <- as.numeric(as.character(Train_df$isBad))
  
  # Function to compute smbinning on every variable. 
  compute_bins <- function(name, data){
    library(smbinning)
    output <- smbinning(data, y = "isBad", x = name, p = 0.05)
    if (class(output) == "list"){ # case where the binning was performed and returned bins.
      cuts <- output$cuts  
      return(cuts)
    }
  }
  
  # We apply it in parallel accross cores with rxExec and the compute context set to Local Parallel.
  ## 3 cores will be used here so the code can run on servers with smaller RAM. 
  ## You can increase numCoresToUse below in order to speed up the execution if using a larger server.
  ## numCoresToUse = -1 will enable the use of the maximum number of cores.
  rxOptions(numCoresToUse = 3) # use 3 cores.
  rxSetComputeContext('localpar')
  q <- rxExec(compute_bins, name = rxElemArg(names(bins)), data = Train_df)
  names(q) <- names(bins)
  
  # Fill bins with bins obtained in q with smbinning. 
  ## We replace the default values in bins if and only if smbinning returned a non NULL result. 
  for(name in names(bins)){
    if (!is.null(q[[name]])){ 
      bins[[name]] <- q[[name]]
    }
  }
  
  # Save the bins to SQL for use in Production Stage. 
  
  ## Open an Odbc connection with SQL Server.
  OdbcModel <- RxOdbcData(table = "Bins", connectionString = connection_string)
  rxOpen(OdbcModel, "w")
  
  ## Drop the Bins table if it exists. 
  if(rxSqlServerTableExists(OdbcModel@table, OdbcModel@connectionString)) {
    rxSqlServerDropTable(OdbcModel@table, OdbcModel@connectionString)
  }
  
  ## Create an empty Bins table. 
  rxExecuteSQLDDL(OdbcModel, 
                  sSQLString = paste(" CREATE TABLE [", OdbcModel@table, "] (",
                                     "     [id] varchar(200) not null, ",
                                     "     [value] varbinary(max), ",
                                     "     constraint unique_id unique (id))",
                                     sep = "")
  )
  
  ## Write the model to SQL. 
  rxWriteObject(OdbcModel, "Bin Info", bins)
  
  ## Close the Obdc connection used. 
  rxClose(OdbcModel)
  
  # Set back the compute context to SQL.
  rxSetComputeContext(sql)
  
  #############################################################################################################################################
  
  ## The block below will bucketize variables based on the previously computed bins. 
  
  ############################################################################################################################################
  print("Bucketizing variables...")
  
  # Function to bucketize numeric variables. It will be wrapped into rxDataStep. 
  bucketize <- function(data) {
    for(name in  buckets_names) {
      # Deal with the last bin.
      name2 <- paste(name, "Bucket", sep = "")
      data[[name2]] <- as.character(as.numeric(cut(data[[name]], c(-Inf, b[[name]], Inf))))
    }
    return(data)
  }
  
  # Perform feature engineering on the cleaned data set.
   
    # Output:
    Merged_Features_sql <- RxSqlServerData(table = "Merged_Features", connectionString = connection_string)
    
    # Create buckets for various numeric variables with the function Bucketize. 
    rxDataStep(inData = Merged_Labeled_sql,
               outFile = Merged_Features_sql, 
               overwrite = TRUE, 
               transformFunc = bucketize,
               transformObjects =  list(
                b = bins, buckets_names = names(bins))
    )
    
  print("Step 2 Completed.")
  
} # end of step 2 function. 




