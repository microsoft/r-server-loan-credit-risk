-- Stored Procedure for the Production pipeline. 
-- Pre-requisites: 
-- 1) The data should be already loaded with PowerShell into Loan_Prod and Borrower_Prod.
-- 2) The stored procedures should be defined. Open the .sql files for steps 1,2,3, 4 and run "Execute". 
-- 3) You should connect to the database in the SQL Server of the DSVM with:
-- - Server Name: localhost
-- - username: rdemo (if you did not change it)
-- - password: D@tascience (if you did not change it)


-- Set the working database to the one where you created the stored procedures.
Use Loans_Prod
GO

-- @loan_input: specify the name of the table holding the raw data set about loans for Production.
-- @borrower_input: specify the name of the table holding the raw data set about borrowers for Production.
-- @dev_db: specify the name of the development database holding the Stats, Models, ColInfo, Scores_Average, and Operational_Scores tables. 

DROP PROCEDURE IF EXISTS [dbo].[prod_loan]
GO

CREATE PROCEDURE [dbo].[prod_loan]  @loan_input varchar(max) = 'Loan_Prod', @borrower_input varchar(max) = 'Borrower_Prod', @dev_db varchar(max) = 'Loan'								  
AS
BEGIN

-- Step 0: Copy the Stats, Models, Colum_Info, Scores_Average, and Operational_Metrics tables to the production database (Only used for Production). 
	exec [dbo].[copy_modeling_tables] @dev_db = @dev_db 

-- Step 1: Preprocessing. 

-- Join the two raw tables. 
    exec [dbo].[merging] @loan_input = @loan_input, @borrower_input = @borrower_input  , @output = 'Merged_Prod'

-- Replace the missing values with the mode and the mean. 
	exec [dbo].[fill_NA_mode_mean]  @input = 'Merged_Prod',  @output = 'Merged_Cleaned_Prod'

-- Step 2: Feature Engineering. 
    exec [dbo].[feature_engineering]  @input = 'Merged_Cleaned_Prod', @output  = 'Merged_Features_Prod'

-- Step 3: Scoring.
	DECLARE @query_string nvarchar(max)
	SET @query_string ='SELECT * FROM Merged_Features_Prod' 

	exec [dbo].[score] @inquery = @query_string, @output = 'Predictions_Logistic_Prod'  

-- Step 4: Score transformation.  
    exec [dbo].[apply_score_transformation] @predictions_table = 'Predictions_Logistic_Prod' , @output = 'Scores_Prod'

-- Drop the is_bad column since it is unknown for Production and has been artificially created during the process.  
    ALTER TABLE Scores_Prod DROP COLUMN isBad;

END
GO
;

