VeeamHub
VeeamHub projects are community driven projects, and are not created by Veeam R&D nor validated by Veeam Q&A. They are maintained by community members which might be or not be Veeam employees.

Project Notes
Author(s): Joe Houghes (Veeam Software)

*NOTE: CSV export of the output sample included.*  

**Functionality of the script:**  
The script will gather the details of VBO restore sessions for a specified job type, then gather details from the restore session and items where the restore log contains the text of 'opened'.
It will write the output of our PSCustomObject so that it can be used within the PowerShell pipeline.  

**Running the script:**  
*(This is some PowerShell basics, but including just in case)*  
The script can be dot-sourced from a PowerShell console in the same directory as the script file, which will load the function into memory, and then it can be used like a native cmdlet.  

If the script was in the C:\Code directory and the user is gather Exchange restore session log details, it would look like the following:  
`Set-Location -Path C:\Code`  
`. .\Get-VBORestoreSessionLog.ps1`  
`Get-VBORestoreSessionLog -JobTypeFilter Exchange  | Format-Table`  

To gather Exchange restore session log details, and export the results to CSV, the last line could be changed to this:  
`Get-VBORestoreSessionLog -JobTypeFilter Exchange | Export-CSV .\OrphanedBackupsDetail.csv -NoTypeInformation`  

**The output of the script:**  
The script will output an object which includes the following properties:  
InitiatedBy (user who started session), SessionName (shows entire org or O365 job name), SessionStartTime, ItemName, ItemSize, SourceName (user name and folder), LogEntryID, LogDetail (full text from log entry), LogItemCreationTime, LogItemEndTime, SessionStatus, SessionResult, ProcessedObjects (# of objects within session)  

🤝🏾 License
Copyright (c) 2020 VeeamHub

MIT License