<# 
.NAME
    Veeam Backup & Replication Data Integration API example
.SYNOPSIS
    Script to use for mounting backup data (VM disks) from a backup to an external server
.DESCRIPTION
    This script will perform the following tasks:
	- check a specific backup file 
	- select the last restore point for ALL the available virtual machines
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

# Filter the restore points by unique Object ID to get the virtual machines
$filter = Get-VBRRestorePoint -Backup $backup | Sort-Object ObjectId -Unique | Select-Object Name

foreach ($vm in $filter) {
    # Get-VBRRestorePoint is where you find the last restore point you wish to use
    $restorepoint = Get-VBRRestorePoint -Backup $backup -Name $vm.Name | Sort-Object –Property CreationTime | Select -Last 1

    # Publish the disk(s) for the restore point
    $session = Publish-VBRBackupContent -RestorePoint $restorepoint -TargetServerName $targetServerName -TargetServerCredentials $targetAdminCreds 

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