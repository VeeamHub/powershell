<#
.SYNOPSIS
    Restores Veeam Backup for Microsoft 365 configuration from an export.

.DESCRIPTION
    Reads the output produced by Export-VB365Config_v2.ps1 (with -IncludeJobs) and
    restores configuration on a fresh VB365 installation.

    Scope:
      • Re-register M365 organizations with modern app-only authentication (certificate)
      • Create missing cloud storage accounts (prompts for secret keys)
      • Add object storage repositories to the default backup proxy and synchronise them
      • Create backup jobs from exported Jobs\BackupJob_*.json files
      • Create backup copy jobs from exported Jobs\BackupCopyJob_*.json files

    Idempotent: organizations, repositories, and jobs that already exist by name are skipped.

    Repository and organization matching uses NAME — IDs change on a fresh installation.

.PARAMETER ImportPath
    Root folder of a previous export — the timestamped sub-folder created by
    Export-VB365Config_v2.ps1 (e.g. "C:\VB365Export\VB365_20260630_120000").

.PARAMETER Server
    VB365 server hostname or IP. Defaults to localhost.

.PARAMETER Port
    Optional. Only needed when connecting to a remote VB365 server on a non-default port.

.PARAMETER Credential
    PSCredential for the VB365 server. Omit to use the current Windows session.

.PARAMETER CertificatePassword
    Password that was used when the PFX files were exported. Required.

.PARAMETER WhatIf
    Show what would be done without making any changes.

.EXAMPLE
    .\Import-VB365Config_v2.ps1 `
        -ImportPath "C:\VB365Export\VB365_20260630_120000" `
        -CertificatePassword (Read-Host -AsSecureString "PFX password")
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][string]       $ImportPath,
    [string]                             $Server     = 'localhost',
    [Nullable[int]]                      $Port       = $null,
    [PSCredential]                       $Credential = $null,
    [Parameter(Mandatory)][string]       $CertificatePassword,
    [switch]                             $SyncRepositories
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── Output helpers ────────────────────────────────────────────────────────────
function Write-Step { param($m) Write-Host "  $m"         -ForegroundColor Cyan     }
function Write-Ok   { param($m) Write-Host "  [OK]  $m"   -ForegroundColor Green    }
function Write-Warn { param($m) Write-Host "  [WARN] $m"  -ForegroundColor Yellow   }
function Write-Fail { param($m) Write-Host "  [FAIL] $m"  -ForegroundColor Red      }
function Write-Skip { param($m) Write-Host "  [SKIP] $m"  -ForegroundColor DarkGray }
function Write-Info { param($m) Write-Host "  [INFO] $m"  -ForegroundColor White    }

# Convert plain-text password to SecureString (parameter accepts both forms)
$CertificatePasswordSecure = $CertificatePassword | ConvertTo-SecureString -AsPlainText -Force

# ── Validate import folder ────────────────────────────────────────────────────
if (-not (Test-Path $ImportPath -PathType Container)) {
    throw "Import path not found: $ImportPath"
}

$orgsJson = Join-Path $ImportPath 'Organizations.json'
$certDir  = Join-Path $ImportPath 'Certificates'

if (-not (Test-Path $orgsJson)) { throw "Organizations.json not found in: $ImportPath" }
if (-not (Test-Path $certDir -PathType Container)) { throw "Certificates folder not found in: $ImportPath" }

Write-Host ""
Write-Host "VB365 Configuration Import v2" -ForegroundColor Magenta
Write-Host "  Import path : $ImportPath"
Write-Host "  Server      : $Server"
Write-Host ""

# ── Load VB365 module ─────────────────────────────────────────────────────────
Write-Step "Loading Veeam.Archiver.PowerShell module"
if (-not (Get-Module -ListAvailable -Name Veeam.Archiver.PowerShell)) {
    throw "Veeam.Archiver.PowerShell module not found. Run this script on a VB365 server."
}
Import-Module Veeam.Archiver.PowerShell -ErrorAction Stop
Write-Ok "Module loaded"

# ── Connect ───────────────────────────────────────────────────────────────────
Write-Step "Connecting to VB365 server"
$connectParams = @{}
if ($Server -notin @('localhost', '127.0.0.1', $env:COMPUTERNAME)) {
    $connectParams['Server'] = $Server
    if ($null -ne $Port) { $connectParams['Port'] = $Port }
}
if ($Credential) { $connectParams['Credential'] = $Credential }
Connect-VBOServer @connectParams
Write-Ok "Connected"

# ── Read export data ──────────────────────────────────────────────────────────
Write-Step "Reading Organizations.json"
$exportedOrgs = Get-Content $orgsJson -Raw | ConvertFrom-Json
Write-Ok "$($exportedOrgs.Count) organization(s) in export"

$existingOrgs = @(Get-VBOOrganization)
Write-Info "Organizations already registered: $($existingOrgs.Count)"

# ── Organizations ─────────────────────────────────────────────────────────────
$stats = @{ Registered = 0; Skipped = 0; Failed = 0 }

foreach ($exportedOrg in $exportedOrgs) {
    $orgName = $exportedOrg.Name
    $orgType = $exportedOrg.Type
    $region  = if ($exportedOrg.Region) { $exportedOrg.Region } else { 'Worldwide' }

    Write-Host ""
    Write-Step "Organization: $orgName  (Type: $orgType  Region: $region)"

    $alreadyExists = $existingOrgs | Where-Object { $_.Name -eq $orgName } | Select-Object -First 1
    if ($alreadyExists) {
        Write-Skip "$orgName is already registered — skipping"
        $stats.Skipped++
        continue
    }

    $useVeeamAAD = $exportedOrg.PSObject.Properties['UseVeeamAADApplication'] -and [bool]$exportedOrg.UseVeeamAADApplication
    $backupApps  = @($exportedOrg.BackupApplications)

    if ($useVeeamAAD) {
        # ── Veeam AAD application mode — no custom cert required ─────────────
        Write-Info "  Auth mode      : Veeam AAD application"
        Write-Step "  Registering organization"
        if ($PSCmdlet.ShouldProcess($orgName, "Add-VBOOrganization")) {
            try {
                $newOrg = Add-VBOOrganization `
                    -Name                  $orgName `
                    -Region                $region `
                    -UseVeeamAADApplication `
                    -EnableOffice365Teams
                Write-Ok "Registered: $orgName"
                $stats.Registered++
                $existingOrgs += $newOrg
            } catch {
                Write-Fail "Add-VBOOrganization failed for $orgName`: $_"
                $stats.Failed++
            }
        } else {
            Write-Info "[WhatIf] Add-VBOOrganization -Name '$orgName' -Region '$region' -UseVeeamAADApplication"
        }
    } else {
        # ── Custom backup application / certificate mode ──────────────────────
        if ($backupApps.Count -eq 0) {
            Write-Fail "No backup application entries in export for $orgName"
            $stats.Failed++
            continue
        }

        $appEntry = $backupApps[0]

        if (-not $appEntry.ApplicationId) {
            Write-Fail "No ApplicationId in export for $orgName"
            $stats.Failed++
            continue
        }
        if (-not $appEntry.CertificateExportFile) {
            Write-Fail "No certificate export file recorded for $orgName"
            $stats.Failed++
            continue
        }

        $pfxPath = Join-Path $certDir $appEntry.CertificateExportFile
        if (-not (Test-Path $pfxPath)) {
            Write-Fail "PFX file not found: $pfxPath"
            $stats.Failed++
            continue
        }

        Write-Info "  Application ID : $($appEntry.ApplicationId)"
        Write-Info "  Certificate    : $($appEntry.CertificateExportFile)"
        if ($appEntry.CertificateExpiry) { Write-Info "  Cert expiry    : $($appEntry.CertificateExpiry)" }

        $impersonationAcct = if ($appEntry.PSObject.Properties['ImpersonationAccountName']) { $appEntry.ImpersonationAccountName } else { $null }
        $officeOrgName     = if ($appEntry.PSObject.Properties['OfficeOrganizationName'])   { $appEntry.OfficeOrganizationName }   else { $null }

        $authAccountParam = if ($impersonationAcct) {
            @{ ImpersonationAccountName = $impersonationAcct }
        } elseif ($officeOrgName) {
            @{ OfficeOrganizationName = $officeOrgName }
        } else {
            @{ OfficeOrganizationName = $orgName }
        }

        $authLabel = if ($impersonationAcct) { "ImpersonationAccount: $impersonationAcct" } `
                     elseif ($officeOrgName)  { "OfficeOrganizationName: $officeOrgName" } `
                     else                     { "OfficeOrganizationName: $orgName (fallback)" }

        Write-Step "  Building connection settings  ($authLabel)"
        $connSettings = $null
        if ($PSCmdlet.ShouldProcess($orgName, "New-VBOOffice365ApplicationOnlyConnectionSettings")) {
            try {
                $connSettings = New-VBOOffice365ApplicationOnlyConnectionSettings `
                    -ApplicationId                  ([guid]$appEntry.ApplicationId) `
                    -ApplicationCertificatePath     $pfxPath `
                    -ApplicationCertificatePassword $CertificatePasswordSecure `
                    @authAccountParam
                Write-Ok "  Connection settings created"
            } catch {
                Write-Fail "New-VBOOffice365ApplicationOnlyConnectionSettings failed: $_"
                $stats.Failed++
                continue
            }
        } else {
            Write-Info "[WhatIf] New-VBOOffice365ApplicationOnlyConnectionSettings -ApplicationId '$($appEntry.ApplicationId)'"
        }

        Write-Step "  Registering organization"
        if ($PSCmdlet.ShouldProcess($orgName, "Add-VBOOrganization")) {
            try {
                $newOrg = Add-VBOOrganization `
                    -Name                                   $orgName `
                    -Region                                 $region `
                    -Office365ExchangeConnectionsSettings   $connSettings `
                    -Office365SharePointConnectionsSettings $connSettings `
                    -EnableOffice365Teams
                Write-Ok "Registered: $orgName"
                $stats.Registered++
                $existingOrgs += $newOrg
            } catch {
                Write-Fail "Add-VBOOrganization failed for $orgName`: $_"
                $stats.Failed++
            }
        } else {
            Write-Info "[WhatIf] Add-VBOOrganization -Name '$orgName' -Region '$region'"
        }
    }
}

# ── Object Storage Repositories ──────────────────────────────────────────────
Write-Host ""
Write-Step "Adding object storage repositories to default backup proxy"

$reposJson = Join-Path $ImportPath 'Repositories.json'
$credsJson  = Join-Path $ImportPath 'CloudCredentials.json'

$repoStats       = @{ Added = 0; Skipped = 0; Failed = 0 }
$proxySyncNeeded = $false
$addedRepoNames  = [System.Collections.Generic.List[string]]::new()

if (-not (Test-Path $reposJson)) {
    Write-Warn "Repositories.json not found — skipping repository import"
} elseif (-not (Test-Path $credsJson)) {
    Write-Warn "CloudCredentials.json not found — skipping repository import"
} else {
    $exportedRepos = Get-Content $reposJson -Raw | ConvertFrom-Json
    $cloudCreds    = Get-Content $credsJson -Raw | ConvertFrom-Json

    $defaultProxy = @(Get-VBOProxy) | Select-Object -First 1
    if (-not $defaultProxy) {
        Write-Fail "No backup proxy found — cannot assign repositories"
    } else {
        Write-Ok "Default proxy: $($defaultProxy.Hostname)"

        $osRepos = @($exportedRepos | Where-Object { $_.IsObjectStorageRepo -eq $true })
        Write-Info "Object storage repositories in export: $($osRepos.Count)"

        # ── Pre-flight: ensure all required cloud accounts exist ──────────────
        $accountCache     = @{}
        $requiredAccounts = [System.Collections.Generic.List[hashtable]]::new()
        foreach ($repo in $osRepos) {
            $osType      = if ($repo.PSObject.Properties['ObjectStorageType'])        { $repo.ObjectStorageType }        else { $null }
            $accountName = if ($repo.PSObject.Properties['ObjectStorageAccountName']) { $repo.ObjectStorageAccountName } else { $null }
            if (-not $osType -or -not $accountName) { continue }
            $key = "$osType|$accountName"
            if (-not ($requiredAccounts | Where-Object { $_['Key'] -eq $key })) {
                $requiredAccounts.Add(@{ Key = $key; Type = $osType; Name = $accountName })
            }
        }

        foreach ($req in $requiredAccounts) {
            $key         = $req['Key']
            $osType      = $req['Type']
            $accountName = $req['Name']

            $existing = $null
            try {
                if ($osType -eq 'AzureBlob') {
                    $existing = Get-VBOAzureBlobAccount -Name $accountName -ErrorAction SilentlyContinue | Select-Object -First 1
                } elseif ($osType -eq 'AmazonS3') {
                    $existing = Get-VBOAmazonS3Account -AccessKey $accountName -ErrorAction SilentlyContinue | Select-Object -First 1
                } elseif ($osType -like 'AmazonS3Compatible*' -or $osType -eq 'IBMCloud' -or $osType -eq 'WasabiCloud') {
                    $existing = Get-VBOAmazonS3CompatibleAccount -AccessKey $accountName -ErrorAction SilentlyContinue | Select-Object -First 1
                }
            } catch { $existing = $null }

            if ($existing) {
                Write-Ok "Cloud account already registered: [$osType] $accountName"
                $accountCache[$key] = $existing
                continue
            }

            Write-Host ""
            Write-Warn "Cloud account not found: [$osType] $accountName"
            Write-Host "  Secret keys are not exportable and must be supplied manually." -ForegroundColor Yellow

            if ($PSCmdlet.ShouldProcess("$osType account '$accountName'", "Add cloud account")) {
                try {
                    if ($osType -eq 'AzureBlob') {
                        $secret = Read-Host -AsSecureString "  Enter Shared Key for Azure Blob account '$accountName'"
                        $accountCache[$key] = Add-VBOAzureBlobAccount -Name $accountName -SharedKey $secret
                        Write-Ok "Created Azure Blob account: $accountName"
                    } elseif ($osType -eq 'AmazonS3') {
                        $secret = Read-Host -AsSecureString "  Enter Secret Access Key for S3 access key '$accountName'"
                        $accountCache[$key] = Add-VBOAmazonS3Account -AccessKey $accountName -SecurityKey $secret
                        Write-Ok "Created Amazon S3 account: $accountName"
                    } elseif ($osType -like 'AmazonS3Compatible*' -or $osType -eq 'IBMCloud' -or $osType -eq 'WasabiCloud') {
                        $secret = Read-Host -AsSecureString "  Enter Secret Key for S3-Compatible access key '$accountName'"
                        $accountCache[$key] = Add-VBOAmazonS3CompatibleAccount -AccessKey $accountName -SecurityKey $secret
                        Write-Ok "Created S3-Compatible account: $accountName"
                    }
                } catch {
                    Write-Fail "Failed to create account '$accountName': $_"
                }
            } else {
                Write-Info "[WhatIf] Add cloud account [$osType] '$accountName'"
            }
        }

        foreach ($repo in $osRepos) {
            $repoName = $repo.Name
            Write-Host ""
            Write-Step "Repository: $repoName"

            $existing = @(Get-VBORepository -Name $repoName -ErrorAction SilentlyContinue) | Select-Object -First 1
            if ($existing) {
                Write-Skip "'$repoName' already exists"
                $repoStats.Skipped++
                continue
            }

            $osType        = if ($repo.PSObject.Properties['ObjectStorageType'])          { $repo.ObjectStorageType }          else { $null }
            $folderName    = if ($repo.PSObject.Properties['ObjectStorageFolderName'])    { $repo.ObjectStorageFolderName }    else { $null }
            $containerName = if ($repo.PSObject.Properties['ObjectStorageContainerName']) { $repo.ObjectStorageContainerName } else { $null }
            $bucketName    = if ($repo.PSObject.Properties['ObjectStorageBucketName'])    { $repo.ObjectStorageBucketName }    else { $null }
            $accountName   = if ($repo.PSObject.Properties['ObjectStorageAccountName'])   { $repo.ObjectStorageAccountName }   else { $null }
            $regionType    = if ($repo.PSObject.Properties['ObjectStorageRegionType'])    { $repo.ObjectStorageRegionType }    else { 'Global' }
            $regionId      = if ($repo.PSObject.Properties['ObjectStorageRegionId'])      { $repo.ObjectStorageRegionId }      else { $null }
            $servicePoint  = if ($repo.PSObject.Properties['ObjectStorageServicePoint'])  { $repo.ObjectStorageServicePoint }  else { $null }
            $customRegion  = if ($repo.PSObject.Properties['ObjectStorageCustomRegionId']){ $repo.ObjectStorageCustomRegionId } else { $null }
            $trustCert     = if ($repo.PSObject.Properties['ObjectStorageTrustCert'])     { [bool]$repo.ObjectStorageTrustCert } else { $false }

            if (-not $osType)      { Write-Warn "'$repoName': ObjectStorageType missing — re-run export";      $repoStats.Failed++; continue }
            if (-not $folderName)  { Write-Warn "'$repoName': ObjectStorageFolderName missing — re-run export"; $repoStats.Failed++; continue }
            if (-not $accountName) { Write-Warn "'$repoName': ObjectStorageAccountName missing — re-run export"; $repoStats.Failed++; continue }

            Write-Info "  Type: $osType  Account: $accountName  Folder: $folderName"

            $cacheKey   = "$osType|$accountName"
            $cachedAcct = if ($accountCache.ContainsKey($cacheKey)) { $accountCache[$cacheKey] } else { $null }
            if (-not $cachedAcct) {
                Write-Fail "Failed to add '$repoName': account '$accountName' is not available (creation failed or was skipped)"
                $repoStats.Failed++
                continue
            }

            try {
                if ($osType -eq 'AzureBlob') {
                    if (-not $containerName) { throw "ObjectStorageContainerName not in export — re-run export script first" }
                    $connBlob  = New-VBOAzureBlobConnectionSettings -Account $cachedAcct -RegionType $regionType
                    $container = Get-VBOAzureBlobContainer -ConnectionSettings $connBlob -Name $containerName
                    $folder    = Get-VBOAzureBlobFolder -Container $container -Name $folderName
                    $settings  = New-VBOAzureBlobObjectStorageSettings -Folder $folder
                    if ($PSCmdlet.ShouldProcess($repoName, "Add-VBOAzureBlobRepository")) {
                        Add-VBOAzureBlobRepository -ObjectStorageSettings $settings -Name $repoName -Proxy $defaultProxy | Out-Null
                        Write-Ok "Added Azure Blob repository: $repoName"
                        $repoStats.Added++; $proxySyncNeeded = $true; $addedRepoNames += $repoName
                    } else { Write-Info "[WhatIf] Add-VBOAzureBlobRepository -Name '$repoName'" }

                } elseif ($osType -eq 'AmazonS3') {
                    $connS3   = New-VBOAmazonS3ConnectionSettings -Account $cachedAcct -RegionType $regionType
                    $bucket   = Get-VBOAmazonS3Bucket -AmazonS3ConnectionSettings $connS3 -Name $bucketName
                    $folder   = Get-VBOAmazonS3Folder -Bucket $bucket -Name $folderName
                    if (-not $folder) { throw "Folder '$folderName' not found in bucket '$bucketName'" }
                    $settings = New-VBOAmazonS3ObjectStorageSettings -Folder $folder
                    if ($PSCmdlet.ShouldProcess($repoName, "Add-VBOAmazonS3Repository")) {
                        Add-VBOAmazonS3Repository -ObjectStorageSettings $settings -Name $repoName -Proxy $defaultProxy | Out-Null
                        Write-Ok "Added Amazon S3 repository: $repoName"
                        $repoStats.Added++; $proxySyncNeeded = $true; $addedRepoNames += $repoName
                    } else { Write-Info "[WhatIf] Add-VBOAmazonS3Repository -Name '$repoName'" }

                } elseif ($osType -like 'AmazonS3Compatible*' -or $osType -eq 'IBMCloud' -or $osType -eq 'WasabiCloud') {
                    if (-not $servicePoint) { throw "ObjectStorageServicePoint not in export for '$repoName'" }
                    $connCompat = New-VBOAmazonS3CompatibleConnectionSettings `
                        -Account                $cachedAcct `
                        -ServicePoint           $servicePoint `
                        -CustomRegionId         $customRegion `
                        -TrustServerCertificate:$trustCert
                    $buckets = @(Get-VBOAmazonS3Bucket -AmazonS3CompatibleConnectionSettings $connCompat)
                    $folder  = $null
                    foreach ($bkt in $buckets) {
                        $match = @(Get-VBOAmazonS3Folder -Bucket $bkt) |
                                 Where-Object { $_.ToString() -eq $folderName } | Select-Object -First 1
                        if ($match) { $folder = $match; break }
                    }
                    if (-not $folder) { throw "Folder '$folderName' not found in any bucket for account '$accountName'" }
                    $settings = New-VBOAmazonS3CompatibleObjectStorageSettings -Folder $folder
                    if ($PSCmdlet.ShouldProcess($repoName, "Add-VBOAmazonS3CompatibleRepository")) {
                        Add-VBOAmazonS3CompatibleRepository -ObjectStorageSettings $settings -Name $repoName -Proxy $defaultProxy | Out-Null
                        Write-Ok "Added S3-Compatible repository: $repoName"
                        $repoStats.Added++; $proxySyncNeeded = $true; $addedRepoNames += $repoName
                    } else { Write-Info "[WhatIf] Add-VBOAmazonS3CompatibleRepository -Name '$repoName'" }

                } else {
                    Write-Warn "'$repoName': Unknown ObjectStorageType '$osType' — skipping"
                    $repoStats.Failed++
                }
            } catch {
                Write-Fail "Failed to add '$repoName': $_"
                $repoStats.Failed++
            }
        }

        if ($proxySyncNeeded -and -not $SyncRepositories) {
            Write-Info "Repository synchronisation skipped — use -SyncRepositories to enable"
        }
        if ($proxySyncNeeded -and $SyncRepositories) {
            Write-Host ""
            Write-Step "Rescanning default proxy: $($defaultProxy.Hostname)"
            if ($PSCmdlet.ShouldProcess($defaultProxy.Hostname, "Sync-VBOProxy")) {
                try { Sync-VBOProxy -Proxy $defaultProxy; Write-Ok "Proxy rescan complete" }
                catch { Write-Warn "Proxy rescan failed: $_" }
            } else { Write-Info "[WhatIf] Sync-VBOProxy -Proxy '$($defaultProxy.Hostname)'" }

            Write-Host ""
            Write-Step "Synchronising added repositories"
            foreach ($rName in $addedRepoNames) {
                $repoObj = Get-VBORepository -Name $rName -ErrorAction SilentlyContinue | Select-Object -First 1
                if (-not $repoObj) { Write-Warn "Could not find repository '$rName' for synchronisation"; continue }
                if ($PSCmdlet.ShouldProcess($rName, "Start-VBORepositorySynchronizeSession")) {
                    try { Start-VBORepositorySynchronizeSession -Repository $repoObj | Out-Null; Write-Ok "Synchronisation started: $rName" }
                    catch { Write-Warn "Synchronisation failed for '$rName': $_" }
                } else { Write-Info "[WhatIf] Start-VBORepositorySynchronizeSession -Repository '$rName'" }
            }
        }
    }
}

# ── Helper: build a VBOJobSchedulePolicy from exported JSON ──────────────────
function New-SchedulePolicyFromExport {
    param($sp)

    $params = @{}

    # EnableSchedule is a SwitchParameter; default is enabled — only act when explicitly false
    if ($sp -and $sp.PSObject.Properties['EnableSchedule'] -and $sp.EnableSchedule -eq $false) {
        $params['EnableSchedule'] = $false
    } else {
        $params['EnableSchedule'] = $true
    }

    $type = if ($sp -and $sp.PSObject.Properties['Type']) { $sp.Type } else { 'Daily' }

    if ($type -eq 'Periodically') {
        $params['Type'] = 'Periodically'
        if ($sp.PSObject.Properties['PeriodicallyEvery'] -and $sp.PeriodicallyEvery) {
            $params['PeriodicallyEvery'] = $sp.PeriodicallyEvery
        }
    } else {
        # Default to Daily
        if ($sp -and $sp.PSObject.Properties['DailyTime'] -and $sp.DailyTime) {
            try { $params['DailyTime'] = [TimeSpan]::Parse($sp.DailyTime) } catch { }
        }
        if ($sp -and $sp.PSObject.Properties['DailyType'] -and $sp.DailyType) {
            $params['DailyType'] = $sp.DailyType
        }
    }

    if ($sp -and $sp.PSObject.Properties['RetryEnabled'] -and $sp.RetryEnabled) {
        $params['RetryEnabled'] = $true
        if ($sp.PSObject.Properties['RetryNumber']       -and $sp.RetryNumber)       { $params['RetryNumber']       = [int]$sp.RetryNumber }
        if ($sp.PSObject.Properties['RetryWaitInterval'] -and $sp.RetryWaitInterval) { $params['RetryWaitInterval'] = [int]$sp.RetryWaitInterval }
    }

    New-VBOJobSchedulePolicy @params
}

# ── Helper: build a VBOCopyJobSchedulePolicy from exported JSON ───────────────
function New-CopySchedulePolicyFromExport {
    param($sp)

    $type = if ($sp -and $sp.PSObject.Properties['Type']) { $sp.Type } else { 'Immediate' }

    if ($type -eq 'Immediate') {
        return New-VBOCopyJobSchedulePolicy
    }

    $params = @{ Type = $type }

    if ($type -eq 'Daily') {
        if ($sp.PSObject.Properties['DailyTime'] -and $sp.DailyTime) {
            try { $params['DailyTime'] = [TimeSpan]::Parse($sp.DailyTime) } catch { }
        }
        if ($sp.PSObject.Properties['DailyType'] -and $sp.DailyType) {
            $params['DailyType'] = $sp.DailyType
        }
    } elseif ($type -eq 'Periodically') {
        if ($sp.PSObject.Properties['PeriodicallyEvery'] -and $sp.PeriodicallyEvery) {
            $params['PeriodicallyEvery'] = $sp.PeriodicallyEvery
        }
    }

    New-VBOCopyJobSchedulePolicy @params
}

# ── Helper: build a VBOBackupItem from an exported item entry ─────────────────
function New-BackupItemFromExport {
    param($item, [object]$org)

    $type = $item.Type

    # Valid New-VBOBackupItem parameter names per item type.
    $validUser  = @('Mailbox','ArchiveMailbox','OneDrive','Sites')
    $validGroup = @('Mailbox','ArchiveMailbox','OneDrive','GroupMailbox','GroupSite')
    $validOrg   = @('Mailbox','ArchiveMailbox','OneDrive','Sites','Teams','TeamsChats')
    $validTeam  = @('TeamsChats')

    # VBOBackupItem property name → New-VBOBackupItem parameter name where they differ.
    # 'Site' (singular, boolean) is the personal SharePoint site flag on User items;
    # the cmdlet parameter is '-Sites' (plural).
    # 'TeamsGroupChats' is how the property appears on the object; the parameter is '-TeamsChats'.
    $propAliases = @{
        'Site'            = 'Sites'
        'TeamsGroupChats' = 'TeamsChats'
    }

    # Build a flag hashtable for the given valid parameter names, checking both the
    # direct property name and any known alias that maps to each parameter.
    function Get-Flags($validParams) {
        $f = @{}
        foreach ($paramName in $validParams) {
            if ($item.PSObject.Properties[$paramName] -and $item.$paramName -eq $true) {
                $f[$paramName] = $true; continue
            }
            foreach ($alias in $propAliases.GetEnumerator()) {
                if ($alias.Value -eq $paramName -and
                    $item.PSObject.Properties[$alias.Key] -and
                    $item.($alias.Key) -eq $true) {
                    $f[$paramName] = $true; break
                }
            }
        }
        $f
    }

    $userFlags  = Get-Flags $validUser
    $groupFlags = Get-Flags $validGroup
    $orgFlags   = Get-Flags $validOrg
    $teamFlags  = Get-Flags $validTeam

    switch ($type) {
        'User' {
            $userName = if ($item.User.PSObject.Properties['UserName']) { $item.User.UserName } else { $item.User.DisplayName }
            $userObj  = Get-VBOOrganizationUser -Organization $org -UserName $userName -ErrorAction SilentlyContinue | Select-Object -First 1
            if (-not $userObj) { throw "User '$userName' not found in org '$($org.Name)'" }
            if ($userFlags.Count -gt 0) { return New-VBOBackupItem -User $userObj @userFlags }
            else                        { return New-VBOBackupItem -User $userObj -Mailbox }
        }
        { $_ -like '*Group*' } {
            $groupDisplayName = if ($item.Group.PSObject.Properties['DisplayName'] -and $item.Group.DisplayName) { $item.Group.DisplayName } else { $item.Group.Name }
            $groupObj = Get-VBOOrganizationGroup -Organization $org -DisplayName $groupDisplayName -ErrorAction SilentlyContinue | Select-Object -First 1
            if (-not $groupObj) { throw "Group '$groupDisplayName' not found in org '$($org.Name)'" }
            if ($groupFlags.Count -gt 0) { return New-VBOBackupItem -Group $groupObj @groupFlags }
            else                         { return New-VBOBackupItem -Group $groupObj -Mailbox }
        }
        'Site' {
            $siteUrl = $item.Site.Url
            $siteObj = Get-VBOOrganizationSite -Organization $org -URL $siteUrl -ErrorAction SilentlyContinue | Select-Object -First 1
            if (-not $siteObj) { throw "Site '$siteUrl' not found in org '$($org.Name)'" }
            return New-VBOBackupItem -Site $siteObj
        }
        'Team' {
            $teamDisplayName = if ($item.Team.PSObject.Properties['DisplayName'] -and $item.Team.DisplayName) { $item.Team.DisplayName } else { $item.Team.Name }
            $teamObj = Get-VBOOrganizationTeam -Organization $org -DisplayName $teamDisplayName -ErrorAction SilentlyContinue | Select-Object -First 1
            if (-not $teamObj) { throw "Team '$teamDisplayName' not found in org '$($org.Name)'" }
            if ($teamFlags.Count -gt 0) { return New-VBOBackupItem -Team $teamObj @teamFlags }
            else                        { return New-VBOBackupItem -Team $teamObj }
        }
        'Organization' {
            if ($orgFlags.Count -gt 0) { return New-VBOBackupItem -Organization $org @orgFlags }
            else                       { return New-VBOBackupItem -Organization $org -Mailbox -OneDrive -Sites -Teams }
        }
        'PersonalSites' {
            return New-VBOBackupItem -PersonalSites
        }
        default {
            throw "Unknown backup item type: $type"
        }
    }
}

# ── Backup Jobs ───────────────────────────────────────────────────────────────
Write-Host ""
Write-Step "Creating backup jobs"

$jobsDir = Join-Path $ImportPath 'Jobs'
$jobStats = @{ Created = 0; Skipped = 0; Failed = 0 }

if (-not (Test-Path $jobsDir -PathType Container)) {
    Write-Warn "Jobs\ folder not found in export — skipping backup job import"
    Write-Warn "Re-run the export with -IncludeJobs to capture job configuration."
} else {
    $jobFiles = @(Get-ChildItem -Path $jobsDir -Filter 'BackupJob_*.json' | Sort-Object Name)
    Write-Info "$($jobFiles.Count) backup job file(s) found"

    # Refresh org list — may have grown during this run
    $existingOrgs = @(Get-VBOOrganization)

    foreach ($jobFile in $jobFiles) {
        $jd = Get-Content $jobFile.FullName -Raw | ConvertFrom-Json
        $jobName = $jd.Name
        Write-Host ""
        Write-Step "Backup job: $jobName"

        # Skip if already exists
        $existingJob = Get-VBOJob -Name $jobName -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($existingJob) {
            Write-Skip "'$jobName' already exists"
            $jobStats.Skipped++
            continue
        }

        # Resolve organization
        $org = $existingOrgs | Where-Object { $_.Name -eq $jd.OrganizationName } | Select-Object -First 1
        if (-not $org) {
            Write-Fail "Organization '$($jd.OrganizationName)' not found — register it first, then re-run"
            $jobStats.Failed++
            continue
        }

        # Resolve repository
        $repo = Get-VBORepository -Name $jd.RepositoryName -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $repo) {
            Write-Fail "Repository '$($jd.RepositoryName)' not found — add it first, then re-run"
            $jobStats.Failed++
            continue
        }

        Write-Info "  Org: $($org.Name)  Repo: $($repo.Name)"

        # Build schedule policy
        $schedulePolicy = $null
        try {
            $schedulePolicy = New-SchedulePolicyFromExport $jd.SchedulePolicy
        } catch {
            Write-Warn "  Could not build schedule policy: $_  — will use default"
            $schedulePolicy = New-VBOJobSchedulePolicy
        }

        # Build Add-VBOJob parameters
        $addParams = @{
            Name           = $jobName
            Organization   = $org
            Repository     = $repo
            SchedulePolicy = $schedulePolicy
        }
        if ($jd.PSObject.Properties['Description'] -and $jd.Description) {
            $addParams['Description'] = $jd.Description
        }

        $isEntireOrg = $jd.PSObject.Properties['IsEntireOrganization'] -and $jd.IsEntireOrganization

        if (-not $isEntireOrg) {
            # Build selected items list
            $selectedItems = [System.Collections.Generic.List[object]]::new()
            $excludedItems = [System.Collections.Generic.List[object]]::new()
            $itemErrors    = 0

            foreach ($itemEntry in @($jd.SelectedItems)) {
                try {
                    $bi = New-BackupItemFromExport -item $itemEntry -org $org
                    $selectedItems.Add($bi)
                } catch {
                    Write-Warn "  Could not resolve selected item ($($itemEntry.Type)): $_"
                    $itemErrors++
                }
            }
            foreach ($itemEntry in @($jd.ExcludedItems)) {
                try {
                    $bi = New-BackupItemFromExport -item $itemEntry -org $org
                    $excludedItems.Add($bi)
                } catch {
                    Write-Warn "  Could not resolve excluded item ($($itemEntry.Type)): $_"
                }
            }

            if ($selectedItems.Count -eq 0) {
                Write-Fail "No resolvable selected items for '$jobName' — skipping"
                $jobStats.Failed++
                continue
            }
            if ($itemErrors -gt 0) {
                Write-Warn "  $itemErrors item(s) could not be resolved and will be omitted"
            }

            $addParams['SelectedItems'] = $selectedItems.ToArray()
            if ($excludedItems.Count -gt 0) { $addParams['ExcludedItems'] = $excludedItems.ToArray() }
        }

        if ($PSCmdlet.ShouldProcess($jobName, "Add-VBOJob")) {
            try {
                if ($isEntireOrg) {
                    Add-VBOJob @addParams -EntireOrganization | Out-Null
                } else {
                    Add-VBOJob @addParams | Out-Null
                }
                Write-Ok "Created backup job: $jobName"
                $jobStats.Created++
            } catch {
                Write-Fail "Add-VBOJob failed for '$jobName': $_"
                $jobStats.Failed++
            }
        } else {
            $scope = if ($isEntireOrg) { 'EntireOrganization' } else { "$($selectedItems.Count) item(s)" }
            Write-Info "[WhatIf] Add-VBOJob -Name '$jobName' -Organization '$($org.Name)' -Repository '$($repo.Name)' [$scope]"
        }
    }
}

# ── Backup Copy Jobs ──────────────────────────────────────────────────────────
Write-Host ""
Write-Step "Creating backup copy jobs"

$copyJobStats = @{ Created = 0; Skipped = 0; Failed = 0 }

if (-not (Test-Path $jobsDir -PathType Container)) {
    Write-Warn "Jobs\ folder not found — skipping backup copy job import"
} else {
    $copyJobFiles = @(Get-ChildItem -Path $jobsDir -Filter 'BackupCopyJob_*.json' | Sort-Object Name)
    Write-Info "$($copyJobFiles.Count) backup copy job file(s) found"

    $existingCopyJobs = @(Get-VBOCopyJob)

    foreach ($cjFile in $copyJobFiles) {
        $cd = Get-Content $cjFile.FullName -Raw | ConvertFrom-Json
        $backupJobName = $cd.BackupJobName
        Write-Host ""
        Write-Step "Copy job for backup job: $backupJobName  → Repo: $($cd.RepositoryName)"

        # Skip if a copy job already exists for this backup job
        $existing = $existingCopyJobs | Where-Object {
            $_.PSObject.Properties['BackupJob'] -and $_.BackupJob -and $_.BackupJob.Name -eq $backupJobName
        } | Select-Object -First 1
        if ($existing) {
            Write-Skip "Copy job for '$backupJobName' already exists"
            $copyJobStats.Skipped++
            continue
        }

        # Resolve source backup job
        $sourceJob = Get-VBOJob -Name $backupJobName -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $sourceJob) {
            Write-Fail "Backup job '$backupJobName' not found — create it first, then re-run"
            $copyJobStats.Failed++
            continue
        }

        # Resolve target repository
        $targetRepo = Get-VBORepository -Name $cd.RepositoryName -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $targetRepo) {
            Write-Fail "Repository '$($cd.RepositoryName)' not found — add it first, then re-run"
            $copyJobStats.Failed++
            continue
        }

        # Build copy schedule policy
        $copySchedule = $null
        try {
            $copySchedule = New-CopySchedulePolicyFromExport $cd.SchedulePolicy
        } catch {
            Write-Warn "  Could not build copy schedule policy: $_ — will use default (Immediate)"
            $copySchedule = New-VBOCopyJobSchedulePolicy
        }

        if ($PSCmdlet.ShouldProcess("copy job for '$backupJobName'", "Add-VBOCopyJob")) {
            try {
                Add-VBOCopyJob -BackupJob $sourceJob -Repository $targetRepo -SchedulePolicy $copySchedule | Out-Null
                Write-Ok "Created copy job for: $backupJobName"
                $copyJobStats.Created++
                # Refresh list for next iteration
                $existingCopyJobs = @(Get-VBOCopyJob)
            } catch {
                Write-Fail "Add-VBOCopyJob failed for '$backupJobName': $_"
                $copyJobStats.Failed++
            }
        } else {
            Write-Info "[WhatIf] Add-VBOCopyJob -BackupJob '$backupJobName' -Repository '$($targetRepo.Name)'"
        }
    }
}

# ── Disconnect ────────────────────────────────────────────────────────────────
Write-Host ""
Disconnect-VBOServer -ErrorAction SilentlyContinue

# ── Summary ───────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "─────────────────────────────────────────" -ForegroundColor Magenta
Write-Host "  Import complete" -ForegroundColor Magenta
Write-Host ""
Write-Host "  Organizations" -ForegroundColor Magenta
Write-Host "    Registered              : $($stats.Registered)"
Write-Host "    Skipped (already exist) : $($stats.Skipped)"
Write-Host "    Failed                  : $($stats.Failed)"
Write-Host ""
Write-Host "  Object storage repositories" -ForegroundColor Magenta
Write-Host "    Added                   : $($repoStats.Added)"
Write-Host "    Skipped (already exist) : $($repoStats.Skipped)"
Write-Host "    Failed                  : $($repoStats.Failed)"
Write-Host ""
Write-Host "  Backup jobs" -ForegroundColor Magenta
Write-Host "    Created                 : $($jobStats.Created)"
Write-Host "    Skipped (already exist) : $($jobStats.Skipped)"
Write-Host "    Failed                  : $($jobStats.Failed)"
Write-Host ""
Write-Host "  Backup copy jobs" -ForegroundColor Magenta
Write-Host "    Created                 : $($copyJobStats.Created)"
Write-Host "    Skipped (already exist) : $($copyJobStats.Skipped)"
Write-Host "    Failed                  : $($copyJobStats.Failed)"
Write-Host "─────────────────────────────────────────" -ForegroundColor Magenta
Write-Host ""
