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
{% include choices.md %}
</div> 

## For the Business Manager
------------------------------

This solution is based on simulated data for a small personal loan financial institution, containing the borrower's financial history as well as information about the requested loan.  It uses predictive analytics to help decide whether or not to grant a loan for each borrower.
<p></p>
<div class="sql"> 
SQL Server R Services takes advantage of the power of SQL Server 2016 and ScaleR (Microsoft R Server package) by allowing R to run on the same server as the database. It includes a database service that runs outside the SQL Server process and communicates securely with the R runtime. 
<p></p>
This solution package shows how to create and refine data, train R models, and perform predictions in-database. The final table in the SQL Server database provides a predicted value for each borrower. This predicted value can help you determine whether you wish to approve the loan.
<p></p>
</div>
<div class="hdi">
Microsoft R Server on HDInsight Spark clusters provides distributed and scalable machine learning capabilities for big data, leveraging the combined power of R Server and Apache Spark. This solution demonstrates how to develop machine learning models for marketing campaign optimization (including data processing, feature engineering, training and evaluating models), deploy the models as a web service (on the edge node) and consume the web service remotely with Microsoft R Server on Azure HDInsight Spark clusters. 
<p></p>
The final table is saved to a Hive table containing XXX. This data is then visualized in Power BI.
<p></p>
</div>
On the Test Data tab, you can use the checkboxes at the top right to find a suitable level of risk for extending a loan.  Start by unchecking all boxes, which shows the entire test set.  Then starting at the top (99%), chekck consecutive boxes to view characteristics of those loans whose scores fall into that percentile or above. The Loan Summary table shows how many loans, the total and average amount, and the average interest rate for those loans that are not bad (isBad = False) as well as those that are truly bad (isBad = True). This allows you to see how many good loans you would be rejecting if you were to use this cutoff value.
<p></p>
Directly below the checkboxes is the actual cutoff value to use for the current loans, as well as the bad loan rate associated with this cutoff value - for percentiles of 80 and above, the value is .47. 
<img src="images/test.jpg">
<p></p>
On the Prod Data tab you will see some scored potential loans.  This page is using  .47 as the cutoff value.  You will reject 9 of the 22 potential loans based on this critera.  (Using PowerBI Desktop, you can change this cutoff to a different value.)
<img src="images/prod.jpg">
 <p></p> 

{% include pbix.md %}


To understand more about the entire process of modeling and deploying this example, see [For the Data Scientist](data-scientist.html).
 

[&lt; Home](index.html)
