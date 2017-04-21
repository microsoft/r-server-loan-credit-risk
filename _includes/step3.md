
## Step 3: Operationalize with Debra and Danny
------------------------------------------------

Debra has completed her tasks.  She has connected to the SQL database, executed code from her R IDE that pushed (in part) execution to the SQL machine to create and transform scores. She has also created a summary dashboard which she will hand off to Bernie - see below.

Debra hands over her scripts to Danny who adds the code to the database as stored procedures, using embedded R code, and SQL queries.  You can see these procedures by logging into SSMS and opening the `Programmability>Stored Procedures` section of the `{{ site.db_name }}` database.  These stored procedures will then be used to score applicatants in the production pipeline.  

<div class="alert alert-info" role="alert">
Log into SSMS with SQL Server Authentication, user <code>rdemo</code> - the default password upon creating the solution was <code>D@tascience</code>, unless you changed this password.
</div>