

<h2> Step 3: Operationalize with Debra <span class="sql">and Danny</span></h2>
<hr />
<p/>
Debra has completed her tasks.  <span class="sql">She has connected to the SQL database, executed code from her R IDE that pushed (in part) execution to the SQL machine to create and transform scores.</span>
<span class="hdi">She has executed code from RStudio that pushed (in part) execution to Hadoop to create and transform scores.</span> 
She has also created a summary dashboard which she will hand off to Bernie - see below.
<p/>

<div class="sql">
While this task is complete for the current set of borrowers, we will need to score new loans on an ongoing basis.  Instead of going back to Debra each time, Danny can operationalize the code in TSQL files which he can then run himself whenver new loans appear.
Debra hands over her scripts to Danny who adds the code to the database as stored procedures, using embedded R code, or SQL queries.  You can see these procedures by logging into SSMS and opening the <code>Programmability>Stored Procedures</code> section of the <code>Loans</code> database.
<p/>
Log into SSMS using the <code>rdemo</code> user with SQL Server Authentication - the default password upon creating the solution was <code>D@tascience</code>, unless you changed this password.
<p/>
You can find this script in the <strong>SQLR</strong> directory, and execute it yourself by following the <a href="Powershell_Instructions.html">PowerShell Instructions</a>.  
<span class="cig">As noted earlier, this was already executed when your VM was first created.</span>
<span class="onp"> As noted earlier, this is the fastest way to execute all the code included in this solution.  (This will re-create the same set of tables and models as the above R scripts.)
</span>
</div>

<div class="hdi">
<p/>
While this task is complete for the current set of borrowers, we will need to score new loans on an ongoing basis. 
In the steps above, we saw the first way of scoring new data, using <strong>production_main.R</strong> script. 
Debra may also create an analytic web service  with <a href="https://msdn.microsoft.com/en-us/microsoft-r/operationalize/about">R Server Operationalization</a> that incorporates these same steps: data processing, feature engineering, and scoring.
<p/>
 <strong>deployment_main.R</strong> will create a web service and test it on the edge node.  
<p/>
<div class="alert alert-info" role="alert">
The operationalization server has been configured for you on the edge node of your cluster.
Follow <a href="deployr.html">instructions here</a> if you wish to connect to the edge node and/or use the admin utility.
</div>
<p/>
The service can also be used by application developers, which is not shown here.
<p/>
</div>
