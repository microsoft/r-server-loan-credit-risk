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
SQL Server R Services takes advantage of the power of SQL Server 2016 and RevoScaleR (Microsoft R Server package) by allowing R to run on the same server as the database. It includes a database service that runs outside the SQL Server process and communicates securely with the R runtime. 
<p></p>
This solution shows how to preprocess data, create new features, train R models, and perform predictions in-database. The final table in the SQL Server database provides a predicted value for each borrower. This predicted value, which can be interpreted as a probability of default, can help you determine whether you wish to approve the loan.
<p></p>
</div>
<div class="hdi">
Microsoft R Server on HDInsight Spark clusters provides distributed and scalable machine learning capabilities for big data, leveraging the combined power of R Server and Apache Spark. This solution demonstrates how to develop machine learning models for loan credit risk (including data processing, feature engineering, training and evaluating models), deploy the models as a web service (on the edge node) and consume the web service remotely with Microsoft R Server on Azure HDInsight Spark clusters. 

<p></p>
Hive tables are saved containing the predicted scores during both development and production. This data is then visualized in Power BI.
<p></p>
</div>

The PowerBI dashboard allows you to visualize and use these predicted scores to aid in deciding when to approve a loan.  There are two different tabs: the Test Data tab lets you explore the scores in the test data in order to decide on a cutoff value to use in the decision to reject a loan.  The Prod Data tab shows new potential loans in the production pipeline where you can view the results of using this cutoff value.  

### Test Data Tab
<img src="images/test.jpg">
The output scores from the model have been binned according to percentiles: the higher the percentile, the more likely the risk of default.  On the Test Data tab, you can use the slider at the top right to examine loans in the test data that correspond to these percentiles. The slider at the is set to show the top 20% of scores (Score Percentile from 80-99%).  The box in yellow will show the corresponding cutpoint that can be used to classify these loans as bad.  The default value of .4933 (corresponding to the top 20% in the training data) is used in the Loan Summary tab.

<p></p>
The Loan Summary table divides those loans classified as bad in two: those that were indeed bad (Bad Loan = Yes) and those that were in fact good although they were classified as bad (Bad Loan = No). For each of these 2 categories, the table shows the number, total and average amount, and the average interest rate of the loans. This allows you to see the expected impact of choosing this cutoff value.
<p></p>

### New Loans Tab
<img src="images/prod.jpg">
On the New Loans tab you will see some scored potential loans. This page is using .4933 as the cutoff value. You will reject 9 of the 22 potential loans based on this critera. (With PowerBI Desktop, you can change this cutoff to a different value.)

 <p></p> 

{% include pbix.md %}


To understand more about the entire process of modeling and deploying this example, see [For the Data Scientist](data-scientist.html).
 

[&lt; Home](index.html)
