<#
.SYNOPSIS
Identifies orphaned Cloud Connect Backups (or Restore Points)

.DESCRIPTION
This script is designed to be run on a VBR server that sends backups to a (Cloud Connect) Cloud Repository. It looks for backups that are no longer tied to an active Backup Job and then filters the results depending on the parameters specified.
	
.PARAMETER Age
Returns orphaned Restore Points older than XX number of days (must be used with AsRestorePoints flag)

.PARAMETER AsRestorePoints
Returns Restore Points instead of Backups

.OUTPUTS
Returns a PSObject

.EXAMPLE
Find-VCCOrphanedBackups.ps1

Description 
-----------     
Identifies ALL orphaned Cloud Connect Backups

.EXAMPLE
Find-VCCOrphanedBackups.ps1 -AsRestorePoints

Description 
-----------     
Identifies ALL orphaned Cloud Connect Restore Points

.EXAMPLE
Find-VCCOrphanedBackups.ps1 -Age 30 -AsRestorePoints

Description 
-----------     
Identifies orphaned Cloud Connect Restore Points more than 30 days old

.EXAMPLE
Find-VCCOrphanedBackups.ps1 -Verbose

Description 
-----------     
Verbose output is supported

.NOTES
NAME:  Find-VCCOrphanedBackups.ps1
VERSION: 1.0
AUTHOR: Chris Arceneaux
TWITTER: @chris_arceneaux
GITHUB: https://github.com/carceneaux

THIS SCRIPT WILL NOT WORK IF EXECUTED ON A CLOUD CONNECT SERVER. IT'S DESIGNED TO BE RUN ON A TENANT VBR SERVER.

.LINK
https://arsano.ninja/

.LINK
https://helpcenter.veeam.com/docs/backup/powershell/

#>

[CmdletBinding(DefaultParametersetName = 'None')] 
param(
    [Parameter(ParameterSetName = 'RestorePoints', Mandatory = $false)]
    [Int] $Age = $null,
    [Parameter(ParameterSetName = 'RestorePoints', Mandatory = $true)]
    [Switch] $AsRestorePoints
)

# Initializing variables
$date = Get-Date
$backupsFiltered = New-Object 'System.Collections.Generic.List[PSObject]'
$orphans = New-Object 'System.Collections.Generic.List[PSObject]'
Write-Verbose "Current date identified: $date"

# Retrieving all active Backup Jobs
$jobs = Get-VBRJob | Where-Object { $_.IsScheduleEnabled -eq $True }
Write-Verbose "Active Backup Jobs found: $($jobs.count)"

# Retrieving all cloud repositories
$repos = Get-VBRBackupRepository | Where-Object { $_.Type -eq "Cloud" }
Write-Verbose "Cloud Repositories found: $($repos.count)"

# Retrieving all backups
Write-Verbose "Retrieving ALL Backups..."
$backups = Get-VBRBackup
Write-Verbose "Backups found: $($backups.count)"

# Applying filter so only backups stored on cloud repositories remain
$backups = $backups | Where-Object { $repos.Id.Guid -contains $_.RepositoryId.Guid }
Write-Verbose "Backups stored in a Cloud Repository: $($backups.count)"

# Applying further filters
Write-Verbose "Identifying Backups without an active Backup Job..."
foreach ($backup in $backups) {
    Write-Verbose "Checking Backup Id: $($backup.Id.Guid)"
    # Determining if backup has an active job. We only want backups don't have an active backup job.  
    if ($backup.HasParent) {
        # Use parent job Id to look for active job
        if ($jobs.Id.Guid -notcontains ($backups | Where-Object { $_.Id.Guid -eq $backup.ParentBackupId.Guid }).JobId.Guid) {
            Write-Verbose "Backup ($($backup.Id.Guid)) does not have an active Backup Job."
            $backupsFiltered.Add($backup)
        }
    }
    else {
        if ($jobs.Id.Guid -notcontains $backup.JobId.Guid) {
            Write-Verbose "Backup ($($backup.Id.Guid)) does not have an active Backup Job."
            $backupsFiltered.Add($backup)
        }
    }
}

# Returning results if AsRestorePoints flag wasn't specified
if (-NOT $AsRestorePoints) {
    # Returning output PSObject
    return $backupsFiltered
}

# Looping through backups checking for stale restore points
foreach ($backup in $backupsFiltered) {
    Write-Verbose "Retrieving all Restore Points for Backup Id: $($backup.Id.Guid)"
    # Retrieving all restore points associated with the specified backup
    $rps = Get-VBRRestorePoint -Backup $backup
    Write-Verbose "Restore Points found: $($rps.count)"
    foreach ($rp in $rps) {
        # Was the Age parameter specified?
        if ($Age) {
            # Is restore point older than defined threshold?
            if ($rp.CreationTime -lt $date.AddDays(- $Age)) {
                Write-Verbose "Stale Restore Point found: $($rp.Id.Guid)"
                $orphans.Add($rp)
            }
        }
        else {
            Write-Verbose "Adding Restore Point to output object: $($rp.Id.Guid)"
            $orphans.Add($rp)
        }
        
    }
}

# Returning output PSObject
return $orphans