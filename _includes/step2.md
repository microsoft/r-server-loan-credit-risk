
Now you're ready to follow along with Debra as she creates the scripts needed for this solution. <span class="sql"> If you are using Visual Studio, you will see these file in the <code>Solution Explorer</code> tab on the right. In RStudio, the files can be found in the <code>Files</code> tab, also on the right. </span> 

<div class="hdi">The steps described below each create a function to perform their task.  The individual steps are described in more detail below.  The following scripts are then used to execute the steps.  
<ul><li>
<strong>campaign_main.R</strong> is used to define the data and directories and then run all of the steps to process data, perform feature engineering, training, and scoring.  
<p></p>
The default input for this script uses 100,000 leads for training models, and will split this into train and test data.  After running this script you will see data files in the <strong>/var/RevoShare/sshuser/Campaign/dev/temp</strong> directory.  Models are stored in the <strong>/var/RevoShare/sshuser/Campaign/dev/model</strong> directory. The Hive table <code>recommendations</code> contains the 100,000 records with recommendations (<code>recommended_day</code>, <code>recommended_time</code> and <code>recommended_channel</code>) created from the best model.
</li>
<li>
<strong>Copy_Dev2Prod.R</strong> copies the model information from the <strong>dev</strong> folder to the <strong>prod</strong> folder to be used for production.  This script must be executed once after <strong>campaign_main.R</strong> completes, before running <strong>campaign_scoring.R</strong>.  It can then be used again as desired to update the production model. 
<p></p>
After running this script models created during <strong>campaign_main.R</strong> are copied into the <strong>/var/RevoShare/sshuser/Campaign/prod/model</strong> directory.
</li>
<li>
<strong>XXX_scoring.R</strong> uses the previously trained model and invokes the steps to process data, perform feature engineering and scoring.  Use this script after first executing <strong>XXX_main.R</strong> and <strong>Copy_Dev2Prod.R</strong>.
<p></p>
The input to this script defaults to XXX applicants to be scored with the model in the <strong>XXX</strong> directory. After running this script the Hive table <code>XXX</code> now contains the scores for these XXX applicants.  
</li></ul>
</div>

Below is a summary of the individual steps used for this solution. 
<div class="alert alert-info" role="alert">
<div class="sql">
<strong>modeling_main.R</strong> is used to define the input and call all these steps. The inputs are pre-poplulated with the default values created for a VM from the Cortana Intelligence Gallery.  You must  change the values accordingly for your implementation if you are not using the default server (<code>localhost</code> represents a server on the same machine as the R code),  user (<code>rdemo</code>), and password (<code>D@tascience</code>).  If you are connecting to an Azure VM from a different machine, the server name can be found in the Azure Portal under the "Network interfaces" section - use the Public IP Address as the server name. The user and the password can be modified from the script <strong>create_user.sql</strong> 
<p/>
</div>
<div class=" hdi" >
To run all the steps described below, open and execute the file <strong>XXX_main.R</strong>.
<p/>
</div>
In <span class="sql">both Visual Studio and</span> RStudio, there are multiple ways to execute the code from the R Script window.  The fastest way <span class="sql">for both IDEs</span> is to use Ctrl-Enter on a single line or a selection.  Learn more about  <span class="sql"><a href="http://microsoft.github.io/RTVS-docs/">R Tools for Visual Studio</a> or</span> <a href="https://www.rstudio.com/products/rstudio/features/">RStudio</a>.

</div>

<ol>


<li>
The first few steps prepare the data for training.


<ul>

<li>	<strong>step1_preprocessing.R</strong>:  Uploads data and performs preprocessing steps -- merging of the <a href="input_data.html">input data sets</a> and missing value treatment.  </li>

<li>	<strong>step2_feature_engineering.R</strong>:   Creates the label <code>isBad</code> based on the status of the loan, splits the cleaned data set into a Training and a Testing set, and bucketizes all the numeric variables, based on Conditional Inference Trees on the Training set.  </li>
</ul>

 </li>   

 <li class="sql">  After running the step1 and step2 scripts, Debra goes to SQL Server Management Studio to log in and view the results of feature engineering by running the following query:
        
<pre class="highlight">
SELECT TOP 1000 *
FROM [Loans].[dbo].[Merged_Features]
</pre>
</li>

<li>  Now she is ready for training the models, using <strong>step3_train_score_evaluate.R</strong>.  This step will train a logistic regression classification model on the training set, save it to SQL, score the logisitc regression on the test set, and evaluate the tested model.
<p></p>
</li>

<li> Finally  <strong>step4_operational_metrics.R</strong> computes the expected bad rate for various classification decision thresholds and  applies a score transformation based on operational metrics. 
<p></p>
</li>
<li class="hdi">
After creating the model, Debra runs <strong>Copy_Dev2Prod.R</strong> to copy the model information from the <strong>dev</strong> folder to the <strong>prod</strong> folder, then runs <strong>campaign_scoring.R</strong> to create recommendations for her new data. 
</li>
<li> Once all the above code has been executed, Debra will create a PowerBI dashboard to visualize the scores created from her model. 

{% include pbix.md %}

She uses an ODBC connection to connect to the data, so that it will always show the most recently modeled and scored data.
  <div class="alert alert-info" role="alert">
  If you want to refresh data in your PowerBI Dashboard, make sure to <a href="Visualize_Results.html">follow these instructions</a> to setup and use an ODBC connection to the dashboard.
  </div>
</li>
<li>A summary of this process and all the files involved is described in more detail on the <a href="data-scientist.html">For the Data Scientist</a> page.
</li>
</ol>