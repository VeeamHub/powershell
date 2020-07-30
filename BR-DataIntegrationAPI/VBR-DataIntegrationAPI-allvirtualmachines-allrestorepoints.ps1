<# 
.NAME
    Veeam Backup & Replication Data Integration API example
.SYNOPSIS
    Script to use for mounting backup data (VM disks) from a backup to an external server
.DESCRIPTION
    This script will perform the following tasks:
	- check a specific backup file 
	- select ALL the restore points for ALL the available virtual machines
	- present the disks within that backup to an external server
	
    Created for Veeam Backup & Replication v10
    Released under the MIT license.
.LINK
    http://www.github.com/nielsengelen
#>

# Add the Veeam PowerShell snapin - if it is already loaded continue silently with no error
Add-PSSnapin VeeamPSSnapin -ErrorAction SilentlyContinue

# The backup variable $backup is populated by the cmdlet Get-VBRBackup which will return info regarding the backup data
$backup = Get-VBRBackup -Name "MYBACKUPJOBNAME"

# Provide the host name of the target server
$targetServerName = "TARGETSERVER"

# Provide the credentials to access the remote server  example: LAB\administrator
# These must be stored within the Credentials manager in Veeam Backup & Replication
$targetAdminCreds = Get-VBRCredentials -name "LAB\Administrator"

# Get-VBRRestorePoint is where you find the restore points
$restorepoints = Get-VBRRestorePoint -Backup $backup | Sort-Object –Property CreationTime

foreach ($point in $restorepoints) {
    # Publish the disks for the restore points via the Publish-VBRBackupContent cmdlet
    $session = Publish-VBRBackupContent -RestorePoint $point -TargetServerName $targetServerName -TargetServerCredentials $targetAdminCreds

    # Obtaining information about mounted disks
    $contentInfo = Get-VBRPublishedBackupContentInfo -Session $session

    Write-Host "`nBackup Job Name:" $session.BackupName "`nRestore Point time:" $session.RestorePoint "`nVM Name:" $session.PublicationName

    # Produce a report showing what mount points were published and where
    foreach ($contentType in $contentInfo) {
	    Write-Host "================================"
	    $disks = $contentType.Disks
	    Write-Host "Mounted Disk:" $disks.DiskName
	    Write-Host "Mounted At:" $disks.MountPoints
	    Write-Host "Mounted As:" $contentType.Mode
	    Write-Host "Available From:" $contentType.ServerIps "(Port:" $contentType.ServerPort ")"
	    Write-Host "Available Via:" $disks.AccessLink
	    Write-Host "================================"
    }
}