#Requires -Version 7.0
<#
.SYNOPSIS
    Staged, resumable batch restore of SharePoint or OneDrive content
    from Veeam Backup for Microsoft 365.
.DESCRIPTION
    Fresh run: interactive wizard (organization -> job -> restore point), then
    detects whether the restore point holds SharePoint data, OneDrive data, or
    both and offers what is present -> site -> library -> folder (SharePoint) or
    user -> folder (OneDrive). Scope can be a single folder, a whole library,
    all libraries in a site, or a whole OneDrive. Saves a resumable JSON config
    next to the script, then restores the chosen targets' direct children in
    batches of -Items. A subfolder counts as one item and is restored recursively.
    Resume run: -ConfigPath <file> reconnects and continues where it left off.
    Existing items in the target are always skipped (Veeam default), so
    re-runs never duplicate content.
    Design specs: docs/superpowers/specs/2026-06-12-vbo-staged-sp-restore-design.md
    (original SharePoint build) and 2026-06-15-vbo-staged-restore-onedrive-design.md
    (OneDrive support + scope levels).
.NOTES
    Run on the VB365 server (or a machine with its console installed) in
    PowerShell 7 (pwsh.exe), as an account with VB365 restore rights.
    PowerShell 7 is required: the VB365 SharePoint module's dependencies
    (e.g. Microsoft.Bcl.AsyncInterfaces) fail to load under Windows
    PowerShell 5.1 (powershell.exe).
    Requires the org to use app-based SharePoint auth (ApplicationId +
    certificate); the app certificate must be in the local cert store with
    an exportable private key, or supply -PfxPath.
#>
[CmdletBinding()]
param(
    [string]$Server = 'localhost',
    [int]$Items = 500,
    [string]$ConfigPath,
    [string]$PfxPath,
    [string]$SiteUrl,
    [string]$LibraryName,
    [string]$FolderPath,
    [switch]$DryRun,
    [switch]$RestorePermissions,
    [switch]$DiagnoseDetection
)

# Remember whether -Items was explicitly supplied, so a resume run can
# override the batch size stored in the config file.
$script:ItemsWasSupplied = $PSBoundParameters.ContainsKey('Items')

# Cache for probe-based folder detection (OneDrive): item id -> is-folder bool.
# Avoids re-querying children for the same item across menu + logging passes.
$script:folderProbeCache = @{}

function Get-SafeName {
    # Reduce a site name to something safe for config/log filenames.
    param([Parameter(Mandatory)][string]$Name)
    return ($Name -replace '[^A-Za-z0-9.-]', '-')
}

function Write-RestoreLog {
    # Append a timestamped line to the log file and echo it to the console.
    param(
        [Parameter(Mandatory)][string]$LogPath,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Message
    )
    $line = "[{0:yyyy-MM-dd HH:mm:ss}] {1}" -f (Get-Date), $Message
    Add-Content -Path $LogPath -Value $line -Encoding UTF8
    Write-Host $line
}

function Show-Menu {
    # Numbered console menu. Loops until a valid 1..N selection is entered
    # and returns the selected object. Works in any PowerShell host (no GUI).
    param(
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][object[]]$Options,
        [scriptblock]$Label = { "$_" }
    )
    Write-Host ""
    Write-Host "=== $Title ==="
    for ($i = 0; $i -lt $Options.Count; $i++) {
        $text = $Options[$i] | ForEach-Object -Process $Label
        Write-Host ("  [{0}] {1}" -f ($i + 1), $text)
    }
    while ($true) {
        $answer = Read-Host "Select 1-$($Options.Count)"
        $index = 0
        if ([int]::TryParse($answer, [ref]$index) -and $index -ge 1 -and $index -le $Options.Count) {
            return $Options[$index - 1]
        }
        Write-Host "Invalid selection -- enter a number between 1 and $($Options.Count)."
    }
}

function New-RestoreProvider {
    # Returns the data-type-specific pieces the shared engine needs. Cmdlet
    # names are strings so the engine can invoke them with & and they stay
    # mockable in tests. PermissionParams maps the -RestorePermissions script
    # switch to whichever parameters the type's restore cmdlet uses.
    param(
        [Parameter(Mandatory)]
        [ValidateSet('SharePoint', 'OneDrive')]
        [string]$DataType
    )
    if ($DataType -eq 'SharePoint') {
        return [pscustomobject]@{
            DataType         = 'SharePoint'
            StartSessionCmd  = 'Start-VBOSharePointItemRestoreSession'
            StopSessionCmd   = 'Stop-VBOSharePointItemRestoreSession'
            ChildrenCmd      = 'Get-VESPDocument'
            ContainerParam   = 'DocumentLibrary'
            RestoreCmd       = 'Restore-VESPItem'
            PermissionParams = @{ RestorePermissions = $true; SkipPermissionNotificationSending = $true }
            # Restore-VESPItem accepts -ImpersonationAccountName; Restore-VEODDocument does not.
            SupportsImpersonation = $true
            # VESPDocument carries a stable Id and an IsFolder/Type marker, so the
            # engine can key on Id and detect folders by reading a property.
            IdProperty       = 'Id'
            FolderDetection  = 'Property'
        }
    }
    # Note: the OneDrive session cmdlets use the VEOD prefix and do NOT mirror
    # the SharePoint "Start/Stop-VBO<type>ItemRestoreSession" naming -- confirmed
    # against the live build (Veeam.SharePoint.PowerShell module).
    return [pscustomobject]@{
        DataType         = 'OneDrive'
        StartSessionCmd  = 'Start-VEODRestoreSession'
        StopSessionCmd   = 'Stop-VEODRestoreSession'
        ChildrenCmd      = 'Get-VEODDocument'
        ContainerParam   = 'User'
        RestoreCmd       = 'Restore-VEODDocument'
        PermissionParams = @{ RestoreSharedAccess = $true; SkipSharedAccessNotificationSending = $true }
        SupportsImpersonation = $false
        # VBOOneDriveDocument has neither an Id nor a folder marker (confirmed on
        # the live build: properties are only Name/Url/Version/Base64UniqueKey).
        # So the engine keys on Base64UniqueKey for identity, and a folder is
        # detected by probing -- an item that returns children is a folder.
        IdProperty       = 'Base64UniqueKey'
        FolderDetection  = 'Probe'
    }
}

function Select-DataType {
    # Decide which data type to restore given the types actually present in
    # the restore point. 0 -> error; 1 -> use it silently; 2 -> ask.
    param([string[]]$Available = @())
    if ($Available.Count -eq 0) {
        throw 'This restore point contains no SharePoint or OneDrive data.'
    }
    if ($Available.Count -eq 1) { return $Available[0] }
    return Show-Menu -Title 'Select data type' -Options $Available -Label { "$_" }
}

function Build-Targets {
    # Turn a set of containers (libraries or a single user) plus an optional
    # shared root folder into the engine's ordered target list. One target per
    # container; the common case is a single target. The "all libraries" scope
    # passes every library with RootFolder = $null.
    param(
        [Parameter(Mandatory)][object[]]$Containers,
        $RootFolder,
        [string]$ScopePath = '/'
    )
    return $Containers | ForEach-Object {
        [pscustomobject]@{
            Container     = $_
            ContainerName = "$($_.Name)"
            RootFolder    = $RootFolder
            ScopePath     = $ScopePath
        }
    }
}

function Get-DocumentId {
    # The engine keys batching/dedup/resume on a stable per-item id, but the
    # property differs by data type: SharePoint's VESPDocument has 'Id';
    # OneDrive's VBOOneDriveDocument has no Id at all, only 'Base64UniqueKey'.
    # The provider names the right property; default 'Id' keeps old callers working.
    param(
        [Parameter(Mandatory)]$Document,
        $Provider
    )
    $prop = if ($Provider -and $Provider.IdProperty) { $Provider.IdProperty } else { 'Id' }
    return "$($Document.$prop)"
}

function Test-IsFolderDocument {
    # Is this document a folder? SharePoint exposes a marker property
    # (IsFolder/Type). OneDrive's VBOOneDriveDocument has NO folder marker
    # (only Name/Url/Version/Base64UniqueKey), so the only way to tell is to
    # probe: an item that returns child documents is a folder. The provider's
    # FolderDetection mode selects which technique to use. Default 'Property'
    # keeps SharePoint and the pure unit tests working without a provider.
    param(
        [Parameter(Mandatory)]$Document,
        $Provider
    )
    $mode = if ($Provider -and $Provider.FolderDetection) { $Provider.FolderDetection } else { 'Property' }
    if ($mode -eq 'Probe') {
        # Cache probe results by id so navigating the same level twice (e.g.
        # building the menu, then logging the batch) does not re-hit the server.
        $id = Get-DocumentId -Provider $Provider -Document $Document
        if ($null -ne $script:folderProbeCache -and $script:folderProbeCache.ContainsKey($id)) {
            return $script:folderProbeCache[$id]
        }
        # An empty folder also returns 0 children and is treated as a file --
        # harmless, since restoring it still recreates the (empty) folder.
        $isFolder = @(& $Provider.ChildrenCmd -ParentDocument $Document).Count -gt 0
        if ($null -ne $script:folderProbeCache) { $script:folderProbeCache[$id] = $isFolder }
        return $isFolder
    }
    if ($null -ne $Document.PSObject.Properties['IsFolder']) { return [bool]$Document.IsFolder }
    if ($null -ne $Document.PSObject.Properties['Type'])     { return ("$($Document.Type)" -eq 'Folder') }
    return $false
}

function Get-NextBatch {
    # Pure batching math: sort direct children by name (stable order across
    # runs), drop already-processed ids, take the next BatchSize items. The id
    # property differs by data type, so identity goes through Get-DocumentId
    # (provider-driven); the secondary sort key uses the same id for a stable
    # tie-break. With no provider the id is 'Id' -- the SharePoint default.
    param(
        [object[]]$Children = @(),
        [string[]]$ProcessedIds = @(),
        [Parameter(Mandatory)][int]$BatchSize,
        $Provider
    )
    $done = New-Object 'System.Collections.Generic.HashSet[string]'
    foreach ($id in $ProcessedIds) { [void]$done.Add($id) }
    $Children |
        Sort-Object Name, @{ Expression = { Get-DocumentId -Provider $Provider -Document $_ } } |
        Where-Object { -not $done.Contains((Get-DocumentId -Provider $Provider -Document $_)) } |
        Select-Object -First $BatchSize
}

function Save-RestoreConfig {
    # Persist the resumable state. Called after every batch, so a crash
    # loses at most one batch of bookkeeping (which skip-existing absorbs).
    # Never contains passwords or key material.
    # Written BOM-less via .NET (Set-Content -Encoding UTF8 adds a BOM on
    # Windows PowerShell 5.1, which can break JSON parsers).
    param(
        [Parameter(Mandatory)]$Config,
        [Parameter(Mandatory)][string]$Path
    )
    # .NET resolves relative paths against the process CWD, not the
    # PowerShell location, so resolve through the provider first.
    $resolved = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    $json = $Config | ConvertTo-Json -Depth 5
    $encoding = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($resolved, $json, $encoding)
}

function Read-RestoreConfig {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -Path $Path)) { throw "Config file not found: $Path" }
    $raw = Get-Content -Path $Path -Raw
    # Tolerate a leading BOM (configs written by older versions or other tools).
    if ($raw) { $raw = $raw.TrimStart([char]0xFEFF) }
    try {
        $config = $raw | ConvertFrom-Json
    } catch {
        throw "Config file '$Path' is empty or corrupt (possibly from a crash during write): $($_.Exception.Message)"
    }
    if ($null -eq $config) { throw "Config file '$Path' is empty or corrupt (possibly from a crash during write)." }
    # Normalize processedItems to an array (JSON round-trip quirk guard).
    if ($null -eq $config.PSObject.Properties['processedItems'] -or $null -eq $config.processedItems) {
        $config | Add-Member -NotePropertyName processedItems -NotePropertyValue @() -Force
    }
    $config.processedItems = @($config.processedItems)
    return $config
}

function Get-ConfigDataType {
    # Back-compat: config files written before OneDrive support have no
    # dataType field and are SharePoint by definition.
    param([Parameter(Mandatory)]$Config)
    $dt = if ($null -ne $Config.PSObject.Properties['dataType']) { "$($Config.dataType)" } else { '' }
    if (-not $dt) { return 'SharePoint' }
    return $dt
}

function New-RandomPfxPassword {
    # Random password for the temp PFX -- generated in memory, never persisted.
    # RandomNumberGenerator::Create() works on both PS 5.1 and PS 7.
    $bytes = New-Object byte[] 32
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try { $rng.GetBytes($bytes) } finally { $rng.Dispose() }
    return (ConvertTo-SecureString -String ([Convert]::ToBase64String($bytes)) -AsPlainText -Force)
}

function Export-OrgCertificate {
    # Find the org's app certificate in the Windows cert store by thumbprint
    # and export it to a temp PFX for Restore-VESPItem (which requires a PFX
    # path -- it has no thumbprint parameter). Caller must delete the file.
    param(
        [Parameter(Mandatory)][string]$Thumbprint,
        [Parameter(Mandatory)][securestring]$Password
    )
    $thumb = ($Thumbprint -replace '\s', '').ToUpper()
    $cert = $null
    foreach ($storePath in 'Cert:\LocalMachine\My', 'Cert:\CurrentUser\My') {
        $cert = Get-ChildItem -Path $storePath -ErrorAction SilentlyContinue |
            Where-Object { $_.Thumbprint -eq $thumb } | Select-Object -First 1
        if ($cert) { break }
    }
    if (-not $cert) {
        throw "Certificate $thumb was not found in LocalMachine\My or CurrentUser\My. Export the app certificate to a PFX manually and re-run with -PfxPath."
    }
    if (-not $cert.HasPrivateKey) {
        throw "Certificate $thumb has no private key in the store. Export the app certificate to a PFX manually and re-run with -PfxPath."
    }
    $tempPfx = Join-Path ([System.IO.Path]::GetTempPath()) ("vboStagedRestore-{0}.pfx" -f [guid]::NewGuid())
    try {
        Export-PfxCertificate -Cert $cert -FilePath $tempPfx -Password $Password | Out-Null
    } catch {
        throw "Could not export certificate $thumb (the private key may be non-exportable): $($_.Exception.Message). Export the PFX manually and re-run with -PfxPath."
    }
    return $tempPfx
}

function Test-PfxThumbprint {
    # Guard for -PfxPath: refuse to restore with a certificate that doesn't
    # match the org's configured thumbprint.
    param(
        [Parameter(Mandatory)][string]$PfxFilePath,
        [Parameter(Mandatory)][securestring]$Password,
        [Parameter(Mandatory)][string]$ExpectedThumbprint
    )
    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($PfxFilePath, $Password)
    try {
        return ($cert.Thumbprint -eq (($ExpectedThumbprint -replace '\s', '').ToUpper()))
    } finally {
        $cert.Dispose()
    }
}

function Get-FolderChildren {
    # Direct children (one level, no recursion) of a folder, or of the
    # container root when -Folder is $null. This one level IS the batching
    # unit. The container is a SharePoint library or a OneDrive user; the
    # provider supplies the cmdlet and the root parameter name.
    param(
        [Parameter(Mandatory)]$Provider,
        [Parameter(Mandatory)]$Container,
        $Folder
    )
    if ($null -ne $Folder) { return ,@(& $Provider.ChildrenCmd -ParentDocument $Folder) }
    $rootArgs = @{ $Provider.ContainerParam = $Container }
    return ,@(& $Provider.ChildrenCmd @rootArgs)
}

function Resolve-FolderByPath {
    # Re-resolve a saved folder path like '/Reports/2024/' on resume by
    # walking segment-by-segment from the container root. $null = root.
    param(
        [Parameter(Mandatory)]$Provider,
        [Parameter(Mandatory)]$Container,
        [Parameter(Mandatory)][AllowEmptyString()][string]$FolderPath
    )
    $current = $null
    $segments = @($FolderPath.Trim('/') -split '/' | Where-Object { $_ })
    foreach ($segment in $segments) {
        $children = Get-FolderChildren -Provider $Provider -Container $Container -Folder $current
        $current = $children |
            Where-Object { (Test-IsFolderDocument -Provider $Provider -Document $_) -and $_.Name -eq $segment } |
            Select-Object -First 1
        if (-not $current) {
            throw "Could not resolve folder segment '$segment' of path '$FolderPath' -- the folder structure may differ in this restore point."
        }
    }
    return $current
}

function Get-SubFolder {
    # Filter a level's children down to its subfolders. For probe-based
    # providers (OneDrive) this is expensive -- one children-query per item --
    # so emit a "please wait" notice and let the probe cache absorb repeats.
    param(
        [Parameter(Mandatory)]$Provider,
        [object[]]$Children = @()
    )
    if ($Provider.FolderDetection -eq 'Probe' -and $Children.Count -gt 0) {
        Write-Host ("(scanning {0} item(s) to find folders -- this can take a moment for OneDrive...)" -f $Children.Count)
    }
    return @($Children | Where-Object { Test-IsFolderDocument -Provider $Provider -Document $_ })
}

function Select-RecoveryFolder {
    # Interactive drill-down: at each level offer a "use this level" option
    # plus the subfolders. At the top level that option is worded as
    # "restore everything" (the explicit all-items scope); deeper it is
    # "use this folder". Returns @{ Folder = <doc or $null>; Path = '/a/b/' }.
    #
    # Lazy gate (probe-based providers only): listing folders costs one query
    # per item, so at the top level we first ask "restore everything" vs "drill
    # into a folder" and only pay the scan cost if the operator chooses to drill.
    param(
        [Parameter(Mandatory)]$Provider,
        [Parameter(Mandatory)]$Container,
        [Parameter(Mandatory)][string]$ContainerLabel
    )
    $current = $null
    $path = '/'
    $isTop = $true

    if ($Provider.FolderDetection -eq 'Probe') {
        $drill = [pscustomobject]@{ Name = 'Choose a folder to drill into...'; IsDrill = $true }
        $everything = [pscustomobject]@{ Name = "== restore EVERYTHING in this $ContainerLabel =="; IsUseHere = $true }
        $picked = Show-Menu -Title "$ContainerLabel scope" -Options @($everything, $drill) -Label { $_.Name }
        if ($null -ne $picked.PSObject.Properties['IsUseHere']) {
            return [pscustomobject]@{ Folder = $null; Path = '/' }
        }
        # Operator opted into drilling; the loop below now shows "use this folder".
        $isTop = $false
    }

    while ($true) {
        $children = Get-FolderChildren -Provider $Provider -Container $Container -Folder $current
        $subFolders = Get-SubFolder -Provider $Provider -Children $children
        if ($subFolders.Count -eq 0) { break }
        $useLabel = if ($isTop) { "== restore EVERYTHING in this $ContainerLabel ==" } else { '== use this folder ==' }
        $useHere = [pscustomobject]@{ Name = $useLabel; IsUseHere = $true }
        $picked = Show-Menu -Title "Recovery folder (current: $path)" -Options (@($useHere) + $subFolders) -Label { $_.Name }
        if ($null -ne $picked.PSObject.Properties['IsUseHere']) { break }
        $current = $picked
        $path = '{0}{1}/' -f $path, $picked.Name
        $isTop = $false
    }
    return [pscustomobject]@{ Folder = $current; Path = $path }
}

# === end of helper functions; main flow below ===

function Get-RestoreContext {
    # Probe a restore point for SharePoint and OneDrive data, ask the operator
    # which to restore (Select-DataType), and return the chosen data type with
    # its already-open session. Sessions opened for types we do not use are
    # stopped before returning.
    param(
        [Parameter(Mandatory)]$RestorePoint,
        [switch]$Diagnose
    )

    # -DiagnoseDetection: dump the FULL failure detail (exception type, message,
    # and inner exception -- Veeam often wraps the real cause inside) instead of
    # the one-line summary, plus the raw counts each probe sees. This turns the
    # otherwise-swallowed probe errors into evidence for why detection failed.
    $reportProbeError = {
        param($Label, $ErrorRecord)
        if ($Diagnose) {
            Write-Host ""
            Write-Host "--- [DIAGNOSE] $Label probe failed ---"
            Write-Host "Exception type : $($ErrorRecord.Exception.GetType().FullName)"
            Write-Host "Message        : $($ErrorRecord.Exception.Message)"
            $inner = $ErrorRecord.Exception.InnerException
            $depth = 1
            while ($inner) {
                Write-Host "Inner ($depth) type   : $($inner.GetType().FullName)"
                Write-Host "Inner ($depth) message: $($inner.Message)"
                $inner = $inner.InnerException
                $depth++
            }
            Write-Host "Failing line   : $($ErrorRecord.InvocationInfo.Line.Trim())"
            Write-Host "----------------------------------------"
        } else {
            Write-Host "Could not read $Label data from this restore point ($($ErrorRecord.Exception.Message))"
        }
    }

    $probes = @()   # @{ Type; Session; HasData }

    # SharePoint probe. If the session opens but enumeration then fails, stop
    # the orphaned session in the catch so it does not leak. The wording says
    # "could not read" rather than "no data": a fault here is not proof the
    # restore point is empty.
    $spSession = $null
    try {
        if ($Diagnose) { Write-Host "[DIAGNOSE] Starting SharePoint probe session..." }
        $spSession = Start-VBOSharePointItemRestoreSession -RestorePoint $RestorePoint
        if ($Diagnose) { Write-Host "[DIAGNOSE] SharePoint session opened: $($null -ne $spSession)" }
        $spOrg     = Get-VESPOrganization -Session $spSession
        $spSites   = @(Get-VESPSite -Organization $spOrg -Recurse)
        if ($Diagnose) { Write-Host "[DIAGNOSE] SharePoint sites returned: $($spSites.Count)" }
        $hasSp     = $spSites.Count -gt 0
        $probes += @{ Type = 'SharePoint'; Session = $spSession; HasData = $hasSp }
    } catch {
        if ($spSession) { try { Stop-VBOSharePointItemRestoreSession -Session $spSession -ErrorAction SilentlyContinue } catch { } }
        & $reportProbeError 'SharePoint' $_
    }

    # OneDrive probe (same pattern).
    $odSession = $null
    try {
        if ($Diagnose) { Write-Host "[DIAGNOSE] Starting OneDrive probe session..." }
        $odSession = Start-VEODRestoreSession -RestorePoint $RestorePoint
        if ($Diagnose) { Write-Host "[DIAGNOSE] OneDrive session opened: $($null -ne $odSession)" }
        $odUsers   = @(Get-VEODUser -Session $odSession)
        if ($Diagnose) { Write-Host "[DIAGNOSE] OneDrive users returned: $($odUsers.Count)" }
        $hasOd     = $odUsers.Count -gt 0
        $probes += @{ Type = 'OneDrive'; Session = $odSession; HasData = $hasOd }
    } catch {
        if ($odSession) { try { Stop-VEODRestoreSession -Session $odSession -ErrorAction SilentlyContinue } catch { } }
        & $reportProbeError 'OneDrive' $_
    }

    if ($Diagnose) {
        Write-Host ""
        Write-Host "[DIAGNOSE] Probe summary:"
        foreach ($p in $probes) { Write-Host ("  {0}: HasData={1}" -f $p.Type, $p.HasData) }
        Write-Host ("[DIAGNOSE] Types with data: {0}" -f (@($probes | Where-Object { $_.HasData } | ForEach-Object { $_.Type }) -join ', '))
        Write-Host ""
    }

    $available = @($probes | Where-Object { $_.HasData } | ForEach-Object { $_.Type })
    $chosenType = Select-DataType -Available $available   # throws if none

    # Stop every probe session except the one we will use. Dispatch the right
    # stop cmdlet per type via the provider, matching the rest of the script.
    $chosen = $probes | Where-Object { $_.Type -eq $chosenType } | Select-Object -First 1
    foreach ($p in $probes) {
        if ($p.Type -ne $chosenType -and $p.Session) {
            $stopCmd = (New-RestoreProvider -DataType $p.Type).StopSessionCmd
            try { & $stopCmd -Session $p.Session -ErrorAction SilentlyContinue } catch { }
        }
    }
    return [pscustomobject]@{ DataType = $chosenType; Session = $chosen.Session }
}

function Invoke-StagedRestore {
    $session = $null
    $connected = $false
    $pfxFilePath = $null
    $pfxIsTemp = $false
    $pfxPassword = $null

    try {
        # ---- connect to the VB365 server ----
        # Just attempt the connection. If a session is already open Connect-VBOServer
        # throws "already connected"; treat that as success and reuse the session.
        # Only flag $connected (and later disconnect) for a connection we opened.
        Write-Host "Connecting to VB365 server '$Server'..."
        try {
            if ($Server -eq 'localhost') {
                Connect-VBOServer
            } else {
                Connect-VBOServer -Server $Server -Credential (Get-Credential -Message "Credentials for VB365 server $Server")
            }
            $connected = $true
        } catch {
            if ($_.Exception.Message -match 'already connected') {
                Write-Host "Already connected to VB365; reusing the existing session."
            } else {
                throw
            }
        }

        if ($ConfigPath) {
            # ---- RESUME: load config, re-resolve every saved object ----
            $config = Read-RestoreConfig -Path $ConfigPath
            if ($script:ItemsWasSupplied) { $config.itemsPerBatch = $Items }
            $configFile = $ConfigPath
            $scopeName = if ((Get-ConfigDataType $config) -eq 'OneDrive') { $config.userName } else { $config.siteName }
            $logFile = Join-Path $PSScriptRoot ("stagedRestore-{0}.log" -f (Get-SafeName $scopeName))
            Write-RestoreLog $logFile ("=== RESUME: {0} (batch size {1}) ===" -f $scopeName, $config.itemsPerBatch)

            $organization = Get-VBOOrganization -Name $config.organizationName
            if (-not $organization) { throw "Organization '$($config.organizationName)' not found on this server." }
            $job = @(Get-VBOJob -Organization $organization) | Where-Object { "$($_.Id)" -eq $config.jobId } | Select-Object -First 1
            if (-not $job) { throw "Backup job $($config.jobId) not found for organization '$($organization.Name)'." }
            $rp = @(Get-VBORestorePoint -Job $job) | Where-Object { "$($_.Id)" -eq $config.restorePointId } | Select-Object -First 1
            if (-not $rp) { throw "Restore point $($config.restorePointId) is no longer available (it may have aged out of retention)." }

            $dataType = Get-ConfigDataType $config
            $provider = New-RestoreProvider -DataType $dataType
            $session  = & $provider.StartSessionCmd -RestorePoint $rp

            if ($dataType -eq 'SharePoint') {
                $vespOrg = Get-VESPOrganization -Session $session
                $site = @(Get-VESPSite -Organization $vespOrg -Recurse) | Where-Object { "$($_.Url)" -eq $config.siteUrl } | Select-Object -First 1
                if (-not $site) { throw "Site $($config.siteUrl) not found in this restore point." }
                $libraries = @(Get-VESPDocumentLibrary -Site $site)
                if ($config.PSObject.Properties['allLibraries'] -and $config.allLibraries) {
                    if ($libraries.Count -eq 0) { throw "No document libraries found in site $($config.siteUrl)." }
                    $targets = @(Build-Targets -Containers $libraries -RootFolder $null -ScopePath '/')
                } else {
                    $library = $libraries | Where-Object { $_.Name -eq $config.libraryName } | Select-Object -First 1
                    if (-not $library) { throw "Document library '$($config.libraryName)' not found in site $($config.siteUrl)." }
                    $rootFolder = Resolve-FolderByPath -Provider $provider -Container $library -FolderPath $config.folderPath
                    $targets = @(Build-Targets -Containers @($library) -RootFolder $rootFolder -ScopePath $config.folderPath)
                }
            }
            else {
                $user = @(Get-VEODUser -Session $session) | Where-Object { "$($_.Name)" -eq $config.userName } | Select-Object -First 1
                if (-not $user) { throw "OneDrive user '$($config.userName)' not found in this restore point." }
                $rootFolder = Resolve-FolderByPath -Provider $provider -Container $user -FolderPath $config.folderPath
                $targets = @(Build-Targets -Containers @($user) -RootFolder $rootFolder -ScopePath $config.folderPath)
            }
        }
        else {
            # ---- FRESH RUN: selection wizard ----
            $orgs = @(Get-VBOOrganization)
            if ($orgs.Count -eq 0) { throw 'No organizations found on this VB365 server.' }
            $organization = Show-Menu -Title 'Select organization' -Options $orgs -Label { $_.Name }

            $jobs = @(Get-VBOJob -Organization $organization)
            if ($jobs.Count -eq 0) { throw "No backup jobs found for organization '$($organization.Name)'." }
            $job = Show-Menu -Title 'Select backup job' -Options $jobs -Label { $_.Name }

            $rps = @(Get-VBORestorePoint -Job $job | Sort-Object BackupTime -Descending)
            if ($rps.Count -eq 0) { throw "No restore points found for job '$($job.Name)'." }
            $rp = Show-Menu -Title 'Select restore point' -Options $rps -Label { '{0:yyyy-MM-dd HH:mm:ss}' -f $_.BackupTime }

            # ---- detect data type + open the session we will use ----
            $ctx = Get-RestoreContext -RestorePoint $rp -Diagnose:$DiagnoseDetection
            $dataType = $ctx.DataType
            $session  = $ctx.Session
            $provider = New-RestoreProvider -DataType $dataType

            $scope = @{}   # serialized into config below

            if ($dataType -eq 'SharePoint') {
                $vespOrg = Get-VESPOrganization -Session $session
                $sites = @(Get-VESPSite -Organization $vespOrg -Recurse)
                if ($sites.Count -eq 0) { throw 'No SharePoint sites found in this restore point.' }
                if ($SiteUrl) {
                    $site = $sites | Where-Object { "$($_.Url)" -eq $SiteUrl } | Select-Object -First 1
                    if (-not $site) { throw "Site $SiteUrl not found in this restore point." }
                } else {
                    $site = Show-Menu -Title 'Select SharePoint site' -Options $sites -Label { '{0} ({1})' -f $_.Name, $_.Url }
                }

                $libraries = @(Get-VESPDocumentLibrary -Site $site)
                if ($libraries.Count -eq 0) { throw "No document libraries found in site $($site.Url)." }

                # Library menu gains an explicit "all libraries" entry.
                $allLibs = [pscustomobject]@{ Name = '== ALL libraries in this site =='; IsAllLibraries = $true }
                if ($LibraryName) {
                    $libPick = $libraries | Where-Object { $_.Name -eq $LibraryName } | Select-Object -First 1
                    if (-not $libPick) { throw "Document library '$LibraryName' not found in site $($site.Url)." }
                } else {
                    $libPick = Show-Menu -Title 'Select document library' -Options (@($allLibs) + $libraries) -Label { $_.Name }
                }

                if ($null -ne $libPick.PSObject.Properties['IsAllLibraries']) {
                    $targets = @(Build-Targets -Containers $libraries -RootFolder $null -ScopePath '/')
                    $scope = @{ siteUrl = "$($site.Url)"; siteName = "$($site.Name)"; allLibraries = $true }
                    $scopeName = $site.Name
                } else {
                    if ($FolderPath) {
                        $rootFolder = Resolve-FolderByPath -Provider $provider -Container $libPick -FolderPath $FolderPath
                        $rootPath = $FolderPath
                    } else {
                        $sel = Select-RecoveryFolder -Provider $provider -Container $libPick -ContainerLabel 'library'
                        $rootFolder = $sel.Folder
                        $rootPath = $sel.Path
                    }
                    $targets = @(Build-Targets -Containers @($libPick) -RootFolder $rootFolder -ScopePath $rootPath)
                    $scope = @{ siteUrl = "$($site.Url)"; siteName = "$($site.Name)"; libraryName = "$($libPick.Name)"; folderPath = $rootPath }
                    $scopeName = $site.Name
                }
            }
            else {
                # OneDrive: user -> (entire OneDrive | folder drill-down)
                $users = @(Get-VEODUser -Session $session)
                if ($users.Count -eq 0) { throw 'No OneDrive users found in this restore point.' }
                $user = Show-Menu -Title 'Select OneDrive user' -Options $users -Label { $_.Name }
                if ($FolderPath) {
                    $rootFolder = Resolve-FolderByPath -Provider $provider -Container $user -FolderPath $FolderPath
                    $rootPath = $FolderPath
                } else {
                    $sel = Select-RecoveryFolder -Provider $provider -Container $user -ContainerLabel 'OneDrive'
                    $rootFolder = $sel.Folder
                    $rootPath = $sel.Path
                }
                $targets = @(Build-Targets -Containers @($user) -RootFolder $rootFolder -ScopePath $rootPath)
                $scope = @{ userName = "$($user.Name)"; folderPath = $rootPath }
                $scopeName = $user.Name
            }

            $config = [pscustomobject]@{
                server                = $Server
                dataType              = $dataType
                organizationName      = $organization.Name
                jobId                 = "$($job.Id)"
                restorePointId        = "$($rp.Id)"
                itemsPerBatch         = $Items
                applicationId         = ''
                certificateThumbprint = ''
                processedItems        = @()
            }
            foreach ($k in $scope.Keys) { $config | Add-Member -NotePropertyName $k -NotePropertyValue $scope[$k] -Force }
            $safeName = Get-SafeName $scopeName
            $configFile = Join-Path $PSScriptRoot "stagedRestore-$safeName.config.json"
            $logFile = Join-Path $PSScriptRoot "stagedRestore-$safeName.log"
        }

        # ---- restore auth: app id + cert thumbprint from the org's SP settings (spec req 9) ----
        $connSettings = $organization.Office365SharePointConnectionSettings
        if (-not $connSettings -or -not $connSettings.ApplicationId) {
            throw "Organization '$($organization.Name)' has no SharePoint application (ApplicationId) configured -- this script requires app-based restore auth."
        }
        $applicationId = "$($connSettings.ApplicationId)"
        $thumbprint = ("$($connSettings.ApplicationCertificateThumbprint)" -replace '\s', '').ToUpper()
        if (-not $thumbprint) { throw "Organization '$($organization.Name)' has no ApplicationCertificateThumbprint configured." }
        $config.applicationId = $applicationId
        $config.certificateThumbprint = $thumbprint

        # ---- get a PFX for Restore-VESPItem (skipped in -DryRun: no restores happen) ----
        if (-not $DryRun) {
            if ($PfxPath) {
                $pfxPassword = Read-Host -AsSecureString -Prompt "Password for PFX $PfxPath"
                if (-not (Test-PfxThumbprint -PfxFilePath $PfxPath -Password $pfxPassword -ExpectedThumbprint $thumbprint)) {
                    throw "The PFX at $PfxPath does not match the organization's configured certificate thumbprint ($thumbprint)."
                }
                $pfxFilePath = $PfxPath
            } else {
                $pfxPassword = New-RandomPfxPassword
                $pfxFilePath = Export-OrgCertificate -Thumbprint $thumbprint -Password $pfxPassword
                $pfxIsTemp = $true
            }
        }

        # ---- save config before the first restore call (resumable from any point;
        #      a dry run also produces a config you can resume from for the real run) ----
        Save-RestoreConfig -Config $config -Path $configFile
        $targetNames = ($targets | ForEach-Object { $_.ContainerName }) -join ','
        Write-RestoreLog $logFile ("=== SESSION START: dataType={0} scope={1} targets={2} batchSize={3} dryRun={4} ===" -f $dataType, $targetNames, $targets.Count, $config.itemsPerBatch, [bool]$DryRun)
        Write-Host "Config saved to: $configFile"

        # ---- restore parameters reused for every batch ----
        # No -SiteURL (original location); no -RestoreChangedItems (skip existing).
        $restoreParams = @{
            ApplicationId                  = [guid]$applicationId
            ApplicationCertificatePath     = $pfxFilePath
            ApplicationCertificatePassword = $pfxPassword
        }
        if ($RestorePermissions) {
            foreach ($k in $provider.PermissionParams.Keys) { $restoreParams[$k] = $provider.PermissionParams[$k] }
        }
        # Impersonation is a SharePoint-only restore option; Restore-VEODDocument
        # has no -ImpersonationAccountName parameter, so only pass it when the
        # provider supports it.
        if ($provider.SupportsImpersonation -and
            $null -ne $connSettings.PSObject.Properties['ImpersonationAccountName'] -and
            $connSettings.ImpersonationAccountName) {
            $restoreParams['ImpersonationAccountName'] = "$($connSettings.ImpersonationAccountName)"
        }

        # Batch numbering and processed-id tracking are GLOBAL across all
        # targets: "all libraries" yields Batch 1, 2, 3... spanning libraries,
        # and a resume skips already-done items in every target.
        $processedIds = @($config.processedItems | ForEach-Object { "$($_.id)" })
        $runAll = $false
        $batchNum = 0

        # ---- walk every target (1 normally; one per library for "all libraries") ----
        :targetLoop foreach ($target in $targets) {
            $children = Get-FolderChildren -Provider $provider -Container $target.Container -Folder $target.RootFolder
            $total = $children.Count
            Write-RestoreLog $logFile ("=== TARGET '{0}' {1}: {2} direct child item(s); {3} already processed overall. ===" -f $target.ContainerName, $target.ScopePath, $total, $processedIds.Count)

            # ---- batch loop for this target ----
            :batchLoop while ($true) {
                $batch = @(Get-NextBatch -Children $children -ProcessedIds $processedIds -BatchSize $config.itemsPerBatch -Provider $provider)
                if ($batch.Count -eq 0) {
                    Write-RestoreLog $logFile ("Target '{0}' complete." -f $target.ContainerName)
                    break
                }
                $batchNum++
                $remaining = @($children | Where-Object { $processedIds -notcontains (Get-DocumentId -Provider $provider -Document $_) }).Count
                Write-RestoreLog $logFile ("--- Batch {0} [{1}]: {2} item(s) selected, {3} pending of {4} in target ---" -f $batchNum, $target.ContainerName, $batch.Count, $remaining, $total)

                foreach ($item in $batch) {
                    if (Test-IsFolderDocument -Provider $provider -Document $item) {
                        Write-RestoreLog $logFile ("FOLDER: {0} -- restored recursively" -f $item.Name)
                    } else {
                        Write-RestoreLog $logFile ("FILE: {0}" -f $item.Name)
                    }
                }

                $batchOutcome = 'restored'
                if ($DryRun) {
                    $batchOutcome = 'dry-run (no restore performed)'
                } else {
                    while ($true) {
                        try {
                            & $provider.RestoreCmd -Document $batch @restoreParams | Out-Null
                            break
                        } catch {
                            Write-RestoreLog $logFile ("ERROR: batch {0} failed: {1}" -f $batchNum, $_.Exception.Message)
                            $answer = (Read-Host '[R]etry, [S]kip this batch, or [Q]uit').Trim().ToUpper()
                            if ($answer -eq 'S') { $batchOutcome = 'skipped after error'; break }
                            if ($answer -eq 'Q') {
                                Write-RestoreLog $logFile 'Operator quit after batch failure. Failed batch NOT marked processed; state saved.'
                                break targetLoop
                            }
                            if ($answer -ne 'R') { Write-Host "Unrecognized input '$answer' -- retrying." }
                            Write-RestoreLog $logFile ("Retrying batch {0}..." -f $batchNum)
                        }
                    }
                }

                foreach ($item in $batch) {
                    $type = if (Test-IsFolderDocument -Provider $provider -Document $item) { 'folder' } else { 'file' }
                    if ($batchOutcome -eq 'skipped after error') { $type = "$type (skipped after error)" }
                    $itemId = Get-DocumentId -Provider $provider -Document $item
                    $config.processedItems += [pscustomobject]@{ id = $itemId; name = "$($item.Name)"; type = $type }
                    $processedIds += $itemId
                }
                if (-not $DryRun) { Save-RestoreConfig -Config $config -Path $configFile }
                Write-RestoreLog $logFile ("Batch {0} complete: {1}." -f $batchNum, $batchOutcome)

                if (-not $runAll) {
                    $answer = (Read-Host '[C]ontinue, [A]ll remaining, or [Q]uit and save').Trim().ToUpper()
                    if ($answer -eq 'A') { $runAll = $true }
                    elseif ($answer -eq 'Q') {
                        Write-RestoreLog $logFile 'Operator quit between batches. State saved.'
                        break targetLoop
                    }
                }
            }
        }
        Write-RestoreLog $logFile 'All targets processed. Staged restore complete.'
    }
    finally {
        # Cleanup on every exit path: temp PFX, restore session, connection.
        if ($pfxIsTemp -and $pfxFilePath -and (Test-Path -Path $pfxFilePath)) {
            Remove-Item -Path $pfxFilePath -Force -ErrorAction SilentlyContinue
        }
        if ($session) {
            $stopCmd = if ($provider) { $provider.StopSessionCmd } else { 'Stop-VBOSharePointItemRestoreSession' }
            try { & $stopCmd -Session $session } catch { Write-Warning "Could not stop restore session: $($_.Exception.Message)" }
        }
        if ($connected) {
            try { Disconnect-VBOServer } catch { Write-Warning "Could not disconnect from VB365: $($_.Exception.Message)" }
        }
    }
}

# Entry point -- skipped when dot-sourced (e.g. by Pester tests)
if ($MyInvocation.InvocationName -ne '.') {
    Invoke-StagedRestore
}
