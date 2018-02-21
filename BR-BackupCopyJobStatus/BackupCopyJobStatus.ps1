<# 
.SYNOPSIS 
    Veeam OffSite Backups Information 
.DESCRIPTION 
    This scripts connects to the specified Veeam server, and returns the status of any Backup Copy jobs (whether the are running or idle, the duration of that job, and the current progress), then outputs that information to a colour coded HTML file.
.PARAMETER Server
    Specifies the Veeam Backup Server. If this is blank, Localhost will be used.
.PARAMETER Outfile
    Specifies the path to save the HTML report. If this is blank, C:\Reports\CopyJobStatus.html will be used.
.NOTES 
    File Name  : BackupCopyJobStatus.ps1 
    Author     : Mike Conjoice - mike@mikeconjoice.com
    Requires   : Veeam Console installed if running from a remote machine 
.LINK 
    http://www.mikeconjoice.com 
.EXAMPLE
    BackupCopyJobStatus.ps1

    This will run the script with the default parameters.
.EXAMPLE 
    BackupCopyJobStatus.ps1 -Server SRV-VB01 -Outfile c:\Reports\veeam.html

    This will run the script against the Veeam server named "SRV-VB01" and output the HTML report to "C:\Reports\veeam.html"
#> 
 
######
## TODO: Add Job Duration
## TODO: Send STOPPED Jobs to the Bottom
## ----------------------------------------------------
## DONE: Change $outfile and $server to Parameters
######

######
## Parameters
######

param(
    [String]$outfile="C:\Reports\CopyJobStatus.html",
    [String]$Server="localhost"
)

######
## Load required Snapins and Modules
######

if ((Get-PSSnapin -Name VeeamPSSNapin -ErrorAction SilentlyContinue) -eq $null)
{
    Add-PSSnapin VeeamPSSNapin
}

######
## Set the CSS for the output file
######

$head = @"
<style>
th {background-color: #00aff0} 
table {border-collapse: collapse} 
table, th, td {
border: 1px solid black;
padding: 5px
} 
th {color: white} 
body {font-family: sans-serif} 
</style>
"@

######
## Create an empty array
######

$results = @()

######
## Begin the script by collecting a list of all the Offsite backup jobs
######

if ($Server -eq $null) {
    Connect-VBRServer -Server $server 
} else {
    Disconnect-VBRServer
Connect-VBRServer -Server $server 
}
$JobNames = Get-VBRJob | Where-Object {$_.JobType -Like "*Sync"}

######
## Loop through all the returned jobs to find the Job Name, Current Status, Progress, and Duration to be entered in to the array
######

foreach ($JobName in $JobNames) {
    $Job = Get-VBRJob -name $JobName.Name
    $LastSession = $Job.FindLastSession()
    $Name = $Job.Name
    $Status = $LastSession.State
    $Progress = "$($LastSession.BaseProgress)%"
    
    ######
    ## Create a new PSObject and populate the array with the details 
    ######
    
    $results += New-Object PSObject -Property @{JobName = $Name; Status = $Status; Progress = $Progress;}
} 

######
## Collate, sort, colourise, and output the results to an HTML file
######

$results |
Select JobName, Status, Progress |
sort @{expression="Status";Descending=$false},@{expression="JobName";Ascending=$true} |
ConvertTo-Html -body "<H2>Veeam OffSite Backups Information</H2> <p>The following report was run on $(get-date).</p>" -PreContent $head -Title "Veeam OffSite Backups Information" | 
    foreach {
        $PSItem -replace "<td>Working</td>", "<td style='background-color:green; color: white'>Running</td>" -replace "<td>Idle</td>", "<td style='background-color:orange; color: white'>Idle</td>" -replace "<td>Stopped</td>", "<td style='background-color:red; color: white'>Stopped</td>"
    } | Out-File $outfile

######
## End of script
######