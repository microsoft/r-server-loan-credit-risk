SQL Server on the VM has been set up with the username and password you specified during deployment.  If you wish to change the password, connect to the VM, log into SSMS with Windows Authentication and execute the following query:

```  
        ALTER LOGIN rdemo WITH PASSWORD = 'newpassword';  
```     
