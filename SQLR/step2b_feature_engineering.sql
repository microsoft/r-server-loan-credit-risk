SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- Stored Procedure to compute or specify the bins to be used to bucket the data. This is done during the deployment pipeline. The same bins will be used for Production. 
-- You can manually modify the bins we specified by hand in the script. 

DROP PROCEDURE IF EXISTS [dbo].[compute_bins]  
GO

CREATE PROCEDURE [compute_bins] @inquery nvarchar(max) = N'SELECT Merged_Cleaned.*, isBad = CASE WHEN loanStatus IN (''Current'') THEN ''0'' ELSE ''1'' END
                                                           FROM  Merged_Cleaned JOIN Hash_Id 
														   ON Merged_Cleaned.loanId = Hash_Id.loanId
                                                           WHERE hashCode <= 70'
AS 
BEGIN

	-- Create an empty table to be filled with the serialized cutoffs. 
    DROP TABLE if exists  [dbo].[Bins]
	CREATE TABLE [dbo].[Bins](
		[id] [varchar](200) NOT NULL, 
	    [value] [varbinary](max), 
			CONSTRAINT unique_id UNIQUE(id)
		) 
		

	-- Get the database name.
	DECLARE @database_name varchar(max) = db_name();

	-- The input is the training set to which we append the label isBad (because the bins are computed through Conditional Inference Trees).
	-- Compute, define and serialize the bins. 
	EXECUTE sp_execute_external_script @language = N'R',
	                                   @input_data_1 = @inquery,
     					               @script = N' 

########################################################################################################################################## 
## Setting up
########################################################################################################################################## 
# Define the connection string
connection_string <- paste("Driver=SQL Server;Server=localhost;Database=", database_name, ";Trusted_Connection=true;", sep="")

# Set the type of the label to numeric. 
InputDataSet$isBad <- as.numeric(as.character(InputDataSet$isBad))

########################################################################################################################################## 
## Specify the default bins
########################################################################################################################################## 
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
  
########################################################################################################################################## 
## Compute bins with smbinning
########################################################################################################################################## 
# Function to compute smbinning on every variable. 
compute_bins <- function(name, data){
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
bins_smb <- rxExec(compute_bins, name = rxElemArg(names(bins)), data = InputDataSet)
names(bins_smb) <- names(bins)
  
# Fill bins with bins obtained in bins_smb with smbinning. 
## We replace the default values in bins if and only if smbinning returned a non NULL result. 
  for(name in names(bins)){
    if (!is.null(bins_smb[[name]])){ 
      bins[[name]] <- bins_smb[[name]]
    }
  }

########################################################################################################################################## 
## Save the bins in SQL Server 
########################################################################################################################################## 
# Open an Odbc connection with SQL Server. 
OdbcModel <- RxOdbcData(table = "Bins", connectionString = connection_string) 
rxOpen(OdbcModel, "w") 

# Write the model to SQL.  
rxWriteObject(OdbcModel, "Bin Info", bins) 
 
'
, @params = N'@database_name varchar(max)'
, @database_name = @database_name 
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

	-- Perform the feature engineering. 
	EXECUTE sp_execute_external_script @language = N'R',
     					               @script = N'
		
##########################################################################################################################################
##	Connection String
##########################################################################################################################################							   
# Define the connection string
connection_string <- paste("Driver=SQL Server;Server=localhost;Database=", database_name, ";Trusted_Connection=true;", sep="")

########################################################################################################################################## 
## Get the bins
########################################################################################################################################## 
# Create an Odbc connection with SQL Server using the name of the table storing the bins. 
OdbcModel <- RxOdbcData(table = "Bins", connectionString = connection_string) 

# Read the model from SQL.  
bins <- rxReadObject(OdbcModel, "Bin Info") 

##########################################################################################################################################
##	Feature Engineering
##########################################################################################################################################		
# Function to bucketize numeric variables. It will be wrapped into rxDataStep. 
  bucketize <- function(data) { 
    for(name in  names(b) { 
      name2 <- paste(name, "Bucket", sep = "") 
      data[[name2]] <- as.character(as.numeric(cut(data[[name]], c(-Inf, b[[name]], Inf)))) 
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
           transformFunc = bucketize,
           transformObjects =  list(
             b = bins),
	       transforms = list(
             isBad = ifelse(loanStatus %in% c("Current"), "0", "1") 
            ))
 '
 , @params = N'@input varchar(max), @output varchar(max), @database_name varchar(max)'
 , @input = @input
 , @output = @output 
 , @database_name = @database_name 

  -- Set loanId as the primary key. 
DECLARE @sql1 nvarchar(max);
SELECT @sql1 = N'
ALTER TABLE ' + @output + ' ALTER COLUMN [loanId] INTEGER NOT NULL'
EXEC sp_executesql @sql1

DECLARE @sql2 nvarchar(max);
SELECT @sql2 = N'
ALTER TABLE ' + @output + ' ADD CONSTRAINT [PK_Features] PRIMARY KEY([loanId])'
EXEC sp_executesql @sql2
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
		[id] [varchar](200) NOT NULL, 
	    [value] [varbinary](max), 
			CONSTRAINT unique_id2 UNIQUE(id)
		) 

	-- Get the database name.
	DECLARE @database_name varchar(max) = db_name()

    -- Serialize the column information. 
	EXECUTE sp_execute_external_script @language = N'R',
     					               @script = N' 
########################################################################################################################################## 
## Setting up
########################################################################################################################################## 
# Define the connection string
connection_string <- paste("Driver=SQL Server;Server=localhost;Database=", database_name, ";Trusted_Connection=true;", sep="")

# Point to the input data set.
Merged_Features_sql <- RxSqlServerData(sqlQuery = sprintf( "SELECT *  FROM [%s]", input),
					                   connectionString = connection_string, 
					                   stringsAsFactors = T)

########################################################################################################################################## 
## Get the variable information
########################################################################################################################################## 
column_info <- rxCreateColInfo(Merged_Features_sql, sortLevels = TRUE)

########################################################################################################################################## 
## Save the column info to SQL Server 
########################################################################################################################################## 
# Open an Odbc connection with SQL Server. 
OdbcModel <- RxOdbcData(table = "Column_Info", connectionString = connection_string) 
rxOpen(OdbcModel, "w") 

# Write the model to SQL.  
rxWriteObject(OdbcModel, "Column Info", column_info) 

'
, @params = N'@input varchar(max), @database_name varchar(max)'
, @input = @input
, @database_name = @database_name 
;
END
GO




