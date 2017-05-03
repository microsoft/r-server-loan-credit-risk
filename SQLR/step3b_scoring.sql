-- Stored Procedure to score a data set on the trained model stored in the Model table. 

-- @inquery: select the dataset to be scored (the testing set for Development, or the featurized data set for Production). 
-- @output: name of the table that will hold the predictions. 

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

DROP PROCEDURE IF EXISTS [dbo].[score]
GO

CREATE PROCEDURE [score] @inquery varchar(max),
						 @output varchar(max)

AS 
BEGIN

	--	Get the current database name.
	DECLARE @database_name varchar(max) = db_name();

	-- Compute the predictions. 
	EXECUTE sp_execute_external_script @language = N'R',
     					               @script = N' 

##########################################################################################################################################
##	Connection String
##########################################################################################################################################
# Define the connection string. 
connection_string <- paste("Driver=SQL Server;Server=localhost;Database=", database_name, ";Trusted_Connection=true;", sep="")

########################################################################################################################################## 
## Get the column information
########################################################################################################################################## 
# Create an Odbc connection with SQL Server using the name of the table storing the bins. 
OdbcModel <- RxOdbcData(table = "Column_Info", connectionString = connection_string) 

# Read the model from SQL.  
column_info <- rxReadObject(OdbcModel, "Column Info") 

########################################################################################################################################## 
## Get the trained model
########################################################################################################################################## 
# Create an Odbc connection with SQL Server using the name of the table storing the model. 
OdbcModel <- RxOdbcData(table = "Model", connectionString = connection_string) 

# Read the model from SQL.  
logistic_model <- rxReadObject(OdbcModel, "Logistic Regression")

# Set the Compute Context to SQL.
sql <- RxInSqlServer(connectionString = connection_string)
rxSetComputeContext(sql) 

##########################################################################################################################################
## Point to the data set to score and use the column_info list to specify the types of the features
##########################################################################################################################################
Test_sql <- RxSqlServerData(sqlQuery = sprintf("%s", inquery),
							connectionString = connection_string,
							colInfo = column_info)

##########################################################################################################################################
## Logistic Regression scoring
##########################################################################################################################################
# The prediction results are directly written to a SQL table.
if(length(logistic_model) > 0){

  Predictions_Logistic_sql <- RxSqlServerData(table = output, connectionString = connection_string, stringsAsFactors = T)

  rxPredict(logistic_model, 
            data = Test_sql, 
            outData = Predictions_Logistic_sql, 
            overwrite = T, 
            type = "response",
            extraVarsToWrite = c("isBad", "loanId"))
 }	 		   	   	   
'
, @params = N' @inquery nvarchar(max), @database_name varchar(max), @output varchar(max)' 
, @inquery = @inquery
, @database_name = @database_name
, @output = @output 
;
END
GO


