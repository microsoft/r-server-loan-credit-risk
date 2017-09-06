
You are ready to follow along with Debra as she creates the scripts needed for this solution. <span class="sql"> If you are using Visual Studio, you will see these file in the <code>Solution Explorer</code> tab on the right. In RStudio, the files can be found in the <code>Files</code> tab, also on the right. </span> 

<div class="hdi">
The steps described below each create a function to perform their task.  The individual steps are described in more detail below.  The following scripts are then used to execute the steps. 
<p></p> 
<ul>
<li>To create the model and score test data, Debra runs <strong>development_main.R</strong> which invokes steps 1-4 described below.
<p></p>
The default input for this script generates 1,000,000 rows for training models, and will split this into train and test data.  After running this script you will see data files in the <strong>/var/RevoShare/&lt;username&gt;/LoanCreditRisk/dev/temp</strong> directory.  Models are stored in the <strong>/var/RevoShare/&lt;username&gt;/LoanCreditRisk/dev/model</strong> directory. The Hive table <code>ScoresData</code> contains the the results for the test data.  Finally, the model is copied into the  <strong>/var/RevoShare/&lt;username&gt;/LoanCreditRisk/prod/model</strong> directory for use in production mode.
<p></p>
</li>
<li>After completing the model, Debra next runs <strong>production_main.R</strong>, which invokes steps 1, 2, and 3 using the production mode setting.
<strong>production_main.R</strong> uses the previously trained model and invokes the steps to process data, perform feature engineering and scoring. 
The input to this script defaults to 22 applicants to be scored with the model in the <strong>prod</strong> directory. After running this script the Hive table <code>ScoresData_Prod</code> now contains the scores for these  applicants.  Note that if the data to be scored is sufficiently small, it is faster to provide it as a data frame; the scoring will then be performed in-memory and will be much faster.  If the input  provided is paths to the input files, scoring will be performed in the Spark Compute Context.
<p></p>
</li>
<li> Once all the above code has been executed, Debra will create a PowerBI dashboard to visualize the scores created from her model. 
<p></p>
</li>
</ul>
</div>

<ul>
<li class="sql">
<strong>modeling_main.R</strong> is used to define the input and call all these steps. The inputs are pre-poplulated with the default values created for a VM from the Cortana Intelligence Gallery.  You must  change the values accordingly for your implementation if you are not using the default server (<code>localhost</code> represents a server on the same machine as the R code).  If you are connecting to an Azure VM from a different machine, the server name can be found in the Azure Portal under the "Network interfaces" section - use the Public IP Address as the server name. 
</li>

<li class="sql">To run all the steps described below, open and execute the file <strong>modeling_main.R</strong>.  You may see some warnings regarding <code>rxClose()</code>. You can ignore these warnings.
</li>
</ul>
<div class="alert alert-info" role="alert">
In <span class="sql">both Visual Studio and</span> RStudio, there are multiple ways to execute the code from the R Script window.  The fastest way <span class="sql">for both IDEs</span> is to use Ctrl-Enter on a single line or a selection.  Learn more about  <span class="sql"><a href="http://microsoft.github.io/RTVS-docs/">R Tools for Visual Studio</a> or</span> <a href="https://www.rstudio.com/products/rstudio/features/">RStudio</a>.

</div>





Below is a summary of the individual steps invoked when running the main script<span class="hdi">s</span>. 

<ol>
<li>
The first few steps prepare the data for training.

<ul>

<li>	<strong>step1_preprocessing.R</strong>:  Uploads data and performs preprocessing steps -- merging of the <a href="input_data.html">input data sets</a> and missing value treatment.  </li>

<li>	<strong>step2_feature_engineering.R</strong>:   Creates the label <code>isBad</code> based on the status of the loan, splits the cleaned data set into a Training and a Testing set, and bucketizes all the numeric variables, based on Conditional Inference Trees on the Training set.  </li>
</ul>

 </li>   


<li>  <strong>step3_train_score_evaluate.R</strong> will train a logistic regression classification model on the training set, and save it<span class="sql"> to SQL</span>. In development mode, this script then scores the logisitic regression on the test set and evaluates the tested model. In production mode, the entire input data is used and no evaluation is performed.
<p></p>
</li>

<li> Finally  <strong>step4_operational_metrics.R</strong> computes the expected bad rate for various classification decision thresholds and  applies a score transformation based on operational metrics. 
<p></p>
</li>
<li>After step4, the development script runs <strong>copy_dev_to_prod.R</strong> to copy the model information from the <strong>dev</strong> folder to the <strong>prod</strong> folder for use in production or web deployment.
<p></p>
</li>
<li>A summary of this process and all the files involved is described in more detail on the <a href="data-scientist.html">For the Data Scientist</a> page.
</li>
</ol>
