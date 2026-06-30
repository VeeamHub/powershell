<#
.SYNOPSIS
    Veeam Backup & Replication v13 Pre-Upgrade Readiness Check

.DESCRIPTION
    Connects to a VBR server via the REST API and validates all pre-upgrade
    requirements documented at:
    https://helpcenter.veeam.com/docs/vbr/userguide/upgrade_vbr_byb.html?ver=13

    Checks performed:
      1.  Server connectivity and API availability
      2.  Current VBR version (must be v11 or v12 to upgrade to v13)
      3.  License status and expiry
      4.  Configuration backup  -  enabled and recent (within 7 days)
      5.  Running backup/replication/copy jobs (must be zero)
      6.  Running restore sessions (must be zero)
      7.  Running SureBackup / SureLive sessions (must be zero)
      8.  Repository free space (warns below 10 GB, fails below 2 GB)
      9.  Backup proxy availability
      10. Managed Server Components (out of date)
      11. Local OS version (Windows Server 2019 or 2022 required for VBR 13)
      12. Pending Windows reboot check
      13. Veeam Windows services status
      14. System drive free disk space (>= 10 GB recommended for installer)
      15. Deprecated Features
	      - Reversed incremental backup mode
	      - Restore point-based retention
	      - Per-Machine backup disabled
	      - AD-based auth for Cloud Connect tenants 

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

    # REST API version of the installed VBR build (not the target version).
    # VBR 11 = 1.1-rev2 | VBR 12 = 1.2-rev0 (default) | VBR 13 = 1.3-rev1
    [Parameter(Mandatory = $false)]
    [string]$ApiVersion = '1.2-rev0'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

#region -- Initialisation ------------------------------------------------------

if (-not (Test-Path $ReportPath)) {
    New-Item -ItemType Directory -Path $ReportPath -Force | Out-Null
    Write-Host "[INFO] Created report directory: $ReportPath" -ForegroundColor Cyan
}

$RunTimestamp   = Get-Date -Format 'yyyyMMdd_HHmmss'
$ReportFile     = Join-Path $ReportPath "VBR13_PreUpgrade_Report_$RunTimestamp.html"
$ErrorLogFile   = Join-Path $ReportPath "VBR13_PreUpgrade_Errors_$RunTimestamp.log"
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
    Write-Log "Checking VBR server version..." -Level INFO
    try {
        $vbrInfo = Invoke-VBRApi -Endpoint '/serverInfo'
        $version = $vbrInfo.buildVersion
        Add-Result 'Version' 'VBR server version' $INFO "Installed version: $version"

        # Version must be 11.x or 12.x to support direct upgrade to 13
        if ($version -match '^(11|12)\.') {
            Add-Result 'Version' 'Version eligible for upgrade to v13' $PASS "Version $version supports direct upgrade to VBR 13"
        } elseif ($version -match '^13\.') {
            Add-Result 'Version' 'Version eligible for upgrade to v13' $WARN "Version $version appears to be VBR 13 already  -  upgrade may not be required"
        } else {
            Add-Result 'Version' 'Version eligible for upgrade to v13' $FAIL "Version $version is not directly upgradeable to VBR 13. Intermediate upgrade steps may be required."
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
                $lastRunRaw = [string]$cfg.lastSuccessfulBackup.lastSuccessfulTime
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
    try {
        $states  = Invoke-VBRApi -Endpoint '/jobs/states'
        $allJobs = @(if ($states.data) { $states.data } elseif ($states -is [array]) { $states } else { @() })
        # VBR 12 uses 'status'; VBR 13 uses 'state' - handle both
        $running = @($allJobs | Where-Object {
            ($_.PSObject.Properties['state']  -and $_.state  -in 'Running','Starting','Stopping','WaitingTape') -or
            ($_.PSObject.Properties['status'] -and $_.status -in 'Running','Starting','Stopping','WaitingTape')
        })

        if ($running.Count -eq 0) {
            Add-Result 'Active Jobs' 'No jobs currently running' $PASS "All backup/replication jobs are idle"
        } else {
            $names = ($running | ForEach-Object { if ($_.PSObject.Properties['name']) { $_.name } else { '(unnamed)' } }) -join ', '
            Add-Result 'Active Jobs' 'No jobs currently running' $FAIL "$($running.Count) job(s) are running: $names  -  stop all jobs before upgrading"
        }
    } catch {
        Add-Result 'Active Jobs' 'Running jobs check' $ERROR_S "Could not retrieve job states  -  $($_.Exception.Message)"
        $ErrorLog.Add("[ERROR] Test-RunningJobs: $($_.Exception.Message)")
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

# -- 11. Local OS version ------------------------------------------------------
function Test-LocalOSVersion {
    Write-Log "Checking local OS version..." -Level INFO
    try {
        $os       = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
        $caption  = $os.Caption
        $build    = $os.BuildNumber

        Add-Result 'Local Server' 'Operating system version' $INFO "$caption (Build $build)"

        # VBR 13 on Windows requires Windows Server 2019 (build 17763) or 2022 (build 20348)
        if ($build -ge 20348) {
            Add-Result 'Local Server' 'OS meets VBR 13 requirements' $PASS "Windows Server 2022  -  fully supported"
        } elseif ($build -ge 17763) {
            Add-Result 'Local Server' 'OS meets VBR 13 requirements' $PASS "Windows Server 2019  -  fully supported"
        } elseif ($build -ge 14393) {
            Add-Result 'Local Server' 'OS meets VBR 13 requirements' $WARN "Windows Server 2016  -  verify support with Veeam KB for VBR 13"
        } else {
            Add-Result 'Local Server' 'OS meets VBR 13 requirements' $FAIL "$caption is not supported for VBR 13. Upgrade to Windows Server 2019 or 2022."
        }
    } catch {
        Add-Result 'Local Server' 'OS version check' $ERROR_S "Could not query OS version  -  $($_.Exception.Message)"
        $ErrorLog.Add("[ERROR] Test-LocalOSVersion: $($_.Exception.Message)")
    }
}

# -- 12. Pending reboot --------------------------------------------------------
function Test-PendingReboot {
    Write-Log "Checking for pending Windows reboot..." -Level INFO
    $pendingReboot = $false
    $reasons       = @()

    try {
        # Windows Update pending reboot
        $wuKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
        if (Test-Path $wuKey) { $pendingReboot = $true; $reasons += 'Windows Update' }

        # Component Based Servicing
        $cbsKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'
        if (Test-Path $cbsKey) { $pendingReboot = $true; $reasons += 'Component Based Servicing' }

        # PendingFileRenameOperations
        $pfroKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager'
        $pfro    = Get-ItemProperty -Path $pfroKey -Name PendingFileRenameOperations -ErrorAction SilentlyContinue
        if ($pfro -and $pfro.PendingFileRenameOperations) { $pendingReboot = $true; $reasons += 'Pending File Rename' }

        if ($pendingReboot) {
            Add-Result 'Local Server' 'No pending Windows reboot' $FAIL "Server has a pending reboot: $($reasons -join ', '). Reboot and verify before upgrading."
        } else {
            Add-Result 'Local Server' 'No pending Windows reboot' $PASS "No pending reboot detected"
        }
    } catch {
        Add-Result 'Local Server' 'Pending reboot check' $ERROR_S "Could not check pending reboot  -  $($_.Exception.Message)"
        $ErrorLog.Add("[ERROR] Test-PendingReboot: $($_.Exception.Message)")
    }
}

# -- 13. Veeam Windows services ------------------------------------------------
function Test-VeeamServices {
    Write-Log "Checking Veeam Windows services..." -Level INFO
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
        $services    = Get-Service -ErrorAction Stop
        $veeamSvcs   = $services | Where-Object { $_.Name -in $veeamServices -and $_.StartType -ne 'Disabled' }
        $notRunning  = @($veeamSvcs | Where-Object { $_.Status -ne 'Running' })

        if ($notRunning.Count -eq 0) {
            Add-Result 'Local Server' 'Veeam services running' $PASS "All $($veeamSvcs.Count) Veeam service(s) are running"
        } else {
            $names = ($notRunning | ForEach-Object { "$($_.Name) [$($_.Status)]" }) -join ', '
            Add-Result 'Local Server' 'Veeam services running' $FAIL "$($notRunning.Count) Veeam service(s) are not running: $names"
        }
    } catch {
        Add-Result 'Local Server' 'Veeam services check' $ERROR_S "Could not query Windows services  -  $($_.Exception.Message)"
        $ErrorLog.Add("[ERROR] Test-VeeamServices: $($_.Exception.Message)")
    }
}

# -- 14. System drive free space -----------------------------------------------
function Test-SystemDriveSpace {
    Write-Log "Checking system drive free space..." -Level INFO
    try {
        $sysDrive = $env:SystemDrive
        $disk     = Get-PSDrive -Name $sysDrive.TrimEnd(':') -ErrorAction Stop
        $freeGB   = [math]::Round($disk.Free / 1GB, 1)

        if ($freeGB -ge 10) {
            Add-Result 'Local Server' "System drive free space ($sysDrive)" $PASS "${freeGB} GB free  -  sufficient for upgrade installer"
        } elseif ($freeGB -ge 5) {
            Add-Result 'Local Server' "System drive free space ($sysDrive)" $WARN "${freeGB} GB free  -  minimum met but additional space recommended (10 GB+)"
        } else {
            Add-Result 'Local Server' "System drive free space ($sysDrive)" $FAIL "${freeGB} GB free on $sysDrive  -  insufficient. At least 10 GB required for the upgrade installer."
        }
    } catch {
        Add-Result 'Local Server' 'System drive space check' $ERROR_S "Could not check disk space  -  $($_.Exception.Message)"
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
<title>Veeam VBR 13 Pre-Upgrade Report</title>
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
    <p>Target: $VBRServer &nbsp;|&nbsp; Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') &nbsp;|&nbsp; Checking readiness for upgrade to VBR 13</p>
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
  <div class="footer">Veeam VBR 13 Pre-Upgrade Check &nbsp;|&nbsp; Reference: helpcenter.veeam.com/docs/vbr/userguide/upgrade_vbr_byb.html?ver=13</div>
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

Write-Log "===== Veeam VBR 13 Pre-Upgrade Readiness Check =====" -Level INFO
Write-Log "Target server : $VBRServer" -Level INFO
Write-Log "API port      : $Port"      -Level INFO
Write-Log "Report path   : $ReportPath" -Level INFO
Write-Log "=====================================================" -Level INFO

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

# Local checks  -  always run regardless of API connectivity
Test-LocalOSVersion
Test-PendingReboot
Test-VeeamServices
Test-SystemDriveSpace

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
