SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- Stored Procedure to join the 2 raw tables Loan and Borrower and create the raw data set.

-- @output: specify the name of the merged table.
-- @is_production is set to 1 for Production pipeline and to 0 for Modeling/Development. The Production data does not contain a loanStatus variable. 

DROP PROCEDURE IF EXISTS [dbo].[merging]
GO

CREATE PROCEDURE [dbo].[merging] @loan_input varchar(max), @borrower_input varchar(max), @output varchar(max)
AS
BEGIN

-- Drop the output table if it already exists. 
	DECLARE @sql1 nvarchar(max);
	SELECT @sql1 = N'
		DROP TABLE if exists ' + @output;
	EXEC sp_executesql @sql1

-- We create empty column loanStatus if it does not exist (typically for Production). 
	DECLARE @sql2 nvarchar(max);
	SELECT @sql2 = N'
	 IF NOT EXISTS( SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = ''' + @loan_input + '''  AND COLUMN_NAME = ''loanStatus'')
	 BEGIN 
		ALTER TABLE ' + @loan_input + ' ADD loanStatus varchar(60) NULL
	 END'; 
	EXEC sp_executesql @sql2

-- Perform the inner join.

	DECLARE @sql3 nvarchar(max);
	SELECT @sql3 = N'
		SELECT loanId, [date], purpose, isJointApplication, loanAmount, term, interestRate, monthlyPayment,
               grade, loanStatus, '+ @borrower_input + '.* 
	    INTO ' + @output + '
	    FROM ' + @loan_input + ' JOIN ' + @borrower_input + '
	    ON ' + @loan_input + '.memberId = ' + @borrower_input + '.memberId ';
	EXEC sp_executesql @sql3
;
END
GO

		
-- Stored Procedure to compute and store data statistics that will be used during production for preprocessing.
-- @input: specify the name of the raw data set of the Development/Modeling pipeline for which you want to store Statistics. 

DROP PROCEDURE IF EXISTS [dbo].[compute_stats]
GO

CREATE PROCEDURE [compute_stats]  @input varchar(max) = 'Loan_Borrower'
AS
BEGIN

	-- Create an empty table that will store the Statistics. 
	DROP TABLE if exists [dbo].[Stats]
	CREATE TABLE [dbo].[Stats](
		[variableName] [varchar](30) NOT NULL,
		[type] [varchar](30) NOT NULL,
		[mode] [varchar](30) NULL, 
		[mean] [float] NULL
	)

	-- Get the names and variable types of the columns to analyze.
		DECLARE @sql nvarchar(max);
		SELECT @sql = N'
		INSERT INTO Stats(variableName, type)
		SELECT *
		FROM (SELECT COLUMN_NAME as variableName, DATA_TYPE as type
			  FROM INFORMATION_SCHEMA.COLUMNS
	          WHERE TABLE_NAME = ''' + @input + ''' 
			  AND COLUMN_NAME NOT IN (''loanId'', ''memberId'', ''loanStatus'', ''date'')) as t ';
		EXEC sp_executesql @sql;

	-- Loops to compute the Mode for categorical variables.
		DECLARE @name1 NVARCHAR(100)
		DECLARE @getname1 CURSOR

		SET @getname1 = CURSOR FOR
		SELECT variableName FROM [dbo].[Stats] WHERE type IN('varchar', 'nvarchar', 'int', 'char')
	
		OPEN @getname1
		FETCH NEXT
		FROM @getname1 INTO @name1
		WHILE @@FETCH_STATUS = 0
		BEGIN	

			DECLARE @sql1 nvarchar(max);
			SELECT @sql1 = N'
			UPDATE Stats
			SET Stats.mode = T.mode
			FROM (SELECT TOP(1) ' + @name1 + ' as mode, count(*) as cnt
						 FROM ' + @input + ' 
						 GROUP BY ' + @name1 + ' 
						 ORDER BY cnt desc) as T
			WHERE Stats.variableName =  ''' + @name1 + '''';
			EXEC sp_executesql @sql1;

			FETCH NEXT
		    FROM @getname1 INTO @name1
		END
		CLOSE @getname1
		DEALLOCATE @getname1
		
	-- Loops to compute the Mean for continuous variables.
		DECLARE @name2 NVARCHAR(100)
		DECLARE @getname2 CURSOR

		SET @getname2 = CURSOR FOR
		SELECT variableName FROM [dbo].[Stats] WHERE type IN('float')
	
		OPEN @getname2
		FETCH NEXT
		FROM @getname2 INTO @name2
		WHILE @@FETCH_STATUS = 0
		BEGIN	

			DECLARE @sql2 nvarchar(max);
			SELECT @sql2 = N'
			UPDATE Stats
			SET Stats.mean = T.mean
			FROM (SELECT  AVG(' + @name2 + ') as mean
				  FROM ' + @input + ') as T
			WHERE Stats.variableName =  ''' + @name2 + '''';
			EXEC sp_executesql @sql2;

			FETCH NEXT
		    FROM @getname2 INTO @name2
		END
		CLOSE @getname2
		DEALLOCATE @getname2

END
GO
;

-- Missing value treatment: NULL is replaced with the mode (categorical variables) or mean (float variables) 
-- Assumption: loanId, memberId, loanStatus and date have no missing values. 

-- @input: specify the name of the raw data set (merged tables) to be cleaned. 
-- @output: specify the name of the View that will hold the cleaned data set.


DROP PROCEDURE IF EXISTS [dbo].[fill_NA_mode_mean]
GO

CREATE PROCEDURE [fill_NA_mode_mean]  @input varchar(max), @output varchar(max)
AS
BEGIN

    -- Drop the output table if it has been created in R in the same database. 
    DECLARE @sql0 nvarchar(max);
	SELECT @sql0 = N'
	IF OBJECT_ID (''' + @output + ''', ''U'') IS NOT NULL  
	DROP TABLE ' + @output ;  
	EXEC sp_executesql @sql0

	-- Create a View with the raw merged data. 
	DECLARE @sqlv1 nvarchar(max);
	SELECT @sqlv1 = N'
	IF OBJECT_ID (''' + @output + ''', ''V'') IS NOT NULL  
	DROP VIEW ' + @output ;  
	EXEC sp_executesql @sqlv1

	DECLARE @sqlv2 nvarchar(max);
	SELECT @sqlv2 = N'
		CREATE VIEW ' + @output + '
		AS
		SELECT *
	    FROM ' + @input;
	EXEC sp_executesql @sqlv2

    -- Loops to fill missing values for the categorical variables with the mode. 
	DECLARE @name1 NVARCHAR(100)
	DECLARE @getname1 CURSOR

	SET @getname1 = CURSOR FOR
	SELECT variableName FROM  [dbo].[Stats] WHERE [type] IN ('varchar', 'nvarchar', 'int', 'char')

	OPEN @getname1
	FETCH NEXT
	FROM @getname1 INTO @name1
	WHILE @@FETCH_STATUS = 0
	BEGIN	

		-- Check whether the variable contains a missing value. We perform cleaning only for variables containing NULL. 
		DECLARE @missing1 varchar(50)
		DECLARE @sql10 nvarchar(max);
		DECLARE @Parameter10 nvarchar(500);
		SELECT @sql10 = N'
			SELECT @missingOUT1 = missing
			FROM (SELECT count(*) - count(' + @name1 + ') as missing
			      FROM ' + @output + ') as t';
		SET @Parameter10 = N'@missingOUT1 varchar(max) OUTPUT';
		EXEC sp_executesql @sql10, @Parameter10, @missingOUT1=@missing1 OUTPUT;

		IF (@missing1 > 0)
		BEGIN 
			-- Replace categorical variables with the mode. 
			DECLARE @sql11 nvarchar(max)
			SET @sql11 = 
			'UPDATE ' + @output + '
			SET ' + @name1 + ' = ISNULL(' + @name1 + ', (SELECT mode FROM [dbo].[Stats] WHERE variableName = ''' + @name1 + '''))';
			EXEC sp_executesql @sql11;
		END;
		FETCH NEXT
		FROM @getname1 INTO @name1
	END
	CLOSE @getname1
	DEALLOCATE @getname1

    -- Loops to fill continous variables with the mean.  
	DECLARE @name2 NVARCHAR(100)
	DECLARE @getname2 CURSOR

	SET @getname2 = CURSOR FOR
	SELECT variableName FROM  [dbo].[Stats] WHERE type IN ('float')

	OPEN @getname2
	FETCH NEXT
	FROM @getname2 INTO @name2
	WHILE @@FETCH_STATUS = 0
	BEGIN	

		-- Check whether the variable contains a missing value. We perform cleaning only for variables containing NULL. 
		DECLARE @missing2 varchar(50)
		DECLARE @sql20 nvarchar(max);
		DECLARE @Parameter20 nvarchar(500);
		SELECT @sql20 = N'
			SELECT @missingOUT2 = missing
			FROM (SELECT count(*) - count(' + @name2 + ') as missing
			      FROM ' + @output + ') as t';
		SET @Parameter20 = N'@missingOUT2 varchar(max) OUTPUT';
		EXEC sp_executesql @sql20, @Parameter20, @missingOUT2=@missing2 OUTPUT;

		IF (@missing2 > 0)
		BEGIN 
			-- Replace numeric variables with '-1'. 
			DECLARE @sql21 nvarchar(max)
			SET @sql21 = 
			'UPDATE ' + @output + '
			SET ' + @name2 + ' = ISNULL(' + @name2 + ', (SELECT mean FROM [dbo].[Stats] WHERE variableName = ''' + @name2 + '''))';
			EXEC sp_executesql @sql21;
		END;
		FETCH NEXT
		FROM @getname2 INTO @name2
	END
	CLOSE @getname2
	DEALLOCATE @getname2
END
GO
;

