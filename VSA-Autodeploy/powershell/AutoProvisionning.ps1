#Requires -Version 5.1
#Requires -Modules Hyper-V

<#
.SYNOPSIS
    Mounts ISOs to Hyper-V VMs and boots them from DVD for QA testing.

.DESCRIPTION
    Automates the process of mounting ISO images to multiple Hyper-V VMs, 
    setting boot order to DVD, and starting the VMs.

.PARAMETER ConfigFile
    Path to a CSV file containing VM configurations (Name, ISOPath columns).

.PARAMETER ISOBasePath
    Base directory for ISO files (optional, for relative paths).

.PARAMETER TranscriptPath
    Path for transcript logging (default: script directory\Logs).

.EXAMPLE
    .\QA.ps1 -ConfigFile ".\vm-config.csv"

.EXAMPLE
    # Default configuration (hardcoded VMs)
    .\QA.ps1

.NOTES
    Author: IT Operations
    Version: 2.1
    Requires: Hyper-V PowerShell Module, Administrator privileges
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory=$false, HelpMessage="Path to CSV configuration file")]
    [ValidateScript({
        if (-not (Test-Path $_ -PathType Leaf)) {
            throw "Configuration file not found: $_"
        }
        $true
    })]
    [string]$ConfigFile,

    [Parameter(Mandatory=$false, HelpMessage="Base directory for ISO files")]
    [string]$ISOBasePath,

    [Parameter(Mandatory=$false, HelpMessage="Path for transcript logging")]
    [string]$TranscriptPath = (Join-Path $PSScriptRoot "Logs")
)

# ==========================================
# INITIALIZATION
# ==========================================
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Start transcript
if (-not (Test-Path $TranscriptPath)) {
    New-Item -Path $TranscriptPath -ItemType Directory -Force | Out-Null
}
$transcriptFile = Join-Path $TranscriptPath ("HyperV-QA_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".log")
Start-Transcript -Path $transcriptFile -Append

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Hyper-V VM QA Provisioning" -ForegroundColor Cyan
Write-Host "  Version 2.1" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# ==========================================
# DEFAULT CONFIGURATION
# ==========================================
$defaultVMConfigs = @(
    @{Name="VBRv13DHCP"; ISOPath="K:\autodeploy vsa\test\DHCP_13.0.1.180_20251101.iso"},
    @{Name="VBRv13Static"; ISOPath="K:\autodeploy vsa\test\static.iso"},
    @{Name="VIAPROXY"; ISOPath="K:\autodeploy vsa\test\VIA_13.0.1.180_20251101.iso"},
    @{Name="VeeamJEOSVHR13"; ISOPath="K:\autodeploy vsa\test\VHR_13.0.1.180_20251101.iso"}
)

# ==========================================
# LOAD CONFIGURATION
# ==========================================
if ($ConfigFile) {
    Write-Host "`nLoading configuration from CSV: $ConfigFile" -ForegroundColor Cyan
    try {
        $csvData = Import-Csv -Path $ConfigFile -ErrorAction Stop
        
        $VMConfigs = $csvData | ForEach-Object {
            @{
                Name = $_.Name
                ISOPath = $_.ISOPath
            }
        }
        
        Write-Host "  ✓ Loaded $($VMConfigs.Count) VM configurations" -ForegroundColor Green
    } catch {
        Write-Host "  ✗ Failed to load CSV: $_" -ForegroundColor Red
        Stop-Transcript
        exit 1
    }
} else {
    Write-Host "`nUsing default VM configurations" -ForegroundColor Cyan
    $VMConfigs = $defaultVMConfigs
    Write-Host "  ✓ Processing $($VMConfigs.Count) VMs" -ForegroundColor Green
}

# ==========================================
# PROCESS EACH VM
# ==========================================
Write-Host "`nProvisioning VMs..." -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$results = @()

foreach ($config in $VMConfigs) {
    Write-Host "`nVM: $($config.Name)" -ForegroundColor Yellow
    
    $result = [PSCustomObject]@{
        VMName = $config.Name
        Success = $false
        Message = ""
        ISOPath = $config.ISOPath
        Actions = @()
    }
    
    try {
        # Resolve ISO path
        $isoPath = $config.ISOPath
        if ($ISOBasePath -and -not [System.IO.Path]::IsPathRooted($isoPath)) {
            $isoPath = Join-Path $ISOBasePath $isoPath
        }
        
        # Validate ISO exists
        if (-not (Test-Path $isoPath -PathType Leaf)) {
            throw "ISO file not found: $isoPath"
        }
        Write-Host "  ✓ ISO found: $isoPath" -ForegroundColor Gray
        
        # Validate VM exists
        $vm = Get-VM -Name $config.Name -ErrorAction Stop
        Write-Host "  ✓ VM found (Generation $($vm.Generation), State: $($vm.State))" -ForegroundColor Gray
        
        # Check if VM is already running
        if ($vm.State -eq 'Running') {
            Write-Host "  ⊘ VM is already running, skipping" -ForegroundColor Yellow
            $result.Success = $true
            $result.Message = "Already running"
            $results += $result
            continue
        }
        
        # Get or add DVD drive
        $dvdDrive = Get-VMDvdDrive -VMName $config.Name -ErrorAction SilentlyContinue
        
        if (-not $dvdDrive) {
            if ($PSCmdlet.ShouldProcess($config.Name, "Add DVD drive and mount ISO")) {
                Add-VMDvdDrive -VMName $config.Name -Path $isoPath -ErrorAction Stop
                Write-Host "  ✓ DVD drive added and ISO mounted" -ForegroundColor Green
                $result.Actions += "DVD drive added"
            }
        } else {
            if ($PSCmdlet.ShouldProcess($config.Name, "Mount ISO to existing DVD drive")) {
                Set-VMDvdDrive -VMName $config.Name -Path $isoPath -ErrorAction Stop
                Write-Host "  ✓ ISO mounted to existing DVD drive" -ForegroundColor Green
                $result.Actions += "ISO mounted"
            }
        }
        
        # Get DVD drive reference
        $dvd = Get-VMDvdDrive -VMName $config.Name -ErrorAction Stop
        
        # Set boot order (Generation 2 only)
        if ($vm.Generation -eq 2) {
            if ($PSCmdlet.ShouldProcess($config.Name, "Set DVD as first boot device")) {
                Set-VMFirmware -VMName $config.Name -FirstBootDevice $dvd -ErrorAction Stop
                Write-Host "  ✓ Boot order set: DVD first" -ForegroundColor Green
                $result.Actions += "Boot order configured"
            }
        } else {
            Write-Host "  ⓘ Generation 1 VM: Boot order managed via BIOS" -ForegroundColor Gray
            $result.Actions += "Gen1 (BIOS boot)"
        }
        
        # Start the VM
        if ($PSCmdlet.ShouldProcess($config.Name, "Start VM")) {
            Start-VM -Name $config.Name -ErrorAction Stop
            Write-Host "  ✓ VM started successfully" -ForegroundColor Green
            $result.Actions += "VM started"
        }
        
        $result.Success = $true
        $result.Message = "Provisioned successfully"
        
    } catch {
        Write-Host "  ✗ ERROR: $_" -ForegroundColor Red
        $result.Success = $false
        $result.Message = $_.Exception.Message
    }
    
    $results += $result
}

# ==========================================
# SUMMARY
# ==========================================
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Provisioning Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$successCount = @($results | Where-Object Success).Count
$failCount = @($results | Where-Object { -not $_.Success }).Count

Write-Host "`nTotal VMs: $($results.Count)" -ForegroundColor Gray
Write-Host "Successful: $successCount" -ForegroundColor Green
Write-Host "Failed: $failCount" -ForegroundColor $(if($failCount -gt 0){'Red'}else{'Green'})

Write-Host "`nDetailed Results:" -ForegroundColor Gray
foreach ($result in $results) {
    $color = if ($result.Success) { 'Green' } else { 'Red' }
    $symbol = if ($result.Success) { '✓' } else { '✗' }
    
    Write-Host "  $symbol $($result.VMName): $($result.Message)" -ForegroundColor $color
    
    # Safe array handling for Actions
    $actionArray = @($result.Actions)
    if ($actionArray.Count -gt 0) {
        Write-Host "    Actions: $($actionArray -join ', ')" -ForegroundColor Gray
    }
}

if ($failCount -gt 0) {
    Write-Host "`nFailed VMs require attention:" -ForegroundColor Red
    $results | Where-Object { -not $_.Success } | ForEach-Object {
        Write-Host "  - $($_.VMName): $($_.Message)" -ForegroundColor Red
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Script completed!" -ForegroundColor Green
Write-Host "  Transcript: $transcriptFile" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

Stop-Transcript

# Exit with appropriate code
exit $(if ($failCount -gt 0) { 1 } else { 0 })
