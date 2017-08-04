<#
.SYNOPSIS
Script to load the data into SQL Server for the Loan Credit Risk solution how-to. 
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
$sqlUsername ="",


[parameter(Mandatory=$true,ParameterSetName = "LC")]
[ValidateNotNullOrEmpty()]
[String]
$sqlPassword ="",

[parameter(Mandatory=$false,ParameterSetName = "LC")]
[ValidateNotNullOrEmpty()]
[String]
$dataPath = ""
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
    Invoke-Sqlcmd -ServerInstance $ServerName  -Database $DBName -Username $sqlUsername -Password $sqlPassword -InputFile $sqlscript -QueryTimeout 200000
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
    Invoke-Sqlcmd -ServerInstance $ServerName  -Database $DBName -Username $sqlUsername -Password $sqlPassword -Query $sqlquery -QueryTimeout 200000
}

##########################################################################
# Check if the SQL server or database exists
##########################################################################
$query = "IF NOT EXISTS(SELECT * FROM sys.databases WHERE NAME = '$DBName') CREATE DATABASE $DBName"
Invoke-Sqlcmd -ServerInstance $ServerName -Username $sqlUsername -Password $sqlPassword -Query $query -ErrorAction SilentlyContinue
if ($? -eq $false)
{
    Write-Host -ForegroundColor Red "Failed the test to connect to SQL server: $ServerName database: $DBName !"
    Write-Host -ForegroundColor Red "Please make sure: `n`t 1. SQL Server: $ServerName exists;
                                     `n`t 2. SQL database: $DBName exists;
                                     `n`t 3. SQL user: $sqlUsername has the right credential for SQL server access."
    exit
}

$query = "USE $DBName;"
Invoke-Sqlcmd -ServerInstance $ServerName -Username $sqlUsername -Password $sqlPassword -Query $query 


if($is_production -eq 'n' -or $is_production -eq 'N')
{

##########################################################################
# Loading the deployment data
##########################################################################
$startTime= Get-Date
Write-Host "Start time is:" $startTime
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
            bcp $tableName format nul -c -x -f $tableSchema  -U $sqlUsername -S $ServerName -P $sqlPassword  -t ',' 
            bcp $tableName in $destination -t ',' -S $ServerName -f $tableSchema -F 2 -C "RAW" -b 50000 -U $sqlUsername -P $sqlPassword 
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

    
  if($is_production -eq 'y' -or $is_production -eq 'Y')
{

##########################################################################
# Loading the production data
##########################################################################
$startTime= Get-Date
Write-Host "Start time is:" $startTime

$development_db = Read-Host 'Name of the development database to get Stats, Bins, Models and Column Information from?'

try{

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
            bcp $tableName format nul -c -x -f $tableSchema  -U $sqlUsername -S $ServerName -P $sqlPassword  -t ',' 
            bcp $tableName in $destination -t ',' -S $ServerName -f $tableSchema -F 2 -C "RAW" -b 50000 -U $sqlUsername -P $sqlPassword 
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
    Write-Host -ForeGroundColor 'Cyan' (" Getting the Stats, Bins, Model, Column Information, Scores_Average, and Operational_Scores from the tables used during the development pipeline...")
    $query = "EXEC copy_modeling_tables $development_db"
    ExecuteSQLQuery $query
}


$endTime =Get-Date
$totalTime = ($endTime-$startTime).ToString()
Write-Host "Finished running at:" $endTime
Write-Host "Total time used: " -foregroundcolor 'green' $totalTime.ToString()

