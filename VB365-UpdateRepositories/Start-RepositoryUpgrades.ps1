<#
.SYNOPSIS
	Upgrades all outdated Veeam Backup for Microsoft 365 repositories.

.DESCRIPTION
	This script retrieves all backup repositories configured in Veeam Backup for
	Microsoft 365, filters those marked as outdated, and upgrades each one
	sequentially using the Start-VBORepositoryUpgradeSession cmdlet. A log file is
	written to the same directory as the script detailing upgrade results.

  If an upgrade fails, the script does not stop but logs the failure — including the error message received — and continues on to the next repository. All logs are written to a log file located in the same folder as the script.

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
	VERSION: 1.1
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
$success = 0
$fail = 0

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

Write-Host "Found $($outdatedRepos.Count) outdated repositories to upgrade." -ForegroundColor Yellow
Write-Log -Message "Found $($outdatedRepos.Count) outdated repositories to upgrade."

# loop through each outdated repository and upgrade one at a time
foreach ($repo in $outdatedRepos) {
  Write-Host "Upgrading repository: $($repo.Name)..." -ForegroundColor Yellow
  Write-Verbose "Starting upgrade session for repository: $($repo.Name)"
  Write-Log -Message "Starting upgrade for repository: $($repo.Name)"

  try {
    # start the upgrade session
    Start-VBORepositoryUpgradeSession -Repository $repo | Out-Null

    # wait for the upgrade session to complete
    $time = 0
    while ($true) {
      Start-Sleep -Seconds 10
      $time += 10

      # checking to see if upgrade is complete
      Write-Host "Elapsed time: $time seconds"

      $command = {
          param($repository)
          $repo = Get-VBORepository -Name $repository
          Get-VBORepositoryUpgradeSession -Repository $repo
      }

      $pInfo = New-Object System.Diagnostics.ProcessStartInfo
      $pInfo.FileName = "powershell.exe"
      $pInfo.RedirectStandardError = $true
      $pInfo.RedirectStandardOutput = $true
      $pInfo.UseShellExecute = $false
      $pInfo.Arguments = "-Command & { $($command) } '$($repo.Name)'"
      $p = New-Object System.Diagnostics.Process
      $p.StartInfo = $pInfo
      $p.Start() | Out-Null
      $p.WaitForExit()
      $stdout = $p.StandardOutput.ReadToEnd()
      $stderr = $p.StandardError.ReadToEnd()
      $exitcode = $p.ExitCode
      Write-Verbose "stdout: $stdout"
      Write-Verbose "stderr: $stderr"
      Write-Verbose "exit code: $exitcode"

      if ($stdout -like "*up to date*") {
        $success++
        Write-Host "Repository '$($repo.Name)' upgraded successfully." -ForegroundColor Green
        Write-Log -Message "Complete time to upgrade repository '$($repo.Name)': $time seconds"
        Write-Log -Message "Repository '$($repo.Name)' upgraded successfully."
        break
      }

      if ($exitcode -ne 0) {
        $fail++
        Write-Log -Message "Upgrade error for repository '$($repo.Name)' failed at $time seconds" -Level "ERROR"
        throw "An error occurred while checking the upgrade status for repository '$($repo.Name)': $stderr"
      } else {
        Write-Verbose "Repository: $($repo.Name) | Upgrade Status: $stdout"
      }
    }
  }
  catch {
    $errorMessage = "REPOSITORY WAS NOT UPGRADED! ($($repo.Name)) $_"
    Write-Host $errorMessage -ForegroundColor Red
    Write-Log -Message $errorMessage -Level "ERROR"
  }
}

# logging out of Veeam session
Disconnect-VBOServer

Write-Log -Message "Total successful upgrades: $success"
Write-Log -Message "Total failed upgrades: $fail"
Write-Host "All outdated repositories have been processed." -ForegroundColor Yellow
Write-Host "Total successful upgrades: $success" -ForegroundColor Green
Write-Host "Total failed upgrades: $fail" -ForegroundColor Red