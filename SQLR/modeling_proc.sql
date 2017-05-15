-- Stored Procedure for the Modeling/Development pipeline. 
-- 1) The data should be already loaded with PowerShell into Loan and Borrower.
-- 2) The stored procedures should be defined. Open the .sql files for steps 1,2,3,4 and run "Execute". 
-- 3) You should connect to the database in the SQL Server of the DSVM with:
-- - Server Name: localhost
-- - username: rdemo (if you did not change it)
-- - password: D@tascience (if you did not change it)


-- Set the working database to the one where you created the stored procedures.
Use Loans
GO

-- @loan_input: specify the name of the table holding the raw data set about loans for Modeling.
-- @borrower_input: specify the name of the table holding the raw data set about borrowers for Modeling.

DROP PROCEDURE IF EXISTS [dbo].[dev_loan]
GO

CREATE PROCEDURE [dbo].[dev_loan]  @loan_input varchar(max) = 'Loan', @borrower_input varchar(max) = 'Borrower'						  
AS
BEGIN

-- Step 1: Preprocessing.
-- Join the two raw tables. 
    exec [dbo].[merging] @loan_input = @loan_input, @borrower_input = @borrower_input  , @output = 'Merged'

-- Compute the Statistics of the input table to be used for Production. 
	exec [dbo].[compute_stats]  @input = 'Merged'

-- Replace the missing values with the mode and the mean. 
	exec [dbo].[fill_NA_mode_mean]  @input = 'Merged',  @output = 'Merged_Cleaned'

-- Step 2a: Splitting into a training and testing set.
    exec [dbo].[splitting]  @input = 'Merged_Cleaned' 

-- Step 2b: Feature Engineering.
-- Compute the Bins to be used for feature engineering in Production. 
	exec [dbo].[compute_bins]  @inquery = 'SELECT Merged_Cleaned.*, isBad = CASE WHEN loanStatus IN (''Current'') THEN ''0'' ELSE ''1'' END
                                           FROM  Merged_Cleaned JOIN Hash_Id 
										   ON Merged_Cleaned.loanId = Hash_Id.loanId
                                           WHERE hashCode <= 70'

-- Feature Engineering. 
    exec [dbo].[feature_engineering]  @input = 'Merged_Cleaned', @output  = 'Merged_Features'

-- Getting column information. 
	exec [dbo].[get_column_info] @input = 'Merged_Features'

-- Step 3a: Training the logistic regression on the training set.
    exec [dbo].[train_model]  @dataset_name = 'Merged_Features'

-- Step 3b: Scoring the model on the test set.
	DECLARE @query_string nvarchar(max)
	SET @query_string ='
	SELECT * FROM Merged_Features WHERE loanId NOT IN (SELECT loanId FROM Hash_Id WHERE hashCode <= 70)' 

	exec [dbo].[score] @inquery = @query_string, @output = 'Predictions_Logistic'  

-- Step 3c: Evaluating the model on the test set. 
	exec [dbo].[evaluate]  @predictions_table = 'Predictions_Logistic'
	
-- Step 4: Operational Metrics.
-- Compute Operational Metrics. 
    exec [dbo].[compute_operational_metrics]  @predictions_table = 'Predictions_Logistic' 

-- Apply score transformation.
    exec [dbo].[apply_score_transformation] @predictions_table = 'Predictions_Logistic' , @output = 'Scores'


END
GO
;
