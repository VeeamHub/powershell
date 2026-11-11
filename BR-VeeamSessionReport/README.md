*NOTE: CSV export of the output (samples) included.*

**Functionality of the script:**  
This script will connect to the B&R server and query for details of backup & task sessions (limited to parsing session details of VMware backup jobs currently).  
The details gathered for job/sessions are: Job Name, VM Name, Status, Retry of Job, All Processing Modes within Backup Session, JobDuration (formatted in HH:mm:ss.ms), TaskDuration (formatted in HH:mm:ss.ms), Task Algorithm (Full/Incremental), Backup Session Creation Time, Backup Size (In GB), Data Size (In GB), Deduplication Ratio (backup session), Compression Ratio (backup session),Bottleneck Details (full breakdown from log), Primary Bottleneck (parsed from log)

**Running the script:**  
*(This is some PowerShell basics, but including just in case)*  
The script can be dot-sourced from a PowerShell console in the same directory as the script file, which will load the function into memory, and it can then be used like a native cmdlet.  
If the script was in the C:\Code directory, it would look like the following:  

`cd C:\Code`  
`. .\Get-VeeamSessionReport.ps1  `  
`Get-VeeamSessionReport -VBRServer ausveeambr`

**The output of the script:**  
The script will output results to the pipeline, which will also output them to the console.
If you want to export CSV files, pipe the results to `Export-CSV` as the final example below.

`Get-VeeamSessionReport -VBRServer ausveeambr | Export-Csv -Path 'D:\Temp\VeeamSessionReportQuick_051920.csv' -NoTypeInformation`