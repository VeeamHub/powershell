*NOTE: CSV export of the output sample included.*  

**Functionality of the script:**  
The script will connect to a specified Veeam server and gather the details for each job session of VMware backup jobs.  
It will write the output of our PSCustomObject so that it can be used within the PowerShell pipeline.  

**Running the script:**  
*(This is some PowerShell basics, but including just in case)*  
The script can be dot-sourced from a PowerShell console in the same directory as the script file, which will load the function into memory, and then it can be used like a native cmdlet.  

If the script was in the C:\Code directory on the VBR server, it would look like the following:  
`Set-Location -Path C:\Code`  
`. .\Get-VeeamBackupSessionReport.ps1`  
`Get-VeeamBackupSessionReport | Format-Table`  

To connect to a remote VBR server and export the results to CSV, the last line could be changed to this:  
`Get-VeeamBackupSessionReport -VBRServer ausveeambr | Export-CSV C:\Temp\DupeSessionReport.csv -NoTypeInformation`  

**The output of the script:**  
The script will output an object which includes the following properties:  
JobName, Result, DataSize (in GB), BackupSize(in GB), Dedupe Ratio, Compression Ratio, CreationTime