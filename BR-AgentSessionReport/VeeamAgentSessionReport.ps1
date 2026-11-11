$StartDate = '10/29/2019'
$EndDate = '1/5/2019'

Import-Module Veeam.Backup.PowerShell

$SessionStart = Get-Date $StartDate
$SessionEnd = Get-Date $EndDate

$AgentJobs = Get-VBRJob | Where-Object { $_.JobType -eq 'EpAgentBackup' }

[System.Collections.ArrayList]$AllJobSessions = @()
[System.Collections.ArrayList]$AllTasksOutput = @()

foreach ($AgentJob in $AgentJobs) {

    $JobSessions = [veeam.backup.core.cbackupsession]::GetByJob($AgentJob.Id) | Where-Object { $_.CreationTime -gt $SessionStart -AND $_.CreationTime -lt $SessionEnd }

    if ([bool]$JobSessions) {

        foreach ($CurrentSession in $JobSessions) {

            $auxdata = [xml]$CurrentSession.Info.AuxData
            $SessionIDs = (($auxdata.AuxData.EpPolicyJobSessionContext.Sessions) -split ';')

            if (![String]::IsNullOrWhiteSpace($SessionIDs)) {

                $AllJobSessions += $SessionIDs

            } #end null session removal
        } #end job sessions loop
    } #end session ID gathering

    $UniqueJobSessions = $AllJobSessions | Select-Object -Unique

    foreach ($CurrentSessionID in $UniqueJobSessions) {

        $TaskSessions = Get-VBRTaskSession (Get-VBRSession -Id $CurrentSessionID)

        foreach ($CurrentTaskSession in $TaskSessions) {

            $reportTaskOutputObject = [pscustomobject][ordered] @{

                'Name'             = $CurrentTaskSession.Name;
                'JobName'          = ($CurrentTaskSession.JobSess.JobName) -replace " - $($CurrentTaskSession.Info.objectName)";
                'Status'           = $CurrentTaskSession.Status;
                'StartTime'        = $CurrentTaskSession.Progress.StartTimeLocal;
                'StopTime'         = $CurrentTaskSession.Progress.StopTimeLocal;
                'TransferedSizeGB' = ($CurrentTaskSession.Progress.TransferedSize / 1GB)
            } #end reportTaskOutputObject

            $null = $AllTasksOutput.Add($reportTaskOutputObject)

        } # end $TaskSessions loop

    } #end #JobSessions Loop


} #end $Jobs loop
$TrimmedOutput = $AllTasksOutput | Select-Object -Property * -Unique
Write-Output $TrimmedOutput

Disconnect-VBRServer