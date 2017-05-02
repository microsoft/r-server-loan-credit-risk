SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- Create empty tables Loan_Prod and Borrower_Prod to be filled with the new data with PowerShell during Production. 
DROP TABLE IF EXISTS [dbo].[Loan_Prod]
CREATE TABLE [dbo].[Loan_Prod](
	[loanId] [int] NOT NULL,
	[memberId] [int] NOT NULL,
    [date] [datetime],
	[purpose] [varchar](30),
    [isJointApplication] [char](1),
	[loanAmount] [float],
	[term] [varchar](10),
	[interestRate] [float],
	[monthlyPayment] [float],
	[grade] [varchar](2)
	)

CREATE CLUSTERED COLUMNSTORE INDEX loanprod_cci ON Loan_Prod WITH (DROP_EXISTING = OFF);

DROP TABLE IF EXISTS [dbo].[Borrower_Prod]
CREATE TABLE [dbo].[Borrower_Prod](
	[memberId] [int] NOT NULL,
	[residentialState] [varchar](2),
	[yearsEmployment] [varchar](10),
	[homeOwnership] [varchar](10),
	[annualIncome] [float],
	[incomeVerified] [char](1),
	[dtiRatio] [float],
	[lengthCreditHistory] [int],
	[numTotalCreditLines] [int],
	[numOpenCreditLines] [int],
	[numOpenCreditLines1Year] [int],
	[revolvingBalance] [float],
	[revolvingUtilizationRate] [float],
	[numDerogatoryRec] [int],
	[numDelinquency2Years] [int],
	[numChargeoff1year] [int],
	[numInquiries6Mon] [int]	
	)

CREATE CLUSTERED COLUMNSTORE INDEX borrowerprod_cci ON Borrower_Prod WITH (DROP_EXISTING = OFF);

-- Copy the Stats, Model, Bins, Column_Info, Scores_Average, and Operational_Scores tables to the Production database (Only used for Production). 
-- @dev_db: specify the name of the development database holding those tables. 

DROP PROCEDURE IF EXISTS [dbo].[copy_modeling_tables]
GO

CREATE PROCEDURE [copy_modeling_tables]  @dev_db varchar(max) = 'Loan'
AS
BEGIN
	-- Only copy deployment tables if the production and the deployment databases are different. 
	DECLARE @database_name varchar(max) = db_name() 
	IF(@database_name <> @dev_db )
	BEGIN 

		-- Copy the Stats table into the production database. 
		 DROP TABLE IF EXISTS [dbo].[Stats]
		 DECLARE @sql1 nvarchar(max);
			SELECT @sql1 = N'
			SELECT *
			INTO [dbo].[Stats]
			FROM ['+ @dev_db + '].[dbo].[Stats]';
			EXEC sp_executesql @sql1;

		-- Copy the Models table into the production database. 
		 DROP TABLE IF EXISTS [dbo].[Model]
		 DECLARE @sql2 nvarchar(max);
			SELECT @sql2 = N'
			SELECT *
			INTO [dbo].[Model]
			FROM ['+ @dev_db + '].[dbo].[Model]';
			EXEC sp_executesql @sql2;

		-- Copy the Bins table into the production database. 
		 DROP TABLE IF EXISTS [dbo].[Bins]
		 DECLARE @sql3 nvarchar(max);
			SELECT @sql3 = N'
			SELECT *
			INTO [dbo].[Bins]
			FROM ['+ @dev_db + '].[dbo].[Bins]';
			EXEC sp_executesql @sql3;

		-- Copy the Column_Info table into the production database. 
		 DROP TABLE IF EXISTS [dbo].[Column_Info]
		 DECLARE @sql4 nvarchar(max);
			SELECT @sql4 = N'
			SELECT *
			INTO [dbo].[Column_Info]
			FROM ['+ @dev_db + '].[dbo].[Column_Info]';
			EXEC sp_executesql @sql4;

		-- Copy the Scores_Average table into the production database. 
		 DROP TABLE IF EXISTS [dbo].[Scores_Average]
		 DECLARE @sql5 nvarchar(max);
			SELECT @sql5 = N'
			SELECT *
			INTO [dbo].[Scores_Average]
			FROM ['+ @dev_db + '].[dbo].[Scores_Average]';
			EXEC sp_executesql @sql5;

		-- Copy the Operational_Metrics table into the production database. 
		 DROP TABLE IF EXISTS [dbo].[Operational_Metrics]
		 DECLARE @sql6 nvarchar(max);
			SELECT @sql6 = N'
			SELECT *
			INTO [dbo].[Operational_Metrics]
			FROM ['+ @dev_db + '].[dbo].[Operational_Metrics]';
			EXEC sp_executesql @sql6;
	END;
END
GO
;


