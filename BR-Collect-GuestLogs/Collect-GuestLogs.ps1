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
    The directory is created if it does not exist. Paths containing wildcard characters
    ('[', ']', '*', '?') are not supported and are rejected at startup.
   .Parameter VeeamLogRotations
    Number of newest rotations of each Veeam log file "family" to collect. Default: 3.
    Veeam B&R v13 and later rotate logs aggressively (Name.1.log, Name.log.gz, dated
    YYYY-MM-DD_Name.zip archives), so log directories can accumulate hundreds of archived
    rotations. This limits the bundle to the N most recent files of each family (the live
    log counts as one). Pass 0 to disable filtering and collect every file (v2.0 behavior).
   .Parameter SkipFreeSpaceCheck
    Skips the preflight free-disk-space check. Before collecting anything, the script estimates the
    size of the data it is about to gather (Veeam logs after rotation filtering, event logs, plus
    staging and archive overhead) and refuses to start if the target volume(s) lack the headroom,
    because filling a volume on a production server is itself an outage risk. Use this switch only
    if you have reviewed the free space yourself and believe the estimate is wrong.
   .Example
    Execute on guest OS server locally (run with Administrator privileges):
        .\Collect_Veeam_Guest_Logs.ps1
    Execute from remote server (run with Administrator privileges):
        Invoke-Command -FilePath <PATH_TO_THIS_SCRIPT> -ComputerName <GUEST_OS_SERVERNAME> -Credential (Get-Credential)
    Collect every rotated Veeam log instead of the newest 3 of each:
        .\Collect_Veeam_Guest_Logs.ps1 -VeeamLogRotations 0
   .Notes
    NAME: Collect_Veeam_Guest_Logs.ps1
    VERSION: 3.0
    AUTHOR: Chris Evans, Veeam Software
    CONTACT: chris.evans@veeam.com
    LASTEDIT: 03-August-2026
    KEYWORDS: Log collection, AAiP, Guest Processing
    REQUIREMENTS: Windows PowerShell 4.0 or later; also runs under PowerShell 7.x. PS 4.0 ships in-box
    with Server 2012 R2 / Windows 8.1 and later. Older guest OSes still supported by Veeam B&R 12
    (e.g. Server 2008 R2 SP1 / Windows 7 SP1) must have WMF 4.0 installed. Only components shipped
    with a default Windows installation are used; no Veeam PowerShell cmdlets are required, so the
    script works identically against Veeam B&R 12.x-and-older and 13.x-and-newer environments.
    Wherever v12 and v13 differ (registry layout, log rotation scheme), the script probes for what
    actually exists on the machine rather than branching on a detected version.
#>
#Requires -Version 4.0
#Requires -RunAsAdministrator
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Interactive console tool: colored console output is the intended UI and must not pollute the success stream, which would corrupt collected data written via redirection.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Internal helper functions in a linear, non-destructive collection script; -WhatIf/-Confirm semantics are not applicable.')]
param (
    [switch] $IncludeSecurityEvents,
    [switch] $Force,
    [string] $OutputDirectory,
    [ValidateRange(0, [int]::MaxValue)]
    [int] $VeeamLogRotations = 3,
    [switch] $SkipFreeSpaceCheck
)

$scriptVersion = "3.0"
#Capture bound parameters at script level for the summary file ($PSBoundParameters is scoped per function).
#Values are rendered too: '-IncludeSecurityEvents:$false' must not show up as '-IncludeSecurityEvents',
#or the reviewing engineer would draw the opposite conclusion about what the bundle contains.
$scriptParameters = ($PSBoundParameters.GetEnumerator() | ForEach-Object {
    if (($_.Value -is [switch]) -or ($_.Value -is [bool])) {
        if ($_.Value) { "-$($_.Key)" } else { "-$($_.Key):`$false" }
    }
    else {
        "-$($_.Key) $($_.Value)"
    }
}) -join " "

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

#Returns the available bytes on the volume hosting $path, or $null when it cannot be determined
#(UNC paths, unresolvable roots). Callers must treat $null as "unknown", not as "empty" or "full".
function Get-VolumeFreeSpace (
    [string] $path
)
{
    try {
        $root = [System.IO.Path]::GetPathRoot([System.IO.Path]::GetFullPath($path))
        if (-not $root) {
            return $null
        }
        return (New-Object System.IO.DriveInfo($root)).AvailableFreeSpace
    }
    catch {
        return $null
    }
}

#Throws when the most recent native command exited nonzero. $ErrorActionPreference does not apply to
#native executables, so without this a failed vssadmin/reg/wevtutil still shows its step as "Done."
#and the reviewing engineer cannot tell an empty artifact apart from a failed collection.
function Assert-NativeSuccess (
    [string] $what
)
{
    if ($LASTEXITCODE -ne 0) {
        throw "$what exited with code $LASTEXITCODE."
    }
}

#Reduces a Veeam log file name to its rotation "family" so that rotated copies of the same log can be
#grouped and only the newest N kept. MAINTAINERS: this function decides what gets OMITTED from a support
#bundle -- after ANY change, run Test-CollectGuestLogs.ps1 (kept alongside this script; documents every
#known rotation naming scheme) under both Windows PowerShell 5.1 and PowerShell 7 before shipping.
#All known Veeam rotation schemes collapse to the same key:
#  Svc.VeeamBackup.log / Svc.VeeamBackup.1.log / Svc.VeeamBackup.log.gz   -> svc.veeambackup
#  2026-07-19_Svc.VeeamBackup.zip (v13 dated archive)                     -> svc.veeambackup
#  VeeamGuestHelper_18.02.2026.log (per-day guest helper log)             -> veeamguesthelper
function Get-LogFamilyKey (
    [string] $fileName
)
{
    $key = $fileName.ToLower()
    #Leading date stamp used by v13+ archived log bundles (e.g. '2026-07-19_Svc.VeeamBackup.zip').
    $key = $key -replace '^\d{4}-\d{2}-\d{2}[_t]', ''
    #Peel archive/log extensions from the end (handles chained extensions like '.log.gz').
    while ($key -match '\.(log|gz|zip|txt|csv|evtx|bak)$') {
        $key = $key -replace '\.(log|gz|zip|txt|csv|evtx|bak)$', ''
    }
    #Trailing per-day date suffix used by guest helper style logs (e.g. '_18.02.2026').
    $key = $key -replace '[._-]\d{1,2}\.\d{1,2}\.\d{4}$', ''
    #Trailing date or per-start timestamp suffix (e.g. '-2026-02-18', '_2026_08_03_05_33_09',
    #'_2026.08.03_05_33_45') used by Explorer/plugin service logs that open a new file per service start.
    $key = $key -replace '[._-]\d{4}[._-]\d{2}[._-]\d{2}([._-]\d{2}){0,3}$', ''
    #Trailing numeric rotation index (e.g. '.10'). Stripped once only -- a single index is all the
    #rotation schemes use, and stripping repeatedly could merge genuinely distinct log names.
    $key = $key -replace '\.\d{1,3}$', ''
    return $key
}

#Copies a Veeam log directory tree, keeping only the newest $rotationsToKeep files of each log family
#per folder (0 = copy everything). v13+ log directories accumulate hundreds of rotated .gz/.zip
#archives; filtering them is what makes collection practical, including on a VBR server itself.
#Files are grouped per source folder so identically named logs in different job folders never compete.
#Each file is copied inside its own try/catch so one unreadable file cannot abort the whole copy.
#Enumerates a Veeam log directory and applies the rotation-family filter, returning both the full file
#count and the selected files. Shared by the preflight size estimate and the actual copy so the two can
#never disagree about what would be collected.
function Select-VeeamLogFileSet (
    [string] $sourcePath,
    [int] $rotationsToKeep
)
{
    $sourceRoot = (Get-Item -LiteralPath $sourcePath).FullName.TrimEnd('\')
    #Explicit iterative walk instead of Get-ChildItem -Recurse: Windows PowerShell 5.1 follows directory
    #junctions/symlinks during recursion (PowerShell 7 does not), which risks infinite loops, collecting
    #data from outside the log directory, and the two engines selecting different files from the same
    #machine. Reparse points (junctions, symlinks) are skipped uniformly on both engines.
    $allFiles = New-Object System.Collections.Generic.List[object]
    $pendingDirs = New-Object System.Collections.Generic.Stack[string]
    $pendingDirs.Push($sourceRoot)
    while ($pendingDirs.Count -gt 0) {
        $currentDir = $pendingDirs.Pop()
        foreach ($item in @(Get-ChildItem -LiteralPath $currentDir -Force -ErrorAction SilentlyContinue)) {
            if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
                continue
            }
            if ($item.PSIsContainer) {
                $pendingDirs.Push($item.FullName)
            }
            else {
                $allFiles.Add($item)
            }
        }
    }
    if ($rotationsToKeep -gt 0) {
        $groups = $allFiles | Group-Object -Property { $_.DirectoryName + '|' + (Get-LogFamilyKey $_.Name) }
        $selected = @()
        foreach ($group in $groups) {
            $selected += @($group.Group | Sort-Object LastWriteTime -Descending | Select-Object -First $rotationsToKeep)
        }
    }
    else {
        $selected = $allFiles
    }
    return @{ SourceRoot = $sourceRoot; AllCount = $allFiles.Count; Selected = $selected }
}

function Copy-VeeamLogDirectory (
    [string] $sourcePath,
    [string] $destinationPath,
    [int] $rotationsToKeep
)
{
    $selection = Select-VeeamLogFileSet -sourcePath $sourcePath -rotationsToKeep $rotationsToKeep
    $sourceRoot = $selection.SourceRoot
    $filesToCopy = $selection.Selected

    $failedFiles = New-Object System.Collections.Generic.List[string]
    foreach ($file in $filesToCopy) {
        try {
            $relativePath = $file.FullName.Substring($sourceRoot.Length).TrimStart('\')
            $targetPath = Join-Path $destinationPath $relativePath
            $targetDir = Split-Path $targetPath -Parent
            if (!(Test-Path -LiteralPath $targetDir)) {
                New-Dir $targetDir
            }
            Copy-Item -LiteralPath $file.FullName -Destination $targetPath -Force -ErrorAction Stop
        }
        catch {
            #Record WHICH file failed and why, so the reviewing engineer can tell exactly what is
            #missing from the bundle instead of just how many files are.
            $failedFiles.Add(("{0} ({1})" -f $file.FullName, $_.Exception.Message))
        }
    }

    $script:veeamLogStats = "Copied $($filesToCopy.Count - $failedFiles.Count) of $($selection.AllCount) files"
    if ($rotationsToKeep -gt 0) {
        $script:veeamLogStats += " (keeping the $rotationsToKeep newest rotation(s) of each log family; -VeeamLogRotations 0 collects all)"
    }
    if ($failedFiles.Count -gt 0) {
        #Throw so the step is recorded as degraded in CollectionErrors.log; the successful copies are already on disk.
        $shownFailures = @($failedFiles | Select-Object -First 10)
        $moreFailures = ""
        if ($failedFiles.Count -gt 10) {
            $moreFailures = "; and $($failedFiles.Count - 10) more"
        }
        throw "$($failedFiles.Count) file(s) could not be copied: $($shownFailures -join '; ')$moreFailures. $($script:veeamLogStats)."
    }
}

#Inventories installed Veeam components by resolving each Veeam* service binary and reading its file
#version. This works identically on v12 and v13 -- unlike the 'Veeam Backup and Replication' registry
#key, which no longer exists in v13 -- and needs no Veeam PowerShell cmdlets.
function Get-VeeamComponentInventory
{
    $components = New-Object System.Collections.Generic.List[object]
    $veeamServices = @(Get-CimInstance Win32_Service -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'Veeam*' })
    foreach ($svc in $veeamServices) {
        $exePath = $null
        $version = $null
        if ($svc.PathName) {
            if ($svc.PathName.StartsWith('"')) {
                $exePath = $svc.PathName.Split('"')[1]
            }
            else {
                $exePath = $svc.PathName.Split(' ')[0]
            }
            try {
                $version = (Get-Item -LiteralPath $exePath -ErrorAction Stop).VersionInfo.FileVersion
            }
            catch {
                $version = $null
            }
        }
        $components.Add([PSCustomObject]@{
            Service     = $svc.Name
            DisplayName = $svc.DisplayName
            State       = $svc.State
            StartMode   = $svc.StartMode
            Version     = $version
            Path        = $exePath
        })
    }
    return , $components
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

#Reports the roles and explicit permissions of ONE database user in ONE database. Called once per
#login-to-database mapping, so total work scales with the number of actual mappings -- not with
#logins x databases x users as the previous all-users walk did.
function GetDBUserInfo (
    $Database,
    [string] $UserName
)
{
    if ((-not $Database) -or (-not $UserName)) {
        return
    }
    #Ensure DB is online before checking
    if ($Database.Status -ne "Normal") {
        $script:sqlReport.Add("`t(Database '" + $Database.Name + "' is not online; permissions not enumerated.)")
        return
    }
    $User = $Database.Users[$UserName]
    if (-not $User) {
        $script:sqlReport.Add("`t(User '" + $UserName + "' was not found in database '" + $Database.Name + "'.)")
        return
    }
    try {
        #Get roles held by this user
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
                $groupName = $SQLLogin.Name.Split("\")[1]
                #Guard rails on group expansion: recursive enumeration hammers a domain controller, can
                #run for minutes, and a support bundle has no need for thousands of account names. (AD
                #Web Services also refuses Get-ADGroupMember on groups beyond 5000 members.) SIDs are
                #compared instead of names so the checks hold on non-English systems.
                $skipReason = $null
                $groupSid = $null
                try { $groupSid = (New-Object System.Security.Principal.SecurityIdentifier(($SQLLogin.Sid), 0)).Value } catch { $groupSid = $null }
                #Effectively-all-of-domain principals: Domain Users (-513), Domain Computers (-515),
                #Everyone (S-1-1-0), Authenticated Users (S-1-5-11).
                if ($groupSid -and (($groupSid -match '-513$') -or ($groupSid -match '-515$') -or ($groupSid -eq 'S-1-1-0') -or ($groupSid -eq 'S-1-5-11'))) {
                    $skipReason = "Membership enumeration skipped: this principal effectively includes the entire domain."
                }
                if (-not $skipReason) {
                    try {
                        $directMemberCount = @((Get-ADGroup -Identity $groupName -Properties Members -ErrorAction Stop).Members).Count
                        if ($directMemberCount -gt 500) {
                            $skipReason = "Membership enumeration skipped: group has $directMemberCount direct members (threshold: 500)."
                        }
                    }
                    catch {
                        #Count could not be read (module missing, ghost group) -- fall through to the
                        #enumeration attempt below, whose error handling reports those cases precisely.
                        Write-Verbose "Direct member count for '$groupName' could not be read: $($_.Exception.Message)"
                    }
                }
                if ($skipReason) {
                    $script:sqlReport.Add("   " + $skipReason)
                }
                else {
                    try {
                        $ADGroupMembers = Get-ADGroupMember $groupName -Recursive
                        foreach ($Member in $ADGroupMembers) {
                            $script:sqlReport.Add("   Account: " + $Member.Name + "(" + $Member.SamAccountName + ")")
                        }
                    } catch {
                        if (Get-Command Get-ADGroupMember -ErrorAction SilentlyContinue) {
                            #Sometimes there are 'ghost' groups left behind that are no longer in the domain. This highlights those still in SQL.
                            $script:sqlReport.Add("Unable to locate group " + $groupName + " in the AD Domain.")
                        }
                        else {
                            $script:sqlReport.Add("Unable to enumerate members of group '" + $SQLLogin.Name + "': the ActiveDirectory PowerShell module is not installed on this server.")
                        }
                    }
                }
            }
            #Check the permissions in the DBs the Login is linked to. (Errors suppressed for all SQL logins that exist but are disabled)
            #Only the databases this login is actually mapped to are visited, and within each only this
            #login's own database user -- work scales with the number of mappings instead of walking
            #every user of every database once per login.
            #(SMO returns $null -- not an empty array -- for logins without mappings, and @($null) has
            #Count 1, so nulls must be filtered or the loop would run once with a null mapping.)
            $mappings = @()
            try { $mappings = @($SQLLogin.EnumDatabaseMappings() | Where-Object { $null -ne $_ }) } catch { $mappings = @() }
            if ($mappings.Count -gt 0) {
                $script:sqlReport.Add("Permissions: ")
                foreach ($mapping in $mappings) {
                    GetDBUserInfo -Database $Server.Databases[$mapping.DBName] -UserName $mapping.UserName
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
    try {
        [System.IO.Compression.ZipFile]::CreateFromDirectory($sourcePath, $zipPath, [System.IO.Compression.CompressionLevel]::Optimal, $includeBaseDirectory)
    }
    catch {
        #Never leave a partial archive behind. Downstream logic treats an existing zip as a successful
        #collection (and deletes the uncompressed data), so a truncated archive -- the typical result of
        #the volume filling up mid-compression -- must not be allowed to pass for a real one.
        if (Test-Path -LiteralPath $zipPath) {
            Remove-Item -LiteralPath $zipPath -Force -ErrorAction SilentlyContinue
        }
        throw
    }
}

#Returns $true only if the file can be opened end-to-end as a zip archive with at least one entry.
#Used to gate deletion of the uncompressed data folder: Test-Path alone would accept a partial or
#corrupt archive, and the collected data must never be deleted on the strength of one of those.
function Test-ZipArchive (
    [string] $zipPath
)
{
    $zip = $null
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $zip = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
        return ($zip.Entries.Count -gt 0)
    }
    catch {
        return $false
    }
    finally {
        if ($zip) {
            $zip.Dispose()
        }
    }
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

#Restricts a collected file/folder to Administrators, SYSTEM, and the invoking user. The collected data
#is sensitive (accounts, SQL permissions, event logs) and the default output location may otherwise
#inherit ACLs that grant all local users read access (e.g. under %ProgramData%). SIDs are used instead
#of account names so this works on non-English systems.
function Protect-Path (
    [string] $path
)
{
    $inheritance = "None"
    if (Test-Path -LiteralPath $path -PathType Container) {
        $inheritance = "ContainerInherit,ObjectInherit"
    }
    #-ErrorAction Stop so a failure is always terminating: callers treat an unprotected output location
    #as fatal, and a silently ignored Set-Acl error would defeat that.
    $acl = Get-Acl -LiteralPath $path -ErrorAction Stop
    #Disable inheritance and discard inherited entries, then grant explicit full control only.
    $acl.SetAccessRuleProtection($true, $false)
    $adminsSid = New-Object System.Security.Principal.SecurityIdentifier([System.Security.Principal.WellKnownSidType]::BuiltinAdministratorsSid, $null)
    $systemSid = New-Object System.Security.Principal.SecurityIdentifier([System.Security.Principal.WellKnownSidType]::LocalSystemSid, $null)
    $currentUserSid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User
    foreach ($sid in @($adminsSid, $systemSid, $currentUserSid)) {
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($sid, "FullControl", $inheritance, "None", "Allow")
        $acl.AddAccessRule($rule)
    }
    Set-Acl -LiteralPath $path -AclObject $acl -ErrorAction Stop
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
    if ($script:veeamSummaryLine) {
        $s.Add(" Veeam components  : $($script:veeamSummaryLine)")
        $s.Add("                     (full inventory in veeam_component_versions.log)")
    }
    elseif ($script:veeamComponents -and ($script:veeamComponents.Count -eq 0)) {
        $s.Add(" Veeam components  : No Veeam services detected on this machine.")
    }
    if ($script:vbrMajorVersion -ge 13) {
        $s.Add(" [INFO] VBR v13+: advanced options live in the configuration database, not the registry (see v13_registry_note.log).")
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
            #Minifilters confidently known to ship in-box with Windows. This list is a fast path only:
            #any filter NOT in it has its driver binary's publisher metadata checked before being flagged,
            #so newly introduced in-box Microsoft filters (e.g. UCPD) are not misreported as third-party.
            $knownMicrosoftFilters = @('bindflt', 'wcifs', 'cldflt', 'cimfs', 'fileinfo', 'filecrypt', 'luafv', 'npsvctrig',
                'wof', 'storqosflt', 'wdfilter', 'wddevflt', 'applockerfltr', 'datascrn', 'quota', 'dfsrro',
                'fsdepends', 'iorate', 'prjflt', 'resumekeyfilter', 'sisraw', 'mssecflt', 'msseccore', 'bfs',
                'wcnfs', 'dedup', 'wimmount', 'peauth', 'ucpd')
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
                $candidates = @($filters | Where-Object { $knownMicrosoftFilters -notcontains $_.Name.ToLower() })
                $unknownFilters = @()
                if ($candidates.Count -gt 0) {
                    #Fallback check: minifilter names normally match their driver service name, so resolve the
                    #driver binary and read its publisher. Publisher metadata is self-declared (not a signature
                    #check), but is sufficient for an advisory triage hint; FLTMC.txt remains the source of truth.
                    $driverIndex = @{}
                    try {
                        Get-CimInstance Win32_SystemDriver | ForEach-Object {
                            if ($_.Name -and $_.PathName) { $driverIndex[$_.Name.ToLower()] = $_.PathName }
                        }
                    }
                    catch { Write-Verbose "Driver service index could not be built: $($_.Exception.Message)" }
                    foreach ($f in $candidates) {
                        $company = $null
                        $driverPath = $driverIndex[$f.Name.ToLower()]
                        if ($driverPath) {
                            $driverPath = $driverPath -replace '^\\\?\?\\', ''
                            try { $company = (Get-Item -LiteralPath $driverPath -ErrorAction Stop).VersionInfo.CompanyName } catch { $company = $null }
                        }
                        if ($company -notmatch '^Microsoft') {
                            $unknownFilters += $f
                        }
                    }
                }
                if ($unknownFilters.Count -gt 0) {
                    $s.Add(" [INFO] $($unknownFilters.Count) of $($filters.Count) registered minifilter driver(s) are not known in-box Windows filters -- review:")
                    foreach ($f in $unknownFilters) {
                        $s.Add("        - $($f.Name) (Altitude $($f.Altitude))")
                    }
                    $s.Add("        AV/EDR/encryption filters can interfere with VSS snapshots and guest interaction.")
                }
                else {
                    $s.Add(" [OK]   All $($filters.Count) registered minifilter driver(s) are in-box Windows filters or report Microsoft as the driver publisher.")
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

    #--- Hosts file ---
    $s.Add("")
    $s.Add("--- HOSTS FILE (hosts.txt) --------------------------------------------------")
    try {
        $hostsFile = "$directory\hosts.txt"
        if (Test-Path $hostsFile) {
            $activeEntries = @(Get-Content $hostsFile | Where-Object { $_.Trim() -and ($_.Trim() -notmatch '^#') })
            if ($activeEntries.Count -eq 0) {
                $s.Add(" [OK]   No active (uncommented) entries -- name resolution is not overridden by the hosts file.")
            }
            else {
                $s.Add(" [INFO] $($activeEntries.Count) active (uncommented) entries present -- verify none override names involved in this case:")
                $maxListed = 15
                foreach ($entry in ($activeEntries | Select-Object -First $maxListed)) {
                    $s.Add("        " + $entry.Trim())
                }
                if ($activeEntries.Count -gt $maxListed) {
                    $s.Add("        ... and $($activeEntries.Count - $maxListed) more (see hosts.txt).")
                }
            }
            if (Test-Path "$directory\lmhosts.txt") {
                $s.Add(" [INFO] An lmhosts file is also present (NetBIOS name overrides) -- see lmhosts.txt.")
            }
        }
        else {
            $s.Add(" [INFO] hosts.txt was not collected (no hosts file was found on this system).")
        }
    }
    catch {
        $s.Add(" [INFO] Hosts file check could not be completed: $($_.Exception.Message)")
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
    if ($script:veeamLogStats) {
        $s.Add(" [INFO] Veeam log copy: $($script:veeamLogStats).")
    }
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
    Exit 1
}

#Determine whether we can show GUI prompts. Remote sessions (Invoke-Command) and other non-interactive
#contexts cannot display message boxes, so all prompts must be skipped and driven by parameters instead.
$isInteractive = [Environment]::UserInteractive -and ($Host.Name -ne 'ServerRemoteHost')

#Shows a Yes/No message box and returns $true/$false. Returns $null if the dialog could not be shown at
#all (e.g. WinForms unavailable on this host) so the caller can apply its own safe default.
#-defaultNo makes 'No' the default button, so a reflexive Enter press gives the conservative answer.
function Show-YesNoPrompt (
    [string] $message,
    [string] $title,
    [bool] $defaultNo = $false
)
{
    $owner = $null
    try {
        Add-Type -AssemblyName System.Windows.Forms
        #A TopMost owner window forces the dialog above other windows; without one, the message box can
        #open behind the console or another application and make the script look hung.
        $owner = New-Object System.Windows.Forms.Form
        $owner.TopMost = $true
        $defaultButton = [System.Windows.Forms.MessageBoxDefaultButton]::Button1
        if ($defaultNo) {
            $defaultButton = [System.Windows.Forms.MessageBoxDefaultButton]::Button2
        }
        $msgResult = [System.Windows.Forms.MessageBox]::Show(
            $owner,
            $message,
            $title,
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Question,
            $defaultButton
        )
        return ($msgResult -eq [System.Windows.Forms.DialogResult]::Yes)
    }
    catch {
        return $null
    }
    finally {
        if ($owner) {
            $owner.Dispose()
        }
    }
}

#Check if running on VBR server. Prompt user for confirmation if running on VBR server, as this is rarely necessary.
$isVBR = Get-Service -Name "VeeamBackupSv*"
if ($isVBR -and -not $Force) {
    if ($isInteractive) {
        $promptResult = Show-YesNoPrompt -title "Are you running this on the correct server?" -message `
            "This script is almost always intended to be executed on the server which has Guest Processing errors, not the Veeam Backup Server. Were you specifically asked to run this script on the Backup Server?"
        if ($promptResult -eq $false) {
            Exit
        }
        if ($null -eq $promptResult) {
            Write-Console "This appears to be a Veeam Backup Server, and the confirmation dialog could not be displayed. Continuing; pass -Force to suppress this warning, or Ctrl+C now to abort." "Yellow" 5
        }
    }
    else {
        Write-Console "This appears to be a Veeam Backup Server. This script is normally intended for the guest OS with Guest Processing errors. Continuing because this is a non-interactive session (pass -Force to suppress this warning)." "Yellow"
    }
}

#Initialize variables
#Log directory override: v12 and older store LogDirectory under the 64-bit VBR key. That key no longer
#exists in v13+ (a WOW6432Node copy may exist), so both locations are probed; if neither defines an
#override, the default %ProgramData%\Veeam\Backup applies -- which is also where v13 writes its logs.
$veeamDir = Join-Path $env:ProgramData "Veeam\Backup"
$veeamRegPaths = @(
    'HKLM:\SOFTWARE\Veeam\Veeam Backup and Replication',
    'HKLM:\SOFTWARE\WOW6432Node\Veeam\Veeam Backup and Replication'
)
foreach ($veeamRegPath in $veeamRegPaths) {
    if ((Test-Path $veeamRegPath) -and ((Get-Item -Path $veeamRegPath).Property -contains "LogDirectory")) {
        $veeamDir = (Get-ItemProperty -Path $veeamRegPath).LogDirectory
        break
    }
}

$date = Get-Date -f yyyy-MM-ddTHHmmss_
#Unique per-run working directory under %windir%\Temp (writable only by Administrators/SYSTEM). Using a
#randomized name in a protected location prevents pre-planted file/junction attacks against this elevated
#script, avoids clobbering pre-existing files (e.g. C:\temp\Execution.log), and allows concurrent runs.
$temp = Join-Path $env:windir ("Temp\VeeamGuestLogs_" + [guid]::NewGuid().ToString("N"))
$hostname = $env:COMPUTERNAME
if ($OutputDirectory) {
    $logDir = $OutputDirectory
}
else {
    $logVolume = Split-Path -Path $veeamDir -Parent
    $logDir = Join-Path -Path $logVolume -ChildPath "Case_Logs"
}
#Paths containing wildcard characters are rejected up front: several cmdlets used downstream treat
#'[', ']', '*' and '?' in -Path arguments as wildcard patterns (with version-dependent quirks), and
#declining to run is safer than risking a file operation resolving to an unintended location.
#(Checked on the resolved path so a wildcard in a registry-derived Veeam log directory is caught too.)
if ($logDir -match '[\[\]\*\?]') {
    Write-Console "The output directory path contains wildcard characters ('[', ']', '*' or '?') which are not supported: $logDir. Please specify a different path with -OutputDirectory." "Red" 3
    Exit 1
}
if ($OutputDirectory) {
    #Validate the custom output directory early so the user gets a clear error instead of a failed collection.
    New-Dir $OutputDirectory
    if (!(Test-Path -LiteralPath $OutputDirectory)) {
        Write-Console "Unable to create or access the specified output directory: $OutputDirectory. Please verify the path and try again." "Red" 3
        Exit 1
    }
}
$directory = Join-Path -Path $logDir -ChildPath $date$hostname
#Defaults for values populated by collection steps and consumed by the summary file, so that a failed
#step degrades to "not collected" in the summary instead of referencing undefined variables.
$script:veeamComponents = $null
$script:veeamSummaryLine = $null
$script:vbrVersion = $null
$script:vbrMajorVersion = 0
$script:veeamLogStats = $null
$VBR = "$directory\Backup"
#Event logs are staged uncompressed inside the (ACL-protected) output folder rather than on the system
#drive: this puts the bulk of the disk load on the volume the operator chose with -OutputDirectory, and
#if the export step fails partway, whatever was staged still ships inside the final archive instead of
#being stranded in %windir%\Temp. The staging folder is removed once the event zips are built.
$eventStaging = "$directory\_EventStaging"
$tempEVTXEvents = "$eventStaging\EVTXEvents"
$tempCSVEvents = "$eventStaging\CSVEvents"
$Events = "$directory\Events"
$VSS = "$directory\VSS"
$PSVersion = $PSVersionTable.PSVersion.Major

if ($isInteractive) {
    #Guarded: PowerShell 7 raises "The handle is invalid" from Clear-Host when there is no real console
    #(e.g. output redirected or launched from a service), even though the session reports as interactive.
    try { Clear-Host } catch { Write-Verbose "Console could not be cleared: $($_.Exception.Message)" }
}

#Preflight: estimate the size of the data about to be collected and verify the target volume(s) have
#the headroom BEFORE anything is written. Filling a volume on a production server is itself an outage
#risk, so the script refuses to start rather than run the disk out of space partway through. The
#estimate is deliberately generous (staging + folder + archives); -SkipFreeSpaceCheck overrides it.
if (-not $SkipFreeSpaceCheck) {
    Write-Console "Estimating collection size and checking free disk space..." "White"
    $estimatedDataBytes = [long]0
    if (Test-Path -LiteralPath $veeamDir) {
        $preflightSelection = Select-VeeamLogFileSet -sourcePath $veeamDir -rotationsToKeep $VeeamLogRotations
        foreach ($file in $preflightSelection.Selected) {
            $estimatedDataBytes += [long]$file.Length
        }
    }
    #Event logs are staged uncompressed before zipping. Security is counted only when the parameter
    #already asks for it; a later interactive "Yes" to the Security prompt is absorbed by the margin.
    Get-WinEvent -ListLog * -ErrorAction SilentlyContinue |
        Where-Object { ($_.LogName -ne 'Security') -or [bool]$IncludeSecurityEvents } |
        ForEach-Object { $estimatedDataBytes += [long]$_.FileSize }

    $freeOutputBytes = Get-VolumeFreeSpace -path $logDir
    $freeTempBytes = Get-VolumeFreeSpace -path $temp
    $outputRoot = $null
    $tempRoot = $null
    try { $outputRoot = [System.IO.Path]::GetPathRoot([System.IO.Path]::GetFullPath($logDir)) } catch { $outputRoot = $null }
    try { $tempRoot = [System.IO.Path]::GetPathRoot([System.IO.Path]::GetFullPath($temp)) } catch { $tempRoot = $null }
    $sameVolume = ($outputRoot -and $tempRoot -and ($outputRoot -ieq $tempRoot))

    #Peak usage: uncompressed bundle incl. event staging (~1x), temporary archive in $temp (<=1x),
    #final archive (<=1x). Same-volume runs bear all three at once.
    if ($sameVolume) {
        $requiredOutputBytes = [long]($estimatedDataBytes * 3) + 512MB
    }
    else {
        $requiredOutputBytes = [long]($estimatedDataBytes * 2) + 512MB
        $requiredTempBytes = [long]$estimatedDataBytes + 256MB
        if (($null -ne $freeTempBytes) -and ($freeTempBytes -lt $requiredTempBytes)) {
            Write-Console ("Insufficient free space on the system volume for temporary staging: an estimated {0:N1} GB is needed under '{1}' but only {2:N1} GB is available. Free up space on the system volume, or pass -SkipFreeSpaceCheck to override this estimate." -f ($requiredTempBytes / 1GB), $temp, ($freeTempBytes / 1GB)) "Red" 3
            Exit 1
        }
    }
    if (($null -ne $freeOutputBytes) -and ($freeOutputBytes -lt $requiredOutputBytes)) {
        Write-Console ("Insufficient free space for log collection: an estimated {0:N1} GB is needed (collected data, staging and archives) but only {1:N1} GB is available on the volume of '{2}'. Free up space, use -OutputDirectory to target a larger volume, or pass -SkipFreeSpaceCheck to override this estimate." -f ($requiredOutputBytes / 1GB), ($freeOutputBytes / 1GB), $logDir) "Red" 3
        Exit 1
    }
    if ($null -eq $freeOutputBytes) {
        Write-Console "Free space on '$logDir' could not be determined (network path?). Skipping the free-space check; ensure the location has several GB of headroom." "Yellow"
    }
}

$disclaimerPause = 0
if ($isInteractive) { $disclaimerPause = 5 }
Write-Console "This script is provided as is as a courtesy for collecting Guest Proccessing logs from a guest server. `
Please be aware that some Windows OSes and GPOs may affect script execution. `
There is no support provided for this script, and should it fail, we ask that you please proceed to collect the required information manually." "Yellow" $disclaimerPause

#Create the output root and the working directory (the transcript is written to $temp, so both must
#exist before transcription starts).
Write-Console "Creating temporary directories..." "White"
New-Dir $directory, $temp
Write-Console

#Restrict the output folder before anything is created inside it. FATAL on failure: everything this
#script collects is sensitive (accounts, permissions, event logs) and must never be written to a
#location whose permissions cannot be restricted (e.g. a FAT32 volume or some network shares).
Write-Host "Restricting permissions on the output folder..." -ForegroundColor White
try {
    Protect-Path -path $directory
    Write-Console
}
catch {
    Write-Console "Unable to restrict permissions on the output folder '$directory': $($_.Exception.Message)" "Red"
    Write-Console "Collection aborted before any data was gathered. Please re-run with -OutputDirectory pointing to a local NTFS volume." "Red" 5
    Remove-Item -LiteralPath $directory -Recurse -Force -ErrorAction SilentlyContinue
    Exit 1
}

#Create the rest of the folder structure inside the now-protected output folder, so every subfolder
#and file carries the restricted ACL from the moment it exists.
New-Dir $Events, $VSS, $VBR, $tempEVTXEvents, $tempCSVEvents

# Transcript all workflow (guarded: a transcript may already be running in the calling host)
try {
    Start-Transcript -Path "$temp\Execution.log" > $null
}
catch {
    Write-Console "Unable to start transcript: $($_.Exception.Message). Continuing without transcription." "Yellow"
}
#Stamp the script version into the console output and transcript so support knows which revision produced this bundle.
Write-Console "Collect-GuestLogs.ps1 -- script version $scriptVersion" "White"

#Copy the Veeam log folder. On a VBR server this folder can be massive (v13+ especially rotates heavily),
#which is why v2.0 skipped it there entirely; the rotation filter now makes VBR-side collection practical,
#so the logs are collected everywhere and the marker file still flags VBR-server runs for the reviewing engineer.
if ($isVBR) {
    #Create extensionless file letting engineer reviewing know that the script was ran on the customer's VBR server since this is typically not the use case
    New-Item -ItemType File -Path "$directory\!!!__THIS_SCRIPT_WAS_RAN_ON_THE_VBR_SERVER_!!!" -Force > $null
    if ($VeeamLogRotations -gt 0) {
        Write-Console "Running on a VBR server: collecting the $VeeamLogRotations newest rotation(s) of each Veeam server log. Pass -VeeamLogRotations 0 to collect everything (bundle may be very large)." "Yellow"
    }
}
Invoke-Step "Copying Veeam logs..." {
    if (Test-Path -LiteralPath $veeamDir) {
        Copy-VeeamLogDirectory -sourcePath $veeamDir -destinationPath $VBR -rotationsToKeep $VeeamLogRotations
        Write-Host $script:veeamLogStats -ForegroundColor White
    }
    else {
        throw "Veeam log directory '$veeamDir' does not exist on this machine."
    }
}

#Export VSS logs
Invoke-Step "Copying VSS logs..." {
    vssadmin list providers > "$VSS\vss_providers.log"
    Assert-NativeSuccess "vssadmin list providers"
    vssadmin list shadows > "$VSS\vss_shadows.log"
    Assert-NativeSuccess "vssadmin list shadows"
    vssadmin list shadowstorage > "$VSS\vss_shadow_storage.log"
    Assert-NativeSuccess "vssadmin list shadowstorage"
    vssadmin list volumes > "$VSS\vss_volumes.log"
    Assert-NativeSuccess "vssadmin list volumes"

    #'vssadmin list writers' can hang indefinitely when the VSS infrastructure is wedged (a state this
    #script frequently runs in), so it is started directly with its output redirected and killed on
    #timeout -- vssadmin.exe itself, not an intermediary shell, so nothing lingers holding VSS busy.
    $writersTimeout = 180
    $script:vssWritersTimedOut = $false
    $writersProc = Start-Process -FilePath vssadmin.exe -ArgumentList 'list', 'writers' -RedirectStandardOutput "$temp\vss_writers.log" -PassThru -NoNewWindow
    try {
        $writersProc | Wait-Process -Timeout $writersTimeout -ErrorAction Stop
    }
    catch {
        Write-Console "Collecting VSS Writers data has taken longer than expected. Skipping VSS Writers collection." "Yellow"
        $script:vssWritersTimedOut = $true
        $writersProc | Stop-Process -Force
    }
    if (Test-Path "$temp\vss_writers.log") {
        Move-Item "$temp\vss_writers.log" -Destination $VSS
    }
}

#Export systeminfo
Invoke-Step "Exporting systeminfo..." {
    systeminfo > "$directory\systeminfo.log"
    Assert-NativeSuccess "systeminfo"
    if ($PSVersion -ge 5) {
        Get-ComputerInfo | Out-File "$directory\computerinfo.log" -Encoding utf8
    }
}

#Inventory installed Veeam components and their binary versions. Binary versions are the only version
#source that works across v12 and v13 (v13 removed the VBR registry key that used to carry this).
Invoke-Step "Detecting installed Veeam components and versions..." {
    $script:veeamComponents = Get-VeeamComponentInventory
    if ($script:veeamComponents.Count -gt 0) {
        $script:veeamComponents | Sort-Object Service |
            Format-Table Service, DisplayName, State, StartMode, Version, Path -AutoSize |
            Out-File "$directory\veeam_component_versions.log" -Encoding utf8
    }
    else {
        Write-Output "No Veeam services were found on this machine." | Out-File "$directory\veeam_component_versions.log" -Encoding utf8
    }

    #Derive the headline component versions used by the summary file.
    $script:vbrVersion = ($script:veeamComponents | Where-Object { $_.Service -eq 'VeeamBackupSvc' } | Select-Object -First 1).Version
    $script:vbrMajorVersion = 0
    if ($script:vbrVersion) {
        try { $script:vbrMajorVersion = [int]([version]$script:vbrVersion).Major } catch { $script:vbrMajorVersion = 0 }
    }
    $summaryParts = @()
    $headlineServices = @{
        'VeeamBackupSvc'         = 'VBR Server'
        'VeeamEndpointBackupSvc' = 'Veeam Agent'
        'VeeamTransportSvc'      = 'Transport'
        'VeeamGuestInteraction'  = 'Guest Interaction'
        'VeeamDeploySvc'         = 'Installer'
    }
    foreach ($svcName in @('VeeamBackupSvc', 'VeeamEndpointBackupSvc', 'VeeamTransportSvc', 'VeeamGuestInteraction', 'VeeamDeploySvc')) {
        $component = $script:veeamComponents | Where-Object { $_.Service -eq $svcName } | Select-Object -First 1
        if ($component) {
            $versionText = $component.Version
            if (-not $versionText) { $versionText = "version unknown" }
            $summaryParts += ("{0} {1}" -f $headlineServices[$svcName], $versionText)
        }
    }
    $script:veeamSummaryLine = $summaryParts -join "; "
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
    elseif (($computerSystem.Manufacturer -match "QEMU") -or ($computerSystem.Model -match "KVM|Standard PC \(")) {
        #KVM-based platforms (Proxmox VE -- supported since VBR v13 -- plain KVM, some AHV configurations)
        #present as QEMU hardware. The QEMU guest agent fills the guest-tools role on these platforms.
        $hvReport.Add("Detected hypervisor: KVM-based (e.g. Proxmox VE, RHV/oVirt, plain KVM)")
        $script:hypervisor = "KVM-based (e.g. Proxmox VE, RHV/oVirt, plain KVM)"
        $qemuGA = Get-ItemProperty -Path $uninstallKeys -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -match "QEMU guest agent" }
        if ($qemuGA) {
            $hvReport.Add("QEMU guest agent version: " + $qemuGA.DisplayVersion)
            $script:guestToolsInfo = "QEMU guest agent " + $qemuGA.DisplayVersion
        }
        else {
            $hvReport.Add("QEMU guest agent does not appear to be installed.")
            $script:guestToolsInfo = "QEMU guest agent not detected"
        }
        $qemuGAService = Get-Service -Name "QEMU-GA" -ErrorAction SilentlyContinue
        if ($qemuGAService) {
            $hvReport.Add("QEMU guest agent service status: " + $qemuGAService.Status)
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
    Assert-NativeSuccess "fltmc"
}

#Export VBR reg key values (32-bit and 64-bit values)
Invoke-Step "Exporting Veeam registry values..." {
    $regKeys = @()
    $invalidKeys = @()
    #Must test to see if registry hives exist, otherwise would cause a stack overflow error.
    if (Test-Path 'HKLM:\SOFTWARE\Veeam') {
        reg export 'HKLM\SOFTWARE\Veeam' "$directory\64-Bit_Veeam_Registry_Keys.log" > $null
        Assert-NativeSuccess "reg export HKLM\SOFTWARE\Veeam"
        $regKeys += Get-ChildItem "HKLM:\Software\Veeam" -Recurse
    }
    if (Test-Path 'HKLM:\SOFTWARE\WOW6432Node\Veeam') {
        reg export 'HKLM\SOFTWARE\WOW6432Node\Veeam' "$directory\32-Bit_Veeam_Registry_Keys.log" > $null
        Assert-NativeSuccess "reg export HKLM\SOFTWARE\WOW6432Node\Veeam"
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

    #v13+ removed the 64-bit 'Veeam Backup and Replication' key and moved most advanced options into the
    #configuration database. Leave a note so a reviewing engineer does not mistake the thin export for a
    #collection failure or assume no custom options exist just because the registry is nearly empty.
    if ($script:vbrMajorVersion -ge 13) {
        Write-Output ("NOTE: This machine runs Veeam Backup & Replication v$($script:vbrMajorVersion) ($($script:vbrVersion)). " +
            "Starting with v13, most advanced options are stored in the configuration database rather than the registry, " +
            "and the 'HKLM\SOFTWARE\Veeam\Veeam Backup and Replication' key is empty or absent. The registry exports " +
            "in this bundle therefore contain little beyond component-level keys; a thin export is expected and does " +
            "NOT mean the collection failed or that no custom options are set. Option activity is logged by the " +
            "services themselves under Backup\RegistryOptions in the collected logs.") | Out-File "$directory\v13_registry_note.log" -Encoding utf8
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
    #Named SQL instance services are 'MSSQL$<instance>'. Matching on 'MSSQL*' alone would also pick up
    #auxiliary services (MSSQLFDLauncher$X, MSSQLLaunchpad$X, MSSQLServerADHelper...) and misread them as instances.
    $hasSQLDefaultInstance = Get-Service -Name "MSSQLSERVER" -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq "Running" }
    $hasSQL = Get-Service -Name 'MSSQL$*' -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq "Running" }
    #Load SQL Server Management Objects (SMO). The GAC path is only tried on Windows PowerShell: on
    #PowerShell 7 the .NET Framework SMO assemblies can APPEAR to load but then fail at first use with
    #type-load errors, so there the SqlServer module (which ships Core-compatible SMO) is the only option.
    #$PSEdition is absent below PS 5.1, which is always the Desktop edition.
    if ((-not $PSVersionTable.PSEdition) -or ($PSVersionTable.PSEdition -eq 'Desktop')) {
        try {
            [Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo") > $null
        }
        catch {
            Write-Verbose "SMO could not be loaded from the GAC: $($_.Exception.Message)"
        }
    }
    else {
        try {
            Import-Module SqlServer -ErrorAction Stop
        }
        catch {
            Write-Verbose "The SqlServer module is not available: $($_.Exception.Message)"
        }
    }
    #Functional probe: constructing an offline Server object (no connection is made) exercises the type
    #loader end-to-end, catching assemblies that resolve but cannot actually run on this engine.
    $hasSMO = $false
    try {
        New-Object Microsoft.SqlServer.Management.Smo.Server > $null
        $hasSMO = $true
    }
    catch {
        $hasSMO = $false
    }
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
            $script:sqlReport.Add("Running SQL instance(s) were detected, but a working SQL Server Management Objects (SMO) assembly is not available in this PowerShell session. Unable to enumerate database permissions.")
            if ($PSVersionTable.PSEdition -eq 'Core') {
                $script:sqlReport.Add("This script is running under PowerShell $($PSVersionTable.PSVersion), where SMO requires the 'SqlServer' PowerShell module. Either install it (Install-Module SqlServer) or re-run this script under Windows PowerShell 5.1 to include SQL permission data.")
            }
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
    #The LocalAccount filter is REQUIRED: without it, Win32_UserAccount on a domain-joined machine
    #enumerates domain accounts too -- slow on large domains, needless load on domain controllers,
    #the entire domain user list would land in the support bundle, and the SAM/LDAP enumeration
    #pattern is a known trigger for EDR "account discovery" detections.
    Get-CimInstance Win32_UserAccount -Filter 'LocalAccount = TRUE' | Select-Object AccountType, Caption, LocalAccount, SID, Domain | Export-Csv -Path "$directory\local_accounts.csv" -NoTypeInformation -Encoding UTF8
}

#Get Windows Firewall profile (Get-NetFirewallProfile requires Server 2012/Windows 8 or later; fall back to netsh)
Invoke-Step "Getting status of Windows Firewall profiles..." {
    if (Get-Command Get-NetFirewallProfile -ErrorAction SilentlyContinue) {
        Get-NetFirewallProfile | Format-List | Out-File "$directory\firewall_profiles.log" -Encoding utf8
    }
    else {
        netsh advfirewall show allprofiles > "$directory\firewall_profiles.log"
        Assert-NativeSuccess "netsh advfirewall show allprofiles"
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
        Assert-NativeSuccess "reg export SCHANNEL"
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
    Assert-NativeSuccess "ipconfig /all"
}

#Collect the hosts file (and lmhosts if present). Stale hosts-file overrides are a recurring root cause
#in "DNS is fine" cases; the raw file is collected and any active entries are surfaced in the summary.
Invoke-Step "Collecting hosts file..." {
    $hostsPath = Join-Path $env:SystemRoot "System32\drivers\etc\hosts"
    if (Test-Path -LiteralPath $hostsPath) {
        Copy-Item -LiteralPath $hostsPath -Destination "$directory\hosts.txt" -Force
    }
    #lmhosts overrides NetBIOS name resolution the same way. The in-box lmhosts.sam sample is ignored.
    $lmhostsPath = Join-Path $env:SystemRoot "System32\drivers\etc\lmhosts"
    if (Test-Path -LiteralPath $lmhostsPath) {
        Copy-Item -LiteralPath $lmhostsPath -Destination "$directory\lmhosts.txt" -Force
    }
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
    Assert-NativeSuccess "netstat -ano"
    ($disclaimer + $netstatOutput) | Out-File "$directory\netstat.log" -Encoding utf8
}

#Check if 'LocalAccountTokenFilterPolicy' registry value is enabled
Invoke-Step "Checking if 'Remote UAC' is disabled..." {
    #Must test to see if registry hive exists, otherwise would cause a stack overflow error.
    if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System') {
        reg export "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" "$directory\System_Policies.log" > $null
        Assert-NativeSuccess "reg export HKLM policies System"
        $content = Get-Content "$directory\System_Policies.log"
        Write-Output "If 'LocalAccountTokenFilterPolicy' = 1 then 'RemoteUAC' has been disabled. If it does not exist or is set to '0' then it is still enabled.`r`n" | Out-File "$directory\System_Policies.log" -Encoding utf8
        $content | Out-File "$directory\System_Policies.log" -Append -Encoding utf8
    }
}

#Determine whether to include the Security event log. Driven by the -IncludeSecurityEvents parameter
#(passing it explicitly -- either -IncludeSecurityEvents or -IncludeSecurityEvents:$false -- always
#suppresses the prompt, so unattended interactive runs can be fully scripted). In an interactive session
#without the parameter, the user is prompted. Non-interactive sessions default to excluded.
if ($PSBoundParameters.ContainsKey('IncludeSecurityEvents')) {
    $includeSecurity = [bool]$IncludeSecurityEvents
}
elseif ($isInteractive) {
    #Prompt the user. Defaults to 'No' if the dialog is closed, 'No' is selected, the dialog cannot be
    #shown, or Enter is pressed without reading (-defaultNo makes 'No' the focused button).
    $promptResult = Show-YesNoPrompt -defaultNo $true -title "Include Security events?" -message `
        "Do you want to include Security events? (Likely no, unless specifically requested by your Veeam support engineer.)"
    $includeSecurity = ($promptResult -eq $true)
}
else {
    $includeSecurity = $false
}

#Export event viewer logs in EVTX format (full logs) and CSV format (past 14 days)
Write-Console "This step can possibly take several minutes. Please do not cancel or exit the console." "Yellow"
Invoke-Step "Exporting Windows Event Viewer logs..." {
    $evLogNames = (Get-WinEvent -ListLog * -ErrorAction SilentlyContinue | Where-Object { ($_.LogName -ne 'Security') -or $includeSecurity })
    #Per-log failures are tallied instead of thrown so one bad log cannot abort the remaining exports;
    #a single summary error is raised at the end, after the successfully exported logs are zipped.
    $wevtutilFailures = New-Object System.Collections.Generic.List[string]
    foreach ($evLog in $evLogNames) {
        $name = $evLog.LogName
        $validName = $name -replace '/', '_'
        wevtutil epl $name "$tempEVTXEvents\$validName.evtx"
        if ($LASTEXITCODE -ne 0) {
            $wevtutilFailures.Add("$name (export, code $LASTEXITCODE)")
        }
    }

    #Generate LocaleMetadata for each event log.
    Get-ChildItem -File -Path $tempEVTXEvents | ForEach-Object {
        wevtutil al $_.FullName
        if ($LASTEXITCODE -ne 0) {
            $wevtutilFailures.Add("$($_.Name) (locale metadata, code $LASTEXITCODE)")
        }
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
    #Remove the staging folder only after both zips exist. If this step failed above, the staging
    #folder deliberately remains and ships (uncompressed) inside the final archive rather than losing
    #whatever was exported before the failure.
    Remove-Item -LiteralPath $eventStaging -Recurse -Force

    #Raised last: every successfully exported log is already zipped and shipping regardless.
    if ($wevtutilFailures.Count -gt 0) {
        $shownLogs = @($wevtutilFailures | Select-Object -First 5)
        $moreLogs = ""
        if ($wevtutilFailures.Count -gt 5) {
            $moreLogs = " (and $($wevtutilFailures.Count - 5) more)"
        }
        throw "wevtutil reported failures for $($wevtutilFailures.Count) of $($evLogNames.Count) event logs: $($shownLogs -join ', ')$moreLogs. All other logs were exported and are included."
    }
}

#Check if this is a Server Edition of Windows because Workstation Edition servers would throw an error.
if ((Get-CimInstance -ClassName Win32_OperatingSystem).ProductType -ne 1) {
    #Get status of all Windows Features. Get-CommandName check: the ServerManager module is a Windows
    #PowerShell module; under PowerShell 7 it is only reachable if the Windows compatibility layer can
    #proxy it, so fall back to DISM (in-box everywhere) rather than failing the step.
    Invoke-Step "Retrieving list of installed features..." {
        if (Get-Command Get-WindowsFeature -ErrorAction SilentlyContinue) {
            Get-WindowsFeature | Format-Table -AutoSize | Out-File "$directory\installed_features.log" -Encoding utf8
        }
        else {
            dism /online /get-features /format:table > "$directory\installed_features.log"
            Assert-NativeSuccess "dism /online /get-features"
        }
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

#Compress folder containing data. The archive is first built inside the admin-only working directory,
#and the destination file is pre-created with a restricted ACL before any content is copied into it
#(overwriting an existing file preserves its security descriptor). The sensitive bundle is therefore
#never readable by non-administrators at any point, even mid-compression or mid-copy.
Invoke-Step "Compressing and zipping collected logs..." {
    $tempZip = Join-Path $temp ($date + $hostname + ".zip")
    Compress-Directory -sourcePath $directory -zipPath $tempZip -includeBaseDirectory $true
    New-Item -ItemType File -Path "$directory.zip" -Force > $null
    Protect-Path -path "$directory.zip"
    Copy-Item -LiteralPath $tempZip -Destination "$directory.zip" -Force
    Remove-Item -LiteralPath $tempZip -Force
}

#Remove temporary log folder, but only if the archive was fully written and opens as a valid zip. A
#partial archive (e.g. the volume filled up mid-compression or mid-copy) must never cause the collected
#data to be deleted, or the customer would have to re-run the entire collection.
#(-LiteralPath is used on paths that can be user-influenced via -OutputDirectory so that wildcard
#characters such as '[' are never glob-expanded by file cmdlets.)
$zipIsValid = (Test-Path -LiteralPath "$directory.zip") -and (Test-ZipArchive -zipPath "$directory.zip")
if ($zipIsValid) {
    Write-Console "Removing temporary log folder..." "White"
    Remove-Item -LiteralPath "$directory" -Recurse -Force -Confirm:$false
    if (Test-Path -LiteralPath $directory) {
        Write-Console "Problem encountered cleaning up temporary log folder. Manual cleanup may be necessary. Location: $directory" "Yellow" 3
    }
}
else {
    Write-Console "The zip archive was not created successfully. Leaving uncompressed log folder in place: $directory" "Yellow" 3
}

#Test if %ProgramData%\Veeam\Backup\ exists (will be present on any Veeam component or server that is being backed up by a job with AAiP)
if (!(Test-Path -Path $veeamDir)) {
    Write-Console "Not all logs could be collected. Please verify you are executing this script on the correct server (ie. guest OS where troubleshooting is necessary)." "Yellow" 3
    Write-Console "Please find any collected logs at $logDir" "Green" 2
}
else {
    Write-Console "Log collection finished. Please find the collected logs at $logDir" "Green" 3
}

Write-Console "NOTE: The collected archive contains sensitive configuration data (accounts, permissions, event logs). `
Archives are not removed automatically -- please delete previous collections under $logDir once your support case is closed." "Yellow"

#Remove custom Out-File width setting just in case.
$PSDefaultParameterValues.Remove('Out-File:Width')

#Stop transcript and copy Execution.log into the .zip archive.
try { Stop-Transcript > $null } catch { Write-Verbose "No active transcript to stop." }
Start-Sleep -Seconds 1
if (Test-Path -LiteralPath "$temp\Execution.log") {
    if ($zipIsValid) {
        Add-FileToZip -FileToAdd "$temp\Execution.log" -ZipName ($directory + ".zip")
    }
    else {
        #Zip was not created -- preserve the transcript alongside the uncompressed log folder instead.
        Move-Item -LiteralPath "$temp\Execution.log" -Destination $directory -Force
    }
}

#Remove the per-run working directory.
Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue

#Open Windows Explorer to the location of the created .zip file (interactive sessions only)
if ($isInteractive) {
    Explorer $logDir
    Start-Sleep 2
}

#Exit non-zero if the archive is missing or any collection step failed, so unattended callers
#(e.g. Invoke-Command) can detect problems programmatically.
$exitCode = 0
if (($script:stepErrors.Count -gt 0) -or (-not $zipIsValid)) {
    $exitCode = 1
}
Exit $exitCode