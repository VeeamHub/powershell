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
    Path to Veeam.Archiver.PowerShell.dll in the VB365 install root
    (default: C:\Program Files\Veeam\Backup365\Veeam.Archiver.PowerShell.dll).
    Importing the DLL directly loads the current module natively in pwsh 7. The .psd1
    manifest in the Veeam.Archiver.PowerShell subfolder loads an older module version
    (6.0) that lacks newer cmdlets, and importing by module name goes through the
    Windows PowerShell compatibility layer, which drops -Confirm:$false.
#>

#Requires -Version 7.0

[CmdletBinding()]
param(
    [string]$ArchiverModulePath = 'C:\Program Files\Veeam\Backup365\Veeam.Archiver.PowerShell.dll'
)

### If needed, import PowerShell modules for VB365 and ExchangeOnline

Write-Host "Checking, installing and importing Veeam.Archiver.PowerShell module if needed." -ForegroundColor Yellow

if (-not (Get-Module -Name Veeam.Archiver.PowerShell)) {
    if (-not (Test-Path $ArchiverModulePath)) {
        throw "Veeam.Archiver.PowerShell module not found at '$ArchiverModulePath'. Set -ArchiverModulePath to its location."
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