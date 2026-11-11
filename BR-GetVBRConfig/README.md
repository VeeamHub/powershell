*NOTE: CSV export of the output (samples) included.*

**Functionality of the script:**  
This script will connect to the B&R server and query for details of servers, proxies, repositories, scale-out repositories,  scale-out extents, and jobs (limited details).
The details gathered for jobs are: Name, JobType , Schedule Time, Schedule Options, # of restore points, repository name, backup algorithm, full backup info and synthetic backup info.
It will export CSV files to the path which is provided to the script.

**Running the script:**  
*(This is some PowerShell basics, but including just in case)*  
The script can be dot-sourced from a PowerShell console in the same directory as the script file, which will load the function into memory, and it can then be used like a native cmdlet.  
If the script was in the C:\Code directory, it would look like the following:  

`cd C:\Code`  
`. .\Get-VBRConfig.ps1  `  
`Get-VBRConfig -VBRServer ausveeambr -ReportPath C:\Temp\VBROutput`

**The output of the script:**  
The script will output a CSV for each VBR object type, which will be placed into the folder given to the 'ReportPath' parameter.
