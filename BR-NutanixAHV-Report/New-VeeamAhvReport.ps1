<#
.SYNOPSIS
    Builds a self-contained HTML report for Veeam Plug-in for Nutanix AHV: worker sizing and
    concurrency, job settings, and session history with API rate-limit analysis.

.DESCRIPTION
    Everything in this report comes from the Veeam Plug-in for Nutanix AHV REST API (v10)
    exposed through the VBR server, so the scope is inherently AHV-only.

      Auth      : POST https://<VbrServer>:9419/api/oauth2/token   (x-api-version 1.3-rev1)
      Base      : https://<VbrServer>/extension/799a5a3e-ae1e-4eaf-86eb-8a9acc2670e2/api/v10
      Endpoints : /clusters  /workers  /jobs  /sessions  /sessions/{id}

    Report sections:
      1. Summary            - worker count, total concurrent tasks, job and session totals
      2. Rate-limit analysis- sessions hit by TooManyRequests / API rate limit exceeded
      3. Workers            - maxConcurrentTasks, vCPU, memory, cluster, status, host affinity
      4. Jobs               - schedule, retention, GFS, active/synthetic full, retries, repo
      5. Sessions           - per-session result, duration, throughput, failure reason
      6. Per-job rollup     - success / warning / failure counts over the window

    Session detail (/sessions/{id}) is fetched only for sessions that did not succeed, which
    is where the rate-limit event messages live. That keeps the number of API calls bounded.

.PARAMETER VbrServer
    FQDN or IP of the Veeam Backup & Replication server.

.PARAMETER DaysBack
    How far back to pull session history. Default 7.

.PARAMETER OutputPath
    Where to write the HTML file. Defaults to .\VeeamAhvReport_<server>_<timestamp>.html

.PARAMETER DeepScanAllSessions
    Fetch full detail for every session, not just non-successful ones. Slower, but catches
    rate-limit warnings inside sessions that still reported Success.

.PARAMETER ExportCsv
    Also write the session data to a CSV next to the HTML report
    (<report name>_sessions.csv). Includes every collected field, including raw byte counts
    and duration in minutes, which the HTML table does not show. The HTML report also has a
    Download CSV button on the Session detail section, which exports the table as shown.

.PARAMETER IncludeRescans
    Include infrastructure rescan sessions in the report. By default they are left out of
    every count, table and the CSV, because the plug-in rescans every few minutes and they
    can outnumber backup sessions hundreds to one. The report always states how many were
    hidden and how many of those failed. Use this switch when investigating API rate
    limits or Prism connectivity, where rescans are part of the picture.

.PARAMETER BackupTypePattern
    Optional. Regex matched against sessionType to identify backup sessions. Used to pick
    the per-VM runs for window sizing, and to make sure a backup job is never mistaken for
    a rescan. Default: backup. Only change it if your plug-in reports backup sessions under
    a different type.

.PARAMETER RescanPattern
    Optional. Regex identifying rescan sessions. Matched against the session's jobName / name, but
    only for sessions whose sessionType is not a backup type, so a backup job with
    "rescan" in its name is never treated as a rescan. Default: ^Rescan
    (matches "Rescan cluster <name>" and "Rescanning the infrastructure", which the plug-in
    logs with sessionType Internal).

    Successful rescans are never deep-scanned, even with -DeepScanAllSessions: they carry
    no bottleneck, throughput or per-VM data, and on a busy plug-in they can be 99% of all
    sessions. Failed rescans are still scanned so their error text appears.

.EXAMPLE
    .\New-VeeamAhvReport.ps1 -VbrServer vbr01.example.local -SkipCertificateCheck

    VBR v13 / AHV plug-in v8 or later. Prompts for VBR administrator credentials.

.EXAMPLE
    .\New-VeeamAhvReport.ps1 -VbrServer vbr12.example.local -ApplianceServer 192.0.2.40 -SkipCertificateCheck

    VBR 12.x / AHV plug-in v7 or earlier. Prompts for the AHV BACKUP APPLIANCE account,
    not a VBR account. Find the appliance address in the VBR console under
    Backup Infrastructure - Nutanix AHV.

.EXAMPLE
    .\New-VeeamAhvReport.ps1 -VbrServer vbr01.example.local -DaysBack 30 -DeepScanAllSessions -Show

.NOTES
    Script  : New-VeeamAhvReport.ps1
    Version : 1.9.4
    Updated : 2026-10-21
    Author  : Jason Berry
    Assisted: Written with assistance from Claude (Anthropic). Reviewed and tested by
              the author.
    Requires: PowerShell 5.1 or 7.x. Read-only - makes no changes to the environment.
    Tested  : VBR v13 (AHV plug-in v9, v10). VBR 12.x support added in 1.3.0 via
              -ApplianceServer.

    VERSION HISTORY
    ---------------
    1.9.4  2026-10-21  API error text now includes the plug-in's traceId, which identifies
                       the matching exception in the plug-in logs on the VBR server.

    1.9.3  2026-10-21  Session detail failures are now visible. A lab run showed
                       GET /sessions/{id} returning HTTP 500 for a BackupVmJob session,
                       which silently left VM, throughput and bottleneck data empty.
                       - Failed detail calls are retried once on 5xx, then reported: a
                         console warning, a note in Session detail, and the error in the
                         row's Reason column (also DetailError in the CSV / output).
                       - The plug-in's problem+json title/detail is captured for errors.
                       - Host lookup uses only the documented /clusters/{id}/hosts and
                         runs only when a worker has affinity enabled (the undocumented
                         /hosts call returned 404).

    1.9.2  2026-10-21  Fails fast on connection problems. The server name is checked in DNS
                       before the credential prompt, and authentication stops at the first
                       attempt that gets no HTTP response (DNS, refused, timeout, TLS)
                       instead of retrying every x-api-version.

    1.9.1  2026-10-21  Prepared for VeeamHub publication: lab host names in examples
                       replaced with example.local / documentation IPs, and the
                       worker-consistency note no longer refers to a script that is not
                       part of this repository. No functional change.

    1.9.0  2026-10-13  Parameter clean-up.
                       - Rescan sessions are now hidden by default. -IgnoreRescans is
                         replaced by -IncludeRescans. The report still states how many
                         were hidden and how many failed.
                       - Removed -NonBackupTypePattern; rescans report as 'Internal', so it
                         had nothing left to catch.
                       - -BackupTypePattern and -RescanPattern stay as optional overrides
                         with working defaults.

    1.8.2  2026-10-13  Plain-language explanation of median, mean, P90, P95 and max in the
                       per-VM duration section, using the run's own figures, plus a
                       small-sample warning when fewer than 20 VM runs were measured.

    1.8.1  2026-10-13  Rescan handling fixed after a run where 1,384 of 1,388 sessions were
                       rescans and -DeepScanAllSessions spent 295 of 300 s fetching them.
                       - Rescans use sessionType 'Internal' with the text in jobName, so
                         the 1.6.0 detection never matched. -RescanPattern now defaults to
                         ^Rescan against the name, for non-backup session types only.
                       - Successful rescans are no longer deep-scanned (no useful data).
                       - Console reports how many sessions are rescans.

    1.8.0  2026-10-13  Fixed the per-VM window-sizing maths.
                       - Only backup sessions count (-BackupTypePattern /
                         -NonBackupTypePattern). Previously any child session with an
                         objectName was used, including restores and retention.
                       - Only Success / Warning runs count; fast failures skewed the mean.
                       - The projection now uses DISTINCT VMs. It used every VM run in the
                         reporting window, so a 7-day window overstated it about 7x.
                       - Shows distinct VMs and run count separately, the P90 projection,
                         the slowest-VM floor, and what was excluded and why.
                       - Removed unused $budget / $breakEven values.

    1.7.1  2026-10-13  Run-time diagnostics. Prints elapsed time per phase plus API call
                       count, failures, average and slowest call at the end (also returned
                       as Timings / ApiStats). -Verbose logs every GET with its duration.
                       Suppresses the per-call web progress bar on Windows PowerShell 5.1.
                       Host lookups now run only when a worker has affinity configured, and
                       the per-cluster fallback only when /hosts returned nothing.

    1.7.0  2026-10-09  Collapsible sections and CSV export. Every section can be expanded
                       or collapsed (Expand all / Collapse all at the top); Session detail
                       starts collapsed. Collapsed sections open automatically for
                       printing. Added a Download CSV button on Session detail and an
                       -ExportCsv switch that writes <report>_sessions.csv with every
                       collected session field.

    1.6.0  2026-10-09  Added -IgnoreRescans and -RescanPattern. Infrastructure rescan
                       sessions are removed before detail is fetched (fewer API calls) and
                       excluded from all counts. The report shows how many were excluded
                       and how many of those failed, so rescan problems stay visible.

    1.5.1  2026-10-09  Failed count now includes sessions with result 'Error'. The AHV
                       API reports failures as Error, but the summary card, per-job
                       rollup and row highlighting only matched 'Failed', so failed
                       sessions were shown in the table but not counted.

    1.5.0  2026-10-07  Worker host affinity. The Workers table now shows whether host
                       affinity is configured and which AHV host(s) the worker is pinned
                       to. Host IDs are resolved to names from the clusters response,
                       /hosts, and /clusters/{id}/hosts where the plug-in build exposes
                       them; unresolved IDs are shown as-is. The affinity block is read
                       defensively (affinitySettings / hostAffinity / affinity, and
                       hostId / hostIds / hosts / hostUuid / nodeId variants) because the
                       property names differ across plug-in versions. Run with -Verbose
                       to dump the raw affinity JSON for any worker whose host could not
                       be read.

    1.4.0  2026-09-30  Bottleneck capture and per-VM duration statistics.

                       The AHV session schema has NO bottleneck field - progressState
                       carries events, transferred, read, processed, progressPercents,
                       processingRate, avgProcessingRate, objectsCount and
                       objectsProcessed, and nothing else. VBR emits the bottleneck line
                       ("Source 99% > Proxy 100% > Network 0% > Target 10%") as a session
                       EVENT MESSAGE, so it has to be parsed out of the event text.

                       Fixed the filter bug that made this impossible: event messages were
                       only collected at Error and Warning severity, which discarded the
                       bottleneck line because it is emitted at Info. Messages are now
                       gathered at every severity for scanning, while the Reason column
                       still shows only Error/Warning text.

                       Added per-VM duration statistics - min, median, mean, P90, P95, max
                       - taken from child sessions, which are identified by a populated
                       context.objectName. This is the measurement the backup-window model
                       depends on, and the report now produces it directly along with an
                       elapsed-time projection against the configured concurrency.

                       Also captured, all previously discarded: context.objectName (so
                       per-VM sessions are identifiable by VM), context.backupMode,
                       parentSessionId, and progressState.read.value - the read figure
                       gives source-side throughput and, against transferred, the
                       compression ratio.

                       Note: bottleneck and per-VM rows only appear for sessions whose
                       detail was fetched. Use -DeepScanAllSessions to cover successful
                       sessions, which is where most bottleneck lines live.

    1.3.0  2026-09-15  VBR 12.x support.

                       Two problems, both hit on a VBR 12.3 server.

                       (a) HTTP 400 at login. The x-api-version header is version-specific
                           and a wrong value is rejected outright: VBR 13 = 1.3-rev1,
                           12.3 = 1.2-rev1, 12.2 = 1.2-rev0, 12.1 = 1.1-rev1,
                           12.0 = 1.1-rev0. The script hardcoded 1.3-rev1. It now negotiates,
                           trying each in turn and stopping early on 401 (credentials wrong,
                           so other versions will not help).

                       (b) Different architecture. The /extension/<guid>/ path only exists
                           from AHV plug-in v8 / VBR v13. On 12.x the plug-in is v7 or
                           earlier and its API lives on the separate AHV BACKUP APPLIANCE
                           VM: base https://<appliance>/api/v7, no version header, auth
                           body uses camelCase (grantType=Password&userName=&password=),
                           the token comes back as accessToken not access_token, and the
                           account is local to the appliance rather than a VBR account.
                           Added -ApplianceServer to select this mode.

                       Also: repository names now resolve per mode (main VBR API vs the
                       appliance's own backupServers/repositories), and the session query
                       falls back to fetching all sessions and windowing client-side if a
                       build rejects the from= filter.

    1.2.1  2026-09-10  Add-Type for the PS 5.1 certificate policy is now guarded by a type
                       existence test. Re-running in the same session threw
                       TYPE_ALREADY_EXISTS, which -ErrorAction cannot suppress. All four
                       scripts now share one type name, VeeamAhvCertPolicy.

    1.2.0  2026-09-10  Null-safe collection handling. Added Get-ResultArray (normalises
                       paged {results:[]} objects, bare arrays and $null, stripping null
                       elements) and Get-PropValue (property read that does not throw on a
                       null object or a missing property). Fixes "Cannot index into a null
                       array" raised by the cluster-name lookup on v9.
                       Report footer now states the detected API version and base URL
                       instead of hardcoding v10.
                       Verified every field read against the v9 schema: only
                       periodic.startTimeWithinAnHour and periodic.backupWindow are v10-only,
                       and neither is used.

    1.1.0  2026-09-10  Auto-discovers the AHV extension base URL after authentication,
                       probing ports 443 and 9419 across API v10/v9/v8, and fails with a
                       diagnostic list of what was tried. Previously hardcoded v10 on 443,
                       which 404'd on servers running plug-in v9.
                       Fixed phantom session: @($null) returns a one-element array holding
                       $null, so a failed sessions call reported one "(no job name)" session.

    1.0.1  2026-09-09  Write-Progress -Status rejects null or empty; sessions without a
                       jobName (snapshot, retention, infrastructure) crashed the detail
                       loop. Falls back to session name, then a positional label.

    1.0.0  2026-09-09  Initial release. Self-contained HTML report covering worker
                       concurrency and sizing, job settings, session history, per-job
                       rollup, and TooManyRequests / API rate-limit analysis.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$VbrServer,

    # VBR 12.x / AHV plug-in v7 and earlier only. The AHV backup appliance is a separate VM
    # that hosts its own API and its own local accounts. Supply its address here and -Credential
    # becomes the APPLIANCE account, not a VBR account. Leave empty for VBR v13 / plug-in v8+.
    [Parameter()]
    [string]$ApplianceServer,

    [Parameter()]
    [System.Management.Automation.PSCredential]$Credential,

    [Parameter()]
    [ValidateRange(1, 365)]
    [int]$DaysBack = 7,

    [Parameter()]
    [string]$OutputPath,

    [Parameter()]
    [int]$RestPort = 9419,

    [Parameter()]
    [switch]$DeepScanAllSessions,

    [Parameter()]
    [switch]$ExportCsv,

    [Parameter()]
    [string]$BackupTypePattern = 'backup',

    [Parameter()]
    [switch]$IncludeRescans,

    [Parameter()]
    [string]$RescanPattern = '^Rescan',

    [Parameter()]
    [switch]$Show,

    [Parameter()]
    [switch]$SkipCertificateCheck
)

$ErrorActionPreference = 'Stop'

# Phase timings, printed at the end so slow runs can be pinned to a stage.
$script:RunTimer   = [System.Diagnostics.Stopwatch]::StartNew()
$script:PhaseTimes = New-Object System.Collections.Generic.List[object]
$script:PhaseName  = $null
$script:PhaseStart = [timespan]::Zero
function Step-Phase {
    param([string]$Name)
    $now = $script:RunTimer.Elapsed
    if ($script:PhaseName) {
        $script:PhaseTimes.Add([pscustomobject]@{ Phase = $script:PhaseName; Seconds = [math]::Round(($now - $script:PhaseStart).TotalSeconds, 1) })
    }
    $script:PhaseName  = $Name
    $script:PhaseStart = $now
}

# Bumped with every change - see VERSION HISTORY in the help block above.
$ScriptVersion = '1.9.4'
Write-Host "New-VeeamAhvReport.ps1 v$ScriptVersion" -ForegroundColor DarkGray

# --- Constants -------------------------------------------------------------
$AhvExtensionId = '799a5a3e-ae1e-4eaf-86eb-8a9acc2670e2'
$AhvApiVersion  = 'v10'
$VbrApiVersion  = '1.3-rev1'

$AuthUri = "https://${VbrServer}:${RestPort}/api/oauth2/token"
$VbrBase = "https://${VbrServer}:${RestPort}/api/v1"
# $AhvBase is discovered after authentication - see Resolve-AhvBase below. The documented
# path is https://<host>/extension/<guid>/api/v10, but the port and API version vary with
# how VBR was deployed and which plug-in build is installed.
$AhvBase = $null

# Patterns that indicate Nutanix API throttling
$RateLimitPattern = 'TooManyRequests|rate limit|429\b|too many requests'

# Check the server name resolves before prompting for credentials or trying API versions.
# A typo otherwise surfaces only after five failed logins with a blank status table.
foreach ($srv in @($VbrServer, $ApplianceServer) | Where-Object { $_ }) {
    $ip = $null
    if ([System.Net.IPAddress]::TryParse($srv, [ref]$ip)) { continue }
    try   { $null = [System.Net.Dns]::GetHostAddresses($srv) }
    catch { throw "Cannot resolve '$srv' in DNS. Check the server name (FQDN or IP) and that this machine can reach your DNS server." }
}

if (-not $Credential) {
    $prompt = if ($ApplianceServer) {
        "AHV BACKUP APPLIANCE credentials for $ApplianceServer (an appliance-local account, not a VBR account)"
    } else {
        "VBR administrator credentials for $VbrServer"
    }
    $Credential = Get-Credential -Message $prompt
}

if (-not $OutputPath) {
    $stamp      = Get-Date -Format 'yyyyMMdd-HHmmss'
    $safeServer = ($VbrServer -split '\.')[0]
    $OutputPath = Join-Path (Get-Location) "VeeamAhvReport_${safeServer}_${stamp}.html"
}

# --- Certificate handling --------------------------------------------------
$irmExtra = @{}
if ($SkipCertificateCheck) {
    if ($PSVersionTable.PSVersion.Major -ge 6) {
        $irmExtra['SkipCertificateCheck'] = $true
    }
    else {
        # Windows PowerShell 5.1. The type persists for the life of the session, so adding it
        # a second time throws TYPE_ALREADY_EXISTS - which -ErrorAction cannot suppress.
        # Test for it instead of trying to swallow the error.
        if (-not ('VeeamAhvCertPolicy' -as [type])) {
            Add-Type -TypeDefinition @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class VeeamAhvCertPolicy : ICertificatePolicy {
    public bool CheckValidationResult(ServicePoint sp, X509Certificate cert, WebRequest req, int problem) { return true; }
}
"@
        }
        [System.Net.ServicePointManager]::CertificatePolicy = New-Object VeeamAhvCertPolicy
    }
}
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

# --- Helpers ---------------------------------------------------------------
function ConvertTo-HtmlText {
    param([AllowNull()][string]$Text)
    if ([string]::IsNullOrEmpty($Text)) { return '' }
    $Text.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;').Replace('"', '&quot;')
}

function Get-LocalTimeString {
    param([AllowNull()]$Utc)
    if (-not $Utc) { return '-' }
    try { ([datetime]$Utc).ToLocalTime().ToString('yyyy-MM-dd HH:mm:ss') } catch { '-' }
}

function Get-DurationString {
    param([AllowNull()]$StartUtc, [AllowNull()]$FinishUtc)
    if (-not $StartUtc -or -not $FinishUtc) { return '-' }
    try {
        $span = ([datetime]$FinishUtc) - ([datetime]$StartUtc)
        if ($span.TotalSeconds -lt 0) { return '-' }
        '{0:00}:{1:00}:{2:00}' -f [int]$span.TotalHours, $span.Minutes, $span.Seconds
    }
    catch { '-' }
}

function Get-DurationMinutes {
    # Numeric duration for statistics. Returns $null when it cannot be computed, so
    # unfinished or malformed sessions drop out of percentile maths rather than skewing it.
    param([AllowNull()]$StartUtc, [AllowNull()]$FinishUtc)
    if (-not $StartUtc -or -not $FinishUtc) { return $null }
    try {
        $span = ([datetime]$FinishUtc) - ([datetime]$StartUtc)
        if ($span.TotalMinutes -lt 0) { return $null }
        [math]::Round($span.TotalMinutes, 2)
    }
    catch { $null }
}

function Get-BottleneckInfo {
    <#
      The AHV session schema has no bottleneck field. VBR emits the bottleneck line as a
      session event message instead, so it has to be parsed out of the event text.
      Two formats are handled:
        "Load: Source 99% > Proxy 100% > Network 0% > Target 10%"
        "Primary bottleneck: Source"
      Returns the stage with the highest load, plus the raw line for the report.
    #>
    param([AllowNull()][string]$Text)

    $out = [pscustomobject]@{ Stage = ''; Primary = ''; Detail = '' }
    if ([string]::IsNullOrEmpty($Text)) { return $out }

    if ($Text -match 'Source\s+(\d+)\s*%.*?Proxy\s+(\d+)\s*%.*?Network\s+(\d+)\s*%.*?Target\s+(\d+)\s*%') {
        $vals = [ordered]@{
            Source  = [int]$Matches[1]
            Proxy   = [int]$Matches[2]
            Network = [int]$Matches[3]
            Target  = [int]$Matches[4]
        }
        $top = ($vals.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 1)
        $out.Stage   = [string]$top.Key
        $out.Primary = "$($top.Key) $($top.Value)%"
        $out.Detail  = ($vals.GetEnumerator() | ForEach-Object { "$($_.Key) $($_.Value)%" }) -join ' > '
        return $out
    }

    if ($Text -match '[Bb]ottleneck[:\s]+([A-Za-z]+)') {
        $out.Stage   = $Matches[1]
        $out.Primary = $Matches[1]
        $out.Detail  = $Matches[0]
    }

    $out
}

function Get-Percentile {
    # Nearest-rank percentile on a pre-sorted numeric array. Kept simple deliberately -
    # PowerShell 5.1 has no built-in and interpolation buys nothing for this purpose.
    param([double[]]$Sorted, [double]$P)
    if (-not $Sorted -or $Sorted.Count -eq 0) { return $null }
    $idx = [math]::Ceiling(($P / 100) * $Sorted.Count) - 1
    if ($idx -lt 0) { $idx = 0 }
    if ($idx -ge $Sorted.Count) { $idx = $Sorted.Count - 1 }
    $Sorted[$idx]
}

function Get-HttpStatus {
    # Defined up here because the authentication routines below call it, and PowerShell
    # resolves functions at call time - it must exist before the auth block runs.
    param($ErrorRecord)
    if ($ErrorRecord.Exception.Response) {
        try { return [int]$ErrorRecord.Exception.Response.StatusCode } catch { }
    }
    $null
}

function Format-Bytes {
    param([AllowNull()]$Bytes)
    if (-not $Bytes -or $Bytes -le 0) { return '-' }
    $units = 'B', 'KB', 'MB', 'GB', 'TB', 'PB'
    $i = 0; $v = [double]$Bytes
    while ($v -ge 1024 -and $i -lt $units.Count - 1) { $v /= 1024; $i++ }
    '{0:N2} {1}' -f $v, $units[$i]
}

function Get-ScheduleSummary {
    param($Schedule)
    if (-not $Schedule) { return 'Not configured' }
    if (-not $Schedule.enabled) { return 'Disabled' }

    switch ($Schedule.type) {
        'Daily' {
            $d = $Schedule.weekly
            $days = if ($d.configuredDays -and $d.configuredDays -ne 'None') { $d.configuredDays } else { ($d.selectedDays -join ', ') }
            "Daily at $($d.startTime) ($days)"
        }
        'Monthly' {
            $m = $Schedule.monthly
            "Monthly at $($m.startTime) - $($m.configuredWeekOrDay) $($m.dayOfWeek)"
        }
        'Periodic' {
            $p = $Schedule.periodic
            "Every $($p.interval) $($p.mode)"
        }
        default {
            if ($Schedule.weekly -and $Schedule.weekly.startTime) { "$($Schedule.type) at $($Schedule.weekly.startTime)" }
            else { [string]$Schedule.type }
        }
    }
}

function Get-RetentionSummary {
    param($Retention)
    if (-not $Retention) { return '-' }
    switch ($Retention.type) {
        'RestorePoints' { "$($Retention.restorePointsToKeep) restore points" }
        'Days'          { "$($Retention.daysToKeep) days" }
        default {
            if ($Retention.restorePointsToKeep -gt 0) { "$($Retention.restorePointsToKeep) restore points" }
            elseif ($Retention.daysToKeep -gt 0)      { "$($Retention.daysToKeep) days" }
            else { [string]$Retention.type }
        }
    }
}

function Get-GfsSummary {
    param($Gfs)
    if (-not $Gfs -or -not $Gfs.enabled) { return 'Off' }
    $parts = @()
    if ($Gfs.weekly.enabled)  { $parts += "W:$($Gfs.weekly.weeklyRetention)" }
    if ($Gfs.monthly.enabled) { $parts += "M:$($Gfs.monthly.monthlyRetention)" }
    if ($Gfs.yearly.enabled)  { $parts += "Y:$($Gfs.yearly.yearlyRetention)" }
    if ($parts.Count -eq 0) { 'On' } else { $parts -join ' / ' }
}

function Get-ToggleSummary {
    param($Setting)
    if (-not $Setting) { return 'Off' }
    if (-not $Setting.enabled) { return 'Off' }
    $t = if ($Setting.type) { $Setting.type } else { 'On' }
    if ($Setting.weekly -and $Setting.weekly.startTime) { "$t @ $($Setting.weekly.startTime)" } else { [string]$t }
}

# --- 1. Authenticate -------------------------------------------------------
Step-Phase 'Authenticate'
#
# There are two completely different architectures to deal with:
#
#   Mode A - VBR-hosted (AHV plug-in v8, v9, v10 / VBR v13)
#            Auth : POST https://<vbr>:9419/api/oauth2/token
#                   header x-api-version, body grant_type=password&username=&password=
#                   response field access_token
#            Base : https://<vbr>/extension/<guid>/api/vN
#            Creds: VBR backup administrator
#
#   Mode B - Appliance-hosted (AHV plug-in v7 and earlier / VBR 12.x)
#            Auth : POST https://<appliance>/api/oauth2/token
#                   NO version header, body grantType=Password&userName=&password=
#                   response field accessToken  (camelCase throughout)
#            Base : https://<appliance>/api/v7      (no /extension/ segment)
#            Creds: a local account on the AHV backup appliance, NOT a VBR account
#
# The x-api-version value is also version-specific and a wrong one returns HTTP 400:
#   VBR 13 = 1.3-rev1, 12.3 = 1.2-rev1, 12.2 = 1.2-rev0, 12.1 = 1.1-rev1, 12.0 = 1.1-rev0

$VbrApiVersionCandidates = @('1.3-rev1', '1.2-rev1', '1.2-rev0', '1.1-rev1', '1.1-rev0')

function Connect-ApplianceMode {
    param([string]$Server, [System.Management.Automation.PSCredential]$Cred)

    $uri = "https://$Server/api/oauth2/token"
    Write-Host "Connecting to AHV backup appliance $Server (plug-in v7 style) ..." -ForegroundColor Cyan

    try {
        $t = Invoke-RestMethod -Method Post -Uri $uri `
                -Body @{
                    grantType = 'Password'
                    userName  = $Cred.UserName
                    password  = $Cred.GetNetworkCredential().Password
                } `
                -ContentType 'application/x-www-form-urlencoded' @irmExtra
    }
    catch {
        throw "Authentication to appliance $Server failed: $($_.Exception.Message)`n" +
              "Note this must be an account local to the AHV backup appliance, not a VBR account."
    }

    # v7 returns accessToken; be tolerant in case a build returns access_token.
    $access = if ($t.accessToken) { $t.accessToken } else { $t.access_token }
    if (-not $access) { throw "Appliance returned no access token." }

    @{
        Headers = @{ Authorization = "Bearer $access"; Accept = 'application/json' }
        BaseUrl = "https://$Server/api/v7"
        Mode    = 'Appliance'
    }
}

function Connect-VbrMode {
    param([string]$Server, [int]$Port, [System.Management.Automation.PSCredential]$Cred)

    $uri      = "https://${Server}:${Port}/api/oauth2/token"
    $lastErr  = $null
    $attempts = New-Object System.Collections.Generic.List[object]

    foreach ($apiVer in $VbrApiVersionCandidates) {
        try {
            $t = Invoke-RestMethod -Method Post -Uri $uri `
                    -Headers @{ 'x-api-version' = $apiVer } `
                    -Body @{
                        grant_type = 'password'
                        username   = $Cred.UserName
                        password   = $Cred.GetNetworkCredential().Password
                    } `
                    -ContentType 'application/x-www-form-urlencoded' @irmExtra

            Write-Host "  Authenticated (x-api-version $apiVer)" -ForegroundColor Green
            return @{
                Headers = @{
                    Authorization   = "Bearer $($t.access_token)"
                    'x-api-version' = $apiVer
                    Accept          = 'application/json'
                }
                ApiVersion = $apiVer
                Mode       = 'Vbr'
            }
        }
        catch {
            $code = Get-HttpStatus $_
            $attempts.Add([pscustomobject]@{ ApiVersion = $apiVer; Status = $code })
            $lastErr = $_

            # 401 means the header was accepted but the credentials were not - trying
            # other versions will not help.
            if ($code -eq 401) {
                throw "Authentication to $Server failed: credentials rejected (401)."
            }
            # No HTTP status means the request never got an answer (DNS, refused
            # connection, timeout, TLS). A different x-api-version will not help.
            if ($null -eq $code) {
                throw "Could not connect to ${Server}:${Port}: $($_.Exception.Message)"
            }
        }
    }

    Write-Host ""
    Write-Host "x-api-version negotiation results:" -ForegroundColor Yellow
    $attempts | Format-Table ApiVersion, Status -AutoSize | Out-String | Write-Host

    throw "Could not authenticate to $Server on port $Port. Last error: $($lastErr.Exception.Message)"
}

if ($ApplianceServer) {
    $conn    = Connect-ApplianceMode -Server $ApplianceServer -Cred $Credential
    $headers = $conn.Headers
    $AhvBase = $conn.BaseUrl
    $ConnMode = 'Appliance'
    Write-Host "  AHV API at $AhvBase" -ForegroundColor Green
}
else {
    Write-Host "Connecting to $VbrServer ..." -ForegroundColor Cyan
    $conn    = Connect-VbrMode -Server $VbrServer -Port $RestPort -Cred $Credential
    $headers = $conn.Headers
    $ConnMode = 'Vbr'
}

$script:ApiStats = [pscustomobject]@{ Calls = 0; Failed = 0; TotalMs = 0.0; SlowestMs = 0.0; SlowestPath = '' }
$script:LastApiError = $null   # { Status; Detail } of the most recent failed GET

function Invoke-AhvGet {
    param([string]$Path, [switch]$Quiet)
    # Windows PowerShell 5.1 draws a progress bar for every web call, which slows each one
    # noticeably. Suppress it for this call only (function scope).
    $ProgressPreference = 'SilentlyContinue'
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $script:LastApiError = $null
    try {
        Invoke-RestMethod -Method Get -Uri "$AhvBase/$Path" -Headers $headers @irmExtra
    }
    catch {
        $script:ApiStats.Failed++
        # The plug-in returns application/problem+json; its title/detail explain the error.
        $err    = $_   # keep it: $_ is reassigned inside the nested pipeline and catch below
        $status = Get-HttpStatus $err
        $detail = $null
        if ($err.ErrorDetails -and $err.ErrorDetails.Message) {
            try {
                $pj = $err.ErrorDetails.Message | ConvertFrom-Json
                $detail = (@($pj.title, $pj.detail) | Where-Object { $_ }) -join ': '
                # traceId lets support find the matching exception in the plug-in logs.
                if ($pj.traceId) { $detail += " (traceId $($pj.traceId))" }
            }
            catch { $detail = [string]$err.ErrorDetails.Message }
        }
        if (-not $detail) { $detail = $err.Exception.Message }
        $script:LastApiError = [pscustomobject]@{ Status = $status; Detail = $detail }
        if (-not $Quiet) { Write-Warning "GET $Path failed: $detail" }
        Write-Verbose ("GET {0} failed: HTTP {1} - {2}" -f $Path, $status, $detail)
        $null
    }
    finally {
        $sw.Stop()
        $ms = $sw.Elapsed.TotalMilliseconds
        $script:ApiStats.Calls++
        $script:ApiStats.TotalMs += $ms
        if ($ms -gt $script:ApiStats.SlowestMs) { $script:ApiStats.SlowestMs = $ms; $script:ApiStats.SlowestPath = $Path }
        Write-Verbose ("GET {0}  {1:N0} ms" -f $Path, $ms)
    }
}

function Get-ResultArray {
    <#
      Normalises a collection response into a clean array. Handles three shapes seen across
      plug-in API versions: a paged object with .results, a bare JSON array, and a failed
      call that returned $null. Null elements are stripped, because indexing into them later
      throws "Cannot index into a null array".
    #>
    param($Response)

    if ($null -eq $Response) { return @() }

    if ($Response.PSObject -and $Response.PSObject.Properties['results']) {
        return @($Response.results | Where-Object { $null -ne $_ })
    }

    @($Response | Where-Object { $null -ne $_ })
}

function Get-PropValue {
    <#
      Null-safe property read. Returns $null instead of throwing when the object is null or
      the property does not exist on this API version.
    #>
    param($Object, [string]$Name)

    if ($null -eq $Object) { return $null }
    if (-not $Object.PSObject) { return $null }

    $p = $Object.PSObject.Properties[$Name]
    if ($p) { return $p.Value }
    $null
}

function Resolve-AhvBase {
    <#
      The AHV plug-in API lives behind the VBR web service, but which listener serves it
      depends on the deployment (Windows backup server vs Veeam Software Appliance) and the
      installed plug-in build determines the newest usable API version. Probe the sensible
      combinations and return the first that answers 200.
    #>
    $hosts    = @("https://${VbrServer}", "https://${VbrServer}:${RestPort}")
    $versions = @('v10', 'v9', 'v8')
    $tried    = New-Object System.Collections.Generic.List[object]

    foreach ($h in $hosts) {
        foreach ($v in $versions) {
            $candidate = "$h/extension/$AhvExtensionId/api/$v"
            try {
                $null = Invoke-RestMethod -Method Get -Uri "$candidate/workers?limit=1" `
                            -Headers $headers @irmExtra
                Write-Host "  AHV API found at $candidate" -ForegroundColor Green
                return $candidate
            }
            catch {
                $code = Get-HttpStatus $_
                $tried.Add([pscustomobject]@{ Url = $candidate; Status = $code })
                # 401/403 means the endpoint exists but the token or rights are wrong -
                # keep it, since probing further versions will not help.
                if ($code -in @(401, 403)) {
                    Write-Warning "AHV API at $candidate returned $code (authorised endpoint, insufficient rights?)."
                    return $candidate
                }
            }
        }
    }

    Write-Host ""
    Write-Host "Endpoint probe results:" -ForegroundColor Yellow
    $tried | Format-Table Url, Status -AutoSize | Out-String | Write-Host

    throw @"
Could not reach the Veeam Plug-in for Nutanix AHV REST API on $VbrServer.

Authentication to VBR succeeded, so the server is reachable and the credentials are valid -
only the AHV extension did not answer. Most likely one of:

  1. THIS IS VBR 12.x. The extension path only exists from AHV plug-in v8 / VBR v13 onward.
     On 12.x the plug-in is v7 or earlier and its API lives on the separate AHV BACKUP
     APPLIANCE VM, at https://<appliance>/api/v7, with its own local account.
     Re-run pointing at the appliance:

         .\New-VeeamAhvReport.ps1 -VbrServer $VbrServer ``
                                  -ApplianceServer <appliance-ip-or-fqdn> ``
                                  -SkipCertificateCheck

     and supply the APPLIANCE administrator credentials when prompted.

  2. The Nutanix AHV plug-in is not installed on this backup server. Check the VBR console
     under Backup Infrastructure; if there is no Nutanix AHV node, this server has no AHV API.
  3. This is a different backup server from the one holding your AHV configuration.
  4. A reverse proxy in front of VBR routes by hostname, so an IP does not reach the
     extension. Try the FQDN instead of the IP.

Verify by opening the Swagger UI in a browser:
  v13 / plug-in v8+ : https://$VbrServer/extension/$AhvExtensionId/swagger/index.html
  12.x / plug-in v7 : https://<appliance>/swagger/index.html
"@
}

# --- 2. Locate the AHV API -------------------------------------------------
Step-Phase 'Locate AHV API'
# Appliance mode already knows its base URL; only VBR-hosted mode needs discovery.
if ($ConnMode -eq 'Vbr') {
    Write-Host "Locating AHV plug-in API ..." -ForegroundColor Cyan
    $AhvBase = Resolve-AhvBase
}

# --- 3. Collect ------------------------------------------------------------
Step-Phase 'Clusters and hosts'
Write-Host "Collecting clusters ..." -ForegroundColor Cyan
$clusterMap = @{}
$clusters   = Invoke-AhvGet -Path 'clusters?limit=-1'
foreach ($c in (Get-ResultArray $clusters)) {
    $cname = Get-PropValue $c 'name'
    foreach ($p in @('id', 'uid', 'uuid', 'clusterId')) {
        $val = Get-PropValue $c $p
        if ($val) { $clusterMap[[string]$val] = $cname }
    }
}
Write-Host ("  {0} cluster name(s) resolved." -f $clusterMap.Count)

# Host ID -> name, used to resolve worker host affinity. Sources vary by plug-in build,
# so collect from everything available and ignore what is not there.
$hostMap = @{}
function Add-HostEntries {
    param($Items)
    foreach ($h in @($Items | Where-Object { $null -ne $_ })) {
        $hname = $null
        foreach ($n in @('name', 'hostName', 'displayName', 'hypervisorAddress', 'ipAddress')) {
            $hname = Get-PropValue $h $n
            if ($hname) { break }
        }
        if (-not $hname) { continue }
        foreach ($p in @('id', 'uid', 'uuid', 'hostId', 'hostUuid', 'nodeId')) {
            $val = Get-PropValue $h $p
            if ($val) { $hostMap[[string]$val] = [string]$hname }
        }
    }
}
foreach ($c in (Get-ResultArray $clusters)) {
    foreach ($p in @('hosts', 'nodes')) { Add-HostEntries (Get-PropValue $c $p) }
}
# Only query hosts if a worker actually uses affinity, and only fall back to one call per
# cluster when the cheaper sources returned nothing.
# Workers are fetched here (not in the Workers step) so the affinity check can use them.
$workersRaw = Invoke-AhvGet -Path 'workers?limit=-1'
# Only workers with affinity ENABLED need host names - the settings block is present (with
# enabled=false) on every worker. /clusters/{id}/hosts is the documented endpoint; there is
# no top-level /hosts in the v10 API.
$needHosts = @((Get-ResultArray $workersRaw) | Where-Object {
    $cfg = $_.configuration
    $on  = $false
    foreach ($p in @('affinitySettings', 'hostAffinity', 'affinity', 'hostAffinitySettings')) {
        $a = Get-PropValue $cfg $p
        if ($a -is [bool]) { $on = $a }
        elseif ($a) { foreach ($e in @('enabled', 'isEnabled', 'hostAffinityEnabled')) { if (Get-PropValue $a $e) { $on = $true } } }
        if ($on) { break }
    }
    $on
}).Count -gt 0
if ($needHosts -and $hostMap.Count -eq 0) {
    foreach ($c in (Get-ResultArray $clusters)) {
        $cid = Get-PropValue $c 'id'
        if ($cid) { Add-HostEntries (Get-ResultArray (Invoke-AhvGet -Path "clusters/$cid/hosts?limit=-1" -Quiet)) }
    }
}
Write-Host ("  {0} host name(s) resolved." -f $hostMap.Count)

function Get-WorkerAffinity {
    <#
      Returns Enabled (bool) and Hosts (display string) for a worker's host affinity.
      Property names differ between plug-in versions, so try the known variants.
    #>
    param($Configuration)

    $aff = $null
    foreach ($p in @('affinitySettings', 'hostAffinity', 'affinity', 'hostAffinitySettings')) {
        $aff = Get-PropValue $Configuration $p
        if ($null -ne $aff) { break }
    }
    if ($null -eq $aff) { return [pscustomobject]@{ Enabled = $false; Hosts = ''; Raw = $null } }

    $enabled = $false
    if ($aff -is [bool]) { $enabled = $aff }
    else {
        foreach ($p in @('enabled', 'isEnabled', 'hostAffinityEnabled')) {
            $v = Get-PropValue $aff $p
            if ($null -ne $v) { $enabled = [bool]$v; break }
        }
    }

    $refs = New-Object System.Collections.Generic.List[string]
    if ($aff -isnot [bool]) {
        foreach ($p in @('hostId', 'hostIds', 'hosts', 'hostUuid', 'hostUuids', 'host', 'nodeId', 'nodeIds', 'hostName', 'hostNames')) {
            foreach ($item in @((Get-PropValue $aff $p) | Where-Object { $null -ne $_ })) {
                if ($item -is [string] -or $item -is [guid]) { $refs.Add([string]$item); continue }
                $label = $null
                foreach ($n in @('name', 'hostName', 'displayName')) {
                    $label = Get-PropValue $item $n
                    if ($label) { break }
                }
                if (-not $label) {
                    foreach ($n in @('id', 'uuid', 'hostId', 'hostUuid', 'nodeId')) {
                        $label = Get-PropValue $item $n
                        if ($label) { break }
                    }
                }
                if ($label) { $refs.Add([string]$label) }
            }
        }
    }

    $names = @($refs | ForEach-Object { if ($hostMap.ContainsKey($_)) { $hostMap[$_] } else { $_ } } | Select-Object -Unique)
    $hostText = if ($names.Count -gt 0) { $names -join ', ' }
                elseif ($enabled)   { '(host not reported)' }
                else                { '' }

    [pscustomobject]@{ Enabled = $enabled; Hosts = $hostText; Raw = $aff }
}

Step-Phase 'Workers'
Write-Host "Collecting workers ..." -ForegroundColor Cyan
$workers = @(
    foreach ($w in (Get-ResultArray $workersRaw)) {
        $cid = [string](Get-PropValue $w.configuration 'clusterId')
        $ip  = $null
        if ($w.configuration -and $w.configuration.networkSettings -and $w.configuration.networkSettings.networks) {
            $ip = ($w.configuration.networkSettings.networks | Where-Object { $_ } | Select-Object -First 1).ipAddress
        }
        $aff = Get-WorkerAffinity $w.configuration
        if ($aff.Enabled -and $aff.Hosts -eq '(host not reported)') {
            Write-Verbose ("Worker '{0}' affinity enabled but no host found. Raw affinity: {1}" -f `
                $w.configuration.name, ($aff.Raw | ConvertTo-Json -Depth 5 -Compress))
        }
        [pscustomobject]@{
            Name               = $w.configuration.name
            Cluster            = if ($clusterMap.ContainsKey($cid)) { $clusterMap[$cid] } else { $cid }
            Enabled            = [bool]$w.enabled
            Status             = [string]$w.status
            MaxConcurrentTasks = [int]$w.configuration.maxConcurrentTasks
            vCPU               = [int]$w.configuration.cpuCount
            MemoryGB           = [int]$w.configuration.memoryGb
            IPAddress          = if ($ip) { $ip } else { 'DHCP / n/a' }
            Affinity           = if ($aff.Enabled) { 'Yes' } else { 'No' }
            AffinityHost       = if ($aff.Enabled) { $aff.Hosts } else { '' }
            Description        = [string]$w.configuration.description
        }
    }
)

Step-Phase 'Jobs and repositories'
Write-Host "Collecting jobs ..." -ForegroundColor Cyan
$jobsRaw = Invoke-AhvGet -Path 'jobs?limit=-1'

# Optional: resolve repository names via the main VBR REST API
$repoMap = @{}
if ($ConnMode -eq 'Vbr') {
    # Main VBR REST API, which appliance-mode credentials cannot reach.
    try {
        $repos = Invoke-RestMethod -Method Get -Uri "$VbrBase/backupInfrastructure/repositories?limit=-1" `
            -Headers $headers @irmExtra
        foreach ($r in @($repos.data | Where-Object { $null -ne $_ })) {
            $rid = Get-PropValue $r 'id'
            if ($rid) { $repoMap[[string]$rid] = Get-PropValue $r 'name' }
        }
    }
    catch {
        Write-Verbose "Repository name lookup unavailable: $($_.Exception.Message)"
    }
}
else {
    # Plug-in v7 exposes repositories through the appliance itself.
    foreach ($r in (Get-ResultArray (Invoke-AhvGet -Path 'backupServers/repositories?limit=-1' -Quiet))) {
        $rid = Get-PropValue $r 'id'
        if ($rid) { $repoMap[[string]$rid] = Get-PropValue $r 'name' }
    }
}

$jobs = @(
    foreach ($j in (Get-ResultArray $jobsRaw)) {
        $s      = $j.settings
        $repoId = [string](Get-PropValue $s 'repositoryId')
        [pscustomobject]@{
            Name          = $j.name
            Mode          = [string]$j.mode
            Enabled       = [bool]$j.enabled
            Status        = [string]$j.status
            Objects       = [int]$j.objects
            Repository    = if ($repoMap.ContainsKey($repoId)) { $repoMap[$repoId] } else { $repoId }
            Schedule      = Get-ScheduleSummary $s.scheduleSettings
            AutoRetry     = if ($s.scheduleSettings.automaticRetry) { "$($s.scheduleSettings.retryCount) x $($s.scheduleSettings.retryTimeDelay)min" } else { 'Off' }
            Retention     = Get-RetentionSummary $s.retentionSettings
            GFS           = Get-GfsSummary $s.gfsSettings
            ActiveFull    = Get-ToggleSummary $s.activeFullSettings
            SyntheticFull = Get-ToggleSummary $s.syntheticFullSettings
            HealthCheck   = Get-ToggleSummary $s.healthCheckSettings
            Compression   = [string]$s.compression
            BlockSize     = [string]$s.backupBlockSize
            DeletedVmRet  = if ($s.deletedVmRetention.enabled) { "$($s.deletedVmRetention.days) days" } else { 'Off' }
            Notifications = if ($s.emailSettings.isEnabled) { ($s.emailSettings.recipients -join '; ') } else { 'Off' }
            LastRun       = Get-LocalTimeString $j.lastRunUtc
            NextRun       = if ($j.nextRunUtc) { Get-LocalTimeString $j.nextRunUtc } else { [string]$j.nextRunInfo }
            Description   = [string]$j.description
        }
    }
)

Step-Phase 'Session list'
Write-Host "Collecting sessions (last $DaysBack days) ..." -ForegroundColor Cyan
$fromUtc      = (Get-Date).ToUniversalTime().AddDays(-$DaysBack)
$fromIso      = $fromUtc.ToString('yyyy-MM-ddTHH:mm:ssZ')
$sessionsRaw  = Invoke-AhvGet -Path "sessions?from=$fromIso&limit=-1" -Quiet

if ($null -eq $sessionsRaw) {
    # Older plug-in builds may not accept the from filter. Pull everything and window it here.
    Write-Verbose "from= filter rejected; retrieving all sessions and filtering client-side."
    $sessionsRaw = Invoke-AhvGet -Path 'sessions?limit=-1'
    $sessionList = @(Get-ResultArray $sessionsRaw | Where-Object {
        $_.startTimeUtc -and ([datetime]$_.startTimeUtc) -ge $fromUtc
    })
}
else {
    # Get-ResultArray strips nulls. Previously @($null) produced a one-element array holding
    # $null, which showed up as a phantom "(no job name)" session whenever the call failed.
    $sessionList = Get-ResultArray $sessionsRaw
}

Write-Host ("  {0} session(s) returned." -f $sessionList.Count)

# Optional: drop infrastructure rescan sessions before any detail is fetched.
# Rescans are logged with sessionType 'Internal' and the description in jobName, e.g.
# "Rescan cluster <cluster name>" / "Rescanning the infrastructure". Match on the name, but
# never for a backup-type session, so a backup job called "Rescan..." is not caught.
$isRescan = {
    param($x)
    $label = if ($x.jobName) { [string]$x.jobName } else { [string]$x.name }
    ([string]$x.sessionType -notmatch $BackupTypePattern) -and ($label -match $RescanPattern)
}
$rescanTotal = @($sessionList | Where-Object { & $isRescan $_ }).Count
if ($rescanTotal -gt 0) {
    Write-Host ("  {0} of them are infrastructure rescans." -f $rescanTotal) -ForegroundColor DarkGray
}

# Rescans are hidden by default; -IncludeRescans keeps them.
$excludedRescans = @()
if (-not $IncludeRescans) {
    $excludedRescans = @($sessionList | Where-Object { & $isRescan $_ })
    $sessionList     = @($sessionList | Where-Object { -not (& $isRescan $_) })
    if ($excludedRescans.Count -gt 0) {
        Write-Host ("  {0} rescan session(s) hidden (use -IncludeRescans to keep them)." -f $excludedRescans.Count) -ForegroundColor DarkYellow
    }
    if ($excludedRescans.Count -gt 0) {
        $typesSeen = ($excludedRescans | ForEach-Object { [string]$_.sessionType } | Sort-Object -Unique) -join ', '
        Write-Verbose "Excluded session types: $typesSeen"
    }
}
$excludedRescanIssues = @($excludedRescans | Where-Object { $_.result -and $_.result -ne 'Success' })

# --- 3. Enrich sessions ----------------------------------------------------
Step-Phase 'Session detail'
$detailCallsBefore = $script:ApiStats.Calls
# Session detail carries progressState.events, where the rate-limit text appears.
# Successful rescans hold nothing the report uses, so they are never deep-scanned. On a
# plug-in that rescans every 15 minutes they were ~99% of detail calls and run time.
$toScan = if ($DeepScanAllSessions) {
    $sessionList | Where-Object { $_.result -ne 'Success' -or -not (& $isRescan $_) }
} else {
    $sessionList | Where-Object { $_.result -ne 'Success' }
}
Write-Host ("Fetching detail for {0} session(s) ..." -f @($toScan).Count) -ForegroundColor Cyan

$detailMap    = @{}
$detailErrors = @{}   # session id -> error text when /sessions/{id} failed
$toScanList = @($toScan)
$toScanCount = $toScanList.Count
$n = 0

foreach ($s in $toScanList) {
    $n++
    if ($toScanCount -gt 10) {
        # -Status rejects null/empty, and jobName is not always populated (snapshot,
        # retention and infrastructure sessions in particular).
        $label = if ($s.jobName)   { [string]$s.jobName }
                 elseif ($s.name)  { [string]$s.name }
                 else              { "session $n of $toScanCount" }
        Write-Progress -Activity 'Fetching session detail' -Status $label `
                       -PercentComplete ([math]::Min(100, ($n / $toScanCount) * 100))
    }
    $d = Invoke-AhvGet -Path "sessions/$($s.id)" -Quiet
    # One retry for server-side errors, which can be transient.
    if (-not $d -and $script:LastApiError -and $script:LastApiError.Status -ge 500) {
        Start-Sleep -Milliseconds 500
        $d = Invoke-AhvGet -Path "sessions/$($s.id)" -Quiet
    }
    if ($d) { $detailMap[[string]$s.id] = $d }
    else {
        $e = $script:LastApiError
        $detailErrors[[string]$s.id] = if ($e) { "HTTP $($e.Status): $($e.Detail)" } else { 'no response' }
    }
}
if ($detailErrors.Count -gt 0) {
    Write-Warning ("Session detail unavailable for {0} of {1} session(s) - the plug-in API returned an error. Run with -Verbose for the error text." -f $detailErrors.Count, $toScanCount)
}
Write-Progress -Activity 'Fetching session detail' -Completed

$sessions = @(
    foreach ($s in $sessionList) {
        $d = $detailMap[[string]$s.id]
        $dErr = $detailErrors[[string]$s.id]

        # Two separate message collections, because they are used for different things and
        # filtering them the same way was a bug:
        #   $errMsgs  - Error/Warning only, shown in the Reason column
        #   $allMsgs  - every severity, scanned for the bottleneck line, which VBR emits at
        #               Info severity and which the old Error/Warning filter discarded
        $errMsgs = New-Object System.Collections.Generic.List[string]
        $allMsgs = New-Object System.Collections.Generic.List[string]

        if ($s.reason) { $errMsgs.Add([string]$s.reason); $allMsgs.Add([string]$s.reason) }
        if ($d) {
            if ($d.context.reason) { $errMsgs.Add([string]$d.context.reason); $allMsgs.Add([string]$d.context.reason) }
            foreach ($e in @($d.progressState.events | Where-Object { $null -ne $_ })) {
                if (-not $e.message) { continue }
                $allMsgs.Add([string]$e.message)
                # Parentheses matter: the comma list must bind to -in before -and is applied.
                if (($e.severity -in @('Error', 'Warning'))) { $errMsgs.Add([string]$e.message) }
            }
        }

        $joined    = ($errMsgs | Select-Object -Unique) -join ' | '
        $allJoined = ($allMsgs | Select-Object -Unique) -join ' | '
        $rateLimit = [bool]($allJoined -match $RateLimitPattern)
        $bn        = Get-BottleneckInfo $allJoined

        $durMin = Get-DurationMinutes $s.startTimeUtc $s.finishTimeUtc

        [pscustomobject]@{
            JobName     = if ($s.jobName)  { [string]$s.jobName }
                          elseif ($s.name) { [string]$s.name }
                          else             { '(no job name)' }
            ObjectName  = if ($d) { [string](Get-PropValue $d.context 'objectName') } else { '' }
            BackupMode  = if ($d) { [string](Get-PropValue $d.context 'backupMode') } else { '' }
            IsChild     = if ($d -and (Get-PropValue $d 'parentSessionId')) { $true } else { $false }
            SessionType = [string]$s.sessionType
            State       = [string]$s.state
            Result      = [string]$s.result
            StartLocal  = Get-LocalTimeString $s.startTimeUtc
            StartUtcRaw = $s.startTimeUtc
            Duration    = Get-DurationString $s.startTimeUtc $s.finishTimeUtc
            DurationMin = $durMin
            Objects     = [int]$s.objectsCount
            Processed   = if ($d) { [int]$d.progressState.objectsProcessed } else { 0 }
            ReadBytes   = if ($d) { [double]$d.progressState.read.value } else { 0 }
            Read        = if ($d) { Format-Bytes $d.progressState.read.value } else { '-' }
            Transferred = if ($d) { Format-Bytes $d.progressState.transferred.value } else { '-' }
            AvgRate     = if ($d -and $d.progressState.avgProcessingRate) { (Format-Bytes $d.progressState.avgProcessingRate) + '/s' } else { '-' }
            BnStage     = $bn.Stage
            Bottleneck  = $bn.Primary
            BnDetail    = $bn.Detail
            RateLimited = $rateLimit
            Reason      = if ($dErr) { (@($joined, "(session detail unavailable - $dErr)") | Where-Object { $_ }) -join ' | ' } else { $joined }
            DetailError = $dErr
        }
    }
)
# Re-wrap in @() so .Count stays reliable when 0 or 1 session comes back.
$sessions = @($sessions | Sort-Object { if ($_.StartUtcRaw) { [datetime]$_.StartUtcRaw } else { [datetime]::MinValue } } -Descending)

# --- 4. Aggregate ----------------------------------------------------------
$detailCalls = $script:ApiStats.Calls - $detailCallsBefore
Step-Phase 'Parse and aggregate'
$enabledWorkers = @($workers | Where-Object { $_.Enabled })
$totalTasks     = ($enabledWorkers | ForEach-Object { $_.MaxConcurrentTasks } | Measure-Object -Sum).Sum
if (-not $totalTasks) { $totalTasks = 0 }

$distinctTasks  = @($enabledWorkers | ForEach-Object { $_.MaxConcurrentTasks } | Sort-Object -Unique)
$consistent     = ($distinctTasks.Count -le 1)

# The AHV API reports failures as 'Error'; VBR-style results use 'Failed'. Count both.
$FailResults    = @('Failed', 'Error')
$failedSessions = @($sessions | Where-Object { $_.Result -in $FailResults })
$warnSessions   = @($sessions | Where-Object { $_.Result -eq 'Warning' })
$rlSessions     = @($sessions | Where-Object { $_.RateLimited })

$jobRollup = @(
    $sessions | Group-Object JobName | ForEach-Object {
        $g = $_.Group
        [pscustomobject]@{
            JobName     = $_.Name
            Total       = $g.Count
            Success     = @($g | Where-Object { $_.Result -eq 'Success' }).Count
            Warning     = @($g | Where-Object { $_.Result -eq 'Warning' }).Count
            Failed      = @($g | Where-Object { $_.Result -in $FailResults }).Count
            RateLimited = @($g | Where-Object { $_.RateLimited }).Count
        }
    } | Sort-Object -Property @{Expression = 'RateLimited'; Descending = $true}, @{Expression = 'Failed'; Descending = $true}, 'JobName'
)

# --- Per-VM duration statistics --------------------------------------------
# This is the measurement the whole backup-window model depends on. Child sessions carry
# a populated context.objectName, so they are the per-VM records; parent job sessions are
# excluded or the mean would be meaningless.
# Only completed BACKUP runs of a VM count. Previously any session with an objectName was
# used, which pulled in restores, retention and other per-object tasks, and failed runs
# (which often end in seconds) dragged the mean down.
$vmCandidates = @($sessions | Where-Object { $_.ObjectName })
$vmExcluded   = New-Object System.Collections.Generic.List[object]
$vmSessions   = @(
    foreach ($v in $vmCandidates) {
        $why = $null
        if     ($v.SessionType -notmatch $BackupTypePattern)  { $why = "Not a backup ($($v.SessionType))" }
        elseif ($v.Result -notin @('Success', 'Warning'))     { $why = "Result $($v.Result)" }
        elseif ($null -eq $v.DurationMin)                     { $why = 'Not finished' }
        if ($why) { $vmExcluded.Add([pscustomobject]@{ Reason = $why }) } else { $v }
    }
)
$vmExcludedSummary = @($vmExcluded | Group-Object Reason | Sort-Object Count -Descending |
    ForEach-Object { [pscustomobject]@{ Reason = $_.Name; Sessions = $_.Count } })
$vmIncludedTypes = (@($vmSessions | ForEach-Object { $_.SessionType } | Sort-Object -Unique) -join ', ')
$durSorted  = @($vmSessions | ForEach-Object { [double]$_.DurationMin } | Sort-Object)

$durStats = $null
if ($durSorted.Count -gt 0) {
    $durStats = [pscustomobject]@{
        Count = $durSorted.Count
        DistinctVMs = @($vmSessions | ForEach-Object { $_.ObjectName } | Sort-Object -Unique).Count
        Min   = [math]::Round($durSorted[0], 1)
        P50   = [math]::Round((Get-Percentile $durSorted 50), 1)
        Mean  = [math]::Round(($durSorted | Measure-Object -Average).Average, 1)
        P90   = [math]::Round((Get-Percentile $durSorted 90), 1)
        P95   = [math]::Round((Get-Percentile $durSorted 95), 1)
        Max   = [math]::Round($durSorted[$durSorted.Count - 1], 1)
    }
}

# --- Bottleneck tally ------------------------------------------------------
$bnSessions = @($sessions | Where-Object { $_.BnStage })
$bnTally = @(
    $bnSessions | Group-Object BnStage | Sort-Object Count -Descending | ForEach-Object {
        [pscustomobject]@{ Stage = $_.Name; Sessions = $_.Count }
    }
)

$rlByDay = @(
    $rlSessions | Where-Object { $_.StartUtcRaw } |
        Group-Object { ([datetime]$_.StartUtcRaw).ToLocalTime().ToString('yyyy-MM-dd') } |
        Sort-Object Name | ForEach-Object {
            [pscustomobject]@{ Day = $_.Name; Count = $_.Count }
        }
)

# --- 5. Build HTML ---------------------------------------------------------
Step-Phase 'Build and write report'
Write-Host "Building report ..." -ForegroundColor Cyan

$css = @'
<style>
:root{
  --bg:#f5f6f8; --card:#ffffff; --ink:#1b1f24; --muted:#5b6570; --line:#dfe3e8;
  --accent:#00b336; --warn:#b8860b; --bad:#c0392b; --good:#1e7e34; --chip:#eef1f4;
}
@media (prefers-color-scheme: dark){
  :root{ --bg:#14171a; --card:#1c2024; --ink:#e6e9ec; --muted:#9aa4ae; --line:#2c3238;
         --accent:#3ddc6b; --warn:#e0a92b; --bad:#ef6a5a; --good:#4cc36b; --chip:#242a30; }
}
*{box-sizing:border-box}
body{margin:0;padding:28px;background:var(--bg);color:var(--ink);
     font:14px/1.55 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Helvetica,Arial,sans-serif}
h1{font-size:23px;margin:0 0 4px}
h2{font-size:17px;margin:34px 0 12px;padding-bottom:7px;border-bottom:2px solid var(--line)}
h3{font-size:14px;margin:22px 0 8px;color:var(--muted);text-transform:uppercase;letter-spacing:.06em}
.sub{color:var(--muted);margin:0 0 22px;font-size:13px}
.cards{display:flex;flex-wrap:wrap;gap:12px;margin-bottom:8px}
.card{background:var(--card);border:1px solid var(--line);border-radius:9px;padding:14px 18px;min-width:150px;flex:1}
.card .v{font-size:26px;font-weight:640;line-height:1.15}
.card .l{color:var(--muted);font-size:12px;margin-top:3px}
.card.bad .v{color:var(--bad)} .card.warn .v{color:var(--warn)} .card.good .v{color:var(--good)}
.wrap{overflow-x:auto;background:var(--card);border:1px solid var(--line);border-radius:9px}
table{border-collapse:collapse;width:100%;font-size:13px}
th,td{padding:8px 12px;text-align:left;border-bottom:1px solid var(--line);white-space:nowrap;vertical-align:top}
th{background:var(--chip);font-weight:620;font-size:12px;text-transform:uppercase;letter-spacing:.04em;color:var(--muted);position:sticky;top:0}
tr:last-child td{border-bottom:none}
td.wrapcell{white-space:normal;min-width:280px;max-width:620px}
.pill{display:inline-block;padding:1px 9px;border-radius:11px;font-size:11.5px;font-weight:620}
.p-ok{background:rgba(30,126,52,.15);color:var(--good)}
.p-warn{background:rgba(184,134,11,.17);color:var(--warn)}
.p-bad{background:rgba(192,57,43,.15);color:var(--bad)}
.p-mute{background:var(--chip);color:var(--muted)}
tr.r-bad td{background:rgba(192,57,43,.06)}
tr.r-warn td{background:rgba(184,134,11,.06)}
.note{background:var(--card);border:1px solid var(--line);border-left:4px solid var(--warn);
      border-radius:7px;padding:13px 17px;margin:14px 0}
.note.ok{border-left-color:var(--good)}
.note.bad{border-left-color:var(--bad)}
.note p{margin:0 0 7px} .note p:last-child{margin:0}
.note ul{margin:7px 0 0 18px;padding:0} .note li{margin:3px 0}
code{background:var(--chip);padding:1px 5px;border-radius:4px;font-size:12.5px}
footer{margin-top:38px;padding-top:14px;border-top:1px solid var(--line);color:var(--muted);font-size:12px}
.empty{padding:18px;color:var(--muted);font-style:italic}
details.sec{margin:0}
details.sec>summary{list-style:none;cursor:pointer;user-select:none}
details.sec>summary::-webkit-details-marker{display:none}
details.sec>summary h2{display:flex;align-items:center;gap:8px}
details.sec>summary h2::before{content:'\25B8';font-size:13px;color:var(--muted);transition:transform .15s}
details.sec[open]>summary h2::before{transform:rotate(90deg)}
details.sec>summary:hover h2{color:var(--accent)}
.toolbar{display:flex;flex-wrap:wrap;gap:8px;margin:0 0 14px}
.btn{font:inherit;font-size:12.5px;padding:5px 12px;border:1px solid var(--line);border-radius:6px;
     background:var(--card);color:var(--ink);cursor:pointer}
.btn:hover{border-color:var(--accent)}
@media print{.toolbar,.btn{display:none}}
</style>
'@

function New-Card {
    param($Value, $Label, $Class = '')
    "<div class='card $Class'><div class='v'>$Value</div><div class='l'>$(ConvertTo-HtmlText $Label)</div></div>"
}

function New-Pill {
    param($Text)
    $cls = switch -Regex ($Text) {
        '^(Success|Running|Enabled|True|Healthy)$' { 'p-ok' }
        '^(Warning)$'                              { 'p-warn' }
        '^(Failed|Error|Unhealthy)$'               { 'p-bad' }
        default                                    { 'p-mute' }
    }
    "<span class='pill $cls'>$(ConvertTo-HtmlText ([string]$Text))</span>"
}

# Each H2 section is wrapped in <details> so it can be collapsed. Start-Section closes
# the previous section before opening the next; Close-Section closes the last one.
$script:sectionOpen = $false
function Start-Section {
    param([string]$Title, [switch]$Collapsed, [string]$Id)
    if ($script:sectionOpen) { $null = $sb.AppendLine("</details>") }
    $openAttr = if ($Collapsed) { '' } else { ' open' }
    $idAttr   = if ($Id) { " id='$Id'" } else { '' }
    $null = $sb.AppendLine("<details class='sec'$openAttr$idAttr><summary><h2>$Title</h2></summary>")
    $script:sectionOpen = $true
}
function Close-Section {
    if ($script:sectionOpen) { $null = $sb.AppendLine("</details>") }
    $script:sectionOpen = $false
}

$csvPath = [System.IO.Path]::Combine(
    [System.IO.Path]::GetDirectoryName([System.IO.Path]::GetFullPath($OutputPath)),
    [System.IO.Path]::GetFileNameWithoutExtension($OutputPath) + '_sessions.csv')
$csvName = [System.IO.Path]::GetFileName($csvPath)
# Safe for a JS string inside an HTML attribute, in case -OutputPath contains quotes.
$csvNameJs = ConvertTo-HtmlText ($csvName -replace '\\', '\\' -replace "'", "\'")

$sb = New-Object System.Text.StringBuilder
$null = $sb.AppendLine("<!DOCTYPE html><html lang='en'><head><meta charset='utf-8'>")
$null = $sb.AppendLine("<meta name='viewport' content='width=device-width,initial-scale=1'>")
$null = $sb.AppendLine("<title>Veeam AHV Report - $(ConvertTo-HtmlText $VbrServer)</title>")
$null = $sb.AppendLine($css)
$null = $sb.AppendLine("</head><body>")

$null = $sb.AppendLine("<h1>Veeam Plug-in for Nutanix AHV &mdash; Configuration &amp; Session Report</h1>")
$null = $sb.AppendLine("<p class='sub'>Server <strong>$(ConvertTo-HtmlText $VbrServer)</strong> &nbsp;&middot;&nbsp; Generated $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') (local time) &nbsp;&middot;&nbsp; Session window: last $DaysBack day(s)</p>")
$null = $sb.AppendLine("<div class='toolbar'><button class='btn' type='button' onclick='setAll(true)'>Expand all</button><button class='btn' type='button' onclick='setAll(false)'>Collapse all</button></div>")

# --- Summary cards
$null = $sb.AppendLine("<div class='cards'>")
$null = $sb.AppendLine((New-Card $workers.Count 'Workers configured'))
$null = $sb.AppendLine((New-Card $enabledWorkers.Count 'Workers enabled'))
$null = $sb.AppendLine((New-Card $totalTasks 'Total concurrent tasks' $(if ($totalTasks -ge 20) { 'warn' } else { 'good' })))
$null = $sb.AppendLine((New-Card $jobs.Count 'AHV jobs'))
$null = $sb.AppendLine((New-Card $sessions.Count 'Sessions in window'))
$null = $sb.AppendLine((New-Card $failedSessions.Count 'Failed' $(if ($failedSessions.Count -gt 0) { 'bad' } else { 'good' })))
$null = $sb.AppendLine((New-Card $warnSessions.Count 'Warnings' $(if ($warnSessions.Count -gt 0) { 'warn' } else { 'good' })))
$null = $sb.AppendLine((New-Card $rlSessions.Count 'Rate-limited' $(if ($rlSessions.Count -gt 0) { 'bad' } else { 'good' })))
if ($durStats) {
    $null = $sb.AppendLine((New-Card "$($durStats.Mean)m" 'Mean per VM'))
}
if ($bnTally.Count -gt 0) {
    $null = $sb.AppendLine((New-Card (ConvertTo-HtmlText $bnTally[0].Stage) 'Top bottleneck' 'warn'))
}
$null = $sb.AppendLine("</div>")

if (-not $IncludeRescans -and $excludedRescans.Count -gt 0) {
    $cls = if ($excludedRescanIssues.Count -gt 0) { 'note' } else { 'note ok' }
    $issueText = if ($excludedRescanIssues.Count -gt 0) {
        " <strong>$($excludedRescanIssues.Count) of them did not succeed</strong> &mdash; rescan failures often point at Prism connectivity, credentials or API throttling, so re-run with <code>-IncludeRescans</code> to see them."
    } else { ' All of them succeeded.' }
    $null = $sb.AppendLine("<div class='$cls'><p><strong>Rescan sessions hidden.</strong> $($excludedRescans.Count) infrastructure rescan session(s) were left out of every count and table in this report. Add <code>-IncludeRescans</code> to show them.$issueText</p></div>")
}

# --- Rate-limit analysis
Start-Section "API rate-limit analysis"

if ($rlSessions.Count -eq 0) {
    $null = $sb.AppendLine("<div class='note ok'><p><strong>No rate-limit errors detected</strong> in the last $DaysBack day(s).</p><p>Sessions were scanned for <code>TooManyRequests</code>, <code>API rate limit exceeded</code> and HTTP 429.$(if (-not $DeepScanAllSessions) { ' Only non-successful sessions were inspected in detail &mdash; re-run with <code>-DeepScanAllSessions</code> to also scan successful sessions for suppressed warnings.' })</p></div>")
}
else {
    $pct = if ($sessions.Count -gt 0) { [math]::Round(($rlSessions.Count / $sessions.Count) * 100, 1) } else { 0 }
    $null = $sb.AppendLine("<div class='note bad'>")
    $null = $sb.AppendLine("<p><strong>$($rlSessions.Count) of $($sessions.Count) sessions ($pct%) hit Nutanix API rate limiting.</strong></p>")
    $null = $sb.AppendLine("<p>This is a Prism Central limitation, not a Veeam defect. Current total concurrent tasks across enabled workers: <strong>$totalTasks</strong>.</p>")
    $null = $sb.AppendLine("<ul>")
    $null = $sb.AppendLine("<li>Upgrade Prism Central to <code>7.3.1.7</code>, <code>7.5.1.2</code> or <code>7.6</code> &mdash; these contain the fix for the IAM auth-caching regression (Nutanix ENG-897683).</li>")
    $null = $sb.AppendLine("<li>Reduce <code>maxConcurrentTasks</code> per worker as an interim mitigation.</li>")
    $null = $sb.AppendLine("<li>Ask Nutanix support to raise the API session threshold (the 7K session workaround).</li>")
    $null = $sb.AppendLine("</ul></div>")

    if ($rlByDay.Count -gt 0) {
        $null = $sb.AppendLine("<h3>Rate-limited sessions per day</h3><div class='wrap'><table><thead><tr><th>Date</th><th>Sessions affected</th></tr></thead><tbody>")
        foreach ($r in $rlByDay) {
            $null = $sb.AppendLine("<tr><td>$(ConvertTo-HtmlText $r.Day)</td><td>$($r.Count)</td></tr>")
        }
        $null = $sb.AppendLine("</tbody></table></div>")
    }

    $null = $sb.AppendLine("<h3>Affected sessions</h3><div class='wrap'><table><thead><tr><th>Job</th><th>Start</th><th>Result</th><th>Duration</th><th>Message</th></tr></thead><tbody>")
    foreach ($s in $rlSessions) {
        $null = $sb.AppendLine("<tr class='r-bad'><td>$(ConvertTo-HtmlText $s.JobName)</td><td>$(ConvertTo-HtmlText $s.StartLocal)</td><td>$(New-Pill $s.Result)</td><td>$(ConvertTo-HtmlText $s.Duration)</td><td class='wrapcell'>$(ConvertTo-HtmlText $s.Reason)</td></tr>")
    }
    $null = $sb.AppendLine("</tbody></table></div>")
}

# --- Workers
Start-Section "Workers &mdash; concurrency and sizing"

if (-not $consistent) {
    $null = $sb.AppendLine("<div class='note'><p><strong>Workers are not consistent.</strong> Max concurrent tasks values in use: <code>$($distinctTasks -join ', ')</code>. Align them in each worker&#39;s settings in the VBR console so load is spread evenly.</p></div>")
}

if ($workers.Count -eq 0) {
    $null = $sb.AppendLine("<div class='wrap'><div class='empty'>No workers configured.</div></div>")
}
else {
    $null = $sb.AppendLine("<div class='wrap'><table><thead><tr><th>Worker</th><th>Cluster</th><th>Enabled</th><th>Status</th><th>Max concurrent tasks</th><th>vCPU</th><th>Memory (GB)</th><th>IP</th><th>Host affinity</th><th>Affinity host</th><th>Description</th></tr></thead><tbody>")
    foreach ($w in ($workers | Sort-Object Cluster, Name)) {
        $null = $sb.AppendLine("<tr><td><strong>$(ConvertTo-HtmlText $w.Name)</strong></td><td>$(ConvertTo-HtmlText $w.Cluster)</td><td>$(New-Pill $w.Enabled)</td><td>$(New-Pill $w.Status)</td><td><strong>$($w.MaxConcurrentTasks)</strong></td><td>$($w.vCPU)</td><td>$($w.MemoryGB)</td><td>$(ConvertTo-HtmlText $w.IPAddress)</td><td>$(ConvertTo-HtmlText $w.Affinity)</td><td>$(if ($w.Affinity -eq 'Yes') { ConvertTo-HtmlText $w.AffinityHost } else { '&mdash;' })</td><td class='wrapcell'>$(ConvertTo-HtmlText $w.Description)</td></tr>")
    }
    $null = $sb.AppendLine("</tbody></table></div>")

    $null = $sb.AppendLine("<h3>Concurrency by cluster (enabled workers)</h3><div class='wrap'><table><thead><tr><th>Cluster</th><th>Workers</th><th>Total concurrent tasks</th><th>Total vCPU</th><th>Total memory (GB)</th></tr></thead><tbody>")
    foreach ($g in ($enabledWorkers | Group-Object Cluster | Sort-Object Name)) {
        $t  = ($g.Group | ForEach-Object { $_.MaxConcurrentTasks } | Measure-Object -Sum).Sum
        $cpu = ($g.Group | ForEach-Object { $_.vCPU }     | Measure-Object -Sum).Sum
        $mem = ($g.Group | ForEach-Object { $_.MemoryGB } | Measure-Object -Sum).Sum
        $null = $sb.AppendLine("<tr><td>$(ConvertTo-HtmlText $g.Name)</td><td>$($g.Count)</td><td><strong>$t</strong></td><td>$cpu</td><td>$mem</td></tr>")
    }
    $null = $sb.AppendLine("</tbody></table></div>")
}

# --- Jobs
Start-Section "Job settings"
if ($jobs.Count -eq 0) {
    $null = $sb.AppendLine("<div class='wrap'><div class='empty'>No AHV jobs found.</div></div>")
}
else {
    $null = $sb.AppendLine("<div class='wrap'><table><thead><tr><th>Job</th><th>Mode</th><th>Enabled</th><th>Status</th><th>VMs</th><th>Repository</th><th>Schedule</th><th>Retry</th><th>Retention</th><th>GFS</th><th>Active full</th><th>Synthetic full</th><th>Health check</th><th>Compression</th><th>Block size</th><th>Deleted VM ret.</th><th>Last run</th><th>Next run</th></tr></thead><tbody>")
    foreach ($j in ($jobs | Sort-Object Name)) {
        $null = $sb.AppendLine("<tr><td><strong>$(ConvertTo-HtmlText $j.Name)</strong></td><td>$(ConvertTo-HtmlText $j.Mode)</td><td>$(New-Pill $j.Enabled)</td><td>$(New-Pill $j.Status)</td><td>$($j.Objects)</td><td>$(ConvertTo-HtmlText $j.Repository)</td><td>$(ConvertTo-HtmlText $j.Schedule)</td><td>$(ConvertTo-HtmlText $j.AutoRetry)</td><td>$(ConvertTo-HtmlText $j.Retention)</td><td>$(ConvertTo-HtmlText $j.GFS)</td><td>$(ConvertTo-HtmlText $j.ActiveFull)</td><td>$(ConvertTo-HtmlText $j.SyntheticFull)</td><td>$(ConvertTo-HtmlText $j.HealthCheck)</td><td>$(ConvertTo-HtmlText $j.Compression)</td><td>$(ConvertTo-HtmlText $j.BlockSize)</td><td>$(ConvertTo-HtmlText $j.DeletedVmRet)</td><td>$(ConvertTo-HtmlText $j.LastRun)</td><td>$(ConvertTo-HtmlText $j.NextRun)</td></tr>")
    }
    $null = $sb.AppendLine("</tbody></table></div>")
}

# --- Per-VM duration: the window-sizing measurement
Start-Section "Per-VM duration &mdash; window sizing"

$scopeNote = "Counts completed backup runs only (session type matching <code>$(ConvertTo-HtmlText $BackupTypePattern)</code>, result Success or Warning)."
if (-not $DeepScanAllSessions) {
    $scopeNote += " <strong>Run with <code>-DeepScanAllSessions</code> for meaningful figures</strong> &mdash; without it, per-VM detail is only fetched for non-successful sessions, so successful VM runs are missing and the sample is biased towards problem runs."
}

if (-not $durStats) {
    $null = $sb.AppendLine("<div class='note'><p><strong>No completed per-VM backup runs found.</strong> $scopeNote</p></div>")
}
else {
    $null = $sb.AppendLine("<div class='wrap'><table><thead><tr><th>Distinct VMs</th><th>VM backup runs</th><th>Min</th><th>Median</th><th>Mean</th><th>P90</th><th>P95</th><th>Max</th></tr></thead><tbody>")
    $null = $sb.AppendLine("<tr><td><strong>$($durStats.DistinctVMs)</strong></td><td>$($durStats.Count)</td><td>$($durStats.Min) min</td><td>$($durStats.P50) min</td><td><strong>$($durStats.Mean) min</strong></td><td>$($durStats.P90) min</td><td>$($durStats.P95) min</td><td>$($durStats.Max) min</td></tr>")
    $null = $sb.AppendLine("</tbody></table></div>")

    # Plain-language guide to the columns, using this run's own numbers.
    $null = $sb.AppendLine("<div class='note ok'><p><strong>How to read these numbers.</strong></p><ul>")
    $null = $sb.AppendLine("<li><strong>Median</strong> &mdash; the middle VM. Half of the VM backups finished in $($durStats.P50) min or less, half took longer.</li>")
    $null = $sb.AppendLine("<li><strong>Mean</strong> &mdash; the average ($($durStats.Mean) min). One very slow VM can pull it up, so on its own it can make things look better or worse than a typical run.</li>")
    $null = $sb.AppendLine("<li><strong>P90</strong> &mdash; 9 out of 10 VM backups finished within $($durStats.P90) min. Only the slowest 10% took longer.</li>")
    $null = $sb.AppendLine("<li><strong>P95</strong> &mdash; 19 out of 20 VM backups finished within $($durStats.P95) min. Only the slowest 5% took longer.</li>")
    $null = $sb.AppendLine("<li><strong>Max</strong> &mdash; the single slowest VM ($($durStats.Max) min). A job cannot finish before its slowest VM does, however many workers you add.</li>")
    $null = $sb.AppendLine("</ul><p>Think of it like a queue at the checkout: the average tells you a typical wait, but P90 and P95 tell you how long the slow customers hold things up &mdash; and they decide when the shop can close. Plan the backup window on P90 rather than the average, so the slower VMs are allowed for.</p>")
    if ($durStats.Count -lt 20) {
        $null = $sb.AppendLine("<p><strong>Small sample:</strong> only $($durStats.Count) VM backup run(s) were measured. With this few, P90, P95 and Max are often the same run, so treat them as rough. Use <code>-DaysBack</code> to cover more runs.</p>")
    }
    $null = $sb.AppendLine("</div>")

    # One backup window processes each VM once, so project with DISTINCT VMs, not with every
    # run in the reporting window (that multiplied the estimate by the number of days).
    if ($totalTasks -gt 0) {
        $projMean = [math]::Round(($durStats.DistinctVMs * $durStats.Mean) / $totalTasks, 0)
        $projP90  = [math]::Round(($durStats.DistinctVMs * $durStats.P90)  / $totalTasks, 0)
        $floor    = [math]::Round($durStats.Max, 0)
        $null = $sb.AppendLine("<div class='note'><p><strong>Projection for one backup window.</strong> $($durStats.DistinctVMs) VMs &times; mean $($durStats.Mean) min &divide; $totalTasks concurrent tasks &asymp; <strong>$projMean min</strong> (using P90: $projP90 min). The window can never be shorter than the slowest single VM, $floor min.</p>")
        $null = $sb.AppendLine("<p>Formula: distinct VMs &times; per-VM duration &divide; concurrent tasks. It assumes every enabled worker can take any VM; if jobs are split across clusters, apply it per cluster using that cluster's task total.</p>")
        $null = $sb.AppendLine("<p>Watch the gap between mean and P95 &mdash; a long tail means stragglers, and stragglers are what overrun a fixed window.</p></div>")
    }
    else {
        $null = $sb.AppendLine("<div class='note'><p><strong>No projection.</strong> No enabled workers, so total concurrent tasks is 0.</p></div>")
    }
}

$exclText = if ($vmExcludedSummary.Count -gt 0) {
    'Excluded per-VM sessions: ' + (($vmExcludedSummary | ForEach-Object { "$(ConvertTo-HtmlText $_.Reason) &times; $($_.Sessions)" }) -join ', ') + '.'
} else { 'No per-VM sessions were excluded.' }
$inclText = if ($vmIncludedTypes) { " Included session types: <code>$(ConvertTo-HtmlText $vmIncludedTypes)</code>." } else { '' }
$null = $sb.AppendLine("<div class='note ok'><p>$scopeNote$inclText $exclText</p></div>")

# --- Bottleneck
Start-Section "Bottleneck analysis"

if ($bnTally.Count -eq 0) {
    $null = $sb.AppendLine("<div class='note'><p><strong>No bottleneck data found in session events.</strong> The AHV session schema has no bottleneck field &mdash; the line is parsed out of session event messages, which are only retrieved for sessions the detail scan covers. Re-run with <code>-DeepScanAllSessions</code>. If it is still empty, this plug-in build may not emit the line and the bottleneck must be read from the job statistics in the console.</p></div>")
}
else {
    $null = $sb.AppendLine("<div class='wrap'><table><thead><tr><th>Limiting stage</th><th>Sessions</th><th>Share</th></tr></thead><tbody>")
    foreach ($b in $bnTally) {
        $share = [math]::Round(($b.Sessions / $bnSessions.Count) * 100, 1)
        $null = $sb.AppendLine("<tr><td><strong>$(ConvertTo-HtmlText $b.Stage)</strong></td><td>$($b.Sessions)</td><td>$share%</td></tr>")
    }
    $null = $sb.AppendLine("</tbody></table></div>")
    $null = $sb.AppendLine("<div class='note'><p><strong>Reading this.</strong> <code>Proxy</code> dominant means worker CPU is the limit &mdash; fewer concurrent tasks per worker across more workers gives each task more vCPU. <code>Source</code> means the read from the hypervisor is the limit, where worker placement on the VM's own host matters. <code>Target</code> points at repository ingest or the repository task limit. <code>Network</code> is rarely the constraint on AHV.</p></div>")
}

# --- Per-job rollup
Start-Section "Per-job session rollup (last $DaysBack day(s))"
if ($jobRollup.Count -eq 0) {
    $null = $sb.AppendLine("<div class='wrap'><div class='empty'>No sessions in the selected window.</div></div>")
}
else {
    $null = $sb.AppendLine("<div class='wrap'><table><thead><tr><th>Job</th><th>Sessions</th><th>Success</th><th>Warning</th><th>Failed</th><th>Rate-limited</th><th>Success rate</th></tr></thead><tbody>")
    foreach ($r in $jobRollup) {
        $rate = if ($r.Total -gt 0) { [math]::Round(($r.Success / $r.Total) * 100, 1) } else { 0 }
        $cls  = if ($r.Failed -gt 0) { "class='r-bad'" } elseif ($r.Warning -gt 0) { "class='r-warn'" } else { '' }
        $null = $sb.AppendLine("<tr $cls><td><strong>$(ConvertTo-HtmlText $r.JobName)</strong></td><td>$($r.Total)</td><td>$($r.Success)</td><td>$($r.Warning)</td><td>$($r.Failed)</td><td>$($r.RateLimited)</td><td>$rate%</td></tr>")
    }
    $null = $sb.AppendLine("</tbody></table></div>")
}

# --- Sessions
Start-Section "Session detail (last $DaysBack day(s))" -Collapsed -Id 'sessions'
if ($detailErrors.Count -gt 0) {
    $null = $sb.AppendLine("<div class='note bad'><p><strong>Session detail unavailable for $($detailErrors.Count) of $toScanCount scanned session(s).</strong> The plug-in API returned an error for <code>GET /sessions/{id}</code>, so VM name, read / transferred, rate, bottleneck and event text are missing for those rows, and they cannot contribute to the per-VM duration or bottleneck sections. The error is shown in each row's Reason column. This is a server-side error; reproduce it in the plug-in Swagger UI and raise it with Veeam Support if it persists.</p></div>")
}
if ($sessions.Count -eq 0) {
    $null = $sb.AppendLine("<div class='wrap'><div class='empty'>No sessions in the selected window.</div></div>")
}
else {
    $null = $sb.AppendLine("<div class='toolbar'><button class='btn' type='button' onclick=""downloadCsv('sessionTable','$csvNameJs')"">Download CSV</button></div>")
    $null = $sb.AppendLine("<div class='wrap'><table id='sessionTable'><thead><tr><th>Job</th><th>VM</th><th>Type</th><th>Start (local)</th><th>Duration</th><th>Result</th><th>Objects</th><th>Read</th><th>Transferred</th><th>Avg rate</th><th>Bottleneck</th><th>Rate limited</th><th>Reason / error</th></tr></thead><tbody>")
    foreach ($s in $sessions) {
        $cls = if ($s.Result -in $FailResults) { "class='r-bad'" } elseif ($s.Result -eq 'Warning') { "class='r-warn'" } else { '' }
        $rl  = if ($s.RateLimited) { "<span class='pill p-bad'>Yes</span>" } else { '' }
        $bnCell = if ($s.BnDetail) { ConvertTo-HtmlText $s.BnDetail } elseif ($s.Bottleneck) { ConvertTo-HtmlText $s.Bottleneck } else { '-' }
        $vmCell = if ($s.ObjectName) { ConvertTo-HtmlText $s.ObjectName } else { '-' }
        $null = $sb.AppendLine("<tr $cls><td><strong>$(ConvertTo-HtmlText $s.JobName)</strong></td><td>$vmCell</td><td>$(ConvertTo-HtmlText $s.SessionType)</td><td>$(ConvertTo-HtmlText $s.StartLocal)</td><td>$(ConvertTo-HtmlText $s.Duration)</td><td>$(New-Pill $s.Result)</td><td>$($s.Objects)</td><td>$(ConvertTo-HtmlText $s.Read)</td><td>$(ConvertTo-HtmlText $s.Transferred)</td><td>$(ConvertTo-HtmlText $s.AvgRate)</td><td>$bnCell</td><td>$rl</td><td class='wrapcell'>$(ConvertTo-HtmlText $s.Reason)</td></tr>")
    }
    $null = $sb.AppendLine("</tbody></table></div>")
}

Close-Section

$js = @'
<script>
function setAll(open){document.querySelectorAll('details.sec').forEach(function(d){d.open=open;});}
// Open everything for printing, then restore what the reader had.
var _printState=null;
window.addEventListener('beforeprint',function(){_printState=[];document.querySelectorAll('details.sec').forEach(function(d){_printState.push(d.open);d.open=true;});});
window.addEventListener('afterprint',function(){if(!_printState)return;document.querySelectorAll('details.sec').forEach(function(d,i){d.open=_printState[i];});_printState=null;});
function csvCell(t){
  t=(t||'').replace(/\s+/g,' ').trim();
  if(/^[=+@]/.test(t)){t="'"+t;}            // stop Excel treating text as a formula
  return '"'+t.replace(/"/g,'""')+'"';
}
function downloadCsv(tableId,fileName){
  var tbl=document.getElementById(tableId); if(!tbl)return;
  var lines=[];
  tbl.querySelectorAll('tr').forEach(function(r){
    var cells=[]; r.querySelectorAll('th,td').forEach(function(c){cells.push(csvCell(c.textContent));});
    lines.push(cells.join(','));
  });
  var blob=new Blob(['\ufeff'+lines.join('\r\n')],{type:'text/csv;charset=utf-8'});
  var a=document.createElement('a'); a.href=URL.createObjectURL(blob); a.download=fileName;
  document.body.appendChild(a); a.click(); document.body.removeChild(a);
  setTimeout(function(){URL.revokeObjectURL(a.href);},1000);
}
</script>
'@

$scanNote = if ($DeepScanAllSessions) { 'all sessions' } else { 'non-successful sessions only' }
$detectedVer = if ($AhvBase -match '/api/(v\d+)$') { $Matches[1] } else { 'unknown' }
$null = $sb.AppendLine("<footer>Generated by <code>New-VeeamAhvReport.ps1 v$ScriptVersion</code>. Source: Veeam Plug-in for Nutanix AHV REST API <strong>$detectedVer</strong> at <code>$(ConvertTo-HtmlText $AhvBase)</code>. Session detail scanned for $scanNote. Times shown in local time; the API returns UTC. Read-only report &mdash; no configuration was changed.</footer>")
$null = $sb.AppendLine($js)
$null = $sb.AppendLine("</body></html>")

# --- 6. Write --------------------------------------------------------------
$sb.ToString() | Out-File -FilePath $OutputPath -Encoding UTF8

if ($ExportCsv) {
    $sessions | Select-Object JobName, ObjectName, IsChild, SessionType, BackupMode, State, Result,
        StartLocal, StartUtcRaw, Duration, DurationMin, Objects, Processed, ReadBytes, Read,
        Transferred, AvgRate, BnStage, Bottleneck, BnDetail, RateLimited, Reason, DetailError |
        Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
}

Write-Host ""
Write-Host "Report written to: $OutputPath" -ForegroundColor Green
if ($ExportCsv) { Write-Host "Session CSV written to: $csvPath" -ForegroundColor Green }
Write-Host ("  Workers {0} ({1} enabled, {2} total concurrent tasks)" -f $workers.Count, $enabledWorkers.Count, $totalTasks)
Write-Host ("  Jobs    {0}" -f $jobs.Count)
Write-Host ("  Sessions {0}  ({1} failed, {2} warning, {3} rate-limited)" -f $sessions.Count, $failedSessions.Count, $warnSessions.Count, $rlSessions.Count)
if (-not $IncludeRescans -and $excludedRescans.Count -gt 0) {
    Write-Host ("  Rescans hidden {0}  ({1} not successful)" -f $excludedRescans.Count, $excludedRescanIssues.Count)
}

Step-Phase $null
$avgMs = if ($script:ApiStats.Calls) { $script:ApiStats.TotalMs / $script:ApiStats.Calls } else { 0 }
Write-Host ""
Write-Host ("Run time {0:N1}s  -  {1} API call(s), {2} failed, avg {3:N0} ms, slowest {4:N0} ms ({5})" -f `
    $script:RunTimer.Elapsed.TotalSeconds, $script:ApiStats.Calls, $script:ApiStats.Failed, $avgMs,
    $script:ApiStats.SlowestMs, $script:ApiStats.SlowestPath) -ForegroundColor DarkGray
Write-Host ("  Session detail calls: {0}" -f $detailCalls) -ForegroundColor DarkGray
$script:PhaseTimes | Format-Table Phase, Seconds -AutoSize | Out-String | Write-Host -ForegroundColor DarkGray

if ($Show) { Start-Process $OutputPath }

[pscustomobject]@{
    ReportPath         = $OutputPath
    Workers            = $workers
    Jobs               = $jobs
    Sessions           = $sessions
    JobRollup          = $jobRollup
    TotalConcurrentTasks = $totalTasks
    RateLimitedCount   = $rlSessions.Count
    ExcludedRescans    = $excludedRescans
    CsvPath            = if ($ExportCsv) { $csvPath } else { $null }
    Timings            = $script:PhaseTimes
    ApiStats           = $script:ApiStats
}
