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
            <li><a href="#dev">Development Stage</a></li>
            <ul>
                <li><a href="#step0" class="hdi">Step 0: Create Intermediate Directories</a></li>
                <li><a href="#step1">Step 1: Merging and Cleaning</a></li>
                <li><a href="step2">Step 2: Splitting and Feature Engineering</a></li>
                <li><a href="#step3">Step 3: Training, Testing and Evaluating</a></li>
                <li><a href="#step4">Step 4: Operational Metrics Computation and Scores Transformation</a></li>
            </ul>
            <li class="hdi"><a href="#update">Updating the Production Stage Directory</a></li>
            <li class="hdi"><a href="#production">Production Stage</a></li>
            <li class="hdi"><a href="#web">Deploy as a Web Service</a></li>
            <li><a href="#viz">Visualize Results</a></li>
            <li class="hdi"><a href="#data">Using Your Own Data Set</a></li>
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
Data scientists who are testing and developing solutions can work from the convenience of their R IDE on their client machine, while <a href="https://msdn.microsoft.com/en-us/library/mt604885.aspx">setting the computation context to SQL</a> (see <strong>R</strong> folder for code).  They can also deploy the completed solutions to SQL Server 2016 by embedding calls to R in stored procedures (see <strong>SQLR</strong> folder for code). These solutions can then be further automated by the use of SQL Server Integration Services and SQL Server agent: a PowerShell script (.ps1 file) automates the running of the SQL code.
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
In this solution, an Apache Hive table will be created to show predicted scores. This data is then visualized in PowerBI. 
<p></p>
</div>

To try this out yourself, visit the [Quick Start](START_HERE.html) page.  

Below is a description of what happens in each of the steps: data preparation, feature engineering, model development, prediction, and deployment in more detail.

<div class="sql">
The file <strong>modeling_main.R</strong> enables the user to define the input and call all the steps. Inputs are: paths to the raw data files, database name, server name, username and password.

The database is created if it does not not already exist, and the connection string as well as the SQL compute context are defined.
</div>
<div class="hdi">
<p><a name="dev"></a></p>
<h2>Development Stage</h2>
<hr />

<p>The Modeling or Development stage includes five steps:</p>

<ul>
  <li><a href="step0">Step 0: Create intermediate directories</a></li>
  <li><a href="step1">Step 1: Data processing</a></li>
  <li><a href="step2">Step 2: Splitting and Feature engineering</a></li>
  <li><a href="step3">Step 3: Training, testing and evaluation</a></li>
  <li><a href="step4">Step 4: Operational metrics computation and scores transformation</a></li>
</ul>

<p>They will all be invoked by the <strong>development_main.R</strong> script for this development stage. This script also:</p>

<ul>
  <li>Opens the Spark connection.</li>
  <li>Lets the user specify the paths to the working directories on the edge node and HDFS. We assume they already exist.</li>
  <li>Lets the user specify the paths to the data sets Loan and Borrower on HDFS.  (The data is synthetically generated by sourcing the data_generation.R script.) </li>
  <li>Creates a directory, LocalModelsDir, that will store the model and other tables for use in the Production or Web Scoring stages (inside the loan_dev main function).</li>
  <li>Updates the tables of the Production stage directory, ProdModelDir, with the contents of LocalModelsDir (inside the loan_dev main function).</li>
</ul>
<p><a name="step0"></a></p>
<h3>Step 0: Intermediate Directories Creation</h3>
<hr />

<p>In this step, we create or clean intermediate directories both on the edge node and HDFS. These directories will hold all the intermediate processed data sets in subfolders.</p>

<p><strong>Related files:</strong></p>

<ul>
  <li>step0_directories_creation.R</li>
</ul>
</div>


<p><a name="step1"></a></p>

<h2>Step 1: Merging and Cleaning</h2>
<hr />
<div class="sql">
<p>In this step, the raw data is loaded into SQL in two tables called <code>Loan</code> and <code>Borrower</code>. They are then merged into one, <code>Merged</code>.</p>

<p>Then, if there are missing values, the data is cleaned by replacing missing values with the mode (categorical variables) or mean (float variables). This assumes that the ID variables (<code>loanId</code> and <code>memberId</code>) as well as <code>loanStatus</code> do not contain blanks.</p>

<p>The cleaned data is written to the SQL table <code>Merged_Cleaned</code>. The Statistics are written to SQL if you want to run a batch scoring from SQL after a development stage in R.</p>

<h3>Input:</h3>
<ul>
  <li>Raw data: <strong>Loan.csv</strong> and <strong>Borrower.csv</strong>.</li>
</ul>

<h3>Output:</h3>
<ul>
  <li><code>Loan</code> and <code>Borrower</code> SQL tables with the raw data.</li>
  <li><code>Merged_Cleaned</code> SQL table , with missing values replaced if applicable.</li>
  <li><code>Stats</code> SQL table , with global means or modes for every variable.</li>
</ul>
</div>

<div class="hdi">
<p>In order to speed up the computations in this step and the following ones, we first convert the input data to .xdf files stored in HDFS. We convert characters to factors at the same time. 
We then merge the xdf files with the rxMerge function, which writes the xdf result to the HDFS directory “Merged”.</p>

<p>Finally, we want to fill the missing values in the merged table. Missing values of numeric variables will be filled with the global mean, while character variables will be filled with the global mode.<br />
This is done in the following way:</p>

<ul>
  <li>Use rxSummary function on the HDFS directory holding the merged table xdf files. This will give us the names of the variables with missing values, their types, the global means, as well as counts table through which we can compute the global modes.</li>
  <li>Save these statistics information to be used for the Production or Web Scoring stages, in the directory LocalModelsDir.</li>
  <li>If no missing values are found, the merged data splits are copied to the folder “MergedCleaned” on HDFS, without missing value treatment.</li>
</ul>

<p>If there are missing values, we:</p>

<ul>
  <li>Compute the global means and modes for the variables with missing values by using the rxSummary results.</li>
  <li>Define the “Mean_Mode_Replace” function which will deal with the missing values. It will be called in rxDataStep function which acts on the xdf files of “Merged”.</li>
  <li>Apply the rxDataStep function.</li>
</ul>

<p>We end up with the cleaned splits of the merged table, “MergedCleaned” on HDFS.</p>
<p><strong>Input:</strong></p>

<ul>
  <li>Working directories on the edge node and HDFS.</li>
  <li>2 Data Tables: Loan and Borrower (paths to csv files)</li>
</ul>

<p><strong>Output:</strong></p>

<ul>
  <li>The statistics summary information saved to the local edge node in the LocalModelsDir folder.</li>
  <li>Cleaned raw data set MergedCleaned on HDFS in xdf format.</li>
</ul>
</div>
<h3>Related files:</h3>
<ul>
  <li><strong>step1_preprocessing.R</strong></li>
</ul>

<p><a name="step2"></a></p>

<h2>Step 2: Splitting and Feature Engineering</h2>
<hr />

<p><img src="images/steps12.png?raw=true" alt="Visualize" /></p>

<p>For feature engineering, we want to design new features:</p>

<ul>
  <li>Categorical versions of all the numeric variables. This is done for interpretability and is a standard practice in the Credit Score industry.</li>
  <li><code>isBad</code>: the label, specifying whether the loan has been charged off or has defaulted (<code>isBad</code> = 1) or if it is in good standing (<code>isBad</code> = 0), based on <code>loanStatus</code>.</li>
</ul>

<p>This is done by following these steps:</p>

<ol>
  <li>
    <p class="sql">Create the label <code>isBad</code> with <code>rxDataStep</code> function into the table <code>Merged_Labeled</code>.</p>
    <p class="hdi">Create the label isBad with rxDataStep function. Outputs are written to the HDFS directory “MergedLabeled”. We create at the same time the variable hashCode with values corresponding to hashing loanId to integers. It will be used for splitting. This hashing function ensures repeatability of the splitting procedure.</p>
  </li>
  <li>
    <p class="sql">Split the data set into a training and a testing set. This is done by selecting randomly 70% of <code>loanId</code> to be part of the training set. In order to ensure repeatability, <code>loanId</code> values are mapped to integers through a hash function, with the mapping and <code>loanId</code> written to the <code>Hash_Id</code> SQL table. The splitting is performed prior to feature engineering instead of in the training step because the feature engineering creates bins based on conditional inference trees that should be built only on the training set. If the bins were computed with the whole data set, the evaluation step would be rigged.</p>
    <p class="hdi">Split the data set into a training and a testing set. This is done by selecting randomly a proportion (equal to the user-specified splitting ratio) of the MergedLabeled data. The output is written to the “Train” directory.</p>
  </li>
  <li>
    Compute the bins that will be used to create the categorical variables with <code>smbinning</code>. Because some of the numeric variables have too few unique values, or because the binning function did not return significant splits, we decided to manually specify default bins in case smbinning does not return the splits. These default bins have been determined through an analysis of the data or through running <code>smbinning</code> on a larger data set. <span class="hdi">Those cutoffs are saved in the directory LocalModelsDir, to be used for the Production or Web Scoring stages.</span>
    <p>The bins computation is optimized by running <code>smbinning</code> in parallel across the different cores of the server, through the use of <code>rxExec</code> function applied in a Local Parallel (<code>localpar</code>) compute context. The <code>rxElemArg</code> argument it takes is used to specify the list of variables (here the numeric variables names) we want to apply smbinning on. <span class="sql">They are saved to SQL in case you want to run a production stage with SQL after running a development stage in R.</span></p>
  </li>
  <li>Bucketize the variables based on the computed/specified bins with the function <code>bucketize</code>, wrapped into an <code>rxDataStep</code> function. <span class="sql">The final output is written into the SQL table <code>Merged_Features</code>.</span><span class="hdi">The final output is written into the HDFS directory <strong>MergedFeatures</strong>, in xdf format.</span>
  <p class="hdi">Finally, we convert the newly created variables from character to factors, and save the variable information in the directory LocalModelsDir, to be used for the Production or Web Scoring stages. The data with the correct variable types is written to the directory “MergedFeaturesFactors” on HDFS.</p>
  </li>
</ol>

<h3>Input:</h3>
<p class="hdi">(assume the cleaned data, MergedCleaned is already created there by Step 1)</p>

<ul>
  <li class="sql"><code>Merged_Cleaned</code> SQL table.</li>
  <li class="hdi">Working directories on the edge node and HDFS.</li>
  <li class="hdi">The splitting ratio, corresponding to the proportion of the input data set that will go to the training set.</li>
</ul>

<h3>Output:</h3>

<ul>
  <li class="sql"><code>Merged_Features</code> SQL table containing new features.</li>
  <li class="sql"><code>Hash_Id</code> SQL table containing the <code>loanId</code> and the mapping through the hash function.</li>
  <li class="sql"><code>Bins</code> SQL table containing the serialized list of cutoffs to be used in a future Production stage.</li>
  <li class="hdi">Cutoffs saved to the local edge node in the <strong>LocalModelsDir</strong> folder.</li>
  <li class="hdi">Factor information saved to the local edge node in the <strong>LocalModelsDir</strong> folder.</li>
  <li class="hdi">Analytical data set with correct variable types <code>MergedFeaturesFactors</code> on HDFS in xdf format.</li>
</ul>

<h3>Related files:</h3>

<ul>
  <li><strong>step2_feature_engineering.R</strong></li>
</ul>

<p><a name="step3"></a></p>

<h2>Step 3: Training, Testing and Evaluating</h2>
<hr />

<p><img src="images/step3.png?raw=true" alt="Visualize" /></p>

<p class="sql">After converting the strings to factors (with <code>stringsAsFactors = TRUE</code>), we get the variables information (types and levels) of the <code>Merged_Features</code> SQL table with <code>rxCreateColInfo</code>. We then point to the training and testing sets with the correct column information.</p>

<p class="hdi">In this step, we perform the following:</p>

<p class="hdi">Split the xdf files in MergedFeaturesFactors into a training set, “Train”, and a testing set “Test”. This is done through rxDataStep functions, according to the splitting ratio defined and used in Step 2 and using the same hashCode created in Step 2.</p>

<p class="hdi">Train a Logistic Regression on Train, and save it on the local edge node in the <strong>LocalModelsDir</strong> folder. It will be used in the Production or Web Scoring stages.</p>

<p class="sql">Then we build a Logistic Regression Model on the training set. The trained model is serialized and uploaded to a SQL table <code>Model</code> if needed later, through an Odbc connection.</p>

<p>Training a Logistic Regression for loan credit risk prediction is a standard practice in the Credit Score industry. Contrary to more complex models such as random forests or neural networks, it is easily understandable through the simple formula generated during the training. Also, the presence of bucketed numeric variables helps understand the impact of each category and variable on the probability of default. The variables used and their respective coefficients, sorted by order of magnitude, are stored in the data frame <code>Logistic_Coeff</code> returned by the step 3 function.</p>

<p>Finally, we compute predictions on the testing set, as well as performance metrics:</p>

<ul>
  <li><strong>KS</strong> (Kolmogorov-Smirnov) statistic. The KS statistic is a standard performance metric in the credit score industry. It represents how well the model can differenciate between the Good Credit applicants and the Bad Credit applicants in the testing set. We also draw the KS plot which corresponds to two cumulative distributions of the predicted probabilities. One is a subset of the predictions for which the observed values were bad loans (is_bad = 1) and the other concerns good loans (is_bad = 0). KS will be the biggest distance between those two curves.</li>
</ul>

<p><img src="images/KS.png?raw=true" alt="Visualize" /></p>

<ul>
  <li>Various classification performance metrics computed on the confusion matrix. These are dependent on the threshold chosen to decide whether to classify a predicted probability as good or bad. Here, we use as a threshold the point of the x axis in the KS plot where the curves are the farthest possible.</li>
  <li><strong>AUC</strong> (Area Under the Curve) for the ROC. This represents how well the model can differenciate between the Good Credit applicants from the Bad Credit applicants given a good decision threshold in the testing set. We draw the ROC, representing the true positive rate in function of the false positive rate for various possible cutoffs.</li>
</ul>

<p><img src="images/ROC.png?raw=true" alt="Visualize" /></p>

<ul>
  <li><strong>The Lift Chart</strong>. The lift chart represents how well the model can perform compared to a naive approach. For instance, at the level where a naive effort could produce a 10% rate of positive predictions, we draw a vertical line on x = 0.10 and read the lift value where the vertical line crosses the lift curve. If the lift value is 3, it means that the model would produce 3 times the 10%, ie. 30% rate of positive predictions.</li>
</ul>

<p><img src="images/Lift_Chart.png?raw=true" alt="Visualize" /></p>

<h3>Input:</h3>
<p class="hdi">(assume the analytical data set, “MergedFeaturesFactors”, is already created there by Step 2)</p>
<ul>
  <li class="sql"><code>Merged_Features</code> SQL table containing new features.</li>
  <li class="sql"><code>Hash_Id</code> SQL table containing the <code>loanId</code> and the mapping through the hash function.</li>
  <li class="hdi">Working directories on the edge node and HDFS.</li>
  <li class="hdi">The splitting ratio, corresponding to the proportion of the input data set that will go to the training set. It should be the same as the one used in Step 2.</li>
</ul>

<h3>Output:</h3>

<ul>
  <li class="sql"><code>Model</code> SQL table containing the serialized logistic regression model.</li>
  <li class="sql"><code>Logistics_Coeff</code> data frame returned by the function.  It contains variables names and coefficients of the logistic regression formula. They are sorted in decreasing order of the absolute value of the coefficients.</li>
  <li class="sql"><code>Predictions_Logistic</code> SQL table containing the predictions made on the testing set.</li>
  <li class="sql"><code>Column_Info</code> SQL table containing the serialized list of factor levels to be used in a future Production stage.</li>
  <li class="sql">Performance metrics returned by the step 3 function.</li>
  <li class="hdi">Logistic Regression model saved to the local edge node in the LocalModelsDir folder.</li>
  <li class="hdi">Logistic Regression formula saved to the local edge node in the LocalModelsDir folder.</li>
  <li class="hdi">Prediction results given by the model on the testing set, “PredictionsLogistic” on HDFS in xdf format.</li>
</ul>

<h3>Related files:</h3>

<ul>
  <li><strong>step3_train_score_evaluate.R</strong></li>
</ul>

<p><a name="step4"></a></p>

<h2>Step 4: Operational Metrics Computation and Scores Transformation</h2>
<hr />

<p><img src="images/step4bis.png?raw=true" alt="Visualize" /></p>

<p>In this step, we create two functions <code>compute_operational_metrics</code>, and <code>apply_score_transformation</code>.</p>

<p>The first, <code>compute_operational_metrics</code> will:</p>

<ol>
  <li>
    <p>Apply a sigmoid function to the output scores of the logistic regression, in order to spread them in [0,1] and make them more interpretable. This sigmoid uses the average predicted score, which is saved to SQL in case you want to run a production stage through SQL after a development stage with R.</p>
  </li>
  <li>
    <p>Compute bins for the scores, based on quantiles (we compute the 1%-99% percentiles).</p>
  </li>
  <li>
    <p>Take each lower bound of each bin as a decision threshold for default loan classification, and compute the rate of bad loans among loans with a score higher than the threshold.</p>
  </li>
</ol>

<p>It outputs the data frame <code>Operational_Metrics</code>, 
<span class="sql">which is also saved to SQL.</span>
<span class="hdi">which is saved to the local edge node in the LocalModelsDir folder, for use in the Production and Web Scoring stages.</span> 
It can be read in the following way: 
If the score cutoff of the 91th score percentile is 0.9834, and we read a bad rate of 0.6449, this means that if 0.9834 is used as a threshold to classify loans as bad, we would have a bad rate of 64.49%. This bad rate is equal to the number of observed bad loans over the total number of loans with a score greater than the threshold.</p>

<p>The second, <code>apply_score_transformation</code> will:</p>

<ol>
  <li>
    <p>Apply the same sigmoid function to the output scores of the logistic regression, in order to spread them in [0,1].</p>
  </li>
  <li>
    <p>Asssign each score to a percentile bin with the bad rates given by the <code>Operational_Metrics</code> table.</p>
  </li>
</ol>

<h3>Input:</h3>
<p class="hdi">(assume the predictions on the testing set, <code>PredictionsLogistic</code>, are already created there by Step 3)</p>
<ul>
  <li class="sql"><code>Predictions_Logistic</code> SQL table storing the predictions from the tested model.</li>
  <li class="hdi">Working directories on the edge node and HDFS.</li>

</ul>

<h3>Output:</h3>

<ul>
  <li class="sql"><code>Operational_Metrics</code> SQL table and data frame containing the percentiles from 1% to 99%, the scores thresholds each one corresponds to, and the observed bad rate among loans with a score higher than the corresponding threshold.</li>
  <li class="sql"><code>Scores</code> SQL table containing the transformed scores for each record of the testing set, together with the percentiles they belong to, the corresponding score cutoff, and the observed bad rate among loans with a higher score than this cutoff.</li>
  <li class="sql"><code>Scores_Average</code> SQL table , with the average score on the testing set, to be used in a future Production stage.</li>
  <li class="hdi">Average of the predicted scores on the testing set of the Development stage, saved to the local edge node in the <strong>LocalModelsDir</strong> folder.</li>
  <li class="hdi">Operational Metrics saved to the local edge node in the <strong>LocalModelsDir</strong> folder.</li>
  <li class="hdi"><code>Scores</code> on HDFS in xdf format. It contains the transformed scores for each record of the testing set, together with the percentiles they belong to, the corresponding score cutoff, and the observed bad rate among loans with a higher score than this cutoff.</li>
  <li class="hdi"><code>ScoresData</code> on HDFS in Hive format for visualizations in PowerBI.</li>
</ul>

<h3>Related files:</h3>

<ul>
  <li><strong>step4_operational_metrics.R</strong></li>
</ul>

<p>The <strong>modeling_main.R</strong> script uses the <code>Operational_Metrics</code> table to plot the rates of bad loans among those with scores higher than each decision threshold. The decision thresholds correspond to the beginning of each percentile-based bin.</p>

<p><img src="images/step4bis.png?raw=true" alt="Visualize" /></p>

<p>For example, if the score cutoff of the 91th score percentile is 0.9834, and we read a bad rate of 0.6449. This means that if 0.9834 is used as a threshold to classify loans as bad, we would have a bad rate of 64.49%. This bad rate is equal to the number of observed bad loans over the total number of loans with a score greater than the threshold.</p>

<div class="hdi">
<h2 id="update">Updating the Production Stage Directory (“Copy Dev to Prod”)</h2>
<hr />
<p>At the end of the main function of the script <strong>development_main.R</strong>, the <strong>copy_dev_to_prod.R</strong> script is invoked in order to copy (overwrite if it already exists) the model, statistics and other data from the Development Stage to a directory of the Production or Web Scoring stage.</p>

<p>If you do not wish to overwrite the model currently in use in a Production stage, you can either save them to a different directory, or set <code>update_prod_flag</code> to <code>0</code> inside the main function.</p>
</div>

<div class="hdi">
<h2 id="production">Production Stage</h2>
<hr />

<p>In the Production stage, the goal is to perform a batch scoring.</p>

<p>The script <strong>production_main.R</strong> will complete this task by invoking the scripts described above. The batch scoring can be done either:</p>

<ul>
  <li>In-memory : The input should be provided as data frames. All the preprocessing and scoring steps are done in-memory on the edge node (local compute context). In this case, the main batch scoring function calls the R script “in_memory_scoring.R”.</li>
  <li>Using data stored on HDFS: The input should be provided as paths to the Production data sets. All the preprocessing and scoring steps are one on HDFS in Spark Compute Context.</li>
</ul>

<p>When the data set to be scored is relatively small and can fit in memory on the edge node, it is recommended to perform an in-memory scoring because of the overhead of using Spark which would make the scoring much slower.</p>

<p>The script:</p>

<ul>
  <li>Lets the user specify the paths to the Production working directories on the edge node and HDFS (only used for Spark compute context).</li>
  <li>Lets the user specify the paths to the Production data sets Loan and Borrower (Spark Compute Context) or point to them if they are data frames loaded in memory on the edge node (In-memory scoring).</li>
</ul>

<p>The computations described in the Development stage are performed, with the following differences:</p>

<ul>
  <li>The global means and modes used to clean the data are the ones used in the Development Stage. (Step 1)</li>
  <li>The cutoffs used to bucketize the numeric variables are the ones used in the Development Stage. (Step 2)</li>
  <li>The variables information (in particular levels of factors) are uploaded from the Development Stage. (Step 2)</li>
  <li>No splitting into a training and testing set, no training and no model evaluation are performed. Instead, the logistic regression model created in the Development Stage is loaded and used for predictions on the new data set. (Step 3)</li>
  <li>Operational metrics are not computed. The one created in the Development Stage is used for score transformation on the predictions. (Step 4)</li>
</ul>

<div class="alert alert-info">
If you get the following: “Error: file.exists(inData1) is not TRUE”, you should reset your R session with Ctrl + Shift + F10 (or Session &gt; Restart R) and try running it again.</div>

<h2 id="web">Deploy as a Web Service</h2>
<hr />

<p>In the script <strong>deloyment_main.R</strong>, we define a scoring function and deploy it as a web service so that customers can score their own data sets locally/remotely through the API. Again, the scoring can be done either:</p>

<ul>
  <li>In-memory : The input should be provided as data frames. All the preprocessing and scoring steps are done in-memory on the edge node (local compute context). In this case, the main batch scoring function calls the R script <strong>in_memory_scoring.R</strong>.</li>
  <li>Using data stored on HDFS: The input should be provided as paths to the Production data sets. All the preprocessing and scoring steps are one on HDFS in Spark Compute Context.</li>
</ul>

<p>When the data set to be scored is relatively small and can fit in memory on the edge node, it is recommended to perform an in-memory scoring because of the overhead of using Spark which would make the scoring much slower.</p>

<p>This is done in the following way:</p>
<ol>
<li>Log into the R server that hosts the web services as admin. Note that even if you are already on the edge node, you still need to perform this step for authentication purpose.</li>

<li> Specify the paths to the working directories on the edge node and HDFS.</li>

<li>  Specify the paths to the input data sets Loan and Borrower or point to them if they are data frames loaded in memory on the edge node.</li>

<li>  Load the static .rds files needed for scoring and created in the Development Stage. They are wrapped into a list called “dev_objects” which will be published along with the scoring function.</li>

<li>  Define the web scoring function which calls the steps like for the Production stage.</li>

<li>  Publish as a web service using the publishService function. Two web services are published: one for the string input (Spark Compute Context) and one for a data frame input (In-memory scoring in local compute context). 
In order to update an existing web service, use updateService function to do so.
Note that you cannot publish a new web service with the same name and version twice, so you might have to change the version number.</li>

<li>  Verification:
<ul>
  <li>
    Verify the API locally: call the API from the edge node.
  </li>
  <li>
    <p>Verify the API remotely: call the API from your local machine. You still need to remote login as admin from your local machine in the beginning. It is not allowed to connect to the edge node which hosts the service directly from other machines. The workaround is to open an ssh session with port 12800 and leave this session on. Then, you can remote login. Use getService function to get the published API and call the API on your local R console.</p>
  </li>
</ul>
</li>
</ol>

</div>


<p><a name="viz"></a></p>
<h2>Visualize Results</h2>
<hr />
<div class="sql">
The final scores reside in the table <code>Scores</code> of the <code>Loans</code> database. The production data is in a new database, <code>Loans_Prod</code>, in the table <code>Scores_Prod</code>. The final step of this solution visualizes both predictions tables in PowerBI.
</div>
<div class="hdi">
The final scores reside in the Hive table <code>Scores</code>. The production results are in the Hive table <code>Scores_Prod</code> and <code>Merged_Prod</code>. The final step of this solution visualizes predictions of both the test and productions results. 
</div>

<p></p>
<ul>
  <li>See <a href="business-manager.html">For the Business Manager</a> for details of the PowerBI dashboard.</li>
</ul>

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

<h2 id="template-contents">Template Contents</h2>
<hr />

<ul>
  <li><a href="contents.html">View the contents of this solution template</a>.</li>
</ul>

<p>To try this out yourself:</p>

<ul>
  <li>View the <a href="START_HERE.html">Quick Start</a>.</li>
</ul>

<p><a href="index.html">&lt; Home</a></p>