
<div class="sql">
<h2> Step 1: Server Setup and Configuration with Danny the DB Analyst</h2>
<hr />
<p>
Let me introduce you to  Danny, the Database Analyst. Danny is the main contact for anything regarding the SQL Server database that contains <a href="input_data.html">borrower and loan data</a>.  </p>

<p>Danny was responsible for installing and configuring the SQL Server.  He has added a user named <code>rdemo</code> with all the necessary permissions to execute R scripts on the server and modify the <code>{{ site.db_name }}</code> database. This was done through the <strong>create_user.sql</strong> file.  </p>
</div>
<div class="hdi">
<h2> Step 1: Server Setup and Configuration with Ivan the IT Administrator</h2>
<hr />

<p>Let me introduce you to Ivan, the IT Administrator. Ivan is responsible for implementation as well as ongoing administration of the Hadoop infrastructure at his company, which uses <a href="https://azure.microsoft.com/en-us/solutions/hadoop/">Hadoop in the Azure Cloud from Microsoft</a>. Ivan created the <a href="https://docs.microsoft.com/en-us/azure/hdinsight/hdinsight-hadoop-r-server-get-started">HDInsight cluster with R Server</a> for Debra. He also uploaded the data onto the storage account associated with the cluster.</p>

</div>
