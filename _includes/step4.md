
<h2> Step 4: Deploy and Visualize with Bernie the Business Analyst </h2>
----------------------------------------------------------------

Now that the predictions are created  we will meet our last persona - Bernie, the Business Analyst. Bernie will use the Power BI Dashboard to examine the test data to find an appropriate score cutoff, then use that cutoff value for a new set of loan applicants.

{% include pbix.md %}





### Test Data Tab 

<img src="images/test.jpg">
The output scores from the model have been binned according to the percentiles: the higher the percentile, and the most likely the risk of default. Bernie uses the slider showing these percentiles at the top right to find a suitable level of risk for extending a loan.  He sets the slider to 80-99 to show the top 20% of scores.  The cutpoint value for this is shown in yellow and he uses this score cutpoint to classify new loans - predicted scores higher than this number will be rejected. 

The Loan Summary table divides those loans classified as bad in two: those that were indeed bad (Bad Loan = Yes) and those that were in fact good although they were classified as bad (Bad Loan = No). For each of those 2 categories, the table shows the number, total and average amount, and the average interest rate of the loans. This allows you to see the expected impact of choosing this cutoff value.

### New Loans Tab 
<img src="images/prod.jpg">
Now Bernie switches to the New Loans tab to view some scored potential loans.  He uses the cutoff value from the first tab and views information about these loans.  He sees he will reject 9 of the 22 potential loans based on this critera.

<div class="alert alert-info" role="alert">
The PowerBI file has cached data in it.  You can use these <a href="Visualize_Results.html">steps to refresh the PowerBI data</a>.
</div>  
