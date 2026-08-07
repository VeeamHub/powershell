<#
.SYNOPSIS
    Veeam Backup & Replication Pre-Upgrade Readiness Check (VBR 13.0 / 13.1)

.DESCRIPTION
    Connects to a VBR server via the REST API and validates all pre-upgrade
    requirements documented at:
    https://helpcenter.veeam.com/docs/vbr/userguide/upgrade_vbr_byb.html?ver=13

    Use -TargetVersion to select the upgrade target:
      13.0  (default)  Upgrading from VBR 12.x  -  requires 12.3.1.1139+ or 12.3.2+
      13.1             Upgrading from VBR 13.0.x -  requires 13.0.1 or later

    The API version (-ApiVersion) is auto-selected based on the target if not specified:
      Target 13.0 -> 1.2-rev0   Target 13.1 -> 1.3-rev1

    Checks performed:
      1.  Server connectivity and API availability
      2.  Current VBR version eligibility for the selected target
      3.  License status and expiry
      4.  Configuration backup  -  enabled and recent (within 7 days)
      5.  Running backup/replication/copy jobs (must be zero)
      6.  Running restore sessions (must be zero)
      7.  Running SureBackup / SureLive sessions (must be zero)
      8.  Repository free space (warns below 10 GB, fails below 2 GB)
      9.  Backup proxy availability
     10.  Managed server component versions
     11.  Deprecated features in use (reversed incremental, restore-point retention,
           single-storage format, Cloud Connect AD auth)
     12.  VBR server OS version via WMI (Windows Server 2019 or 2022 required)
     13.  Pending Windows reboot on VBR server (via WMI)
     14.  Veeam Windows services status (via WMI)
     15.  System drive free disk space on VBR server (>= 10 GB required)
     16.  Port 443 availability on VBR server (VBR 13 REST service requires port 443)
     17.  SQL Server version on VBR server (2016 or later required; PostgreSQL is fine)
     18.  PowerShell 7 installed on VBR server (required for Veeam PS module in VBR 13)
     19.  CPU core count on VBR server (minimum 8 logical cores required for VBR 13)
     20.  RAM on VBR server (minimum 16 GB required for VBR 13)

.PARAMETER TargetVersion
    The VBR version you are upgrading TO. Accepted values: '13.0' (default) or '13.1'.
    Use '13.0' when upgrading from VBR 12.x to VBR 13.
    Use '13.1' when upgrading from VBR 13.0.x to VBR 13.1.

.PARAMETER VBRServer
    FQDN or IP address of the Veeam Backup & Replication server.

.PARAMETER Port
    REST API port. Default: 9419.

.PARAMETER Credential
    PSCredential object for the VBR API user. If omitted you will be prompted.

.PARAMETER ReportPath
    Directory where the HTML report and error log are saved.
    Defaults to the current directory.

.PARAMETER SkipCertCheck
    Bypass TLS certificate validation (useful for self-signed certs in labs).

.EXAMPLE
    .\VBR13-PreUpgradeCheck.ps1 -VBRServer vbr01.corp.local -Credential (Get-Credential)

.EXAMPLE
    .\VBR13-PreUpgradeCheck.ps1 -VBRServer 10.0.0.50 -SkipCertCheck -ReportPath C:\Temp

.EXAMPLE
    .\VBR13-PreUpgradeCheck.ps1 -VBRServer vbr01.corp.local -TargetVersion 13.1 -Credential (Get-Credential)
    Check readiness for upgrading VBR 13.0.x to VBR 13.1.

.NOTES
    Author  : Veeam Pre-Upgrade Automation
    Version : 1.0
    Requires: PowerShell 5.1+ or PowerShell 7+
              VBR REST API port 9419 reachable from the machine running this script
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$VBRServer,

    [Parameter(Mandatory = $false)]
    [int]$Port = 9419,

    [Parameter(Mandatory = $false)]
    [System.Management.Automation.PSCredential]$Credential,

    [Parameter(Mandatory = $false)]
    [string]$ReportPath = (Get-Location).Path,

    [Parameter(Mandatory = $false)]
    [switch]$SkipCertCheck,

    # Target VBR version to check upgrade eligibility for.
    # '13.0' = upgrading from VBR 12.x | '13.1' = upgrading from VBR 13.0.x
    [Parameter(Mandatory = $false)]
    [ValidateSet('13.0', '13.1')]
    [string]$TargetVersion = '13.0',

    # REST API version of the INSTALLED VBR build (not the target).
    # VBR 11 = 1.1-rev2 | VBR 12 = 1.2-rev0 | VBR 13 = 1.3-rev1
    # Leave unset to auto-select based on -TargetVersion.
    [Parameter(Mandatory = $false)]
    [string]$ApiVersion = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

#region -- Initialisation ------------------------------------------------------

if (-not (Test-Path $ReportPath)) {
    New-Item -ItemType Directory -Path $ReportPath -Force | Out-Null
    Write-Host "[INFO] Created report directory: $ReportPath" -ForegroundColor Cyan
}

# Auto-select API version based on target if not explicitly supplied
if ([string]::IsNullOrEmpty($ApiVersion)) {
    $ApiVersion = if ($TargetVersion -eq '13.1') { '1.3-rev1' } else { '1.2-rev0' }
}

$TargetLabel    = $TargetVersion -replace '\.', ''
$RunTimestamp   = Get-Date -Format 'yyyyMMdd_HHmmss'
$ReportFile     = Join-Path $ReportPath "VBR${TargetLabel}_PreUpgrade_Report_$RunTimestamp.html"
$ErrorLogFile   = Join-Path $ReportPath "VBR${TargetLabel}_PreUpgrade_Errors_$RunTimestamp.log"
$BaseUrl        = "https://${VBRServer}:${Port}/api/v1"
$AuthUrl        = "https://${VBRServer}:${Port}/api/oauth2/token"

# Collected results: each entry is [Category, CheckName, Status, Detail]
$Results        = [System.Collections.Generic.List[PSCustomObject]]::new()
$ErrorLog       = [System.Collections.Generic.List[string]]::new()
$AccessToken    = $null

# Status constants
$PASS    = 'PASS'
$WARN    = 'WARN'
$FAIL    = 'FAIL'
$INFO    = 'INFO'
$ERROR_S = 'ERROR'

#endregion

#region -- Helper Functions ----------------------------------------------------

function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    $ts  = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "[$ts][$Level] $Message"
    Write-Host $line -ForegroundColor $(switch($Level){
        'INFO'  {'Cyan'}
        'PASS'  {'Green'}
        'WARN'  {'Yellow'}
        'FAIL'  {'Red'}
        'ERROR' {'Magenta'}
        default {'White'}
    })
    if ($Level -in 'FAIL','ERROR') { $ErrorLog.Add($line) }
}

function Add-Result {
    param(
        [string]$Category,
        [string]$CheckName,
        [string]$Status,
        [string]$Detail
    )
    $Results.Add([PSCustomObject]@{
        Category  = $Category
        CheckName = $CheckName
        Status    = $Status
        Detail    = $Detail
    })
    Write-Log "[$Category] $CheckName  -  $Status  -  $Detail" -Level $Status
}

function Invoke-VBRApi {
    param(
        [string]$Endpoint,
        [string]$Method = 'GET',
        [hashtable]$Body = $null,
        [string]$ContentType = 'application/json'
    )

    $headers = @{
        'x-api-version' = $ApiVersion
        'Accept'        = 'application/json'
    }
    if ($AccessToken) { $headers['Authorization'] = "Bearer $AccessToken" }

    $splat = @{
        Uri             = "${BaseUrl}${Endpoint}"
        Method          = $Method
        Headers         = $headers
        ContentType     = $ContentType
        UseBasicParsing = $true
    }
    if ($SkipCertCheck) {
        if ($PSVersionTable.PSVersion.Major -ge 7) {
            $splat['SkipCertificateCheck'] = $true
        } else {
            # PowerShell 5 workaround
            [Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        }
    }
    if ($Body) { $splat['Body'] = ($Body | ConvertTo-Json -Depth 10) }

    try {
        $response = Invoke-WebRequest @splat
        return ($response.Content | ConvertFrom-Json)
    } catch {
        throw $_
    }
}

#endregion

#region -- Check Functions -----------------------------------------------------

# -- 1. Server connectivity ----------------------------------------------------
function Test-ServerConnectivity {
    Write-Log "Testing connectivity to ${VBRServer}:${Port}..." -Level INFO
    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $tcp.Connect($VBRServer, $Port)
        $tcp.Close()
        Add-Result 'Connectivity' "TCP port $Port reachable" $PASS "Successfully connected to ${VBRServer}:${Port}"
        return $true
    } catch {
        Add-Result 'Connectivity' "TCP port $Port reachable" $FAIL "Cannot reach ${VBRServer}:${Port}  -  $($_.Exception.Message)"
        return $false
    }
}

# -- 2. API Authentication -----------------------------------------------------
function Connect-VBRApi {
    Write-Log "Authenticating to VBR REST API..." -Level INFO
    Write-Log "Auth URL: $AuthUrl" -Level INFO

    # PS 5.1 requires TLS to be set at the ServicePointManager level before any call
    if ($SkipCertCheck) {
        [Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    }

    try {
        $user      = $Credential.UserName
        $plainPass = $Credential.GetNetworkCredential().Password

        # Build a URL-encoded string body explicitly.
        # PS 5.1 Invoke-WebRequest does not reliably serialise a hashtable body
        # when ContentType is application/x-www-form-urlencoded (it can send an
        # empty payload). Using Invoke-RestMethod with a string body + Content-Type
        # in the Headers hashtable is the reliable cross-version approach.
        $bodyStr = "grant_type=password" +
                   "&username=$([uri]::EscapeDataString($user))" +
                   "&password=$([uri]::EscapeDataString($plainPass))"

        $splat = @{
            Uri     = $AuthUrl
            Method  = 'POST'
            Body    = $bodyStr
            Headers = @{
                'Content-Type'  = 'application/x-www-form-urlencoded'
                'x-api-version' = $ApiVersion
            }
        }
        if ($PSVersionTable.PSVersion.Major -ge 7 -and $SkipCertCheck) {
            $splat['SkipCertificateCheck'] = $true
        }

        # Invoke-RestMethod returns a parsed object directly (no ConvertFrom-Json needed)
        $parsed = Invoke-RestMethod @splat

        if (-not $parsed.access_token) {
            throw "Token endpoint returned no access_token. Response: $($parsed | Out-String)"
        }
        $script:AccessToken = $parsed.access_token
        Add-Result 'Connectivity' 'REST API authentication' $PASS "Authenticated as $user"
        return $true

    } catch {
        $detail = $_.Exception.Message
        try {
            $errResp   = $_.Exception.Response
            $errStream = $errResp.GetResponseStream()
            $reader    = New-Object System.IO.StreamReader($errStream)
            $errText   = $reader.ReadToEnd()
            $reader.Close()
            if ($errText) { $detail += " | VBR: $errText" }
            $detail += " | HTTP $([int]$errResp.StatusCode) $($errResp.StatusDescription)"
        } catch { }
        Add-Result 'Connectivity' 'REST API authentication' $FAIL "Authentication failed - $detail"
        return $false
    }
}

# -- 3. VBR version -----------------------------------------------------------
function Test-VBRVersion {
    Write-Log "Checking VBR server version (target: VBR $TargetVersion)..." -Level INFO
    try {
        $vbrInfo = Invoke-VBRApi -Endpoint '/serverInfo'
        $version = $vbrInfo.buildVersion
        Add-Result 'Version' 'VBR server version' $INFO "Installed version: $version"

        $vParts = $version -split '\.'
        $vMaj   = if ($vParts.Count -ge 1) { [int]$vParts[0] } else { 0 }
        $vMin   = if ($vParts.Count -ge 2) { [int]$vParts[1] } else { 0 }
        $vPatch = if ($vParts.Count -ge 3) { [int]$vParts[2] } else { 0 }
        $vBuild = if ($vParts.Count -ge 4) { [int]$vParts[3] } else { 0 }

        if ($TargetVersion -eq '13.1') {
            # --- Target: VBR 13.1 (upgrading from 13.0.x) ---
            if ($vMaj -eq 13 -and $vMin -ge 1) {
                Add-Result 'Version' "Version eligible for upgrade to VBR $TargetVersion" $WARN "Version $version is VBR 13.1 or later already  -  upgrade may not be required"
            } elseif ($vMaj -eq 13 -and $vMin -eq 0 -and $vPatch -ge 1) {
                # 13.0.1 or later patch - supported for direct upgrade to 13.1
                Add-Result 'Version' "Version eligible for upgrade to VBR $TargetVersion" $PASS "Version $version  -  eligible for direct upgrade to VBR 13.1"
            } elseif ($vMaj -eq 13 -and $vMin -eq 0 -and $vPatch -eq 0) {
                # 13.0.0 RTM - recommend patching to 13.0.1 first
                Add-Result 'Version' "Version eligible for upgrade to VBR $TargetVersion" $WARN "Version $version (VBR 13.0.0). Apply the latest VBR 13.0 patch (13.0.1+) before upgrading to VBR 13.1."
            } elseif ($vMaj -eq 12) {
                Add-Result 'Version' "Version eligible for upgrade to VBR $TargetVersion" $FAIL "Version $version (VBR 12) cannot upgrade directly to VBR 13.1. Upgrade to VBR 13.0.1 first, then to VBR 13.1."
            } else {
                Add-Result 'Version' "Version eligible for upgrade to VBR $TargetVersion" $FAIL "Version $version is not eligible for VBR 13.1. Upgrade path: VBR 13.0.1 -> VBR 13.1."
            }
        } else {
            # --- Target: VBR 13.0 (upgrading from VBR 12.x) ---
            # Minimum source: 12.3.1.1139+ or 12.3.2+
            if ($vMaj -eq 13) {
                Add-Result 'Version' "Version eligible for upgrade to VBR $TargetVersion" $WARN "Version $version appears to be VBR 13 already  -  upgrade may not be required"
            } elseif ($vMaj -eq 12) {
                if ($vMin -gt 3) {
                    # 12.4+ (future release) - treat as eligible
                    Add-Result 'Version' "Version eligible for upgrade to VBR $TargetVersion" $PASS "Version $version  -  eligible for direct upgrade to VBR 13"
                } elseif ($vMin -eq 3 -and $vPatch -ge 2) {
                    # 12.3.2 or later
                    Add-Result 'Version' "Version eligible for upgrade to VBR $TargetVersion" $PASS "Version $version  -  eligible for direct upgrade to VBR 13"
                } elseif ($vMin -eq 3 -and $vPatch -eq 1 -and $vBuild -ge 1139) {
                    # 12.3.1 build 1139 or later
                    Add-Result 'Version' "Version eligible for upgrade to VBR $TargetVersion" $PASS "Version $version  -  eligible for direct upgrade to VBR 13 (minimum 12.3.1.1139 met)"
                } elseif ($vMin -eq 3 -and $vPatch -eq 1 -and $vBuild -gt 0) {
                    # 12.3.1 but build < 1139
                    Add-Result 'Version' "Version eligible for upgrade to VBR $TargetVersion" $FAIL "Version $version is below minimum build 12.3.1.1139 for direct VBR 13 upgrade. Apply the 12.3.1 patch (build 1139+) or upgrade to 12.3.2 first."
                } else {
                    # 12.3.0 or earlier 12.x
                    Add-Result 'Version' "Version eligible for upgrade to VBR $TargetVersion" $FAIL "Version $version requires an intermediate upgrade to VBR 12.3.1 (build 1139+) or 12.3.2 before upgrading to VBR 13."
                }
            } elseif ($vMaj -eq 11) {
                Add-Result 'Version' "Version eligible for upgrade to VBR $TargetVersion" $FAIL "Version $version (VBR 11) cannot upgrade directly to VBR 13. Upgrade to VBR 12.3.1 (build 1139+) or 12.3.2 first."
            } else {
                Add-Result 'Version' "Version eligible for upgrade to VBR $TargetVersion" $FAIL "Version $version is not directly upgradeable to VBR 13. Review upgrade path requirements."
            }
        }
    } catch {
        Add-Result 'Version' 'VBR server version' $ERROR_S "Could not retrieve version  -  $($_.Exception.Message)"
        $ErrorLog.Add("[ERROR] Test-VBRVersion: $($_.Exception.Message)")
    }
}

# -- 4. License ---------------------------------------------------------------
function Test-License {
    Write-Log "Checking license status..." -Level INFO
    try {
        $lic = Invoke-VBRApi -Endpoint '/license'

        $licType    = $lic.type
        $licStatus  = $lic.status
        $expiry     = if ($lic.expirationDate) { [datetime]$lic.expirationDate } else { $null }
        $daysLeft   = if ($expiry) { ($expiry - (Get-Date)).Days } else { $null }

        Add-Result 'License' 'License type' $INFO "Type: $licType | Status: $licStatus"

        if ($licStatus -in 'Valid','Active') {
            if ($daysLeft -ne $null -and $daysLeft -le 30) {
                Add-Result 'License' 'License expiry' $WARN "License expires in $daysLeft day(s) on $($expiry.ToString('yyyy-MM-dd')). Renew before upgrading."
            } elseif ($daysLeft -ne $null) {
                Add-Result 'License' 'License expiry' $PASS "License valid  -  expires $($expiry.ToString('yyyy-MM-dd')) ($daysLeft days remaining)"
            } else {
                Add-Result 'License' 'License expiry' $PASS "License is perpetual/rental  -  no expiry date"
            }
        } elseif ($licStatus -eq 'Expired') {
            Add-Result 'License' 'License expiry' $FAIL "License is EXPIRED. Upgrade cannot proceed without a valid license."
        } else {
            Add-Result 'License' 'License status' $WARN "License status: $licStatus  -  verify before upgrading"
        }
    } catch {
        Add-Result 'License' 'License check' $ERROR_S "Could not retrieve license info  -  $($_.Exception.Message)"
        $ErrorLog.Add("[ERROR] Test-License: $($_.Exception.Message)")
    }
}

# -- 5. Configuration backup ---------------------------------------------------
function Test-ConfigBackup {
    Write-Log "Checking configuration backup status..." -Level INFO
    try {
        $cfg = Invoke-VBRApi -Endpoint '/configBackup'

        $enabled    = if ($cfg.PSObject.Properties['isEnabled'])  { $cfg.isEnabled  } else { $false }
        $targetPath = if ($cfg.PSObject.Properties['targetDir']) { $cfg.targetDir } else { 'unknown' }
        # VBR 12: lastSuccessfulBackup is a nested object {lastSuccessfulTime, sessionId}
        # VBR 13: lastSuccessfulBackup may be a direct datetime string
        $lastRunRaw = $null
        if ($cfg.PSObject.Properties['lastSuccessfulBackup'] -and $cfg.lastSuccessfulBackup) {
            if ($cfg.lastSuccessfulBackup -is [System.Management.Automation.PSCustomObject]) {
                # Property name varies by VBR version - try each known variant under StrictMode-safe checks
                if      ($cfg.lastSuccessfulBackup.PSObject.Properties['lastSuccessfulTime']) { $lastRunRaw = [string]$cfg.lastSuccessfulBackup.lastSuccessfulTime }
                elseif  ($cfg.lastSuccessfulBackup.PSObject.Properties['lastSuccessTime'])    { $lastRunRaw = [string]$cfg.lastSuccessfulBackup.lastSuccessTime    }
                elseif  ($cfg.lastSuccessfulBackup.PSObject.Properties['time'])               { $lastRunRaw = [string]$cfg.lastSuccessfulBackup.time               }
                else {
                    # Fallback: find first property whose value looks like a datetime string
                    $dtProp = $cfg.lastSuccessfulBackup.PSObject.Properties |
                        Where-Object { ($_.Value -is [datetime]) -or (($_.Value -is [string]) -and ($_.Value -match '^\d{4}-\d{2}-\d{2}')) } |
                        Select-Object -First 1
                    if ($dtProp) {
                        $lastRunRaw = [string]$dtProp.Value
                    } else {
                        $propList = ($cfg.lastSuccessfulBackup.PSObject.Properties | Select-Object -ExpandProperty Name) -join ', '
                        Write-Log "Config backup nested object has unexpected structure. Properties: $propList" -Level INFO
                    }
                }
            } else {
                $lastRunRaw = [string]$cfg.lastSuccessfulBackup
            }
        }
        $lastRun = if ($lastRunRaw -and $lastRunRaw.Trim() -ne '') { [datetime]$lastRunRaw } else { $null }

        if (-not $enabled) {
            Add-Result 'Config Backup' 'Configuration backup enabled' $WARN "Configuration backup is DISABLED. Enable and run a backup before upgrading."
        } else {
            Add-Result 'Config Backup' 'Configuration backup enabled' $PASS "Configuration backup is enabled (target: $targetPath)"
        }

        if ($lastRun) {
            $age = ((Get-Date) - $lastRun).Days
            if ($age -le 1) {
                Add-Result 'Config Backup' 'Recent config backup exists' $PASS "Last successful backup: $($lastRun.ToString('yyyy-MM-dd HH:mm')) ($age day(s) ago)"
            } elseif ($age -le 7) {
                Add-Result 'Config Backup' 'Recent config backup exists' $WARN "Last config backup was $age days ago ($($lastRun.ToString('yyyy-MM-dd'))). Consider running a fresh backup."
            } else {
                Add-Result 'Config Backup' 'Recent config backup exists' $FAIL "Last config backup was $age days ago ($($lastRun.ToString('yyyy-MM-dd'))). Run a configuration backup BEFORE upgrading."
            }
        } else {
            Add-Result 'Config Backup' 'Recent config backup exists' $FAIL "No successful configuration backup found. Create one before upgrading."
        }
    } catch {
        Add-Result 'Config Backup' 'Configuration backup check' $ERROR_S "Could not retrieve config backup info  -  $($_.Exception.Message)"
        $ErrorLog.Add("[ERROR] Test-ConfigBackup: $($_.Exception.Message)")
    }
}

# -- 6. Running jobs -----------------------------------------------------------
function Test-RunningJobs {
    Write-Log "Checking for running jobs..." -Level INFO

    $jobData   = @()
    $statesSrc = ''
    $fetchErr  = ''

    # Try /jobs/states (preferred); fall back to /sessions if it returns an error (e.g. HTTP 500)
    try {
        $states    = Invoke-VBRApi -Endpoint '/jobs/states'
        $jobData   = @(if ($states.data) { $states.data } elseif ($states -is [array]) { $states } else { @() })
        $statesSrc = '/jobs/states'
    } catch {
        $fetchErr = $_.Exception.Message
        Write-Log "  /jobs/states unavailable ($fetchErr) - falling back to /sessions" -Level INFO
        try {
            $sessResp  = Invoke-VBRApi -Endpoint '/sessions?limit=500'
            $jobData   = @(if ($sessResp.data) { $sessResp.data } elseif ($sessResp -is [array]) { $sessResp } else { @() })
            $statesSrc = '/sessions (fallback)'
        } catch {
            Add-Result 'Active Jobs' 'Running jobs check' $WARN "/jobs/states returned an error ($fetchErr) and session fallback also failed  -  verify no jobs are running before upgrading"
            $ErrorLog.Add("[WARN] Test-RunningJobs (both endpoints failed): $fetchErr")
            return
        }
    }

    # VBR 12 uses 'status'; VBR 13 uses 'state' - handle both
    $running = @($jobData | Where-Object {
        ($_.PSObject.Properties['state']  -and $_.state  -in 'Running','Starting','Stopping','WaitingTape') -or
        ($_.PSObject.Properties['status'] -and $_.status -in 'Running','Starting','Stopping','WaitingTape')
    })

    if ($running.Count -eq 0) {
        Add-Result 'Active Jobs' 'No jobs currently running' $PASS "All backup/replication jobs are idle (source: $statesSrc)"
    } else {
        $names = ($running | ForEach-Object { if ($_.PSObject.Properties['name']) { $_.name } else { '(unnamed)' } }) -join ', '
        Add-Result 'Active Jobs' 'No jobs currently running' $FAIL "$($running.Count) job(s) are running: $names  -  stop all jobs before upgrading (source: $statesSrc)"
    }
}

# -- 7. Active sessions --------------------------------------------------------
function Test-ActiveSessions {
    Write-Log "Checking for active sessions..." -Level INFO
    try {
        $sessions    = Invoke-VBRApi -Endpoint '/sessions?limit=500'
        $allSessions = @(if ($sessions.data) { $sessions.data } elseif ($sessions -is [array]) { $sessions } else { @() })
        # VBR 12 uses 'status'; VBR 13 uses 'state' - handle both
        $active = @($allSessions | Where-Object {
            ($_.PSObject.Properties['state']  -and $_.state  -in 'Running','Starting','Stopping','WaitingTape') -or
            ($_.PSObject.Properties['status'] -and $_.status -in 'Running','Starting','Stopping','WaitingTape')
        })

        if ($active.Count -eq 0) {
            Add-Result 'Active Sessions' 'No active sessions' $PASS "No backup, restore, or replication sessions are currently active"
        } else {
            $types = ($allSessions | Where-Object { $_.state -in 'Running','Starting','Stopping','WaitingTape' } | Group-Object jobType | ForEach-Object { "$($_.Name): $($_.Count)" }) -join ' | '
            Add-Result 'Active Sessions' 'No active sessions' $FAIL "$($active.Count) active session(s) found  -  $types. Wait for completion or stop before upgrading."
        }
    } catch {
        Add-Result 'Active Sessions' 'Active sessions check' $ERROR_S "Could not retrieve sessions  -  $($_.Exception.Message)"
        $ErrorLog.Add("[ERROR] Test-ActiveSessions: $($_.Exception.Message)")
    }
}

# -- 8. Repositories -----------------------------------------------------------
function Test-Repositories {
    Write-Log "Checking repository free space..." -Level INFO
    try {
        $repoResp = Invoke-VBRApi -Endpoint '/backupInfrastructure/repositories/states'
        $repoData = @(if ($repoResp.data) { $repoResp.data } elseif ($repoResp -is [array]) { $repoResp } else { @() })
        $warnGB   = 10
        $failGB   = 2

        # Dump property names from first repo for diagnostics
        if ($repoData.Count -gt 0) {
            $propNames = ($repoData[0].PSObject.Properties | Select-Object -ExpandProperty Name) -join ', '
            Write-Log "Repository object properties: $propNames" -Level INFO
        }

        foreach ($repo in $repoData) {
            # VBR 12 exposes capacityGB, freeGB, usedSpaceGB; fall back to byte variants for other versions.
            $repoName = if ($repo.PSObject.Properties['name']) { $repo.name } else { [string]$repo.id }

            $freeGB  = if      ($repo.PSObject.Properties['freeGB'])         { [double]$repo.freeGB }
                       elseif  ($repo.PSObject.Properties['freeSpaceGB'])    { [double]$repo.freeSpaceGB }
                       elseif  ($repo.PSObject.Properties['freeSpace'])      { [math]::Round([double]$repo.freeSpace  / 1073741824, 1) }
                       else { -1 }

            $totalGB = if      ($repo.PSObject.Properties['capacityGB'])     { [double]$repo.capacityGB }
                       elseif  ($repo.PSObject.Properties['capacity'])       { [math]::Round([double]$repo.capacity   / 1073741824, 1) }
                       else {
                           $usedGB = if ($repo.PSObject.Properties['usedSpaceGB']) { [double]$repo.usedSpaceGB } else { 0 }
                           if ($freeGB -ge 0 -and $usedGB -gt 0) { [math]::Round($freeGB + $usedGB, 1) } else { 0 }
                       }

            if ($freeGB -lt 0) {
                $props = ($repo.PSObject.Properties | Select-Object -ExpandProperty Name) -join ', '
                Add-Result 'Repositories' "Repository: $repoName" $WARN "Could not determine free space - available properties: $props"
                continue
            }
            $freeGB  = [math]::Round($freeGB,  1)
            $totalGB = [math]::Round($totalGB, 1)
            $pctFree = if ($totalGB -gt 0) { [math]::Round(($freeGB / $totalGB) * 100, 1) } else { 0 }
            $detail  = "$repoName  -  Free: ${freeGB} GB / Total: ${totalGB} GB ($pctFree%)" 
            if ($freeGB -lt $failGB) {
                Add-Result 'Repositories' "Repository space: $repoName" $FAIL "$detail  -  CRITICALLY LOW"
            } elseif ($freeGB -lt $warnGB) {
                Add-Result 'Repositories' "Repository space: $repoName" $WARN "$detail  -  Low free space"
            } else {
                Add-Result 'Repositories' "Repository space: $repoName" $PASS $detail
            }
        }

        if ($repoData.Count -eq 0) {
            Add-Result 'Repositories' 'Repository check' $WARN "No repositories returned from API"
        }
    } catch {
        Add-Result 'Repositories' 'Repository space check' $ERROR_S "Could not retrieve repository states  -  $($_.Exception.Message)"
        $ErrorLog.Add("[ERROR] Test-Repositories: $($_.Exception.Message)")
    }
}

# -- 9. Proxies ----------------------------------------------------------------
function Test-Proxies {
    Write-Log "Checking proxy availability..." -Level INFO
    try {
        # VBR 12 may not have the /states sub-endpoint; fall back to /proxies
        $proxyResp = $null
        try   { $proxyResp = Invoke-VBRApi -Endpoint '/backupInfrastructure/proxies/states' }
        catch { $proxyResp = Invoke-VBRApi -Endpoint '/backupInfrastructure/proxies' }
        $proxyData = @(if ($proxyResp.data) { $proxyResp.data } elseif ($proxyResp -is [array]) { $proxyResp } else { @() })
        # Only flag proxies that are explicitly in a bad state.
        # "Unknown" means untested/unreachable check - not necessarily unavailable.
        $badProxyStates = @('Unavailable','Offline','Error','Warning','Disabled','Failed','Unreachable')
        $unavail = @($proxyData | Where-Object {
            $st = if ($_.PSObject.Properties['status']) { $_.status } elseif ($_.PSObject.Properties['state']) { $_.state } else { '' }
            $st -in $badProxyStates
        })

        if ($proxyData.Count -eq 0) {
            Add-Result 'Proxies' 'Proxy availability' $WARN "No proxies found in the infrastructure"
        } elseif ($unavail.Count -eq 0) {
            $statusBreakdown = ($proxyData | ForEach-Object {
                $st = if ($_.PSObject.Properties['status']) { $_.status } elseif ($_.PSObject.Properties['state']) { $_.state } else { 'Unknown' }
                $nm = if ($_.PSObject.Properties['name'])   { $_.name }   else { $_.id }
                "$nm [$st]"
            }) -join ', '
            Add-Result 'Proxies' 'Proxy availability' $PASS "$($proxyData.Count) proxy/proxies  -  no failed proxies detected: $statusBreakdown"
        } else {
            $names = ($unavail | ForEach-Object {
                $n  = if ($_.PSObject.Properties['name'])   { $_.name }   else { $_.id }
                $st = if ($_.PSObject.Properties['status']) { $_.status } elseif ($_.PSObject.Properties['state']) { $_.state } else { 'Unknown' }
                "$n [$st]"
            }) -join ', ' 
            Add-Result 'Proxies' 'Proxy availability' $WARN "$($unavail.Count) proxy/proxies not available: $names"
        }
    } catch {
        Add-Result 'Proxies' 'Proxy availability check' $ERROR_S "Could not retrieve proxy states  -  $($_.Exception.Message)"
        $ErrorLog.Add("[ERROR] Test-Proxies: $($_.Exception.Message)")
    }
}

# -- 10. Managed server components --------------------------------------------
function Test-ManagedServers {
    Write-Log "Checking managed server component versions..." -Level INFO
    try {
        $svrResp  = Invoke-VBRApi -Endpoint '/backupInfrastructure/managedServers'
        $svrData  = @(if ($svrResp.data) { $svrResp.data } elseif ($svrResp -is [array]) { $svrResp } else { @() })
        # VBR 12 may use 'outOfDate' or not expose this property at all
        $outdated = @($svrData | Where-Object {
            ($_.PSObject.Properties['isOutOfDate'] -and $_.isOutOfDate -eq $true) -or
            ($_.PSObject.Properties['outOfDate']   -and $_.outOfDate   -eq $true)
        })

        if ($outdated.Count -eq 0) {
            Add-Result 'Infrastructure' 'Managed server components up to date' $PASS "All $($svrData.Count) managed server(s) are current"
        } else {
            $names = ($outdated | ForEach-Object { if ($_.PSObject.Properties['name']) { $_.name } else { $_.id } }) -join ', '
            Add-Result 'Infrastructure' 'Managed server components up to date' $WARN "$($outdated.Count) server(s) have outdated components: $names  -  components will be updated during upgrade"
        }
    } catch {
        Add-Result 'Infrastructure' 'Managed server component check' $ERROR_S "Could not retrieve managed server data  -  $($_.Exception.Message)"
        $ErrorLog.Add("[ERROR] Test-ManagedServers: $($_.Exception.Message)")
    }
}

# Shared helper: open CIM session to VBR server (WSMan, fall back to DCOM)
function New-VBRCimSession {
    $credArgs = @{}
    if ($Credential) { $credArgs['Credential'] = $Credential }
    try {
        return New-CimSession -ComputerName $VBRServer @credArgs -ErrorAction Stop
    } catch {
        $dcom = New-CimSessionOption -Protocol Dcom
        return New-CimSession -ComputerName $VBRServer @credArgs -SessionOption $dcom -ErrorAction Stop
    }
}

# -- 11. VBR server OS version -------------------------------------------------
function Test-LocalOSVersion {
    Write-Log "Checking VBR server ($VBRServer) OS version via WMI..." -Level INFO
    try {
        $cimSession = New-VBRCimSession
        try {
            $os = Get-CimInstance -CimSession $cimSession -ClassName Win32_OperatingSystem -ErrorAction Stop
        } finally {
            Remove-CimSession $cimSession -ErrorAction SilentlyContinue
        }
        $caption = $os.Caption
        $build   = $os.BuildNumber

        Add-Result 'VBR Server' 'Operating system version' $INFO "$caption (Build $build)"

        if ($build -ge 20348) {
            Add-Result 'VBR Server' 'OS meets VBR 13 requirements' $PASS "Windows Server 2022  -  fully supported"
        } elseif ($build -ge 17763) {
            Add-Result 'VBR Server' 'OS meets VBR 13 requirements' $PASS "Windows Server 2019  -  fully supported"
        } elseif ($build -ge 14393) {
            Add-Result 'VBR Server' 'OS meets VBR 13 requirements' $WARN "Windows Server 2016  -  verify support with Veeam KB for VBR 13"
        } else {
            Add-Result 'VBR Server' 'OS meets VBR 13 requirements' $FAIL "$caption is not supported for VBR 13. Upgrade to Windows Server 2019 or 2022."
        }
    } catch {
        Add-Result 'VBR Server' 'OS version check' $WARN "Could not query OS version on $VBRServer via WMI  -  $($_.Exception.Message). Verify manually."
        $ErrorLog.Add("[ERROR] Test-LocalOSVersion: $($_.Exception.Message)")
    }
}

# -- 12. Pending reboot (on VBR server via WMI) --------------------------------
function Test-PendingReboot {
    Write-Log "Checking VBR server ($VBRServer) for pending reboot via WMI..." -Level INFO
    try {
        $cimSession = New-VBRCimSession
        try {
            # Use Win32_ComputerSystem + registry keys via StdRegProv WMI class
            $reg    = [Microsoft.Win32.RegistryKey]
            $hklm   = 2147483650   # HKEY_LOCAL_MACHINE
            $stdReg = Get-CimClass -CimSession $cimSession -Namespace root/default -ClassName StdRegProv -ErrorAction Stop

            $checkKey = {
                param($session, $hive, $key)
                $result = Invoke-CimMethod -CimSession $session -ClassName StdRegProv `
                    -Namespace root/default -MethodName CheckAccess `
                    -Arguments @{ hDefKey = $hive; sSubKeyName = $key; uRequired = 1 } -ErrorAction SilentlyContinue
                return ($result -and $result.bGranted)
            }

            $pendingReboot = $false
            $reasons       = @()

            if (& $checkKey $cimSession $hklm 'SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') {
                $pendingReboot = $true; $reasons += 'Windows Update'
            }
            if (& $checkKey $cimSession $hklm 'SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') {
                $pendingReboot = $true; $reasons += 'Component Based Servicing'
            }

            # PendingFileRenameOperations via WMI registry
            $pfroResult = Invoke-CimMethod -CimSession $cimSession -ClassName StdRegProv `
                -Namespace root/default -MethodName GetMultiStringValue `
                -Arguments @{ hDefKey = $hklm; sSubKeyName = 'SYSTEM\CurrentControlSet\Control\Session Manager'; sValueName = 'PendingFileRenameOperations' } `
                -ErrorAction SilentlyContinue
            if ($pfroResult -and $pfroResult.sValue -and $pfroResult.sValue.Count -gt 0) {
                $pendingReboot = $true; $reasons += 'Pending File Rename'
            }
        } finally {
            Remove-CimSession $cimSession -ErrorAction SilentlyContinue
        }

        if ($pendingReboot) {
            Add-Result 'VBR Server' 'No pending Windows reboot' $FAIL "Server has a pending reboot: $($reasons -join ', '). Reboot and verify before upgrading."
        } else {
            Add-Result 'VBR Server' 'No pending Windows reboot' $PASS "No pending reboot detected on $VBRServer"
        }
    } catch {
        Add-Result 'VBR Server' 'Pending reboot check' $WARN "Could not check pending reboot on $VBRServer via WMI  -  $($_.Exception.Message). Verify manually."
        $ErrorLog.Add("[ERROR] Test-PendingReboot: $($_.Exception.Message)")
    }
}

# -- 13. Veeam Windows services (on VBR server) --------------------------------
function Test-VeeamServices {
    Write-Log "Checking Veeam Windows services on $VBRServer..." -Level INFO
    $veeamServices = @(
        'VeeamBackupSvc',
        'VeeamBrokerSvc',
        'VeeamCatalogSvc',
        'VeeamCloudSvc',
        'VeeamDeploymentSvc',
        'VeeamFilesysVssSvc',
        'VeeamMountSvc',
        'VeeamNFSSvc',
        'VeeamRESTSvc',
        'VeeamTransportSvc'
    )

    try {
        $cimSession = New-VBRCimSession
        try {
            $svcData = Get-CimInstance -CimSession $cimSession -ClassName Win32_Service `
                           -Filter "Name LIKE 'Veeam%'" -ErrorAction Stop
        } finally {
            Remove-CimSession $cimSession -ErrorAction SilentlyContinue
        }

        $veeamSvcs  = @($svcData | Where-Object { $_.Name -in $veeamServices -and $_.StartMode -ne 'Disabled' })
        $notRunning = @($veeamSvcs | Where-Object { $_.State -ne 'Running' })

        if ($notRunning.Count -eq 0) {
            Add-Result 'VBR Server' 'Veeam services running' $PASS "All $($veeamSvcs.Count) Veeam service(s) are running on $VBRServer"
        } else {
            $names = ($notRunning | ForEach-Object { "$($_.Name) [$($_.State)]" }) -join ', '
            Add-Result 'VBR Server' 'Veeam services running' $FAIL "$($notRunning.Count) Veeam service(s) not running on ${VBRServer}: $names"
        }
    } catch {
        Add-Result 'VBR Server' 'Veeam services check' $WARN "Could not query services on $VBRServer via WMI  -  $($_.Exception.Message). Verify manually."
        $ErrorLog.Add("[ERROR] Test-VeeamServices: $($_.Exception.Message)")
    }
}

# -- 14. System drive free space (on VBR server via WMI) ----------------------
function Test-SystemDriveSpace {
    Write-Log "Checking VBR server ($VBRServer) system drive free space via WMI..." -Level INFO
    try {
        $cimSession = New-VBRCimSession
        try {
            $remoteOS = Get-CimInstance -CimSession $cimSession -ClassName Win32_OperatingSystem -ErrorAction Stop
            $sysDrive = $remoteOS.SystemDrive   # e.g. "C:"

            $diskInfo = Get-CimInstance -CimSession $cimSession -ClassName Win32_LogicalDisk `
                            -Filter "DeviceID='$sysDrive'" -ErrorAction Stop
            $freeGB  = [math]::Round($diskInfo.FreeSpace / 1073741824, 1)
            $totalGB = [math]::Round($diskInfo.Size       / 1073741824, 1)
        } finally {
            Remove-CimSession $cimSession -ErrorAction SilentlyContinue
        }

        if ($freeGB -ge 10) {
            Add-Result 'VBR Server' "System drive ($sysDrive) free space" $PASS "${freeGB} GB free of ${totalGB} GB  -  sufficient for upgrade installer"
        } elseif ($freeGB -ge 5) {
            Add-Result 'VBR Server' "System drive ($sysDrive) free space" $WARN "${freeGB} GB free of ${totalGB} GB  -  minimum met but 10 GB+ recommended"
        } else {
            Add-Result 'VBR Server' "System drive ($sysDrive) free space" $FAIL "${freeGB} GB free of ${totalGB} GB  -  insufficient, at least 10 GB required for the upgrade installer"
        }
    } catch {
        Add-Result 'VBR Server' 'System drive free space' $WARN "Could not query disk space on $VBRServer via WMI  -  $($_.Exception.Message). Verify manually before upgrading."
        $ErrorLog.Add("[ERROR] Test-SystemDriveSpace: $($_.Exception.Message)")
    }
}


# -- 15. Deprecated features (VBR 13) -----------------------------------------
function Test-DeprecatedFeatures {
    Write-Log "Checking for deprecated VBR 13 features in use..." -Level INFO

    # Helper: safely get a nested property value by dot-path, returns $null if missing
    function Get-SafeProp {
        param($Obj, [string[]]$Path)
        $cur = $Obj
        foreach ($key in $Path) {
            if (-not $cur -or -not ($cur.PSObject.Properties[$key])) { return $null }
            $cur = $cur.$key
        }
        return $cur
    }

    # -- 1 & 2. Fetch /jobs once; reuse for both job-related checks -------------
    $allJobsList = @()
    $jobsFetched = $false
    $jobsFetchErr = ''
    try {
        $jobsResp    = Invoke-VBRApi -Endpoint '/jobs'
        $allJobsList = @(if ($jobsResp.data) { $jobsResp.data } elseif ($jobsResp -is [array]) { $jobsResp } else { @() })
        $jobsFetched = $true
    } catch {
        $jobsFetchErr = $_.Exception.Message
    }

    # -- 1. Reversed incremental backup mode ------------------------------------
    if ($jobsFetched) {
        $revJobs = @($allJobsList | Where-Object {
            $mode = Get-SafeProp $_ 'storage','backupStorageSettings','backupMode'
            if (-not $mode) { $mode = Get-SafeProp $_ 'storage','backupMode' }
            if (-not $mode) { $mode = Get-SafeProp $_ 'backupMode' }
            $mode -eq 'ReverseIncremental'
        })
        if ($revJobs.Count -gt 0) {
            $names = ($revJobs | ForEach-Object { if ($_.PSObject.Properties['name']) { $_.name } else { $_.id } }) -join ', '
            Add-Result 'Deprecated Features' 'Reversed incremental backup mode' $WARN "$($revJobs.Count) job(s) use reversed incremental mode (no longer available for new jobs in VBR 13): $names"
        } else {
            Add-Result 'Deprecated Features' 'Reversed incremental backup mode' $PASS "No jobs using reversed incremental backup mode"
        }
    } else {
        Add-Result 'Deprecated Features' 'Reversed incremental backup mode' $INFO "Could not query job modes - verify manually in VBR console ($jobsFetchErr)"
        $ErrorLog.Add("[INFO] Test-DeprecatedFeatures (reversed incremental): $jobsFetchErr")
    }

    # -- 2. Restore point-based retention --------------------------------------
    if ($jobsFetched) {
        $rpRetJobs = @($allJobsList | Where-Object {
            $retType = Get-SafeProp $_ 'storage','retentionPolicy','type'
            if (-not $retType) { $retType = Get-SafeProp $_ 'storage','backupStorageSettings','retentionType' }
            if (-not $retType) { $retType = Get-SafeProp $_ 'storage','retentionType' }
            $retType -in 'RestorePoints','ByRestorePoints'
        })
        if ($rpRetJobs.Count -gt 0) {
            $names = ($rpRetJobs | ForEach-Object { if ($_.PSObject.Properties['name']) { $_.name } else { $_.id } }) -join ', '
            Add-Result 'Deprecated Features' 'Restore point-based retention' $WARN "$($rpRetJobs.Count) job(s) use restore point-based retention (no longer available for new jobs in VBR 13): $names"
        } else {
            Add-Result 'Deprecated Features' 'Restore point-based retention' $PASS "No jobs using restore point-based retention"
        }
    } else {
        Add-Result 'Deprecated Features' 'Restore point-based retention' $INFO "Could not query job retention settings - verify manually in VBR console ($jobsFetchErr)"
        $ErrorLog.Add("[INFO] Test-DeprecatedFeatures (restore point retention): $jobsFetchErr")
    }

    # -- 3. Single-storage backup format (repository setting) --------------------
    try {
        $repoListResp = Invoke-VBRApi -Endpoint '/backupInfrastructure/repositories'
        $repoList     = @(if ($repoListResp.data) { $repoListResp.data } elseif ($repoListResp -is [array]) { $repoListResp } else { @() })

        # Single-storage = perMachineBackup disabled / backupFormat = 'SingleFile' / usePerMachineBackupFiles = false
        $singleStoreRepos = @($repoList | Where-Object {
            $perMachine = Get-SafeProp $_ 'repository','advancedSettings','perMachineBackup'
            if ($perMachine -eq $null) { $perMachine = Get-SafeProp $_ 'advancedSettings','perMachineBackup' }
            if ($perMachine -eq $null) { $perMachine = Get-SafeProp $_ 'perMachineBackup' }
            # flag repos where perMachineBackup is explicitly $false
            ($perMachine -ne $null) -and ($perMachine -eq $false)
        })

        if ($singleStoreRepos.Count -gt 0) {
            $names = ($singleStoreRepos | ForEach-Object { if ($_.PSObject.Properties['name']) { $_.name } else { $_.id } }) -join ', '
            Add-Result 'Deprecated Features' 'Single-storage backup format' $WARN "$($singleStoreRepos.Count) repository(ies) use single-storage format (no longer available in VBR 13 repository settings): $names"
        } else {
            Add-Result 'Deprecated Features' 'Single-storage backup format' $PASS "No repositories using single-storage backup format"
        }
    } catch {
        Add-Result 'Deprecated Features' 'Single-storage backup format' $INFO "Could not query repository format settings - verify manually in VBR console ($($_.Exception.Message))"
        $ErrorLog.Add("[INFO] Test-DeprecatedFeatures (single-storage): $($_.Exception.Message)")
    }

    # -- 4. AD-based auth for Cloud Connect tenants ------------------------------
    try {
        $ccResp    = Invoke-VBRApi -Endpoint '/cloudConnect/tenants'
        $ccTenants = @(if ($ccResp.data) { $ccResp.data } elseif ($ccResp -is [array]) { $ccResp } else { @() })

        if ($ccTenants.Count -eq 0) {
            Add-Result 'Deprecated Features' 'Cloud Connect AD authentication' $INFO "No Cloud Connect tenants configured on this server"
        } else {
            $adTenants = @($ccTenants | Where-Object {
                $authType = Get-SafeProp $_ 'authentication','type'
                if (-not $authType) { $authType = Get-SafeProp $_ 'authType' }
                if (-not $authType) { $authType = Get-SafeProp $_ 'activeDirectoryAuth','isEnabled' }
                $authType -in 'ActiveDirectory','AD' -or $authType -eq $true
            })

            if ($adTenants.Count -gt 0) {
                $names = ($adTenants | ForEach-Object { if ($_.PSObject.Properties['name']) { $_.name } else { $_.id } }) -join ', '
                Add-Result 'Deprecated Features' 'Cloud Connect AD authentication' $WARN "$($adTenants.Count) tenant(s) use Active Directory authentication (no longer available for new tenants in VBR 13): $names"
            } else {
                Add-Result 'Deprecated Features' 'Cloud Connect AD authentication' $PASS "No Cloud Connect tenants using Active Directory authentication"
            }
        }
    } catch {
        Add-Result 'Deprecated Features' 'Cloud Connect AD authentication' $INFO "Cloud Connect tenants endpoint not available or no CC license - skipping AD auth check ($($_.Exception.Message))"
        $ErrorLog.Add("[INFO] Test-DeprecatedFeatures (CC AD auth): $($_.Exception.Message)")
    }
}

# -- 16. Port 443 availability on VBR server -----------------------------------
function Test-Port443 {
    # For a 13.1 upgrade the server is already running VBR 13, which owns port 443.
    # The check only applies when migrating from VBR 12 where 443 may be free or occupied
    # by a different service that would conflict with the new VBR 13 REST listener.
    if ($TargetVersion -eq '13.1') {
        Add-Result 'VBR Server' 'Port 443 available for VBR 13' $INFO "Port 443 check skipped for VBR $TargetVersion upgrade  -  VBR 13 already holds port 443 (expected)"
        return
    }
    Write-Log "Checking if port 443 is available on ${VBRServer} for VBR 13 REST API..." -Level INFO
    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $ar  = $tcp.BeginConnect($VBRServer, 443, $null, $null)
        $connected = $ar.AsyncWaitHandle.WaitOne(3000, $false)
        if ($connected) {
            try { $tcp.EndConnect($ar) } catch { $connected = $false }
        }
        try { $tcp.Close() } catch {}

        if ($connected) {
            Add-Result 'VBR Server' 'Port 443 available for VBR 13' $WARN "Port 443 is already in use on ${VBRServer}. VBR 13 REST service requires port 443. Identify and stop the conflicting service before upgrading."
        } else {
            Add-Result 'VBR Server' 'Port 443 available for VBR 13' $PASS "Port 443 is not in use on ${VBRServer}  -  available for VBR 13 REST service"
        }
    } catch {
        Add-Result 'VBR Server' 'Port 443 available for VBR 13' $INFO "Could not determine port 443 status on ${VBRServer}  -  $($_.Exception.Message). Verify manually."
        $ErrorLog.Add("[INFO] Test-Port443: $($_.Exception.Message)")
    }
}

# -- 17. SQL Server version (on VBR server via WMI) ----------------------------
function Test-SQLServerVersion {
    Write-Log "Checking SQL Server version on ${VBRServer} via WMI..." -Level INFO
    try {
        $cimSession = New-VBRCimSession
        try {
            # Find running SQL Server engine services (default and named instances)
            $sqlSvcs = @(Get-CimInstance -CimSession $cimSession -ClassName Win32_Service `
                -Filter "Name LIKE 'MSSQL%'" -ErrorAction Stop |
                Where-Object { $_.Name -match '^(MSSQLSERVER$|MSSQL\$)' })
        } finally {
            Remove-CimSession $cimSession -ErrorAction SilentlyContinue
        }

        if ($sqlSvcs.Count -eq 0) {
            Add-Result 'VBR Server' 'SQL Server version' $INFO "No SQL Server instances found on ${VBRServer}. If VBR uses PostgreSQL, no SQL Server upgrade is needed."
            return
        }

        foreach ($svc in $sqlSvcs) {
            $instName = $svc.Name -replace '^MSSQL\$?', ''
            if ($instName -eq '') { $instName = 'MSSQLSERVER' }

            # Extract SQL major version from binary path: e.g. MSSQL13.VEEAMSQL2016 -> 13
            $sqlMajor = $null
            if ($svc.PathName -match 'MSSQL(\d+)\.') {
                $sqlMajor = [int]$Matches[1]
            }

            $sqlYear = switch ($sqlMajor) {
                11 { 'SQL Server 2012' }
                12 { 'SQL Server 2014' }
                13 { 'SQL Server 2016' }
                14 { 'SQL Server 2017' }
                15 { 'SQL Server 2019' }
                16 { 'SQL Server 2022' }
                default { "SQL Server (version $sqlMajor)" }
            }

            if ($sqlMajor -ne $null -and $sqlMajor -ge 13) {
                Add-Result 'VBR Server' "SQL Server version ($instName)" $PASS "$sqlYear  -  supported by VBR 13"
            } elseif ($sqlMajor -ne $null) {
                Add-Result 'VBR Server' "SQL Server version ($instName)" $FAIL "$sqlYear is NOT supported by VBR 13. Upgrade to SQL Server 2016 or later before upgrading VBR."
            } else {
                Add-Result 'VBR Server' "SQL Server version ($instName)" $WARN "Could not parse SQL Server version from path. Verify version is 2016+ before upgrading VBR."
            }
        }
    } catch {
        Add-Result 'VBR Server' 'SQL Server version check' $WARN "Could not query SQL Server services on ${VBRServer} via WMI  -  $($_.Exception.Message). Verify SQL Server version manually (2016+ required)."
        $ErrorLog.Add("[ERROR] Test-SQLServerVersion: $($_.Exception.Message)")
    }
}

# -- 18. PowerShell 7 installed (on VBR server via WMI) -----------------------
function Test-PowerShell7 {
    Write-Log "Checking for PowerShell 7 installation on ${VBRServer} via WMI..." -Level INFO
    try {
        $cimSession = New-VBRCimSession
        try {
            # Check standard install locations for PowerShell 7.x
            $pwshCandidates = @(
                'C:\\Program Files\\PowerShell\\7\\pwsh.exe',
                'C:\\Program Files\\PowerShell\\7.4\\pwsh.exe',
                'C:\\Program Files\\PowerShell\\7.5\\pwsh.exe'
            )
            $found     = $false
            $foundPath = ''
            foreach ($candidate in $pwshCandidates) {
                $fileObj = Get-CimInstance -CimSession $cimSession -ClassName CIM_DataFile `
                    -Filter "Name='$candidate'" -ErrorAction SilentlyContinue
                if ($fileObj) {
                    $found     = $true
                    $foundPath = $candidate -replace '\\\\', '\'
                    break
                }
            }
        } finally {
            Remove-CimSession $cimSession -ErrorAction SilentlyContinue
        }

        if ($found) {
            Add-Result 'VBR Server' 'PowerShell 7 installed' $PASS "PowerShell 7 found at $foundPath  -  required for Veeam PowerShell module in VBR 13"
        } else {
            Add-Result 'VBR Server' 'PowerShell 7 installed' $WARN "PowerShell 7 (pwsh.exe) not found in standard locations on ${VBRServer}. Required for Veeam PowerShell cmdlets post-upgrade. Download from https://aka.ms/install-powershell"
        }
    } catch {
        Add-Result 'VBR Server' 'PowerShell 7 check' $INFO "Could not check PowerShell 7 on ${VBRServer} via WMI  -  $($_.Exception.Message). Verify manually if using Veeam PowerShell automation."
        $ErrorLog.Add("[INFO] Test-PowerShell7: $($_.Exception.Message)")
    }
}

# -- 19 & 20. CPU and RAM hardware requirements (on VBR server via WMI) -------
function Test-HardwareRequirements {
    Write-Log "Checking CPU and RAM hardware requirements on ${VBRServer} via WMI..." -Level INFO

    # VBR 13 Windows-Based Backup Server minimums (per Veeam system requirements):
    #   CPU : 8 logical cores (vCPUs)
    #   RAM : 16 GB
    # Source: https://helpcenter.veeam.com/docs/vbr/userguide/system_requirements_backup_server.html?ver=13
    $cpuMin = 8
    $ramMin = 16

    try {
        $cimSession = New-VBRCimSession
        try {
            $cs = Get-CimInstance -CimSession $cimSession -ClassName Win32_ComputerSystem -ErrorAction Stop
        } finally {
            Remove-CimSession $cimSession -ErrorAction SilentlyContinue
        }

        # CPU  -  NumberOfLogicalProcessors reflects vCPUs on VMs, logical processors on physical
        $cpuCount = [int]$cs.NumberOfLogicalProcessors

        if ($cpuCount -ge $cpuMin) {
            Add-Result 'VBR Server' "CPU logical cores (minimum $cpuMin)" $PASS "$cpuCount logical core(s) detected  -  meets VBR 13 requirement"
        } else {
            Add-Result 'VBR Server' "CPU logical cores (minimum $cpuMin)" $FAIL "$cpuCount logical core(s) detected  -  VBR 13 requires $cpuMin cores minimum. Add CPU resources before upgrading."
        }

        # RAM
        $ramBytes = [long]$cs.TotalPhysicalMemory
        $ramGB    = [math]::Round($ramBytes / 1073741824, 1)

        if ($ramGB -ge $ramMin) {
            Add-Result 'VBR Server' "RAM (minimum ${ramMin} GB)" $PASS "${ramGB} GB RAM detected  -  meets VBR 13 requirement"
        } elseif ($ramGB -ge ($ramMin - 2)) {
            # Within 2 GB of minimum - possibly a rounding/reserved memory difference
            Add-Result 'VBR Server' "RAM (minimum ${ramMin} GB)" $WARN "${ramGB} GB RAM detected  -  marginally below ${ramMin} GB minimum. Verify available RAM before upgrading."
        } else {
            Add-Result 'VBR Server' "RAM (minimum ${ramMin} GB)" $FAIL "${ramGB} GB RAM detected  -  VBR 13 requires ${ramMin} GB minimum. Add RAM before upgrading."
        }

    } catch {
        Add-Result 'VBR Server' 'Hardware requirements (CPU/RAM)' $WARN "Could not query hardware specs on ${VBRServer} via WMI  -  $($_.Exception.Message). Verify manually: 8+ CPU cores and 16+ GB RAM required."
        $ErrorLog.Add("[ERROR] Test-HardwareRequirements: $($_.Exception.Message)")
    }
}

#endregion

#region -- Report Generation ---------------------------------------------------

function Get-StatusBadge {
    param([string]$Status)
    $color = switch ($Status) {
        'PASS'  { '#27ae60' }
        'WARN'  { '#f39c12' }
        'FAIL'  { '#e74c3c' }
        'INFO'  { '#2980b9' }
        'ERROR' { '#8e44ad' }
        default { '#7f8c8d' }
    }
    return "<span style='background:$color;color:#fff;padding:2px 8px;border-radius:4px;font-weight:bold;font-size:0.85em'>$Status</span>"
}

function Export-HTMLReport {
    $passCount  = @($Results | Where-Object { $_.Status -eq $PASS  }).Count
    $warnCount  = @($Results | Where-Object { $_.Status -eq $WARN  }).Count
    $failCount  = @($Results | Where-Object { $_.Status -eq $FAIL  }).Count
    $errorCount = @($Results | Where-Object { $_.Status -eq $ERROR_S }).Count
    $infoCount  = @($Results | Where-Object { $_.Status -eq $INFO  }).Count

    $overallStatus = if     ($failCount  -gt 0) { 'NOT READY  -  BLOCKERS FOUND' }
                     elseif ($errorCount -gt 0) { 'REVIEW REQUIRED  -  ERRORS ENCOUNTERED' }
                     elseif ($warnCount  -gt 0) { 'CONDITIONALLY READY  -  WARNINGS PRESENT' }
                     else                       { 'READY FOR UPGRADE' }

    $overallColor  = if     ($failCount  -gt 0) { '#e74c3c' }
                     elseif ($errorCount -gt 0) { '#8e44ad' }
                     elseif ($warnCount  -gt 0) { '#f39c12' }
                     else                       { '#27ae60' }

    $categories = $Results | Select-Object -ExpandProperty Category -Unique

    $tableRows = foreach ($cat in $categories) {
        $catResults = @($Results | Where-Object { $_.Category -eq $cat })
        $first = $true
        foreach ($r in $catResults) {
            $badge = Get-StatusBadge -Status $r.Status
            $rowClass = switch ($r.Status) {
                'FAIL'  { 'row-fail' }
                'WARN'  { 'row-warn' }
                'ERROR' { 'row-error' }
                default { '' }
            }
            if ($first) {
                "<tr class='$rowClass'><td class='cat-cell' rowspan='$($catResults.Count)'>$cat</td><td>$($r.CheckName)</td><td>$badge</td><td>$($r.Detail)</td></tr>"
                $first = $false
            } else {
                "<tr class='$rowClass'><td>$($r.CheckName)</td><td>$badge</td><td>$($r.Detail)</td></tr>"
            }
        }
    }

    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Veeam VBR $TargetVersion Pre-Upgrade Report</title>
<style>
  body { font-family: 'Segoe UI', Arial, sans-serif; background: #f0f2f5; margin: 0; padding: 20px; color: #2c3e50; }
  .container { max-width: 1100px; margin: auto; }
  .header { background: #1a2433; color: #fff; padding: 24px 32px; border-radius: 8px 8px 0 0; }
  .header h1 { margin: 0 0 4px 0; font-size: 1.6em; }
  .header p  { margin: 0; opacity: 0.7; font-size: 0.9em; }
  .summary { display: flex; gap: 12px; background: #fff; padding: 20px 32px; border-left: 1px solid #dde; border-right: 1px solid #dde; flex-wrap: wrap; align-items: center; }
  .overall { font-size: 1.3em; font-weight: bold; padding: 10px 20px; border-radius: 6px; color: #fff; background: $overallColor; }
  .stat { text-align: center; padding: 8px 16px; border-radius: 6px; background: #f8f9fa; min-width: 70px; }
  .stat .num { font-size: 1.6em; font-weight: bold; }
  .stat .lbl { font-size: 0.75em; text-transform: uppercase; opacity: 0.7; }
  table { width: 100%; border-collapse: collapse; background: #fff; border-radius: 0 0 8px 8px; box-shadow: 0 2px 8px rgba(0,0,0,0.08); }
  th { background: #1a2433; color: #fff; padding: 12px 16px; text-align: left; font-size: 0.9em; }
  td { padding: 10px 16px; border-bottom: 1px solid #ecf0f1; font-size: 0.88em; vertical-align: top; }
  .cat-cell { font-weight: 600; background: #f8fafc; color: #2c3e50; border-right: 3px solid #2980b9; white-space: nowrap; }
  .row-fail  { background: #fff5f5; }
  .row-warn  { background: #fffbf0; }
  .row-error { background: #fdf0ff; }
  tr:last-child td { border-bottom: none; }
  .footer { text-align: center; margin-top: 16px; font-size: 0.8em; opacity: 0.6; }
</style>
</head>
<body>
<div class="container">
  <div class="header">
    <h1>Veeam Backup &amp; Replication  -  Pre-Upgrade Readiness Report</h1>
    <p>Target: $VBRServer &nbsp;|&nbsp; Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') &nbsp;|&nbsp; Upgrade target: VBR $TargetVersion</p>
  </div>
  <div class="summary">
    <div class="overall">$overallStatus</div>
    <div class="stat"><div class="num" style="color:#27ae60">$passCount</div><div class="lbl">Pass</div></div>
    <div class="stat"><div class="num" style="color:#f39c12">$warnCount</div><div class="lbl">Warn</div></div>
    <div class="stat"><div class="num" style="color:#e74c3c">$failCount</div><div class="lbl">Fail</div></div>
    <div class="stat"><div class="num" style="color:#8e44ad">$errorCount</div><div class="lbl">Error</div></div>
    <div class="stat"><div class="num" style="color:#2980b9">$infoCount</div><div class="lbl">Info</div></div>
  </div>
  <table>
    <thead><tr><th width="160">Category</th><th>Check</th><th width="90">Status</th><th>Detail</th></tr></thead>
    <tbody>
      $($tableRows -join "`n      ")
    </tbody>
  </table>
  <div class="footer">Veeam VBR $TargetVersion Pre-Upgrade Check &nbsp;|&nbsp; Reference: helpcenter.veeam.com/docs/vbr/userguide/upgrade_vbr_byb.html?ver=13</div>
</div>
</body>
</html>
"@

    $html | Out-File -FilePath $ReportFile -Encoding UTF8 -Force
    Write-Log "HTML report saved to: $ReportFile" -Level INFO
}

function Export-ErrorLog {
    if ($ErrorLog.Count -gt 0) {
        $ErrorLog | Out-File -FilePath $ErrorLogFile -Encoding UTF8 -Force
        Write-Log "Error log saved to: $ErrorLogFile" -Level INFO
    } else {
        "No errors or failures recorded during pre-upgrade check run on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')." |
            Out-File -FilePath $ErrorLogFile -Encoding UTF8 -Force
        Write-Log "Error log (empty) saved to: $ErrorLogFile" -Level INFO
    }
}

#endregion

#region -- Main Execution ------------------------------------------------------

Write-Log "===== Veeam VBR Pre-Upgrade Readiness Check ============" -Level INFO
Write-Log "Target server  : $VBRServer"       -Level INFO
Write-Log "Upgrade target : VBR $TargetVersion" -Level INFO
Write-Log "API version    : $ApiVersion"       -Level INFO
Write-Log "API port       : $Port"             -Level INFO
Write-Log "Report path    : $ReportPath"       -Level INFO
Write-Log "========================================================" -Level INFO

# Prompt for credentials if not supplied
if (-not $Credential) {
    $Credential = Get-Credential -Message "Enter VBR administrator credentials for $VBRServer"
}

# Step 1  -  connectivity
$connected = Test-ServerConnectivity
if (-not $connected) {
    Write-Log "Cannot reach server. Skipping API-dependent checks." -Level FAIL
} else {
    # Step 2  -  authenticate
    $authenticated = Connect-VBRApi
    if (-not $authenticated) {
        Write-Log "Authentication failed. Skipping API-dependent checks." -Level FAIL
    } else {
        # API-dependent checks
        Test-VBRVersion
        Test-License
        Test-ConfigBackup
        Test-RunningJobs
        Test-ActiveSessions
        Test-Repositories
        Test-Proxies
        Test-ManagedServers
        Test-DeprecatedFeatures
    }
}

# VBR server checks via WMI  -  always run if server is reachable
Test-LocalOSVersion
Test-PendingReboot
Test-VeeamServices
Test-SystemDriveSpace
Test-Port443
Test-SQLServerVersion
Test-PowerShell7
Test-HardwareRequirements

# Logout cleanly
if ($AccessToken) {
    try {
        $headers = @{
            'Authorization' = "Bearer $AccessToken"
            'x-api-version' = $ApiVersion
        }
        $splat = @{
            Uri    = "https://${VBRServer}:${Port}/api/oauth2/logout"
            Method = 'POST'
            Headers = $headers
            UseBasicParsing = $true
        }
        if ($SkipCertCheck -and $PSVersionTable.PSVersion.Major -ge 7) {
            $splat['SkipCertificateCheck'] = $true
        }
        Invoke-WebRequest @splat | Out-Null
        Write-Log "Logged out from VBR REST API" -Level INFO
    } catch {
        Write-Log "Logout call failed (non-critical): $($_.Exception.Message)" -Level INFO
    }
}

# Reports
Export-HTMLReport
Export-ErrorLog

# Summary to console
$failCount  = @($Results | Where-Object { $_.Status -eq $FAIL  }).Count
$warnCount  = @($Results | Where-Object { $_.Status -eq $WARN  }).Count
$errorCount = @($Results | Where-Object { $_.Status -eq $ERROR_S }).Count

Write-Log "=====================================================" -Level INFO
Write-Log "RESULTS - PASS: $(@($Results | Where-Object {$_.Status -eq $PASS}).Count)  WARN: $warnCount  FAIL: $failCount  ERROR: $errorCount" -Level INFO
if   ($failCount  -gt 0) { Write-Log "OUTCOME: NOT READY - resolve FAIL items before upgrading" -Level FAIL }
elseif ($errorCount -gt 0) { Write-Log "OUTCOME: REVIEW REQUIRED - check ERROR items" -Level WARN }
elseif ($warnCount  -gt 0) { Write-Log "OUTCOME: CONDITIONALLY READY - review WARN items" -Level WARN }
else                       { Write-Log "OUTCOME: READY FOR UPGRADE" -Level PASS }
Write-Log "Report : $ReportFile"    -Level INFO
Write-Log "Errors : $ErrorLogFile"  -Level INFO
Write-Log "=====================================================" -Level INFO
