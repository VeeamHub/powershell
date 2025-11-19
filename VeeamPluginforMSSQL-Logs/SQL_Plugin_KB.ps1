## Veeam SQL Plugin Script
###[26.04] - v 1.0 . Script for SQL Plugin logs collection
###[02.12.2024] - v 2.0 . Logs folder was changed from "Case_logs" to "Veeam_Case_logs". Added the collection of system info (mount vol, OS info, ipconfig, firewall settings, etc.)
###[19.11.2025] - v 2.1 . Added "filters" output" and replaced "wmic" with "Get-CimInstance"

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

#Variables
$ErrorActionPreference = 'SilentlyContinue'
$PS = $PSVersionTable.PSVersion.Major
$date = Get-Date -f yyyy-MM-ddTHHmmss_
$hostname = HOSTNAME.EXE
$item = Get-ItemProperty -Path "HKLM:\SOFTWARE\Veeam\Veeam Endpoint Backup" -Name "LogDirectory" -ErrorAction SilentlyContinue
$logvolume = Split-Path -Path $item.LogDirectory -Parent -ErrorAction SilentlyContinue #<---- "-ErrorAction SilentlyContinue was added"
$veeamlogs = "$logvolume\Veeam_Case_Logs"
$directory = "$veeamlogs\$date$hostname"
$Execution = "$directory\Execution.log"
$Events = "$directory\Events"
$RegVal = "$directory\RegVal"   #<---- separate directory for Registry entries
$SysInfo = "$directory\SysInfo" #<---- separate directory for system information commands
$SQL_Err_Log_Folder = "$directory\SQL_Logs"

#Collecting SQL Plugin logs
$SQL_Log_Folder = "$directory\Plugin_Logs" 
$LogsDir = "C:\ProgramData\Veeam\Backup\MSSQLPluginLogs"
$LogsDirExists = Test-Path $LogsDir
$LogsDirCopy = "C:\ProgramData\Veeam\Backup\MSSQLPluginLogs\*" 

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
New-Item -ItemType Directory -Force -Path $SQL_Log_Folder -ErrorAction SilentlyContinue > $null
New-Item -ItemType Directory -Force -Path $SQL_Err_Log_Folder -ErrorAction SilentlyContinue > $null
New-Item -ItemType Directory -Force -Path $Events -ErrorAction SilentlyContinue > $null
New-Item -ItemType Directory -Force -Path $RegVal -ErrorAction SilentlyContinue > $null
New-Item -ItemType Directory -Force -Path $SysInfo -ErrorAction SilentlyContinue > $null
New-Item -ItemType Directory -Force -Path C:\Temp -ErrorAction SilentlyContinue > $null
Write-Host -ForegroundColor Yellow "Done"

""
Write-Host "Collected logs will be located at:" $veeamlogs -ForegroundColor White -BackgroundColor DarkGreen -ErrorAction SilentlyContinue 

#Copy SQL logs folder
Write-Host 'Copying Veeam SQL Plugin logs' -ForegroundColor White -BackgroundColor Black -ErrorAction SilentlyContinue 
	if ($LogsDirExists -eq $False )
		{
		Write-Warning "Could not copy SQL Plugin logs. Directory was not found" -ErrorAction SilentlyContinue 
		}
	else
		{
		Get-ChildItem -Path $LogsDirCopy | Copy-Item -Destination $SQL_Log_Folder -Recurse -Force -ErrorAction SilentlyContinue 
		Write-Host -ForegroundColor Yellow "Done"
		Start-Sleep 1
		}
	
#Gathering system information (systeminfo, bcedit, mountvol)
Start-Sleep 1
Write-Host 'Gathering system information...' -ForegroundColor White -BackgroundColor Black -ErrorAction SilentlyContinue 
systeminfo > "$SysInfo\systeminfo.log"
bcdedit /v /enum > "$SysInfo\bcedit.log"
mountvol /l > "$SysInfo\mountvol.log"
whoami > "$SysInfo\whoami.log"  #<-- Adding whoami output
dism /online /Get-Packages /Format:Table > "$SysInfo\dism_pack.log" #<-- Adding disk packages output
fsutil fsinfo sectorinfo C: > "$SysInfo\fsutil_info.log" #<-- Adding fsutil command
Get-ComputerInfo > "$SysInfo\SysInfo.log" #<-- Collecting list of the hardware
Get-WmiObject Win32_PnPSignedDriver| select devicename,drivername,infname,driverversion > "$SysInfo\drivers.log" #<-collecting list of drivers
Start-Sleep 1
Write-Host -ForegroundColor Yellow "Done"

#export output of 'ComputerSystemProduct' 
Start-Sleep 1
Write-Host 'Gathering hardware information' -ForegroundColor White -BackgroundColor Black -ErrorAction SilentlyContinue 
Get-CimInstance -ClassName Win32_ComputerSystemProduct | Select Name, IdentifyingNumber, Vendor, UUID  > "$SysInfo\csproduct.log"
Start-Sleep 1
Write-Host -ForegroundColor Yellow "Done"

#export filters
Start-Sleep 1
Write-Host 'Copying File System Minifilter report' -ForegroundColor White -BackgroundColor Black -ErrorAction SilentlyContinue 
fltmc instances > "$SysInfo\filter.log" 
Start-Sleep 1
Write-Host -ForegroundColor Yellow "Done"

#Get list of installed software
Write-Host "Getting list of installed software..." -ForegroundColor White -BackgroundColor Black -ErrorAction SilentlyContinue
Get-WmiObject Win32_Product | Sort-Object Name | Format-Table Name, InstallDate > "$SysInfo\installed_software.log"
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

#Get network information
Write-Host "Getting network information" -ForegroundColor White -BackgroundColor Black -ErrorAction SilentlyContinue
ipconfig /all > "$SysInfo\ipconfig.log"
netstat -bona > "$SysInfo\netstat.log"
route print > "$SysInfo\route.log"
Start-Sleep 1
Write-Host -ForegroundColor Yellow "Done"

#export reg key
Write-Host 'Gathering registy entries' -ForegroundColor White -BackgroundColor Black -ErrorAction SilentlyContinue 
Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" > "$RegVal\Net.log" -ErrorAction SilentlyContinue #<-- .Net ver
Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" > "$RegVal\Policy.log" -ErrorAction SilentlyContinue #<-- Policy
gpresult /z > "$RegVal\GPR.log" #<-- GPR
Get-ItemProperty -Path "HKLM:SYSTEM\CurrentControlSet\Control\Session Manager\Environment" > "$RegVal\env_system.log" -ErrorAction SilentlyContinue #<-- env_system
Get-ItemProperty -Path "HKCU:\Environment" > "$RegVal\env_user.log" -ErrorAction SilentlyContinue #<-- env for user
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

#Collecting SQL ERROR logs for each Instance
Write-Host 'Copying SQL Error logs' -ForegroundColor White -BackgroundColor Black -ErrorAction SilentlyContinue 

#Checking instances
$CheckInstanses = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server').InstalledInstances
#Creating folder for each Instance
$CheckInstanses| ForEach-Object -Begin $null -Process {New-Item -ItemType Directory -Force -Path "$SQL_Err_Log_Folder\$_" -ErrorAction SilentlyContinue > $null} -End $null

#Appendix for the SQL log path
$SQLLog_app = "\Log"


foreach ($Instance in $CheckInstanses) {
	
	$SQLLog = $Instance | ForEach-Object -Begin $null -Process {(Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$($_)\Setup").SQLPath } -End $null  -ErrorAction SilentlyContinue
	
	$SQLLog_path = $SQLLog | ForEach-Object -Begin $null -Process {Join-Path -Path "$($_)" -ChildPath "$SQLLog_app" } -End $null  -ErrorAction SilentlyContinue	
	
	$SQLLog_error = Get-ChildItem -Path $SQLLog_path  -Recurse -Include ERRORLOG, ERRORLOG.* -ErrorAction SilentlyContinue

	$destinationFolder = "$SQL_Err_Log_Folder\$Instance"
	
	Copy-Item $SQLLog_error $destinationFolder -ErrorAction SilentlyContinue
	Write-Host -ForegroundColor Yellow "Done"
	Start-Sleep 1
}

#SQL connection checks

#Set up file paths
$successLogPath = "$directory\SQLConnectionSuccess.txt"
$errorLogPath = "$directory\SQLConnectionErrors.txt"

# Get a list of installed SQL providers
$providers = (New-Object system.data.oledb.oledbenumerator).GetElements() | select sources_name | ? {$_.sources_name -like '*loledb' -or $_.sources_name -like "msoledbsql" -or $_.sources_name -like "SQLNCLI11"}

# Get a list of SQL Server instances
$servers = @()
$serverNames = (Get-WmiObject -Class Win32_Service -Filter "Name LIKE 'MSSQL$%' AND Started = 'True'").Name
foreach ($serverName in $serverNames) {
    $serverInstance = $serverName.Substring(6)
    $servers += New-Object PSObject -Property @{
        ServerName = $env:COMPUTERNAME
        InstanceName = $serverInstance
    }
}

# Test each provider and server combination
foreach ($provider in $providers) {

    foreach ($server in $servers) {
        $dataSource = $server.ServerName + '\' + $server.InstanceName

        $auth = "Integrated Security=SSPI;Persist Security Info=False"
        $connectionString = "Provider=$($provider.SOURCES_NAME);" + "Data Source=$dataSource;" + "$auth;"
        $query = "SELECT @@VERSION"
        $connection = New-Object System.Data.OleDb.OleDbConnection $connectionString
        $command = New-Object System.Data.OleDb.OleDbCommand $query, $connection
        
        
        $success = $false
        $errorMessage = $null

        try {
            $connection.Open()
            $success = $true
            #Write-Host "Connection successful: $dataSource ($($provider.SOURCES_NAME))"
        }
        catch {
        $errorMessage = $_.Exception.Message
            #Write-Host "Connection failed: $dataSource ($($provider.SOURCES_NAME)) - $($_.Exception.Message)"
        }
        finally {
            $connection.Close()
            if ($success) {
                Add-Content -Path $successLogPath -Value "Connection successful: $dataSource ($provider)"
            }
            else {
                Add-Content -Path $errorLogPath -Value "Connection failed: $dataSource ($provider) - $errorMessage"
            }
        }
    }
    }

#export event viewer logs
""
Write-Host 'Copying Windows Event Viewer Logs' -ForegroundColor White -BackgroundColor Black -ErrorAction SilentlyContinue 

wevtutil epl Application "$Events\Application_$hostname.evtx" /q:"*[System[TimeCreated[timediff(@SystemTime) <= 7889231490]]]" /ow:true  
wevtutil al "$Events\Application_$hostname.evtx" 

wevtutil epl Security "$Events\Security_$hostname.evtx" /q:"*[System[TimeCreated[timediff(@SystemTime) <= 7889231490]]]" /ow:true  
wevtutil al "$Events\Security_$hostname.evtx" 

wevtutil epl System "$Events\System_$hostname.evtx" /q:"*[System[TimeCreated[timediff(@SystemTime) <= 7889231490]]]" /ow:true  
wevtutil al "$Events\System_$hostname.evtx" 

Start-Sleep 1
Write-Host -ForegroundColor Yellow "Done"

#Collecting cluster evens (if applicable)

Write-Host 'Collecting cluster evens (if applicable)' -ForegroundColor White -BackgroundColor Black -ErrorAction SilentlyContinue 

$CheckCluEvents = [System.Diagnostics.EventLog]::SourceExists("Microsoft-Windows-FailoverClustering")
$GetClusterEv = Get-WinEvent -listLog * | ? LogName -like "*failover*" -ErrorAction SilentlyContinue

	if ($CheckCluEvents -eq $False )
		{
		Write-Warning "This is not a cluster node. Skipping this step" -ErrorAction SilentlyContinue 
		}
	else
	{
		$GetClusterEv.Logname | ForEach-Object -Begin $null -Process {wevtutil epl "$_" "$Events\$($_.replace("/", "_")).evtx" /q:"*[System[TimeCreated[timediff(@SystemTime) <= 1209600000 ]]]" /ow:true}, {wevutil al "$Events\$($_.replace("/", "_")).evtx" -ErrorAction SilentlyContinue} -End $null
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
    Write-Warning "Not all SQL Plugin logs could be collected. Please verify Veeam Plug-in for Microsoft SQL Server is installed." -ErrorAction SilentlyContinue
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
