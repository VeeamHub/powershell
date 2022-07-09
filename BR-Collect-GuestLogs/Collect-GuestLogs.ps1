<# 
   .Synopsis 
    Automated collection of Windows guest OS logs for troubleshooting of Veeam Backup jobs with 
    Application Aware Processing enabled (SQL/Exchange/Active Directory/SharePoint/Oracle).
   .Example 
	Execute on guest OS server locally (run with Administrator privileges): 
        .\Collect_Veeam_Guest_Logs.ps1
    Execute from remote server (run with Administrator privileges): 
        Invoke-Command -FilePath <PATH_TO_THIS_SCRIPT> -ComputerName <GUEST_OS_SERVERNAME> -Credentials (Get-Credential)
   .Notes 
    NAME: Collect_Veeam_Guest_Logs.ps1
    AUTHOR: Chris Evans, Veeam Software
    CONTACT: chris.evans@veeam.com
    LASTEDIT: 07-09-2022
    KEYWORDS: Log collection, AAiP, Guest Processing
#> 
#Requires -Version 4.0
#Requires -RunAsAdministrator
$ErrorActionPreference = "SilentlyContinue"

#Check if script running in PowerShell ISE. If so, instruct to call the script again from a normal PowerShell console. This is due to PS ISE loading additional modules that can cause issues with transcription.
if ($psISE) {
    Write-Console "PowerShell ISE is not supported for this script. Please call the script from a PowerShell console (launched with Administrator privileges)." "Red" 5
    Exit
}

function Write-Console (
    [string] $message = "Done.",
    [string] $fgcolor = "Green",
    [int] $seconds = 1
)
{
    Write-Host $message -ForegroundColor $fgcolor
    ""
    Start-Sleep $seconds
}
    
function New-Dir (
    [string[]] $path) {
    New-Item -ItemType Directory -Force -Path $path > $null
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
                #Get permissions for each user
                $DBRoles = $User.EnumRoles()
                foreach ($role in $DBRoles) {
                    ("`t" + $role + " on " + $Database.Name)  | Out-File "$directory\SQL_Permissions.log" -Append
                } 
                #Get any explicitily granted permissions
                foreach ($Permission in $Database.EnumObjectPermissions($User.Name)) {
                    ("`t" + $Permission.PermissionState + " " + $Permission.PermissionType + " on " + $Permission.ObjectName + " in " + $Database.Name)  | Out-File "$directory\SQL_Permissions.log" -Append
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
         "=================================================================================" | Out-File "$directory\SQL_Permissions.log" -Append
         ("SQL Instance: " + $Server.Name) | Out-File "$directory\SQL_Permissions.log" -Append 
         ("SQL Version: " + $Server.VersionString) | Out-File "$directory\SQL_Permissions.log" -Append
         ("Edition: " + $Server.Edition) | Out-File "$directory\SQL_Permissions.log" -Append 
         ("Login Mode: " + $Server.LoginMode) | Out-File "$directory\SQL_Permissions.log" -Append
         "=================================================================================" | Out-File "$directory\SQL_Permissions.log" -Append
        $SQLLogins = $Server.Logins
        foreach ($SQLLogin in $SQLLogins) {
             ("Login          : " + $SQLLogin.Name) | Out-File "$directory\SQL_Permissions.log" -Append
             ("Login Type     : " + $SQLLogin.LoginType) | Out-File "$directory\SQL_Permissions.log" -Append
             ("Created        : " + $SQLLogin.CreateDate) | Out-File "$directory\SQL_Permissions.log" -Append
             ("Default DB     : " + $SQLLogin.DefaultDatabase) | Out-File "$directory\SQL_Permissions.log" -Append
             ("Disabled       : " + $SQLLogin.IsDisabled) | Out-File "$directory\SQL_Permissions.log" -Append
            $SQLRoles = $SQLLogin.ListMembers()
            if ($SQLRoles) {
                ("Server Role    : " + $SQLRoles) | Out-File "$directory\SQL_Permissions.log" -Append
            } 
            else { 
                 "Server Role    :  Public" | Out-File "$directory\SQL_Permissions.log" -Append
            } 
            #Get individuals in any Windows domain groups
            if ($SQLLogin.LoginType -eq "WindowsGroup") {   
                 "Group Members: " | Out-File "$directory\SQL_Permissions.log" -Append
                try {
                    $ADGRoupMembers = Get-ADGroupMember  $SQLLogin.Name.Split("\")[1] -Recursive
                    foreach($Member in $ADGRoupMembers) {
                         ("   Account: " + $Member.Name + "(" + $Member.SamAccountName + ")") | Out-File "$directory\SQL_Permissions.log" -Append
                    } 
                } catch {
                    #Sometimes there are 'ghost' groups left behind that are no longer in the domain. This highlights those still in SQL.
                    ("Unable to locate group " + $SQLLogin.Name.Split("\")[1] + " in the AD Domain.") | Out-File "$directory\SQL_Permissions.log" -Append
                } 
            } 
            #Check the permissions in the DBs the Login is linked to. (Errors suppressed for all SQL logins that exist but are disabled)
            if ($SQLLogin.EnumDatabaseMappings()) { 
                "Permissions: " | Out-File "$directory\SQL_Permissions.log" -Append
                foreach ($DB in $Server.Databases) {
                    GetDBUserInfo($DB)
                }
            } 
            else {
                 "None." | Out-File "$directory\SQL_Permissions.log" -Append
            }
             "----------------------------------------------------------------------------" | Out-File "$directory\SQL_Permissions.log" -Append
        } 
    } 
}

function Test-FileLock (
    [string] $path
)
{
    if ([string]::IsNullOrEmpty($path)) {
        Throw "The path must be specified."
    }
            
    [bool] $fileExists = Test-Path $path
            
    if (!($fileExists)) {
        Throw "File does not exist: (" + $path + ")"
    }
            
    [bool] $isFileLocked = $true
    
    $file = $null
            
    try {
        $file = [IO.File]::Open(
            $path,
            [IO.FileMode]::Open,
            [IO.FileAccess]::Read,
            [IO.FileShare]::None)
                    
        $isFileLocked = $false
    }
    catch [IO.IOException] {
        if (!($_.Exception.Message.EndsWith("is being used by another process."))) {
            Throw $_.Exception
        }
    }
    finally {
        if ($null -ne $file) {
            $file.Close()
        }
    }
            
    return $isFileLocked
}
        
function GetWaitInterval (
    [int] $waitTime
)
{
    if ($waitTime -lt 1000) {
        return 100
    }
    elseif ($waitTime -lt 5000) {
        return 1000
    }
    else {
        return 5000
    }
}
    
function Wait-Zip (
    [__ComObject] $zipFile
)
{
    if ($null -eq $zipFile) {
        Throw "Value cannot be null: zipFile"
    }
    
    Write-Host -NoNewLine "Waiting for zip operation to finish" -ForegroundColor Green
            
    [int] $waitTime = 0
    [int] $maxWaitTime = 60 * 10000 # [milliseconds]
    while ($waitTime -lt $maxWaitTime) {
        [int] $waitInterval = GetWaitInterval($waitTime)
                        
        Write-Host -NoNewLine "."
        Start-Sleep -Milliseconds $waitInterval
        $waitTime += $waitInterval
    
        Write-Debug ("Wait time: " + $waitTime / 1000 + " seconds")
                
        [bool] $isFileLocked = Test-FileLock($zipFile.Self.Path)
                
        if ($isFileLocked) {
            Write-Debug "Zip file is locked by another process."
            Continue
        }
        else {
            Break
        }
    }
                
    if ($waitTime -gt $maxWaitTime) {
        Throw "Timeout exceeded waiting for zip operation."
    }
                
}
    
function Compress-Folder (
    [IO.DirectoryInfo] $directory
)
{
    if ($null -eq $directory) {
        Throw "Value cannot be null: directory"
    }
            
    Write-Console ("Creating zip file for folder (" + $directory.FullName + ")...") "White" 1
            
    [IO.DirectoryInfo] $parentDir = $directory.Parent
            
    [string] $zipName
            
    if ($parentDir.FullName.EndsWith("\")) {
        $zipName = $parentDir.FullName + $directory.Name + ".zip"
    }
    else {
        $zipName = $parentDir.FullName + "\" + $directory.Name + ".zip"
    }
            
    if (Test-Path $zipName) {
        Throw "Zip file already exists: ($zipName)."
    }
            
    Set-Content $zipName ("PK" + [char]5 + [char]6 + ("$([char]0)" * 18))
                
    $shellApp = New-Object -ComObject Shell.Application
    $zipFile = $shellApp.NameSpace($zipName)
    
    if ($null -eq $zipFile) {
        Throw "Failed to get zip file object."
    }
            
    $zipFile.CopyHere($directory.FullName)
    
    Wait-Zip $zipFile
            
    Write-Console ("Successfully created zip file for folder (" + $directory.FullName + ").") 
}

function Add-FileToZip (
    [string]$ZipName,
    [string]$FileToAdd
)
{

    try {
        [Reflection.Assembly]::LoadWithPartialName('System.IO.Compression.FileSystem') > $null
        $zip = [System.IO.Compression.ZipFile]::Open($ZipName,"Update")
        $addedFile = [System.IO.Path]::GetFileName($FileToAdd)
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip,$FileToAdd,$addedFile,"Optimal") > $null
        $zip.Dispose()
    } 
    catch {
        Write-Output "Failed to add $FileToAdd to $ZipName. Details: $_" > $null
    }

}

#Check to make sure we are not running this on the VBR server
$isVBR = Get-Service -Name "VeeamBackupSv*"
if ($isVBR) {
    Write-Console "This script is meant to be executed on the server which has Guest Processing errors, NOT the Veeam Backup Server." "Red" 3
    Write-Console "Please re-run this script on the GUEST server." "Red" 3
    Exit
}
 
#Initialize variables
if ((Get-Item -Path 'HKLM:\SOFTWARE\Veeam\Veeam Backup and Replication').Property -Contains "LogDirectory") {
    $veeamDir = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Veeam\Veeam Backup and Replication').LogDirectory
}
else {
    $veeamDir = $env:ProgramData + "\Veeam\Backup"    
}

$date = Get-Date -f yyyy-MM-ddTHHmmss_
$temp = "C:\temp"
$hostname = hostname
$logvolume = Split-Path -Path $veeamDir -Parent
$logDir = Join-Path -Path $logVolume -ChildPath "Case_Logs" 
$directory = Join-Path -Path $logDir -ChildPath $date$hostname
$VBR = "$directory\Backup"
$Events = "$directory\Events"
$VSS = "$directory\VSS"
$PSVersion = $PSVersionTable.PSVersion.Major

Write-Console "This script is provided as is as a courtesy for collecting Guest Proccessing logs from a guest server. `
Please be aware that due to certain Microsoft operations there may be a short burst `
of high CPU activity, and that some Windows OSes and GPOs may affect script execution. `
There is no support provided for this script, and should it fail, we ask that you please proceed to collect the required information manually." "Yellow" 5

# Transcript all workflow
Start-Transcript -Path $temp\Execution.log > $null

#Create directories
Write-Console "Creating temporary directories..." "White" 1
New-Dir $directory, $VBR, $Events, $VSS, $temp
Write-Console

#Copy Backup Folder
Write-Console "Copying Veeam guest operation logs..." "White" 1
Get-ChildItem -Path $veeamDir | Copy-Item -Destination $VBR -Recurse -Force
Write-Console

#Export VSS logs
Write-Console "Copying VSS logs..." "White" 1
vssadmin list providers > "$VSS\vss_providers.log"
vssadmin list shadows > "$VSS\vss_shadows.log"
vssadmin list shadowstorage > "$VSS\vss_shadow_storage.log"

#Handle vssadmin timeout taking more than 120 seconds
$writersTimeout = 180;
$writersProcs = Start-Process -FilePath PowerShell.exe -ArgumentList '-Command "vssadmin list writers > C:\temp\vss_writers.log"' -PassThru -NoNewWindow
try {
    $writersProcs | Wait-Process -Timeout $writersTimeout -ErrorAction Stop
}
catch {
    Write-Console "Collecting VSS Writers data has taken longer than expected. Skipping VSS Writers collection." "Yellow" 2
    $writersProcs | Stop-Process -Force
}
if (Test-Path "C:\temp\vss_writers.log") { 
    Move-Item "C:\temp\vss_writers.log" -Destination $VSS 
}
Write-Console

#Export systeminfo
Write-Console "Exporting systeminfo..." "White" 1
systeminfo > "$directory\systeminfo.log"
Write-Console

#Export VBR reg key values and check each value name for leading or trailing whitespace
Write-Console "Exporting Veeam registry values..." "White" 1
$VBRKeys = Get-ItemProperty "HKLM:\SOFTWARE\Veeam\Veeam Backup and Replication\" 
if ($VBRKeys) {
    $VBRKeys > "$directory\registry_values.log"
    
    #Check all the reg key names to detect any names with leading or trailing whitespace
    $invalidkeys = $VBRkeys.PSObject.Properties.Name | Where-Object { $_.EndsWith(" ") -or $_.StartsWith(" ") } | ForEach-Object { "'{0}'" -f $_ }
    #Log invalid keys if any were found
    if ($invalidkeys) {
        Write-Output "The following registry value names were found to have leading or trailing whitespace:`n $invalidkeys" >> "$directory\invalid_registry_keys.log"
    }
} 
else {
    Write-Output "Veeam Backup and Replication registry hive contains zero registry key values (default setting)." > "$directory\registry_values.log"
    Write-Output "No invalid registry keys detected." > "$directory\invalid_registry_keys.log"
}
Write-Console

#Get list of installed software
Write-Console "Getting list of installed software..." "White" 1
Get-WmiObject Win32_Product | Sort-Object Name | Format-Table IdentifyingNumber, Name, LocalPackage -AutoSize > "$directory\installed_software.log"
Write-Console

#Check if this server is running any SQL instances
Write-Host "Are there any running SQL instances here? - " -ForegroundColor White -NoNewline; Start-Sleep 1
$hasSQLDefaultInstance = Get-Service -Name MSSQL* | Where-Object { $_.Status -eq "Running" -and $_.Name -eq "MSSQLSERVER" }
$hasSQL = Get-Service -Name "MSSQL*" | Where-Object { $_.Status -eq "Running" -and ($_.Name -ne "MSSQLFDLauncher" -and $_.Name -ne "MSSQLSERVER") }
$hasSMO = [Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo")
$SQLServerInstance = @()
if (!($hasSQLDefaultInstance) -and !($hasSQL)) {
    Write-Output "No running SQL instances were detected. If you suspect this is in error, please report it to this script's maintainer." >> "$directory\SQL_Permissions.log"
    Write-Console "No. Unable to detect any running SQL instances. Continuing..." "White" 1
}
else {
    if ($hasSQL -and $hasSMO) {
        Write-Console "Yes. Enumerating permissions for each database." "White" 1
        foreach ($instance in $hasSQL) {
                $SQLServerInstance = ($instance.Name -replace '^.*\$',($hostname + "\"))
        }
        LogSQLPermissions($SQLServerInstance)
    }
    if ($hasSQLDefaultInstance -and $hasSMO) {
        LogSQLPermissions($hostname)
    }
}
Write-Console

#Get volume information
Write-Console "Getting volume information..." "White" 1
Get-Volume | Select-Object DriveLetter, FriendlyName, FileSystemType, DriveType, HealthStatus, OperationalStatus, SizeRemaining, Size, @{n = "% Free"; e = { ($_.SizeRemaining / $_.size).toString("P") } } | Sort-Object DriveLetter | Format-Table -AutoSize > "$directory\volume_info.log"
Write-Console

#Get local accounts
Write-Console "Getting list of accounts with Local Administrator privileges..." "White" 1
Get-WmiObject Win32_UserAccount | Select-Object AccountType, Caption, LocalAccount, SID, Domain | Format-Table -AutoSize > "$directory\local_accounts.log"
Write-Console

#Get Windows Firewall profile
Write-Console "Getting status of Windows Firewall profiles..." "White" 1
Get-NetFirewallProfile | Format-List > "$directory\firewall_profiles.log"
Write-Console

#Get status of Services
Write-Console "Getting status of Windows Services..." "White" 1
Get-Service | Select-Object DisplayName, Status | Sort-Object DisplayName | Format-Table -AutoSize > "$directory\services.log"
Write-Console

#Get network security settings (This is where customizations such as disabling TLS 1.0/1.1 or key exchange algorithms are done)
Write-Console "Checking for network customizations (ie. Is TLS 1.0/1.1 disabled? Custom key exchange algorithms?)..." "White" 1
Write-Output "Reference: https://docs.microsoft.com/en-us/windows-server/security/tls/tls-registry-settings" > "$directory\network_customizations.log"
Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL" -Recurse >> "$directory\network_customizations.log"
Write-Console

#Get status of 'File and Printer Sharing'
Write-Console "Checking if 'File and Printer Sharing' is enabled..." "White" 1
Get-NetAdapterBinding | Where-Object { $_.DisplayName -match "File and Printer Sharing" } > "$directory\file_and_printer_sharing.log"
Write-Console

#Get settings of attached NICs
Write-Console "Getting settings of attached NICs..." "White" 1
ipconfig /all > "$directory\ipconfig.log"
Write-Console

#Check if 'LocalAccountTokenFilterPolicy' registry value is enabled
Write-Console "Checking if 'Remote UAC' is disabled..." "White" 1
Write-Output "If 'LocalAccountTokenFilterPolicy' = 1 then 'RemoteUAC' has been disabled. If it does not exist or is set to '0' then it is still enabled." > "$directory\System_Policies.log"
(Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System").PSObject.Properties | Select-Object Name, Value >> "$directory\System_Policies.log"
Write-Console

#Export event viewer logs
Write-Console "Exporting relevant Windows Event Viewer logs..." "White" 1
wevtutil epl Application "$Events\Application_$hostname.evtx" 
wevtutil al "$Events\Application_$hostname.evtx" 
wevtutil epl System "$Events\System_$hostname.evtx"
wevtutil al "$Events\System_$hostname.evtx"
#Check if this is a Server Edition of Windows.
if ((Get-CimInstance -ClassName Win32_OperatingSystem).ProductType -ne 1) {
    #Check if Hyper-V role enabled. If so, collect VMMS event logs.
    if ((Get-WindowsFeature -Name Hyper-V).Installed) {
        wevtutil epl Microsoft-Windows-Hyper-V-VMMS-Admin "$Events\VMMS_$hostname.evtx"
        wevtutil al "$Events\VMMS_$hostname.evtx"
        Write-Console
    }
    else {
        Write-Console
    }

    #Get status of all Windows Features. This block included here because Workstation Edition servers would throw an error.
    Write-Console "Retrieving list of installed features..." "White" 1
    Get-WindowsFeature | Format-Table -AutoSize > "$directory\installed_features.log"
}
Write-Console

#Compress folder containing data
Write-Console "Compressing and zipping collected logs..." "White" 1
#Get large files count
$largefiles = (Get-ChildItem -Path $directory -Recurse | Where-Object { ($_.Length / 1GB) -gt 2 }).Count
#Handle proper method of creating zip file based on PowerShell version + number of files larger than 1GB
if (($PSVersion -gt '4') -and ($largefiles -lt '1')) {
    Compress-Archive "$directory" "$directory.zip" -Force
}
else {
    Compress-Folder $directory
}
Write-Console

#Remove temporary log folder
Write-Console "Removing temporary log folder..." "White" 1
Remove-Item "$directory" -Recurse -Force -Confirm:$false
Start-Sleep 5
if (!(Test-Path -Path $directory)) {
    Write-Console
}
else {
    Write-Console "Problem encountered cleaning up temporary log folder. Manual cleanup may be necessary. Location: $directory" "Yellow" 3
}

#Test if %ProgramData%\Veeam\Backup\ exists (will be present on any Veeam component or server that is being backed up by a job with AAiP)
if (!(Test-Path -Path $veeamDir)) {
    Write-Console "Not all logs could be collected. Please verify you are executing this script on the correct server (ie. guest OS where troubleshooting is necessary)." "Yellow" 3
    Write-Console "Please find any collected logs at $logDir" "Green" 2
} 
else { 
    Write-Console "Log collection finished. Please find the collected logs at $logDir" "Green" 3
}

#Stop transcript, copy Execution.log into the .zip archive, then cleanup Execution.log from C:\temp directory.
Stop-Transcript > $null
Add-FileToZip -FileToAdd "C:\temp\Execution.log" -ZipName ($directory + ".zip")
Remove-Item "$temp\Execution.Log" -Force

#Open Windows Explorer to the location of the created .zip file
Explorer $logDir
Start-Sleep 2
Exit
