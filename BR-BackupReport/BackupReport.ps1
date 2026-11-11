
<#
    .SYNOPSIS
        Generates html report on Backups and Backup Copies.
    .SYNTAX
        Get-BackupReport -Path <string[]> [-Backup] [-BackupCopy]
    .PARAMETERS
        -path <string[]>
        -Backup <switch>
        -BackupCopy <switch>
#>
add-pssnapin -name VeeamPSSnapin
connect-vbrserver -server localhost
$styleHtml = @"
        <style>
        TABLE {border-width: 1px; border-style: solid; border-color: black; border-collapse: collapse;}
        TH {border-width: 1px; padding: 3px; border-style: solid; border-color: black; background-color: #6495ED;}
        TD {border-width: 1px; padding: 3px; border-style: solid; border-color: black;}
        </style>
"@
function get-backupreport {
[cmdletbinding(defaultparametersetname = 'Path')]
param (
   [parameter(
        mandatory,
        parametersetname  = 'Path',
        valuefrompipeline,
        valuefrompipelinebypropertyname
    )]
    [validatenotnullorempty()]
    [string[]]$Path,

    [switch]$Backup,

    [switch]$BackupCopy
)

if ($Backup) {
    $includeJobs = "^Backup$"
} elseif ($BackupCopy) {
    $includeJobs = "^BackupSync$"
} else {
    $includeJobs = "^Backup$|^BackupSync$"
}    
 
$sessions = Get-VBRBackupSession | ?{$_.JobType -match $includeJobs}
$taskSessions = $sessions.GetTaskSessions() | Group-Object -Property Name -AsHashTable

$sessionInfo = @()
$importPath = get-content -LiteralPath $Path
$sessionInfo = foreach ($import in $importPath) {
    $taskSessions.$import | Select-Object @{n='VM Name';e={$_.Name}}, @{n='Result';e={$_.Status}}, @{n='Job Name';e={$_.JobName}}, @{n='Job Type';e={$_.JobSess.JobType}}, @{n='Start time';e={$_.Progress.StartTimeLocal}}, @{n='End time';e={$_.Progress.StopTimeLocal}}
}

$sessionInfo = $sessionInfo | Sort-Object "VM Name", "Job Type", "Job Name", "Start Time"

$exportDir = test-path -path 'C:\Temp'
$currentDate = (get-date).tostring('MM-dd-yyyy')
$exportTo = 'C:\Temp\BackupReport-' + $currentDate + '.html'
if (!$exportDir)
{
new-item -ItemType directory -Path 'C:\Temp'
$sessionInfo | convertto-html -Head $styleHtml | out-file -filepath $exportTo -Append
write-host 'The report was saved to C:\Temp\BackupReport.html'-ForegroundColor Green
}
elseif ($exportDir){
write-host 'The report was saved to C:\Temp\BackupReport.html'-ForegroundColor Green
$sessionInfo | convertto-html -Head $styleHtml | out-file -filepath $exportTo -Append
}

}
