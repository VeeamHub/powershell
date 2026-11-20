<#
.SYNOPSIS
    Reads backup policy (job) configuration from a Veeam Backup for Microsoft Azure appliance
    via REST API: retention, workload regions and target repositories.

.DESCRIPTION
    - Authenticates against https://<appliance>/api/oauth2/token (password grant)
    - Auto-detects the newest working API version (v8 .. v4) unless -ApiVersion is given
    - Enumerates policies of all supported workload types (VM, SQL, File Shares, Cosmos DB, ...)
    - Resolves target repository IDs to repository names
    - Retention values are collected generically (any property containing "retention",
      "ToKeep" or "Count" inside a *Schedule object), so the script survives small schema
      differences between VBAz versions. Raw JSON is always saved for verification.

.EXAMPLE
    ./VBAz-GetJobDetails.ps1 -Server vbaz.contoso.com
    ./VBAz-GetJobDetails.ps1 -Server 10.0.0.4 -Credential (Get-Credential) -ApiVersion v8 -OutDir ./out
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $Server,
    [pscredential] $Credential = (Get-Credential -Message "VBAz appliance login"),
    [string] $ApiVersion,                      # e.g. 'v8'; empty = auto-detect
    [string] $OutDir = (Join-Path $PSScriptRoot "vbaz-export_$(Get-Date -Format yyyyMMdd-HHmmss)"),
    [switch] $NoSkipCertificateCheck
)

$ErrorActionPreference = 'Stop'
$base   = "https://$Server"
$irmArg = @{ SkipCertificateCheck = -not $NoSkipCertificateCheck }

# ---------- Auth ----------
$tokenResp = Invoke-RestMethod @irmArg -Method Post -Uri "$base/api/oauth2/token" `
    -ContentType 'application/x-www-form-urlencoded' -Body @{
        grant_type = 'password'
        username   = $Credential.UserName
        password   = $Credential.GetNetworkCredential().Password
    }
if (-not $tokenResp.access_token) {
    throw "No access_token returned. If MFA is enabled for this account, use a service/API account without MFA. Response: $($tokenResp | ConvertTo-Json -Compress)"
}
$headers = @{ Authorization = "Bearer $($tokenResp.access_token)"; Accept = 'application/json' }

function Invoke-Vbaz([string]$Path) {
    Invoke-RestMethod @irmArg -Method Get -Uri "$base/api/$script:ApiVersion/$Path" -Headers $headers
}

# Handles offset/limit paging; returns all items of a list endpoint
function Get-VbazAll([string]$Path) {
    $offset = 0; $limit = 100; $all = @()
    do {
        $sep  = if ($Path.Contains('?')) { '&' } else { '?' }
        $resp = Invoke-Vbaz "$Path${sep}offset=$offset&limit=$limit"
        if ($null -eq $resp.results) { return @($resp) }     # non-paged endpoint
        $all   += $resp.results
        $offset += $limit
    } while ($all.Count -lt $resp.totalCount -and $resp.results.Count -gt 0)
    $all
}

# ---------- API version ----------
if (-not $ApiVersion) {
    foreach ($v in 'v8','v7','v6','v5','v4') {
        try {
            $null = Invoke-RestMethod @irmArg -Uri "$base/api/$v/repositories?limit=1" -Headers $headers
            $ApiVersion = $v; break
        } catch { }
    }
    if (-not $ApiVersion) { throw "Could not detect a working API version on $base" }
}
Write-Host "Connected to $Server, API $ApiVersion" -ForegroundColor Green

# ---------- Repositories ----------
$repos   = Get-VbazAll 'repositories'
$repoMap = @{}
foreach ($r in $repos) { $repoMap[$r.id] = $r }

function Get-RepoRegion($r)  { if ($r) { $r.regionName ?? $r.region.name ?? $r.regionId ?? $r.region } }
function Get-RepoType($r)    { if ($r) { $r.storageTier ?? $r.tier } }
function Get-RepoAccount($r) {
    if ($r) { $r.storageAccountName ?? $r.azureStorageAccountName ?? $r.storageAccount.name ?? $r.azureStorageAccount.name ?? $r.accountName ?? $r.storageAccount ?? $r.azureStorageAccount }
}

function Get-RepoLabel($id) {
    $r = $repoMap[$id]
    if (-not $r) { return "<unknown repo $id>" }
    $parts = @($r.name, (Get-RepoRegion $r), (Get-RepoType $r)) | Where-Object { $_ }
    $parts -join ' | '
}

# Warn once if a field could not be resolved, listing the real property names to fix the mapping
foreach ($r in $repos) {
    if (-not (Get-RepoAccount $r) -or -not (Get-RepoRegion $r)) {
        Write-Warning "Repository '$($r.name)': storage account or region not found. Available properties: $($r.PSObject.Properties.Name -join ', ')"
    }
}

# Repository columns per schedule (Daily/Weekly/Monthly/Yearly): Name, StorageAccount, Region, Type
$scheduleProps = [ordered]@{ Daily = 'dailySchedule'; Weekly = 'weeklySchedule'; Monthly = 'monthlySchedule'; Yearly = 'yearlySchedule' }

function Get-RepoColumns($policy) {
    $cols = [ordered]@{}
    $seen = @()
    foreach ($label in $scheduleProps.Keys) {
        $ids = @(Find-RepositoryIds $policy.($scheduleProps[$label]) | Select-Object -Unique)
        $seen += $ids
        $rs  = @($ids | ForEach-Object { $repoMap[$_] })
        $cols["${label}_Repository"]     = ($ids | ForEach-Object { $repoMap[$_].name ?? "<unknown repo $_>" }) -join '; '
        $cols["${label}_StorageAccount"] = ($rs | ForEach-Object { Get-RepoAccount $_ }) -join '; '
        $cols["${label}_Region"]         = ($rs | ForEach-Object { Get-RepoRegion  $_ }) -join '; '
        $cols["${label}_Type"]           = ($rs | ForEach-Object { Get-RepoType    $_ }) -join '; '
    }
    # repository references outside the daily/weekly/monthly/yearly schedules (e.g. other workload types)
    $other = @(Find-RepositoryIds $policy | Select-Object -Unique | Where-Object { $_ -notin $seen })
    if ($other) {
        $rs = @($other | ForEach-Object { $repoMap[$_] })
        $cols['Other_Repository']     = ($other | ForEach-Object { $repoMap[$_].name ?? "<unknown repo $_>" }) -join '; '
        $cols['Other_StorageAccount'] = ($rs | ForEach-Object { Get-RepoAccount $_ }) -join '; '
        $cols['Other_Region']         = ($rs | ForEach-Object { Get-RepoRegion  $_ }) -join '; '
        $cols['Other_Type']           = ($rs | ForEach-Object { Get-RepoType    $_ }) -join '; '
    }
    $cols
}

# ---------- Generic walkers ----------
# Collect every value whose property name ends with "RepositoryId" (anywhere in the policy)
function Find-RepositoryIds($obj) {
    if ($null -eq $obj -or $obj -is [string] -or $obj.GetType().IsValueType) { return }
    if ($obj -is [System.Collections.IEnumerable]) { foreach ($i in $obj) { Find-RepositoryIds $i }; return }
    foreach ($p in $obj.PSObject.Properties) {
        if ($p.Name -match 'RepositoryId$' -and $p.Value) { $p.Value }
        else { Find-RepositoryIds $p.Value }
    }
}

# Collect retention-like leaf settings inside *Schedule objects, with their path
function Find-Retention($obj, [string]$path = '') {
    if ($null -eq $obj) { return }
    if ($obj -is [System.Collections.IEnumerable] -and $obj -isnot [string]) {
        $i = 0; foreach ($e in $obj) { Find-Retention $e "$path[$i]"; $i++ }; return
    }
    foreach ($p in $obj.PSObject.Properties) {
        $here = if ($path) { "$path.$($p.Name)" } else { $p.Name }
        $v = $p.Value
        if ($null -eq $v) { continue }
        if ($v -is [string] -or $v.GetType().IsValueType) {
            if ($here -match 'Schedule' -and $p.Name -match 'retention|ToKeep|Count$|Duration|Type$' -and $p.Name -notmatch 'dailyType') {
                [pscustomobject]@{ Path = $here; Value = $v }
            }
        } else {
            Find-Retention $v $here
        }
    }
}

# Turn the flat retention list into a short human-readable string per schedule
function Format-Retention($rows) {
    $rows | Group-Object { ($_.Path -split '\.')[0] } | ForEach-Object {
        $vals = $_.Group | ForEach-Object { "{0}={1}" -f ($_.Path -replace '^[^.]+\.', ''), $_.Value }
        "{0}: {1}" -f $_.Name, ($vals -join ', ')
    }
}

# Workload regions: any property named *region* / *regions* in the policy (repository refs excluded)
function Find-Regions($obj) {
    if ($null -eq $obj -or $obj -is [string] -or $obj.GetType().IsValueType) { return }
    if ($obj -is [System.Collections.IEnumerable]) { foreach ($i in $obj) { Find-Regions $i }; return }
    foreach ($p in $obj.PSObject.Properties) {
        if ($null -eq $p.Value) { continue }
        if ($p.Name -match 'region' -and $p.Name -notmatch 'Id$|repository') {
            foreach ($v in @($p.Value)) {
                if ($v -is [string]) { $v } else { $v.name ?? $v.regionName ?? $v.displayName ?? $v.regionId ?? $v.id }
            }
        } elseif ($p.Name -notmatch 'Schedule$') {
            Find-Regions $p.Value
        }
    }
}

function Get-RegionNames($policy) {
    $names = @(Find-Regions $policy | Where-Object { $_ } | Select-Object -Unique)
    if (-not $names) {
        Write-Warning "Policy '$($policy.name)': no regions found. Top-level properties: $($policy.PSObject.Properties.Name -join ', ')"
    }
    $names
}

# ---------- Policies ----------
$policyTypes = [ordered]@{
    'VirtualMachine' = 'policies/virtualMachines'
    'SQL'            = 'policies/sql'
    'FileShare'      = 'policies/fileShares'
    'CosmosDB'       = 'policies/cosmosDb'
    'PostgreSQL'     = 'policies/postgreSql'
    'MySQL'          = 'policies/mySql'
}

New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
$repos | ConvertTo-Json -Depth 20 | Set-Content (Join-Path $OutDir 'repositories.raw.json')

$detail  = [System.Collections.Generic.List[object]]::new()
$lines   = [System.Collections.Generic.List[string]]::new()
$raw     = [ordered]@{}

foreach ($type in $policyTypes.Keys) {
    try { $list = Get-VbazAll $policyTypes[$type] }
    catch {
        Write-Verbose "Skipping $type ($($policyTypes[$type])): $($_.Exception.Message)"
        continue
    }
    $raw[$type] = @()
    foreach ($item in $list) {
        # fetch the full object; list results can be trimmed
        $p = try { Invoke-Vbaz "$($policyTypes[$type])/$($item.id)" } catch { $item }
        $raw[$type] += $p

        $retRows  = @(Find-Retention $p)
        $repoCols = Get-RepoColumns $p

        # one row per job: base + repository columns per schedule + one column per retention setting
        $d = [ordered]@{
            Policy  = $p.name
            Type    = $type
            Enabled = $p.isEnabled
            Regions = (Get-RegionNames $p) -join '; '
        }
        foreach ($k in $repoCols.Keys) { $d[$k] = $repoCols[$k] }
        foreach ($r in $retRows) { $d[$r.Path] = $r.Value }
        $detail.Add($d)

        # one console line per job
        $repoText = foreach ($label in @($scheduleProps.Keys) + 'Other') {
            if ($d["${label}_Repository"]) {
                "{0}: {1} ({2}, {3}, {4})" -f $label, $d["${label}_Repository"], $d["${label}_StorageAccount"], $d["${label}_Region"], $d["${label}_Type"]
            }
        }
        $lines.Add(("{0} [{1}] Enabled={2} | Regions: {3} | Retention: {4} | Repos: {5}" -f `
            $d.Policy, $d.Type, $d.Enabled, $d.Regions, ((Format-Retention $retRows) -join ' || '), ($repoText -join '; ')))
    }
}

# ---------- Output ----------
$raw | ConvertTo-Json -Depth 30 | Set-Content (Join-Path $OutDir 'policies.raw.json')
# Union of all columns across jobs (Export-Csv would otherwise use only the first row's columns)
function Export-WideCsv($rows, [string]$file) {
    $columns = [System.Collections.Generic.List[string]]::new()
    foreach ($d in $rows) { foreach ($k in $d.Keys) { if (-not $columns.Contains($k)) { $columns.Add($k) } } }
    $rows | ForEach-Object {
        $o = [ordered]@{}
        foreach ($c in $columns) { $o[$c] = $_[$c] }
        [pscustomobject]$o
    } | Export-Csv (Join-Path $OutDir $file) -NoTypeInformation -Encoding utf8
}
Export-WideCsv $detail 'policies-retention.csv'

# One line per backup job
$lines
Write-Host "`nRepositories:" -ForegroundColor Cyan
$repos | ForEach-Object { [pscustomobject]@{ Name = $_.name; Label = Get-RepoLabel $_.id; Id = $_.id } } | Format-Table -AutoSize
Write-Host "Export written to $OutDir" -ForegroundColor Green
