SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- Stored Procedure to compute or specify the bins to be used to bucket the data. This is done during the deployment pipeline. The same bins will be used for Production. 
-- You can manually modify the bins we specified by hand in the script. 

DROP PROCEDURE IF EXISTS [dbo].[compute_bins]  
GO

CREATE PROCEDURE [compute_bins] @inquery nvarchar(max) = N'SELECT *, isBad = CASE WHEN loanStatus IN (''Current'') THEN ''0'' ELSE ''1'' END
                                                           FROM  Merged_Cleaned WHERE loanId IN (SELECT loanId from Train_Id)'
AS 
BEGIN
	-- Create an empty table to store the serialized bins information. 
	DROP TABLE IF EXISTS [dbo].[Bins]
	CREATE TABLE [dbo].[Bins](
		[binsInfo] [varbinary](max) NOT NULL
		)

	-- The input is the training set to which we append the label isBad (because the bins are computed through Conditional Inference Trees).
	-- Compute, define and serialize the bins. 
	INSERT INTO Bins
	EXECUTE sp_execute_external_script @language = N'R',
	                                   @input_data_1 = @inquery,
     					               @script = N' 

  # Names of the variables for which we are going to look for the bins with smbinning. 
  smb_buckets_names <- c("loanAmount", "interestRate", "monthlyPayment", "annualIncome", "dtiRatio", "lengthCreditHistory",
                         "numTotalCreditLines", "numOpenCreditLines", "numOpenCreditLines1Year", "revolvingBalance",
                         "revolvingUtilizationRate", "numDerogatoryRec", "numDelinquency2Years", "numChargeoff1year", 
                         "numInquiries6Mon")
  
  # Using the smbinning has some limitations, such as: 
  # - The variable should have more than 10 unique values. 
  # - If no significant splits are found, it does not output bins. 
  # For this reason, we manually specify default bins based on an analysis of the variables distributions or smbinning on a larger data set. 
  # We then overwrite them with smbinning when it output bins. 
  
  b <- list()
  
  # Default cutoffs for bins:
  ## EXAMPLE: If the cutoffs are (c1, c2, c3),
  ## Bin 1 = ]- inf, c1], Bin 2 = ]c1, c2], Bin 3 = ]c2, c3], Bin 4 = ]c3, + inf] 
  ## c1 and c3 are NOT the minimum and maximum found in the training set. 
  b$loanAmount <- c(14953, 18951, 20852, 22122, 24709, 28004)
  b$interestRate <- c(7.17, 10.84, 12.86, 14.47, 15.75, 18.05)
  b$monthlyPayment <- c(382, 429, 495, 529, 580, 649, 708, 847)
  b$annualIncome <- c(49402, 50823, 52089, 52885, 53521, 54881, 55520, 57490)
  b$dtiRatio <- c(9.01, 13.42, 15.92, 18.50, 21.49, 22.82, 24.67)
  b$lengthCreditHistory <- c(8)
  b$numTotalCreditLines <- c(1, 2)
  b$numOpenCreditLines <- c(3, 5)
  b$numOpenCreditLines1Year <- c(3, 4, 5, 6, 7, 9)
  b$revolvingBalance <- c(11912, 12645, 13799, 14345, 14785, 15360, 15883, 16361, 17374, 18877)
  b$revolvingUtilizationRate <- c(49.88, 60.01, 74.25, 81.96)
  b$numDerogatoryRec <- c(0, 1)
  b$numDelinquency2Years <- c(0)
  b$numChargeoff1year <- c(0)
  b$numInquiries6Mon <- c(0)
  
  # Set the type of the label to numeric. 
  InputDataSet$isBad <- as.numeric(as.character(InputDataSet$isBad))
  
  # Function to compute smbinning on every variable. 
  bins <- function(name, data){
    library(smbinning)
    output <- smbinning(data, y = "isBad", x = name, p = 0.05)
    if (class(output) == "list"){ # case where the binning was performed and returned bins.
      cuts <- output$cuts  
      return (cuts)
    }
  }
  
  # We apply it in parallel accross cores with rxExec and the compute context set to Local Parallel.
  ## 3 cores will be used here so the code can run on servers with smaller RAM. 
  ## You can increase numCoresToUse below in order to speed up the execution if using a larger server.
  ## numCoresToUse = -1 will enable the use of the maximum number of cores.
  rxOptions(numCoresToUse = 3) # use 3 cores.
  rxSetComputeContext("localpar")
  q <- rxExec(bins, name = rxElemArg(smb_buckets_names), data = InputDataSet)
  names(q) <- smb_buckets_names
  
  # Fill b with bins obtained in q with smbinning. 
  ## We replace the default values in b if and only if: 
  ## - smbinning returned a non NULL result. 
  ## - there is no repetition in the bins provided by smbinning. 
  for(name in smb_buckets_names){
    if (!is.null(q[[name]]) & (length(unique(q[[name]])) == length(q[[name]]))){ 
      b[[name]] <- q[[name]]
    }
  }
 
OutputDataSet <- data.frame(payload = as.raw(serialize(b, connection=NULL)))
'
;
END
GO


-- Stored procedure for feature engineering.
-- We create the target variable based on loanStatus, and we bucketize the numeric variables (some based on smbinning and some on manually defined bins).

-- @input: specify the name of the cleaned View to be featurized by this SP. 
-- @output: specify the Table that will hold the featurized data. 



DROP PROCEDURE IF EXISTS [dbo].[feature_engineering]
GO

CREATE PROCEDURE [dbo].[feature_engineering]  @input varchar(max), @output varchar(max)
AS
BEGIN 

	--	Get the current database name and the Bins information.
	DECLARE @database_name varchar(max) = db_name();
	DECLARE @b varbinary(max) = (select * from [dbo].[Bins]);

	-- Perform the feature engineering. 
	EXECUTE sp_execute_external_script @language = N'R',
     					               @script = N'
		
##########################################################################################################################################
##	Setup. 
##########################################################################################################################################							   
# Define the connection string
connection_string <- paste("Driver=SQL Server;Server=localhost;Database=", database_name, ";Trusted_Connection=true;", sep="")

# Get the bins.
b <- unserialize(b)

##########################################################################################################################################
##	Feature Engineering. 
##########################################################################################################################################		

# Names of the variables to be bucketed. 
buckets_names <- c("loanAmount", "interestRate", "monthlyPayment", "annualIncome", "dtiRatio", "lengthCreditHistory",
                   "numTotalCreditLines", "numOpenCreditLines", "numOpenCreditLines1Year", "revolvingBalance",
                   "revolvingUtilizationRate", "numDerogatoryRec", "numDelinquency2Years", "numChargeoff1year", 
                   "numInquiries6Mon")

# Function to bucketize numeric variables. It will be wrapped into rxDataStep. 
  Bucketize <- function(data) {
    data <- data.frame(data)
    for(name in  buckets_names2){
      # Deal with the last bin.
      name2 <- paste(name, "Bucket", sep = "")
      data[, name2] <- as.character(length(b2[[name]]) + 1)
      # Deal with the first bin. 
      rows <- which(data[, name] <= b2[[name]][[1]])
      data[rows, name2] <- "1"
      # Deal with the rest.
      if(length(b2[[name]]) > 1){
        for(i in seq(1, (length(b2[[name]]) - 1))){
          rows <- which(data[, name] <= b2[[name]][[i + 1]] & data[, name] > b2[[name]][[i]])
          data[rows, name2] <- as.character(i + 1)
         }
	  }
    }
    return(data)  
  }
  

# Perform feature engineering on the cleaned data set.
   
## Point to the cleaned data set. 
Merged_Cleaned_sql <- RxSqlServerData(table =  input, connectionString = connection_string)

## Point to the output data set. 
Merged_Features_sql <- RxSqlServerData(table =  output, connectionString = connection_string)
    
## Create buckets for various numeric variables with the function Bucketize. 
## We also create the target variable, is_bad, based on loan_status.
    
rxDataStep(inData = Merged_Cleaned_sql,
           outFile = Merged_Features_sql, 
           overwrite = TRUE, 
           transformFunc = Bucketize,
           transformObjects =  list(
             b2 = b, buckets_names2 = buckets_names),
	       transforms = list(
             isBad = ifelse(loanStatus %in% c("Current"), "0", "1") 
            ))
 '
 , @params = N'@input varchar(max), @output varchar(max), @database_name varchar(max), @b varbinary(max)'
 , @input = @input
 , @output = @output 
 , @database_name = @database_name 
 , @b = @b
;
END
GO

-- Stored Procedure to get the column information (variable names, types, and levels for factors) from the data used during the deployment pipeline. 
-- @input: specify the name of the featurized data set.  

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

DROP PROCEDURE IF EXISTS [dbo].[get_column_info]  
GO

CREATE PROCEDURE [get_column_info] @input varchar(max)
AS 
BEGIN
	-- Create an empty table to store the serialized column information. 
	DROP TABLE IF EXISTS [dbo].[Column_Info]
	CREATE TABLE [dbo].[Column_Info](
		[info] [varbinary](max) NOT NULL
		)

	-- Serialize the column information. 
	DECLARE @database_name varchar(max) = db_name()
	INSERT INTO Column_Info
	EXECUTE sp_execute_external_script @language = N'R',
     					               @script = N' 

connection_string <- paste("Driver=SQL Server;Server=localhost;Database=", database_name, ";Trusted_Connection=true;", sep="");
Merged_Features_sql <- RxSqlServerData(sqlQuery = sprintf( "SELECT *  FROM [%s]", input),
					                   connectionString = connection_string, 
					                   stringsAsFactors = T)
OutputDataSet <- data.frame(payload = as.raw(serialize(rxCreateColInfo(Merged_Features_sql, sortLevels = T), connection = NULL)))
'
, @params = N'@input varchar(max), @database_name varchar(max)'
, @input = @input
, @database_name = @database_name 
;
END
GO

