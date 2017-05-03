<#
.SYNOPSIS
Script to predict the probability of default or charge off for a loan, using SQL Server and MRS. 
#>

[CmdletBinding()]
param(

[parameter(Mandatory=$true,ParameterSetName = "LC")]
[ValidateNotNullOrEmpty()] 
[String]    
$is_production = "",

[parameter(Mandatory=$true,ParameterSetName = "LC")]
[ValidateNotNullOrEmpty()] 
[String]    
$ServerName = "",

[parameter(Mandatory=$true,ParameterSetName = "LC")]
[ValidateNotNullOrEmpty()]
[String]
$DBName = "",

[parameter(Mandatory=$true,ParameterSetName = "LC")]
[ValidateNotNullOrEmpty()]
[String]
$username ="",


[parameter(Mandatory=$true,ParameterSetName = "LC")]
[ValidateNotNullOrEmpty()]
[String]
$password ="",

[parameter(Mandatory=$true,ParameterSetName = "LC")]
[ValidateNotNullOrEmpty()]
[String]
$uninterrupted="",

[parameter(Mandatory=$false,ParameterSetName = "LC")]
[ValidateNotNullOrEmpty()]
[String]
$dataPath = "",

[parameter(Mandatory=$false,ParameterSetName = "LC")]
[ValidateNotNullOrEmpty()]
[String]
$development_db = "Loans"  #default set to Loans. 
)


$scriptPath = Get-Location
$filePath = $scriptPath.Path+ "\"

if ($dataPath -eq "")
{
$parentPath = Split-Path -parent $scriptPath
$dataPath = $parentPath + "/Data/"
}

##########################################################################
# Function wrapper to invoke SQL command
##########################################################################
function ExecuteSQL
{
param(
[String]
$sqlscript
)
    Invoke-Sqlcmd -ServerInstance $ServerName  -Database $DBName -Username $username -Password $password -InputFile $sqlscript -QueryTimeout 200000
}

##########################################################################
# Function wrapper to invoke SQL query
##########################################################################
function ExecuteSQLQuery
{
param(
[String]
$sqlquery
)
    Invoke-Sqlcmd -ServerInstance $ServerName  -Database $DBName -Username $username -Password $password -Query $sqlquery -QueryTimeout 200000
}

##########################################################################
# Check if the SQL server exists
##########################################################################
$query = "IF NOT EXISTS(SELECT * FROM sys.databases WHERE NAME = '$DBName') CREATE DATABASE $DBName"
Invoke-Sqlcmd -ServerInstance $ServerName -Username $username -Password $password -Query $query -ErrorAction SilentlyContinue
if ($? -eq $false)
{
    Write-Host -ForegroundColor Red "Failed the test to connect to SQL server: $ServerName database: $DBName !"
    Write-Host -ForegroundColor Red "Please make sure: `n`t 1. SQL Server: $ServerName exists;
                                     `n`t 2. SQL user: $username has the right credential for SQL server access."
    exit
}

$query = "USE $DBName;"
Invoke-Sqlcmd -ServerInstance $ServerName -Username $username -Password $password -Query $query 

##########################################################################

# Uninterrupted

##########################################################################
$startTime= Get-Date
Write-Host "Start time is:" $startTime  

if ($uninterrupted -eq 'y' -or $uninterrupted -eq 'Y')
{
    if($is_production -eq 'n' -or $is_production -eq 'N')
    {
    
##########################################################################
# Deployment Pipeline
##########################################################################
try{

        # create raw tables
        Write-Host -ForeGroundColor 'green' ("Create SQL tables.")
        $script = $filePath + "step0_create_tables.sql"
        ExecuteSQL $script
    
        Write-Host -ForeGroundColor 'green' ("Populate SQL tables.")
        $dataList = "Loan", "Borrower"
		
		# upload csv files into SQL tables
        foreach ($dataFile in $dataList)
        {
            $destination = $dataPath + $dataFile + ".csv"
            $tableName = $DBName + ".dbo." + $dataFile
            $tableSchema = $dataPath + $dataFile + ".xml"
            bcp $tableName format nul -c -x -f $tableSchema  -U $username -S $ServerName -P $password  -t ',' 
            bcp $tableName in $destination -t ',' -S $ServerName -f $tableSchema -F 2 -C "RAW" -b 50000 -U $username -P $password 
        }
    }
    catch
    {
        Write-Host -ForegroundColor DarkYellow "Exception in populating database tables:"
        Write-Host -ForegroundColor Red $Error[0].Exception 
        throw
    }

    $query = "ALTER TABLE Loan ALTER COLUMN [date] Date"
    ExecuteSQLQuery $query

    # create the stored procedures for preprocessing
    $script = $filepath + "step1_data_preprocessing.sql"
    ExecuteSQL $script

    # merge the tables.
    Write-Host -ForeGroundColor 'Cyan' (" Merging the Loan and Borrower tables...")
    $query = "EXEC merging 'Loan', 'Borrower', 'Merged'"
    ExecuteSQLQuery $query

    # compute statistics for production and faster NA replacement.
    Write-Host -ForeGroundColor 'Cyan' (" Computing statistics on the merged table...")
    $query = "EXEC compute_stats 'Merged'"
    ExecuteSQLQuery $query

    # execute the NA replacement
    Write-Host -ForeGroundColor 'Cyan' (" Replacing missing values with the mean and mode...")
    $query = "EXEC fill_NA_mode_mean 'Merged', 'Merged_Cleaned'"
    ExecuteSQLQuery $query

    # create the stored procedure for splitting into train and test data sets
    $script = $filepath + "step2a_splitting.sql"
    ExecuteSQL $script

    # execute the procedure
    $splitting_percent = 70
    Write-Host -ForeGroundColor 'Cyan' (" Splitting the data set...")
    $query = "EXEC splitting $splitting_percent, 'Merged_Cleaned'"
    ExecuteSQLQuery $query

    # create the stored procedure for feature engineering and getting column information.
    $script = $filepath + "step2b_feature_engineering.sql"
    ExecuteSQL $script

    # compute bins for production.
    Write-Host -ForeGroundColor 'Cyan' (" Computing bins for feature engineering...")
    $query = "EXEC compute_bins 'SELECT *, isBad = CASE WHEN loanStatus IN (''Current'') THEN ''0'' ELSE ''1'' END
                                 FROM  Merged_Cleaned WHERE loanId IN (SELECT loanId from Train_Id)'"
    ExecuteSQLQuery $query

    # execute the feature engineering
    Write-Host -ForeGroundColor 'Cyan' (" Computing new features...")
    $query = "EXEC feature_engineering 'Merged_Cleaned', 'Merged_Features'"
    ExecuteSQLQuery $query

    # get the column information
    Write-Host -ForeGroundColor 'Cyan' (" Getting column information...")
    $query = "EXEC get_column_info 'Merged_Features'"
    ExecuteSQLQuery $query

    # create the stored procedure for training 
    $script = $filepath + "step3a_training.sql"
    ExecuteSQL $script

    # execute the training 
    Write-Host -ForeGroundColor 'Cyan' (" Training the Logistic Regression...")
    $query = "EXEC train_model 'Merged_Features'"
    ExecuteSQLQuery $query
     
    # create the stored procedure for predicting 
    $script = $filepath + "step3b_scoring.sql"
    ExecuteSQL $script

    # execute the scoring 
    Write-Host -ForeGroundColor 'Cyan' (" Scoring the Logistic Regression...")
    $query = "EXEC score 'SELECT * FROM Merged_Features WHERE loanId NOT IN (SELECT loanId FROM Train_Id)', 'Predictions_Logistic'"
    ExecuteSQLQuery $query

    # create the stored procedure for evaluation
    $script = $filepath + "step3c_evaluating.sql"
    ExecuteSQL $script

    # execute the evaluation 
    Write-Host -ForeGroundColor 'Cyan' (" Evaluating the Logistic Regression...")
    $query = "EXEC evaluate 'Predictions_Logistic'"
    ExecuteSQLQuery $query  

    # create the stored procedure for operational metrics and scores transformation.
    $script = $filepath + "step4_operational_metrics.sql"
    ExecuteSQL $script

    # execute the script
    Write-Host -ForeGroundColor 'Cyan' (" Computing operational metrics...")
    $query = "EXEC compute_operational_metrics 'Predictions_Logistic'"
    ExecuteSQLQuery $query  

    Write-Host -ForeGroundColor 'Cyan' (" Apply score transformation...")
    $query = "EXEC apply_score_transformation 'Predictions_Logistic', 'Scores'"
    ExecuteSQLQuery $query  

    Write-Host -foregroundcolor 'green'("Loan Credit Risk Scoring Workflow Finished Successfully!")
    }

     if($is_production -eq 'y' -or $is_production -eq 'Y')
    {
##########################################################################
# Production Pipeline
##########################################################################
   try
       {

        # create raw tables
        Write-Host -ForeGroundColor 'green' ("Create SQL tables.")
        $script = $filePath + "create_tables_prod.sql"
        ExecuteSQL $script
    
        Write-Host -ForeGroundColor 'green' ("Populate SQL tables.")
        $dataList = "Loan_Prod", "Borrower_Prod"
		
		# upload csv files into SQL tables
        foreach ($dataFile in $dataList)
        {
            $destination = $dataPath + $dataFile + ".csv"
            $tableName = $DBName + ".dbo." + $dataFile
            $tableSchema = $dataPath + $dataFile + ".xml"
            bcp $tableName format nul -c -x -f $tableSchema  -U $username -S $ServerName -P $password  -t ',' 
            bcp $tableName in $destination -t ',' -S $ServerName -f $tableSchema -F 2 -C "RAW" -b 50000 -U $username -P $password 
        }
    }
    catch
    {
        Write-Host -ForegroundColor DarkYellow "Exception in populating database tables:"
        Write-Host -ForegroundColor Red $Error[0].Exception 
        throw
    }

    $query = "ALTER TABLE Loan_Prod ALTER COLUMN [date] Date"
    ExecuteSQLQuery $query

    # execute the stored procedure to get the Stats, Bins, Model, ColInfo, Scores_Average, and  tables. 
    Write-Host -ForeGroundColor 'Cyan' (" Getting the Stats, Bins, Model, Column Information, Scores_Average, and Operational_Metrics from the tables used during the development pipeline...")
    $query = "EXEC copy_modeling_tables $development_db"
    ExecuteSQLQuery $query

    # create the stored procedures for preprocessing
    $script = $filepath + "step1_data_preprocessing.sql"
    ExecuteSQL $script

    # merge the tables.
    Write-Host -ForeGroundColor 'Cyan' (" Merging the Loan and Borrower tables...")
    $query = "EXEC merging 'Loan_Prod', 'Borrower_Prod', 'Merged_Prod'"
    ExecuteSQLQuery $query

    # execute the NA replacement
    Write-Host -ForeGroundColor 'Cyan' (" Replacing missing values with the mean and mode...")
    $query = "EXEC fill_NA_mode_mean 'Merged_Prod', 'Merged_Cleaned_Prod'"
    ExecuteSQLQuery $query

    # create the stored procedure for feature engineering
    $script = $filepath + "step2b_feature_engineering.sql"
    ExecuteSQL $script

    # execute the feature engineering
    Write-Host -ForeGroundColor 'Cyan' (" Computing new features...")
    $query = "EXEC feature_engineering 'Merged_Cleaned_Prod', 'Merged_Features_Prod'"
    ExecuteSQLQuery $query
     
    # create the stored procedure for predicting 
    $script = $filepath + "step3b_scoring.sql"
    ExecuteSQL $script

    # execute the scoring 
    Write-Host -ForeGroundColor 'Cyan' (" Making predictions with the logistic regression...")
    $query = "EXEC score 'SELECT * FROM Merged_Features_Prod', 'Predictions_Logistic_Prod'  "
    ExecuteSQLQuery $query

    # create the stored procedure to transform scores
    $script = $filepath + "step4_operational_metrics.sql"
    ExecuteSQL $script

    # execute the script
    Write-Host -ForeGroundColor 'Cyan' (" Applying score transformation...")
    $query = "exec apply_score_transformation 'Predictions_Logistic_Prod', 'Scores_Prod'"
    ExecuteSQLQuery $query  

    # drop the isBad column since it is unknown for Production and has been artificially created during the process. 
    $query = "ALTER TABLE Scores_Prod DROP COLUMN isBad"
    ExecuteSQLQuery $query

    Write-Host -foregroundcolor 'green'("Loan Credit Risk Scoring Workflow Finished Successfully!")
    }

}

##########################################################################

# Interrupted

##########################################################################

if ($uninterrupted -eq 'n' -or $uninterrupted -eq 'N')
{

    if($is_production -eq 'n' -or $is_production -eq 'N')
    {
##########################################################################
# Deployment Pipeline
##########################################################################

##########################################################################
# Create input table and populate with data from csv file.
##########################################################################
Write-Host -foregroundcolor 'green' ("Step 0: Create and populate tables in Database" -f $dbname)
$ans = Read-Host 'Continue [y|Y], Exit [e|E], Skip [s|S]?'
if ($ans -eq 'E' -or $ans -eq 'e')
{
    return
} 
if ($ans -eq 'y' -or $ans -eq 'Y')
{
    try
    {
        # create raw tables
        Write-Host -ForeGroundColor 'green' ("Create SQL tables.")
        $script = $filePath + "step0_create_tables.sql"
        ExecuteSQL $script
    
        Write-Host -ForeGroundColor 'green' ("Populate SQL tables.")
        $dataList = "Loan", "Borrower"
		
		# upload csv files into SQL tables
        foreach ($dataFile in $dataList)
        {
            $destination = $dataPath + $dataFile + ".csv"
            $tableName = $DBName + ".dbo." + $dataFile
            $tableSchema = $dataPath + $dataFile + ".xml"
            bcp $tableName format nul -c -x -f $tableSchema  -U $username -S $ServerName -P $password  -t ',' 
            bcp $tableName in $destination -t ',' -S $ServerName -f $tableSchema -F 2 -C "RAW" -b 50000 -U $username -P $password 
        }
    }
    catch
    {
        Write-Host -ForegroundColor DarkYellow "Exception in populating database tables:"
        Write-Host -ForegroundColor Red $Error[0].Exception 
        throw
    }

    
    $query = "ALTER TABLE Loan ALTER COLUMN [date] Date"
    ExecuteSQLQuery $query
}

##########################################################################
# Create and execute the stored procedure for data processing
##########################################################################
Write-Host -foregroundcolor 'green' ("Step 1: Data Preprocessing")
$ans = Read-Host 'Continue [y|Y], Exit [e|E], Skip [s|S]?'
if ($ans -eq 'E' -or $ans -eq 'e')
{
    return
} 
if ($ans -eq 'y' -or $ans -eq 'Y')
{
    # create the stored procedures for preprocessing
    $script = $filepath + "step1_data_preprocessing.sql"
    ExecuteSQL $script

    # merge the tables.
    $output0 = Read-Host 'Merging the Loan and Borrower tables: Output table name? Type D or d for default (Merged)'
    if ($output0 -eq 'D' -or $output1 -eq 'd')
    {
        $output0 = 'Merged'
    }

    Write-Host -ForeGroundColor 'Cyan' (" Merging the Loan and Borrower tables...")
    $query = "EXEC merging 'Loan', 'Borrower', $output0"
    ExecuteSQLQuery $query

    # compute statistics for production and faster NA replacement.
    Write-Host -ForeGroundColor 'Cyan' (" Computing statistics on the merged table...")
    $query = "EXEC compute_stats $output0"
    ExecuteSQLQuery $query

    # execute the NA replacement
    $output1 = Read-Host 'Missing value treatment: Output table name? Type D or d for default (Merged_Cleaned)'
    if ($output1 -eq 'D' -or $output1 -eq 'd')
    {
        $output1 = 'Merged_Cleaned'
    }
   
    Write-Host -ForeGroundColor 'Cyan' (" Replacing missing values with mode and mean...")
    $query = "EXEC fill_NA_mode_mean $output0, $output1"
    ExecuteSQLQuery $query
    
}

if ($ans -eq 's' -or $ans -eq 'S')
{
 $output1 = 'Merged_Cleaned'
}

##########################################################################
# Create and execute the stored procedure to split data into train/test
##########################################################################
Write-Host -foregroundcolor 'green' ("Step 2a: Split the data into train and test")
$ans = Read-Host 'Continue [y|Y], Exit [e|E], Skip [s|S]?'
if ($ans -eq 'E' -or $ans -eq 'e')
{
    return
} 
if ($ans -eq 'y' -or $ans -eq 'Y')
{
    # create the stored procedure for splitting into train and test data sets
    $script = $filepath + "step2a_splitting.sql"
    ExecuteSQL $script

    # execute the procedure
    $splitting_percent = Read-Host 'Split Percent (e.g. Type 70 for 70% in training set) ?'
    Write-Host -ForeGroundColor 'Cyan' (" Splitting the data set...")
    $query = "EXEC splitting $splitting_percent, $output1"
    ExecuteSQLQuery $query
}

##########################################################################
# Create and execute the stored procedure for feature engineering
##########################################################################
Write-Host -foregroundcolor 'green' ("Step 2b: Feature Engineering")
$ans = Read-Host 'Continue [y|Y], Exit [e|E], Skip [s|S]?'
if ($ans -eq 'E' -or $ans -eq 'e')
{
    return
} 
if ($ans -eq 'y' -or $ans -eq 'Y')
{
    # create the stored procedure for feature engineering
    $script = $filepath + "step2b_feature_engineering.sql"
    ExecuteSQL $script

    # compute bins for production.
    Write-Host -ForeGroundColor 'Cyan' (" Computing bins for feature engineering...")
    $query = "EXEC compute_bins 'SELECT *, isBad = CASE WHEN loanStatus IN (''Current'') THEN ''0'' ELSE ''1'' END
                                 FROM $output1 WHERE loanId IN (SELECT loanId from Train_Id)'"
    ExecuteSQLQuery $query

    # execute the feature engineering
    $output2 = Read-Host 'Feature Engineering: Output table name? Type D or d for default (Merged_Features)'
    if ($output2 -eq 'D' -or $output2-eq 'd')
    {
        $output2 = 'Merged_Features'
    }
    Write-Host -ForeGroundColor 'Cyan' (" Computing new features...")
    $query = "EXEC feature_engineering $output1, $output2"
    ExecuteSQLQuery $query

    # get the column information
    Write-Host -ForeGroundColor 'Cyan' (" Getting column information...")
    $query = "EXEC get_column_info $output2"
    ExecuteSQLQuery $query
}

if ($ans -eq 's' -or $ans -eq 'S')
{
    $output2 = 'Merged_Features'
}


##########################################################################
# Create and execute the stored procedure for Training 
##########################################################################
Write-Host -foregroundcolor 'green' ("Step 3a: Model Training")
$ans = Read-Host 'Continue [y|Y], Exit [e|E], Skip [s|S]?'
if ($ans -eq 'E' -or $ans -eq 'e')
{
    return
} 
if ($ans -eq 'y' -or $ans -eq 'Y')
{
    # create the stored procedure for training 
    $script = $filepath + "step3a_training.sql"
    ExecuteSQL $script

    # execute the Logistic Regression training 
    Write-Host -ForeGroundColor 'Cyan' (" Training the Logistic Regression...")
    $query = "EXEC train_model $output2"
    ExecuteSQLQuery $query
   
}

##########################################################################
# Create and execute the stored procedure for scoring
##########################################################################

Write-Host -foregroundcolor 'green' ("Step 3b: Model Scoring")
$ans = Read-Host 'Continue [y|Y], Exit [e|E], Skip [s|S]?'
if ($ans -eq 'E' -or $ans -eq 'e')
{
    return
} 
if ($ans -eq 'y' -or $ans -eq 'Y')
{
    # create the stored procedure for predicting 
    $script = $filepath + "step3b_scoring.sql"
    ExecuteSQL $script

    # execute the scoring
    $output3 = Read-Host 'Output table name holding predictions? Type D or d for default (Predictions_Logistic)'
    if ($output3 -eq 'D' -or $output3 -eq 'd')
    {
       $output3 = 'Predictions_Logistic'
    }

    Write-Host -ForeGroundColor 'Cyan' (" Scoring the Logistic Regression...")  
    $query = "EXEC score 'SELECT * FROM $output2 WHERE loanId NOT IN (SELECT loanId FROM Train_Id)', $output3"
    ExecuteSQLQuery $query
         
}

if ($ans -eq 's' -or $ans -eq 'S')
{
   $output3 = 'Predictions_Logistic'
}


##########################################################################
# Create and execute the stored procedure for the model evaluation
##########################################################################

Write-Host -foregroundcolor 'green' ("Step 3c: Model Evaluation")
$ans = Read-Host 'Continue [y|Y], Exit [e|E], Skip [s|S]?'
if ($ans -eq 'E' -or $ans -eq 'e')
{
    return
} 
if ($ans -eq 'y' -or $ans -eq 'Y')
{
    # create the stored procedure for evaluation
    $script = $filepath + "step3c_evaluating.sql"
    ExecuteSQL $script

    # execute the evaluation
     Write-Host -ForeGroundColor 'Cyan' (" Evaluating the Logistic Regression...")
     $query = "EXEC evaluate $output3"
     ExecuteSQLQuery $query
}

##########################################################################
# Create and execute the stored procedure for operational metrics
##########################################################################

Write-Host -foregroundcolor 'green' ("Step 4: Operational Metrics Computation and Scores Transformation")
$ans = Read-Host 'Continue [y|Y], Exit [e|E], Skip [s|S]?'
if ($ans -eq 'E' -or $ans -eq 'e')
{
    return
} 
if ($ans -eq 'y' -or $ans -eq 'Y')
{
    # create the stored procedure for operational metrics and scores transformation.
    $script = $filepath + "step4_operational_metrics.sql"
    ExecuteSQL $script

    # execute the script
    Write-Host -ForeGroundColor 'Cyan' (" Computing operational metrics...")
    $query = "EXEC compute_operational_metrics $output3"
    ExecuteSQLQuery $query  

    $output4 = Read-Host 'Output table name holding final scores? Type D or d for default (Scores)'
    if ($output4 -eq 'D' -or $output4 -eq 'd')
    {
       $output4 = 'Scores'
    }

    Write-Host -ForeGroundColor 'Cyan' (" Applying score transformation...")
    $query = "EXEC apply_score_transformation $output3, $output4"
    ExecuteSQLQuery $query 
}


  Write-Host -foregroundcolor 'green'("Loan Credit Risk Scoring Workflow Finished Successfully!")
}

 if($is_production -eq 'y' -or $is_production -eq 'Y')
 {
##########################################################################
# Production Pipeline
##########################################################################

##########################################################################
# Create input table and populate with data from csv file.
##########################################################################
Write-Host -foregroundcolor 'green' ("Step 0: Create and populate tables in Database" -f $dbname)
$ans = Read-Host 'Continue [y|Y], Exit [e|E], Skip [s|S]?'
if ($ans -eq 'E' -or $ans -eq 'e')
{
    return
} 
if ($ans -eq 'y' -or $ans -eq 'Y')
{
    try
    {
         # create raw tables
        Write-Host -ForeGroundColor 'green' ("Create SQL tables.")
        $script = $filePath + "create_tables_prod.sql"
        ExecuteSQL $script
    
        Write-Host -ForeGroundColor 'green' ("Populate SQL tables.")
        $dataList = "Loan_Prod", "Borrower_Prod"
		
		# upload csv files into SQL tables
        foreach ($dataFile in $dataList)
        {
            $destination = $dataPath + $dataFile + ".csv"
            $tableName = $DBName + ".dbo." + $dataFile
            $tableSchema = $dataPath + $dataFile + ".xml"
            bcp $tableName format nul -c -x -f $tableSchema  -U $username -S $ServerName -P $password  -t ',' 
            bcp $tableName in $destination -t ',' -S $ServerName -f $tableSchema -F 2 -C "RAW" -b 50000 -U $username -P $password 
        }
    }
    catch
    {
        Write-Host -ForegroundColor DarkYellow "Exception in populating database tables:"
        Write-Host -ForegroundColor Red $Error[0].Exception 
        throw
    }

    $query = "ALTER TABLE Loan_Prod ALTER COLUMN [date] Date"
    ExecuteSQLQuery $query

    

  # execute the stored procedure to get the Stats, Bins, Model, ColInfo, Scores_Average, and Operational_Metrics tables. 
    $ans = Read-Host 'Name of the development database to get Stats, Bins, Model, Column Information, Scores_Average and Operational_Metrics from?'
    Write-Host -ForeGroundColor 'Cyan' (" Getting the Stats, Bins, Model, Column Information, Scores_Average, and Operational_Metrics from the tables used during the development pipeline...")
    $query = "EXEC copy_modeling_tables $ans "
    ExecuteSQLQuery $query

}

##########################################################################
# Create and execute the stored procedure for data processing
##########################################################################
Write-Host -foregroundcolor 'green' ("Step 1: Data Preprocessing")
$ans = Read-Host 'Continue [y|Y], Exit [e|E], Skip [s|S]?'
if ($ans -eq 'E' -or $ans -eq 'e')
{
    return
} 
if ($ans -eq 'y' -or $ans -eq 'Y')
{
    # create the stored procedures for preprocessing
    $script = $filepath + "step1_data_preprocessing.sql"
    ExecuteSQL $script

    # merge the tables.
    $output0 = Read-Host 'Merging the Loan_Prod and Borrower_Prod tables: Output table name? Type D or d for default (Merged_Prod)'
    if ($output0 -eq 'D' -or $output0 -eq 'd')
    {
        $output0 = 'Merged_Prod'
    }

    Write-Host -ForeGroundColor 'Cyan' (" Merging the Loan_Prod and Borrower_Prod tables...")
    $query = "EXEC merging 'Loan_Prod', 'Borrower_Prod', $output0"
    ExecuteSQLQuery $query

    # execute the NA replacement
    $output1 = Read-Host 'Missing value treatment: Output table name? Type D or d for default (Merged_Cleaned_Prod)'
    if ($output1 -eq 'D' -or $output1 -eq 'd')
    {
        $output1 = 'Merged_Cleaned_Prod'
    }

    Write-Host -ForeGroundColor 'Cyan' (" Replacing missing values with mode and mean...")
    $query = "EXEC fill_NA_mode_mean $output0, $output1"
    ExecuteSQLQuery $query

}

if ($ans -eq 's' -or $ans -eq 'S')
{
$output1 = 'Merged_Cleaned_Prod'
}

##########################################################################
# Create and execute the stored procedure for feature engineering
##########################################################################
Write-Host -foregroundcolor 'green' ("Step 2: Feature Engineering")
$ans = Read-Host 'Continue [y|Y], Exit [e|E], Skip [s|S]?'
if ($ans -eq 'E' -or $ans -eq 'e')
{
    return
} 
if ($ans -eq 'y' -or $ans -eq 'Y')
{
    # create the stored procedure for feature engineering
    $script = $filepath + "step2b_feature_engineering.sql"
    ExecuteSQL $script

    # execute the feature engineering
    $output2 = Read-Host 'Output table name? Type D or d for default (Merged_Features_Prod)'
    if ($output2 -eq 'D' -or $output2 -eq 'd')
    {
        $output2 = 'Merged_Features_Prod'
    }
    Write-Host -ForeGroundColor 'Cyan' (" Computing new features...")
    $query = "EXEC feature_engineering $output1, $output2"
    ExecuteSQLQuery $query
}

if ($ans -eq 's' -or $ans -eq 'S')
{
    $output2 = 'Merged_Features_Prod'
}


##########################################################################
# Create and execute the stored procedure for the model scoring
##########################################################################
Write-Host -foregroundcolor 'green' ("Step 3: Making Predictions")
$ans = Read-Host 'Continue [y|Y], Exit [e|E], Skip [s|S]?'
if ($ans -eq 'E' -or $ans -eq 'e')
{
    return
} 
if ($ans -eq 'y' -or $ans -eq 'Y')
{
  # create the stored procedure for predicting 
    $script = $filepath + "step3b_scoring.sql"
    ExecuteSQL $script

  # execute the scoring
    $output3 = Read-Host 'Output table name holding predictions? Type D or d for default (Predictions_Logistic_Prod)'
    if ($output3 -eq 'D' -or $output3 -eq 'd')
    {
       $output3 = 'Predictions_Logistic_Prod'
    }
    Write-Host -ForeGroundColor 'Cyan' (" Making predictions with the logistic regression...")

    $query = "EXEC score 'SELECT * FROM $output2', $output3  "
    ExecuteSQLQuery $query

if ($ans -eq 's' -or $ans -eq 'S')
{
$output3 = 'Predictions_Logistic_Prod'
}

##########################################################################
# Create and execute the stored procedure for operational metrics
##########################################################################

Write-Host -foregroundcolor 'green' ("Step 4: Scores Transformation")
$ans = Read-Host 'Continue [y|Y], Exit [e|E], Skip [s|S]?'
if ($ans -eq 'E' -or $ans -eq 'e')
{
    return
} 
if ($ans -eq 'y' -or $ans -eq 'Y')
{
    # create the stored procedure to transform scores.
    $script = $filepath + "step4_operational_metrics.sql"
    ExecuteSQL $script

    $output4 = Read-Host 'Output table name holding final scores? Type D or d for default (Scores_Prod)'
    if ($output4 -eq 'D' -or $output4 -eq 'd')
    {
       $output4 = 'Scores_Prod'
    }

    # execute the script
    Write-Host -ForeGroundColor 'Cyan' (" Applying score transformation...")
    $query = "exec apply_score_transformation $output3, $output4"
    ExecuteSQLQuery $query  


    # drop the isBad column since it is unknown for Production and has been artificially created during the process. 
    $query = "ALTER TABLE $output4 DROP COLUMN isBad"
    ExecuteSQLQuery $query
}

}
Write-Host -foregroundcolor 'green'("Loan Credit Risk Scoring Workflow Finished Successfully!")
}
}

$endTime =Get-Date
$totalTime = ($endTime-$startTime).ToString()
Write-Host "Finished running at:" $endTime
Write-Host "Total time used: " -foregroundcolor 'green' $totalTime.ToString()