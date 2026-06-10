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
   .Example
    Execute on guest OS server locally (run with Administrator privileges):
        .\Collect_Veeam_Guest_Logs.ps1
    Execute from remote server (run with Administrator privileges):
        Invoke-Command -FilePath <PATH_TO_THIS_SCRIPT> -ComputerName <GUEST_OS_SERVERNAME> -Credential (Get-Credential)
   .Notes
    NAME: Collect_Veeam_Guest_Logs.ps1
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
    [switch] $Force
)

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
$logVolume = Split-Path -Path $veeamDir -Parent
$logDir = Join-Path -Path $logVolume -ChildPath "Case_Logs"
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
    $writersProcs = Start-Process -FilePath PowerShell.exe -ArgumentList "-Command `"vssadmin list writers > '$temp\vss_writers.log'`"" -PassThru -NoNewWindow
    try {
        $writersProcs | Wait-Process -Timeout $writersTimeout -ErrorAction Stop
    }
    catch {
        Write-Console "Collecting VSS Writers data has taken longer than expected. Skipping VSS Writers collection." "Yellow"
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
        Select-Object DisplayName, DisplayVersion, Publisher, InstallDate, @{Name = "ProductCode"; Expression = { $_.PSChildName } } |
        Sort-Object DisplayName |
        Format-Table -AutoSize | Out-File "$directory\installed_software.log" -Encoding utf8
}

#Check if this server is running any SQL instances and if so, enumerate permissions for each database
Invoke-Step "Checking for running SQL instances..." {
    $script:sqlReport = New-Object System.Collections.Generic.List[string]
    $hasSQLDefaultInstance = Get-Service -Name "MSSQL*" | Where-Object { $_.Status -eq "Running" -and $_.Name -eq "MSSQLSERVER" }
    $hasSQL = Get-Service -Name "MSSQL*" | Where-Object { $_.Status -eq "Running" -and ($_.Name -ne "MSSQLFDLauncher" -and $_.Name -ne "MSSQLSERVER") }
    $hasSMO = [Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo")
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
    if (Get-Command Get-Volume -ErrorAction SilentlyContinue) {
        Get-Volume | Select-Object DriveLetter, FriendlyName, FileSystemType, DriveType, HealthStatus, OperationalStatus, SizeRemaining, Size, @{n = "% Free"; e = { ($_.SizeRemaining / $_.Size).ToString("P") } } | Sort-Object DriveLetter | Format-Table -AutoSize | Out-File "$directory\volume_info.log" -Encoding utf8
    }
    else {
        Get-CimInstance Win32_Volume | Select-Object DriveLetter, Label, FileSystem, DriveType, @{n = "Size(GB)"; e = { [math]::Round($_.Capacity / 1GB, 2) } }, @{n = "FreeSpace(GB)"; e = { [math]::Round($_.FreeSpace / 1GB, 2) } }, @{n = "% Free"; e = { if ($_.Capacity) { ($_.FreeSpace / $_.Capacity).ToString("P") } } } | Sort-Object DriveLetter | Format-Table -AutoSize | Out-File "$directory\volume_info.log" -Encoding utf8
    }
}

#Get local accounts
Invoke-Step "Getting list of local accounts..." {
    Get-CimInstance Win32_UserAccount | Select-Object AccountType, Caption, LocalAccount, SID, Domain | Format-Table -AutoSize | Out-File "$directory\local_accounts.log" -Encoding utf8
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
    Get-CimInstance Win32_Service | Select-Object DisplayName, @{Name = "Status"; Expression = { $_.State } }, @{Name = "Log On As"; Expression = { $_.StartName } } | Sort-Object DisplayName | Format-Table -AutoSize | Out-File "$directory\services.log" -Encoding utf8
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
        Get-NetAdapterBinding | Where-Object { $_.DisplayName -match "File and Printer Sharing" } | Format-Table -AutoSize | Out-File "$directory\file_and_printer_sharing.log" -Encoding utf8
    }
    else {
        Write-Output "Get-NetAdapterBinding is not available on this OS version (requires Windows 8/Server 2012 or later). Unable to collect 'File and Printer Sharing' binding state." | Out-File "$directory\file_and_printer_sharing.log" -Encoding utf8
    }
}

#Get settings of attached NICs
Invoke-Step "Getting settings of attached NICs..." {
    ipconfig /all > "$directory\ipconfig.log"
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
