<#
.SYNOPSIS
	Enable the migration related cmdlets for migrating Jet Repositories to Object Storage Repositories.

.DESCRIPTION
  This script need to be run in PowerShell v7. It enables the migration related cmdlets for migrating Jet Repositories to Object Storage Repositories and the easiest way would be to run it on the VB365 Controller.
  The enablement is only for the current PowerShell session, so if you want to use the migration cmdlets in a new PowerShell session, you will need to run this script again.

.OUTPUTS
	Enabled migration related cmdlets for migrating Jet Repositories to Object Storage Repositories.

.NOTES
	NAME:  VB365-EnableMigrationCmdlets.ps1
	VERSION: 1.3
	AUTHOR: David Bewernick
	GITHUB: https://github.com/d-works
	
.PARAMETER ArchiverModulePath
    Path to the Veeam.Archiver.PowerShell module manifest (.psd1). Importing by manifest
    path (instead of by module name) avoids the pwsh 7 Windows PowerShell compatibility/
    implicit-remoting layer, which is known to silently drop -Confirm:$false on some
    VB365 cmdlets.
#>

#Requires -Version 7.0

[CmdletBinding()]
param(
    [string]$ArchiverModulePath = 'C:\Program Files\Veeam\Backup365\Veeam.Archiver.PowerShell\Veeam.Archiver.PowerShell.psd1'
)

### If needed, import PowerShell modules for VB365 and ExchangeOnline

Write-Host "Checking, installing and importing Veeam.Archiver.PowerShell module if needed." -ForegroundColor Yellow

if (-not (Get-Module -Name Veeam.Archiver.PowerShell)) {
    if (-not (Test-Path $ArchiverModulePath)) {
        throw "Veeam.Archiver.PowerShell.psd1 not found at '$ArchiverModulePath'. Set -ArchiverModulePath to its location."
    }
    Import-Module $ArchiverModulePath
}

$vb365ModuleLoaded = [bool](Get-Module -Name Veeam.Archiver.PowerShell)

if ($vb365ModuleLoaded) {
    Write-Host "Veeam.Archiver.PowerShell module loaded successfully." -ForegroundColor Green
} else {
    Write-Host "PowerShell module load check failed: `n   Veeam.Archiver.PowerShell loaded: $vb365ModuleLoaded." -ForegroundColor Red
}

#enable the migration option (on VB365 server)
[Environment]::SetEnvironmentVariable("VEEAM_DATA_MIGRATION_ENABLED", "true")