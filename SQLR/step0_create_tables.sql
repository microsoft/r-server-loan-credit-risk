SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- Create empty tables Loan and Borrower to be filled with the raw data with PowerShell during Development/Modeling. 
DROP TABLE IF EXISTS [dbo].[Loan]
CREATE TABLE [dbo].[Loan](
	[loanId] [int] NOT NULL,
	[memberId] [int] NOT NULL,
	[date] [datetime],
	[purpose] [varchar](30),
    [isJointApplication] [char](1),
	[loanAmount] [float],
	[term] [varchar](10),
	[interestRate] [float],
	[monthlyPayment] [float],
	[grade] [varchar](2),
	[loanStatus] [varchar](60) NOT NULL
	)

CREATE CLUSTERED COLUMNSTORE INDEX loan_cci ON Loan WITH (DROP_EXISTING = OFF);

DROP TABLE IF EXISTS [dbo].[Borrower]
CREATE TABLE [dbo].[Borrower](
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

CREATE CLUSTERED COLUMNSTORE INDEX borrower_cci ON Borrower WITH (DROP_EXISTING = OFF);
