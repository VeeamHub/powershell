<#PSScriptInfo
.VERSION 1.0.6
.GUID b2c3d4e5-f678-4901-abcd-ef1234567890
.AUTHOR Tim Smith (https://tsmith.co)
.COPYRIGHT 2025
.TAGS Veeam Backup for Microsoft 365, SharePoint
.LICENSEURI
.PROJECTURI
.ICONURI
.EXTERNALMODULEDEPENDENCIES Veeam.Archiver.PowerShell
.REQUIREDSCRIPTS
.EXTERNALSCRIPTDEPENDENCIES
.RELEASENOTES
1.0.0: Initial version to remove deleted SharePoint sites using backup job status
1.0.1: Corrected Get-VBOJobSession parameters (-LastRun to -Last, removed -Organization)
1.0.2: Fixed URL comparison by removing trailing periods from failed site URLs
1.0.3: Added handling for jobs that would become empty after removal (disable and rename)
1.0.4: Fixed disabling jobs by using SchedulePolicy instead of invalid EnableSchedule parameter
1.0.5: Attempted minimal disabled schedule policy (reverted)
1.0.6: Switched to Disable-VBOJob for proper job disabling
#>

#Requires -Module Veeam.Archiver.PowerShell
#Requires -Version 5.0

<#
.DESCRIPTION
Removes SharePoint sites from Veeam Backup for Microsoft 365 jobs if they fail with 404 errors in recent job sessions.
If removal would leave a job empty, disables and renames the job by default using Disable-VBOJob.
#>
[CmdletBinding()]
Param(
    [Parameter(Mandatory = $true)]
    [string] $Organization,
    [Parameter(Mandatory = $false)]
    [string] $JobNamePattern = "SharePointTeams-{0:d3}",
    [Parameter(Mandatory = $false)]
    [ValidateSet("DisableAndRename", "Remove", "DisableOnly")]
    [string] $EmptyJobAction = "DisableAndRename"
)

BEGIN {
    filter timelog { "$(Get-Date -Format "yyyy-MM-dd HH:mm:ss"): $_" }
    
    # Start logging
    $logFile = "${PSScriptRoot}\logs\vb365-deleted-sites-jobstatus-$(Get-Date -Format FileDateTime).log"
    if (-not (Test-Path "${PSScriptRoot}\logs")) { New-Item -Path "${PSScriptRoot}\logs" -ItemType Directory -Force }
    Start-Transcript -Path $logFile -NoClobber

    "Starting deleted sites removal using job status" | timelog
    "Organization: $Organization" | timelog
    "JobNamePattern: $JobNamePattern" | timelog
    "EmptyJobAction: $EmptyJobAction" | timelog

    # Get organization
    $org = Get-VBOOrganization -Name $Organization
    if (-not $org) { throw "Organization $Organization not found" }
}

PROCESS {
    # Get jobs matching the pattern for the organization
    "Fetching jobs matching pattern $JobNamePattern" | timelog
    $jobs = @()
    $jobNumber = 1
    while ($true) {
        $jobName = $JobNamePattern -f $jobNumber
        $job = Get-VBOJob -Organization $org -Name $jobName
        if (-not $job) { break }
        $jobs += $job
        $jobNumber++
    }
    "Found {0} jobs" -f $jobs.Count | timelog

    # Get recent job sessions for failed sites
    "Fetching last job sessions for failed or warning statuses" | timelog
    $jobSessions = $jobs | ForEach-Object { Get-VBOJobSession -Job $_ -Last -WarningAction:SilentlyContinue } | 
        Where-Object { $_.Status -eq "Warning" -or $_.Status -eq "Failed" }
    $failedSiteUrls = @()
    foreach ($session in $jobSessions) {
        $logEntries = $session.Log | Where-Object { $_.Title -match "Failed to process site" -and $_.Title -match "404" }
        foreach ($entry in $logEntries) {
            if ($entry.Title -match "https://[^\s]+") {
                $cleanUrl = $matches[0] -replace '\.$', ''
                $failedSiteUrls += $cleanUrl
            }
        }
    }
    $failedSiteUrls = $failedSiteUrls | Select-Object -Unique
    "Identified {0} inaccessible sites: {1}" -f $failedSiteUrls.Count, ($failedSiteUrls -join ", ") | timelog

    $removedSitesCounter = 0
    $modifiedJobsCounter = 0
    foreach ($job in $jobs) {
        "Processing job: $($job.Name)" | timelog
        $backupItems = Get-VBOBackupItem -Job $job
        $siteItems = $backupItems | Where-Object { $_.Type -eq "Site" }
        "Found {0} site items in job" -f $siteItems.Count | timelog

        $itemsToRemove = @()
        foreach ($item in $siteItems) {
            $siteId = $item.Site.SiteId
            $siteUrl = $item.Site.URL
            "Evaluating site: $siteUrl (ID: $siteId)" | timelog

            if ($siteUrl -in $failedSiteUrls) {
                "Site $siteUrl (ID: $siteId) failed with 404, marking for removal" | timelog
                $itemsToRemove += $item
            } else {
                "Site $siteUrl (ID: $siteId) not recently failed" | timelog
            }
        }

        if ($itemsToRemove.Count -gt 0) {
            if ($backupItems.Count -eq $itemsToRemove.Count) {
                # Job would become empty
                "Job $($job.Name) would become empty after removal" | timelog
                switch ($EmptyJobAction) {
                    "Remove" {
                        "Removing job $($job.Name)" | timelog
                        Remove-VBOJob -Job $job -WarningAction:SilentlyContinue
                        $modifiedJobsCounter++
                    }
                    "DisableOnly" {
                        "Disabling job $($job.Name)" | timelog
                        Disable-VBOJob -Job $job -WarningAction:SilentlyContinue
                        $modifiedJobsCounter++
                    }
                    "DisableAndRename" {
                        $newName = "$($job.Name)_Empty_Disabled"
                        "Disabling and renaming job $($job.Name) to $newName" | timelog
                        Disable-VBOJob -Job $job -WarningAction:SilentlyContinue
                        Set-VBOJob -Job $job -Name $newName -WarningAction:SilentlyContinue
                        $modifiedJobsCounter++
                    }
                }
            } else {
                # Safe to remove items
                foreach ($item in $itemsToRemove) {
                    $siteUrl = $item.Site.URL
                    $siteId = $item.Site.SiteId
                    "Removing site $siteUrl (ID: $siteId) from job $($job.Name)" | timelog
                    Remove-VBOBackupItem -Job $job -BackupItem $item -WarningAction:SilentlyContinue
                    $removedSitesCounter++
                }
            }
        }
    }

    "Removed $removedSitesCounter deleted sites and modified $modifiedJobsCounter jobs" | timelog
}

END {
    Stop-Transcript
    "Script completed" | timelog
}