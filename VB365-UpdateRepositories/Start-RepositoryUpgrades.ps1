<#
.SYNOPSIS
	Upgrades all outdated Veeam Backup for Microsoft 365 repositories.

.DESCRIPTION
	This script retrieves all backup repositories configured in Veeam Backup for
	Microsoft 365, filters those marked as outdated, and upgrades each one
	sequentially using the Start-VBORepositoryUpgradeSession cmdlet. A log file is
	written to the same directory as the script detailing upgrade results. If an
	upgrade fails, the script stops and the failure is recorded in the log.

.OUTPUTS
	Start-RepositoryUpgrades.ps1 writes upgrade results to a timestamped log file
	in the same directory as the script.

.EXAMPLE
	Start-RepositoryUpgrades.ps1

	Description
	-----------
	Upgrades all outdated Veeam Backup for Microsoft 365 repositories.

.EXAMPLE
	Start-RepositoryUpgrades.ps1 -Verbose

	Description
	-----------
	Verbose output is supported.

.NOTES
	NAME:  Start-RepositoryUpgrades.ps1
	VERSION: 1.0
	AUTHOR: Chris Arceneaux
	GITHUB: https://github.com/carceneaux

.LINK
	https://helpcenter.veeam.com/docs/vbo365/powershell/get-vborepository.html?ver=8

.LINK
	https://helpcenter.veeam.com/docs/vbo365/powershell/start-vborepositoryupgradesession.html?ver=8

.LINK
	https://helpcenter.veeam.com/docs/vbo365/powershell/get-vborepositoryupgradesession.html?ver=8

#>

[CmdletBinding()]
param()

# setting default PowerShell action to halt on error
$ErrorActionPreference = "Stop"

# importing Veeam PowerShell module
Import-Module "C:\Program Files\Veeam\Backup365\Veeam.Archiver.PowerShell\Veeam.Archiver.PowerShell.psd1"

# initializing log file in the same directory as the script
$logFile = Join-Path $PSScriptRoot "RepositoryUpgrades_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').log"

function Write-Log {
  param(
    [Parameter(Mandatory = $true)]
    [string] $Message,
    [Parameter(Mandatory = $false)]
    [ValidateSet("INFO", "ERROR")]
    [string] $Level = "INFO"
  )
  $logEntry = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] $Message"
  Add-Content -Path $logFile -Value $logEntry
  Write-Verbose $logEntry
}

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

# retrieving all backup repositories
$repositories = Get-VBORepository

Write-Verbose "Total repositories found: $($repositories.Count)"

# filtering to only outdated repositories
$outdatedRepos = $repositories | Where-Object { $_.IsOutdated -eq $true }

Write-Verbose "Outdated repositories found: $($outdatedRepos.Count)"

if ($outdatedRepos.Count -eq 0) {
  Write-Host "No outdated repositories found. No upgrades needed." -ForegroundColor Green
  Write-Log -Message "No outdated repositories found. No upgrades needed."
  Disconnect-VBOServer
  exit
}

Write-Host "Found $($outdatedRepos.Count) outdated repository(ies) to upgrade." -ForegroundColor Yellow
Write-Log -Message "Found $($outdatedRepos.Count) outdated repository(ies) to upgrade."

# loop through each outdated repository and upgrade one at a time
foreach ($repo in $outdatedRepos) {
  Write-Host "Upgrading repository: $($repo.Name)..." -ForegroundColor Yellow
  Write-Verbose "Starting upgrade session for repository: $($repo.Name)"
  Write-Log -Message "Starting upgrade for repository: $($repo.Name)"

  try {
    # start the upgrade session
    Start-VBORepositoryUpgradeSession -Repository $repo

    # wait for the upgrade session to complete
    do {
      Start-Sleep -Seconds 10
      $session = Get-VBORepositoryUpgradeSession -Repository $repo
      Write-Verbose "Repository: $($repo.Name) | Upgrade Status: $($session.Status)"
    } while ($session.Status -notlike "Upgrading")

    # check if the upgrade was successful
    if ($session.Status -eq "Repository is already up to date.") {
      Write-Host "Repository '$($repo.Name)' upgraded successfully." -ForegroundColor Green
      Write-Log -Message "Repository '$($repo.Name)' upgraded successfully."
    }
    else {
      $failMessage = "Repository '$($repo.Name)' upgrade failed with status '$($session.Status)'"
      Write-Host $failMessage -ForegroundColor Red
      Write-Log -Message $failMessage -Level "ERROR"
      throw $failMessage
    }
  }
  catch {
    $errorMessage = "Repository '$($repo.Name)' upgrade encountered an error: $_"
    Write-Host $errorMessage -ForegroundColor Red
    Write-Log -Message $errorMessage -Level "ERROR"

    # logging out of Veeam session before stopping
    Disconnect-VBOServer

    throw $_
  }
}

# logging out of Veeam session
Disconnect-VBOServer

Write-Host "All outdated repositories have been successfully upgraded." -ForegroundColor Green
Write-Log -Message "All outdated repositories have been successfully upgraded."
