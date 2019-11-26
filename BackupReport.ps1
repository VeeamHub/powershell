
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


$sessions = get-vbrbackupsession
$sessionInfo = @()
$importPath = get-content -LiteralPath $Path
foreach ($import in $importPath) {
   foreach ($session in $sessions) {
        if ($Backup)
        {
        $backupInfo = get-vbrtasksession -session $session | where-object {$_.Name -eq $import -and $session.JobType -eq 'Backup'}
        }
        elseif ($BackupCopy)
        {
        $backupInfo = get-vbrtasksession -session $session | where-object {$_.Name -eq $import -and $session.JobType -eq 'BackupSync'}
        }
        else {
         $backupInfo = get-vbrtasksession -session $session | where-object {$_.Name -eq $import -and ($session.JobType -eq 'BackupSync' -or $session.JobType -eq 'Backup')}
        }
        if ($backupInfo) {
                $sessionStats = @{
                    VirtualMachine = $backupInfo.Name
                    Result = $backupInfo.Status
                    JobName = $session.JobName
                    JobType = $session.JobType
                    SessionStartTime = $session.CreationTime
                    SessionEndTime = $session.EndTime
                }
     $sessionInfo += $sessionStats | select-object @{n='VM Name';e={$_.VirtualMachine}}, @{n='Result';e={$_.Result}}, @{n='Job Name';e={$_.JobName}}, @{n='Job Type';e={$_.JobType}}, @{n='Start time';e={$_.SessionStartTime}}, @{n='End time';e={$_.SessionEndTime}}

 }
   }
   }
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

