<#
.SYNOPSIS
	Upgrades Veeam Environment from 9.5 Update 4b to v10 GA

.DESCRIPTION
    This script will upgrade Veeam Backup Enterprise Manager and/or
    Veeam Backup & Replication Server depending on what's installed. The script
    is designed to be executed on the server to be upgraded. It's also
    possible to execute the script from a remote PowerShell session.
	
.PARAMETER ISO
	Location of Veeam ISO containing upgrade files. If not specified, script will attempt to download the ISO from Veeam's public servers.

.PARAMETER License
	Veeam License key file

.OUTPUTS
	Update-Veeam.ps1 returns exit code of 0 upon success

.EXAMPLE
	Update-Veeam.ps1 -License "C:\Veeam-backup-trial.lic"

	Description 
	-----------     
	Upgrades Veeam environment using the specified license file and downloads the Veeam 10 ISO from Veeam's public servers

.EXAMPLE
	Update-Veeam.ps1 -ISO "C:\VeeamBackup&Replication_10.0.0.4461.iso" -License "C:\Veeam-backup-trial.lic"

	Description 
	-----------     
	Upgrades Veeam environment using the specified license file and uses the specified local ISO

.NOTES
	NAME:  Update-Veeam.ps1
	VERSION: 1.0
	AUTHOR: Chris Arceneaux
	TWITTER: @chris_arceneaux
	GITHUB: https://github.com/carceneaux

    ####### VEEAM BACKUP ENTERPRISE MANAGER UPGRADE #######
    1. Veeam Backup Catalog
    2. Veeam Backup Enterprise Manager
    3. Veeam Cloud Connect Portal (if installed)

    ####### VEEAM BACKUP & REPLICATION SERVER UPGRADE #######
    1. Veeam Backup Catalog
    2. Veeam Backup & Replication Server
    3. Veeam Backup & Replication Console
    4. Veeam Explorer for Microsoft Active Directory
    5. Veeam Explorer for Microsoft Exchange
    6. Veeam Explorer for Microsoft SharePoint
    7. Veeam Explorer for Microsoft SQL Server
    8. Veeam Explorer for Oracle
    9. Veeam Distribution Service
    10. Veeam Installer Service
    11. Veeam Agent for Linux Redistributable
    12. Veeam Agent for Microsoft Windows Redistributable
    13. Veeam Mount Service
    14. Veeam Backup Transport
    15. Veeam Backup vPowerNFS
    16. Veeam Backup Cloud Gateway (if installed)

.LINK
	https://arsano.ninja/

.LINK
    https://helpcenter.veeam.com/docs/backup/vsphere/silent_mode.html?ver=100

.LINK
    https://helpcenter.veeam.com/docs/backup/vsphere/upgrade_vbr.html?ver=100

#>
#Requires -RunAsAdministrator
param(
    [Parameter(Mandatory = $false)]
    [String] $ISO = "download",
    [Parameter(Mandatory = $true)]
    [String] $License
)

# Setting Log Location
$logFolder = $env:SYSTEMDRIVE + "\temp\veeam-upgrade"
New-Item -ItemType Directory -Force -Path $logFolder | Out-Null  #makes sure folder exists
$logFile = "$logFolder\upgrade.log"
Clear-Content $logFile -ErrorAction SilentlyContinue

Function Get-Software {
    # Sourced from https://mcpmag.com/articles/2017/07/27/gathering-installed-software-using-powershell.aspx
    [OutputType('System.Software.Inventory')]
    [Cmdletbinding()] 
    Param( 
        [Parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)] 
        [String[]]$Computername = $env:COMPUTERNAME
    )         
    Begin {
    }
    Process {     
        ForEach ($Computer in  $Computername) { 
            If (Test-Connection -ComputerName  $Computer -Count  1 -Quiet) {
                $Paths = @("SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall", "SOFTWARE\\Wow6432node\\Microsoft\\Windows\\CurrentVersion\\Uninstall")         
                ForEach ($Path in $Paths) { 
                    Write-Verbose  "Checking Path: $Path"
                    #  Create an instance of the Registry Object and open the HKLM base key 
                    Try { 
                        $reg = [microsoft.win32.registrykey]::OpenRemoteBaseKey('LocalMachine', $Computer, 'Registry64') 
                    }
                    Catch { 
                        Write-Error $_ 
                        Continue 
                    } 
                    #  Drill down into the Uninstall key using the OpenSubKey Method 
                    Try {
                        $regkey = $reg.OpenSubKey($Path)  
                        # Retrieve an array of string that contain all the subkey names 
                        $subkeys = $regkey.GetSubKeyNames()      
                        # Open each Subkey and use GetValue Method to return the required  values for each 
                        ForEach ($key in $subkeys) {   
                            Write-Verbose "Key: $Key"
                            $thisKey = $Path + "\\" + $key 
                            Try {  
                                $thisSubKey = $reg.OpenSubKey($thisKey)   
                                # Prevent Objects with empty DisplayName 
                                $DisplayName = $thisSubKey.getValue("DisplayName")
                                If ($DisplayName -AND $DisplayName -notmatch '^Update  for|rollup|^Security Update|^Service Pack|^HotFix') {
                                    $Date = $thisSubKey.GetValue('InstallDate')
                                    If ($Date) {
                                        Try {
                                            $Date = [datetime]::ParseExact($Date, 'yyyyMMdd', $Null)
                                        }
                                        Catch {
                                            Write-Warning "$($Computer): $_ <$($Date)>"
                                            $Date = $Null
                                        }
                                    } 
                                    # Create New Object with empty Properties 
                                    $Publisher = Try {
                                        $thisSubKey.GetValue('Publisher').Trim()
                                    } 
                                    Catch {
                                        $thisSubKey.GetValue('Publisher')
                                    }
                                    $Version = Try {
                                        #Some weirdness with trailing [char]0 on some strings
                                        $thisSubKey.GetValue('DisplayVersion').TrimEnd(([char[]](32, 0)))
                                    } 
                                    Catch {
                                        $thisSubKey.GetValue('DisplayVersion')
                                    }
                                    $UninstallString = Try {
                                        $thisSubKey.GetValue('UninstallString').Trim()
                                    } 
                                    Catch {
                                        $thisSubKey.GetValue('UninstallString')
                                    }
                                    $InstallLocation = Try {
                                        $thisSubKey.GetValue('InstallLocation').Trim()
                                    } 
                                    Catch {
                                        $thisSubKey.GetValue('InstallLocation')
                                    }
                                    $InstallSource = Try {
                                        $thisSubKey.GetValue('InstallSource').Trim()
                                    } 
                                    Catch {
                                        $thisSubKey.GetValue('InstallSource')
                                    }
                                    $HelpLink = Try {
                                        $thisSubKey.GetValue('HelpLink').Trim()
                                    } 
                                    Catch {
                                        $thisSubKey.GetValue('HelpLink')
                                    }
                                    $Object = [pscustomobject]@{
                                        Computername    = $Computer
                                        DisplayName     = $DisplayName
                                        Version         = $Version
                                        InstallDate     = $Date
                                        Publisher       = $Publisher
                                        UninstallString = $UninstallString
                                        InstallLocation = $InstallLocation
                                        InstallSource   = $InstallSource
                                        HelpLink        = $HelpLink
                                        EstimatedSizeMB = [decimal]([math]::Round(($thisSubKey.GetValue('EstimatedSize') * 1024) / 1MB, 2))
                                    }
                                    $Object.pstypenames.insert(0, 'System.Software.Inventory')
                                    Write-Output $Object
                                }
                            }
                            Catch {
                                Write-Warning "$Key : $_"
                            }   
                        }
                    }
                    Catch { }   
                    $reg.Close() 
                }                  
            }
            Else {
                Write-Error  "$($Computer): unable to reach remote system!"
            }
        } 
    } 
}

Function Write-Log {
    Param ([string]$logString)

    $logEntry = "$('[{0:MM/dd/yyyy} {0:HH:mm:ss}]' -f (Get-Date)) $logString"
    Write-Output $logEntry
    Write-Output $logEntry | Out-file $logFile -Append
}

Function Update-Package {
    Param(
        [String]$msi
    )

    # Extracting msi package name
    $msi -match "[^\\]+$" | Out-Null
    $logName = $Matches[0] -replace ".msi", ".log"

    $params = @(
        "/L*v"
        '"{0}\{1}"' -f $logFolder, $logName
        "/norestart"
        "/qn"
        "/i"
        '"{0}"' -f $msi
        'ACCEPTEULA="YES"'
        'ACCEPT_THIRDPARTY_LICENSES="1"'
    )
    return (Start-Process msiexec.exe -Wait -ArgumentList $params -Passthru).ExitCode
}

Function Update-Explorer {
    Param(
        [String]$msi
    )

    # Extracting msi package name
    $msi -match "[^\\]+$" | Out-Null
    $logName = $Matches[0] -replace ".msi", ".log" 

    $params = @(
        "/L*v"
        '"{0}\{1}"' -f $logFolder, $logName
        "/norestart"
        "/qn"
        "/i"
        '"{0}"' -f $msi
        'ACCEPT_EULA="1"'
        'ACCEPT_THIRDPARTY_LICENSES="1"'
    )
    return (Start-Process msiexec.exe -Wait -ArgumentList $params -Passthru).ExitCode
}
Function Update-VBR {
    Param(
        [String]$msi,
        [String]$license
    )

    $params = @(
        "/L*v"
        '"{0}\BackupServer.log"' -f $logFolder
        "/norestart"
        "/qn"
        "/i"
        '"{0}"' -f $msi
        'ACCEPTEULA="YES"'
        'ACCEPT_THIRDPARTY_LICENSES="1"'
        'VBR_LICENSE_FILE="{0}"' -f $license
        'VBR_AUTO_UPGRADE="YES"'
    )
    return (Start-Process msiexec.exe -Wait -ArgumentList $params -Passthru).ExitCode
}

Function Update-VEM {
    Param(
        [String]$msi,
        [String]$license
    )

    $params = @(
        "/L*v"
        '"{0}\EnterpriseManager.log"' -f $logFolder
        "/norestart"
        "/qn"
        "/i"
        '"{0}"' -f $msi
        'ACCEPTEULA="YES"'
        'ACCEPT_THIRDPARTY_LICENSES="1"'
        'VBREM_LICENSE_FILE="{0}"' -f $license
    )
    return (Start-Process msiexec.exe -Wait -ArgumentList $params -Passthru).ExitCode
}

Write-Log "INFO: Upgrade logs for this script can be found here: $logFile"

# Enforcing absolute paths
if ($iso -ne "download") {
    $iso = Resolve-Path $iso
}
if ($license) {
    $license = Resolve-Path $license
}

# Determining installed software
$vem = Get-Software | Where-Object { $_.DisplayName -eq "Veeam Backup Enterprise Manager" } | Select-Object DisplayName, Version
$vbr = Get-Software | Where-Object { $_.DisplayName -eq "Veeam Backup & Replication Server" } | Select-Object DisplayName, Version
if ((-not $vem) -and (-not $vbr)) {
    throw "At least 1 Veeam product must be installed on this server: Veeam Backup Enterprise Manager or Veeam Backup & Replication Server"
}
if ($vem) { Write-Log "Veeam Backup Enterprise Manager found: $($vem.Version)" }
if ($vbr) { Write-Log "Veeam Backup & Replication Server found: $($vbr.Version)" }
if (($vem.Version -eq "10.0.0.4461") -or ($vbr.Version -eq "10.0.0.4461")) {
    throw "Veeam environment has already been partially upgraded to version 10.0.0.4461. As such, you cannot use this script. You must perform a manual upgrade to proceed."
}

# If ISO wasn't specified, download it from Veeam's public servers
if ($iso -eq "download") {
    try {
        $iso = "$logFolder\VeeamBackup&Replication_10.0.0.4461.iso"
        Write-Log "ISO not specified. Checking if previously downloaded..."
        if (Test-Path $iso) {
            Write-Log "ISO found: $iso"
        }
        else {
            Write-Log "ISO not found. Downloading ISO now..."
            Start-BitsTransfer -Source "https://download2.veeam.com/VeeamBackup&Replication_10.0.0.4461.iso" -Destination $iso
            Write-Log "ISO downloaded to: $logFolder\VeeamBackup&Replication_10.0.0.4461.iso"
        }
        
    }
    catch {
        Write-Log $_
        throw "ISO download failed. Please check upgrade log for more information: $logFile"
    }
}

# Mounting ISO
try {
    Write-Log "Mounting ISO in Operating System"
    $mount = Mount-DiskImage -ImagePath $iso
    $mountDrive = ($mount | Get-Volume).DriveLetter + ":"
}
catch {
    Write-Log $_
    throw "ISO mount failed. Please check upgrade log for more information: $logFile"
}

### VBR PRE-UPGRADE ACTIONS
if ($vbr) {
    try {        
        # Registering VeeamPSSnapin if necessary
        Write-Log "Registering VeeamPSSnapin if necessary"
        $registered = $false
        foreach ($snapin in (Get-PSSnapin)) {
            if ($snapin.Name -eq "veeampssnapin") { $registered = $true }
        }
        if ($registered -eq $false) { Add-PSSnapin veeampssnapin }
    
        try {
            # Checking for Cloud Connect environment
            $state = Get-VBRCloudInfrastructureState
            Write-Log "Cloud Connect instance found. Determining infrastructure state..."
            $vcc = $true
            if ($state -eq "Active") {
                Write-Log "ACTIVE: Enabling maintenance mode and waiting for all active sessions to complete"
                Enable-VBRCloudMaintenanceMode
            }
            else {
                Write-Log "MAINTENANCE: Maintenance mode already enabled. Currently waiting for all active sessions to complete"
            }
            $sw = [System.Diagnostics.Stopwatch]::StartNew()  #stopwatch
            # Forever loop until Cloud Connect active sessions complete or manual user interrupt
            while ($true) {
                $sessions = ([Veeam.Backup.Core.CCloudSession]::GetAll() | Where-Object { $_.JobName -ne "Console" } | Where-Object { $_.State -eq "Working" }).Count
                if ($sessions -eq 0) {
                    Write-Log "All active sessions have gracefully ended. Total time waiting: $([int]$sw.Elapsed.TotalMinutes) minutes"
                    $sw.Stop()
                    break
                }
                Clear-Host
                Write-Host "Still waiting for $sessions active sessions to complete after $([int]$sw.Elapsed.TotalMinutes) minutes..."
                Write-Host "To interrupt the wait and forcefully close active sessions, press (I)"
                # Allows manual escape from loop
                if ($host.UI.RawUI.KeyAvailable) {
                    $key = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyUp,IncludeKeyDown")
                    if ("i" -like $key.Character) {
                        Write-Log "Manual interrupt received, proceeding with upgrade. $sessions active sessions will be forcefully closed."
                        $sw.Stop()
                        break
                    }
                }
                Start-Sleep -Seconds 5
            }

            # Performing Configuration Backup prior to upgrade
            Write-Log "Performing Configuration Backup prior to upgrade"
            Start-VBRConfigurationBackupJob
        }
        catch {
            $vcc = $false

            # Performing Configuration Backup prior to upgrade
            Write-Log "Performing Configuration Backup prior to upgrade"
            Start-VBRConfigurationBackupJob

            # Stopping all running Backup Jobs
            Write-Log "Stopping all running Backup Jobs"
            Get-VBRJob | Where-Object { $_.GetLastState() -eq 'Working' } | Stop-VBRJob
        
            # Setting Disabled Jobs csv - using unique name to make sure this file is never overwritten
            $csv = "$logFolder\DisabledJobs$([int](New-TimeSpan -Start (Get-Date "01/01/1970") -End (Get-Date)).TotalSeconds).csv"
            
            # Backing up scheduled Backup Jobs and disabling
            Write-Log "Backing up scheduled Backup Jobs and disabling"
            Get-VBRJob | Where-Object { $_.IsScheduleEnabled -eq $True } | Select-Object Name | Export-Csv $csv 
            Import-Csv $csv | Disable-VBRJob -Job { $_.Name }
        }
    }
    catch {
        Write-Log "One of the pre-upgrade actions failed. Please investigate and resolve. Logs can be found here: $logFile"
        Write-Log "Unmounting Veeam ISO"
        $mount | Dismount-DiskImage | Out-Null
        throw "ERROR: Upgrade halted. Please check logs for more information."
    }
}
### END VBR PRE-UPGRADE ACTIONS

# Beginning VEM upgrade
if ($vem) {
    # Closing open Console sessions
    Write-Log "Closing open Console sessions"
    Stop-Process -Name "Veeam.Backup.Shell" -Force -ErrorAction SilentlyContinue

    # Stopping all Veeam services prior to upgrade
    Write-Log "Stopping all Veeam services"
    Get-Service veeam* | Stop-Service

    try {
        # Upgrading Veeam Backup Catalog
        Write-Log "Upgrading Veeam Backup Catalog: $mountDrive\Catalog\VeeamBackupCatalog64.msi"
        $result = Update-Package -msi "$mountDrive\Catalog\VeeamBackupCatalog64.msi"
        if ($result -eq 0) { Write-Log "SUCCESS: ${result}" }
        else { throw "ERROR: ${result}" }
    }
    catch {
        Write-Log $_
        Write-Log "Unmounting Veeam ISO"
        $mount | Dismount-DiskImage | Out-Null
        throw "Upgrade failed. Please check debug log for more information: $logFolder\VeeamBackupCatalog64.log"
    }
    
    try {
        # Upgrading Veeam Backup Enterprise Manager
        Write-Log "Upgrading Veeam Backup Enterprise Manager: $mountDrive\EnterpriseManager\BackupWeb_x64.msi"
        $result = Update-VEM -msi "$mountDrive\EnterpriseManager\BackupWeb_x64.msi" -license $license
        if ($result -eq 0) { Write-Log "SUCCESS: ${result}" }
        else { throw "ERROR: ${result}" }
    }
    catch {
        Write-Log $_
        Write-Log "Unmounting Veeam ISO"
        $mount | Dismount-DiskImage | Out-Null
        throw "Upgrade failed. Please check debug log for more information: $logFolder\EnterpriseManager.log"
    }

    # Is Veeam Cloud Connect Portal installed?
    if (Get-Software | Where-Object { $_.DisplayName -eq "Veeam Cloud Connect Portal" }) {
        try {
            # Upgrading Veeam Cloud Connect Portal
            Write-Log "Upgrading Veeam Cloud Connect Portal: $mountDrive\Cloud Portal\BackupCloudPortal_x64.msi"
            $result = Update-Package -msi "$mountDrive\Cloud Portal\BackupCloudPortal_x64.msi"
            if ($result -eq 0) { Write-Log "SUCCESS: ${result}" }
            else { throw "ERROR: ${result}" }
        }
        catch {
            Write-Log $_
            Write-Log "Unmounting Veeam ISO"
            $mount | Dismount-DiskImage | Out-Null
            throw "Upgrade failed. Please check debug log for more information: $logFolder\BackupCloudPortal_x64.log"
        }
    }

    Write-Log "Veeam Backup Enterprise Manager has been successfully upgraded"
} # End VBR upgrade

# Beginning VBR upgrade
if ($vbr) {
    # Closing open Console sessions
    Write-Log "Closing open Console sessions"
    Stop-Process -Name "Veeam.Backup.Shell" -Force -ErrorAction SilentlyContinue

    # Stopping all Veeam services prior to upgrade
    Write-Log "Stopping all Veeam services"
    Get-Service veeam* | Stop-Service
    
    try {
        # Upgrading Veeam Backup Catalog
        Write-Log "Upgrading Veeam Backup Catalog: $mountDrive\Catalog\VeeamBackupCatalog64.msi"
        $result = Update-Package -msi "$mountDrive\Catalog\VeeamBackupCatalog64.msi"
        if ($result -eq 0) { Write-Log "SUCCESS: ${result}" }
        else { throw "ERROR: ${result}" }
    }
    catch {
        Write-Log $_
        Write-Log "Unmounting Veeam ISO"
        $mount | Dismount-DiskImage | Out-Null
        throw "Upgrade failed. Please check debug log for more information: $logFolder\VeeamBackupCatalog64.log"
    }
    
    try {
        # Upgrading Veeam Backup & Replication Server
        Write-Log "Upgrading Veeam Backup & Replication Server: $mountDrive\Backup\Server.x64.msi"
        $result = Update-VBR  -msi "$mountDrive\Backup\Server.x64.msi" -license $license
        if ($result -eq 0) { Write-Log "SUCCESS: ${result}" }
        else { throw "ERROR: ${result}" }
    }
    catch {
        Write-Log $_
        Write-Log "Unmounting Veeam ISO"
        $mount | Dismount-DiskImage | Out-Null
        throw "Upgrade failed. Please check debug log for more information: $logFolder\BackupServer.log"
    }
    
    Write-Log "Stopping all Veeam services. This may take a while as all Veeam Proxies & Repositories are currently being upgraded."
    Get-Service veeam* | Stop-Service
    
    try {
        # Upgrading Veeam Backup & Replication Console
        Write-Log "Upgrading Veeam Backup & Replication Console: $mountDrive\Backup\Shell.x64.msi"
        $result = Update-Package -msi "$mountDrive\Backup\Shell.x64.msi"
        if ($result -eq 0) { Write-Log "SUCCESS: ${result}" }
        else { throw "ERROR: ${result}" }
    }
    catch {
        Write-Log $_
        Write-Log "Unmounting Veeam ISO"
        $mount | Dismount-DiskImage | Out-Null
        throw "Upgrade failed. Please check debug log for more information: $logFolder\Shell.x64.log"
    }
    
    try {
        # Upgrading Veeam Explorer for Microsoft Active Directory
        Write-Log "Upgrading Veeam Explorer for Microsoft Active Directory: $mountDrive\Explorers\VeeamExplorerForActiveDirectory.msi"
        $result = Update-Explorer -msi "$mountDrive\Explorers\VeeamExplorerForActiveDirectory.msi"
        if ($result -eq 0) { Write-Log "SUCCESS: ${result}" }
        else { throw "ERROR: ${result}" }
    }
    catch {
        Write-Log $_
        Write-Log "Unmounting Veeam ISO"
        $mount | Dismount-DiskImage | Out-Null
        throw "Upgrade failed. Please check debug log for more information: $logFolder\VeeamExplorerForActiveDirectory.log"
    }
    
    try {
        # Upgrading Veeam Explorer for Microsoft Exchange
        Write-Log "Upgrading Veeam Explorer for Microsoft Exchange: $mountDrive\Explorers\VeeamExplorerForExchange.msi"
        $result = Update-Explorer -msi "$mountDrive\Explorers\VeeamExplorerForExchange.msi"
        if ($result -eq 0) { Write-Log "SUCCESS: ${result}" }
        else { throw "ERROR: ${result}" }
    }
    catch {
        Write-Log $_
        Write-Log "Unmounting Veeam ISO"
        $mount | Dismount-DiskImage | Out-Null
        throw "Upgrade failed. Please check debug log for more information: $logFolder\VeeamExplorerForExchange.log"
    }
    
    try {
        # Upgrading Veeam Explorer for Microsoft SharePoint
        Write-Log "Upgrading Veeam Explorer for Microsoft SharePoint: $mountDrive\Explorers\VeeamExplorerForSharePoint.msi"
        $result = Update-Explorer -msi "$mountDrive\Explorers\VeeamExplorerForSharePoint.msi"
        if ($result -eq 0) { Write-Log "SUCCESS: ${result}" }
        else { throw "ERROR: ${result}" }
    }
    catch {
        Write-Log $_
        Write-Log "Unmounting Veeam ISO"
        $mount | Dismount-DiskImage | Out-Null
        throw "Upgrade failed. Please check debug log for more information: $logFolder\VeeamExplorerForSharePoint.log"
    }
    
    try {
        # Upgrading Veeam Explorer for Microsoft SQL Server
        Write-Log "Upgrading Veeam Explorer for Microsoft SQL Server: $mountDrive\Explorers\VeeamExplorerForSQL.msi"
        $result = Update-Explorer -msi "$mountDrive\Explorers\VeeamExplorerForSQL.msi"
        if ($result -eq 0) { Write-Log "SUCCESS: ${result}" }
        else { throw "ERROR: ${result}" }
    }
    catch {
        Write-Log $_
        Write-Log "Unmounting Veeam ISO"
        $mount | Dismount-DiskImage | Out-Null
        throw "Upgrade failed. Please check debug log for more information: $logFolder\VeeamExplorerForSQL.log"
    }
    
    try {
        # Upgrading Veeam Explorer for Oracle
        Write-Log "Upgrading Veeam Explorer for Oracle: $mountDrive\Explorers\VeeamExplorerForOracle.msi"
        $result = Update-Explorer -msi "$mountDrive\Explorers\VeeamExplorerForOracle.msi"
        if ($result -eq 0) { Write-Log "SUCCESS: ${result}" }
        else { throw "ERROR: ${result}" }
    }
    catch {
        Write-Log $_
        Write-Log "Unmounting Veeam ISO"
        $mount | Dismount-DiskImage | Out-Null
        throw "Upgrade failed. Please check debug log for more information: $logFolder\VeeamExplorerForOracle.log"
    }
    
    try {
        # Upgrading Veeam Distribution Service
        Write-Log "Upgrading Veeam Distribution Service: $mountDrive\Packages\VeeamDistributionSvc.msi"
        $result = Update-Package -msi "$mountDrive\Packages\VeeamDistributionSvc.msi"
        if ($result -eq 0) { Write-Log "SUCCESS: ${result}" }
        else { throw "ERROR: ${result}" }
    }
    catch {
        Write-Log $_
        Write-Log "Unmounting Veeam ISO"
        $mount | Dismount-DiskImage | Out-Null
        throw "Upgrade failed. Please check debug log for more information: $logFolder\VeeamDistributionSvc.log"
    }
    
    try {
        # Upgrading Veeam Installer Service
        Write-Log "Upgrading Veeam Installer Service: $mountDrive\Packages\VeeamInstallerSvc.msi"
        $result = Update-Package -msi "$mountDrive\Packages\VeeamInstallerSvc.msi"
        if ($result -eq 0) { Write-Log "SUCCESS: ${result}" }
        else { throw "ERROR: ${result}" }
    }
    catch {
        Write-Log $_
        Write-Log "Unmounting Veeam ISO"
        $mount | Dismount-DiskImage | Out-Null
        throw "Upgrade failed. Please check debug log for more information: $logFolder\VeeamInstallerSvc.log"
    }
    
    try {
        # Upgrading Veeam Agent for Linux Redistributable
        Write-Log "Upgrading Veeam Agent for Linux Redistributable: $mountDrive\Packages\VALRedist.msi"
        $result = Update-Package -msi "$mountDrive\Packages\VALRedist.msi"
        if ($result -eq 0) { Write-Log "SUCCESS: ${result}" }
        else { throw "ERROR: ${result}" }
    }
    catch {
        Write-Log $_
        Write-Log "Unmounting Veeam ISO"
        $mount | Dismount-DiskImage | Out-Null
        throw "Upgrade failed. Please check debug log for more information: $logFolder\VALRedist.log"
    }
    
    try {
        # Upgrading Veeam Agent for Microsoft Windows Redistributable
        Write-Log "Upgrading Veeam Agent for Microsoft Windows Redistributable: $mountDrive\Packages\VAWRedist.msi"
        $result = Update-Package -msi "$mountDrive\Packages\VAWRedist.msi"
        if ($result -eq 0) { Write-Log "SUCCESS: ${result}" }
        else { throw "ERROR: ${result}" }
    }
    catch {
        Write-Log $_
        Write-Log "Unmounting Veeam ISO"
        $mount | Dismount-DiskImage | Out-Null
        throw "Upgrade failed. Please check debug log for more information: $logFolder\VAWRedist.log"
    }
    
    try {
        # Upgrading Veeam Mount Service
        Write-Log "Upgrading Veeam Mount Service: $mountDrive\Packages\VeeamMountService.msi"
        $result = Update-Package -msi "$mountDrive\Packages\VeeamMountService.msi"
        if ($result -eq 0) { Write-Log "SUCCESS: ${result}" }
        else { throw "ERROR: ${result}" }
    }
    catch {
        Write-Log $_
        Write-Log "Unmounting Veeam ISO"
        $mount | Dismount-DiskImage | Out-Null
        throw "Upgrade failed. Please check debug log for more information: $logFolder\VeeamMountService.log"
    }
    
    try {
        # Upgrading Veeam Backup Transport
        Write-Log "Upgrading Veeam Backup Transport: $mountDrive\Packages\VeeamTransport.msi"
        $result = Update-Package -msi "$mountDrive\Packages\VeeamTransport.msi"
        if ($result -eq 0) { Write-Log "SUCCESS: ${result}" }
        else { throw "ERROR: ${result}" }
    }
    catch {
        Write-Log $_
        Write-Log "Unmounting Veeam ISO"
        $mount | Dismount-DiskImage | Out-Null
        throw "Upgrade failed. Please check debug log for more information: $logFolder\VeeamTransport.log"
    }
    
    try {
        # Upgrading Veeam Backup vPowerNFS
        Write-Log "Upgrading Veeam Backup vPowerNFS: $mountDrive\Packages\vPowerNFS.msi"
        $result = Update-Package -msi "$mountDrive\Packages\vPowerNFS.msi"
        if ($result -eq 0) { Write-Log "SUCCESS: ${result}" }
        else { throw "ERROR: ${result}" }
    }
    catch {
        Write-Log $_
        Write-Log "Unmounting Veeam ISO"
        $mount | Dismount-DiskImage | Out-Null
        throw "Upgrade failed. Please check debug log for more information: $logFolder\vPowerNFS.log"
    }

    # Is Veeam Backup Cloud Gateway installed?
    if (Get-Software | Where-Object { $_.DisplayName -eq "Veeam Backup Cloud Gateway" }) {
        try {
            # Upgrading Veeam Backup Cloud Gateway
            Write-Log "Upgrading Veeam Backup Cloud Gateway: $mountDrive\Packages\VeeamGateSvc.msi"
            $result = Update-Package -msi "$mountDrive\Packages\VeeamGateSvc.msi" -license $license
            if ($result -eq 0) { Write-Log "SUCCESS: ${result}" }
            else { throw "ERROR: ${result}" }
        }
        catch {
            Write-Log $_
            Write-Log "Unmounting Veeam ISO"
            $mount | Dismount-DiskImage | Out-Null
            throw "Upgrade failed. Please check debug log for more information: $logFolder\VeeamGateSvc.log"
        }
    }
    
    Write-Log "Veeam Backup & Replication environment has been successfully upgraded"

    ### POST-UPGRADE ACTIONS
    try {
        Write-Log "Starting all Veeam services"
        Get-Service veeam* | Start-Service
        
        if ($vcc) {
            Write-Log "Disabling Cloud Connect Maintenance Mode"
            powershell.exe -NoLogo -ExecutionPolicy bypass -NoProfile -Command "Add-PSSnapin VeeamPSSnapin; Disable-VBRCloudMaintenanceMode"
        }
        else {
            # Cloud Connect environment does not exist
            Write-Log "Enabling previously disabled Backup Jobs"
            foreach ($job in (Import-Csv $csv).Name) {
                #creating another PS session so the latest Veeam cmdlets are used
                powershell.exe -NoLogo -ExecutionPolicy bypass -NoProfile -Command "Add-PSSnapin VeeamPSSnapin; Enable-VBRJob -Job '${job}'"
            }
            Write-Log "Shutting down Veeam prior to reboot"
            powershell.exe -NoLogo -ExecutionPolicy bypass -NoProfile -Command 'Add-PSSnapin VeeamPSSnapin; Get-VBRJob | Stop-VBRJob'
        }

        # Stopping Veeam services prior to reboot
        Get-Service veeam* | Stop-Service
    }
    catch {
        Write-Log $_
        Write-Log "One of the post-upgrade actions failed. Please investigate and resolve. Logs can be found here: $logFile"
        Write-Log "Unmounting Veeam ISO"
        $mount | Dismount-DiskImage | Out-Null
        throw "ERROR: Post-upgrade actions failed. Please check logs for more information."
    }
    ### END POST-UPGRADE ACTIONS
} # End VBR upgrade

Write-Log "Unmounting Veeam ISO"
$mount | Dismount-DiskImage | Out-Null
Write-Log "Script has completed successfully. Please reboot this server prior to using Veeam."
Write-Host "This can be done easily in PowerShell as well: Restart-Computer -Force"
return 0
