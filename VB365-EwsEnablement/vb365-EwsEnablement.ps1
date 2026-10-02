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

# PowerShell v7 is required for this script
#Requires -Version 7.0

#define parameters and variables
[CmdletBinding()]
param(
    [string]$ArchiverModulePath = 'C:\Program Files\Veeam\Backup365\Veeam.Archiver.PowerShell\Veeam.Archiver.PowerShell.psd1'
)
$vb365ExoPathPattern = '\\Veeam\\Backup365\\'


### Modules pre-check and import for VB365 and ExchangeOnline

Write-Host "Checking, installing and importing ExchangeOnlineManagement and Veeam.Archiver.PowerShell modules if needed." -ForegroundColor Yellow

# Check if the Veeam.Archiver.PowerShell module is already loaded; if not, import it from the specified path
if (-not (Get-Module -Name Veeam.Archiver.PowerShell)) {
    if (-not (Test-Path $ArchiverModulePath)) {
        throw "Veeam.Archiver.PowerShell.psd1 not found at '$ArchiverModulePath'. Set -ArchiverModulePath to its location."
    }
    Import-Module $ArchiverModulePath -ErrorAction Stop
}

#check if ExchangeOnlineManagement is loaded from the VB365-bundled copy; if so, remove it to allow the official module to be loaded instead
$loadedExo = Get-Module -Name ExchangeOnlineManagement
if ($loadedExo -and $loadedExo.Path -match $vb365ExoPathPattern) {
    Write-Warning "ExchangeOnlineManagement is currently loaded from the VB365-bundled copy ('$($loadedExo.Path)'). Removing it so the official module can be loaded instead."
    Remove-Module -Name ExchangeOnlineManagement -Force
    $loadedExo = $null
}

$exoMaxVersion = $null
if ($PSVersionTable.PSVersion -lt [version]'7.6.0') {
    $exoMaxVersion = [version]'3.9.99'
    Write-Host "PowerShell $($PSVersionTable.PSVersion) detected. ExchangeOnlineManagement 3.10+ needs 7.6, so a 3.9.x release will be used." -ForegroundColor Yellow
}
function Get-GenuineExoModule {
    # Newest standalone copy that this pwsh can actually load. Skips the VB365-bundled copies and, on pwsh older than 7.6, any 3.10+ copy that may already be installed.
    Get-Module -Name ExchangeOnlineManagement -ListAvailable |
        Where-Object { $_.Path -notmatch $vb365ExoPathPattern } |
        Where-Object { -not $exoMaxVersion -or $_.Version -le $exoMaxVersion } |
        Sort-Object Version -Descending |
        Select-Object -First 1
}
if (-not $loadedExo) {
    $genuineExo = Get-GenuineExoModule
    if (-not $genuineExo) {
        Write-Host "No usable standalone ExchangeOnlineManagement module found (only the copy bundled with VB365, or only a version this PowerShell cannot load). Installing from PSGallery..." -ForegroundColor Yellow
        $installParams = @{
            Name         = 'ExchangeOnlineManagement'
            Scope        = 'CurrentUser'
            AllowClobber = $true
            Force        = $true
            ErrorAction  = 'Stop'
        }
        if ($exoMaxVersion) { $installParams.MaximumVersion = $exoMaxVersion.ToString() }
        Install-Module @installParams
        $genuineExo = Get-GenuineExoModule
    }
    if (-not $genuineExo) {
        throw "ExchangeOnlineManagement could not be found after installation."
    }
    Write-Host "Importing ExchangeOnlineManagement $($genuineExo.Version) from '$($genuineExo.ModuleBase)'."
    Import-Module $genuineExo.Path -ErrorAction Stop
}

# Verify that both modules are loaded, otherwise exit the script.
$vb365ModuleLoaded = $false
$exoModuleLoaded = $false
$vb365ModuleLoaded = [bool](Get-Module -Name Veeam.Archiver.PowerShell)
$exoModuleLoaded = [bool](Get-Module -Name ExchangeOnlineManagement)

if ($vb365ModuleLoaded -and $exoModuleLoaded) {
    Write-Host "Veeam.Archiver.PowerShell and ExchangeOnlineManagement modules loaded successfully." -ForegroundColor Green
} else {
    Write-Host "PowerShell module load check failed: `n   Veeam.Archiver.PowerShell loaded: $vb365ModuleLoaded. `n   ExchangeOnlineManagement loaded: $exoModuleLoaded." -ForegroundColor Red
    Write-Host "Exiting script due to module load failure." -ForegroundColor Red
    Break
}


# Little capture function for yes/no answers
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

### Main script logic starts here

# Check connection to VB365 and retrieve organizations
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

# List available organizations and prompt user selection

Write-Host "`nAvailable VB365 organizations:" -ForegroundColor Cyan
for ($i = 0; $i -lt $organizations.Count; $i++) {
    Write-Host "  [$i] $($organizations[$i].Name)"
}

$selectedIndex = -1
do {
    $selection = Read-Host "`nSelect organization number"
} until ([int]::TryParse($selection, [ref]$selectedIndex) -and $selectedIndex -ge 0 -and $selectedIndex -lt $organizations.Count)

$org = $organizations[$selectedIndex]

# Retrieve the Application ID for the selected organization
$appId = $org.Office365ExchangeConnectionSettings.ApplicationId

if ([string]::IsNullOrWhiteSpace($appId)) {
    Write-Warning "Organization '$($org.Name)' has no Exchange Online Application ID. Please check the VB365 configuration for this organization and ensure it is set up correctly."
    Disconnect-VBOServer
    return
}

Write-Host "`nSelected organization: $($org.Name)" -ForegroundColor Cyan
Write-Host "Application ID: $appId" -ForegroundColor Yellow

# Prompt user to confirm continuation of adding the Application ID to EwsAllowedAppIDs
if (-not (Read-YesNo "`nContinue enabling EwsEnabled and adding this Application ID to the Exchange Online configuration?" -Color Magenta)) {
    Write-Host "Disconnecting from VB365..."
    Disconnect-VBOServer
    return
}


# Connect to Exchange Online and perform the EwsEnabled and EwsAllowedAppIDs checks/updates
try {
    Connect-ExchangeOnline -ErrorAction Stop

    # Get the current EwsEnabled status
    $orgConfig = Get-OrganizationConfig -ErrorAction Stop
    Write-Host "`nCurrent EwsEnabled status:"
    $orgConfig | Format-List EwsEnabled

    # If EwsEnabled is not enabled, should this be done?
    if (-not $orgConfig.EwsEnabled) {
        if (Read-YesNo "EwsEnabled is not set to `$true. Enable it now?" -Color Magenta) {
            Set-OrganizationConfig -EwsEnabled $true -ErrorAction Stop
            Write-Host "EwsEnabled set to `$true." -ForegroundColor Green
        }
    }
    # Get the current EwsAllowedAppIDs list
    $ewsPolicy = Get-OrganizationConfig -RetrieveEwsOperationAccessPolicy -ErrorAction Stop
    if ($null -eq $ewsPolicy) {
        throw "Get-OrganizationConfig -RetrieveEwsOperationAccessPolicy returned nothing. Cannot safely determine the current EwsAllowedAppIDs list."
    }
    Write-Host "`nCurrent EwsAllowedAppIDs:"
    $ewsPolicy | Format-List EwsAllowedAppIDs

    # Check if the Application ID is already in the EwsAllowedAppIDs list. If the list is empty, confirm if this is expected.
    $currentAppIdList = @()
    if (-not [string]::IsNullOrWhiteSpace($ewsPolicy.EwsAllowedAppIDs)) {
        $currentAppIdList = $ewsPolicy.EwsAllowedAppIDs -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
    } elseif (-not (Read-YesNo "`nEwsAllowedAppIDs came back empty. Confirm this Exchange Online organization genuinely has no allow list entries yet (answering 'n' aborts without changing anything)" -Color Magenta)) {
        Write-Warning "Aborting: EwsAllowedAppIDs read as empty and this was not confirmed as genuine. Refusing to write, since that could silently wipe out an existing allow list."
        return
    }

    # Check if the Application ID is already present in the EwsAllowedAppIDs list. If not, should it be added?
    if ($currentAppIdList -contains $appId) {
        Write-Host "`nThe VB365 organization Application ID is already added to EwsAllowedAppIDs." -ForegroundColor Green
    } else {
        if (Read-YesNo "`nApplication ID $appId was not found in EwsAllowedAppIDs. Add it?" -Color Magenta) {
            $newAppIdsString = (@($currentAppIdList) + $appId) -join ','

            $setFailed = $false
            try {
                Set-OrganizationConfig -EwsAllowedAppIDs $newAppIdsString -ErrorAction Stop
            } catch {
                $setFailed = $true
                Write-Warning "Set-OrganizationConfig failed to update EwsAllowedAppIDs: $($_.Exception.Message)"
            }

            if (-not $setFailed) {
                $verifyPolicy = Get-OrganizationConfig -RetrieveEwsOperationAccessPolicy -ErrorAction Stop
                $verifyList = @()
                if (-not [string]::IsNullOrWhiteSpace($verifyPolicy.EwsAllowedAppIDs)) {
                    $verifyList = $verifyPolicy.EwsAllowedAppIDs -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
                }

                if ($verifyList -contains $appId) {
                    Write-Host "EwsAllowedAppIDs updated." -ForegroundColor Green
                } else {
                    $setFailed = $true
                    Write-Warning "Set-OrganizationConfig did not report an error, but Application ID $appId is not present in EwsAllowedAppIDs. It can take some time for the update to take effect or there was an issue during updating - verify manually."
                }
            }
        } else {
            Write-Host "`nSkipped adding the Application ID, nothing was changed!" -ForegroundColor yellow
        }
    }

    Write-Host "`nEwsAllowedAppIDs after main script action (verification):"
    (Get-OrganizationConfig -RetrieveEwsOperationAccessPolicy -ErrorAction Stop) | Format-List EwsAllowedAppIDs
}
catch {
    Write-Host "An error occurred during the main script execution: $($_.Exception.Message)" -ForegroundColor Red
    $setFailed = $true
} finally {
# Disconnect from Exchange Online and VB365, regardless of success or failure.
    Write-Host "`nDisconnecting from Exchange Online and VB365 if sessions are still active..."
    try {
        Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue
        Write-Host "Exchange Online disconnected." -ForegroundColor Green
    } catch {
        Write-Warning "Failed to disconnect from Exchange Online: $($_.Exception.Message)"
    }
    try {
        Disconnect-VBOServer -ErrorAction SilentlyContinue
        Write-Host "VB365 server disconnected." -ForegroundColor Green
    } catch {
        Write-Warning "Failed to disconnect from VB365 server: $($_.Exception.Message)"
    }
}

