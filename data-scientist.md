---
layout: default
title: For the Data Scientist
---
<div class="alert alert-success" role="alert"> This page describes the 
<strong>
<span class="cig">{{ site.cig_text }}</span>
<span class="onp">{{ site.onp_text }}</span>
<span class="hdi">{{ site.hdi_text }}</span> 
</strong>
solution.
{% include choices.md %}
</div> 

## For the Data Scientist - Develop with R
----------------------------

<div class="row">
    <div class="col-md-6">
        <div class="toc">
            <li><a href="#intro">Loan Credit Risk</a></li>
            <li><a href="#step1">Step 1: Merging and Cleaning</a></li>
            <li><a href="step2">Step 2: Splitting and Feature Engineering</a></li>
            <li><a href="#step3">Step 3: Training, Testing and Evaluating</a></li>
            <li><a href="#step4">Step 4: Operational Metrics Computation and Scores Transformation</a></li>
            <li><a href="#deploy">Deploy and Visualize Results</a></li>
            <li class="sql"><a href="#requirements">System Requirements</a></li>
            <li><a href="#template-contents">Template Contents</a></li>
        </div>
    </div>
    <div class="col-md-6">

        <div class="onp">
        For businesses that prefer an on-prem solution, the implementation with SQL Server R Services is a great option, which takes advantage of the power of SQL Server and RevoScaleR (Microsoft R Server).
        </div> 
        <div class="cig">
        This implementation on Azure SQL Server R Services is a great option which takes advantage of the power of SQL Server and RevoScaleR (Microsoft R Server). 
        </div>
        <div class="hdi">
        HDInsight is a cloud Spark and Hadoop service for the enterprise.  HDInsight is also the only managed cloud Hadoop solution with integration to Microsoft R Server.
        <p></p>
        This solution shows how to pre-process data (cleaning and feature engineering), train prediction models, and perform scoring on an HDInsight Spark cluster with Microsoft R Server. 
        </div>   
    </div>
</div>
<div class="sql">
<p></p>
This solution package shows how to pre-process data (cleaning and feature engineering), train prediction models, and perform scoring on the SQL Server machine.
<p></p>
</div>

<div class="sql">
Data scientists who are testing and developing solutions can work from the convenience of their R IDE on their client machine, while <a href="https://msdn.microsoft.com/en-us/library/mt604885.aspx">setting the computation context to SQL</a> (see <bd>R</bd> folder for code).  They can also deploy the completed solutions to SQL Server 2016 by embedding calls to R in stored procedures (see <strong>SQLR</strong> folder for code). These solutions can then be further automated by the use of SQL Server Integration Services and SQL Server agent: a PowerShell script (.ps1 file) automates the running of the SQL code.
</div>
<div class="hdi">
Data scientists who are testing and developing solutions can work from the browser-based Open Source Edition of RStudio Server on the HDInsight Spark cluster edge node, while <a href="https://docs.microsoft.com/en-us/azure/hdinsight/hdinsight-hadoop-r-server-compute-contexts">using a compute context</a> to control whether computation will be performed locally on the edge node, or whether it will be distributed across the nodes in the HDInsight Spark cluster. 
</div>

<a name="intro">
## {{ site.solution_name }}
--------------------------

When a financial institution examines a request for a loan, it is crucial to assess the risk of default to determine whether to grant it. This solution is based on simulated data for a small personal loan financial institution, containing the borrower's financial history as well as information about the requested loan.  View [more information about the data](input_data.html).

<div class="sql">
<p></p>
In this solution, the final scored database table <code>Scores</code> is created in SQL Server.  This data is then visualized in PowerBI. 
<p></p>
</div>
<div class="hdi">
<p></p>
In this solution, an Apache Hive table will be created to show predicted recommendations for how and when to contact each lead. This data is then visualized in PowerBI. 
<p></p>
</div>

To try this out yourself, visit the [Quick Start](START_HERE.html) page.  

Below is a description of what happens in each of the steps: data preparation, feature engineering, model development, prediction, and deployment in more detail.


The file **modeling_main.R** enables the user to define the input and call all the steps. Inputs are: paths to the raw data files, database name, server name, username and password.

The database is created if it does not not already exist, and the connection string as well as the SQL compute context are defined.

<a name="step1">

## Step 1: Merging and Cleaning
-------------------------

In this step, the raw data is loaded into SQL in two tables called `Loan` and `Borrower`. They are then merged into one, `Merged`.

Then, if there are missing values, the data is cleaned by replacing missing values with the mode (categorical variables) or mean (float variables). This assumes that the ID variables (`loanId` and `memberId`) as well as `loanStatus` do not contain blanks. 

The cleaned data is written to the SQL table `Merged_Cleaned`.

### Input:
* Raw data: **Loan.csv** and **Borrower.csv**.

### Output:
* `Loan` and `Borrower` SQL tables with the raw data. 
* `Merged_Cleaned` SQL table , with missing values replaced if applicable.

### Related files:
* **step1_preprocessing.R**

<a name="step2">

## Step 2: Splitting and Feature Engineering
-------------------------

![Visualize](images/steps12.png?raw=true)

For feature engineering, we want to design new features: 

* Categorical versions of all the numeric variables. This is done for interpretability and is a standard practice in the Credit Score industry. 
* `isBad`: the label, specifying whether the loan has been charged off or has defaulted (`isBad` = 1) or if it is in good standing (`isBad` = 0), based on `loanStatus`. 

This is done by following these steps:

1. Create the label `isBad` with `rxDataStep` function into the table `Merged_Labeled`. 

2. Split the data set into a training and a testing set. This is done by selecting randomly a proportion (equal to the user-specified splitting ratio) of `loanId` to be part of the training set, written to the SQL table `Train_Id`. 
The splitting is performed prior to feature engineering instead of in the training step because the feature engineering creates bins based on conditional inference trees that should be built only on the training set. If the bins were computed with the whole data set, the evaluation step would be rigged. 

3. Compute the bins that will be used to create the categorical variables. It uses the CRAN R package `smbinning` that builds a conditional inference tree on the training set (to which we append the binary label isBad) in order to get the optimal bins to be used for the numeric variables we want to bucketize. Because some of the numeric variables have too few unique values, or because the binning function did not return significant splits, we decided to manually specify default bins in case smbinning does not return the splits. These default bins have been determined through an analysis of the data or through running smbinning on a larger data set.

The bins computation is optimized by running `smbinning` in parallel across the different cores of the server, through the use of `rxExec` function applied in a Local Parallel (`localpar`) compute context. The `rxElemArg` argument it takes is used to specify the list of variables (here the numeric variables names) we want to apply smbinning on. 

4.  Bucketize the variables based on the computed/specified bins with the function `bucketize`, wrapped into an `rxDataStep` function. The final output is written into the SQL table `Merged_Features`.

### Input:

* `Merged_Cleaned` SQL table.

### Output:

* `Merged_Features` SQL table containing new features.
* `Train_Id` SQL table containing the `loanId` that will end in the training set. 


### Related files:

* **step2_feature_engineering.R**

<a name="step3">

## Step 3: Training, Testing and Evaluating 
-------------------------

![Visualize](images/step3.png?raw=true)

After converting the strings to factors (with `stringsAsFactors = TRUE`), we get the variables information (types and levels) of the `Merged_Features` SQL table with `rxCreateColInfo`. We then point to the training and testing sets with the correct column information. 

Then we build a Logistic Regression Model on the training set. The trained model is serialized and uploaded to a SQL table `Model` if needed later, through an Odbc connection. 

Training a Logistic Regression for loan credit risk prediction is a standard practice in the Credit Score industry. Contrary to more complex models such as random forests or neural networks, it is easily understandable through the simple formula generated during the training. Also, the presence of bucketed numeric variables helps understand the impact of each category and variable on the probability of default. The variables used and their respective coefficients, sorted by order of magnitude, are stored in the data frame `Logistic_Coeff` returned by the step 3 function.

Finally, we compute predictions on the testing set, as well as performance metrics: 

* **KS** (Kolmogorov-Smirnov) statistic. The KS statistic is a standard performance metric in the credit score industry. It represents how well the model can differenciate between the Good Credit applicants and the Bad Credit applicants in the testing set. We also draw the KS plot which corresponds to two cumulative distributions of the predicted probabilities. One is a subset of the predictions for which the observed values were bad loans (is_bad = 1) and the other concerns good loans (is_bad = 0). KS will be the biggest distance between those two curves. 

![Visualize](images/KS.png?raw=true)


* Various classification performance metrics computed on the confusion matrix. These are dependent on the threshold chosen to decide whether to classify a predicted probability as good or bad. Here, we use as a threshold the point of the x axis in the KS plot where the curves are the farthest possible.   
* **AUC** (Area Under the Curve) for the ROC. This represents how well the model can differenciate between the Good Credit applicants from the Bad Credit applicants given a good decision threshold in the testing set. We draw the ROC, representing the true positive rate in function of the false positive rate for various possible cutoffs. 

![Visualize](images/ROC.png?raw=true)

* **The Lift Chart**. The lift chart represents how well the model can perform compared to a naive approach. For instance, at the level where a naive effort could produce a 10% rate of positive predictions, we draw a vertical line on x = 0.10 and read the lift value where the vertical line crosses the lift curve. If the lift value is 3, it means that the model would produce 3 times the 10%, ie. 30% rate of positive predictions. 

![Visualize](images/Lift_Chart.png?raw=true)


### Input:

* `Merged_Features` SQL table containing new features.
* `Train_Id` SQL table containing the loanId that will end in the training set. 

### Output:

* `Model` SQL table containing the serialized logistic regression model.
* `Logistics_Coeff` data frame returned by the function.  It contains variables names and coefficients of the logistic regression formula. They are sorted in decreasing order of the absolute value of the coefficients. 
* `Predictions_Logistic` SQL table containing the predictions made on the testing set.
* Performance metrics returned by the step 3 function. 

### Related files:

* **step3_train_score_evaluate.R**

<a name="step4">

## Step 4: Operational Metrics Computation and Scores Transformation 
-------------------------

![Visualize](images/step4bis.png?raw=true)

In this step, we create two functions `compute_operational_metrics`, and `apply_score_transformation`.

The first, `compute_operational_metrics` will:

1. Apply a sigmoid function to the output scores of the logistic regression, in order to spread them in [0,1] and make them more interpretable. This sigmoid uses the average predicted score.

2. Compute bins for the scores, based on quantiles (we compute the 1%-99% percentiles). 

3. Take each lower bound of each bin as a decision threshold for default loan classification, and compute the rate of bad loans among loans with a score higher than the threshold. 

It outputs the data frame `Operational_Scores`, which is also saved to SQL. It can be read in the following way: 
If the score cutoff of the 91th score percentile is 0.9834, and we read a bad rate of 0.6449, this means that if 0.9834 is used as a threshold to classify loans as bad, we would have a bad rate of 64.49%. This bad rate is equal to the number of observed bad loans over the total number of loans with a score greater than the threshold. 

The second, `apply_score_transformation` will: 

1. Apply the same sigmoid function to the output scores of the logistic regression, in order to spread them in [0,1].

2. Asssign each score to a percentile bin with the bad rates given by the `Operational_Scores` table. 

### Input:

* `Predictions_Logistic` SQL table storing the predictions from the tested model.

### Output:

* `Operational_Scores` SQL table and data frame containing the percentiles from 1% to 99%, the scores thresholds each one corresponds to, and the observed bad rate among loans with a score higher than the corresponding threshold. 
* `Scores` SQL table containing the transformed scores for each record of the testing set, together with the percentiles they belong to, the corresponding score cutoff, and the observed bad rate among loans with a higher score than this cutoff.

### Related files:

* **step4_operational_metrics.R**

The **modeling_main.R** script uses the `Operational_Scores` table to plot the rates of bad loans among those with scores higher than each decision threshold. The decision thresholds correspond to the beginning of each percentile-based bin.

![Visualize](images/Operational_Scores.png?raw=true)

For example, if the score cutoff of the 91th score percentile is 0.9834, and we read a bad rate of 0.6449. This means that if 0.9834 is used as a threshold to classify loans as bad, we would have a bad rate of 64.49%. This bad rate is equal to the number of observed bad loans over the total number of loans with a score greater than the threshold. 



 <a name="deploy"> 

##  Deploy and Visualize Results
--------------------------------
<div class="sql">
The final scores reside in the table <code>Scores</code> of the <code>{{ site.db_name }}</code> database. The production data is in a new database, <code>{{ site.db_name }}_Prod</code>, in the table <code>Scores_Prod</code>. The final step of this solution visualizes both predictions tables in PowerBI.
</div>

<div class="hdi">
<h2>Deploy</h2>
XXXThe script <strong>campaign_deployment.R </strong> creates and tests a analytic web service.  The web service can then be used from another application to score future data.  The file <strong>web_scoring.R</strong> can be downloaded to invoke this web service locally on any computer with Microsoft R Server 9.0.1 installed. 
<p></p>
<div class="alert alert-info" role="alert">
XXXBefore running  <strong>campaign_web_scoring.R</strong> on any computer, you must first connect to edge node from that computer.
Once you have connected you can also use the web server admin utility to reconfigure or check on the status of the server.
<p></p>
Follow <a href="deployr.html">Operationalization with R Server instruction</a> to connect to the edge node and/or use the admin utility.
</div>
</div>

<p></p>
* See [For the Business Manager](business-manager.html) for details of the PowerBI dashboard.

<div name="requirements" class="sql">
<h2> System Requirements</h2>

The following are required to run the scripts in this solution:
<ul>
<li>SQL Server 2016 with Microsoft R Server  (version 9.0.1) installed and configured.  </li>   
<li>The SQL user name and password, and the user configured properly to execute R scripts in-memory.</li> 
<li>SQL Database which the user has write permission and execute stored procedures.</li> 
<li>For more information about SQL server 2016 and R service, please visit: <a href="https://msdn.microsoft.com/en-us/library/mt604847.aspx">https://msdn.microsoft.com/en-us/library/mt604847.aspx</a></li> 
</ul>
</div>


## Template Contents 
---------------------

* [View the contents of this solution template](contents.html).


To try this out yourself: 

* View the [Quick Start](START_HERE.html).

[&lt; Home](index.html)
