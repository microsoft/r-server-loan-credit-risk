##########################################################################################################################################
## This R script will do the following:
## 1. Specify parameters: Full path of the two input tables, SQL Server database name, User ID, Password, Server Name and Splitting Ratio.
## 2. Call the different functions for the Modeling Pipeline. 

## Input : Full path of the two input tables, database name, User ID, Password, Server Name and Splitting Ratio.
## Output: Trained model.

##########################################################################################################################################

# Load library. 
library(RevoScaleR)

# Set the working directory to the R scripts location.
# setwd()

##########################################################################################################################################
## SPECIFY INPUTS
##########################################################################################################################################

# Data sets full path. The paths below work if the working directory is set to the R scripts location. 
Loan <- "../Data/Loan.txt"
Borrower <- "../Data/Borrower.txt"

# Creating the connection string. Specify:
## Database name. If it already exists, tables will be overwritten. If not, it will be created.
## Server name. If conecting remotely to the DSVM, the full DNS address should be used with the port number 1433 (which should be enabled) 
## User ID and Password. Change them below if you modified the default values.  
db_name <- "Loans"
server <- "localhost"

connection_string <- sprintf("Driver=SQL Server;Server=%s;Database=%s;Trusted_Connection=Yes", server, db_name)

##############################################################################################################################
## Database Creation. 
##############################################################################################################################

# Open an Odbc connection with SQL Server master database only to create a new database with the rxExecuteSQLDDL function.
connection_string_master <- sprintf("Driver=SQL Server;Server=%s;Database=master;Trusted_Connection=True", server)
outOdbcDS_master <- RxOdbcData(table = "Default_Master", connectionString = connection_string_master)
rxOpen(outOdbcDS_master, "w")

# Create database if applicable. 
query <- sprintf( "if not exists(SELECT * FROM sys.databases WHERE name = '%s') CREATE DATABASE %s;", db_name, db_name)
rxExecuteSQLDDL(outOdbcDS_master, sSQLString = query)

# Close Obdc connection to master database. 
rxClose(outOdbcDS_master)

##############################################################################################################################
## Odbc connection and SQL Compute Context. 
##############################################################################################################################

# Open an Obdc connection with the SQL Server database that will store the modeling tables. (Only used for rxExecuteSQLddl) 
outOdbcDS <- RxOdbcData(table = "Default", connectionString = connection_string)
rxOpen(outOdbcDS, "w")

# Define SQL Compute Context for in-database computations. 
sql <- RxInSqlServer(connectionString = connection_string)

##############################################################################################################################
## Modeling Pipeline.
##############################################################################################################################

# Step 1: data processing.
source("./step1_preprocessing.R")
print("Step 1: Data Processing.")
data_process(Loan, Borrower)
  
# Step 2: feature engineering.
source("./step2_feature_engineering.R")
print("Step 2: Feature Engineering.")
feature_engineer()
  
# Step 3: training, scoring and evaluation of Logistic Regression. 
source("./step3_train_score_evaluate.R")
print("Step 3: Training, Scoring and Evaluating.")
Coeff_metrics <- training_evaluation()

Logistic_Coeff <- Coeff_metrics[[1]]
metrics <- Coeff_metrics[[2]]
print(metrics)

# Step 4: operational metrics computation and scores transformation.  
source("./step4_operational_metrics.R")
print("Step 4: Operational Metrics Computation and Scores Transformation.")

## Compute operational metrics and plot the rates of bad loans for various thresholds obtained through binning. 
Operational_Metrics <- compute_operational_metrics()
plot(Operational_Metrics$badRate, main = c("Rate of Bad Loans Among those with Scores Higher than Decision Thresholds"), xlab = "Default Score Percentiles", ylab = "Expected Rate of Bad Loans")

## EXAMPLE: 
## If the score cutoff of the 91th score percentile is 0.9834, and we read a bad rate of 0.6449.  
## This means that if 0.9834 is used as a threshold to classify loans as bad, we would have a bad rate of 64.49%.  
## This bad rate is equal to the number of observed bad loans over the total number of loans with a score greater than the threshold. 

## Transform the scores using the computed thresholds. 
apply_score_transformation(Operational_Metrics)

# Close the Obdc connection used for rxExecuteSQLddl functions. 
rxClose(outOdbcDS)

##########################################################################################################################################
## Function to get the top n rows of a table stored on SQL Server.
## You can execute this function at any time during  your progress by removing the comment "#", and inputting:
##  - the table name.
##  - the number of rows you want to display.
##########################################################################################################################################

display_head <- function(table_name, n_rows){
  table_sql <- RxSqlServerData(sqlQuery = sprintf("SELECT TOP(%s) * FROM %s", n_rows, table_name), connectionString = connection_string)
  table <- rxImport(table_sql)
  print(table)
}

# table_name <- "insert_table_name"
# n_rows <- 10
# display_head(table_name, n_rows)


