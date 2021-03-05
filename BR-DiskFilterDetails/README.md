**Functionality of the script:**  
This script contains a function to get details of backup jobs to include VM names, job names, repository names, and details of disk filters.
To run the script itself, it must be imported as a module, or dot-sourced.  Then the function `'Get-VMandDiskFilterDetails'` can be run.
This script assumes you are running on the VBR server for the PowerShell connection, or are already connected to a remote VBR server.

Two different versions of this script exist - one specific for v11, and one for v10 or older.

**Running the script:**  

*From a PowerShell console launched from the Veeam UI*  
Assuming the script file is located in C:\Code for this example.  

`Connect-VBRServer`  
`cd C:\Code`  
`.\Get-VMandDiskFilterDetails.ps1`  
`Get-VMandDiskFilterDetails | Format-Table -AutoSize`  


*From a PowerShell console launched from a remote system*  
Launch Windows PowerShell from the start menu (right-click and run as Administrator).  
Change directories to whichever folder contains the script (assuming the script file is located in C:\Code for this example), and it should run.  

`cd C:\Code`  
`.\Get-VMandDiskFilterDetails.ps1`  
`Get-VMandDiskFilterDetails -Server | Format-Table -AutoSize`  
