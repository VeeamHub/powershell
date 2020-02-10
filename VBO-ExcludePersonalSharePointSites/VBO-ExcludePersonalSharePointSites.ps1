<# 
.NAME
    Veeam Backup for Microsoft Office 365 Personal SharePoint Site Excluder
.SYNOPSIS
    Script to use for excluding Personal SharePoint Sites from a backup job
.DESCRIPTION
    Script to use for excluding Personal SharePoint Sites from a backup job
    Created for Veeam Backup for Microsoft Office 365 v2
    Released under the MIT license.
.LINK
    http://www.github.com/nielsengelen
#>

# Modify the values below to your needs
$organizationname = "YOURORGANIZATION"
$backupjob = "TEST"

# Do not change below unless you know what you are doing
Import-Module "C:\Program Files\Veeam\Backup365\Veeam.Archiver.PowerShell\Veeam.Archiver.PowerShell.psd1"

# Get the Organization
$Org = Get-VBOOrganization -Name $organizationname
# Leverage the Job which backs up the required sites
$Job = Get-VBOJob -Name $backupjob
# Get all the SharePoint Sites which aren't in a job but exclude the Personal Sites
$Sites = Get-VBOOrganizationSite -Organization $Org -IncludePersonalSite:$false -NotInJob

ForEach ($Site in $Sites) {
  #Write-Progress -Activity "Parsing sites" -status "Site: $Sites.Name" -percentComplete ($i / $Sites.count * 100)
  $newSite = New-VBOBackupItem -Site $Site
  Add-VBOBackupItem -Job $Job -BackupItem $newSite
}

Write-Host "Added a total of " $Sites.count " sites to the job"