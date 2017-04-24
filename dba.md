---
layout: default
title: For the Database Analyst
---
<div class="alert alert-success" role="alert"> This page describes the 
<strong>
<span class="cig">{{ site.cig_text }}</span>
<span class="onp">{{ site.onp_text }}</span>
</strong>
solution.
{% include sqlchoices.md %}
</div> 

## For the Database Analyst - Operationalize with SQL
------------------------------

<div class="row">
    <div class="col-md-6">
        <div class="toc">
        <li><a href="#system-requirements">System Requirements</a></li>
        <li><a href="#workflow-automation">Workflow Automation</a></li>
        <li><a href="#step0">Step 0: Creating Tables</a></li>
        <li><a href="#step1">Step 1: Merging and Cleaning</a></li>
        <li><a href="#step2a">Step 2a: Splitting the Data Set</a></li>
        <li><a href="#step2b">*Step 2b: Feature Engineering</a></li>
        <li><a href="#step3a">Step 3a: Training</a></li>
        <li><a href="#step3b">Step 3b: Scoring</a></li>
        <li><a href="#step3c">Step 3c: Evaluating</a></li>
        <li><a href="#step4">Step 4: Operational Metrics Computation and Scores Transformation</a></li>
        <li><a href="#prod">The Production Pipeline</a></li>
        </div>
    </div>
    <div class="col-md-6">
When a financial institution examines a request for a loan, it is crucial to assess the risk of default to determine whether to grant it. This solution is based on simulated data for a small personal loan financial institution, containing the borrower's financial history as well as information about the requested loan.  View [more information about the data.](input_data.html) 
      <p/>
      <p>
      
      </p>

        </div>
</div>

For businesses that prefers an on-prem solution, the implementation with SQL Server R Services is a great option, which takes advantage of the power of SQL Server and RevoScaleR (Microsoft R Server). In this template, we implemented all steps in SQL stored procedures: data preprocessing, and feature engineering are implemented in pure SQL, while models training, scoring and evaluation steps are implemented with SQL stored procedures with embedded R (Microsoft R Server) code. 
<p/>
All the steps can be executed on SQL Server client environment (such as SQL Server Management Studio). We provide a Windows PowerShell script, Loan_Credit_Risk.ps1, which invokes the SQL scripts and demonstrates the end-to-end modeling process.

## System Requirements
-----------------------

To run the scripts requires the following:

To run the scripts, it requires the following:
 * SQL server 2016 with Microsoft R server (version 9.0.1) installed and configured;
 * The SQL user name and password, and the user is configured properly to execute R scripts in-memory;
 * SQL Database for which the user has write permission and can execute stored procedures (see create_user.sql);
 * Implied authentification is enabled so a connection string can be automatically created in R codes embedded into SQL Stored Procedures (see create_user.sql).
 * For more information about SQL server 2016 and R service, please visit: [What's New in SQL Server R Services](https://msdn.microsoft.com/en-us/library/mt604847.aspx)


## Workflow Automation
-------------------
Follow the [PowerShell instructions](Powershell_Instructions.html) to execute all the scripts described below.  View the [details all tables](tables.html)  created in this solution.

 
<a name="step0">

## Step 0: Creating Tables
-------------------------

The data sets Loan.csv and Borrower.csv are provided in the Data directory.

In this step, we create two tables, `Loan` and `Borrower` in a SQL Server database, and the data is uploaded to these tables using bcp command in PowerShell. This is done through either `Load_Data.ps1` or through running the beginning of `Loan_Credit_Risk.ps1`. 

### Input:

* Raw data: **Loan.csv** and **Borrower.csv**.

### Output:

* 2 Tables filled with the raw data: `Loan` and `Borrower` (filled through PowerShell).

### Related files:
* **step0_create_tables.sql**


<a name="step1">

## Step 1: Merging and Cleaning
-------------------------

In this step, the two tables are first merged into "Merged" with an inner join on memberId. This is done through the stored procedure [dbo].[merging]. 

Then, statistics (mode or mean) of "Merged" are computed and stored into a table called Stats. This table will be used for the Production pipeline. 
This is done through the `[dbo].[compute_stats]` stored procedure. 

The raw data is then cleaned. This assumes that the ID variables (`loanId` and `memberId`), the `date` and `loanStatus` (Variables that will be used to create the label) do not contain blanks. 
The stored procedure, `[fill_NA_mode_mean]`, will replace the missing values with the mode (categorical variables) or mean (float variables).

### Input:
* 2 Tables filled with the raw data: `Loan` and `Borrower` (filled through PowerShell).

### Output:
* A view, `Merged_Cleaned` with the cleaned data.
* `Stats` table with statistics on the raw data set. 

### Related files:
* **step1_data_preprocessing.sql**

<a name="step2a">

## Step 2a: Splitting the data set
-------------------------

In this step, we create a stored procedure `[dbo].[splitting]` that splits the data into a training set and a testing set. The user has to specify a splitting percentage. For example, if the splitting percentage is 70, 70% of the data will be put in the training set, while the other 30% will be assigned to the testing set. The `loanId` that will end in the training set is stored in the table `Train_Id`. The splitting is performed prior to feature engineering instead of in the training step because the feature engineering creates bins based on conditional inference trees that should be built only on the training set. If the bins were computed with the whole data set, the evaluation step would be rigged. 

### Input:

* `Merged_Cleaned` View.

### Output:

* `Train_Id` table containing the loanId that will end in the training set.

### Related files:

* **step2a_splitting.sql**


<a name="step2b">

## Step 2b: Feature Engineering
-------------------------

For feature engineering, we want to design new features: 

* Categorical versions of all the numeric variables. This is done for interpretability and is a standard practice in the Credit Score industry. 
* `isBad`: the label, specifying whether the loan has been charged off or has defaulted (`isBad` = 1) or if it is in good standing (`isBad` = 0), based on `loanStatus`. 

In this step, we first create a stored procedure `[dbo].[compute_bins]`. It uses the CRAN R package `smbinning` that builds a conditional inference tree on the training set (to which we append the binary label isBad) in order to get the optimal bins to be used for the numeric variables we want to bucketize. Because some of the numeric variables have too few unique values, or because the binning function did not return significant splits, we decided to manually specify default bins for all the variables in case smbinning failed to provide them. These default bins have been determined through an analysis of the data or through running smbinning on a larger data set. The computed and specified bins are then serialized and stored into the Bins table for usage in feature engineering of both Modeling and Production pipelines. 

The bins computation is optimized by running `smbinning` in parallel across the different cores of the server, through the use of `rxExec` function applied in a Local Parallel (`localpar`) compute context. The `rxElemArg` argument it takes is used to specify the list of variables (here the numeric variables names) we want to apply `smbinning` on. 

The `[dbo].[feature_engineering]` stored procedure then designs those new features on the view `Merged_Cleaned`, to create the table `Merged_Features`. This is done through an R code wrapped into the stored procedure. 

Variables names and types (and levels for factors) of the raw data set are then stored in a table called `Column_Info` through the stored procedure `[dbo].[get_column_info]`. It will be used for training and testing as well as during Production (Scenario 2 and 4) in order to ensure we have the same data types and levels of factors in all the data sets used.

### Input:

* `Merged_Cleaned` View and `Train_Id` table.

### Output:

* `Merged_Features` table containing new features.
* `Bins` table with bins to be used to bucketize numeric variables. 
* `Colum_Info` table with variables names and types (and levels for factors) of the raw data set.

### Related files:

* **step2b_feature_engineering.sql**

![Visualize](images/steps12.png?raw=true)


<a name="step3a">

## Step 3a: Training 
-------------------------

In this step, we create a stored procedure `[dbo].[train_model]` that trains a Logistic Regression on the training set. The trained model is serialized and stored in a table called `Model` using an Odbc connection. 
Training a Logistic Regression for loan credit risk prediction is a standard practice in the Credit Score industry. Contrary to more complex models such as random forests or neural networks, it is easily understandable through the simple formula generated during the training. Also, the presence of bucketed numeric variables helps understand the impact of each category and variable on the probability of default. The variables used and their respective coefficients, sorted by order of magnitude, are stored in the table `Logistic_Coeff`.

### Input:

* `Merged_Features` and `Train_Id` tables.

### Output:

* `Model` table containing the trained model. 
* `Logistic_Coeff` table with variables names and coefficients of the logistic regression formula. They are sorted in decreasing order of the absolute value of the coefficients. 

### Related files:

* **step3a_training.sql**

<a name="step3b">


## Step 3b: Scoring  
-------------------------

In this step, we create a stored procedure `[dbo].[score]` that scores the trained model on the testing set. The Predictions are stored in a SQL table. 

### Input:

* `Merged_Features`,`Train_Id`, and `Model` tables.

### Output:

* `Predictions_Logistic` table storing the predictions from the tested model.

### Related files:

* **step3b_scoring.sql**

<a name="step3c">

## Step 3c: Evaluating 
-------------------------

In this step, we create a stored procedure `[dbo].[evaluate]` that computes classification performance metrics written in the table `Metrics`. The metrics are: 

* KS (Kolmogorov-Smirnov) statistic. It is a standard performance metric in the credit score industry. It represents how well the model can differenciate between the Good Credit applicants from the Bad Credit applicants in the testing set.
* Various classification performance metrics computed on the confusion matrix. These are dependent on the threshold chosen to decide whether to classify a predicted probability as good or bad. Here, we use as a threshold the point on the x axis in the KS plot where the curves are the farthest possible.   
* AUC (Area Under the Curve) for the ROC. It represents how well the model can differenciate between the Good Credit applicants from the Bad Credit applicants given a good decision threshold in the testing set.

## Input:

* `Predictions_Logistic` table storing the predictions from the tested model.

### Output:

* `Metrics` table containing the performance metrics of the model.


### Related files:

* **step3c_evaluating.sql**

![Visualize](images/step3.png?raw=true)

<a name="step4">

## Step 4: Operational Metrics Computation and Scores Transformation 
-------------------------

![Visualize](images/step4bis.png?raw=true)

In this step, we create two stored procedures `[dbo].[compute_operational_metrics]`, and `[apply_score_transformation]`.

The first, `[dbo].[compute_operational_metrics]` will:

1. Apply a sigmoid function to the output scores of the logistic regression, in order to spread them in [0,1] and make them more interpretable. This sigmoid uses the average predicted score, so it is saved into the table `Scores_Average` for use in the Production pipeline. 

2. Compute bins for the scores, based on quantiles (we compute the 1%-99% percentiles). 

3. Take each lower bound of each bin as a decision threshold for default loan classification, and compute the rate of bad loans among loans with a score higher than the threshold. 

It outputs the table `Operational_Scores`, which will also be used in the Production pipeline. It can be read in the following way: 
If the score cutoff of the 91th score percentile is 0.9834, and we read a bad rate of 0.6449, this means that if 0.9834 is used as a threshold to classify loans as bad, we would have a bad rate of 64.49%. This bad rate is equal to the number of observed bad loans over the total number of loans with a score greater than the threshold. 

The second, `[apply_score_transformation]` will: 

1- Apply the same sigmoid function to the output scores of the logistic regression, in order to spread them in [0,1].

2- Asssign each score to a percentile bin with the bad rates given by the `Operational_Scores` table. These bad rates are either observed (Modeling pipeline) or expected (Production pipeline).


## Input:

* `Predictions_Logistic` table storing the predictions from the tested model.

## Output:

* `Operational_Scores` table containing the percentiles from 1% to 99%, the scores thresholds each one corresponds to, and the observed bad rate among loans with a score higher than the corresponding threshold. 
* `Scores_Average` table containing the single value of the average score output from the logistic regression. It is used for the sigmoid transformation in Modeling and Production pipeline.
* `Scores` table containing the transformed scores for each record of the testing set, together with the percentiles they belong to, the corresponding score cutoff, and the observed bad rate among loans with a higher score than this cutoff.

## Related files:

* **step4_operational_metrics.sql**

<a name="step4">

## The Production Pipeline 
-------------------------

In the Production pipeline, the data from the files **Loan_Prod.csv** and **Borrower_Prod.csv** is uploaded through PowerShell to the `Loan_Prod` and `Borrower_Prod` tables.
The tables `Stats`, `Bins`, `Column_Info`, `Model`, `Operational_Scores` and `Scores_Average` created during the Development pipeline are then moved to the Production database through the stored procedure `[dbo].[copy_modeling_tables]` located in the file **create_tables_prod.sql**.

The `Loan_Prod` and `Borrower_Prod` tables are then merged and cleaned like in Step 1 (using the `Stats` table), and a feature engineered table is created like in Step 2 (using the `Bins` table). The featurized table is then scored on the logistic regression model (using the `Model` and `Column_Info` tables). Finally, the scores are transformed and stored in the `Scores_Prod` table (using the `Scores_Average` and `Operational_Scores` tables). 



