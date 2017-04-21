
<h2> Step 4: Deploy and Visualize with Bernie the Business Analyst </h2>
----------------------------------------------------------------

Now that the predictions are created  we will meet our last persona - Bernie, the Business Analyst. Bernie will use the Power BI Dashboard to examine the test data to find an appropriate score cutoff, then use that cutoff value for a new set of loan applicants

{% include pbix.md %}



<div class="alert alert-info" role="alert">
Remember that before the data in this dashboard can be refreshed to use your scored data, you must <a href="Visualize_Results.html">configure the dashboard</a> as Debra did in step 2 of this workflow.
</div>



On the Test Data tab, Bernie uses the checkboxes at the top right to find a suitable level of risk for extending a loan.  He starts by unchecking all boxes, which shows the entire test set.  Then starting at the top (99%), he checks consecutive boxes to view characteristics of those loans whose scores fall into that percentile or above. The Loan Summary table shows how many loans, the total and average amount, and the average interest rate for those loans that are not bad (isBad = False) as well as those that are truly bad (isBad = True). This allows him to see how many good loans he would be rejecting if he were to use this cutoff value.

Directly below the checkboxes is the actual cutoff value to use for the current loans, as well as the bad loan rate associated with this cutoff value - for percentiles of 80 and above, the value is .47. 
<img src="images/test.jpg">

Now Bernie switches to the Prod Data tab to view some scored potential loans.  He uses the .47 cutoff value and views information about these loans.  He sees he will reject 9 of the 22 potential loans based on this critera.
<img src="images/prod.jpg">
  
