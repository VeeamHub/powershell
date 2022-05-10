<# 
    .SYNOPSIS 
    Automated collection of Windows guest OS logs for troubleshooting of Veeam Backup jobs with 
    Application Aware Processing enabled (SQL/Exchange/Active Directory/SharePoint/Oracle).
    .EXAMPLE 
	Execute on guest OS server locally (run with Administrator privileges): 
        .\Collect-GuestLogs.ps1
    .EXAMPLE
    Execute from remote server (run with Administrator privileges): 
        Invoke-Command -FilePath <PATH_TO_THIS_SCRIPT> -ComputerName <GUEST_OS_SERVERNAME> -Credentials (Get-Credential)
    .NOTES 
    NAME: Collect-GuestLogs.ps1
    AUTHOR: Chris Evans, Veeam Software
    LASTEDIT: 05-09-2022
    KEYWORDS: Log collection, AAiP, Guest Processing
#> 

function Write-Console (
    [string] $message = "Done.",
    [string] $fgcolor = "Green",
    [int] $seconds = 1) {
    ""
    Write-Host $message -ForegroundColor $fgcolor
    Start-Sleep $seconds
}
    
function New-Dir (
    [string[]] $path) {
    New-Item -ItemType Directory -Force -Path $path -ErrorAction SilentlyContinue > $null
}
    
function Measure-ZipFiles (
    [__ComObject] $zipFile) {
    if ($null -eq $zipFile) {
        Throw "Value cannot be null: zipFile"
    }
            
    Write-Console ("Counting items in zip file (" + $zipFile.Self.Path + ")...")
            
    [int] $count = Measure-ZipFilesRecursive($zipFile)
            
    Write-Console ($count.ToString() + " items in zip file (" + $zipFile.Self.Path + ").")
            
    return $count
}
    
function Measure-ZipFilesRecursive (
    [__ComObject] $parent) {
    if ($null -eq $parent) {
        Throw "Value cannot be null: parent"
    }
            
    [int] $count = 0
    
    $parent.Items() |
    ForEach-Object {
        $count += 1
                    
        if ($_.IsFolder) {
            $count += Measure-ZipFilesRecursive($_.GetFolder)
        }
    }
    
    return $count
}
    
function Test-FileLock (
    [string] $path) {
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
    [int] $waitTime) {
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
    [__ComObject] $zipFile,
    [int] $sumZipItems) {
    if ($null -eq $zipFile) {
        Throw "Value cannot be null: zipFile"
    }
    elseif ($sumZipItems -lt 1) {
        Throw "The expected number of items in the zip file must be specified."
    }
    
    Write-Host -NoNewLine "Waiting for zip operation to finish..." -ForegroundColor White -BackgroundColor Black
    #ensure zip operation had time to start
            
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
            
    [int] $count = Measure-ZipFiles($zipFile)
            
    if ($count -eq $sumZipItems) {
        Write-Console "The zip operation completed succesfully."
    }
    elseif ($count -eq 0) {
        Throw ("Something went wrong. Zip file is empty.")
    }
    elseif ($count -gt $expectedCount) {
        Throw "Zip file contains more than the expected number of items."
    }
}
    
function Compress-Folder(
    [IO.DirectoryInfo] $directory) {
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
            
    [int] $expectedCount = (Get-ChildItem $directory -Force -Recurse).Count
    $expectedCount += 1 #Account for the top-level folder
            
    $zipFile.CopyHere($directory.FullName)
    
    Wait-Zip $zipFile $expectedCount
            
    Write-Console ("Successfully created zip file for folder (" + $directory.FullName + ").") 
}

 #Verify running PowerShell as Administrator
 Write-Console "Checking elevation rights..." "White" 1
 if (!(New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
     Write-Console "PowerShell does not have elevated rights. Please open a PowerShell window as Administrator and run the script again." "Red" 3
     Exit
 }
 else { 
     Write-Console "PowerShell is running with Administrator privileges. Starting data collection..."
 }
 
#Initialize variables
if ((Get-Item -Path 'HKLM:\SOFTWARE\Veeam\Veeam Backup and Replication').Property -contains "LogDirectory") {
    $veeamDir = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Veeam\Veeam Backup and Replication').LogDirectory
}
else {
    $veeamDir = $env:ProgramData + "\Veeam\Backup"    
}

$date = Get-Date -f yyyy-MM-ddTHHmmss_
$temp = "C:\temp"
$hostname = hostname
$logvolume = Split-Path -Path $veeamDir -Parent
$logDir = "$logvolume\Case_Logs"
$directory = "$logDir\$date$hostname"
$VBR = "$directory\Backup"
$Events = "$directory\Events"
$VSS = "$directory\VSS"
$PSVersion = $PSVersionTable.PSVersion.Major

#Create directories & execution log
Write-Console "Creating temporary directories..." "White" 1
New-Dir $directory, $VBR, $Events, $VSS, $temp
Write-Console
    
# Transcript all workflow
Start-Transcript -Path $directory\Execution.log > $null

Write-Console "This script is provided as is as a courtesy for collecting Guest Proccessing logs from a guest server. `
Please be aware that due to certain Microsoft operations there may be a short burst `
of high CPU activity, and that some Windows OSes and GPOs may affect script execution. `
There is no support provided for this script, and should it fail, we ask that you please proceed to collect the required information manually." "Yellow" 5

#Copy Backup Folder
Write-Console "Copying Veeam guest operation logs..." "White" 1
Get-ChildItem -Path $veeamDir | Copy-Item -Destination $VBR -Recurse -Force -ErrorAction SilentlyContinue 
Write-Console

#Export VSS logs
Write-Console "Copying VSS logs..." "White" 1
vssadmin list providers > "$VSS\vss_providers.log"
vssadmin list shadows > "$VSS\vss_shadows.log"
vssadmin list shadowstorage > "$VSS\vss_shadow_storage.log"

#Handle vssadmin timeout taking more than 120 seconds
$writersTimeout = 120;
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

#Export VBR reg key values
Write-Console "Exporting Veeam registry values..." "White" 1
Get-ItemProperty "HKLM:\SOFTWARE\Veeam\Veeam Backup and Replication" > "$directory\registry_values.log"
Write-Console

#Check all the reg key names to detect any names with leading or trailing whitespace
Write-Console "Checking for any invalid registry values..." "White" 1
$invalidkeys = (Get-ItemProperty "HKLM:\SOFTWARE\Veeam\Veeam Backup and Replication\").PSObject.Properties.Name | Where-Object { $_.EndsWith(" ") -or $_.StartsWith(" ") } | ForEach-Object { "'{0}'" -f $_ }
#If any invalid keys were detected, log them to file
if ($invalidkeys) {
    Write-Output "The following registry value names were found to have leading or trailing whitespace:" > "$directory\invalid_registry_keys.log"
    $invalidkeys >> "$directory\invalid_registry_keys.log"
}
else {
    Write-Output "No invalid registry keys detected." > "$directory\invalid_registry_keys.log"
}
Write-Console

#Get list of installed software
Write-Console "Getting list of installed software..." "White" 1
Get-WmiObject Win32_Product | Sort-Object Name | Format-Table IdentifyingNumber, Name, LocalPackage -AutoSize > "$directory\installed_software.log"
Write-Console

#Get volume information
Write-Console "Getting volume information..." "White" 1
Get-Volume | Select-Object DriveLetter, FriendlyName, FileSystemType, DriveType, HealthStatus, OperationalStatus, SizeRemaining, Size, @{n = "% Free"; e = { ($_.SizeRemaining / $_.size).toString("P") } } | Sort-Object DriveLetter | Format-Table -AutoSize > "$directory\volume_info.log"
Write-Console

#Get local accounts
Write-Console "Getting list of accounts with Local Administrator privileges..." "White" 1
if ($PSVersion -lt 5) {
    WMIC UserAccount get AccountType,Caption,LocalAccount,SID,Domain > "$directory\local_accounts.log"
} 
else {
    Get-LocalGroupMember Administrators > "$directory\local_accounts.log"
}
Write-Console

#Get Windows Firewall profile
Write-Console "Getting status of Windows Firewall profiles..." "White" 1
Get-NetFirewallProfile | Format-List > "$directory\firewall_profiles.log"
Write-Console

#Get status of Services
Write-Console "Getting status of Windows Services..." "White" 1
Get-Service | Select-Object DisplayName, Status | Format-Table -AutoSize > "$directory\services.log"
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
(Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System").PSObject.Properties | Select-Object Name, Value -SkipLast 5 >> "$directory\System_Policies.log"
Write-Console

#Export event viewer logs
Write-Console "Exporting Windows Event Viewer logs ('Application' and 'System' only)..." "White" 1
wevtutil epl Application "$Events\Application_$hostname.evtx" 
wevtutil al "$Events\Application_$hostname.evtx" 
wevtutil epl System "$Events\System_$hostname.evtx"
wevtutil al "$Events\System_$hostname.evtx"
Write-Console

#Check if this is a Server edition of Windows. Workstations do not contain Get-WindowsFeature cmdlet and will throw an error.
if ((Get-CimInstance -ClassName Win32_OperatingSystem).ProductType -ne 1) {
    if ((Get-WindowsFeature -Name Hyper-V).Installed) {
        Write-Console "Hyper-V server detected. Collecting Hyper-V VMMS Event Viewer logs..." "White" 1
        wevtutil epl Microsoft-Windows-Hyper-V-VMMS-Admin "$Events\VMMS_$hostname.evtx"
        wevtutil al "$Events\VMMS_$hostname.evtx"
        Write-Console
    }
    else {
        Write-Console "Hyper-V role was not detected. Skipping collection of VMMS Event Logs." > $null
    }
}

#Get list of installed features
if ((Get-CimInstance -ClassName Win32_OperatingSystem).ProductType -ne 1) {
    Write-Console "Retrieving list of installed features..." "White" 1
    Get-WindowsFeature | Format-Table -AutoSize > "$directory\installed_features.log"
    Write-Console
}

Stop-Transcript > $null
		
#Compress folder containing data
Write-Console "Compressing and zipping collected logs..." "White" 1
#Get large files count
$largefiles = (Get-ChildItem -Path $directory -Recurse | Where-Object { ($_.Length / 1GB) -gt 2 }).Count
#Handle proper method of creating zip file based on PowerShell version + number of files larger than 1GB
if (($PSVersion -gt '4') -and ($largefiles -lt '1')) {
    Compress-Archive "$directory" "$directory.zip" -Force
}
elseif (($PSVersion -lt '5') -or ($largefiles -gt '0')) {
    Compress-Folder $directory
}
Write-Console

#Remove temporary log folder
Write-Console "Removing temporary log folder..." "White" 1
Remove-Item "$directory" -Recurse -Force -Confirm:$false
if (!(Test-Path -Path $directory)) {
    Write-Console
}
else {
    Write-Console "Problem encountered cleaning up temporary log folder. Manual cleanup may be necessary. Location: $directory" "Yellow" 3
}

if (!(Test-Path -Path $veeamDir)) {
    Write-Console "Not all logs could be collected. Please verify you are executing this script on the correct server (ie. guest OS where troubleshooting is necessary)." "Yellow" 3
    Write-Console "Please find any collected logs at $logDir" "Green" 2
} 
else { 
    Write-Console "Log collection finished. Please find the collected logs at $logDir" "Green" 3
}

Explorer $logDir
Start-Sleep 2
Exit
