# Johan Huttenga, 20220517

Param([string] $JobId, [string] $SessionId)

$Version = "0.0.0.1"

$ImportFunctions = { 
      Import-Module Veeam.Backup.PowerShell
      Import-Module "C:\Scripts\BR-DataIntegrationAPIAtScale\BR-DataIntegrationAPIModule.psm1" -Force > $null
}

Invoke-Command -ScriptBlock $ImportFunctions -NoNewScope

Write-Log $("="*78)
Write-Log "{"
Write-Log "`tScript: $($MyInvocation.MyCommand.Name)"
Write-Log "`tVersion: { $($Version) }"
Write-Log "}"

$servers = Get-VBRServer

$job = [Veeam.Backup.Core.CBackupJob]::Get([System.Guid]::new($jobid))
if ($job -eq $null) { Write-Log "Error: Cannot continue. Job ($($jobid)) not found."; return }

$session = Get-VBRBackupSession -Id $sessionid
if ($session -eq $null) { Write-Log "Error: Cannot continue. Session ($($sessionid)) not found."; return }

$tasks = $session.GetTaskSessions() 
$restorepoints = @()

Write-Log "Finding latest restore points for $($job.Name) ($($jobid))."
Write-Log "{"
foreach($task in $tasks) {
    $restorepoints += Get-VBRRestorePoint -ObjectId $task.ObjectId | Sort-Object -Property CreationTimeUTC -Descending | Select-Object -First 1
    $stats = $restorepoints[-1].GetStorage().Stats
    $dataSize = DisplayInBytes($stats.DataSize)
    $backupSize = DisplayInBytes($stats.BackupSize)
    Write-Log "$($task.Name), created $($restorepoints[-1].CreationTimeUTC), source $dataSize, backup $backupSize"
}
Write-Log "}"

Write-Log "Attaching to $($job.Name) ($($jobid)) session ($($sessionid))."

$restorejobs = @()
foreach ($restorepoint in $restorepoints) {

    $scriptblock = {
        param($RestorePointId)
        
        $LogFile = "C:\Scripts\BR-DataIntegrationAPIAtScale\BR-DataIntegrationAPI-$($RestorePoint.Name).log"
        Write-Log "Job: Initializing logic to assign restore task for restore point $($RestorePoint.Name)..."
        $restorepoint = Get-VBRRestorePoint -Id $RestorePointId
        
        # find host to assign secure restore task to
        $targetservers = get-vbrserver -Type Windows

        Write-Log $("="*78)
        Write-Log "Secure restore session task for ($($RestorePoint.Name)) started."

        Queue-VBRPublishBackupContent -RestorePoint $restorepoint -TargetServers $targetservers
    }

    $maxrestorejobs = 10

    #while restorejobs running less than maxrestore jobs
    while (($restorejobs | Where-Object { $_.State -eq "Running" } | Measure-Object | Select-Object -ExpandProperty Count) -ge $maxrestorejobs) {

        Write-Log "Waiting for available resources to run jobs. Currently already processing $($restorejobs.Count) jobs..."
        Start-Sleep -Seconds 30
    }

    $restorejobs += Start-Job -ScriptBlock $scriptblock -ArgumentList $restorepoint.Id -InitializationScript $ImportFunctions

    while (($restorejobs | Where-Object { $_.State -eq "Running" } | Measure-Object | Select-Object -ExpandProperty Count) -gt 0) {
        Start-Sleep -Seconds 5
    }

    $restorejobs | receive-job

}
