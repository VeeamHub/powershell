<#
.SYNOPSIS
    Adds a VB365 organization's Exchange Online Application ID to the EwsAllowedAppIDs
    allow list in Exchange Online, without overwriting existing entries.

    This script was created with the assistance of an AI coding tool (Claude/Anthropic).
    Review and test it in a lab environment before relying on it in production; provided
    as-is, with no warranty.

.NOTES
    Author: David Bewernick
    Last Modification Date: 2026-09-30
    License: MIT

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

Write-Host "Checking, installing and importing ExchangeOnlineManagement and Veeam.Archiver.PowerShell modules if needed." -ForegroundColor Yellow

if (-not (Get-Module -Name Veeam.Archiver.PowerShell)) {
    if (-not (Test-Path $ArchiverModulePath)) {
        throw "Veeam.Archiver.PowerShell.psd1 not found at '$ArchiverModulePath'. Set -ArchiverModulePath to its location."
    }
    Import-Module $ArchiverModulePath -ErrorAction Stop
}

$vb365ExoPathPattern = '\\Veeam\\Backup365\\'

$loadedExo = Get-Module -Name ExchangeOnlineManagement
if ($loadedExo -and $loadedExo.Path -match $vb365ExoPathPattern) {
    Write-Warning "ExchangeOnlineManagement is currently loaded from the VB365-bundled copy ('$($loadedExo.Path)'). Removing it so the official module can be loaded instead."
    Remove-Module -Name ExchangeOnlineManagement -Force
    $loadedExo = $null
}

if (-not $loadedExo) {
    $genuineExo = Get-Module -Name ExchangeOnlineManagement -ListAvailable |
        Where-Object { $_.Path -notmatch $vb365ExoPathPattern } |
        Sort-Object Version -Descending |
        Select-Object -First 1

    if (-not $genuineExo) {
        Write-Host "No standalone ExchangeOnlineManagement module found (only the copy bundled with VB365). Installing the official module from PSGallery..." -ForegroundColor Yellow
        Install-Module -Name ExchangeOnlineManagement -Scope CurrentUser -Force -ErrorAction Stop
        $genuineExo = Get-Module -Name ExchangeOnlineManagement -ListAvailable |
            Where-Object { $_.Path -notmatch $vb365ExoPathPattern } |
            Sort-Object Version -Descending |
            Select-Object -First 1
    }

    Import-Module $genuineExo.Path -ErrorAction Stop
}

$vb365ModuleLoaded = [bool](Get-Module -Name Veeam.Archiver.PowerShell)
$exoModuleLoaded = [bool](Get-Module -Name ExchangeOnlineManagement)

if ($vb365ModuleLoaded -and $exoModuleLoaded) {
    Write-Host "Veeam.Archiver.PowerShell and ExchangeOnlineManagement modules loaded successfully." -ForegroundColor Green
} else {
    Write-Host "PowerShell module load check failed: `n   Veeam.Archiver.PowerShell loaded: $vb365ModuleLoaded. `n   ExchangeOnlineManagement loaded: $exoModuleLoaded." -ForegroundColor Red
}



function Read-YesNo {
    param(
        [Parameter(Mandatory)][string]$Prompt,
        [System.ConsoleColor]$Color = [System.Console]::ForegroundColor
    )
    do {
        Write-Host "$Prompt (y/n): " -ForegroundColor $Color -NoNewline
        $answer = Read-Host
    } until ($answer -match '^[yYnN]$')
    return $answer -match '^[yY]$'
}

try {
    $organizations = Get-VBOOrganization -ErrorAction Stop
} catch {
    $vbServer = Read-Host "Not connected to VB365. Enter VB365 server name to connect"
    Connect-VBOServer -Server $vbServer
    $organizations = Get-VBOOrganization
}

if (-not $organizations) {
    Write-Warning "No organizations found in VB365."
    return
}

Write-Host "`nAvailable VB365 organizations:" -ForegroundColor Cyan
for ($i = 0; $i -lt $organizations.Count; $i++) {
    Write-Host "  [$i] $($organizations[$i].Name)"
}

$selectedIndex = -1
do {
    $selection = Read-Host "`nSelect organization number"
} until ([int]::TryParse($selection, [ref]$selectedIndex) -and $selectedIndex -ge 0 -and $selectedIndex -lt $organizations.Count)

$org = $organizations[$selectedIndex]
$appId = $org.Office365ExchangeConnectionSettings.ApplicationId

if ([string]::IsNullOrWhiteSpace($appId)) {
    Write-Warning "Organization '$($org.Name)' has no Exchange Online Application ID. Nothing to do."
    Disconnect-VBOServer
    return
}

Write-Host "`nSelected organization: $($org.Name)" -ForegroundColor Cyan
Write-Host "Application ID: $appId" -ForegroundColor Yellow

if (-not (Read-YesNo "`nContinue enabling EwsEnabled and adding this Application ID to the Exchange Online configuration?")) {
    Write-Host "Disconnecting from VB365..."
    Disconnect-VBOServer
    return
}

try {
    Connect-ExchangeOnline -ErrorAction Stop

    $orgConfig = Get-OrganizationConfig -ErrorAction Stop
    Write-Host "`nCurrent EwsEnabled status:"
    $orgConfig | Format-List EwsEnabled

    if (-not $orgConfig.EwsEnabled) {
        if (Read-YesNo "EwsEnabled is not set to `$true. Enable it now?" -Color Magenta) {
            Set-OrganizationConfig -EwsEnabled $true -ErrorAction Stop
            Write-Host "EwsEnabled set to `$true." -ForegroundColor Green
        }
    }

    $ewsPolicy = Get-OrganizationConfig -RetrieveEwsOperationAccessPolicy -ErrorAction Stop
    if ($null -eq $ewsPolicy) {
        throw "Get-OrganizationConfig -RetrieveEwsOperationAccessPolicy returned nothing. Cannot safely determine the current EwsAllowedAppIDs list."
    }
    Write-Host "`nCurrent EwsAllowedAppIDs:"
    $ewsPolicy | Format-List EwsAllowedAppIDs

    $currentAppIdList = @()
    if (-not [string]::IsNullOrWhiteSpace($ewsPolicy.EwsAllowedAppIDs)) {
        $currentAppIdList = $ewsPolicy.EwsAllowedAppIDs -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
    } elseif (-not (Read-YesNo "`nEwsAllowedAppIDs came back empty. Confirm this Exchange Online organization genuinely has no allow list entries yet (answering 'n' aborts without changing anything)" -Color Magenta)) {
        Write-Warning "Aborting: EwsAllowedAppIDs read as empty and this was not confirmed as genuine. Refusing to write, since that could silently wipe out an existing allow list."
        return
    }

    if ($currentAppIdList -contains $appId) {
        Write-Host "`nThe VB365 organization Application ID is already added to EwsAllowedAppIDs." -ForegroundColor Green
    } else {
        if (Read-YesNo "`nApplication ID $appId was not found in EwsAllowedAppIDs. Add it?" -Color Magenta) {
            $newAppIdsString = (@($currentAppIdList) + $appId) -join ','
            Set-OrganizationConfig -EwsAllowedAppIDs $newAppIdsString -ErrorAction Stop
            Write-Host "EwsAllowedAppIDs updated." -ForegroundColor Green
        } else {
            Write-Host "Skipped adding the Application ID."
        }
    }

    Write-Host "`nEwsAllowedAppIDs after update (verification):"
    (Get-OrganizationConfig -RetrieveEwsOperationAccessPolicy -ErrorAction Stop) | Format-List EwsAllowedAppIDs
} finally {
    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue
    Disconnect-VBOServer -ErrorAction SilentlyContinue
}

Write-Host "`nScript completed." -ForegroundColor Cyan
