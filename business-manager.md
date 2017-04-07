---
layout: default
title: For the Business Manager
---

## For the Business Manager
------------------------------

This solution template uses XXXDESCRIBE TYPE OF DATA data to XXX.
 
SQL Server R Services takes advantage of the power of SQL Server 2016 and ScaleR (Microsoft R Server package) by allowing R to run on the same server as the database. It includes a database service that runs outside the SQL Server process and communicates securely with the R runtime. 

This solution package shows XXXSOMETHING HERE. The final table in the SQL Server database provides XXXSOME PREDICTION USED FOR SOMETHING OR ANOTHER. This data is then visualized in Power BI.  XXXSHOW PICT OF DASHBOAORD HERE.


![Visualize](images/XXvisualize.png?raw=true)


You can try out this dashboard in either of the following ways:

* Visit the [online version]({{ site.pbix_view_url }}).

*  <a href="https://powerbi.microsoft.com/en-us/desktop/" target="_blank">Install PowerBI Desktop</a> and 
<a href="site.pbix_download_url" target="_blank">download and open the {{ site.solution_name }} Dashboard</a> to see the simulated results.

You can use the predicted scores to help determine whether or not to grant a loan.  You can fine tunes the prediction by using the PowerBI Dashboard to see the number of loans and the total dollar amount saved under different scenarios.  The dashboard includes a filter based on percentiles of the predicted scores.  When all the values are selected, the display includes all the loans in the testing sample, and you can inspect information about how many of them defaulted.  Then by checking just the top percentile (100), you drills down to information about loans with a predicted score in the top 1%.  Checking multiple continuous boxes allows you to find a cutoff point you are comfortable with to use as a future loan acceptance criteria.


To understand more about the entire process of modeling and deploying this example, see [For the Data Scientist](data-scientist.html).
 

[&lt; Home](index.html)
