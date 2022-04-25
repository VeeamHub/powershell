*NOTE: CSV export of the output sample included.*

**Functionality of the script:**  
The script will start by checking the repositories attached to the B&R server to determine if the repository is configured for per-VM backups.  
It will also check each extent within a scale-out repository, but will only consider the SOBR repository to be set for per-VM backups if each extent is configured as such.  
It will then query every backup and backup copy job from the B&R server and where the type is a VMware vSphere job.  
From there, we get the backup size from each file in the backup job.  
The next step is based on whether the repository is configured for per-VM backups or not.  
- If configured for per-VM backups, it will match the ID of each restore point to the ID of each storage file and populate a PSCustomObject with the properties that we want.  
- If not configured for per-VM backups, it will check to see if there is more than 1 VM in the backup job.  
    * If only 1 VM is targeted in the job, we extract the name  
    * If we have more than 1 VM, we concatenate all the VM names within the job.

The last thing that the script does is write the output of our PSCustomObject so that it can be used within the PowerShell pipeline.  

**Running the script:**  
*(This is some PowerShell basics, but including just in case)*  
The script can be dot-sourced from a PowerShell console in the same directory as the script file, which will load the function into memory, and then it can be used like a native cmdlet.  
If the script was in the C:\Code directory, it would look like the following:  

`cd C:\Code`  
`. .\Get-VeeamHistoricalBackupSize.ps1  `  
`Get-VeeamHistoricalBackupSize | Format-Table  `  

To export the result to CSV, the last line could be changed to this:  
`Get-VeeamHistoricalBackupSize | Export-Csv VeeamBackupSize.csv -NoTypeInformation`


**The output of the script:**  
The script will output an object which includes the following properties:  BackupJob, VMName, TimeStamp, BackupSize(GB), DataSize(GB)
