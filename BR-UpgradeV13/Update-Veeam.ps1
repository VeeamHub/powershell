<#
.SYNOPSIS
	Upgrades Veeam Environment to v13

.DESCRIPTION
    This script will upgrade Veeam Backup Enterprise Manager and/or
    Veeam Backup & Replication Server depending on what's installed. The script
    is designed to be executed on the server to be upgraded. It's also
    possible to execute the script from a remote PowerShell session.

.PARAMETER ISO
	Location of Veeam ISO containing upgrade files. If not specified, script will attempt to download the ISO from Veeam's public servers.

.PARAMETER License
	Veeam License key file

.PARAMETER ServicePassword
	Password for the account under which the Veeam Backup Service will run (only required if LocalSystem account is not used)

.PARAMETER EntraIDDatabaseInstall
    Boolean to determine if you want to install bundled PostgreSQL server for Microsoft EntraID

.PARAMETER LicenseAutoupdate
	Boolean to determine if you want to update license automatically

.PARAMETER ProactiveSupport
    Boolean to determine if you want to receive proactive support (enables diagnostic data sharing). For Community Edition, NFR and Evaluation licenses it must be set to $true. For licenses without license ID information it must be set to $false.

.PARAMETER AutoUpgrade
	Boolean to automatically upgrade existing components in the backup infrastructure

.OUTPUTS
	Update-Veeam.ps1 returns exit code of 0 upon success

.EXAMPLE
	Update-Veeam.ps1 -License "C:\license.lic"

	Description
	-----------
	Upgrades Veeam environment using the specified license file and downloads the Veeam 13 ISO from Veeam's public servers

.EXAMPLE
	Update-Veeam.ps1 -ISO "C:\VeeamBackup&Replication_13.0.1.180_20251114.iso" -License "C:\license.lic"

	Description
	-----------
	Upgrades Veeam environment using the specified license file and uses the specified local ISO

.NOTES
	NAME:  Update-Veeam.ps1
	VERSION: 1.0
	AUTHOR: Chris Arceneaux
	TWITTER: @chris_arceneaux
	GITHUB: https://github.com/carceneaux

.LINK
    https://helpcenter.veeam.com/docs/vbr/userguide/upgrade_vbr_byb.html?ver=13

.LINK
    https://helpcenter.veeam.com/docs/vbr/userguide/upgrade_vbr_answer_file.html?ver=13

.LINK
    https://helpcenter.veeam.com/docs/vbr/em/em_silent_upgrade.html?ver=13

#>
#Requires -RunAsAdministrator
[CmdletBinding(DefaultParametersetName = "None")]
param(
    [Parameter(Mandatory = $false)]
    [String] $ISO = "download",
    [Parameter(Mandatory = $false)]
    [String] $License,
    [Parameter(Mandatory = $false)]
    [String] $ServicePassword,
    [Parameter(Mandatory = $false)]
    [bool] $EntraIDDatabaseInstall = $true,
    [Parameter(Mandatory = $false)]
    [bool] $LicenseAutoupdate = $true,
    [Parameter(Mandatory = $false)]
    [bool] $ProactiveSupport = $true,
    [Parameter(Mandatory = $false)]
    [bool] $AutoUpgrade = $true
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

Function Test-PendingReboot {
    # Sourced from https://www.powershellgallery.com/packages/PendingReboot/0.9.0.6
    [CmdletBinding()]
    param(
        [Parameter(Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias("CN", "Computer")]
        [String]
        $ComputerName = $env:COMPUTERNAME
    )

    process {
        try {
            $invokeWmiMethodParameters = @{
                Namespace    = 'root/default'
                Class        = 'StdRegProv'
                Name         = 'EnumKey'
                ComputerName = $ComputerName
                ErrorAction  = 'Stop'
            }

            $hklm = [UInt32] "0x80000002"

            ## Query the Component Based Servicing Reg Key
            $invokeWmiMethodParameters.ArgumentList = @($hklm, 'SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\')
            $registryComponentBasedServicing = (Invoke-WmiMethod @invokeWmiMethodParameters).sNames -contains 'RebootPending'

            ## Query WUAU from the registry
            $invokeWmiMethodParameters.ArgumentList = @($hklm, 'SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\')
            $registryWindowsUpdateAutoUpdate = (Invoke-WmiMethod @invokeWmiMethodParameters).sNames -contains 'RebootRequired'

            ## Query JoinDomain key from the registry - These keys are present if pending a reboot from a domain join operation
            $invokeWmiMethodParameters.ArgumentList = @($hklm, 'SYSTEM\CurrentControlSet\Services\Netlogon')
            $registryNetlogon = (Invoke-WmiMethod @invokeWmiMethodParameters).sNames
            $pendingDomainJoin = ($registryNetlogon -contains 'JoinDomain') -or ($registryNetlogon -contains 'AvoidSpnSet')

            ## Query ComputerName and ActiveComputerName from the registry and setting the MethodName to GetMultiStringValue
            $invokeWmiMethodParameters.Name = 'GetMultiStringValue'
            $invokeWmiMethodParameters.ArgumentList = @($hklm, 'SYSTEM\CurrentControlSet\Control\ComputerName\ActiveComputerName\', 'ComputerName')
            $registryActiveComputerName = Invoke-WmiMethod @invokeWmiMethodParameters

            $invokeWmiMethodParameters.ArgumentList = @($hklm, 'SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName\', 'ComputerName')
            $registryComputerName = Invoke-WmiMethod @invokeWmiMethodParameters

            $pendingComputerRename = $registryActiveComputerName -ne $registryComputerName -or $pendingDomainJoin

            ## Query PendingFileRenameOperations from the registry
            $invokeWmiMethodParameters.ArgumentList = @($hklm, 'SYSTEM\CurrentControlSet\Control\Session Manager\', 'PendingFileRenameOperations')
            $registryPendingFileRenameOperations = (Invoke-WmiMethod @invokeWmiMethodParameters).sValue
            $registryPendingFileRenameOperationsBool = [bool]$registryPendingFileRenameOperations

            $isRebootPending = $registryComponentBasedServicing -or `
                $pendingComputerRename -or `
                $pendingDomainJoin -or `
                $registryPendingFileRenameOperationsBool -or `
                $systemCenterConfigManager -or `
                $registryWindowsUpdateAutoUpdate

            return $isRebootPending
        }

        catch {
            Write-Warning "$Computer`: $_"
        }

    }
}

Function Write-Log {
    Param ([string]$logString)

    $logEntry = "$('[{0:MM/dd/yyyy} {0:HH:mm:ss}]' -f (Get-Date)) $logString"
    Write-Output $logEntry
    Write-Output $logEntry | Out-file $logFile -Append
}

Function Update-Veeam {
    Param(
        [String]$SilentInstallExe,
        [String]$Answer,
        [String]$Logs
    )

    $params = @(
        "/AnswerFile"
        '"{0}"' -f $Answer
        "/SkipNetworkLogonErrors"
        "/LogFolder"
        '"{0}"' -f $Logs
    )
    return (Start-Process "$SilentInstallExe" -Wait -ArgumentList $params -Passthru).ExitCode
}

Write-Log "INFO: Upgrade logs for this script can be found here: $logFile"

# Pending reboot check
if (Test-PendingReboot) {
    throw "This Windows server requires a reboot prior to beginning the Veeam Backup & Replication upgrade. After rebooting this server, you can proceed with the upgrade."
}

# Enforcing absolute paths
if ($iso -ne "download") {
    $iso = Resolve-Path $iso
}
if ($license) {
    $license = Resolve-Path $license
}

# Determining installed software
$vbem = Get-Software | Where-Object { $_.DisplayName -eq "Veeam Backup Enterprise Manager" } | Select-Object DisplayName, Version
$vbr = Get-Software | Where-Object { $_.DisplayName -eq "Veeam Backup & Replication Server" } | Select-Object DisplayName, Version
if ((-not $vbem) -and (-not $vbr)) {
    throw "At least 1 Veeam product must be installed on this server: Veeam Backup Enterprise Manager or Veeam Backup & Replication Server"
}
if ($vbem) { Write-Log "Veeam Backup Enterprise Manager found: $($vbem.Version)" }
if ($vbr) { Write-Log "Veeam Backup & Replication Server found: $($vbr.Version)" }

# Checking for license if Enteprise Manager is installed
if ($vbem -and ($license.Length -eq 0)) {
    throw "The License parameter MUST be used when upgrading Veeam Backup Enterprise Manager. Please correct and re-run this script."
}

# If ISO wasn't specified, download it from Veeam's public servers
if ($iso -eq "download") {
    try {
        $iso = "$logFolder\VeeamBackup&Replication_13.0.1.180_20251114.iso"
        Write-Log "ISO not specified. Checking if previously downloaded..."
        if (Test-Path $iso) {
            Write-Log "ISO found: $iso"
        }
        else {
            Write-Log "ISO not found. Downloading ISO now..."
            Start-BitsTransfer -Source "https://download2.veeam.com/VBR/v13/VeeamBackup&Replication_13.0.1.180_20251114.iso" -Destination $iso
            Write-Log "ISO downloaded to: $iso"
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
    Mount-DiskImage -ImagePath $iso | Out-Null
    $mountDrive = (Get-Volume | Where-Object { $_.FileSystemLabel -like "VEEAM BACKUP" }).DriveLetter + ":"
}
catch {
    Write-Log $_
    throw "ISO mount failed. Please check upgrade log for more information: $logFile"
}

# Validating ISO major version
$fileInfo = Get-Content "$mountDrive\autorun.inf"
if ($fileInfo -match "13") {
    Write-Log "ISO validated for version 13"
}
else {
    Write-Log "ISO failed validation! Non-v13 ISO detected."
    Write-Log "Unmounting Veeam ISO"
    Dismount-DiskImage -ImagePath $iso
    throw "Incorrect ISO detected! This script was designed to work with a Veeam Backup & Replication v13 ISO. Please correct and re-run this script."
}

# Validating 13 ISO
try {
    # Identifying Silent Install EXE
    $file = Get-ChildItem -Recurse -Filter "Veeam.Silent.Install.exe" -File -Path $mountDrive
    $exe = $file.FullName

    if ("1.0.0" -eq $file.VersionInfo.ProductVersion) {
        Write-Log "ISO failed validation! Non-v13 ISO detected."
        Write-Log "Unmounting Veeam ISO"
        Dismount-DiskImage -ImagePath $iso
        throw
    }

    Write-Log "ISO validated as version 13"
}
catch {
    Write-Log $_
    Write-Log "Unable to validate ISO. Please investigate and resolve. Logs can be found here: $logFile"
    Write-Log "Unmounting Veeam ISO"
    Dismount-DiskImage -ImagePath $iso
    throw "Incorrect ISO detected! This script was designed to work with a Veeam Backup & Replication v13 ISO. Please correct and re-run this script."
}

### VBR PRE-UPGRADE ACTIONS
if ($vbr) {
    try {
        # Registering VeeamPSSnapin if necessary
        Write-Log "Registering VeeamPSSnapin if necessary"
        if (-Not (Get-Module -ListAvailable -Name Veeam.Backup.PowerShell)) {
            Add-PSSnapin -PassThru VeeamPSSnapIn -ErrorAction Stop | Out-Null
        }

        try {
            # Checking for Cloud Connect environment
            $state = Get-VBRCloudInfrastructureState # returns error not Cloud Connect
            Write-Log "Cloud Connect instance found. Determining infrastructure state..."

            # Pre-upgrade actions for Cloud Connect environment
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
            # Pre-upgrade actions for Veeam Backup & Replication environment (no Cloud Connect)
            $vcc = $false

            # Performing Configuration Backup prior to upgrade
            Write-Log "Performing Configuration Backup prior to upgrade"
            Start-VBRConfigurationBackupJob
        }
    }
    catch {
        Write-Log "One of the pre-upgrade actions failed. Please investigate and resolve. Logs can be found here: $logFile"
        Write-Log "Unmounting Veeam ISO"
        Dismount-DiskImage -ImagePath $iso
        throw "ERROR: Upgrade halted. Please check logs for more information."
    }
}
### END VBR PRE-UPGRADE ACTIONS

### VBEM UPGRADE
if ($vbem) {
    # Closing open Console sessions
    Write-Log "Closing open Console sessions"
    Stop-Process -Name "Veeam.Backup.Shell" -Force -ErrorAction SilentlyContinue

    # Stopping all Veeam services prior to upgrade
    Write-Log "Stopping all Veeam services"
    Get-Service veeam* | Stop-Service

    try {
        # Generate upgrade answer file
        $answerFile = "$logFolder\EmAnswerFile_upgrade.xml"

        Write-Log "Checking if Enterprise Manager answer file already exists..."
        if (Test-Path $answerFile) {
            Write-Log "Answer file: $answerFile"
        }
        else {
            Write-Log "Answer file not found. Generating file now..."
            Add-Content $answerFile @"
<?xml version="1.0" encoding="utf-8"?>
<unattendedInstallationConfiguration bundle="Em" mode="upgrade" version="1.0">
<!--[Required] Parameter 'mode' defines installation mode that silent install should operate in-->
<!--Supported values: install/upgrade/uninstall-->

<!--Note: unused [Optional] parameters should be removed from the answer file-->

    <properties>

        <!--License agreements-->
        <!--Specify parameters to accept all the license agreements during silent installation or upgrade-->

            <!--[Required] Parameter ACCEPT_EULA specifies if you want to accept the Veeam license agreement. Specify '1' to accept the license agreement and proceed with installation or upgrade-->
                <!--Supported values: 0/1-->
                <property name="ACCEPT_EULA" value="1" />

            <!--[Required] Parameter ACCEPT_LICENSING_POLICY specifies if you want to accept Veeam licensing policy. Specify '1' to accept the licensing policy and proceed with installation or upgrade-->
                <!--Supported values: 0/1-->
                <property name="ACCEPT_LICENSING_POLICY" value="1" />

            <!--[Required] Parameter ACCEPT_THIRDPARTY_LICENSES specifies if you want to accept all the 3rd party licenses used. Specify '1' to accept the license agreements and proceed with installation or upgrade-->
                <!--Supported values: 0/1-->
                <property name="ACCEPT_THIRDPARTY_LICENSES" value="1" />

            <!--[Required] Parameter ACCEPT_REQUIRED_SOFTWARE specifies if you want to accept all the required software licenses. Specify '1' to accept the license agreements and proceed with installation or upgrade-->
                <!--Supported values: 0/1-->
                <property name="ACCEPT_REQUIRED_SOFTWARE" value="1" />

        <!--License file-->
        <!--Specify path to a license file and autoupdate option-->

            <!--[Required] Parameter VBREM_LICENSE_FILE specifies a full path to the license file. If you do not specify this parameter, Veeam Backup & Replication will be installed in the Community Edition mode or upgraded using current license file-->
                <!--Supported values: file path-->
                <property name="VBREM_LICENSE_FILE" value="$($License)" />

            <!--[Optional] Parameter VBREM_LICENSE_AUTOUPDATE specifies if you want to update license automatically. If you do not specify this parameter, autoupdate will be enabled. For NFR and Evaluation licenses it must be set to 1. For licenses without license ID information it must be set to 0-->
                <!--Supported values: 0/1-->
                $(if ($LicenseAutoupdate){
                    '<property name="VBREM_LICENSE_AUTOUPDATE" value="1" />'
                } else {
                    '<property name="VBREM_LICENSE_AUTOUPDATE" value="0" />'
                })

            <!--  [Optional] Parameter VBREM_PROACTIVE_SUPPORT specifies if you want to receive proactive support (enables diagnostic data sharing). If you do not specify this parameter, proactive support will be enabled. For Community Edition, NFR and Evaluation licenses it must be set to 1. For licenses without license ID information it must be set to 0 -->
				<!--  Supported values: 0/1  -->
				$(if ($ProactiveSupport){
                    '<property name="VBREM_PROACTIVE_SUPPORT" value="1" />'
                } else {
                    '<property name="VBREM_PROACTIVE_SUPPORT" value="0" />'
                })

        <!--Service account-->

            <!--[Optional] Parameter VBREM_SERVICE_PASSWORD specifies a password for the account under which the Veeam Backup Enterprise Manager Service will run. You must specify this parameter together with VBREM_SERVICE_USER parameter during installation. Required during upgrade if service account is not LocalSystem account-->
            <!--Make sure you keep the answer file in a safe location whenever service account password is added to the answer file-->
                <!--Supported values: password in plain text-->
                $(if ($ServicePassword){
                    '<property name="VBREM_SERVICE_PASSWORD" value="' + $ServicePassword + '" hidden="1"/>'
                })

        <!--Setup settings-->
        <!--Specify additional setup settings-->

            <!--[Optional] Parameter REBOOT_IF_REQUIRED forces target server reboot, whenever it is required. If you do not specify this parameter, reboot is not performed automatically. Keep in mind that setup procedure will not be restarted after reboot-->
                <!--Supported values: 0/1-->
                <property name="REBOOT_IF_REQUIRED" value="0" />

    </properties>
</unattendedInstallationConfiguration>
"@
        }
    }
    catch {
        Write-Log $_
        Write-Log "Answer file generation failed. Please investigate and resolve. Logs can be found here: $logFile"
        Write-Log "Unmounting Veeam ISO"
        Dismount-DiskImage -ImagePath $iso
        throw "ERROR: Answer file generation failed. Please check logs for more information."
    }

    try {
        # Upgrading Veeam Backup Enterprise Manager
        Write-Log "Upgrading Veeam Backup Enterprise Manager using answer file: $answerFile"
        $result = Update-Veeam -SilentInstallExe $exe -Answer $answerFile -Logs $logFolder
        if ($result -eq 0 -or $result -eq 3010 -or $result -eq 3011) { Write-Log "SUCCESS: ${result}" }
        else { throw "ERROR: ${result}" }
    }
    catch {
        Write-Log $_
        Write-Log "Unmounting Veeam ISO"
        Dismount-DiskImage -ImagePath $iso
        throw "Upgrade failed. Please check debug log for more information: $logFolder\EnterpriseManager.log"
    }

    Write-Log "Veeam Backup Enterprise Manager has been successfully upgraded"

}
### END VBEM UPGRADE

### VBR UPGRADE
if ($vbr) {
    # Closing open Console sessions
    Write-Log "Closing open Console sessions"
    Stop-Process -Name "Veeam.Backup.Shell" -Force -ErrorAction SilentlyContinue

    # Stopping all Veeam services prior to upgrade
    Write-Log "Stopping all Veeam services"
    Get-Service veeam* | Stop-Service

    try {
        # Generate upgrade answer file
        $answerFile = "$logFolder\VbrAnswerFile_upgrade.xml"

        Write-Log "Checking if Veeam Backup & Replication answer file already exists..."
        if (Test-Path $answerFile) {
            Write-Log "Answer file: $answerFile"
        }
        else {
            Write-Log "Answer file not found. Generating file now..."
            Add-Content $answerFile @"
<?xml version="1.0" encoding="utf-8"?>
<unattendedInstallationConfiguration bundle="Vbr" mode="upgrade" version="1.0">
<!--[Required] Parameter 'mode' defines installation mode that silent install should operate in-->
<!--Supported values: install/upgrade/uninstall-->

<!--Note: unused [Optional] parameters should be removed from the answer file-->

    <properties>

        <!--License agreements-->
        <!--Specify parameters to accept all the license agreements during silent installation or upgrade-->

            <!--[Required] Parameter ACCEPT_EULA specifies if you want to accept the Veeam license agreement. Specify '1' to accept the license agreement and proceed with installation or upgrade-->
                <!--Supported values: 0/1-->
                <property name="ACCEPT_EULA" value="1" />

            <!--[Required] Parameter ACCEPT_LICENSING_POLICY specifies if you want to accept Veeam licensing policy. Specify '1' to accept the licensing policy and proceed with installation or upgrade-->
                <!--Supported values: 0/1-->
                <property name="ACCEPT_LICENSING_POLICY" value="1" />

            <!--[Required] Parameter ACCEPT_THIRDPARTY_LICENSES specifies if you want to accept all the 3rd party licenses used. Specify '1' to accept the license agreements and proceed with installation or upgrade-->
                <!--Supported values: 0/1-->
                <property name="ACCEPT_THIRDPARTY_LICENSES" value="1" />

            <!--[Required] Parameter ACCEPT_REQUIRED_SOFTWARE specifies if you want to accept all the required software licenses. Specify '1' to accept the license agreements and proceed with installation or upgrade-->
                <!--Supported values: 0/1-->
                <property name="ACCEPT_REQUIRED_SOFTWARE" value="1" />

        <!--License file-->
        <!--Specify path to a license file and autoupdate option-->

            <!--[Optional] Parameter VBR_LICENSE_FILE specifies a full path to the license file. If you do not specify this parameter(or leave it empty value), Veeam Backup & Replication will be installed using current license file. To install Community Edition it must be set to 0-->
                <!--Supported values: file path/0(to install CE)-->
                $(if ($License){
                    '<property name="VBR_LICENSE_FILE" value="' + $License + '" />'
                })

            <!--[Optional] Parameter VBR_LICENSE_AUTOUPDATE specifies if you want to update license automatically(enables usage reporting). If you do not specify this parameter, autoupdate will be enabled. For Community Edition, NFR and Evaluation licenses it must be set to 1. For licenses without license ID information it must be set to 0-->
                <!--Supported values: 0/1-->
                $(if ($LicenseAutoupdate){
                    '<property name="VBR_LICENSE_AUTOUPDATE" value="1" />'
                } else {
                    '<property name="VBR_LICENSE_AUTOUPDATE" value="0" />'
                })

            <!--  [Optional] Parameter VBR_PROACTIVE_SUPPORT specifies if you want to receive proactive support (enables diagnostic data sharing). If you do not specify this parameter, proactive support will be enabled. For Community Edition, NFR and Evaluation licenses it must be set to 1. For licenses without license ID information it must be set to 0 -->
				<!--  Supported values: 0/1  -->
                $(if ($ProactiveSupport){
                    '<property name="VBR_PROACTIVE_SUPPORT" value="1" />'
                } else {
                    '<property name="VBR_PROACTIVE_SUPPORT" value="0" />'
                })

        <!--Service account-->

            <!--[Optional] Parameter VBR_SERVICE_PASSWORD specifies a password for the account under which the Veeam Backup Service is running. Required during upgrade if service account is not LocalSystem account-->
            <!--Make sure you keep the answer file in a safe location whenever service account password is added to the answer file-->
                <!--Supported values: password in plain text-->
                $(if ($ServicePassword){
                    '<property name="VBR_SERVICE_PASSWORD" value="' + $ServicePassword + '" hidden="1"/>'
                })

        <!--Database configuration-->
        <!--Specify database server installation options and required configuration parameters for Veeam Backup & Replication database-->

            <!-- Microsoft Entra ID Database configuration -->
			<!-- Specify Microsoft Entra ID database server installation options. -->
			<!-- [Optional] Parameter VBR_ENTRAID_DATABASE_INSTALL specifies if bundled PostgreSQL server for Microsoft EntraID will be installed. If set to '0', PostgreSQL Database won't be installed -->
				<!-- Supported values: 0/1 -->
				$(if ($EntraIDDatabaseInstall){
                    '<property name="VBR_ENTRAID_DATABASE_INSTALL" value="1" />'
                } else {
                    '<property name="VBR_ENTRAID_DATABASE_INSTALL" value="0" />'
                })

        <!--Automatic update settings-->
        <!--Specify Veeam B&R autoupdate settings-->

            <!--[Optional] Parameter VBR_AUTO_UPGRADE specifies if you want Veeam Backup & Replication to automatically upgrade existing components in the backup infrastructure. If you do not specify this parameter, Veeam Backup & Replication will not upgrade out of date components automatically-->
                <!--Supported values: 0/1-->
                $(if ($AutoUpgrade){
                    '<property name="VBR_AUTO_UPGRADE" value="1" />'
                } else {
                    '<property name="VBR_AUTO_UPGRADE" value="0" />'
                })

        <!--Setup settings-->
        <!--Specify additional setup settings-->

            <!--[Optional] Parameter REBOOT_IF_REQUIRED forces target server reboot, whenever it is required. If you do not specify this parameter, reboot is not performed automatically. Keep in mind that upgrade procedure will not be restarted after reboot-->
                <!--Supported values: 0/1-->
                <property name="REBOOT_IF_REQUIRED" value="0" />

    </properties>
</unattendedInstallationConfiguration>
"@
        }
    }
    catch {
        Write-Log $_
        Write-Log "Answer file generation failed. Please investigate and resolve. Logs can be found here: $logFile"
        Write-Log "Unmounting Veeam ISO"
        Dismount-DiskImage -ImagePath $iso
        throw "ERROR: Answer file generation failed. Please check logs for more information."
    }

    try {
        # Upgrading Veeam Backup & Replication Server
        Write-Log "Upgrading Veeam Backup & Replication Server using answer file: $answerFile"
        $result = Update-Veeam -SilentInstallExe $exe -Answer $answerFile -Logs $logFolder
        if ($result -eq 0 -or $result -eq 3010 -or $result -eq 3011) { Write-Log "SUCCESS: ${result}" }
        else { throw "ERROR: ${result}" }
    }
    catch {
        Write-Log $_
        Write-Log "Unmounting Veeam ISO"
        Dismount-DiskImage -ImagePath $iso
        throw "Upgrade failed. Please check debug log for more information: $logFolder\BackupServer.log"
    }

    Write-Log "Veeam Backup & Replication has been successfully upgraded"
}
### END VBR UPGRADE

### VBR POST-UPGRADE ACTIONS
if ($vbr) {
    try {
        if ($vcc) {
            Write-Log "Disabling Cloud Connect Maintenance Mode"
            powershell.exe -NoLogo -ExecutionPolicy bypass -NoProfile -Command "Import-Module 'C:\Program Files\Veeam\Backup and Replication\Console\Veeam.Backup.PowerShell\Veeam.Backup.PowerShell.psd1'; Disable-VBRCloudMaintenanceMode"
        }

        Write-Log "Shutting down Veeam prior to reboot. This may take a while as all Veeam Proxies & Repositories are currently being upgraded."
        Get-Service veeam* | Where-Object {$_.Name -ne "VeeamBackupSvc"} | Stop-Service
        Get-Service veeam* | Stop-Service
    }
    catch {
        Write-Log $_
        Write-Log "One of the post-upgrade actions failed. Please investigate and resolve. Logs can be found here: $logFile"
        Write-Log "Unmounting Veeam ISO"
        Dismount-DiskImage -ImagePath $iso
        throw "ERROR: Post-upgrade actions failed. Please check logs for more information."
    }
}
### END VBR POST-UPGRADE ACTIONS

Write-Log "Unmounting Veeam ISO"
Dismount-DiskImage -ImagePath $iso
Write-Log "Script has completed successfully. Please reboot this server prior to using Veeam."
Write-Host "This can be done easily in PowerShell as well: Restart-Computer -Force"
return 0
