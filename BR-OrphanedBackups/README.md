VeeamHub
VeeamHub projects are community driven projects, and are not created by Veeam R&D nor validated by Veeam Q&A. They are maintained by community members which might be or not be Veeam employees.

Project Notes
Author(s): Joe Houghes (Veeam Software)

*NOTE: CSV export of the output sample included.*  

**Functionality of the script:**  
The script will connect to a specified Veeam server and gather the details of restore points within backups which no longer have existing Veeam jobs, and show restore points still exist.
It will write the output of our PSCustomObject so that it can be used within the PowerShell pipeline.  

**Running the script:**  
*(This is some PowerShell basics, but including just in case)*  
The script can be dot-sourced from a PowerShell console in the same directory as the script file, which will load the function into memory, and then it can be used like a native cmdlet.  

If the script was in the C:\Code directory on the VBR server, it would look like the following:  
`Set-Location -Path C:\Code`  
`. .\Get-OrphanedBackupsDetail.ps1`  
`Get-OrphanedBackupsDetail | Format-Table`  

To connect to a remote VBR server and export the results to CSV, the last line could be changed to this:  
`Get-OrphanedBackupsDetail -VBRServer ausveeambr | Export-CSV .\OrphanedBackupsDetail.csv -NoTypeInformation`  

**The output of the script:**  
The script will output an object which includes the following properties:  
Hostname, CreationTime, Job Name, FileSize(GB), Full/Incremental, Job Type, FileName, IsAvailable, FilePath, RepoName, RepoID

🤝🏾 License
Copyright (c) 2020 VeeamHub

MIT License