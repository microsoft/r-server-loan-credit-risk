---
layout: default
title: Visualizing Results with PowerBI
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

## Visualizing Results with PowerBI
-----------------------------------

These instructions show you how to replace the cached data in the PowerBI dashboard with data from your 
<span class="sql">SQL Server</span>
<span class="hdi">HDInsight</span> 
solution, by using an ODBC connection to the 
<span class="sql">SQL Database</span>
<span class="hdi">Hive</span> table. 

All but the last step only need to be performed once. After you have performed this once, you can simply <a href="#laststep">
skip to the last step</a> to see new results after any new model scoring. 
<ol>
<li> Set up Connection between SQL Server and PowerBI  using <a href="ODBC.html">these instructions</a>.
</li>

<li> 	Open the 
<span class="sql"><code>{{ site.pbix_download_url }}</code></span>
<span class="hdi"><code>{{ site.pbix_hdidownload_url }}</code></span>
 file in the {{ site.folder_name }} folder. Click on <code>Get Data</code> and select <code>More...</code>
The PowerBI dashboard will show charts built from cached data. We need to set it up to use the latest available scored dataset in the SQL Server.
 <br/>
 <img src="images/vis1.png" >
</li>

<li> 	Select <code>Get Data</code> then <code>Other</code> and then select<code>ODBC</code> and Click <code>OK</code>
 <br/>
 <img src="images/vis2.png" >
</li>

<li> 	Under Data Source Name Enter <code>Campaign</code> and click <code>OK</code>
 <br/>
 <img src="images/vis3.png" width="60%" >
</li>

<li class="sql">	Navigate to Campaign >  dbo and check Recommendations. Click <code>Load</code>.
 <br/>
 <img src="images/vis4.png"  >
</li>
<li class="hdi">Navigate to Spark > default and check recommendations.  Click <code>Load</code>.
</li>

<li> 	Once the data is loaded. Click on <code>Edit Queries</code>. You will see this new window
 <br/>
 <img src="images/vis5.png"  >
    Notice that on the left hand side you have 2 datasets: <code>Lead_Scored_Dataset</code> and <code>Recommendations</code>. 
</li>

<li> 	Click on the second dataset (<code>Recommendations</code>) and then click on <code>Advanced Editor</code> in the toolbar. Select and copy all the code in the dialog that appears.  Then click <code>Done</code> to close this dialog.
</li>

<li> 	Next, click on the first dataset (<code>Lead_Scored_Dataset</code>) and then click on ‘Advanced Editor’ in the toolbar. Delete all the code here and paste what you just copied into this dialog.  Click <code>Done</code> to close this dialog.  You should see the earlier warning disappear and be replaced with a table of data.  This is the data from the SQL database.  
</li>

<li> 	Next, click on the second dataset (<code>Recommendations</code>)  and press the delete key on your keyboard. You will see a pop up asking if you want to delete it. Click on <code>Delete</code>.  
 <br/>
 <img src="images/vis8.png"  >
</li>

<li> 	Next, click on <code>Close</code> and <code>Apply</code>. This will refresh the backend data on the PowerBI and connect it to the SQL Server.
 <br/>
 <a name="laststep" id="laststep"></a>
</li>

<li> 	Press <code>Refresh</code>. This should refresh the back end data of the dashboard and refresh the visuals.  You are now viewing data from your <span class="sql">SQL Database</span><span class="hdi">Hive table</span>, rather than the imported data that was part of the initial solution package.  Updates from the <span class="sql">SQL Database</span><span class="hdi">Hive table</span> will be reflected each time you hit <code>Refresh</code>. 
 <br/>
 <img src="images/vis10.png" >
</li>
</ol>

[&lt; Home](index.html)