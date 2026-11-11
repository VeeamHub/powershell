<#
.SYNOPSIS
    Exports Veeam Backup for Microsoft 365 organizational configuration and application registrations.

.DESCRIPTION
    Connects to a VB365 server and exports:
      • Server info, version, component status
      • License details
      • All settings (email, internet proxy, REST API, security, restore portal,
        tenant authentication, history, RBAC roles)
      • Backup proxy servers and pools
      • Repositories (local, Amazon S3, Azure Blob, S3-compatible)
      • Encryption keys
      • Cloud credential registrations:
          – Azure service accounts (app registrations used for Azure object storage)
          – Azure Blob storage accounts
          – Amazon S3 accounts (access key ID exported; secret key is not readable)
          – S3-compatible accounts
      • All organizations with:
          – Backup application certificates (PFX exported from Windows cert store)
          – Version backup options and retention exclusions
      • Backup jobs with schedule and items (requires -IncludeJobs)
      • Backup copy jobs (requires -IncludeJobs)
      • Federated authentication authorities

    NOTE: Cloud account secret keys and passwords are stored encrypted inside VB365
    and cannot be retrieved via PowerShell. Only account metadata (IDs, names, access
    keys) is exported. Secret keys must be re-entered manually during a restore.

    The resulting folder can be used to restore/recreate a VB365 configuration.

.PARAMETER Server
    VB365 server hostname or IP. Defaults to localhost.

.PARAMETER Port
    Optional. Only specify if your VB365 management service was moved to a non-default port.

.PARAMETER Credential
    PSCredential for the VB365 server. Omit to use the current Windows session.

.PARAMETER OutputPath
    Root folder for the export. A timestamped sub-folder is created inside.

.PARAMETER CertificatePassword
    SecureString password for every exported PFX file. Prompted if omitted.

.PARAMETER IncludeJobs
    Also export backup job and backup copy job configuration.

.EXAMPLE
    # Run locally on the VB365 server
    .\Export-VB365Config.ps1 -OutputPath C:\VB365_Backup

.EXAMPLE
    # Remote, explicit credentials, include jobs
    $cred = Get-Credential
    .\Export-VB365Config.ps1 -Server vb365.corp.local -Credential $cred `
        -OutputPath D:\Exports -IncludeJobs

.EXAMPLE
    # Override only if the VB365 management service was moved to a custom port
    .\Export-VB365Config.ps1 -OutputPath C:\VB365_Backup -Port 9191
#>

[CmdletBinding()]
param(
    [string]        $Server = 'localhost',
    # Only set this if your management service runs on a non-default port.
    [Nullable[int]] $Port,
    [PSCredential]  $Credential,
    [Parameter(Mandatory)]
    [string]        $OutputPath,
    [string]        $CertificatePassword,
    [switch]        $IncludeJobs
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

#region ── Helpers ────────────────────────────────────────────────────────────

function Write-Step { param([string]$m) Write-Host "  [*] $m" -ForegroundColor Cyan   }
function Write-Ok   { param([string]$m) Write-Host "  [+] $m" -ForegroundColor Green  }
function Write-Warn { param([string]$m) Write-Host "  [!] $m" -ForegroundColor Yellow }

function ConvertTo-SafeFileName {
    param([string]$Name)
    $Name -replace '[\\/:*?"<>|]', '_'
}

function Invoke-Collect {
    # Run a scriptblock, return the result; on error warn and return $null.
    param([string]$Label, [scriptblock]$ScriptBlock)
    try   { $r = & $ScriptBlock; Write-Ok $Label; return $r }
    catch { Write-Warn "$Label — skipped: $_"; return $null }
}

function ConvertTo-PropertyHashtable {
    # Reflect all readable properties of any object into an ordered hashtable.
    # Depth controls how many levels of nested objects are expanded (default 1 = flat).
    # Primitive types (string, int, bool, Guid, DateTime, enum) are always stringified.
    # Complex nested objects are expanded up to $Depth levels; beyond that .ToString() is used.
    param($Object, [int]$Depth = 1)

    $primitiveTypes = @(
        [string], [int], [long], [double], [float], [bool],
        [datetime], [guid], [timespan]
    )

    $h = [ordered]@{}
    $Object.PSObject.Properties |
        Where-Object { $_.MemberType -in 'NoteProperty','Property' } |
        ForEach-Object {
            $val = $_.Value
            if ($null -eq $val) {
                $h[$_.Name] = $null
            } elseif ($val.GetType().IsEnum -or ($primitiveTypes | Where-Object { $val -is $_ })) {
                $h[$_.Name] = try { $val.ToString() } catch { $null }
            } elseif ($Depth -gt 0) {
                # Recurse into nested object
                try { $h[$_.Name] = ConvertTo-PropertyHashtable $val ($Depth - 1) }
                catch { $h[$_.Name] = try { $val.ToString() } catch { $null } }
            } else {
                $h[$_.Name] = try { $val.ToString() } catch { $null }
            }
        }
    $h
}

function Export-CertificateFromStore {
    param(
        [string]       $Thumbprint,
        [string]       $DestinationPath,
        [SecureString] $Password
    )
    $clean = $Thumbprint -replace '\s', ''
    $stores = 'Cert:\LocalMachine\My','Cert:\CurrentUser\My','Cert:\LocalMachine\Root','Cert:\LocalMachine\CA'
    foreach ($store in $stores) {
        $cert = Get-ChildItem $store -ErrorAction SilentlyContinue |
                Where-Object { $_.Thumbprint -ieq $clean } | Select-Object -First 1
        if ($cert) {
            try {
                Export-PfxCertificate -Cert $cert -FilePath $DestinationPath -Password $Password -Force | Out-Null
                return $true
            } catch { Write-Warn "Found cert in $store but export failed: $_"; return $false }
        }
    }
    Write-Warn "Certificate $clean not found in any local certificate store."
    return $false
}

#endregion

#region ── Initialise output directory ───────────────────────────────────────

$timestamp  = Get-Date -Format 'yyyyMMdd_HHmmss'
$exportRoot = Join-Path $OutputPath "VB365_Export_$timestamp"
$certDir    = Join-Path $exportRoot 'Certificates'

New-Item -ItemType Directory -Path $exportRoot -Force | Out-Null
New-Item -ItemType Directory -Path $certDir    -Force | Out-Null

Write-Host "`nVeeam Backup for Microsoft 365 — Configuration Export" -ForegroundColor White
Write-Host "Output : $exportRoot`n"

#endregion

#region ── Certificate password ──────────────────────────────────────────────

if (-not $CertificatePassword) {
    Write-Host "A password is required to protect exported PFX files." -ForegroundColor Yellow
    $CertificatePasswordSecure = Read-Host -AsSecureString -Prompt "PFX export password"
} else {
    $CertificatePasswordSecure = $CertificatePassword | ConvertTo-SecureString -AsPlainText -Force
}

#endregion

#region ── Load module ───────────────────────────────────────────────────────

Write-Step "Loading Veeam.Archiver.PowerShell module"
if (-not (Get-Module -ListAvailable -Name 'Veeam.Archiver.PowerShell')) {
    throw "Veeam.Archiver.PowerShell module not found. Run this script on the VB365 server."
}
Import-Module Veeam.Archiver.PowerShell -DisableNameChecking -ErrorAction Stop
Write-Ok "Module loaded"

#endregion

#region ── Connect ───────────────────────────────────────────────────────────

Write-Step "Connecting to VB365 server: $Server"

$connectParams = @{}
# Only pass Server/Port when connecting remotely — supplying 'localhost' explicitly
# causes a handshake failure; omitting it lets the module connect to the local service directly.
if ($Server -notin @('localhost', '127.0.0.1', $env:COMPUTERNAME)) {
    $connectParams['Server'] = $Server
    if ($null -ne $Port) { $connectParams['Port'] = $Port }
}
if ($Credential) { $connectParams['Credential'] = $Credential }

Connect-VBOServer @connectParams
Write-Ok "Connected"

#endregion

#region ── SERVER INFO ───────────────────────────────────────────────────────

Write-Step "Collecting server information"

$serverInfo = [ordered]@{
    ExportDate = (Get-Date -Format 'o')
    Server     = $Server
    Port       = $Port
}

$serverInfo['Version'] = Invoke-Collect "Version" {
    $v = Get-VBOVersion
    [ordered]@{ ProductVersion = $v.ProductVersion; Build = if ($v.PSObject.Properties['Build']) { $v.Build } else { $null } }
}

$serverInfo['ServerComponents'] = Invoke-Collect "Server components" {
    Get-VBOServerComponents | ForEach-Object {
        [ordered]@{
            Name    = $_.Name
            Version = if ($_.PSObject.Properties['Version']) { $_.Version.ToString() } else { $null }
            Status  = if ($_.PSObject.Properties['Status'])  { $_.Status.ToString()  } else { $null }
        }
    }
}

$serverInfo['License'] = Invoke-Collect "License" {
    $lic = Get-VBOLicense
    [ordered]@{
        Status         = $lic.Status.ToString()
        Type           = $lic.Type.ToString()
        ExpirationDate = $lic.ExpirationDate.ToString('o')
        TotalNumber    = $lic.TotalNumber
    }
}

$serverInfo['EmailSettings'] = Invoke-Collect "Email settings" {
    $s = Get-VBOEmailSettings
    [ordered]@{
        EnableNotification = $s.EnableNotification
        SMTPServer         = $s.SMTPServer
        Port               = $s.Port
        UseSSL             = $s.UseSSL
        UseAuthentication  = $s.UseAuthentication
        From               = $s.From
        To                 = $s.To
    }
}

$serverInfo['InternetProxySettings']  = Invoke-Collect "Internet proxy settings"          { ConvertTo-PropertyHashtable (Get-VBOInternetProxySettings) }
$serverInfo['RestAPISettings']        = Invoke-Collect "REST API settings"                { ConvertTo-PropertyHashtable (Get-VBORestAPISettings) }
$serverInfo['SecuritySettings']       = Invoke-Collect "Security settings"                { ConvertTo-PropertyHashtable (Get-VBOSecuritySettings) }
$serverInfo['RestorePortalSettings']  = Invoke-Collect "Restore portal settings"          { ConvertTo-PropertyHashtable (Get-VBORestorePortalSettings) }
$serverInfo['OperatorAuthSettings']   = Invoke-Collect "Operator authentication settings" { ConvertTo-PropertyHashtable (Get-VBOOperatorAuthenticationSettings) }
$serverInfo['TenantAuthSettings']     = Invoke-Collect "Tenant authentication settings"   { ConvertTo-PropertyHashtable (Get-VBOTenantAuthenticationSettings) }
$serverInfo['HistorySettings']        = Invoke-Collect "History settings"                 { ConvertTo-PropertyHashtable (Get-VBOHistorySettings) }
$serverInfo['FolderExclusions']       = Invoke-Collect "Global folder exclusions"         { ConvertTo-PropertyHashtable (Get-VBOFolderExclusions) }

$serverInfo['GlobalRetentionExclusions'] = Invoke-Collect "Global retention exclusions" {
    @(Get-VBOGlobalRetentionExclusion | ForEach-Object { ConvertTo-PropertyHashtable $_ })
}

$serverInfo['RbacRoles'] = Invoke-Collect "RBAC roles" {
    @(Get-VBORbacRole | ForEach-Object {
        [ordered]@{
            Id          = $_.Id.ToString()
            Name        = $_.Name
            Description = $_.Description
            RoleType    = if ($_.PSObject.Properties['RoleType']) { $_.RoleType.ToString() } else { $null }
        }
    })
}

$serverInfo['FederatedAuthAuthorities'] = Invoke-Collect "Federated authentication authorities" {
    @(Get-VBOFederatedAuthenticationAuthority | ForEach-Object {
        [ordered]@{
            Id      = $_.Id.ToString()
            Name    = if ($_.PSObject.Properties['Name'])    { $_.Name }    else { $null }
            Issuer  = if ($_.PSObject.Properties['Issuer'])  { $_.Issuer }  else { $null }
            JwksUri = if ($_.PSObject.Properties['JwksUri']) { $_.JwksUri } else { $null }
        }
    })
}

$serverInfo | ConvertTo-Json -Depth 10 | Set-Content -Path (Join-Path $exportRoot 'ServerInfo.json') -Encoding UTF8

#endregion

#region ── BACKUP PROXY SERVERS & POOLS ──────────────────────────────────────

Write-Step "Collecting backup proxy servers"

$proxies = Invoke-Collect "Backup proxy servers" {
    @(Get-VBOProxy | ForEach-Object {
        [ordered]@{
            Id          = $_.Id.ToString()
            Hostname    = $_.Hostname
            Description = $_.Description
            Type        = if ($_.PSObject.Properties['Type'])   { $_.Type.ToString() }   else { $null }
            Port        = if ($_.PSObject.Properties['Port'])   { $_.Port }              else { $null }
            Status      = if ($_.PSObject.Properties['Status']) { $_.Status.ToString() } else { $null }
        }
    })
}
if ($proxies) { $proxies | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $exportRoot 'ProxyServers.json') -Encoding UTF8 }

$proxyPools = Invoke-Collect "Backup proxy pools" {
    @(Get-VBOProxyPool | ForEach-Object {
        [ordered]@{
            Id          = $_.Id.ToString()
            Name        = $_.Name
            Description = $_.Description
            Proxies     = @($_.Proxies | ForEach-Object { $_.Hostname })
        }
    })
}
if ($proxyPools) { $proxyPools | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $exportRoot 'ProxyPools.json') -Encoding UTF8 }

#endregion

#region ── ENCRYPTION KEYS ───────────────────────────────────────────────────

Write-Step "Collecting encryption keys"

$encKeys = Invoke-Collect "Encryption keys" {
    @(Get-VBOEncryptionKey | ForEach-Object {
        [ordered]@{
            Id          = $_.Id.ToString()
            Description = $_.Description
            Hint        = if ($_.PSObject.Properties['Hint']) { $_.Hint } else { $null }
        }
    })
}
if ($encKeys) { $encKeys | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $exportRoot 'EncryptionKeys.json') -Encoding UTF8 }

#endregion

#region ── CLOUD CREDENTIAL REGISTRATIONS ────────────────────────────────────
# Secret keys and passwords are stored encrypted inside VB365 and cannot be
# retrieved via PowerShell. Only account metadata is exported here.
# Secret keys must be re-entered manually when restoring the configuration.

Write-Step "Collecting cloud credential registrations"

$cloudCreds = [ordered]@{
    ExportNote = "Secret keys and passwords are NOT included — they are stored encrypted and cannot be retrieved. Re-enter them manually during restore."
}

$cloudCreds['AzureServiceAccounts'] = Invoke-Collect "Azure service accounts" {
    @(Get-VBOAzureServiceAccount | ForEach-Object {
        $acct   = $_
        $detail = ConvertTo-PropertyHashtable $acct

        $thumbprint = if ($acct.PSObject.Properties['ApplicationCertificateThumbprint']) { $acct.ApplicationCertificateThumbprint } else { $null }
        $detail['CertificateExportFile'] = $null
        $detail['CertificateExported']   = $false
        $detail['CertificateExpiry']     = $null

        if ($thumbprint) {
            $safe    = ConvertTo-SafeFileName $acct.ApplicationId.ToString()
            $short   = $thumbprint.Substring(0, [Math]::Min(8, $thumbprint.Length))
            $pfxName = "AzureServiceAccount_{0}_{1}.pfx" -f $safe, $short
            $pfxPath = Join-Path $certDir $pfxName

            $exported = Export-CertificateFromStore -Thumbprint $thumbprint -DestinationPath $pfxPath -Password $CertificatePasswordSecure

            $clean = $thumbprint -replace '\s', ''
            foreach ($store in @('Cert:\LocalMachine\My','Cert:\CurrentUser\My','Cert:\LocalMachine\Root','Cert:\LocalMachine\CA')) {
                $certObj = Get-ChildItem $store -ErrorAction SilentlyContinue |
                           Where-Object { $_.Thumbprint -ieq $clean } | Select-Object -First 1
                if ($certObj) { $detail['CertificateExpiry'] = $certObj.NotAfter.ToString('o'); break }
            }

            $detail['CertificateExportFile'] = if ($exported) { $pfxName } else { $null }
            $detail['CertificateExported']   = $exported

            $status = if ($exported) { "(cert exported)" } else { "(cert NOT found in local store)" }
            Write-Ok "    Azure service account '$($acct.Name)' | Thumbprint: $thumbprint $status"
        }

        $detail
    })
}

$cloudCreds['AzureBlobAccounts'] = Invoke-Collect "Azure Blob storage accounts" {
    @(Get-VBOAzureBlobAccount | ForEach-Object { ConvertTo-PropertyHashtable $_ })
}

$cloudCreds['AmazonS3Accounts'] = Invoke-Collect "Amazon S3 accounts" {
    @(Get-VBOAmazonS3Account | ForEach-Object { ConvertTo-PropertyHashtable $_ })
}

$cloudCreds['AmazonS3CompatibleAccounts'] = Invoke-Collect "Amazon S3-compatible accounts" {
    @(Get-VBOAmazonS3CompatibleAccount | ForEach-Object { ConvertTo-PropertyHashtable $_ })
}

$cloudCreds | ConvertTo-Json -Depth 10 | Set-Content -Path (Join-Path $exportRoot 'CloudCredentials.json') -Encoding UTF8

#endregion

#region ── REPOSITORIES ──────────────────────────────────────────────────────

Write-Step "Collecting repositories"

$repos = Invoke-Collect "Repositories" {
    @(Get-VBORepository | ForEach-Object {
        $r = $_

        $d = ConvertTo-PropertyHashtable $r -Depth 2

        $osRepo       = if ($r.PSObject.Properties['ObjectStorageRepository']) { $r.ObjectStorageRepository } else { $null }
        $isObjStorage = $osRepo -and $osRepo -isnot [string]
        $d['IsObjectStorageRepo'] = ($isObjStorage -or -not [string]::IsNullOrWhiteSpace("$osRepo"))

        # Explicitly navigate the object hierarchy to extract the fields required
        # for import: type, folder name, container/bucket name, and account name.
        # IDs are NOT captured for account matching — IDs change on a fresh install;
        # the import script matches cloud credentials by name instead.
        if ($isObjStorage) {
            $d['ObjectStorageType']          = try { $r.ObjectStorageRepository.Type.ToString() }    catch { $null }
            $d['ObjectStorageFolderName']    = $null
            $d['ObjectStoragePath']          = $null
            $d['ObjectStorageContainerName'] = $null
            $d['ObjectStorageBucketName']    = $null
            $d['ObjectStorageAccountName']   = $null
            $d['ObjectStorageRegionType']    = $null
            $d['ObjectStorageRegionId']      = $null
            $d['ObjectStorageServicePoint']  = $null
            $d['ObjectStorageCustomRegionId']= $null
            $d['ObjectStorageTrustCert']     = $null

            # The Folder object exposes Name and Path directly regardless of storage type.
            # Full chained access is required — intermediate variable assignment loses
            # the VB365 type adapter context for Folder sub-properties.
            try { $d['ObjectStorageFolderName'] = $r.ObjectStorageRepository.Folder.Name.ToString() } catch { }
            try { $d['ObjectStoragePath']        = $r.ObjectStorageRepository.Folder.Path.ToString() } catch { }

            # Azure Blob: Folder → Container
            try { $d['ObjectStorageContainerName'] = $r.ObjectStorageRepository.Folder.Container.Name.ToString() }                             catch { }
            try { $d['ObjectStorageRegionType']    = $r.ObjectStorageRepository.Folder.Container.RegionType.ToString() }                       catch { }
            try { $d['ObjectStorageAccountName']   = $r.ObjectStorageRepository.Folder.Container.ConnectionSettings.Account.ToString() }       catch { }

            # S3 / S3-Compatible: Folder → Bucket
            try { $d['ObjectStorageBucketName']    = $r.ObjectStorageRepository.Folder.Bucket.Name.ToString() }                               catch { }
            try { $d['ObjectStorageRegionId']      = $r.ObjectStorageRepository.Folder.Bucket.RegionId.ToString() }                           catch { }
            try { $d['ObjectStorageAccountName']   = $r.ObjectStorageRepository.Folder.Bucket.ConnectionSettings.Account.ToString() }         catch { }
            try { $d['ObjectStorageRegionType']    = $r.ObjectStorageRepository.Folder.Bucket.ConnectionSettings.RegionType.ToString() }      catch { }
            try { $d['ObjectStorageServicePoint']  = $r.ObjectStorageRepository.Folder.Bucket.ConnectionSettings.ServicePoint.ToString() }    catch { }
            try { $d['ObjectStorageCustomRegionId']= $r.ObjectStorageRepository.Folder.Bucket.ConnectionSettings.CustomRegionId.ToString() }  catch { }
            try { $d['ObjectStorageTrustCert']     = [bool]$r.ObjectStorageRepository.Folder.Bucket.ConnectionSettings.TrustServerCertificate } catch { }
        }

        $d
    })
}
if ($repos) { $repos | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $exportRoot 'Repositories.json') -Encoding UTF8 }

#endregion

#region ── ORGANIZATIONS ─────────────────────────────────────────────────────

Write-Step "Collecting organizations and application registrations"

$allOrgs    = @(Get-VBOOrganization)
$orgsExport = @()
Write-Ok "$($allOrgs.Count) organization(s) found"

foreach ($org in $allOrgs) {
    Write-Step "  Processing: $($org.Name)"

    $orgDetail = [ordered]@{
        Id                    = $org.Id.ToString()
        Name                  = $org.Name
        Type                  = $org.Type.ToString()
        Region                = if ($org.PSObject.Properties['Region']) { $org.Region.ToString() } else { $null }
        UseVeeamAADApplication = if ($org.PSObject.Properties['UseVeeamAADApplication']) { [bool]$org.UseVeeamAADApplication } else { $false }
        BackupApplications    = @()
        VersionBackupOptions  = $null
        RetentionExclusions   = @()
    }

    # Certificate lives in the org's connection settings (Exchange + SharePoint share the same app/cert).
    # Deduplicate by thumbprint so we export one PFX per unique certificate.
    Invoke-Collect "    Backup application certificates" {
        $seen = @{}
        foreach ($propName in @('Office365ExchangeConnectionSettings','Office365SharePointConnectionSettings')) {
            if (-not ($org.PSObject.Properties[$propName] -and $org.$propName)) { continue }
            $cs         = $org.$propName
            $appId              = if ($cs.PSObject.Properties['ApplicationId'])                    { $cs.ApplicationId.ToString() }              else { $null }
            $thumbprint         = if ($cs.PSObject.Properties['ApplicationCertificateThumbprint']) { $cs.ApplicationCertificateThumbprint }        else { $null }
            $authType           = if ($cs.PSObject.Properties['AuthenticationType'])               { $cs.AuthenticationType.ToString() }           else { $null }
            $impersonationAcct  = if ($cs.PSObject.Properties['ImpersonationAccountName'])         { $cs.ImpersonationAccountName }                else { $null }
            $officeOrgName      = if ($cs.PSObject.Properties['OfficeOrganizationName'])           { $cs.OfficeOrganizationName }                  else { $null }

            if (-not $thumbprint -or $seen[$thumbprint]) { continue }
            $seen[$thumbprint] = $true

            $pfxName = "BackupApp_{0}_{1}.pfx" -f (ConvertTo-SafeFileName $appId), $thumbprint.Substring(0, [Math]::Min(8, $thumbprint.Length))
            $pfxPath = Join-Path $certDir $pfxName

            $exported = Export-CertificateFromStore -Thumbprint $thumbprint -DestinationPath $pfxPath -Password $CertificatePasswordSecure

            $certExpiry = $null
            $clean = $thumbprint -replace '\s', ''
            foreach ($store in @('Cert:\LocalMachine\My','Cert:\CurrentUser\My','Cert:\LocalMachine\Root','Cert:\LocalMachine\CA')) {
                $certObj = Get-ChildItem $store -ErrorAction SilentlyContinue |
                           Where-Object { $_.Thumbprint -ieq $clean } | Select-Object -First 1
                if ($certObj) { $certExpiry = $certObj.NotAfter.ToString('o'); break }
            }

            $orgDetail.BackupApplications += [ordered]@{
                ApplicationId          = $appId
                AuthenticationType     = $authType
                ImpersonationAccountName = $impersonationAcct
                OfficeOrganizationName = $officeOrgName
                CertificateThumbprint  = $thumbprint
                CertificateExpiry      = $certExpiry
                CertificateExportFile  = if ($exported) { $pfxName } else { $null }
                CertificateExported    = $exported
            }

            $status = if ($exported) { "(cert exported)" } else { "(cert NOT found in local store)" }
            Write-Ok "      App $appId | Thumbprint: $thumbprint $status"
        }
        "$($orgDetail.BackupApplications.Count) backup app cert(s)"
    } | Out-Null

    $orgDetail.VersionBackupOptions = Invoke-Collect "    Version backup options" {
        $v = Get-VBOVersionBackupOptions -Organization $org
        $h = [ordered]@{}
        $v.PSObject.Properties | Where-Object { $_.MemberType -in 'NoteProperty','Property' } |
            ForEach-Object { $h[$_.Name] = if ($null -ne $_.Value) { $_.Value.ToString() } else { $null } }
        $h
    }

    Invoke-Collect "    Retention exclusions" {
        $excl = @(Get-VBOOrganizationRetentionExclusion -Organization $org)
        foreach ($e in $excl) {
            $orgDetail.RetentionExclusions += [ordered]@{
                Id   = if ($e.PSObject.Properties['Id'])          { $e.Id.ToString() }   else { $null }
                Type = if ($e.PSObject.Properties['Type'])        { $e.Type.ToString() } else { $null }
                Name = if ($e.PSObject.Properties['DisplayName']) { $e.DisplayName }     else { $null }
            }
        }
        "$($excl.Count) exclusion(s)"
    } | Out-Null

    $orgsExport += $orgDetail
}

$orgsExport | ConvertTo-Json -Depth 10 | Set-Content -Path (Join-Path $exportRoot 'Organizations.json') -Encoding UTF8

#endregion

#region ── BACKUP JOBS ───────────────────────────────────────────────────────

$exportedJobCount     = 0
$exportedCopyJobCount = 0

if ($IncludeJobs) {
    $jobsDir = Join-Path $exportRoot 'Jobs'
    New-Item -ItemType Directory -Path $jobsDir -Force | Out-Null

    # ── Backup jobs ───────────────────────────────────────────────────────────
    Write-Step "Collecting backup jobs"

    @(Get-VBOJob) | ForEach-Object {
        $job = $_
        try {
            $jd = [ordered]@{
                Id                   = $job.Id.ToString()
                Name                 = $job.Name
                Description          = $(try { $job.Description }              catch { $null })
                IsEnabled            = $(try { [bool]$job.IsEnabled }           catch { $true })
                IsEntireOrganization = $(try { [bool]$job.IsEntireOrganization } catch { $false })
                OrganizationName     = if ($job.Organization) { $job.Organization.Name } else { $null }
                RepositoryName       = if ($job.Repository)   { $job.Repository.Name }   else { $null }
                SchedulePolicy       = $null
                SelectedItems        = @()
                ExcludedItems        = @()
            }

            # Schedule policy — extract each field explicitly for clean re-import
            try {
                $sp = $job.SchedulePolicy
                if ($sp) {
                    $jd.SchedulePolicy = [ordered]@{
                        EnableSchedule    = $(try { [bool]$sp.EnableSchedule }           catch { $true })
                        Type              = $(try { $sp.Type.ToString() }                 catch { 'Daily' })
                        DailyTime         = $(try { $sp.DailyTime.ToString() }            catch { '15:00:00' })
                        DailyType         = $(try { $sp.DailyType.ToString() }            catch { 'Everyday' })
                        PeriodicallyEvery = $(try { $sp.PeriodicallyEvery.ToString() }    catch { $null })
                        RetryEnabled      = $(try { [bool]$sp.RetryEnabled }              catch { $false })
                        RetryNumber       = $(try { [int]$sp.RetryNumber }                catch { 3 })
                        RetryWaitInterval = $(try { [int]$sp.RetryWaitInterval }          catch { 10 })
                    }
                }
            } catch { Write-Warn "    Schedule for '$($job.Name)': $_" }

            # Selected / excluded items with workload flags and identifying properties
            try {
                $items = @(Get-VBOBackupItem -Job $job)
                foreach ($item in $items) {
                    $isExcluded = if ($item.PSObject.Properties['IsExcluded']) { [bool]$item.IsExcluded } else { $false }

                    $entry = [ordered]@{
                        Type       = $(try { $item.Type.ToString() } catch { $null })
                        IsExcluded = $isExcluded
                        User       = $null
                        Group      = $null
                        Site       = $null
                        Team       = $null
                    }

                    # Enumerate ALL boolean properties on the item so every workload flag
                    # is captured regardless of name. Skip only the known non-flag properties.
                    # Note: 'Site' is intentionally NOT skipped — for User-type items it is a
                    # boolean flag (include personal SharePoint site), not a sub-object.
                    $skipProps = @('Type','IsExcluded','User','Group','Team','Organization','Id')
                    foreach ($prop in $item.PSObject.Properties) {
                        if ($prop.Name -in $skipProps) { continue }
                        $v = $prop.Value
                        if ($v -is [bool]) { $entry[$prop.Name] = $v }
                    }

                    if ($item.PSObject.Properties['User'] -and $item.User) {
                        $u = $item.User
                        $entry.User = [ordered]@{
                            DisplayName = $(try { $u.DisplayName } catch { $null })
                            UserName    = $(try { $u.UserName }    catch { $null })
                        }
                    }
                    if ($item.PSObject.Properties['Group'] -and $item.Group) {
                        $g = $item.Group
                        $entry.Group = [ordered]@{
                            DisplayName = $(try { $g.DisplayName } catch { $null })
                            Name        = $(try { $g.Name }        catch { $null })
                        }
                    }
                    # Site is a boolean flag on User-type items (personal SharePoint site).
                    # Only extract it as a sub-object when it is an actual site object.
                    if ($item.PSObject.Properties['Site'] -and $item.Site -and $item.Site -isnot [bool]) {
                        $s = $item.Site
                        $entry.Site = [ordered]@{
                            Title = $(try { $s.Title } catch { $null })
                            Url   = $(try { $s.Url }   catch { $null })
                        }
                    }
                    if ($item.PSObject.Properties['Team'] -and $item.Team) {
                        $t = $item.Team
                        $entry.Team = [ordered]@{
                            DisplayName = $(try { $t.DisplayName } catch { $null })
                            Name        = $(try { $t.Name }        catch { $null })
                        }
                    }

                    if ($isExcluded) { $jd.ExcludedItems += $entry }
                    else             { $jd.SelectedItems += $entry }
                }
            } catch { Write-Warn "    Items for '$($job.Name)': $_" }

            $safeName = (ConvertTo-SafeFileName $job.Name) -replace '\s+', '_'
            $jd | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $jobsDir "BackupJob_$safeName.json") -Encoding UTF8
            $exportedJobCount++
            Write-Ok "  Backup job: $($job.Name)"
        } catch {
            Write-Warn "Failed to export job '$($job.Name)': $_"
        }
    }
    Write-Ok "$exportedJobCount backup job(s) exported to Jobs\"

    # ── Backup copy jobs ──────────────────────────────────────────────────────
    Write-Step "Collecting backup copy jobs"

    @(Get-VBOCopyJob) | ForEach-Object {
        $cj = $_
        try {
            $cd = [ordered]@{
                Id             = $cj.Id.ToString()
                Name           = $(try { $cj.Name }           catch { $null })
                IsEnabled      = $(try { [bool]$cj.IsEnabled } catch { $true })
                BackupJobName  = if ($cj.PSObject.Properties['BackupJob'] -and $cj.BackupJob) { $cj.BackupJob.Name } else { $null }
                RepositoryName = if ($cj.PSObject.Properties['Repository'] -and $cj.Repository) { $cj.Repository.Name } else { $null }
                SchedulePolicy = $null
            }

            try {
                $sp = $cj.SchedulePolicy
                if ($sp) {
                    $cd.SchedulePolicy = [ordered]@{
                        Type              = $(try { $sp.Type.ToString() }              catch { 'Immediate' })
                        DailyTime         = $(try { $sp.DailyTime.ToString() }         catch { '15:00:00' })
                        DailyType         = $(try { $sp.DailyType.ToString() }         catch { 'Everyday' })
                        PeriodicallyEvery = $(try { $sp.PeriodicallyEvery.ToString() } catch { $null })
                    }
                }
            } catch { Write-Warn "    Copy job schedule for '$($cj.Name)': $_" }

            # Filename is based on the source backup job name so the import can correlate them
            $baseName = if ($cd.BackupJobName) { $cd.BackupJobName } else { $cj.Name }
            $safeName = (ConvertTo-SafeFileName $baseName) -replace '\s+', '_'
            $cd | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $jobsDir "BackupCopyJob_$safeName.json") -Encoding UTF8
            $exportedCopyJobCount++
            Write-Ok "  Copy job: '$($cj.Name)' → $($cd.RepositoryName)"
        } catch {
            Write-Warn "Failed to export copy job '$($cj.Name)': $_"
        }
    }
    Write-Ok "$exportedCopyJobCount backup copy job(s) exported to Jobs\"
}

#endregion

#region ── Disconnect & summary ──────────────────────────────────────────────

try { Disconnect-VBOServer } catch { }

$certFiles    = @(Get-ChildItem -Path $certDir -Filter '*.pfx' -ErrorAction SilentlyContinue)
$missingCerts = @($orgsExport | ForEach-Object {
    $_.BackupApplications | Where-Object { $_.CertificateThumbprint -and -not $_.CertificateExported }
}).Count
$outputFiles = @(Get-ChildItem -Path $exportRoot -Filter '*.json' -Recurse)

Write-Host "`n─── Export complete ──────────────────────────────────────────────────" -ForegroundColor White
Write-Host "  Output folder       : $exportRoot"
Write-Host "  JSON files          : $($outputFiles.Count)"
Write-Host "  Organizations       : $($orgsExport.Count)"
Write-Host "  Certificates saved  : $($certFiles.Count)"
if ($IncludeJobs) {
    Write-Host "  Backup jobs         : $exportedJobCount"
    Write-Host "  Backup copy jobs    : $exportedCopyJobCount"
}
if ($missingCerts -gt 0) {
    Write-Warn "  Missing PFX files   : $missingCerts"
    Write-Warn "  Thumbprints recorded in Organizations.json — export those PFX files"
    Write-Warn "  manually from the original machine's Windows certificate store."
}
Write-Host ""

#endregion
