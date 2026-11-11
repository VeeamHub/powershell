<# 
.NAME
    Veeam Backup for Microsoft Office 365 Personal SharePoint Site Includer
.SYNOPSIS
    Script to use for automatically adding SharePoint Sites to a backup job
.DESCRIPTION
    Script to use for automatically adding SharePoint Sites to a backup job based upon a filter 
    Can be used in combination with Windows Task Schedule
    Created for Veeam Backup for Microsoft Office 365 v4
    Released under the MIT license.
.LINK
    http://www.github.com/nielsengelen
#>

# Modify the values below to your needs
$Organization = "X"
$BackupJob = "X"
$Filter = "BE"

# Do not change below unless you know what you are doing
Import-Module "C:\Program Files\Veeam\Backup365\Veeam.Archiver.PowerShell\Veeam.Archiver.PowerShell.psd1"

# Get the Organization
$Org = Get-VBOOrganization -Name $Organization
# Leverage the Job which backs up the required sites
$Job = Get-VBOJob -Name $BackupJob
# Get all the SharePoint Sites which aren't in a job and exclude the Personal Sites
$Sites = Get-VBOOrganizationSite -Organization $Org -IncludePersonalSite:$false -NotInJob

# Go through all SharePoint Sites
ForEach ($Site in $Sites) {
  $FilteredSite = $Site.Name -match "$Filter"

  # Only add the sites based on the filter
  if ($FilteredSite) {
    $newSite = New-VBOBackupItem -Site $Site
    Add-VBOBackupItem -Job $Job -BackupItem $newSite
  }
}