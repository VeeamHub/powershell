<# 
.NAME
    Veeam Backup for Microsoft Office 365 Automatically Backup Office 365 Groups
.SYNOPSIS
    Script to use for automatically adding Office 365 Groups to a backup job
.DESCRIPTION
    Script to use for automatically adding Office 365 Groups to a backup job
    Can be used in combination with Windows Task Schedule
    Created for Veeam Backup for Microsoft Office 365 v4
    Released under the MIT license.
.LINK
    http://www.github.com/nielsengelen
#>

# Modify the values below to your needs
$Organization = "X"
$BackupJob = "X"

# Do not change below unless you know what you are doing
Import-Module "C:\Program Files\Veeam\Backup365\Veeam.Archiver.PowerShell\Veeam.Archiver.PowerShell.psd1"

# Get the Organization
$Org = Get-VBOOrganization -Name $Organization
# Leverage the Job which backs up the required Office 365 groups
$Job = Get-VBOJob -Name $BackupJob
# Get the Office 365 groups
$Groups = Get-VBOOrganizationGroup -Organization $organization -Type Office365

# Go through all the Office 365 groups and add them to the job
ForEach ($Group in $Groups) {
    $Item = New-VBOBackupItem -Group $Group
    Add-VBOBackupItem -Job $Job -BackupItem $Item
}