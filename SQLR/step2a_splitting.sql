SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- Stored Procedure to hash the loanId for splitting purposes.
-- The advantage of using a hashing function for splitting is to permit repeatability of the experiment.  
-- @input: specify the name of the cleaned data set. 

DROP PROCEDURE IF EXISTS [dbo].[splitting]
GO

CREATE PROCEDURE [splitting]  @input varchar(max)
AS
BEGIN
  DROP TABLE if exists [dbo].[Hash_Id]
  CREATE TABLE [dbo].[Hash_Id](
	[loanId] [int] NOT NULL Primary Key,
	[hashCode] [bigint] NOT NULL) 

  DECLARE @sql nvarchar(max);
  SET @sql = N'
  INSERT INTO Hash_Id
  SELECT loanId, ABS(CAST(CAST(HashBytes(''MD5'', CAST(loanId AS varchar(20))) AS VARBINARY(64)) AS BIGINT) % 100) AS hashCode
  FROM ' + @input;

  EXEC sp_executesql @sql


;
END
GO


