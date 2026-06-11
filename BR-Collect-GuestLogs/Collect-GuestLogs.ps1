<#
   .Synopsis
    Automated collection of Windows guest OS logs for troubleshooting of Veeam Backup jobs with
    Application Aware Processing enabled (SQL/Exchange/Active Directory/SharePoint/Oracle).
   .Parameter IncludeSecurityEvents
    Include the Security event log in the exported Windows Event Logs. If omitted in an interactive
    session, a prompt is shown. In a non-interactive session (e.g. Invoke-Command), the Security
    log is excluded unless this switch is passed.
   .Parameter Force
    Suppresses the confirmation normally shown when the script is detected to be running on a
    Veeam Backup & Replication server. Required for unattended runs on a VBR server.
   .Parameter OutputDirectory
    Directory where the collected log bundle is created. Useful when the default location (a
    "Case_Logs" folder on the same volume as the Veeam log directory) is low on disk space.
    The directory is created if it does not exist.
   .Example
    Execute on guest OS server locally (run with Administrator privileges):
        .\Collect_Veeam_Guest_Logs.ps1
    Execute from remote server (run with Administrator privileges):
        Invoke-Command -FilePath <PATH_TO_THIS_SCRIPT> -ComputerName <GUEST_OS_SERVERNAME> -Credential (Get-Credential)
   .Notes
    NAME: Collect_Veeam_Guest_Logs.ps1
    VERSION: 2.0
    AUTHOR: Chris Evans, Veeam Software
    CONTACT: chris.evans@veeam.com
    LASTEDIT: 10-June-2026
    KEYWORDS: Log collection, AAiP, Guest Processing
    REQUIREMENTS: Windows PowerShell 4.0 or later. PS 4.0 ships in-box with Server 2012 R2 / Windows 8.1
    and later. Older guest OSes still supported by Veeam B&R 12 (e.g. Server 2008 R2 SP1 / Windows 7 SP1)
    must have WMF 4.0 installed. Only components shipped with a default Windows installation are used.
#>
#Requires -Version 4.0
#Requires -RunAsAdministrator
param (
    [switch] $IncludeSecurityEvents,
    [switch] $Force,
    [string] $OutputDirectory
)

$scriptVersion = "2.0"
#Capture bound parameters at script level for the summary file ($PSBoundParameters is scoped per function).
$scriptParameters = ($PSBoundParameters.Keys | ForEach-Object { "-$_" }) -join " "

#Set default width of all invocations of Out-File and redirection operators to 2000 to prevent truncation of output.
$PSDefaultParameterValues['Out-File:Width'] = 2000
#Remove enumeration limit to prevent a formatted collection of values from getting truncated
$FormatEnumerationLimit = -1

function Write-Console (
    [string] $message = "Done.",
    [string] $fgcolor = "Green",
    [int] $seconds = 0
)
{
    Write-Host $message -ForegroundColor $fgcolor
    Write-Host ""
    if ($seconds -gt 0) {
        Start-Sleep $seconds
    }
}

function New-Dir (
    [string[]] $path
)
{
    New-Item -ItemType Directory -Force -Path $path > $null
}

#Collection step runner. Each step is try/catch wrapped so one failure cannot abort the whole collection,
#and any failure is recorded so it can be written into the bundle (CollectionErrors.log) for the reviewing engineer.
$script:stepErrors = New-Object System.Collections.Generic.List[string]
function Invoke-Step (
    [string] $description,
    [scriptblock] $action
)
{
    Write-Host $description -ForegroundColor White
    try {
        $ErrorActionPreference = 'Stop'
        & $action
        Write-Console
    }
    catch {
        $message = "'$description' failed: $($_.Exception.Message)"
        Write-Console $message "Yellow"
        $script:stepErrors.Add(("{0:s}  {1}" -f (Get-Date), $message))
    }
}

function GetDBUserInfo (
    $Database
)
{
    #Ensure DB is online before checking
    if ($Database.Status -eq "Normal") {
        $Users = $Database.Users
        foreach ($User in $Users) {
            if ($User) {
                try {
                    #Get permissions for each user
                    $DBRoles = $User.EnumRoles()
                    foreach ($role in $DBRoles) {
                        $script:sqlReport.Add("`t" + $role + " on " + $Database.Name)
                    }
                    #Get any explicitly granted permissions
                    foreach ($Permission in $Database.EnumObjectPermissions($User.Name)) {
                        $script:sqlReport.Add("`t" + $Permission.PermissionState + " " + $Permission.PermissionType + " on " + $Permission.ObjectName + " in " + $Database.Name)
                    }
                }
                catch {
                    $script:sqlReport.Add("`tUnable to enumerate permissions for user '" + $User.Name + "' in " + $Database.Name + ".")
                }
            }
        }
    }
}

function LogSQLPermissions (
    $SQLServerInstance
)
{
    foreach ($SQLServer in $SQLServerInstance) {
        $Server = New-Object ("Microsoft.SqlServer.Management.Smo.Server") $SQLServer
        $script:sqlReport.Add("=================================================================================")
        $script:sqlReport.Add("SQL Instance: " + $Server.Name)
        $script:sqlReport.Add("SQL Version: " + $Server.VersionString)
        $script:sqlReport.Add("Edition: " + $Server.Edition)
        $script:sqlReport.Add("Login Mode: " + $Server.LoginMode)
        $script:sqlReport.Add("=================================================================================")
        $SQLLogins = $Server.Logins
        foreach ($SQLLogin in $SQLLogins) {
            $script:sqlReport.Add("Login          : " + $SQLLogin.Name)
            $script:sqlReport.Add("Login Type     : " + $SQLLogin.LoginType)
            $script:sqlReport.Add("Created        : " + $SQLLogin.CreateDate)
            $script:sqlReport.Add("Default DB     : " + $SQLLogin.DefaultDatabase)
            $script:sqlReport.Add("Disabled       : " + $SQLLogin.IsDisabled)
            $SQLRoles = $SQLLogin.ListMembers()
            if ($SQLRoles) {
                $script:sqlReport.Add("Server Role    : " + $SQLRoles)
            }
            else {
                $script:sqlReport.Add("Server Role    :  Public")
            }
            #Get individuals in any Windows domain groups
            if ($SQLLogin.LoginType -eq "WindowsGroup") {
                $script:sqlReport.Add("Group Members: ")
                try {
                    $ADGroupMembers = Get-ADGroupMember $SQLLogin.Name.Split("\")[1] -Recursive
                    foreach ($Member in $ADGroupMembers) {
                        $script:sqlReport.Add("   Account: " + $Member.Name + "(" + $Member.SamAccountName + ")")
                    }
                } catch {
                    #Sometimes there are 'ghost' groups left behind that are no longer in the domain. This highlights those still in SQL.
                    $script:sqlReport.Add("Unable to locate group " + $SQLLogin.Name.Split("\")[1] + " in the AD Domain.")
                }
            }
            #Check the permissions in the DBs the Login is linked to. (Errors suppressed for all SQL logins that exist but are disabled)
            $hasMappings = $false
            try { $hasMappings = [bool]$SQLLogin.EnumDatabaseMappings() } catch { }
            if ($hasMappings) {
                $script:sqlReport.Add("Permissions: ")
                foreach ($DB in $Server.Databases) {
                    GetDBUserInfo($DB)
                }
            }
            else {
                $script:sqlReport.Add("None.")
            }
            $script:sqlReport.Add("----------------------------------------------------------------------------")
        }
    }
}

#Creates a zip from a directory using .NET (available on any system with PS 4.0+). Works on all
#PowerShell versions this script supports, has no file size limitations, and runs synchronously.
function Compress-Directory (
    [string] $sourcePath,
    [string] $zipPath,
    [bool] $includeBaseDirectory = $false
)
{
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::CreateFromDirectory($sourcePath, $zipPath, [System.IO.Compression.CompressionLevel]::Optimal, $includeBaseDirectory)
}

function Add-FileToZip (
    [string] $ZipName,
    [string] $FileToAdd
)
{
    $zip = $null
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $zip = [System.IO.Compression.ZipFile]::Open($ZipName, "Update")
        $addedFile = [System.IO.Path]::GetFileName($FileToAdd)
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $FileToAdd, $addedFile, "Optimal") > $null
    }
    catch {
        Write-Host "Failed to add $FileToAdd to $ZipName. Details: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    finally {
        if ($zip) {
            $zip.Dispose()
        }
    }
}

#Builds !_SUMMARY.txt -- a triage summary of facts extracted from the data collected in this bundle.
#Advisory only: facts, not verdicts. Any section that cannot be parsed (e.g. localized vssadmin output
#on a non-English OS) degrades to an [INFO] pointing at the raw file rather than a false "all clear".
#Each section is individually try/catch wrapped so one bad parse cannot prevent the rest of the summary.
function New-SummaryFile (
    [string] $summaryPath
)
{
    $s = New-Object System.Collections.Generic.List[string]
    $rule = "=========================================================================="

    #--- Header ---
    $s.Add($rule)
    $s.Add(" VEEAM GUEST OS LOG COLLECTION SUMMARY")
    $s.Add($rule)
    $s.Add(" Script version    : $scriptVersion")
    $utcOffset = [System.TimeZoneInfo]::Local.GetUtcOffset((Get-Date))
    $offsetSign = "+"
    if ($utcOffset.Ticks -lt 0) { $offsetSign = "-" }
    $s.Add((" Collected         : {0} (UTC{1}{2:hh\:mm})" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $offsetSign, $utcOffset))
    if ($scriptParameters) {
        $s.Add(" Parameters        : $scriptParameters")
    } else {
        $s.Add(" Parameters        : (none)")
    }
    if ($isInteractive) {
        $s.Add(" Session type      : Interactive")
    } else {
        $s.Add(" Session type      : Non-interactive (remote or scheduled)")
    }
    $s.Add("")
    $s.Add(" Hostname          : $hostname")
    try {
        $os = Get-CimInstance Win32_OperatingSystem
        $s.Add(" Operating System  : $($os.Caption) (Build $($os.BuildNumber))")
        $s.Add(" PowerShell        : $($PSVersionTable.PSVersion)")
        $uptimeDays = [math]::Round(((Get-Date) - $os.LastBootUpTime).TotalDays, 0)
        $s.Add((" Last boot         : {0:yyyy-MM-dd HH:mm:ss} ({1} days ago)" -f $os.LastBootUpTime, $uptimeDays))
    }
    catch {
        $s.Add(" [INFO] Operating system details could not be read: $($_.Exception.Message)")
    }
    if ($script:hypervisor) {
        $s.Add(" Hypervisor        : $($script:hypervisor)")
        if ($script:guestToolsInfo) {
            $s.Add(" Guest tools       : $($script:guestToolsInfo)")
        }
    }
    if ($isVBR) {
        $s.Add("")
        $s.Add(" [WARN] This script was executed on a Veeam Backup & Replication server.")
    }
    $s.Add($rule)

    #--- VSS writers ---
    $s.Add("")
    $s.Add("--- VSS WRITER STATE (VSS\vss_writers.log) -------------------------------")
    try {
        $writersFile = Join-Path $VSS "vss_writers.log"
        if ($script:vssWritersTimedOut) {
            $s.Add(" [WARN] VSS Writers collection timed out after 180 seconds; vss_writers.log is missing or may be incomplete.")
        }
        if (Test-Path $writersFile) {
            $writers = @()
            $currentWriter = $null
            foreach ($line in (Get-Content $writersFile)) {
                if ($line -match "^Writer name:\s+'(.+)'") {
                    if ($currentWriter) { $writers += $currentWriter }
                    $currentWriter = [PSCustomObject]@{ Name = $matches[1]; StateNum = -1; StateText = ""; LastError = "" }
                }
                elseif ($currentWriter -and ($line -match "^\s+State:\s+\[(\d+)\]\s*(.*)$")) {
                    $currentWriter.StateNum = [int]$matches[1]
                    $currentWriter.StateText = $matches[2].Trim()
                }
                elseif ($currentWriter -and ($line -match "^\s+Last error:\s+(.*)$")) {
                    $currentWriter.LastError = $matches[1].Trim()
                }
            }
            if ($currentWriter) { $writers += $currentWriter }

            if ($writers.Count -eq 0) {
                $s.Add(" [INFO] Could not parse VSS writer states from vss_writers.log (non-English OS or unexpected format?). Review the file manually.")
            }
            else {
                #State [1] = Stable. Writers in any other state, or reporting a last error, are listed.
                $unhealthy = @($writers | Where-Object { ($_.StateNum -ne 1) -or ($_.LastError -ne 'No error') })
                if ($unhealthy.Count -gt 0) {
                    $s.Add(" [WARN] $($unhealthy.Count) of $($writers.Count) writers are not in a stable state with no errors:")
                    foreach ($w in $unhealthy) {
                        $s.Add(("        - {0,-38} State: [{1}] {2,-24} Last error: {3}" -f $w.Name, $w.StateNum, $w.StateText, $w.LastError))
                    }
                }
                else {
                    $s.Add(" [OK]   All $($writers.Count) writers stable with no errors.")
                }
            }
        }
        elseif (-not $script:vssWritersTimedOut) {
            $s.Add(" [INFO] vss_writers.log was not collected.")
        }
    }
    catch {
        $s.Add(" [INFO] VSS writer check could not be completed: $($_.Exception.Message)")
    }

    #--- VSS providers ---
    $s.Add("")
    $s.Add("--- VSS PROVIDERS (VSS\vss_providers.log) --------------------------------")
    try {
        $providersFile = Join-Path $VSS "vss_providers.log"
        if (Test-Path $providersFile) {
            #Provider IDs are locale-independent. These are the in-box Microsoft software/file share providers.
            $defaultProviderIds = @('{b5946137-7b9f-4925-af80-51abd60b20d5}', '{89300202-3cec-4981-9171-19f59559e0f2}')
            $providerContent = Get-Content $providersFile
            $providers = @()
            $currentProvider = $null
            foreach ($line in $providerContent) {
                if ($line -match "^Provider name:\s+'(.+)'") {
                    if ($currentProvider) { $providers += $currentProvider }
                    $currentProvider = [PSCustomObject]@{ Name = $matches[1]; Id = "" }
                }
                elseif ($currentProvider -and (-not $currentProvider.Id) -and ($line -match "(\{[0-9a-fA-F\-]{36}\})")) {
                    $currentProvider.Id = $matches[1].ToLower()
                }
            }
            if ($currentProvider) { $providers += $currentProvider }

            if ($providers.Count -gt 0) {
                $thirdParty = @($providers | Where-Object { $defaultProviderIds -notcontains $_.Id })
                if ($thirdParty.Count -gt 0) {
                    $s.Add(" [WARN] $($thirdParty.Count) non-default VSS provider(s) registered:")
                    foreach ($p in $thirdParty) {
                        $s.Add("        - '$($p.Name)' $($p.Id)")
                    }
                    $s.Add("        Third-party providers are a common cause of snapshot creation failures.")
                }
                else {
                    $s.Add(" [OK]   Only in-box Microsoft VSS provider(s) registered ($($providers.Count)).")
                }
            }
            else {
                #Names could not be parsed (non-English OS?) -- fall back to the locale-independent provider IDs.
                $allIds = @()
                foreach ($line in $providerContent) {
                    if ($line -match "(\{[0-9a-fA-F\-]{36}\})") { $allIds += $matches[1].ToLower() }
                }
                if ($allIds.Count -eq 0) {
                    $s.Add(" [INFO] Could not parse vss_providers.log (non-English OS or unexpected format?). Review the file manually.")
                }
                else {
                    $unknownIds = @($allIds | Where-Object { $defaultProviderIds -notcontains $_ })
                    if ($unknownIds.Count -gt 0) {
                        $s.Add(" [WARN] $($unknownIds.Count) non-default VSS provider ID(s) registered (provider names could not be parsed; non-English OS?):")
                        foreach ($id in $unknownIds) { $s.Add("        - $id") }
                        $s.Add("        Review vss_providers.log manually.")
                    }
                    else {
                        $s.Add(" [OK]   Only in-box Microsoft VSS provider ID(s) found ($($allIds.Count)).")
                    }
                }
            }
        }
        else {
            $s.Add(" [INFO] vss_providers.log was not collected.")
        }
    }
    catch {
        $s.Add(" [INFO] VSS provider check could not be completed: $($_.Exception.Message)")
    }

    #--- Key services ---
    $s.Add("")
    $s.Add("--- KEY SERVICES (services.csv) -------------------------------------------")
    try {
        if ($script:serviceData) {
            $keyServiceNames = @('VSS', 'swprv', 'EventSystem', 'COMSysApp', 'CryptSvc', 'Winmgmt')
            if ($script:sqlDetected) { $keyServiceNames += 'SQLWriter' }
            foreach ($svcName in $keyServiceNames) {
                $svc = $script:serviceData | Where-Object { $_.Name -eq $svcName } | Select-Object -First 1
                if (-not $svc) {
                    if ($svcName -eq 'SQLWriter') {
                        $s.Add(" [WARN] SQL Server VSS Writer (SQLWriter) service not found, but running SQL instance(s) were detected.")
                    }
                    continue
                }
                $flag = "[OK]  "
                if (($svc.StartMode -eq 'Disabled') -or (($svc.StartMode -eq 'Auto') -and ($svc.State -ne 'Running'))) {
                    $flag = "[WARN]"
                }
                $s.Add((" {0} {1,-48} State: {2,-9} StartMode: {3}" -f $flag, "$($svc.DisplayName) ($($svc.Name))", $svc.State, $svc.StartMode))
            }
            foreach ($svc in @($script:serviceData | Where-Object { $_.Name -like 'Veeam*' })) {
                $flag = "[OK]  "
                if (($svc.StartMode -eq 'Disabled') -or (($svc.StartMode -eq 'Auto') -and ($svc.State -ne 'Running'))) {
                    $flag = "[WARN]"
                }
                $s.Add((" {0} {1,-48} State: {2,-9} StartMode: {3}" -f $flag, "$($svc.DisplayName) ($($svc.Name))", $svc.State, $svc.StartMode))
            }
            $s.Add("        (VSS and swprv are demand-start; 'Stopped' with StartMode Manual is normal for them.)")
        }
        else {
            $s.Add(" [INFO] Service data was not collected; see CollectionErrors.log.")
        }
    }
    catch {
        $s.Add(" [INFO] Key services check could not be completed: $($_.Exception.Message)")
    }

    #--- Disk space ---
    $s.Add("")
    $s.Add("--- DISK SPACE (volume_info.csv) -------------------------------------------")
    try {
        if ($script:volumeData) {
            $checkedVolumes = @($script:volumeData | Where-Object { $_.DriveLetter -and ($_.SizeGB -gt 0) })
            $lowVolumes = 0
            foreach ($v in $checkedVolumes) {
                if (($v.PercentFree -lt 10) -or ($v.FreeGB -lt 5)) {
                    $lowVolumes++
                    $s.Add((" [WARN] {0}  {1} GB free of {2} GB ({3}%) -- below free space threshold (10% / 5 GB)" -f $v.DriveLetter, $v.FreeGB, $v.SizeGB, $v.PercentFree))
                }
            }
            if ($checkedVolumes.Count -eq 0) {
                $s.Add(" [INFO] No lettered volumes with size information found in collected volume data.")
            }
            elseif ($lowVolumes -eq 0) {
                $s.Add(" [OK]   All $($checkedVolumes.Count) lettered volume(s) above free space thresholds (10% / 5 GB).")
            }
            else {
                $s.Add(" [OK]   $($checkedVolumes.Count - $lowVolumes) other volume(s) above thresholds.")
                $s.Add("        Low free space can prevent shadow copy creation and growth.")
            }
        }
        else {
            $s.Add(" [INFO] Volume data was not collected; see CollectionErrors.log.")
        }
    }
    catch {
        $s.Add(" [INFO] Disk space check could not be completed: $($_.Exception.Message)")
    }

    #--- Filter drivers ---
    $s.Add("")
    $s.Add("--- FILTER DRIVERS (FLTMC.txt) ---------------------------------------------")
    try {
        $fltFile = "$directory\FLTMC.txt"
        if (Test-Path $fltFile) {
            #Minifilters shipped in-box with Windows. Anything else is listed for review (AV/EDR/encryption/backup agents).
            $knownMicrosoftFilters = @('bindflt', 'wcifs', 'cldflt', 'fileinfo', 'filecrypt', 'luafv', 'npsvctrig', 'wof',
                'storqosflt', 'wdfilter', 'filetrace', 'peauth', 'applockerfltr', 'datascrn', 'quota', 'dfsrro',
                'fsdepends', 'iorate', 'prjflt', 'resumekeyfilter', 'sisraw', 'unionfs', 'mssecflt', 'bfs',
                'easeflt', 'dedup', 'rsfilt', 'wimmount', 'msseccore', 'fileinfo', 'ntfs')
            $filters = @()
            foreach ($line in (Get-Content $fltFile | Where-Object { $_.Trim() })) {
                $tokens = $line.Trim() -split '\s+'
                #Data rows: FilterName NumInstances Altitude Frame. Header/separator rows will not match this shape.
                if (($tokens.Count -ge 3) -and ($tokens[1] -match '^\d+$') -and ($tokens[2] -match '^\d+(\.\d+)?$')) {
                    $filters += [PSCustomObject]@{ Name = $tokens[0]; Altitude = $tokens[2] }
                }
            }
            if ($filters.Count -eq 0) {
                $s.Add(" [INFO] Could not parse FLTMC.txt. Review the file manually.")
            }
            else {
                $unknownFilters = @($filters | Where-Object { $knownMicrosoftFilters -notcontains $_.Name.ToLower() })
                if ($unknownFilters.Count -gt 0) {
                    $s.Add(" [INFO] $($unknownFilters.Count) of $($filters.Count) registered minifilter driver(s) are not in this script's known in-box Windows filter list -- review:")
                    foreach ($f in $unknownFilters) {
                        $s.Add("        - $($f.Name) (Altitude $($f.Altitude))")
                    }
                    $s.Add("        AV/EDR/encryption filters can interfere with VSS snapshots and guest interaction.")
                }
                else {
                    $s.Add(" [OK]   All $($filters.Count) registered minifilter driver(s) are known in-box Windows filters.")
                }
            }
        }
        else {
            $s.Add(" [INFO] FLTMC.txt was not collected.")
        }
    }
    catch {
        $s.Add(" [INFO] Filter driver check could not be completed: $($_.Exception.Message)")
    }

    #--- System state ---
    $s.Add("")
    $s.Add("--- SYSTEM STATE ------------------------------------------------------------")
    try {
        $rebootReasons = @()
        if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') {
            $rebootReasons += "Component Based Servicing: RebootPending key present"
        }
        if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') {
            $rebootReasons += "Windows Update: RebootRequired key present"
        }
        $pfro = (Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -ErrorAction SilentlyContinue).PendingFileRenameOperations
        $pfroCount = @($pfro | Where-Object { $_ }).Count
        if ($rebootReasons.Count -gt 0) {
            $s.Add(" [WARN] A system reboot is pending:")
            foreach ($r in $rebootReasons) { $s.Add("        - $r") }
            if ($pfroCount -gt 0) { $s.Add("        - PendingFileRenameOperations: $pfroCount entries") }
            $s.Add("        Pending servicing operations are a known cause of VSS writer instability.")
        }
        elseif ($pfroCount -gt 0) {
            $s.Add(" [INFO] PendingFileRenameOperations: $pfroCount entries (common and often benign; no servicing reboot flags are set).")
        }
        else {
            $s.Add(" [OK]   No pending reboot indicators found.")
        }
    }
    catch {
        $s.Add(" [INFO] Pending reboot check could not be completed: $($_.Exception.Message)")
    }
    try {
        $schannelOverrides = @()
        $protocolsPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols'
        if (Test-Path $protocolsPath) {
            foreach ($proto in (Get-ChildItem $protocolsPath)) {
                foreach ($side in (Get-ChildItem $proto.PSPath)) {
                    $sideProps = Get-ItemProperty $side.PSPath
                    $settings = @()
                    if ($null -ne $sideProps.Enabled) { $settings += "Enabled=$($sideProps.Enabled)" }
                    if ($null -ne $sideProps.DisabledByDefault) { $settings += "DisabledByDefault=$($sideProps.DisabledByDefault)" }
                    if ($settings.Count -gt 0) {
                        $schannelOverrides += ("{0} {1}: {2}" -f $proto.PSChildName, $side.PSChildName, ($settings -join ", "))
                    }
                }
            }
        }
        if ($schannelOverrides.Count -gt 0) {
            $s.Add(" [INFO] SCHANNEL protocol customizations present (see network_customizations.log):")
            foreach ($o in $schannelOverrides) { $s.Add("        - $o") }
        }
        else {
            $s.Add(" [OK]   No SCHANNEL protocol overrides found.")
        }
    }
    catch {
        $s.Add(" [INFO] SCHANNEL check could not be completed: $($_.Exception.Message)")
    }

    #--- Collection health ---
    $s.Add("")
    $s.Add("--- COLLECTION HEALTH -------------------------------------------------------")
    if ($script:vssWritersTimedOut) {
        $s.Add(" [WARN] VSS Writers collection timed out after 180 seconds; vss_writers.log may be missing or incomplete.")
    }
    if ($script:stepErrors.Count -gt 0) {
        $s.Add(" [WARN] $($script:stepErrors.Count) collection step(s) failed -- see CollectionErrors.log:")
        foreach ($e in $script:stepErrors) { $s.Add("        - $e") }
    }
    else {
        $s.Add(" [OK]   All collection steps completed without recorded errors.")
    }

    $s.Add("")
    $s.Add($rule)
    $s.Add(" This summary is advisory and generated by parsing the data in this")
    $s.Add(" bundle. It is not a diagnosis. Always verify against the raw logs.")
    $s.Add($rule)

    $s | Out-File $summaryPath -Encoding utf8
}

#Check if script running in PowerShell ISE. If so, instruct to call the script again from a normal PowerShell console. This is due to PS ISE loading additional modules that can cause issues with transcription.
if ($psISE) {
    Write-Console "PowerShell ISE is not supported for this script. Please call the script from a PowerShell console (launched with Administrator privileges)." "Red" 5
    Exit
}

#Determine whether we can show GUI prompts. Remote sessions (Invoke-Command) and other non-interactive
#contexts cannot display message boxes, so all prompts must be skipped and driven by parameters instead.
$isInteractive = [Environment]::UserInteractive -and ($Host.Name -ne 'ServerRemoteHost')

#Check if running on VBR server. Prompt user for confirmation if running on VBR server, as this is rarely necessary.
$isVBR = Get-Service -Name "VeeamBackupSv*"
if ($isVBR -and -not $Force) {
    if ($isInteractive) {
        Add-Type -AssemblyName System.Windows.Forms
        $msgResult = [System.Windows.Forms.MessageBox]::Show(
            "This script is almost always intended to be executed on the server which has Guest Processing errors, not the Veeam Backup Server. Were you specifically asked to run this script on the Backup Server?",
            "Are you running this on the correct server?",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Question
        )
        if ($msgResult -ne [System.Windows.Forms.DialogResult]::Yes) {
            Exit
        }
    }
    else {
        Write-Console "This appears to be a Veeam Backup Server. This script is normally intended for the guest OS with Guest Processing errors. Continuing because this is a non-interactive session (pass -Force to suppress this warning)." "Yellow"
    }
}

#Initialize variables
$veeamDir = Join-Path $env:ProgramData "Veeam\Backup"
$veeamRegPath = 'HKLM:\SOFTWARE\Veeam\Veeam Backup and Replication'
if ((Test-Path $veeamRegPath) -and ((Get-Item -Path $veeamRegPath).Property -contains "LogDirectory")) {
    $veeamDir = (Get-ItemProperty -Path $veeamRegPath).LogDirectory
}

$date = Get-Date -f yyyy-MM-ddTHHmmss_
$temp = Join-Path $env:SystemDrive "temp"
$hostname = $env:COMPUTERNAME
if ($OutputDirectory) {
    #Validate the custom output directory early so the user gets a clear error instead of a failed collection.
    New-Dir $OutputDirectory
    if (!(Test-Path -Path $OutputDirectory)) {
        Write-Console "Unable to create or access the specified output directory: $OutputDirectory. Please verify the path and try again." "Red" 3
        Exit
    }
    $logDir = $OutputDirectory
}
else {
    $logVolume = Split-Path -Path $veeamDir -Parent
    $logDir = Join-Path -Path $logVolume -ChildPath "Case_Logs"
}
$directory = Join-Path -Path $logDir -ChildPath $date$hostname
$VBR = "$directory\Backup"
$tempEVTXEvents = "$temp\EVTXEvents"
$tempCSVEvents = "$temp\CSVEvents"
$Events = "$directory\Events"
$VSS = "$directory\VSS"
$PSVersion = $PSVersionTable.PSVersion.Major

if ($isInteractive) {
    Clear-Host
}

$disclaimerPause = 0
if ($isInteractive) { $disclaimerPause = 5 }
Write-Console "This script is provided as is as a courtesy for collecting Guest Proccessing logs from a guest server. `
Please be aware that some Windows OSes and GPOs may affect script execution. `
There is no support provided for this script, and should it fail, we ask that you please proceed to collect the required information manually." "Yellow" $disclaimerPause

#Create directories (must exist before transcription starts, since the transcript is written to $temp)
Write-Console "Creating temporary directories..." "White"
New-Dir $directory, $Events, $VSS, $temp, $tempEVTXEvents, $tempCSVEvents
#If not running on VBR server, create additional folder as destination for GuestHelper logs
if (!($isVBR)) {
    New-Dir $VBR
}
Write-Console

# Transcript all workflow
Start-Transcript -Path "$temp\Execution.log" > $null
#Stamp the script version into the console output and transcript so support knows which revision produced this bundle.
Write-Console "Collect-GuestLogs.ps1 -- script version $scriptVersion" "White"

#Copy backup folder unless being ran on VBR server. Backup folder can potentially be massive if this is ran on the VBR server.
if (!($isVBR)) {
    Invoke-Step "Copying Veeam guest operation logs..." {
        Get-ChildItem -Path $veeamDir | Copy-Item -Destination $VBR -Recurse -Force
    }
} else {
    #Create extensionless file letting engineer reviewing know that the script was ran on the customer's VBR server since this is typically not the use case
    New-Item -ItemType File -Path "$directory\!!!__THIS_SCRIPT_WAS_RAN_ON_THE_VBR_SERVER_!!!" > $null
}

#Export VSS logs
Invoke-Step "Copying VSS logs..." {
    vssadmin list providers > "$VSS\vss_providers.log"
    vssadmin list shadows > "$VSS\vss_shadows.log"
    vssadmin list shadowstorage > "$VSS\vss_shadow_storage.log"
    vssadmin list volumes > "$VSS\vss_volumes.log"

    #Handle vssadmin timeout taking more than 180 seconds
    $writersTimeout = 180
    $script:vssWritersTimedOut = $false
    $writersProcs = Start-Process -FilePath PowerShell.exe -ArgumentList "-Command `"vssadmin list writers > '$temp\vss_writers.log'`"" -PassThru -NoNewWindow
    try {
        $writersProcs | Wait-Process -Timeout $writersTimeout -ErrorAction Stop
    }
    catch {
        Write-Console "Collecting VSS Writers data has taken longer than expected. Skipping VSS Writers collection." "Yellow"
        $script:vssWritersTimedOut = $true
        $writersProcs | Stop-Process -Force
    }
    if (Test-Path "$temp\vss_writers.log") {
        Move-Item "$temp\vss_writers.log" -Destination $VSS
    }
}

#Export systeminfo
Invoke-Step "Exporting systeminfo..." {
    systeminfo > "$directory\systeminfo.log"
    if ($PSVersion -ge 5) {
        Get-ComputerInfo | Out-File "$directory\computerinfo.log" -Encoding utf8
    }
}

#Detect the hypervisor and collect guest tools information. Outdated/missing guest tools are a common cause of guest processing failures.
Invoke-Step "Collecting hypervisor and guest tools information..." {
    $hvReport = New-Object System.Collections.Generic.List[string]
    $computerSystem = Get-CimInstance Win32_ComputerSystem
    $hvReport.Add("Manufacturer : " + $computerSystem.Manufacturer)
    $hvReport.Add("Model        : " + $computerSystem.Model)
    $hvReport.Add("")

    $uninstallKeys = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )

    if (($computerSystem.Manufacturer -match "VMware") -or ($computerSystem.Model -match "VMware")) {
        $hvReport.Add("Detected hypervisor: VMware")
        $script:hypervisor = "VMware"
        $vmwareTools = Get-ItemProperty -Path $uninstallKeys -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -eq "VMware Tools" }
        if ($vmwareTools) {
            $hvReport.Add("VMware Tools version: " + $vmwareTools.DisplayVersion)
            $script:guestToolsInfo = "VMware Tools " + $vmwareTools.DisplayVersion
        }
        else {
            $hvReport.Add("VMware Tools do not appear to be installed.")
            $script:guestToolsInfo = "VMware Tools not detected"
        }
        $toolsService = Get-Service -Name "VMTools" -ErrorAction SilentlyContinue
        if ($toolsService) {
            $hvReport.Add("VMware Tools service status: " + $toolsService.Status)
        }
    }
    elseif (($computerSystem.Manufacturer -match "Microsoft") -and ($computerSystem.Model -match "Virtual Machine")) {
        $hvReport.Add("Detected hypervisor: Microsoft Hyper-V")
        $script:hypervisor = "Microsoft Hyper-V"
        $icVersion = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Virtual Machine\Auto' -ErrorAction SilentlyContinue).IntegrationServicesVersion
        if ($icVersion) {
            $hvReport.Add("Integration Services version: " + $icVersion)
            $script:guestToolsInfo = "Integration Services " + $icVersion
        }
        else {
            $hvReport.Add("Integration Services version not present in registry. (On modern guest OSes the Integration Services are serviced with the OS via Windows Update.)")
            $script:guestToolsInfo = "Integration Services serviced with the OS (no registry version)"
        }
        $hvReport.Add("")
        $hvReport.Add("Hyper-V Integration Services (vmic*) status:")
        Get-Service -Name "vmic*" | ForEach-Object {
            $hvReport.Add(("  {0,-55} {1}" -f $_.DisplayName, $_.Status))
        }
    }
    elseif ($computerSystem.Manufacturer -match "Nutanix") {
        $hvReport.Add("Detected hypervisor: Nutanix AHV")
        $script:hypervisor = "Nutanix AHV"
        $ngt = Get-ItemProperty -Path $uninstallKeys -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -match "Nutanix Guest Tools" }
        if ($ngt) {
            $hvReport.Add("Nutanix Guest Tools version: " + $ngt.DisplayVersion)
            $script:guestToolsInfo = "Nutanix Guest Tools " + $ngt.DisplayVersion
        }
        else {
            $hvReport.Add("Nutanix Guest Tools do not appear to be installed.")
            $script:guestToolsInfo = "Nutanix Guest Tools not detected"
        }
    }
    else {
        $hvReport.Add("Detected hypervisor: None recognized (physical machine or unrecognized hypervisor).")
        $script:hypervisor = "None recognized (physical machine or unrecognized hypervisor)"
    }
    $hvReport | Out-File "$directory\hypervisor_info.log" -Encoding utf8
}

#Export FLTMC (Filter Manager) minifilter driver list
Invoke-Step "Exporting FLTMC minifilter driver list..." {
    fltmc > "$directory\FLTMC.txt"
}

#Export VBR reg key values (32-bit and 64-bit values)
Invoke-Step "Exporting Veeam registry values..." {
    $regKeys = @()
    $invalidKeys = @()
    #Must test to see if registry hives exist, otherwise would cause a stack overflow error.
    if (Test-Path 'HKLM:\SOFTWARE\Veeam') {
        reg export 'HKLM\SOFTWARE\Veeam' "$directory\64-Bit_Veeam_Registry_Keys.log" > $null
        $regKeys += Get-ChildItem "HKLM:\Software\Veeam" -Recurse
    }
    if (Test-Path 'HKLM:\SOFTWARE\WOW6432Node\Veeam') {
        reg export 'HKLM\SOFTWARE\WOW6432Node\Veeam' "$directory\32-Bit_Veeam_Registry_Keys.log" > $null
        $regKeys += Get-ChildItem "HKLM:\SOFTWARE\WOW6432Node\Veeam" -Recurse
    }

    if ($regKeys) {
        foreach ($regSubKey in $regKeys) {
            $regSubKey.Property | Where-Object { $_ } | ForEach-Object {
                if ($_ -ne $_.Trim()) {
                    $invalidKeys += "$regSubkey\'$_'"
                }
            }
        }
    } else {
        Write-Output "Veeam Backup and Replication registry hives contain zero registry key values (default setting)." | Out-File "$directory\registry_values.log" -Encoding utf8
    }

    if ($invalidKeys) {
        Write-Output "The following registry value names were found to have leading or trailing whitespace (Invalid key will be wrapped in single quotes):`r`n" $invalidKeys | Out-File "$directory\invalid_registry_keys.log" -Encoding utf8
    } else {
        Write-Output "No invalid registry keys detected." | Out-File "$directory\invalid_registry_keys.log" -Encoding utf8
    }
}

#Get list of installed software from the registry uninstall keys.
#NOTE: Deliberately NOT using Win32_Product -- querying that WMI class forces Windows Installer to run a
#consistency check of every installed MSI package, which can trigger spontaneous repairs/reconfigurations,
#high CPU usage, and floods the Application event log we are about to collect.
Invoke-Step "Getting list of installed software..." {
    $uninstallKeys = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    Get-ItemProperty -Path $uninstallKeys -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName } |
        Select-Object DisplayName, DisplayVersion, Publisher, InstallDate, InstallLocation, @{Name = "ProductCode"; Expression = { $_.PSChildName } } |
        Sort-Object DisplayName |
        Export-Csv -Path "$directory\installed_software.csv" -NoTypeInformation -Encoding UTF8
}

#Get list of installed Windows updates/hotfixes (useful for cross-referencing known-bad patches affecting VSS or application writers)
Invoke-Step "Getting list of installed Windows updates/hotfixes..." {
    Get-HotFix | Sort-Object -Property InstalledOn -Descending | Select-Object HotFixID, Description, InstalledOn, InstalledBy | Format-Table -AutoSize | Out-File "$directory\installed_hotfixes.log" -Encoding utf8
}

#Check if this server is running any SQL instances and if so, enumerate permissions for each database
Invoke-Step "Checking for running SQL instances..." {
    $script:sqlReport = New-Object System.Collections.Generic.List[string]
    $hasSQLDefaultInstance = Get-Service -Name "MSSQL*" | Where-Object { $_.Status -eq "Running" -and $_.Name -eq "MSSQLSERVER" }
    $hasSQL = Get-Service -Name "MSSQL*" | Where-Object { $_.Status -eq "Running" -and ($_.Name -ne "MSSQLFDLauncher" -and $_.Name -ne "MSSQLSERVER") }
    $hasSMO = [Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo")
    $script:sqlDetected = [bool]($hasSQLDefaultInstance -or $hasSQL)
    if (!($hasSQLDefaultInstance) -and !($hasSQL)) {
        $script:sqlReport.Add("No running SQL instances were detected. If you suspect this is in error, please report it to this script's maintainer.")
        Write-Host "No running SQL instances detected. Continuing..." -ForegroundColor White
    }
    else {
        Write-Host "Found running SQL instance(s). Enumerating permissions for each database..." -ForegroundColor White
        if ($hasSQL -and $hasSMO) {
            $SQLServerInstance = @()
            foreach ($instance in $hasSQL) {
                $SQLServerInstance += ($instance.Name -replace '^.*\$', ($hostname + "\"))
            }
            LogSQLPermissions($SQLServerInstance)
        }
        if ($hasSQLDefaultInstance -and $hasSMO) {
            LogSQLPermissions($hostname)
        }
        if (!($hasSMO)) {
            $script:sqlReport.Add("Running SQL instance(s) were detected, but the SQL Server Management Objects (SMO) assembly could not be loaded. Unable to enumerate database permissions.")
        }
    }
    $script:sqlReport | Out-File "$directory\SQL_Permissions.log" -Encoding utf8
}

#Get volume information (Get-Volume requires Server 2012/Windows 8 or later; fall back to CIM on older OSes)
Invoke-Step "Getting volume information..." {
    #Numeric columns are left as plain numbers (not pre-formatted strings) so they sort correctly in a spreadsheet.
    #Volume data is kept in script scope so the summary file can reuse it.
    if (Get-Command Get-Volume -ErrorAction SilentlyContinue) {
        $script:volumeData = Get-Volume | Select-Object DriveLetter, FriendlyName, FileSystemType, DriveType, HealthStatus, OperationalStatus, @{n = "SizeGB"; e = { [math]::Round($_.Size / 1GB, 2) } }, @{n = "FreeGB"; e = { [math]::Round($_.SizeRemaining / 1GB, 2) } }, @{n = "PercentFree"; e = { if ($_.Size) { [math]::Round(($_.SizeRemaining / $_.Size) * 100, 1) } } } | Sort-Object DriveLetter
    }
    else {
        $script:volumeData = Get-CimInstance Win32_Volume | Select-Object DriveLetter, Label, FileSystem, DriveType, @{n = "SizeGB"; e = { [math]::Round($_.Capacity / 1GB, 2) } }, @{n = "FreeGB"; e = { [math]::Round($_.FreeSpace / 1GB, 2) } }, @{n = "PercentFree"; e = { if ($_.Capacity) { [math]::Round(($_.FreeSpace / $_.Capacity) * 100, 1) } } } | Sort-Object DriveLetter
    }
    $script:volumeData | Export-Csv -Path "$directory\volume_info.csv" -NoTypeInformation -Encoding UTF8
}

#Get local accounts
Invoke-Step "Getting list of local accounts..." {
    Get-CimInstance Win32_UserAccount | Select-Object AccountType, Caption, LocalAccount, SID, Domain | Export-Csv -Path "$directory\local_accounts.csv" -NoTypeInformation -Encoding UTF8
}

#Get Windows Firewall profile (Get-NetFirewallProfile requires Server 2012/Windows 8 or later; fall back to netsh)
Invoke-Step "Getting status of Windows Firewall profiles..." {
    if (Get-Command Get-NetFirewallProfile -ErrorAction SilentlyContinue) {
        Get-NetFirewallProfile | Format-List | Out-File "$directory\firewall_profiles.log" -Encoding utf8
    }
    else {
        netsh advfirewall show allprofiles > "$directory\firewall_profiles.log"
    }
}

#Get list of Windows Services' names, status, and log on account
Invoke-Step "Getting status of Windows Services..." {
    #PathName is included to help spot unquoted service paths and identify AV/filter products by install location.
    #Service data is kept in script scope so the summary file can reuse it.
    $script:serviceData = Get-CimInstance Win32_Service | Select-Object Name, DisplayName, State, StartMode, @{Name = "LogOnAs"; Expression = { $_.StartName } }, PathName | Sort-Object DisplayName
    $script:serviceData | Export-Csv -Path "$directory\services.csv" -NoTypeInformation -Encoding UTF8
}

#Get network security settings (This is where customizations such as disabling TLS 1.0/1.1 or key exchange algorithms are done)
Invoke-Step "Checking for common network customizations (ie. Is TLS 1.0/1.1 disabled? Custom key exchange algorithms?)..." {
    #Must test to see if registry hive exists, otherwise would cause a stack overflow error.
    if (Test-Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL') {
        reg export "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL" "$directory\network_customizations.log" > $null
    }
}

#Get status of 'File and Printer Sharing'
Invoke-Step "Checking if 'File and Printer Sharing' is enabled..." {
    if (Get-Command Get-NetAdapterBinding -ErrorAction SilentlyContinue) {
        Get-NetAdapterBinding | Where-Object { $_.DisplayName -match "File and Printer Sharing" } | Select-Object Name, InterfaceDescription, DisplayName, ComponentID, Enabled | Export-Csv -Path "$directory\file_and_printer_sharing.csv" -NoTypeInformation -Encoding UTF8
    }
    else {
        Write-Output "Get-NetAdapterBinding is not available on this OS version (requires Windows 8/Server 2012 or later). Unable to collect 'File and Printer Sharing' binding state." | Out-File "$directory\file_and_printer_sharing.csv" -Encoding utf8
    }
}

#Get settings of attached NICs
Invoke-Step "Getting settings of attached NICs..." {
    ipconfig /all > "$directory\ipconfig.log"
}

#Get point-in-time snapshot of TCP/UDP endpoints. Raw artifact only -- deliberately NOT referenced by
#the summary file, to avoid misinterpretation. The disclaimer is written into the file itself so it
#cannot be separated from the data.
Invoke-Step "Collecting netstat snapshot..." {
    $disclaimer = @(
        "============================================================================",
        " POINT-IN-TIME SNAPSHOT taken at collection time, outside of any backup job.",
        " Many ports used by Veeam components are bound only while a job or other",
        " operation is actively using them (for example, the 2500-3300 data",
        " transport range). The absence of any such port in this snapshot is",
        " EXPECTED outside of an active operation and is not evidence of a",
        " connectivity problem. Inbound reachability from the backup server/proxy",
        " cannot be determined from this guest-side snapshot.",
        "============================================================================",
        ""
    )
    $netstatOutput = netstat -ano
    ($disclaimer + $netstatOutput) | Out-File "$directory\netstat.log" -Encoding utf8
}

#Check if 'LocalAccountTokenFilterPolicy' registry value is enabled
Invoke-Step "Checking if 'Remote UAC' is disabled..." {
    #Must test to see if registry hive exists, otherwise would cause a stack overflow error.
    if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System') {
        reg export "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" "$directory\System_Policies.log" > $null
        $content = Get-Content "$directory\System_Policies.log"
        Write-Output "If 'LocalAccountTokenFilterPolicy' = 1 then 'RemoteUAC' has been disabled. If it does not exist or is set to '0' then it is still enabled.`r`n" | Out-File "$directory\System_Policies.log" -Encoding utf8
        $content | Out-File "$directory\System_Policies.log" -Append -Encoding utf8
    }
}

#Determine whether to include the Security event log. Driven by the -IncludeSecurityEvents parameter;
#in an interactive session without the parameter, the user is prompted. Non-interactive sessions default to excluded.
if ($IncludeSecurityEvents) {
    $includeSecurity = $true
}
elseif ($isInteractive) {
    Add-Type -AssemblyName System.Windows.Forms
    #Prompt the user. Defaults to 'No' if dialog box is closed or 'No' is selected.
    $msgResult = [System.Windows.Forms.MessageBox]::Show(
        "Do you want to include Security events? (Likely no, unless specifically requested by your Veeam support engineer.)",
        "Include Security events?",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )
    $includeSecurity = ($msgResult -eq [System.Windows.Forms.DialogResult]::Yes)
}
else {
    $includeSecurity = $false
}

#Export event viewer logs in EVTX format (full logs) and CSV format (past 14 days)
Write-Console "This step can possibly take several minutes. Please do not cancel or exit the console." "Yellow"
Invoke-Step "Exporting Windows Event Viewer logs..." {
    $evLogNames = (Get-WinEvent -ListLog * -ErrorAction SilentlyContinue | Where-Object { ($_.LogName -ne 'Security') -or $includeSecurity })
    foreach ($evLog in $evLogNames) {
        $name = $evLog.LogName
        $validName = $name -replace '/', '_'
        wevtutil epl $name "$tempEVTXEvents\$validName.evtx"
    }

    #Generate LocaleMetadata for each event log.
    Get-ChildItem -File -Path $tempEVTXEvents | ForEach-Object {
        wevtutil al $_.FullName
    }

    #Export past 14 days of event viewer logs in CSV format, streaming directly to disk to keep memory usage low.
    foreach ($evLog in $evLogNames) {
        $name = $evLog.LogName
        $validName = $name -replace '/', '_'
        Get-WinEvent -ErrorAction SilentlyContinue -FilterHashTable @{ LogName = $name; StartTime = (Get-Date).AddDays(-14) } |
            Select-Object LevelDisplayName, TimeCreated, ProviderName, Id, Message |
            Export-Csv -Path "$tempCSVEvents\$validName.csv" -NoTypeInformation
    }
    #Remove CSVs for event logs which had zero records in the past 14 days.
    Get-ChildItem -File -Path $tempCSVEvents | Where-Object { $_.Length -eq 0 } | Remove-Item -Force

    Compress-Directory -sourcePath $tempEVTXEvents -zipPath "$Events\Event_Logs_EVTX.zip"
    Compress-Directory -sourcePath $tempCSVEvents -zipPath "$Events\Event_Logs_CSV.zip"
    Remove-Item $tempEVTXEvents -Recurse -Force
    Remove-Item $tempCSVEvents -Recurse -Force
}

#Check if this is a Server Edition of Windows because Workstation Edition servers would throw an error.
if ((Get-CimInstance -ClassName Win32_OperatingSystem).ProductType -ne 1) {
    #Get status of all Windows Features.
    Invoke-Step "Retrieving list of installed features..." {
        Get-WindowsFeature | Format-Table -AutoSize | Out-File "$directory\installed_features.log" -Encoding utf8
    }
}

#Generate the triage summary at the root of the bundle. Runs after all collection steps so it can
#report on collection health. Its own failure is recorded to CollectionErrors.log like any other step.
Invoke-Step "Generating triage summary (!_SUMMARY.txt)..." {
    New-SummaryFile -summaryPath "$directory\!_SUMMARY.txt"
}

#Write step error summary into the bundle so the reviewing engineer can distinguish "collection failed" from "not present on this system".
if ($script:stepErrors.Count -gt 0) {
    $script:stepErrors | Out-File "$directory\CollectionErrors.log" -Encoding utf8
}
else {
    Write-Output "No collection errors recorded." | Out-File "$directory\CollectionErrors.log" -Encoding utf8
}

#Compress folder containing data
Invoke-Step "Compressing and zipping collected logs..." {
    Compress-Directory -sourcePath $directory -zipPath "$directory.zip" -includeBaseDirectory $true
}

#Remove temporary log folder, but only if the zip was successfully created.
if (Test-Path -Path "$directory.zip") {
    Write-Console "Removing temporary log folder..." "White"
    Remove-Item "$directory" -Recurse -Force -Confirm:$false
    if (Test-Path -Path $directory) {
        Write-Console "Problem encountered cleaning up temporary log folder. Manual cleanup may be necessary. Location: $directory" "Yellow" 3
    }
}
else {
    Write-Console "Zip file was not created successfully. Leaving uncompressed log folder in place: $directory" "Yellow" 3
}

#Test if %ProgramData%\Veeam\Backup\ exists (will be present on any Veeam component or server that is being backed up by a job with AAiP)
if (!(Test-Path -Path $veeamDir)) {
    Write-Console "Not all logs could be collected. Please verify you are executing this script on the correct server (ie. guest OS where troubleshooting is necessary)." "Yellow" 3
    Write-Console "Please find any collected logs at $logDir" "Green" 2
}
else {
    Write-Console "Log collection finished. Please find the collected logs at $logDir" "Green" 3
}

#Remove custom Out-File width setting just in case.
$PSDefaultParameterValues.Remove('Out-File:Width')

#Stop transcript, copy Execution.log into the .zip archive, then cleanup Execution.log from the temp directory.
try { Stop-Transcript > $null } catch { }
Start-Sleep -Seconds 1
if (Test-Path -Path "$directory.zip") {
    Add-FileToZip -FileToAdd "$temp\Execution.log" -ZipName ($directory + ".zip")
    Remove-Item "$temp\Execution.log" -Force
}
else {
    #Zip was not created -- preserve the transcript alongside the uncompressed log folder instead.
    Move-Item "$temp\Execution.log" -Destination $directory -Force
}

#Open Windows Explorer to the location of the created .zip file (interactive sessions only)
if ($isInteractive) {
    Explorer $logDir
    Start-Sleep 2
}
Exit
