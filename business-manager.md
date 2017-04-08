---
layout: default
title: For the Business Manager
---
<div class="alert alert-success" role="alert"> This page describes the 
<strong>
<span class="cig">{{ site.cig_text }}</span>
<span class="onp">{{ site.onp_text }}</span>
<span class="hdi">{{ site.hdi_text }}</span> 
</strong>
solution.
</div> 

## For the Business Manager
------------------------------

This solution template uses (simulated) historical data to predict **how** and **when** to contact leads for your campaign. The recommendations include the **best channel** to contact a lead (in our example, Email, SMS, or Cold Call), the **best day of the week** and the **best time of day** during which to make the contact.  

<div class="sql"> 
SQL Server R Services takes advantage of the power of SQL Server 2016 and ScaleR (Microsoft R Server package) by allowing R to run on the same server as the database. It includes a database service that runs outside the SQL Server process and communicates securely with the R runtime. 

This solution package shows how to create and refine data, train R models, and perform predictions in-database. The final table in the SQL Server database provides XXX. This data is then visualized in Power BI. 

</div>
<div class="hdi">
Microsoft R Server on HDInsight Spark clusters provides distributed and scalable machine learning capabilities for big data, leveraging the combined power of R Server and Apache Spark. This solution demonstrates how to develop machine learning models for marketing campaign optimization (including data processing, feature engineering, training and evaluating models), deploy the models as a web service (on the edge node) and consume the web service remotely with Microsoft R Server on Azure HDInsight Spark clusters. 

The final  table is saved to a Hive table containing XXX. This data is then visualized in Power BI.
</div>



![Visualize](images/visualize.png?raw=true)


{% include pbix.md %}

XXXDESCRIBE

To understand more about the entire process of modeling and deploying this example, see [For the Data Scientist](data-scientist.html).
 

[&lt; Home](index.html)
