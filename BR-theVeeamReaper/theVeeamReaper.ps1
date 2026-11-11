<#
.SYNOPSIS
    Displays running Veeam Backup & Replication jobs and allows termination of associated Veeam.Backup.Manager.exe processes.
    WARNING: This script is unofficial and is not created nor supported by Veeam Software.
    WARNING: Forceful termination of running jobs (which is what the script allows you to do) can potentially lead to inconsistencies in the backup chains. Caution is advised.

.DESCRIPTION
    VeeamReaper is an interactive script for administrators. It:
    - Retrieves all currently running Veeam Backup & Replication jobs using Get-VBRJob.
    - Presents them in a GridView for selection.
    - Identifies all Veeam.Backup.Manager.exe processes whose command line contains selected job IDs.
    - Shows these processes in a console table for review.
    - Prompts the user for confirmation before terminating the associated processes.
    - Ensures the Veeam PowerShell module is loaded only if not already present.
    The script supports both Windows PowerShell and PowerShell 7+.
#>

# Load Veeam PowerShell (module only if not already loaded)
if (-not (Get-Module -Name Veeam.Backup.PowerShell)) {
    Import-Module Veeam.Backup.PowerShell
}

# Detect installed PowerShell version
$psVersion = $PSVersionTable.PSVersion
$isPS7OrHigher = ($psVersion.Major -ge 7)

# Step 1: Retrieve running Veeam jobs and their details
$runningJobs = Get-VBRJob | Where-Object { $_.IsRunning } | ForEach-Object {
    $session = $_.FindLastSession()
    if ($session -and $session.State -eq 'Working') {
        $elapsed = (Get-Date) - $session.CreationTime
        $basePercent = $session.BaseProgress
        $percent = if ($basePercent -ne $null) { "{0:N0}%" -f $basePercent } else { "N/A" }
    } else {
        $elapsed = [timespan]::Zero
        $percent = "N/A"
    }
    [PSCustomObject]@{
        Name           = $_.Name
        ID             = $_.Id.Guid
        Platform       = $_.TypeToString
        'Elapsed Time' = "$($elapsed.Hours)h $($elapsed.Minutes)m $($elapsed.Seconds)s"
        'Completion %' = $percent
    }
}

# Communicate and exit if no running jobs found
if (!$runningJobs -or $runningJobs.Count -eq 0) {
    Write-Host ""
    Write-Host "No running Veeam backup jobs were found. Exiting."
    exit
}

# Step 2: Display running jobs in a GridView for selection
$selectedJobs = $runningJobs | Out-GridView -Title "Select Veeam Jobs to Investigate / Terminate (multi-select works: SHIFT+Click, CTRL+Click)" -PassThru
if (!$selectedJobs) { Write-Host "No jobs selected. Exiting."; exit }

# Step 3: Find Veeam.Backup.Manager.exe processes related to selected job IDs
if ($isPS7OrHigher) {
    $allProcesses = Get-Process -Name "Veeam.Backup.Manager" | Where-Object { $_.CommandLine }
    $processes = @()
    foreach ($proc in $allProcesses) {
        foreach ($job in $selectedJobs) {
            if ($proc.CommandLine -match $job.ID) {
                $arguments = $proc.CommandLine -replace '.*Veeam\.Backup\.Manager\.exe\s*', ''
                $processes += [PSCustomObject]@{
                    Name            = $proc.ProcessName
                    PID             = $proc.Id
                    'Backup Job Name' = $job.Name
                    Arguments       = $arguments
                }
            }
        }
    }
} else {
    $allProcesses = Get-CimInstance -ClassName Win32_Process | Where-Object { $_.Name -eq "Veeam.Backup.Manager.exe" }
    $processes = @()
    foreach ($proc in $allProcesses) {
        foreach ($job in $selectedJobs) {
            if ($proc.CommandLine -match $job.ID) {
                $arguments = $proc.CommandLine -replace '.*Veeam\.Backup\.Manager\.exe\s*', ''
                $processes += [PSCustomObject]@{
                    Name            = $proc.Name
                    PID             = $proc.ProcessId
                    'Backup Job Name' = $job.Name
                    Arguments       = $arguments
                }
            }
        }
    }
}

# Step 4: Display relevant processes in a table
if (!$processes -or $processes.Count -eq 0) {
    Write-Host "No related Veeam.Backup.Manager.exe processes found for the selected jobs. Exiting."
    exit
}

Write-Host ""
Write-Host "The following Veeam Manager processes will be terminated:"
$processes | Format-Table -AutoSize Name, PID, 'Backup Job Name', Arguments
Write-Host ""

# Step 5: Confirmation prompt
$confirm = Read-Host "Do you want to terminate all listed processes? (Y/N)"
if ($confirm -ne 'Y') { Write-Host "Operation cancelled."; exit }

# Step 6: Kill listed processes
foreach ($proc in $processes) {
    try {
        Stop-Process -Id $proc.PID -Force
        Write-Host "Terminated process $($proc.PID) ($($proc.Name))"
    } catch {
        Write-Warning "Failed to terminate process $($proc.PID): $_"
    }
}
