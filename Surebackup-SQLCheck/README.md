# Surebackup SQL Check
**Author:** Timothy Dewin
**Function:** Allows you to verifiy if SQL is succesfully working in your Virtual Lab (Surebackup)
**Requires:** Backup & Replication v9
**Usage:** Schedule the script via the Application Group or via the "Surebackup" job > "Linked Job" section. Configure credentials in the application group. Use the -server parameter to pass the ip of the server
**Parameters:**
* -server %vm_ip%
** What is the masked IP of the SQL server, use %vm_ip% in the Surebackup setup.
* -instance MSSQLSERVER
** What is the instance name
* -minimumdb 4
** What are the minimum amount of DBs that should be detected when connecting.  By default this is 4 to account for : master, model, msdb, tempdb