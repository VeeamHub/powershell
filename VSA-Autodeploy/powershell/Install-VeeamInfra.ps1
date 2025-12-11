#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Installs Veeam License, Adds Linux Proxy and Hardened Repository.

.DESCRIPTION
    Connects to a VBR server, applies a license, and registers Linux infrastructure components.
    Retries connection for up to 45 minutes if the VBR server is unavailable.
    
.PARAMETER VbrServer
    IP address or hostname of the VBR server
    
.PARAMETER Credential
    PSCredential object for VBR authentication
    
.PARAMETER VbrUsername
    Username for VBR (used if Credential not provided)
    
.PARAMETER ProxyIP
    IP address of the Linux Proxy (JeOS)
    
.PARAMETER RepositoryIP
    IP address of the Linux Hardened Repository
    
.PARAMETER RepositoryName
    Name for the backup repository in VBR
    
.PARAMETER PairingCodeProxy
    Pairing code for the Proxy appliance
    
.PARAMETER PairingCodeRepo
    Pairing code for the Repository appliance
    
.PARAMETER LicenseFilePath
    Full path to the license file
    
.PARAMETER ImmutabilityPeriod
    Immutability period in days (1-365)
    
.PARAMETER RetryInterval
    Seconds to wait between connection attempts
    
.PARAMETER Timeout
    Total timeout in seconds for connection attempts
    
.PARAMETER ProxyMaxTasks
    Maximum concurrent tasks for the proxy
    
.PARAMETER TranscriptPath
    Path for transcript logging (default: script directory)

.EXAMPLE
    $cred = Get-Credential
    .\Install-VeeamInfra.ps1 -VbrServer "192.168.1.168" -Credential $cred `
        -ProxyIP "192.168.1.141" -RepositoryIP "192.168.1.122" `
        -RepositoryName "HardenedRepo-122" -ImmutabilityPeriod 30 `
        -LicenseFilePath "K:\autodeploy vsa\test\license\Veeam-100instances-entplus-monitoring-nfr.lic"

        
        

.NOTES
    Author: Infrastructure Team
    Version: 2.0
    Requires: Veeam Backup & Replication PowerShell Module
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, HelpMessage="IP address or hostname of the VBR server")]
    [ValidateNotNullOrEmpty()]
    [string]$VbrServer,

    [Parameter(Mandatory=$false, HelpMessage="Username for VBR server")]
    [string]$VbrUsername,

    [Parameter(Mandatory=$false, HelpMessage="Password for VBR server")]
    [string]$VbrPassword,

    [Parameter(Mandatory=$false, HelpMessage="IP of the Linux Proxy (JeOS)")]
    [ValidatePattern('^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$|^(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)*[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$')]
    [string]$ProxyIP,

    [Parameter(Mandatory=$false, HelpMessage="IP of the Linux Hardened Repository (JeOS)")]
    [ValidatePattern('^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$|^(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)*[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$')]
    [string]$RepositoryIP,

    [Parameter(Mandatory=$false, HelpMessage="Name for the Backup Repository in VBR")]
    [ValidateLength(1,255)]
    [string]$RepositoryName,

    [Parameter(Mandatory=$false, HelpMessage="Pairing code for the Proxy appliance")]
    [ValidatePattern('^\d{6}$')]
    [string]$PairingCodeProxy = "000000",

    [Parameter(Mandatory=$false, HelpMessage="Pairing code for the Repository appliance")]
    [ValidatePattern('^\d{6}$')]
    [string]$PairingCodeRepo  = "000000",

    [Parameter(Mandatory=$false, HelpMessage="Full path to the license file")]
    [ValidateScript({
        if ($_ -and -not (Test-Path $_ -PathType Leaf)) {
            throw "License file not found: $_"
        }
        $true
    })]
    [string]$LicenseFilePath,

    [Parameter(Mandatory=$false, HelpMessage="Immutability period in days")]
    [ValidateRange(1,365)]
    [int]$ImmutabilityPeriod = 21,

    [Parameter(Mandatory=$false, HelpMessage="Seconds to wait between connection attempts")]
    [ValidateRange(30,600)]
    [int]$RetryInterval = 120,

    [Parameter(Mandatory=$false, HelpMessage="Total timeout in seconds for connection attempts")]
    [ValidateRange(300,7200)]
    [int]$Timeout = 2700,

    [Parameter(Mandatory=$false, HelpMessage="Maximum concurrent tasks for the proxy")]
    [ValidateRange(1,32)]
    [int]$ProxyMaxTasks = 4,

    [Parameter(Mandatory=$false, HelpMessage="Path for transcript logging")]
    [string]$TranscriptPath = (Join-Path $PSScriptRoot "Logs")
)

# ==========================================
# INITIALIZATION
# ==========================================
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Start transcript logging
if (-not (Test-Path $TranscriptPath)) {
    New-Item -Path $TranscriptPath -ItemType Directory -Force | Out-Null
}
$transcriptFile = Join-Path $TranscriptPath ("VeeamDeploy_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".log")
Start-Transcript -Path $transcriptFile -Append

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Veeam B&R - Infrastructure Deployment" -ForegroundColor Cyan
Write-Host "  Version 2.0" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Prompt for credentials if not provided
if (-not $VbrUsername) {
    $VbrUsername = Read-Host "Enter VBR username"
}

if (-not $VbrPassword) {
    $securePassword = Read-Host "Enter password for $VbrUsername" -AsSecureString
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
    $VbrPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
}

Write-Host "Using credentials for: $VbrUsername" -ForegroundColor Gray

# ==========================================
# HELPER FUNCTIONS
# ==========================================
function Write-Step {
    param([string]$Message, [int]$Step, [int]$Total)
    Write-Host "`n[$Step/$Total] $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "⚠ $Message" -ForegroundColor Yellow
}

function Write-Skip {
    param([string]$Message)
    Write-Host "⊘ $Message" -ForegroundColor Yellow
}

function Wait-ForHostReady {
    param(
        [Parameter(Mandatory=$true)]
        [string]$HostIP,
        
        [int]$MaxWaitSeconds = 60,
        [int]$PollInterval = 5
    )
    
    Write-Verbose "Waiting for host $HostIP to be ready..."
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    
    while ($stopwatch.Elapsed.TotalSeconds -lt $MaxWaitSeconds) {
        try {
            $VBRhost = Get-VBRServer -Name $HostIP -ErrorAction Stop
            if ($VBRhost) {
                Write-Verbose "Host $HostIP is ready"
                $stopwatch.Stop()
                return $true
            }
        } catch {
            Write-Verbose "Host not ready yet, waiting..."
        }
        Start-Sleep -Seconds $PollInterval
    }
    
    $stopwatch.Stop()
    Write-Warning "Timeout waiting for host $HostIP to be ready"
    return $false
}

function Add-JeOSLinuxHost {
    param(
        [Parameter(Mandatory=$true)]
        [string]$IP,
        
        [Parameter(Mandatory=$true)]
        [string]$PairingCode,
        
        [Parameter(Mandatory=$true)]
        [string]$Description
    )
    
    $existing = Get-VBRServer | Where-Object { $_.Name -eq $IP }
    if ($existing) {
        Write-Skip "Linux host $IP already exists"
        return $existing
    }
    
    Write-Verbose "Adding Linux host: $IP"
    try {
        return Add-VBRLinux -Name $IP -UseCertificate -HandshakeCode $PairingCode `
            -ForceDeployerFingerprint -Description $Description -ErrorAction Stop
    } catch {
        Write-Error "Failed to add Linux host $IP : $_"
        throw
    }
}

function Disconnect-VBRServerSafely {
    try {
        if (Get-VBRServerSession -ErrorAction SilentlyContinue) {
            Disconnect-VBRServer -ErrorAction SilentlyContinue
            Write-Verbose "Disconnected from VBR server"
        }
    } catch {
        Write-Verbose "Error during disconnect: $_"
    }
}

# ==========================================
# STEP 1: LOAD VEEAM POWERSHELL MODULE
# ==========================================
try {
    Write-Step -Message "Loading Veeam PowerShell module..." -Step 1 -Total 7
    
    $VBRPSFolder = "C:\Program Files\Veeam\Backup and Replication\Console\Veeam.Backup.PowerShell"
    
    if (-not (Test-Path $VBRPSFolder)) {
        throw "Veeam PowerShell folder not found at: $VBRPSFolder"
    }
    
    # Check if module is already loaded
    if (Get-Module -Name Veeam.Backup.PowerShell -ErrorAction SilentlyContinue) {
        Write-Skip "Veeam module already loaded"
    } else {
        Write-Verbose "Loading Veeam assemblies..."
        $assemblies = @(
            "Veeam.Backup.Core.dll",
            "Veeam.Backup.Core.Common.dll",
            "Veeam.Backup.Common.dll",
            "Veeam.Backup.Model.dll",
            "Rebex.Networking.dll",
            "Veeam.Backup.AzureAPI.dll"
        )
        
        foreach ($assembly in $assemblies) {
            $path = Join-Path (Split-Path $VBRPSFolder -Parent) $assembly
            if (Test-Path $path) {
                Add-Type -Path $path -ErrorAction Stop
            } else {
                Write-Warning "Assembly not found: $assembly (continuing anyway)"
            }
        }
        
        Import-Module (Join-Path (Split-Path $VBRPSFolder -Parent) "Veeam.Backup.PowerShell.dll") `
            -DisableNameChecking -ErrorAction Stop
        
        Write-Success "Veeam PowerShell module loaded successfully"
    }
} catch {
    Write-Host "✗ Failed to load Veeam PowerShell module: $_" -ForegroundColor Red
    Stop-Transcript
    exit 1
}

# ==========================================
# STEP 2: CONNECT TO VBR SERVER
# ==========================================
try {
    Write-Step -Message "Connecting to VBR server..." -Step 2 -Total 7
    
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $connected = $false
    
    while ($stopwatch.Elapsed.TotalSeconds -lt $Timeout) {
        try {
            Disconnect-VBRServerSafely
            
            Connect-VBRServer -Server $VbrServer -User $VbrUsername -Password $VbrPassword `
                -ForceAcceptTlsCertificate -ErrorAction Stop
            
            Write-Success "Connected to VBR server: $VbrServer"
            $connected = $true
            break
        } catch {
            $elapsedMinutes = [math]::Round($stopwatch.Elapsed.TotalMinutes, 1)
            $remainingMinutes = [math]::Round(($Timeout - $stopwatch.Elapsed.TotalSeconds) / 60, 1)
            
            Write-Warning "Connection attempt failed after $elapsedMinutes minutes: $_"
            
            if ($stopwatch.Elapsed.TotalSeconds -lt $Timeout) {
                Write-Host "⟳ Retrying in $($RetryInterval / 60) minutes... ($remainingMinutes minutes remaining)" -ForegroundColor Cyan
                Start-Sleep -Seconds $RetryInterval
            }
        }
    }
    
    $stopwatch.Stop()
    
    if (-not $connected) {
        throw "Failed to connect to VBR server after $($Timeout/60) minutes"
    }
} catch {
    Write-Host "✗ $_" -ForegroundColor Red
    Stop-Transcript
    exit 1
}

# ==========================================
# STEP 3: INSTALL LICENSE
# ==========================================
Write-Step -Message "Installing license..." -Step 3 -Total 7

if (-not $LicenseFilePath) {
    Write-Skip "No license file specified, skipping"
} elseif (-not (Test-Path $LicenseFilePath)) {
    Write-Warning "License file not found: $LicenseFilePath"
    Write-Host "  Continuing without license installation..." -ForegroundColor Yellow
} else {
    # Show file info
    $licFile = Get-Item $LicenseFilePath
    Write-Host "  Checking license file: $LicenseFilePath" -ForegroundColor Gray
    Write-Host "  File size: $($licFile.Length) bytes" -ForegroundColor Gray
    Write-Host "  Last modified: $($licFile.LastWriteTime)" -ForegroundColor Gray
    
    # Validate file content
    try {
        $licContent = Get-Content $LicenseFilePath -Raw -ErrorAction Stop
        if ($licContent -match '<license') {
            Write-Host "  File format: Valid XML" -ForegroundColor Gray
        } else {
            Write-Warning "License file does not appear to be valid XML format"
        }
    } catch {
        Write-Warning "Cannot read license file: $_"
    }
    
    # Check for existing license (handle exception if no license installed)
    Write-Host "  Checking for existing license..." -ForegroundColor Gray
    $existingLicense = $null
    $hasLicense = $false
    
    try {
        $existingLicense = Get-VBRInstalledLicense -ErrorAction Stop
        $hasLicense = $true
    } catch {
        # Exception is expected when no license is installed
        if ($_.Exception.Message -match "No valid license|not installed|no license") {
            Write-Host "  No existing license found (fresh installation)" -ForegroundColor Gray
            $hasLicense = $false
        } else {
            # Unexpected error
            Write-Warning "Error checking existing license: $($_.Exception.Message)"
            $hasLicense = $false
        }
    }
    
    if ($hasLicense -and $existingLicense) {
        Write-Skip "A license is already installed"
        Write-Host "  Licensed To: $($existingLicense.LicensedTo)" -ForegroundColor Gray
        Write-Host "  Edition: $($existingLicense.Edition)" -ForegroundColor Gray
        Write-Host "  Status: $($existingLicense.Status)" -ForegroundColor Gray
        Write-Host "  Expiration: $($existingLicense.ExpirationDate)" -ForegroundColor Gray
    } else {
        # No license installed, proceed with installation
        Write-Host "  Installing license from file..." -ForegroundColor Gray
        
        try {
            Install-VBRLicense -Path $LicenseFilePath -ErrorAction Stop
            Write-Host "  License installation command completed" -ForegroundColor Gray
            
            # Wait for license to register in the system
            Write-Host "  Waiting for license registration..." -ForegroundColor Gray
            Start-Sleep -Seconds 5
            
            # Verify installation
            try {
                $newLicense = Get-VBRInstalledLicense -ErrorAction Stop
                
                if ($newLicense) {
                    Write-Success "License installed successfully"
                    Write-Host "  Licensed To: $($newLicense.LicensedTo)" -ForegroundColor Gray
                    Write-Host "  Edition: $($newLicense.Edition)" -ForegroundColor Gray
                    Write-Host "  Status: $($newLicense.Status)" -ForegroundColor Gray
                    Write-Host "  Expiration: $($newLicense.ExpirationDate)" -ForegroundColor Gray
                } else {
                    Write-Warning "License installation completed but verification returned null"
                }
            } catch {
                Write-Warning "License verification failed: $($_.Exception.Message)"
                Write-Host "  The license may have been installed but cannot be verified" -ForegroundColor Yellow
            }
            
        } catch {
            Write-Warning "License installation failed: $($_.Exception.Message)"
            Write-Host "  Error details: $($_.Exception.GetType().FullName)" -ForegroundColor Gray
            
            # Provide helpful guidance
            if ($_.Exception.Message -match "expired") {
                Write-Host "  → License appears to be expired. Request a new license." -ForegroundColor Yellow
            } elseif ($_.Exception.Message -match "invalid|corrupt") {
                Write-Host "  → License file may be corrupted. Re-download from Veeam portal." -ForegroundColor Yellow
            } elseif ($_.Exception.Message -match "version|mismatch") {
                Write-Host "  → License may not match this Veeam version." -ForegroundColor Yellow
            }
        }
    }
    
    Write-Host "  Continuing with deployment..." -ForegroundColor Gray
}

# ==========================================
# STEP 4: VALIDATE PREREQUISITES
# ==========================================
Write-Step -Message "Validating prerequisites..." -Step 4 -Total 7

$componentsToAdd = @()
if ($ProxyIP) { $componentsToAdd += "Proxy" }
if ($RepositoryIP) { $componentsToAdd += "Repository" }

if ($componentsToAdd.Count -eq 0) {
    Write-Skip "No infrastructure components specified, skipping steps 4-7"
    Disconnect-VBRServerSafely
    Stop-Transcript
    exit 0
}

Write-Host "  Components to configure: $($componentsToAdd -join ', ')" -ForegroundColor Gray

# ==========================================
# STEP 5: ADD LINUX HOSTS
# ==========================================
try {
    Write-Step -Message "Adding Linux hosts..." -Step 5 -Total 7
    
    $linuxHosts = @{}
    
    if ($RepositoryIP) {
        if (-not $PairingCodeRepo) {
            throw "PairingCodeRepo is required when RepositoryIP is specified"
        }
        Write-Verbose "Adding repository host: $RepositoryIP"
        $linuxHosts['Repository'] = Add-JeOSLinuxHost -IP $RepositoryIP `
            -PairingCode $PairingCodeRepo -Description "Hardened Repository (JeOS)"
        Wait-ForHostReady -HostIP $RepositoryIP -MaxWaitSeconds 60 | Out-Null
    }
    
    if ($ProxyIP) {
        if (-not $PairingCodeProxy) {
            throw "PairingCodeProxy is required when ProxyIP is specified"
        }
        Write-Verbose "Adding proxy host: $ProxyIP"
        $linuxHosts['Proxy'] = Add-JeOSLinuxHost -IP $ProxyIP `
            -PairingCode $PairingCodeProxy -Description "Proxy (JeOS)"
        Wait-ForHostReady -HostIP $ProxyIP -MaxWaitSeconds 60 | Out-Null
    }
    
    Write-Success "Linux hosts added successfully"
} catch {
    Write-Warning "Failed to add Linux hosts: $_"
}

# ==========================================
# STEP 6: CONFIGURE BACKUP PROXY
# ==========================================
if ($ProxyIP) {
    try {
        Write-Step -Message "Configuring backup proxy..." -Step 6 -Total 7
        
        $linuxProxy = Get-VBRServer | Where-Object { $_.Name -eq $ProxyIP }
        if (-not $linuxProxy) {
            throw "Linux Proxy host not found in infrastructure"
        }
        
        $existingProxy = Get-VBRViProxy | Where-Object { $_.Host.Name -eq $ProxyIP }
        if ($existingProxy) {
            Write-Skip "Proxy already configured for $ProxyIP"
        } else {
            Add-VBRViLinuxProxy -Server $linuxProxy -Description "Linux Backup Proxy (JeOS)" `
                -MaxTasks $ProxyMaxTasks -ErrorAction Stop
            Write-Success "Proxy configured for $ProxyIP with $ProxyMaxTasks max tasks"
        }
    } catch {
        Write-Warning "Failed to configure backup proxy: $_"
    }
}

# ==========================================
# STEP 7: CONFIGURE HARDENED REPOSITORY
# ==========================================
if ($RepositoryIP) {
    try {
        Write-Step -Message "Configuring hardened repository..." -Step 7 -Total 7
        
        if (-not $RepositoryName) {
            throw "RepositoryName is required when RepositoryIP is specified"
        }
        
        $linuxRepo = Get-VBRServer | Where-Object { $_.Name -eq $RepositoryIP }
        if (-not $linuxRepo) {
            throw "Linux Repository host not found in infrastructure"
        }
        
        $existingRepo = Get-VBRBackupRepository | Where-Object { $_.Name -eq $RepositoryName }
        if ($existingRepo) {
            Write-Skip "Hardened repository '$RepositoryName' already exists"
        } else {
            Add-VBRBackupRepository -Folder "/var/lib/veeam/backups" -Type Hardened `
                -Name $RepositoryName -Server $linuxRepo -EnableXFSFastClone `
                -EnableBackupImmutability -ImmutabilityPeriod $ImmutabilityPeriod -Force
            
            Write-Success "Hardened repository '$RepositoryName' created (Immutability: $ImmutabilityPeriod days)"
        }
    } catch {
        Write-Warning "Failed to configure hardened repository: $_"
    }
}

# ==========================================
# DEPLOYMENT SUMMARY
# ==========================================
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Deployment Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

try {
    $linuxServers = Get-VBRServer | Where-Object { $_.Type -eq "Linux" }
    Write-Host "`nLinux Hosts: $($linuxServers.Count)" -ForegroundColor Gray
    foreach ($s in $linuxServers) {
        Write-Host "  - $($s.Name)" -ForegroundColor Gray
    }
    
    $proxies = Get-VBRViProxy
    Write-Host "`nBackup Proxies: $($proxies.Count)" -ForegroundColor Gray
    foreach ($p in $proxies) {
        $status = if ($p.IsDisabled) { "[Disabled]" } else { "[Enabled]" }
        Write-Host "  - $($p.Name) $status (Max Tasks: $($p.Options.MaxTasksCount))" -ForegroundColor Gray
    }
    
    $repositories = Get-VBRBackupRepository
    Write-Host "`nBackup Repositories: $($repositories.Count)" -ForegroundColor Gray
    foreach ($r in $repositories) {
        Write-Host "  - $($r.Name)" -ForegroundColor Gray
    }
    
    Write-Host "`n" -NoNewline
    Write-Success "Deployment completed successfully"
} catch {
    Write-Warning "Could not retrieve complete deployment summary: $_"
}

# ==========================================
# CLEANUP
# ==========================================
Disconnect-VBRServerSafely

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Script execution completed!" -ForegroundColor Green
Write-Host "  Transcript: $transcriptFile" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

Stop-Transcript
