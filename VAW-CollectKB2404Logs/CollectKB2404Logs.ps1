## Veeam Script
###[09.08.2021] v.1.1 - added %ProgramData%\Veeam\Backup folder as a source of Hardware VSS logs
###[12.12.2022] v.2.0 - added System Information: GPO, network configuration, firewall configuration, installed software & updates; TLS settings, v6 specifics.
###[23.02.2023] v.2.0.1 - added Cloud Native machine logs. 
###[25.08.2023] v.2.0.5 - added dism to grab updates, whoami, fsutil
###[07.02.2024] v 2.0.6 - added additional checks for VAW installation, changed folder for logs from "Case_logs" -> Veeam_Case_logs
###[13.05.2024] v 2.0.7 - changed method for collection installed software from Get-WmiObject to faster and more reliable one, added information about ciphers
###[22.07.2024] v 2.0.8 - command "wevtutil" was fixed on line 603
###[10.12.2024] v 2.0.9 - added additional files and folder to collect (C:\ProgramData\Veeam\Backup\BackupSearch) for FLR troubleshooting
###[08.07.2025] v 2.0.10 - workflow improvements
###[21.08.2025] v 2.0.11 - "wmic" was replaced with "Get-CimInstance" 

Start-Sleep 1
Write-Warning -Message "This script is provided as is as a courtesy for collecting logs from the Guest Machine. Please be aware that due to certain Microsoft Operations, there may be a short burst of high CPU activity, and that some 

Windows OSes and GPOs may affect script execution. There is no support provided for this script, and should it fail, we ask that you please proceed to collect the required information manually"
Start-Sleep 1
Write-Host "`nChecking elevation rights"
Start-Sleep 1

#Checking elevation rights
if (!(New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))
{
  Write-Host -ForegroundColor Yellow "You're running PowerShell without elevated rights. Please open a PowerShell window as an Administrator."
  Exit
}
else {Write-Host -ForegroundColor Green "You're running PowerShell as an Administrator. Starting data collection."}

#Checking if VAW is installed on the machine in question via reg value

$VAW_installed = Test-path -Path "HKLM:\SOFTWARE\Veeam\Veeam Endpoint Backup"

if ($VAW_installed -eq $False) {
    Write-Warning -Message "Looks like Veeam Agent is not installed on this machine."
     $VAW_not_installed = Read-Host -Prompt "Press Y to continue (some errors are expected during log collection process and the logs will be saved in C:\Veeam_Case_logs) or press N to exit"
    if ($VAW_not_installed -eq 'N')
        {
        exit
        }
    else 
    {
        Write-Host -ForegroundColor Green "Starting data collection"
    }

}

#If VAW is installed or input is 'Y' - continue logs collection

#Variables
$PS = $PSVersionTable.PSVersion.Major
$date = Get-Date -f yyyy-MM-ddTHHmmss_
$hostname = HOSTNAME.EXE
$item = Get-ItemProperty -Path "HKLM:\SOFTWARE\Veeam\Veeam Endpoint Backup" -Name "LogDirectory" -ErrorAction SilentlyContinue
$logvolume = Split-Path -Path $item.LogDirectory -Parent -ErrorAction SilentlyContinue #<---- "-ErrorAction SilentlyContinue was added"
$veeamlogs = "$logvolume\Veeam_Case_Logs"
$directory = "$veeamlogs\VAWLogs_$date$hostname"
$Execution = "$directory\Execution.log"
$VAW = "$directory\Endpoint"
$Events = "$directory\Events"
$VSS = "$directory\VSS"
$RegVal = "$directory\RegVal"   #<---- separate directory for Registry entries
$SysInfo = "$directory\SysInfo" #<---- separate directory for system information commands
#Setup section
$SetupFol = "$directory\Setup" #<---- Collecting Setup logs from C:\ProgramData\Veeam\Setup\Temp
$SetupDir = "C:\ProgramData\Veeam\Setup\Temp"
$SetupFolExists = Test-Path $SetupDir
$SetupFolCopy = "C:\ProgramData\Veeam\Setup\Temp\*" #<---- End of the C:\ProgramData\Veeam\Setup\Temp section
$SetupMNGDir = "C:\ProgramData\Veeam\Backup\Setup" #<---- Collecting Setup logs from C:\ProgramData\Veeam\Backup\Setup
$SetupMNGExists = Test-Path "C:\ProgramData\Veeam\Backup\Setup"
$CloudFol = "C:\ProgramData\Veeam\Backup\cloudmsg" #<---- Collecting Setup logs for Cloud-based Agents
$CloudFolExists = Test-Path "C:\ProgramData\Veeam\Backup\cloudmsg"
$CloudFolLog = "$directory\Backup\cloudmsg"
#Snapshot provider logs section
$SnapProv = "$directory\Backup" #<---- Collectiong snapshot logs
$SnapProvDir = "C:\ProgramData\Veeam\Backup\"
$SnapProvExists = Test-Path $SnapProvDir
$SnapProvCopy = "C:\ProgramData\Veeam\Backup\*" #<---- End of the snapshot logs collection section
#FLR for VCSP
$VCSP_FLR = "C:\ProgramData\Veeam\Backup\BackupSearch" #<---- Collecting Setup logs for Cloud-based Agents
$VCSP_FLR_FolExists = Test-Path "C:\ProgramData\Veeam\Backup\BackupSearch"
$VCSP_FLR_FolLog = "$directory\Backup\BackupSearch"

$ZipFolder = $function:ZipFolder

#Logging everything


#Functions

function CountZipItems(
    [__ComObject] $zipFile)
{
    If ($zipFile -eq $null)
    {
        Throw "Value cannot be null: zipFile"
    }
    
    Write-Host ("Counting items in zip file (" + $zipFile.Self.Path + ")...") -ForegroundColor White -BackgroundColor Black
    
    [int] $count = CountZipItemsRecursive($zipFile)
	
    Write-Host ($count.ToString() + " items in zip file (" + $zipFile.Self.Path + ").") -ForegroundColor White -BackgroundColor Black
    
    return $count
}

function CountZipItemsRecursive(
    [__ComObject] $parent)
{
    If ($parent -eq $null)
    {
        Throw "Value cannot be null: parent"
    }
    
    [int] $count = 0

    $parent.Items() |
        ForEach-Object {
            $count += 1
            
            If ($_.IsFolder -eq $true)
            {
                $count += CountZipItemsRecursive($_.GetFolder)
            }
        }
    
    return $count
}

function IsFileLocked(
    [string] $path)
{
    If ([string]::IsNullOrEmpty($path) -eq $true)
    {
        Throw "The path must be specified."
    }
    
    [bool] $fileExists = Test-Path $path
    
    If ($fileExists -eq $false)
    {
        Throw "File does not exist (" + $path + ")"
    }
    
    [bool] $isFileLocked = $true

    $file = $null
    
    Try
    {
        $file = [IO.File]::Open(
            $path,
            [IO.FileMode]::Open,
            [IO.FileAccess]::Read,
            [IO.FileShare]::None)
            
        $isFileLocked = $false
    }
    Catch [IO.IOException]
    {
        If ($_.Exception.Message.EndsWith(
            "it is being used by another process.") -eq $false)
        {
            Throw $_.Exception
        }
    }
    Finally
    {
        If ($file -ne $null)
        {
            $file.Close()
        }
    }
    
    return $isFileLocked
}
    
function GetWaitInterval(
    [int] $waitTime)
{
    If ($waitTime -lt 1000)
    {
        return 100
    }
    ElseIf ($waitTime -lt 5000)
    {
        return 1000
    }
    Else
    {
        return 5000
    }
}

function WaitForZipOperationToFinish(
    [__ComObject] $zipFile,
    [int] $expectedNumberOfItemsInZipFile)
{
    If ($zipFile -eq $null)
    {
        Throw "Value cannot be null: zipFile"
    }
    ElseIf ($expectedNumberOfItemsInZipFile -lt 1)
    {
        Throw "The expected number of items in the zip file must be specified."
    }

    Write-Host -NoNewLine "Waiting for zip operation to finish..." -ForegroundColor White -BackgroundColor Black
    Start-Sleep -Milliseconds 100 # ensure zip operation had time to start
    
    [int] $waitTime = 0
    [int] $maxWaitTime = 60 * 10000 # [milliseconds]
    while($waitTime -lt $maxWaitTime)
    {
        [int] $waitInterval = GetWaitInterval($waitTime)
                
        Write-Host -NoNewLine "."
        Start-Sleep -Milliseconds $waitInterval
        $waitTime += $waitInterval

        Write-Debug ("Wait time: " + $waitTime / 1000 + " seconds")
        
        [bool] $isFileLocked = IsFileLocked($zipFile.Self.Path)
        
        If ($isFileLocked -eq $true)
        {
            Write-Debug "Zip file is locked by another process."
            Continue
        }
        Else
        {
            Break
        }
    }
    
    Write-Host                           
    
    If ($waitTime -ge $maxWaitTime)
    {
        Throw "Timeout exceeded waiting for zip operation"
    }
    
    [int] $count = CountZipItems($zipFile)
    
    If ($count -eq $expectedNumberOfItemsInZipFile)
    {
        Write-Debug "The zip operation completed succesfully."
    }
    ElseIf ($count -eq 0)
    {
        Throw ("Zip file is empty. This can occur if the operation is" `
            + " cancelled by the user.")
    }
    ElseIf ($count -gt $expectedCount)
    {
        Throw "Zip file contains more than the expected number of items."
    }
}

function ZipFolder(
    [IO.DirectoryInfo] $directory)
{
    If ($directory -eq $null)
    {
        Throw "Value cannot be null: directory"
    }
    
    Write-Host ("Creating zip file for folder (" + $directory.FullName + ")...") -ForegroundColor White -BackgroundColor Black
    
    [IO.DirectoryInfo] $parentDir = $directory.Parent
    
    [string] $zipFileName
    
    If ($parentDir.FullName.EndsWith("\") -eq $true)
    {
        # e.g. $parentDir = "C:\"
        $zipFileName = $parentDir.FullName + $directory.Name + ".zip"
    }
    Else
    {
        $zipFileName = $parentDir.FullName + "\" + $directory.Name + ".zip"
    }
    
    If (Test-Path $zipFileName)
    {
       Throw "Zip file already exists ($zipFileName)."
	}
    
    Set-Content $zipFileName ("PK" + [char]5 + [char]6 + ("$([char]0)" * 18))
        
    $shellApp = New-Object -ComObject Shell.Application
    $zipFile = $shellApp.NameSpace($zipFileName)

    If ($zipFile -eq $null)
    {
        Throw "Failed to get zip file object."
    }
    
    [int] $expectedCount = (Get-ChildItem $directory -Force -Recurse).Count
    $expectedCount += 1 # account for the top-level folder
    
    $zipFile.CopyHere($directory.FullName)

    # wait for CopyHere operation to complete
    WaitForZipOperationToFinish $zipFile $expectedCount
    
    Write-Host ("Successfully created zip file for folder (" + $directory.FullName + ").") -ForegroundColor White -BackgroundColor Black
}

#Create directories & execution log

New-Item -ItemType Directory -Force -Path $directory >$null
New-Item -ItemType File -Force -Path "$directory\Execution.log" >$null

# Transcript all workflow
Start-Transcript -Path $Execution > $null

Write-Host "Creating directories" 
New-Item -ItemType Directory -Force -Path $VAW -ErrorAction SilentlyContinue > $null
New-Item -ItemType Directory -Force -Path $Events -ErrorAction SilentlyContinue > $null
New-Item -ItemType Directory -Force -Path $VSS -ErrorAction SilentlyContinue > $null
New-Item -ItemType Directory -Force -Path $RegVal -ErrorAction SilentlyContinue > $null
New-Item -ItemType Directory -Force -Path $SysInfo -ErrorAction SilentlyContinue > $null
New-Item -ItemType Directory -Force -Path $SetupFol -ErrorAction SilentlyContinue > $null
New-Item -ItemType Directory -Force -Path $SnapProv -ErrorAction SilentlyContinue > $null
New-Item -ItemType Directory -Force -Path C:\Temp -ErrorAction SilentlyContinue > $null
Write-Host -ForegroundColor Yellow "Done"

""
Write-Host "Collected logs will be located at:" $veeamlogs -ForegroundColor White -BackgroundColor DarkGreen -ErrorAction SilentlyContinue 

#Copy Endpoint folder
Write-Host 'Copying Veeam Agent for Windows software logs' -ForegroundColor White -BackgroundColor Black -ErrorAction SilentlyContinue 
	if ($item.LogDirectory -eq $null)
		{
		Write-Warning "Could not copy Endpoint folder. Veeam Agent for Windows log directory was not found" -ErrorAction SilentlyContinue 
		}
	else
		{
		Get-ChildItem -Path $item.LogDirectory -Exclude SqlLogBackup | Copy-Item -Destination $VAW -Recurse -Force -ErrorAction SilentlyContinue 
		Write-Host -ForegroundColor Yellow "Done"
		Start-Sleep 1
		}
		
#Copy Setup folder
Write-Host 'Copying Veeam Agent for Windows Setup logs' -ForegroundColor White -BackgroundColor Black -ErrorAction SilentlyContinue 
	if ($SetupFolExists -eq $False )
		{
		Write-Warning "Could not copy Setup logs. Veeam Agent for Windows log directory was not found" -ErrorAction SilentlyContinue 
		}
	else
		{
		Get-ChildItem -Path $SetupFolCopy -Include EndPointSetup.log, SharedManagementObjects.log, SqlLocalDB.log, SQLSysClrTypes.log | Copy-Item -Destination $SetupFol -Recurse -Force -ErrorAction SilentlyContinue 
		Write-Host -ForegroundColor Yellow "Done"
		Start-Sleep 1
		}
		
	if ($SetupMNGExists -eq $False )
		{
		Write-Warning "Could not copy Setup logs. Veeam Agent for Windows version is lower than v6" -ErrorAction SilentlyContinue 
		}
	else
		{
		Get-ChildItem -Path $SetupMNGDir | Copy-Item -Destination $SetupFol -Recurse -Force -ErrorAction SilentlyContinue 
		Write-Host -ForegroundColor Yellow "Done"
		Start-Sleep 1
		}
		
#Copy Backup Folder
Write-Host 'Copying Veeam Agent for Windows Snapshot provider and Installer logs (if applicable)' -ForegroundColor White -BackgroundColor Black -ErrorAction SilentlyContinue 

	if ($SnapProvExists -eq $False )
		{
		Write-Warning "Could not copy provider logs folder. Veeam Agent for Windows log directory was not found" -ErrorAction SilentlyContinue 
		}
	else
		{
		Get-ChildItem -Path $SnapProvCopy -Include *.VssHwSnapshotProviderService.log, *.VssHwSnapshotProviderService.*.log,*.VssHwSnapshotProviderService.zip, *.VeeamInstaller.log, *.VeeamInstaller.*.log, *.VeeamInstallerDll.log, *.VeeamInstallerDll.*.log, Driver.VeeamFLR.log | Copy-Item -Destination $SnapProv -Recurse -Force -ErrorAction SilentlyContinue 
		Write-Host -ForegroundColor Yellow "Done"
		Start-Sleep 1
		}

if ($CloudFolExists -eq $False )
		{
		Write-Warning "Could not copy Setup logs. Veeam Agent for Windows is not Cloud-based" -ErrorAction SilentlyContinue
		}
	else
		{
		New-Item -ItemType Directory -Force -Path $CloudFolLog -ErrorAction SilentlyContinue > $null
		Get-ChildItem -Path $CloudFol | Copy-Item -Destination $CloudFolLog -Recurse -Force -ErrorAction SilentlyContinue 
		Get-ChildItem -Path $SnapProvCopy -Include Cli.VeeamTransport.log, Svc.VeeamTransport.log, VssProxy.log, *.Target.log | Copy-Item -Destination $SnapProv -Recurse -Force -ErrorAction SilentlyContinue
		}

if ($VCSP_FLR_FolExists -eq $False )
		{
		Write-Warning "Could not copy FLR logs." -ErrorAction SilentlyContinue
		}
	else
		{
		New-Item -ItemType Directory -Force -Path $VCSP_FLR_FolLog -ErrorAction SilentlyContinue > $null
		Get-ChildItem -Path $VCSP_FLR | Copy-Item -Destination $VCSP_FLR_FolLog -Recurse -Force -ErrorAction SilentlyContinue 
		}

#export vss logs
Start-Sleep 1
Write-Host 'Copying VSS logs' -ForegroundColor White -BackgroundColor Black -ErrorAction SilentlyContinue 
vssadmin list providers > "$VSS\vss_providers.log"
vssadmin list shadows > "$VSS\vss_shadows.log"
vssadmin list shadowstorage > "$VSS\vss_shadow_storage.log"

#Handling vssadmin writers in case it hangs
$writersTimeout=30;
$writersProcs=Start-Process -FilePath powershell.exe -ArgumentList '-Command "vssadmin list writers > C:\Temp\vss_writers.log' -PassThru -NoNewWindow
	try
	{
		$writersProcs | Wait-Process -Timeout $writersTimeout -ErrorAction Stop
	}
	catch
	{
		Write-Host 'Collecting VSS Writers data has taken more than expected - there can be an issue with the VSS subsystem. Skipping VSS...' 
		$writersProcs | Stop-Process -Force
	}
if (Test-Path C:\Temp\vss_writers.log) {Move-Item C:\Temp\vss_writers.log -Destination  $VSS}

Start-Sleep 1
Write-Host -ForegroundColor Yellow "Done"

#Gathering system information (systeminfo, bcedit, mountvol)
Start-Sleep 1
Write-Host 'Gathering system information...' -ForegroundColor White -BackgroundColor Black -ErrorAction SilentlyContinue 
systeminfo > "$SysInfo\systeminfo.log"
bcdedit /v /enum > "$SysInfo\bcedit.log"
mountvol /l > "$SysInfo\mountvol.log"
whoami > "$SysInfo\whoami.log"  #<-- Adding whoami output
dism /online /Get-Packages /Format:Table > "$SysInfo\dism_pack.log" #<-- Adding disk packages output
fsutil fsinfo sectorinfo C: > "$SysInfo\fsutil_info.log" #<-- Adding fsutil command
if ($PSVersionTable.PSVersion -ge "5.1")
    {Get-ComputerInfo > "$SysInfo\SysInfo.log"} #<-- Collecting list of the hardware  
Get-WmiObject Win32_PnPSignedDriver| select devicename,drivername,infname,driverversion > "$SysInfo\drivers.log" #<-collecting list of drivers
Start-Sleep 1
Write-Host -ForegroundColor Yellow "Done"

#export output of 'ComputerSystemProduct' 
Start-Sleep 1
Write-Host 'Gathering hardware information' -ForegroundColor White -BackgroundColor Black -ErrorAction SilentlyContinue 
Get-CimInstance -ClassName Win32_ComputerSystemProduct | Select Name, IdentifyingNumber, Vendor, UUID  > "$SysInfo\csproduct.log"
Start-Sleep 1
Write-Host -ForegroundColor Yellow "Done"

#export reg key
Write-Host 'Gathering registy entries' -ForegroundColor White -BackgroundColor Black -ErrorAction SilentlyContinue 
Get-ItemProperty -Path "HKLM:\SOFTWARE\Veeam\Veeam Endpoint Backup" > "$RegVal\VAW_registry.log" -ErrorAction SilentlyContinue #<-- VAW reg key
Get-ItemProperty -Path "HKLM:\SOFTWARE\Veeam\Veeam Backup and Replication" > "$RegVal\VBR_registry.log" -ErrorAction SilentlyContinue #<--VBR reg key
Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" > "$RegVal\Net.log" -ErrorAction SilentlyContinue #<-- .Net ver
Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" > "$RegVal\Policy.log" -ErrorAction SilentlyContinue #<-- Policy
gpresult /z > "$RegVal\GPR.log" #<-- GPR
Get-ItemProperty -Path "HKLM:SYSTEM\CurrentControlSet\Control\Session Manager\Environment" > "$RegVal\env_system.log" -ErrorAction SilentlyContinue #<-- env_system
Get-ItemProperty -Path "HKCU:\Environment" > "$RegVal\env_user.log" -ErrorAction SilentlyContinue #<-- env for user
Start-Sleep 1
Write-Host -ForegroundColor Yellow "Done"

#VAW certificate info
Start-Sleep 1
Write-Host 'Gathering information about Veeam Agent for Windows certificate' -ForegroundColor White -BackgroundColor Black -ErrorAction SilentlyContinue 
Get-ChildItem Cert:\LocalMachine\My\ | where{$_.FriendlyName -eq 'Veeam Agent Certificate'} |Format-List -Property Issuer, Subject, SerialNumber, Thumbprint, NotAfter > "$SysInfo\VAW_cert.log"
Start-Sleep 1
Write-Host -ForegroundColor Yellow "Done"

#export filters
Start-Sleep 1
Write-Host 'Copying File System Minifilter report' -ForegroundColor White -BackgroundColor Black -ErrorAction SilentlyContinue 
fltmc instances > "$SysInfo\filter.log" 
Start-Sleep 1
Write-Host -ForegroundColor Yellow "Done"

#Get uptime
Start-Sleep 1
Write-Host 'Collecting uptime information' -ForegroundColor White -BackgroundColor Black -ErrorAction SilentlyContinue 
Get-CimInstance -ClassName Win32_OperatingSystem | Select LastBootUpTime > "$SysInfo\uptime.log"
Start-Sleep 1
Write-Host -ForegroundColor Yellow "Done"

#Get Windows updates 
Start-Sleep 1
Write-Host 'Collecting Windows updates information' -ForegroundColor White -BackgroundColor Black -ErrorAction SilentlyContinue 
Get-CimInstance -ClassName Win32_QuickFixEngineering | Select Caption, CSName, Description, HotFixID, installDate, InstalledOn > "$SysInfo\Windows_updates.log"


#Handling updates collection in case it hangs
$updatesTimeout=30;
$updatesProcs=Start-Process -FilePath powershell.exe -ArgumentList '-Command "Get-CimInstance -ClassName Win32_QuickFixEngineering | Select Caption, CSName, Description, HotFixID, installDate, InstalledOn > "$SysInfo\Windows_updates.log' -PassThru -NoNewWindow
	try
	{
		$updatesProcs | Wait-Process -Timeout $updatesTimeout -ErrorAction Stop
	}
	catch
	{
		Write-Host 'Collecting OS updates information has taken more than expected. Skipping this step...' 
		$updatesProcs | Stop-Process -Force
	}
if (Test-Path C:\Temp\Windows_updates.log) {Move-Item C:\Temp\Windows_updates.log -Destination  $SysInfo}

Start-Sleep 1
Write-Host -ForegroundColor Yellow "Done"

#Get Windows Firewall profile
Write-Host "Getting status of Windows Firewall profiles..." -ForegroundColor White -BackgroundColor Black -ErrorAction SilentlyContinue
Get-NetFirewallProfile | Format-List > "$SysInfo\firewall_profiles.log"
Start-Sleep 1
Write-Host -ForegroundColor Yellow "Done"

#Get network security settings (This is where customizations such as disabling TLS 1.0/1.1 or key exchange algorithms are done)
Write-Host "Checking for network customizations (ie. Is TLS 1.0/1.1 disabled? Custom key exchange algorithms?)..." -ForegroundColor White -BackgroundColor Black -ErrorAction SilentlyContinue
#Must test to see if registry hive exists, otherwise would cause a stack overflow error.
if (Test-Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL') {
    reg export "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL" "$SysInfo\network_customizations.log" 
}
Start-Sleep 1
Write-Host -ForegroundColor Yellow "Done"

#Get network information
Write-Host "Getting network information" -ForegroundColor White -BackgroundColor Black -ErrorAction SilentlyContinue
ipconfig /all > "$SysInfo\ipconfig.log"
netstat -bona > "$SysInfo\netstat.log"
route print > "$SysInfo\route.log"
try { Get-TlsCipherSuite | Format-Table name | Out-File -FilePath "$SysInfo\ciphers.txt" } catch { }
Start-Sleep 1
Write-Host -ForegroundColor Yellow "Done"

#Check if the machine is linked to VBR. If so, tnc and traceroute to VBR IPs

Write-Host "Checking in which mode Veeam Agent operates and connection to Veeam B&R server" -ForegroundColor White -BackgroundColor Black -ErrorAction SilentlyContinue
$ErrorActionPreference = 'SilentlyContinue'
$VBRhostname = Get-ItemProperty -Path "HKLM:\SOFTWARE\Veeam\Veeam Endpoint Backup" -Name BackupServerIPAddress -ErrorAction SilentlyContinue
$IP = $VBRhostname.BackupServerIPAddress 
if ($IP)
{     $IPArray = $IP.Split("|")  
$TrueIP = $IPArray | Select-Object -Last $IPArray.Length -Skip 1     
$TrueIP | ForEach-Object -Begin $null -Process {Test-NetConnection $_ -port 10005 >> $SysInfo\test_netconnection.log -WarningAction SilentlyContinue}, {tracert /d /h 10 /w 1000 $_ >> $SysInfo\tracert.log} -End $null
}  

Start-Sleep 1
Write-Host -ForegroundColor Yellow "Done"

#Get list of installed software
Write-Host "Getting list of installed software..." -ForegroundColor White -BackgroundColor Black -ErrorAction SilentlyContinue

$Installed_apps = @()
$Installed_apps += Get-ItemProperty "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" | select DisplayName, DisplayVersion, InstallDate # 32 Bit
$Installed_apps += Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" | select DisplayName, DisplayVersion, InstallDate # 64 Bit
$Installed_apps | Out-File -FilePath "$SysInfo\installed_software.log"
Start-Sleep 1
Write-Host -ForegroundColor Yellow "Done"

#Get status of 'File and Printer Sharing'
Write-Host "Checking if 'File and Printer Sharing' is enabled..." -ForegroundColor White -BackgroundColor Black -ErrorAction SilentlyContinue
Get-NetAdapterBinding | Where-Object { $_.DisplayName -match "File and Printer Sharing" } | Format-Table -AutoSize > "$SysInfo\file_and_printer_sharing.log"
Start-Sleep 1
Write-Host -ForegroundColor Yellow "Done"

#Get status of Services
Write-Host "Getting status of Windows Services..." -ForegroundColor White -BackgroundColor Black -ErrorAction SilentlyContinue
gwmi win32_service | select displayname, name, startname,startmode,state |fl * > "$SysInfo\services.log"
Start-Sleep 1
Write-Host -ForegroundColor Yellow "Done"

#export event viewer logs
""
Write-Host 'Copying Windows Event Viewer Logs' -ForegroundColor White -BackgroundColor Black -ErrorAction SilentlyContinue 

wevtutil epl Application "$Events\Application_$hostname.evtx" /q:"*[System[TimeCreated[timediff(@SystemTime) <= 7889231490]]]" /ow:true
wevtutil al "$Events\Application_$hostname.evtx" 

wevtutil epl Security "$Events\Security_$hostname.evtx" /q:"*[System[TimeCreated[timediff(@SystemTime) <= 7889231490]]]" /ow:true
wevtutil al "$Events\Security_$hostname.evtx" 

wevtutil epl System "$Events\System_$hostname.evtx" /q:"*[System[TimeCreated[timediff(@SystemTime) <= 7889231490]]]" /ow:true
wevtutil al "$Events\System_$hostname.evtx"

wevtutil epl "Veeam Agent" "$Events\VeeamAgent_$hostname.evtx" /q:"*[System[TimeCreated[timediff(@SystemTime) <= 7889231490]]]" /ow:true
wevtutil al "$Events\VeeamAgent_$hostname.evtx"

wevtutil epl "Microsoft-Windows-SMBClient/Connectivity" "$Events\SMB_Client_Connectivity_$hostname.evtx" /q:"*[System[TimeCreated[timediff(@SystemTime) <= 7889231490]]]" /ow:true
wevtutil al "$Events\SMB_Client_Connectivity_$hostname.evtx"

wevtutil epl "Microsoft-Windows-SMBClient/Operational" "$Events\SMB_Client_Operational_$hostname.evtx" /q:"*[System[TimeCreated[timediff(@SystemTime) <= 7889231490]]]" /ow:true
wevtutil al "$Events\SMB_Client_Operational_$hostname.evtx"

Start-Sleep 1
Write-Host -ForegroundColor Yellow "Done"

#Collecting cluster evens (if applicable)

Write-Host 'Collecting cluster evens (if applicable)' -ForegroundColor White -BackgroundColor Black -ErrorAction SilentlyContinue 

$CheckCluEvents = [System.Diagnostics.EventLog]::SourceExists("Microsoft-Windows-FailoverClustering")
$GetClusterEv = Get-WinEvent -listLog * | ? LogName -like "*failover*" -ErrorAction SilentlyContinue

	if ($CheckCluEvents -eq $False )
		{
		Write-Host "INFO: This is not a cluster node. Skipping this step" -ErrorAction SilentlyContinue 
		}
	else
	{
		$GetClusterEv.Logname | ForEach-Object -Begin $null -Process {wevtutil epl "$_" "$Events\$($_.replace("/", "_")).evtx" /q:"*[System[TimeCreated[timediff(@SystemTime) <= 1209600000 ]]]" /ow:true}, {wevtutil al "$Events\$($_.replace("/", "_")).evtx"} -End $null
	}
		
#Compress folder containing data
""
Write-Host 'Compressing and zipping collected logs' -ForegroundColor White -BackgroundColor Black -ErrorAction SilentlyContinue 


#Stop Transcript (stop it here, because Compress-Archive won't be able to add file to the archive (but ZipFolder will)
Stop-Transcript > $null

Start-Sleep 1

#Get large files count
$largefiles = (Get-ChildItem -Path $directory -Recurse | Where-Object { ($_.Length /1GB) -gt 2 } ).count
Write-Host 'Number of files larger than 1GB is:' $largefiles 

if (($PS -gt '4') -and ($largefiles -lt '1'))
	{
	Compress-Archive "$directory" "$directory.zip" -Force
	}

elseif (($PS -lt '5') -or ($largefiles -gt '0'))
	{
	ZipFolder $directory
	}
Write-Host -ForegroundColor Yellow "Done"
Start-Sleep 1

#Remove temporary log folder
Remove-Item "$directory" -Recurse -Force -Confirm:$false


#Summary
if ($item.LogDirectory -eq $null)
    {
    Write-Warning "Not all Agent logs could be collected. Please verify Veeam Agent for Windows is installed." -ErrorAction SilentlyContinue
	""
	Write-Host 'Log Collection Finished. Please find the collected logs at' $veeamlogs -ForegroundColor White -BackgroundColor DarkGreen
    }
else 
    {
    Write-Host 'Log Collection Finished. Please find the collected logs at' $veeamlogs -ForegroundColor White -BackgroundColor DarkGreen
    }


$exit = Read-Host -Prompt 'Press Y to view logs location or press N to exit.'
if ($exit -eq 'Y')
	{
	explorer $veeamlogs
	}
	
else
	{
	exit
	}