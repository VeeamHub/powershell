<#
.SYNOPSIS
Veeam Appliance ISO Automation Tool

.LICENSE
MIT License - see LICENSE file for details

.AUTHOR
Baptiste TELLIER

.COPYRIGHT
Copyright (c) 2025 Baptiste TELLIER

.VERSION 2.1

.DESCRIPTION
This PowerShell script provides automation for customizing Veeam Software Appliance ISO files to enable fully automated, unattended installations. 
The script is designed to run in the same directory as the source ISO file and creates customized copies without complex path handling.

Enhanced Features:
- JSON CONFIGURATION SUPPORT: Load all parameters from JSON configuration files for easy deployment management
- OUT-OF-PLACE ISO MODIFICATION: Creates customized copies without modifying the original ISO
- PATH HANDLING: Works ONLY in the current directory to avoid WSL path issues
- Network Configuration: Supports both DHCP and static IP configurations with comprehensive validation
- Regional Settings: Configures keyboard layouts and timezone settings with proper validation
- Veeam Configuration Management: Implements Veeam auto deploy 
- Component Integration: Optional deployment of node_exporter monitoring and Veeam license automation
- Service Provider Integration: Automated VCSP connection and management agent installation - v13.0.1 required
- Enterprise Logging: Comprehensive logging system with timestamped Info/Warn/Error levels + output log file in current folder

The script utilizes WSL (Windows Subsystem for Linux) with xorriso for ISO manipulation.

.PARAMETER ConfigFile
Path to JSON configuration file containing all script parameters. When specified, parameters from JSON file take precedence over default values.
Command line parameters will override JSON values. Example: "production-config.json"

.PARAMETER SourceISO
Specifies the filename of the source Veeam Software Appliance ISO file in the current directory.
Default: "VeeamSoftwareAppliance_13.0.0.4967_20250822.iso"

.PARAMETER OutputISO
Specifies the filename for the customized ISO output in the current directory. 
If empty, creates a file with "_customized" suffix.
Example: "veeam-prod.iso"

.PARAMETER InPlace
Switch parameter to modify the original ISO file directly instead of creating a new one.
When $false (default), creates a new customized ISO preserving the original.
Default: $false

.PARAMETER CreateBackup
Switch parameter to create a timestamped backup when using InPlace modification.
Only effective when InPlace is $true. Default: $true

.PARAMETER CleanupCFGFiles
Switch parameter to keep grub.cfg and vbr-ks.cfg for debug
Default: $true

.PARAMETER CFGOnly
Switch parameter to only create grub.cfg and vbr-ks.cfg for debug
Default: $false

.PARAMETER GrubTimeout
Sets the GRUB bootloader timeout value in seconds. Default: 10

.PARAMETER KeyboardLayout
Keyboard layout code (e.g., 'us', 'fr', 'de', 'uk'). Default: "fr"

.PARAMETER Timezone
System timezone (e.g., 'Europe/Paris', 'America/New_York'). Default: "Europe/Paris"

.PARAMETER Hostname
Hostname for the deployed Veeam appliance. Default: "veeam-server"

.PARAMETER UseDHCP
Switch parameter to configure network interface for DHCP. When set, static IP parameters are ignored.
Default: $false

.PARAMETER StaticIP
IP address for static network configuration. Required when UseDHCP is $false.
Must be a valid IPv4 address format. Example: "192.168.1.100"

.PARAMETER Subnet
Subnet mask for static network configuration. Required when UseDHCP is $false.
Must be a valid IPv4 subnet mask format. Example: "255.255.255.0"

.PARAMETER Gateway
Gateway IP address for static network configuration. Required when UseDHCP is $false.
Must be a valid IPv4 address format. Example: "192.168.1.1"

.PARAMETER DNSServers
Array of DNS server IP addresses for static network configuration.
Default: @("192.168.1.64", "8.8.4.4")

##### Veeam Security Configuration #####

.PARAMETER VeeamAdminPassword
Password for the Veeam Backup & Replication administrator account.
Must meet enterprise security complexity requirements: minimum 15 characters with uppercase, lowercase, numbers, and special characters.
This account provides full administrative access to the Veeam console and all backup operations.
Default: "123q123Q123!123"

.PARAMETER VeeamAdminMfaSecretKey
Base32-encoded secret key for multi-factor authentication (MFA) for the admin account.
Used for TOTP (Time-based One-Time Password) authentication with apps like Google Authenticator or Microsoft Authenticator.
Must be a valid Base32 string (A-Z, 2-7, no padding) between 16-32 characters.
Default: "JBSWY3DPEHPK3PXP"

.PARAMETER VeeamAdminIsMfaEnabled
Enable or disable multi-factor authentication for the administrator account.
Recommended setting is "true" for enhanced security in production environments.
When enabled, users must provide both password and TOTP code for console access.
Default: "true"

.PARAMETER VeeamSoPassword
Password for the Veeam Security Officer (SO) account.
The SO account provides service-level access separate from administrative functions for improved security separation.
Must meet the same complexity requirements as the admin password.
Default: "123w123W123!123"

.PARAMETER VeeamSoMfaSecretKey
Base32-encoded MFA secret key for the Security Officer account.
Follows the same format requirements as the admin MFA key.
Should be different from the admin account's MFA key for security isolation.
Used for TOTP authentication when SO account access is required.
Default: "JBSWY3DPEHPK3PXP"

.PARAMETER VeeamSoIsMfaEnabled
Enable or disable multi-factor authentication for the Security Officer account.
Recommended setting is "true" for production environments to secure service-level access.
When enabled, automated systems must provide TOTP codes for SO account operations.
Default: "true"

.PARAMETER VeeamSoRecoveryToken
GUID-format recovery token for Security Officer account emergency access.
Used for account recovery scenarios when MFA devices are unavailable or lost.
Must follow standard GUID format: 8-4-4-4-12 hexadecimal digits (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx).
Store this token securely in your organization's password management system.
Default: "eb9fcbf4-2be6-e94d-4203-dded67c5a450"

.PARAMETER VeeamSoIsEnabled
Enable or disable the Security Officer account entirely.
When set to "true", creates and configures the SO account with specified security settings.
When set to "false", only the administrator account is configured.
Recommended setting is "true" for enterprise deployments requiring role separation.
Default: "true"

.PARAMETER NtpServer
Network Time Protocol (NTP) server for system time synchronization.
Accepts either fully qualified domain name (FQDN) or IP address.
Proper time synchronization is critical for Veeam operations, backup scheduling, and certificate validation.
Recommended to use your organization's internal NTP servers or reliable public pools.
Examples: "pool.ntp.org", "time.windows.com", "192.168.1.10"
Default: "time.nist.gov"

.PARAMETER NodeExporter
Boolean flag to enable node_exporter deployment. 
Default: $false

.PARAMETER NodeExporterDNF
Boolean flag to enable node_exporter deployment using DNF package manager.
Default: $false

.PARAMETER LicenseVBRTune
Boolean flag to enable automatic Veeam license installation. Default: $false

.PARAMETER VCSPConnection
Boolean flag to enable VCSP connection. 
Default: $false

.EXAMPLE
Using JSON configuration file (Recommended)
.\autodeployppxity.ps1 -ConfigFile "production-config.json"

.EXAMPLE
Traditional parameter usage (legacy)
.\autodeployppxity.ps1 -LocalISO "VeeamSoftwareAppliance_13.0.0.4967_20250822.iso"  -GrubTimeout 45  -KeyboardLayout "us"  -Timezone "America/New_York"  -Hostname "veeam-backup-prod01"  -UseDHCP:$false  -StaticIP "10.50.100.150"  -Subnet "255.255.255.0"  -Gateway "10.50.100.1"  -DNSServers @("10.50.1.10", "10.50.1.11", "8.8.8.8")  -VeeamAdminPassword "P@ssw0rd2024!123"  -VeeamAdminMfaSecretKey "ABCDEFGH12345678IJKLMNOP"  -VeeamAdminIsMfaEnabled "true"  -VeeamSoPassword "S3cur3P@ss!123"  -VeeamSoMfaSecretKey "ZYXWVUTS87654321QPONMLKJ"  -VeeamSoIsMfaEnabled "true"  -VeeamSoRecoveryToken "12345678-90ab-cdef-1234-567890abcdef"  -VeeamSoIsEnabled "true"  -NtpServer "pool.ntp.org"  -NtpRunSync "true"  -NodeExporter $true  -LicenseVBRTune $true  -LicenseFile "Enterprise-Plus-License.lic"  -SyslogServer "10.50.1.20"  -VCSPConnection $true  -VCSPUrl "https://vcsp.company.com"  -VCSPLogin "serviceaccount"  -VCSPPassword "VCSPServiceP@ss!"

.EXAMPLE
Simple DHCP configuration for lab environment with all optional features disable (legacy)
.\autodeployppxity.ps1 -LocalISO "VeeamAppliance-Lab.iso"  -GrubTimeout 10  -KeyboardLayout "fr"  -Timezone "Europe/Paris"  -Hostname "veeam-lab-test"  -UseDHCP:$true  -VeeamAdminPassword "LabP@ss123!123"  -VeeamAdminIsMfaEnabled "false"  -VeeamSoPassword "SOLabP@ss123!123"  -VeeamSoIsMfaEnabled "false"  -VeeamSoIsEnabled "false"  -NodeExporter $false  -LicenseVBRTune $false  -VCSPConnection $false

.NOTES
File Name      : autodeployppxity.ps1
Author         : Baptiste TELLIER (Enhanced by AI Assistant)
Prerequisite   : PowerShell 5.1+, WSL with xorriso installed
Version        : 2.1
Creation Date  : 24/09/2025

REQUIREMENTS:
- Windows Subsystem for Linux (WSL) with xorriso package installed
- Source ISO file must be in the same directory as this script
- Optional: JSON configuration file for simplified parameter management
- Optional: 'license' folder with .lic files for license automation
- Optional: 'node_exporter' folder with binaries for monitoring deployment

USAGE:
- Place this script in the same directory as your ISO file
- Create a JSON configuration file with your desired settings
- Run the script with -ConfigFile parameter
- All operations happen in the current directory

JSON CONFIGURATION:
The script supports loading all parameters from a JSON configuration file. Command line parameters will override JSON values.
See example JSON file for proper structure and supported parameters.

OUTPUT:
- Customized ISO
- grub.cfg (optional)
- vbr-ks.cfg (optional)
- ISO_Customization.log

#>

#region Parameters
param (
    # JSON Configuration File
    [string]$ConfigFile = "",

    # Core Parameters
    [string]$SourceISO = "VeeamSoftwareAppliance_13.0.0.4967_20250822.iso",
    [string]$OutputISO = "",  # If empty, uses SourceISO name with "_customized" suffix
    [switch]$InPlace = $false,  # Set to $true to modify original ISO
    [bool]$CreateBackup = $true,  # Create backup when using InPlace

    ##DEBUG### 
    [bool]$CleanupCFGFiles = $true, #$true to clean CFG file from folder
    [bool]$CFGOnly = $false, #no ISO creation - only CFG files in folder. Automatic set $CleanupCFGFiles=$false, $CreateBackup=$false and $InPlace=$true

    ##### GRUB Configuration #####
    [int]$GrubTimeout = 10,

    ##### OS configuration #####
    [string]$KeyboardLayout = "fr",
    [string]$Timezone = "Europe/Paris",

    ##### Network configuration #####
    [string]$Hostname = "veeam-server",
    [switch]$UseDHCP = $false,
    [string]$StaticIP = "192.168.1.166",
    [string]$Subnet = "255.255.255.0",
    [string]$Gateway = "192.168.1.1",
    [string[]]$DNSServers = @("192.168.1.64", "8.8.4.4"),

    ##### Veeam configuration #####
    [string]$VeeamAdminPassword = "123q123Q123!123",
    [string]$VeeamAdminMfaSecretKey = "JBSWY3DPEHPK3PXP",
    [string]$VeeamAdminIsMfaEnabled = "true",
    [string]$VeeamSoPassword = "123w123W123!123",
    [string]$VeeamSoMfaSecretKey = "JBSWY3DPEHPK3PXP",
    [string]$VeeamSoIsMfaEnabled = "true",
    [string]$VeeamSoRecoveryToken = "eb9fcbf4-2be6-e94d-4203-dded67c5a450",
    [string]$VeeamSoIsEnabled = "true",
    [string]$NtpServer = "time.nist.gov",
    [string]$NtpRunSync = "false",

    ##### optional features #####
    [bool]$NodeExporter = $false, #node exporter offline from folder
    [bool]$NodeExporterDNF = $false, #node exporter online with dnf
    [bool]$LicenseVBRTune = $false,
    [string]$LicenseFile = "Veeam-100instances-entplus-monitoring-nfr.lic",
    [string]$SyslogServer = "172.17.53.28",
    [bool]$VCSPConnection = $false,
    [string]$VCSPUrl = "192.168.1.202",
    [string]$VCSPLogin = "v13",
    [string]$VCSPPassword = "Azerty123!"
)
#endregion

#region Logging Functions

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('Info','Warn','Error')][string]$Level = 'Info'
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    switch ($Level) {
        'Info'  { Write-Host "[$timestamp][INFO] $Message" -ForegroundColor Cyan }
        'Warn'  { Write-Warning "[$timestamp][WARN] $Message" }
        'Error' { Write-Host "[$timestamp][ERROR] $Message" -ForegroundColor Red }
    }
}

#endregion

#region JSON Configuration Functions

function Import-JSONConfig {
    <#
    .SYNOPSIS
    Imports configuration from JSON file and updates script parameters
    #>
    
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigFilePath
    )
    
    try {
        if (-not (Test-Path $ConfigFilePath)) {
            throw "Configuration file not found: $ConfigFilePath"
        }
        
        Write-Log "Loading configuration from: $ConfigFilePath" 'Info'
        $jsonContent = Get-Content $ConfigFilePath -Raw -ErrorAction Stop
        $config = $jsonContent | ConvertFrom-Json -ErrorAction Stop
        
        Write-Log "JSON configuration loaded successfully" 'Info'
        return $config
    }
    catch {
        Write-Log "Failed to load JSON configuration: $($_.Exception.Message)" 'Error'
        throw "JSON configuration error: $($_.Exception.Message)"
    }
}

function Update-ParametersFromJSON {
    <#
    .SYNOPSIS
    Updates script parameters with values from JSON configuration
    #>
    
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Config
    )
    
    Write-Log "Applying JSON configuration..." 'Info'
    
    # Update parameters if they exist in JSON (only if not explicitly provided via command line)
    $parametersUpdated = 0
    
    if ($Config.PSObject.Properties['SourceISO'] -and -not $PSBoundParameters.ContainsKey('SourceISO')) {
        $script:SourceISO = $Config.SourceISO
        $parametersUpdated++
    }
    
    if ($Config.PSObject.Properties['OutputISO'] -and -not $PSBoundParameters.ContainsKey('OutputISO')) {
        $script:OutputISO = $Config.OutputISO
        $parametersUpdated++
    }
    
    if ($Config.PSObject.Properties['InPlace'] -and -not $PSBoundParameters.ContainsKey('InPlace')) {
        $script:InPlace = $Config.InPlace
        $parametersUpdated++
    }
    
    if ($Config.PSObject.Properties['CreateBackup'] -and -not $PSBoundParameters.ContainsKey('CreateBackup')) {
        $script:CreateBackup = $Config.CreateBackup
        $parametersUpdated++
    }
    
    if ($Config.PSObject.Properties['CleanupCFGFiles'] -and -not $PSBoundParameters.ContainsKey('CleanupCFGFiles')) {
        $script:CleanupCFGFiles = $Config.CleanupCFGFiles
        $parametersUpdated++
    }

    if ($Config.PSObject.Properties['CFGOnly'] -and -not $PSBoundParameters.ContainsKey('CFGOnly')) {
        $script:CFGOnly = $Config.CFGOnly
        $parametersUpdated++
    }
    
    if ($Config.PSObject.Properties['GrubTimeout'] -and -not $PSBoundParameters.ContainsKey('GrubTimeout')) {
        $script:GrubTimeout = $Config.GrubTimeout
        $parametersUpdated++
    }
    
    if ($Config.PSObject.Properties['KeyboardLayout'] -and -not $PSBoundParameters.ContainsKey('KeyboardLayout')) {
        $script:KeyboardLayout = $Config.KeyboardLayout
        $parametersUpdated++
    }
    
    if ($Config.PSObject.Properties['Timezone'] -and -not $PSBoundParameters.ContainsKey('Timezone')) {
        $script:Timezone = $Config.Timezone
        $parametersUpdated++
    }
    
    if ($Config.PSObject.Properties['Hostname'] -and -not $PSBoundParameters.ContainsKey('Hostname')) {
        $script:Hostname = $Config.Hostname
        $parametersUpdated++
    }
    
    if ($Config.PSObject.Properties['UseDHCP'] -and -not $PSBoundParameters.ContainsKey('UseDHCP')) {
        $script:UseDHCP = $Config.UseDHCP
        $parametersUpdated++
    }
    
    if ($Config.PSObject.Properties['StaticIP'] -and -not $PSBoundParameters.ContainsKey('StaticIP')) {
        $script:StaticIP = $Config.StaticIP
        $parametersUpdated++
    }
    
    if ($Config.PSObject.Properties['Subnet'] -and -not $PSBoundParameters.ContainsKey('Subnet')) {
        $script:Subnet = $Config.Subnet
        $parametersUpdated++
    }
    
    if ($Config.PSObject.Properties['Gateway'] -and -not $PSBoundParameters.ContainsKey('Gateway')) {
        $script:Gateway = $Config.Gateway
        $parametersUpdated++
    }
    
    if ($Config.PSObject.Properties['DNSServers'] -and -not $PSBoundParameters.ContainsKey('DNSServers')) {
        $script:DNSServers = $Config.DNSServers
        $parametersUpdated++
    }
    
    if ($Config.PSObject.Properties['VeeamAdminPassword'] -and -not $PSBoundParameters.ContainsKey('VeeamAdminPassword')) {
        $script:VeeamAdminPassword = $Config.VeeamAdminPassword
        $parametersUpdated++
    }
    
    if ($Config.PSObject.Properties['VeeamAdminMfaSecretKey'] -and -not $PSBoundParameters.ContainsKey('VeeamAdminMfaSecretKey')) {
        $script:VeeamAdminMfaSecretKey = $Config.VeeamAdminMfaSecretKey
        $parametersUpdated++
    }
    
    if ($Config.PSObject.Properties['VeeamAdminIsMfaEnabled'] -and -not $PSBoundParameters.ContainsKey('VeeamAdminIsMfaEnabled')) {
        $script:VeeamAdminIsMfaEnabled = $Config.VeeamAdminIsMfaEnabled
        $parametersUpdated++
    }
    
    if ($Config.PSObject.Properties['VeeamSoPassword'] -and -not $PSBoundParameters.ContainsKey('VeeamSoPassword')) {
        $script:VeeamSoPassword = $Config.VeeamSoPassword
        $parametersUpdated++
    }
    
    if ($Config.PSObject.Properties['VeeamSoMfaSecretKey'] -and -not $PSBoundParameters.ContainsKey('VeeamSoMfaSecretKey')) {
        $script:VeeamSoMfaSecretKey = $Config.VeeamSoMfaSecretKey
        $parametersUpdated++
    }
    
    if ($Config.PSObject.Properties['VeeamSoIsMfaEnabled'] -and -not $PSBoundParameters.ContainsKey('VeeamSoIsMfaEnabled')) {
        $script:VeeamSoIsMfaEnabled = $Config.VeeamSoIsMfaEnabled
        $parametersUpdated++
    }
    
    if ($Config.PSObject.Properties['VeeamSoRecoveryToken'] -and -not $PSBoundParameters.ContainsKey('VeeamSoRecoveryToken')) {
        $script:VeeamSoRecoveryToken = $Config.VeeamSoRecoveryToken
        $parametersUpdated++
    }
    
    if ($Config.PSObject.Properties['VeeamSoIsEnabled'] -and -not $PSBoundParameters.ContainsKey('VeeamSoIsEnabled')) {
        $script:VeeamSoIsEnabled = $Config.VeeamSoIsEnabled
        $parametersUpdated++
    }
    
    if ($Config.PSObject.Properties['NtpServer'] -and -not $PSBoundParameters.ContainsKey('NtpServer')) {
        $script:NtpServer = $Config.NtpServer
        $parametersUpdated++
    }
    
    if ($Config.PSObject.Properties['NtpRunSync'] -and -not $PSBoundParameters.ContainsKey('NtpRunSync')) {
        $script:NtpRunSync = $Config.NtpRunSync
        $parametersUpdated++
    }
    
    if ($Config.PSObject.Properties['NodeExporter'] -and -not $PSBoundParameters.ContainsKey('NodeExporter')) {
        $script:NodeExporter = $Config.NodeExporter
        $parametersUpdated++
    }

    if ($Config.PSObject.Properties['NodeExporterDNF'] -and -not $PSBoundParameters.ContainsKey('NodeExporterDNF')) {
        $script:NodeExporterDNF = $Config.NodeExporterDNF
        $parametersUpdated++
    }
    
    if ($Config.PSObject.Properties['LicenseVBRTune'] -and -not $PSBoundParameters.ContainsKey('LicenseVBRTune')) {
        $script:LicenseVBRTune = $Config.LicenseVBRTune
        $parametersUpdated++
    }
    
    if ($Config.PSObject.Properties['LicenseFile'] -and -not $PSBoundParameters.ContainsKey('LicenseFile')) {
        $script:LicenseFile = $Config.LicenseFile
        $parametersUpdated++
    }
    
    if ($Config.PSObject.Properties['SyslogServer'] -and -not $PSBoundParameters.ContainsKey('SyslogServer')) {
        $script:SyslogServer = $Config.SyslogServer
        $parametersUpdated++
    }
    
    if ($Config.PSObject.Properties['VCSPConnection'] -and -not $PSBoundParameters.ContainsKey('VCSPConnection')) {
        $script:VCSPConnection = $Config.VCSPConnection
        $parametersUpdated++
    }
    
    if ($Config.PSObject.Properties['VCSPUrl'] -and -not $PSBoundParameters.ContainsKey('VCSPUrl')) {
        $script:VCSPUrl = $Config.VCSPUrl
        $parametersUpdated++
    }
    
    if ($Config.PSObject.Properties['VCSPLogin'] -and -not $PSBoundParameters.ContainsKey('VCSPLogin')) {
        $script:VCSPLogin = $Config.VCSPLogin
        $parametersUpdated++
    }
    
    if ($Config.PSObject.Properties['VCSPPassword'] -and -not $PSBoundParameters.ContainsKey('VCSPPassword')) {
        $script:VCSPPassword = $Config.VCSPPassword
        $parametersUpdated++
    }
    
    Write-Log "Applied $parametersUpdated parameters from JSON configuration" 'Info'
}

#endregion

#region Helper Functions

function Test-Prerequisites {
    <#
    .SYNOPSIS
    Tests all prerequisites for the script
    #>

    Write-Log "Testing prerequisites..." 'Info'

    # Test WSL availability
    try {
        $wslTest = & wsl echo "test" 2>$null
        if ($wslTest -ne "test") {
            throw "WSL is not available or not responding correctly"
        }
        Write-Log "WSL is available" 'Info'
    }
    catch {
        Write-Log "WSL test failed: $($_.Exception.Message)" 'Error'
        return $false
    }

    # Test xorriso availability
    try {
        $xorrisoTest = & wsl which xorriso 2>$null
        if ([string]::IsNullOrWhiteSpace($xorrisoTest)) {
            throw "xorriso not found. Install with: wsl sudo apt-get install xorriso"
        }
        Write-Log "xorriso is available at: $xorrisoTest" 'Info'
    }
    catch {
        Write-Log "xorriso test failed: $($_.Exception.Message)" 'Error'
        Write-Log "Please install xorriso: wsl sudo apt-get update && wsl sudo apt-get install xorriso" 'Error'
        return $false
    }

    # Test source ISO exists in current directory
    if (-not (Test-Path $SourceISO)) {
        Write-Log "Source ISO not found in current directory: $SourceISO" 'Error'
        Write-Log "Please ensure the ISO file is in the same directory as this script" 'Error'
        return $false
    }

    Write-Log "All prerequisites validated successfully" 'Info'
    return $true
}

function Initialize-ISOOperation {
    <#
    .SYNOPSIS
    Initializes the ISO operation by determining target file and creating backups if needed
    #>

    # Get current directory
    $currentDir = Get-Location
    Write-Log "Working in directory: $currentDir" 'Info'

    # Determine target ISO filename
    if ($InPlace) {
        $targetISO = $SourceISO
        Write-Log "In-place modification mode: will modify $SourceISO directly" 'Info'

        # Create backup if requested
        if ($CreateBackup) {
            $sourceBaseName = [System.IO.Path]::GetFileNameWithoutExtension($SourceISO)
            $sourceExtension = [System.IO.Path]::GetExtension($SourceISO)
            $backupName = "$sourceBaseName`_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')$sourceExtension"

            Write-Log "Creating backup: $backupName" 'Info'
            Copy-Item $SourceISO $backupName -Force
            Write-Log "Backup created successfully" 'Info'
            $backupPath = $backupName
        } else {
            $backupPath = $null
        }
    }
    else {
        # Out-of-place modification
        if ([string]::IsNullOrWhiteSpace($OutputISO)) {
            $sourceBaseName = [System.IO.Path]::GetFileNameWithoutExtension($SourceISO)
            $sourceExtension = [System.IO.Path]::GetExtension($SourceISO)
            $targetISO = "$sourceBaseName`_customized$sourceExtension"
        } else {
            $targetISO = $OutputISO
        }

        Write-Log "Out-of-place modification mode: creating $targetISO" 'Info'
        Copy-Item $SourceISO $targetISO -Force
        Write-Log "Working copy created: $targetISO" 'Info'
        $backupPath = $null
    }

    return @{
        SourceISO = $SourceISO
        TargetISO = $targetISO
        BackupPath = $backupPath
        IsInPlace = $InPlace.IsPresent
        Mode = if ($CFGOnly) {"CFG ONLY"} elseif ($InPlace) { "In-Place" } else { "Out-of-Place" }
    }
}

function Invoke-WSLCommand {
    <#
    .SYNOPSIS
    Executes WSL commands with proper error handling
    #>

    param(
        [Parameter(Mandatory = $true)]
        [string]$Command,
        [Parameter(Mandatory = $false)]
        [string]$Description = "WSL Command"
    )

    try {
        Write-Log "Executing: $Description" 'Info'
        Write-Log "Command: $Command" 'Info'

        $output = & cmd /c $Command 2>&1
        $exitCode = $LASTEXITCODE

        if ($exitCode -ne 0) {
            Write-Log "Command failed with exit code $exitCode" 'Warn'
            if ($output) {
                Write-Log "Output: $output" 'Warn'
            }
        } else {
            Write-Log "$Description completed successfully" 'Info'
        }

        return ($exitCode -eq 0)
    }
    catch {
        Write-Log "$Description failed: $($_.Exception.Message)" 'Error'
        return $false
    }
}

function Get-ModificationSummary {
    <#
    .SYNOPSIS
    Generates a summary of planned modifications
    #>

    param([hashtable]$ISOInfo)

    $summary = @()
    $summary += "=================================================================================================="
    $summary += "                                    ISO MODIFICATION SUMMARY"
    $summary += "=================================================================================================="
    $summary += "Source ISO: $($ISOInfo.SourceISO)"
    $summary += "Target ISO: $($ISOInfo.TargetISO)"
    $summary += "Mode: $($ISOInfo.Mode)"

    if ($ISOInfo.BackupPath) {
        $summary += "Backup: $($ISOInfo.BackupPath)"
    }

    $summary += ""
    $summary += "CONFIGURATION:"
    $summary += "  GRUB Timeout: $GrubTimeout seconds"
    $summary += "  Keyboard: $KeyboardLayout"
    $summary += "  Timezone: $Timezone"
    $summary += "  Hostname: $Hostname"

    if ($UseDHCP) {
        $summary += "  Network: DHCP"
    } else {
        $summary += "  Network: Static IP ($StaticIP/$Subnet via $Gateway)"
        $summary += "  DNS: $($DNSServers -join ', ')"
    }

    $summary += ""
    $summary += "OPTIONAL FEATURES:"
    $summary += "  Node Exporter Local: $(if ($NodeExporter) { 'Enabled' } else { 'Disabled' })"
    $summary += "  Node Exporter Online: $(if ($NodeExporterDNF) { 'Enabled' } else { 'Disabled' })"
    $summary += "  License Auto-Install: $(if ($LicenseVBRTune) { 'Enabled' } else { 'Disabled' })"
    $summary += "  VCSP Connection: $(if ($VCSPConnection) { 'Enabled' } else { 'Disabled' })"
    $summary += "=================================================================================================="

    return $summary -join "`n"
}

function Update-FileContent {
    <#
    .SYNOPSIS
    Updates file content with search and replace
    #>

    param(
        [string]$FilePath,
        [string]$Pattern,
        [string]$Replacement
    )

    try {
        $content = Get-Content $FilePath 
        $content = $content -replace $Pattern, $Replacement
        Set-Content $FilePath $content 
        Write-Log "Updated with $Replacement in $FilePath" 'Info'
    }
    catch {
        Write-Log "Failed to update $FilePath`: $($_.Exception.Message)" 'Error'
        throw
    }
}

function Add-ContentAfterLine {
    <#
    .SYNOPSIS
    Adds content after a specific line in a file
    #>

    param(
        [string]$FilePath,
        [string]$TargetLine,
        [string[]]$NewLines
    )

    try {
        $content = Get-Content $FilePath
        $newContent = @()

        foreach ($line in $content) {
            $newContent += $line
            if ($line -like "*$TargetLine*") {
                $newContent += $NewLines
                Write-Log "Added content after line: $TargetLine" 'Info'
            }
        }

        Set-Content $FilePath $newContent
    }
    catch {
        Write-Log "Failed to add content to $FilePath`: $($_.Exception.Message)" 'Error'
        throw
    }
}

#endregion

#region Configuration Functions

function Set-KeyboardLayout {
    param([string]$FilePath, [string]$Layout)

    Write-Log "Setting keyboard layout to $Layout" 'Info'
    Update-FileContent -FilePath $FilePath -Pattern "keyboard --xlayouts='[^']*'" -Replacement "keyboard --xlayouts='$Layout'"
}

function Set-Timezone {
    param([string]$FilePath, [string]$TimezoneValue)

    Write-Log "Setting timezone to $TimezoneValue" 'Info'
    Update-FileContent -FilePath $FilePath -Pattern "timezone [^\\s]+ --utc" -Replacement "timezone $TimezoneValue --utc"
}

function Set-NetworkConfiguration {
    param(
        [string]$FilePath,
        [string]$Hostname,
        [switch]$UseDHCP,
        [string]$StaticIP,
        [string]$Subnet,
        [string]$Gateway,
        [string[]]$DNSServers
    )

    Write-Log "Configuring network settings" 'Info'

    if ($UseDHCP) {
        $networkLine = "network --bootproto=dhcp --nodns --hostname=$Hostname"
        Write-Log "Using DHCP configuration" 'Info'
    } else {
        $DNSList = $DNSServers -join ","
        $networkLine = "network --bootproto=static --ip=$StaticIP --netmask=$Subnet --gateway=$Gateway --nameserver=$DNSList --hostname=$Hostname"
        Write-Log "Using static IP configuration: $StaticIP" 'Info'
    }

    # Replace existing network line or add new one
    
    $content = Get-Content $FilePath
    $found = $false

    for ($i = 0; $i -lt $content.Count; $i++) {
        if ($content[$i] -match '^network\s') {
            $content[$i] = $networkLine
            $found = $true
            $found
            break
        }
    }

    if (-not $found) {
        # Add after timezone line
        for ($i = 0; $i -lt $content.Count; $i++) {
            if ($content[$i] -match '^timezone\\s+') {
                $newContent = $content[0..$i] + $networkLine + $content[($i+1)..($content.Count-1)]
                $content = $newContent
                break
            }
        }
    }
    
    Set-Content $FilePath $content 
    Write-Log "Network configuration applied" 'Info'
}

#endregion

#region Configuration Blocks

$CustomVBRBlock = @(
    "# Custom VBR config",
    "pwsh -Command '",
    "Import-Module /opt/veeam/powershell/Veeam.Backup.PowerShell/Veeam.Backup.PowerShell.psd1",
    "Install-VBRLicense -Path /etc/veeam/license/$LicenseFile",
    "Add-VBRSyslogServer -ServerHost '$SyslogServer' -Port 514 -Protocol Udp",
    "'"
)

$CustomVCSPBlock = @(
    "# Connect to Service Provider with Mgmt Agent",
    "pwsh -Command '",
    "Import-Module /opt/veeam/powershell/Veeam.Backup.PowerShell/Veeam.Backup.PowerShell.psd1",
    "Add-VBRCloudProviderCredentials -Name '$VCSPLogin' -Password '$VCSPPassword'",
    "`$credentials = Get-VBRCloudProviderCredentials -Name '$VCSPLogin'",
    "Add-VBRCloudProvider -Address '$VCSPConnection' -Credentials `$credentials -InstallManagementAgent",
    "'"
)

$CopyLicenseBlock = @(
    "# Copy Veeam license file from ISO to OS",
    "log 'starting license file copy'",
    "mkdir -p /mnt/sysimage/etc/veeam/license/",
    "if [ -f /mnt/install/repo/license/$LicenseFile ]; then",
    "  cp -f /mnt/install/repo/license/$LicenseFile /mnt/sysimage/etc/veeam/license/$LicenseFile",
    "  chmod 600 /mnt/sysimage/etc/veeam/license/$LicenseFile",
    "  chown root:root /mnt/sysimage/etc/veeam/license/$LicenseFile",
    "fi",
    "log 'license file copy completed'"
)

$CopyNodeExporterBlock = @(
    "# Copy node_exporter files to OS",
    "log 'starting node_exporter files copy'",
    "mkdir -p /mnt/sysimage/etc/node_exporter",
    "if [ -d /mnt/install/repo/node_exporter ]; then",
    "    cp -r /mnt/install/repo/node_exporter /mnt/sysimage/etc/",
    "fi",
    "log 'node_exporter files copy completed'"
)

$NodeExporterSetupBlock = @(
    "# Setup node_exporter service",
    "log 'starting node_exporter installation'",
    "groupadd -f node_exporter",
    "useradd -g node_exporter --no-create-home --shell /bin/false node_exporter",
    "chown node_exporter:node_exporter /etc/node_exporter",
    "cat << EOF >> /etc/systemd/system/node_exporter.service",
    "[Unit]",
    "Description=Node Exporter",
    "Documentation=https://prometheus.io/docs/guides/node-exporter/",
    "Wants=network-online.target",
    "After=network-online.target",
    "",
    "[Service]",
    "User=node_exporter",
    "Group=node_exporter",
    "Type=simple",
    "Restart=on-failure",
    "ExecStart=/etc/node_exporter/node_exporter --web.listen-address=:9100",
    "",
    "[Install]",
    "WantedBy=multi-user.target",
    "EOF",
    "chmod 664 /etc/systemd/system/node_exporter.service",
    "systemctl daemon-reload",
    "systemctl enable node_exporter.service",
    "log 'node_exporter installation completed'"
)

$NodeExporterFirewallBlock = @(
    "# Configure firewall for node_exporter",
    "firewall-cmd --permanent --zone=drop --add-port=9100/tcp",
    "firewall-cmd --reload"
)

$VeeamHostConfigBlock = @(
    "log 'starting Veeam Host Manager configuration'",
    "###############################################################################",
    "# Automatic Host Manager configuration file",
    "###############################################################################",
    "cat << EOF >> /etc/veeam/vbr_init.cfg",
    "veeamadmin.password=$VeeamAdminPassword",
    "veeamadmin.mfaSecretKey=$VeeamAdminMfaSecretKey",
    "veeamadmin.isMfaEnabled=$VeeamAdminIsMfaEnabled",
    "veeamso.password=$VeeamSoPassword",
    "veeamso.mfaSecretKey=$VeeamSoMfaSecretKey",
    "veeamso.isMfaEnabled=$VeeamSoIsMfaEnabled",
    "veeamso.recoveryToken=$VeeamSoRecoveryToken",
    "veeamso.isEnabled=$VeeamSoIsEnabled",
    "ntp.servers=$NtpServer",
    "ntp.runSync=$NtpRunSync",
    "vbr_control.runInitIso=true",
    "vbr_control.runStart=true",
    "EOF",
    "###############################################################################",
    "#  Automatic Host Manager configuration TRIGGER AFTER REBOOT",
    "###############################################################################",
    "cat << EOF >> /etc/veeam/veeam-init.sh",
    "#!/bin/bash",
    "set -eE -u -o pipefail",
    "/opt/veeam/hostmanager/veeamhostmanager --apply_init_config /etc/veeam/vbr_init.cfg",
    "systemctl disable veeam-init",
    "EOF",
    "chmod +x /etc/veeam/veeam-init.sh",
    "# Create systemd service",
    "cat << EOF >> /etc/systemd/system/veeam-init.service",
    "[Unit]",
    "Description=One-shot daemon to run /opt/veeam/hostmanager/veeamhostmanager at next boot",
    "[Service]",
    "Type=oneshot",
    "ExecStart=/etc/veeam/veeam-init.sh",
    "RemainAfterExit=no",
    "[Install]",
    "WantedBy=multi-user.target",
    "EOF",
    "systemctl enable veeam-init.service",
    "log 'Veeam Host Manager configuration completed'"
)

$NodeExporterDNFBlock = @(
    "log '[1/4] Enabling Rocky Linux repos and EPEL...'",
    "rpm -Uvh https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm",
    "dnf clean all && dnf -y makecache",
    "dnf -y install dnf-plugins-core || true",
    "dnf -y config-manager --set-enabled crb || true",
    "dnf -y install epel-release",
    "dnf -y makecache",

    "log '[2/4] Installing node_exporter...'",
    "dnf -y install node_exporter",

    "log '[3/4] Configuring /etc/sysconfig/node_exporter ...'",
    'bash -c ''echo OPTIONS="--web.listen-address=0.0.0.0:9100" > /etc/sysconfig/node_exporter''',

    "log '[4/4] Enabling and starting node_exporter...'",
    "systemctl daemon-reload",
    "systemctl enable node_exporter.service",
    "log 'node_exporter installation completed'"
)

#endregion

#region Main Script

try {
    # Initialize logging
    $logFile = "ISO_Customization_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
    Start-Transcript -Path $logFile -Append

    Write-Log "=================================================================================================="
    Write-Log "Veeam ISO Customization Script - Version 2.1"
    Write-Log "=================================================================================================="

    # Load JSON configuration if provided
    if (-not [string]::IsNullOrWhiteSpace($ConfigFile)) {
        $jsonConfig = Import-JSONConfig -ConfigFilePath $ConfigFile
        Update-ParametersFromJSON -Config $jsonConfig
        Write-Log "Configuration loaded from JSON file: $ConfigFile" 'Info'
    } else {
        Write-Log "Using default parameters (no JSON configuration file specified)" 'Info'
    }
    #if CFG only keep file and don't do iso backup because it won't be edit
    Write-Log "Config only set to $CFGOnly"
    if($CFGOnly){
        $CleanupCFGFiles=$false
        $InPlace=$true
        $CreateBackup=$false
    }
    # Test prerequisites
    if (-not (Test-Prerequisites)) {
        throw "Prerequisites check failed. Please resolve the issues above."
    }

    # Validate network parameters
    if (-not $UseDHCP) {
        if ([string]::IsNullOrWhiteSpace($StaticIP) -or 
            [string]::IsNullOrWhiteSpace($Subnet) -or 
            [string]::IsNullOrWhiteSpace($Gateway)) {
            throw "Static IP configuration requires StaticIP, Subnet, and Gateway parameters"
        }
    }

    # Initialize ISO operation
    $isoInfo = Initialize-ISOOperation
    
    # Show summary and get confirmation
    Write-Host "`n$(Get-ModificationSummary -ISOInfo $isoInfo)" -ForegroundColor Yellow
    Write-Host "`nPress Enter to continue or Ctrl+C to abort..." -ForegroundColor Cyan
    Read-Host

    # Extract files from target ISO
    Write-Log "Extracting configuration files from ISO..." 'Info'

    $extractCommands = @(
        "wsl xorriso -boot_image any keep -dev `"$($isoInfo.TargetISO)`" -osirrox on -extract vbr-ks.cfg vbr-ks.cfg",
        "wsl xorriso -boot_image any keep -dev `"$($isoInfo.TargetISO)`" -osirrox on -extract /EFI/BOOT/grub.cfg grub.cfg"
    )

    foreach ($cmd in $extractCommands) {
        if (-not (Invoke-WSLCommand -Command $cmd -Description "Extract configuration files")) {
            throw "Failed to extract files from ISO"
        }
    }

    # Verify extracted files exist
    @("vbr-ks.cfg", "grub.cfg") | ForEach-Object {
        if (-not (Test-Path $_)) {
            throw "Required file not extracted: $_"
        }
        Write-Log "File extracted: $_" 'Info'
    }

    # Configure GRUB
    Write-Log "Configuring GRUB bootloader..." 'Info'
    Update-FileContent -FilePath "grub.cfg" -Pattern '^(.*LABEL=Rocky-9-2-x86_64:/vbr-ks.cfg quiet.*)$' -Replacement '${1} inst.assumeyes'
    $newDefault = '"Veeam Backup & Replication v13.0>Install - fresh install, wipes everything (including local backups)"'
    Update-FileContent -FilePath "grub.cfg" -Pattern 'set default=.*' -Replacement "set default=$newDefault"
    Update-FileContent -FilePath "grub.cfg" -Pattern 'set timeout=.*' -Replacement "set timeout=$GrubTimeout"

    # Configure Kickstart
    Write-Log "Configuring Kickstart file..." 'Info'
    Set-KeyboardLayout -FilePath "vbr-ks.cfg" -Layout $KeyboardLayout
    Set-Timezone -FilePath "vbr-ks.cfg" -TimezoneValue $Timezone

    if ($UseDHCP) {
        Set-NetworkConfiguration -FilePath "vbr-ks.cfg" -Hostname $Hostname -UseDHCP:$true
    } else {
        Set-NetworkConfiguration -FilePath "vbr-ks.cfg" -Hostname $Hostname -StaticIP $StaticIP -Subnet $Subnet -Gateway $Gateway -DNSServers $DNSServers
    }

    # Disable init wizard
    Add-ContentAfterLine -FilePath "vbr-ks.cfg" -TargetLine "mkdir -p /var/log/veeam/" -NewLines @("touch /etc/veeam/cockpit_auto_test_disable_init")

    # Add Veeam host configuration
    Add-ContentAfterLine -FilePath "vbr-ks.cfg" -TargetLine 'find /etc/yum.repos.d/ -type f -not -name "*veeam*" -delete' -NewLines $VeeamHostConfigBlock

    # Add optional features
    if ($LicenseVBRTune) {
        Write-Log "Adding license configuration..." 'Info'
        Add-ContentAfterLine -FilePath "vbr-ks.cfg" -TargetLine "/opt/veeam/hostmanager/veeamhostmanager --apply_init_config /etc/veeam/vbr_init.cfg" -NewLines $CustomVBRBlock
        Add-ContentAfterLine -FilePath "vbr-ks.cfg" -TargetLine "/usr/bin/cp -rv /tmp/*.* /mnt/sysimage/var/log/appliance-installation-logs/" -NewLines $CopyLicenseBlock

        # Add license folder to ISO
        if (Test-Path "license") {
            $licenseCmd = "wsl xorriso -boot_image any keep -dev `"$($isoInfo.TargetISO)`" -map license /license"
            Invoke-WSLCommand -Command $licenseCmd -Description "Add license folder to ISO" | Out-Null
        }
    }

    if ($VCSPConnection) {
        Write-Log "Adding VCSP configuration..." 'Info'
        Add-ContentAfterLine -FilePath "vbr-ks.cfg" -TargetLine "/opt/veeam/hostmanager/veeamhostmanager --apply_init_config /etc/veeam/vbr_init.cfg" -NewLines $CustomVCSPBlock
    }

    if ($NodeExporter) {
        Write-Log "Adding node_exporter configuration..." 'Info'
        Add-ContentAfterLine -FilePath "vbr-ks.cfg" -TargetLine 'dnf install -y --nogpgcheck --disablerepo="*" /tmp/static-packages/*.rpm' -NewLines $NodeExporterSetupBlock
        Add-ContentAfterLine -FilePath "vbr-ks.cfg" -TargetLine "/usr/bin/cp -rv /tmp/*.* /mnt/sysimage/var/log/appliance-installation-logs/" -NewLines $CopyNodeExporterBlock
        Add-ContentAfterLine -FilePath "vbr-ks.cfg" -TargetLine "/opt/veeam/hostmanager/veeamhostmanager --apply_init_config /etc/veeam/vbr_init.cfg" -NewLines $NodeExporterFirewallBlock

        # Add node_exporter folder to ISO
        if (Test-Path "node_exporter") {
            $nodeCmd = "wsl xorriso -boot_image any keep -dev `"$($isoInfo.TargetISO)`" -map node_exporter /node_exporter"
            Invoke-WSLCommand -Command $nodeCmd -Description "Add node_exporter folder to ISO" | Out-Null
        }
    }

    if ($NodeExporterDNF){
        Write-Log "Adding node_exporter with DNF configuration..." 'Info'
        Add-ContentAfterLine -FilePath "vbr-ks.cfg" -TargetLine 'dnf install -y --nogpgcheck --disablerepo="*" /tmp/static-packages/*.rpm' -NewLines $NodeExporterDNFBlock
        Add-ContentAfterLine -FilePath "vbr-ks.cfg" -TargetLine "/opt/veeam/hostmanager/veeamhostmanager --apply_init_config /etc/veeam/vbr_init.cfg" -NewLines $NodeExporterFirewallBlock
    }


    # Normalize line endings
    Write-Log "Normalizing line endings..." 'Info'
    @("vbr-ks.cfg", "grub.cfg") | ForEach-Object {
        $content = Get-Content $_ -Raw
        $content = $content.Replace("`r`n", "`n")
        Set-Content $_ $content -NoNewline
    }
    
    if(-not $CFGOnly){
    # Commit changes to ISO
    Write-Log "Committing changes to ISO..." 'Info'

    $commitCommands = @(
        "wsl xorriso -boot_image any keep -dev `"$($isoInfo.TargetISO)`" -rm vbr-ks.cfg",
        "wsl xorriso -boot_image any keep -dev `"$($isoInfo.TargetISO)`" -map vbr-ks.cfg vbr-ks.cfg",
        "wsl xorriso -boot_image any keep -dev `"$($isoInfo.TargetISO)`" -rm /EFI/BOOT/grub.cfg",
        "wsl xorriso -boot_image any keep -dev `"$($isoInfo.TargetISO)`" -map grub.cfg /EFI/BOOT/grub.cfg"
    )

    foreach ($cmd in $commitCommands) {
        if (-not (Invoke-WSLCommand -Command $cmd -Description "Commit changes to ISO")) {
            throw "Failed to commit changes to ISO"
        }
    }

    # Success
    Write-Log "ISO customization completed successfully!" 'Info'
    }
    Write-Host "`n=================================================================================================="  -ForegroundColor Green
    Write-Host "                                        SUCCESS!"  -ForegroundColor Green
    Write-Host "=================================================================================================="  -ForegroundColor Green
    Write-Host "Customized ISO: $($isoInfo.TargetISO)"  -ForegroundColor Green
    if ($isoInfo.BackupPath) {
        Write-Host "Backup created: $($isoInfo.BackupPath)"  -ForegroundColor Green
    }
    Write-Host "Mode: $($isoInfo.Mode)"  -ForegroundColor Green
    Write-Host "Log file: $logFile"  -ForegroundColor Green
    Write-Host "=================================================================================================="  -ForegroundColor Green

    # Cleanup temporary files
    if($CleanupCFGFiles){
        @("vbr-ks.cfg", "grub.cfg") | ForEach-Object {
            if (Test-Path $_) {
                Remove-Item $_ -Force
            }
        }
    }

} catch {
    Write-Log "Script failed: $($_.Exception.Message)" 'Error'

    Write-Host "`n=================================================================================================="  -ForegroundColor Red
    Write-Host "                                        FAILURE!"  -ForegroundColor Red
    Write-Host "=================================================================================================="  -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)"  -ForegroundColor Red
    Write-Host "Check log file: $logFile"  -ForegroundColor Red
    Write-Host "=================================================================================================="  -ForegroundColor Red

    # Cleanup temporary files
    if($CleanupCFGFiles){
        @("vbr-ks.cfg", "grub.cfg") | ForEach-Object {
            if (Test-Path $_ -ErrorAction SilentlyContinue) {
                Remove-Item $_ -Force -ErrorAction SilentlyContinue
            }
        }
    }

    # Cleanup failed working copy (but not if in-place)
    if ($isoInfo -and -not $isoInfo.IsInPlace -and (Test-Path $isoInfo.TargetISO -ErrorAction SilentlyContinue)) {
        Write-Log "Cleaning up failed working copy" 'Info'
        Remove-Item $isoInfo.TargetISO -Force -ErrorAction SilentlyContinue
    }

    exit 1
} finally {
    Stop-Transcript -ErrorAction SilentlyContinue
}

#endregion
# End of script