<#
.SYNOPSIS
	Identifies Organizations using multiple backup applications.

.DESCRIPTION
  Per KB4821, each Organization should use a single backup application per Microsoft term's of use and product documentation. This script identifies Organizations that are using multiple backup applications.

.PARAMETER Fix
  Flag to remove multiple backup applications and leave only one per organization.

.OUTPUTS
	Find-MultipleBackupApplications returns a PowerShell Object containing all data

.EXAMPLE
	Find-MultipleBackupApplications.ps1

	Description
	-----------
	Identifies Organizations using multiple backup applications.

.EXAMPLE
  Find-MultipleBackupApplications.ps1 -Fix

	Description
	-----------
	Removes multiple backup applications and leaves only one per organization.

.EXAMPLE
	Find-MultipleBackupApplications.ps1 -Verbose

	Description
	-----------
	Verbose output is supported

.NOTES
	NAME:  Find-MultipleBackupApplications.ps1
	VERSION: 1.0
	AUTHOR: Chris Arceneaux
	GITHUB: https://github.com/carceneaux

.LINK
  https://www.veeam.com/kb4821

.LINK
  https://helpcenter.veeam.com/docs/vbo365/powershell/get-vbobackupapplication.html

.LINK
  https://helpcenter.veeam.com/docs/vbo365/powershell/remove-vbobackupapplication.html

#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $false)]
  [Switch] $Fix
)

# setting default PowerShell action to halt on error
$ErrorActionPreference = "Stop"

# importing required Veeam PowerShell module
Import-Module "C:\Program Files\Veeam\Backup365\Veeam.Archiver.PowerShell\Veeam.Archiver.PowerShell.psd1"

# determine if connected to Veeam
try {
  if (Get-VBOServer) {
    Write-Host "Connected to Veeam Backup for Microsoft 365" -ForegroundColor Green
  }
}
catch {
  Write-Error "An error was encountered when accessing Veeam. Please ensure you have sufficient access, are running this script on the Veeam Backup for Microsoft 365 server, and that Veeam services are running."
  throw $_
}

# initializing global variables
$output = [System.Collections.ArrayList]::new()

# retrieving a list of organizations
$orgs = Get-VBOOrganization

# loop through each organization, check for multiple backup applications, and fix if requested
foreach ($org in $orgs) {
  # retrieve backup application(s)
  Write-Verbose "Checking backup applications for organization $($org.Name)"
  $apps = Get-VBOBackupApplication -Organization $org

  # check if multiple backup applications are used
  Write-Verbose "Backup Applications found: $($apps.Count)"
  if ($apps.Count -gt 1) {
    # adding field to show if backup application was removed
    $apps | Add-Member -MemberType NoteProperty -Name "RemovedFromVeeam" -Value $false

    # remove extra backup applications if the Fix flag is set
    if ($Fix) {
      Write-Verbose "Fix flag is set. Removing multiple backup applications for organization $($org.Name)..."
      # $j = 1 skipping first backup application
      $appsToRemove = $apps | Select-Object -Skip 1
      foreach ($app in $appsToRemove) {
        Write-Verbose "Removing backup application $($app.ApplicationId)"
        Remove-VBOBackupApplication -Organization $org -BackupApplication $app -Confirm:$false

        # noting that application was removed in output
        $app.RemovedFromVeeam = $true
      }
      Clear-Variable -Name appsToRemove
    }

    $object = [PSCustomObject] @{
      Organization       = $org.Name
      BackupApplications = $apps
    }
    [ref] $null = $output.Add($object)
    Clear-Variable -Name object
  }
  Clear-Variable -Name apps
}

if ($output.Count -eq 0) {
  Write-Verbose "No organizations with multiple backup applications found. Moving along..."
}

# logging out of Veeam session
Disconnect-VBOServer

# output results
if ($output.Count -eq 0) {
  Write-Host "No organizations with multiple backup applications found." -ForegroundColor Green
} elseif ($Fix) {
  Write-Host "Organizations with multiple backup applications have been identified and limited to a single backup application." -ForegroundColor Green
  $output
}
else {
  Write-Host "Organizations with multiple backup applications found. Per KB4821, each Organization must use a single backup application. Running this script with the -Fix parameter will resolve the issue." -ForegroundColor Red
  $output
}
