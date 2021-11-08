<#
.SYNOPSIS
    PowerShell script to perform a clean install of Veeam Backup & Replication Server v10 or higher
.DESCRIPTION
    Performs a number of different installation configurations based on a JSON config file and parameter:

    - Veeam Backup & Replication Server Pre-Requisites Check (Verify Pending Reboots,.NET 4.7.2, SQL 2014 CLR, SQL 2014 SMO)
    - Veeam Backup & Replication Server Pre-Requisites Install
    - Veeam Backup & Replication Server Install
    - Veeam Backup & Replication Console Install
    - Veeam Backup & Replication Explorers Install
    - Veeam Backup Enterprise Manager Pre-Requisites Check
    - Veeam Backup Enterprise Manager Pre-Requisites Install
    - Veeam Backup Enterprise Manager Install
    - All In One (Prerequisites plus Veeam Backup & Replication Server/Console/Explorers plus Backup Enterprise Manager)

    Note: Set Veeam variables in VeeamConfigVariables.ps1 (the only required variables are uncommented, more details in README)
.NOTES
    Version:        0.1
    Author:         Joe Houghes
    Twitter:        @jhoughes
    Github:         jhoughes

.PARAMETER InstallOption
    This parameter set will select the option for the Veeam installation:

    VBRPrereqCheck - Veeam Backup & Replication Server Pre-Requisites Check (Verify Pending Reboots,.NET 4.7.2, SQL 2014 CLR, SQL 2014 SMO, MS Report Viewer 2015)
    VBRPrereqInstall - Veeam Backup & Replication Server Pre-Requisites Install
    VBRServerInstall - Veeam Backup & Replication Server Install (Includes Prereq check and installation, plus Veeam Backup & Replication Server/Console/Explorers)
    VBRConsoleInstall - Veeam Backup & Replication Console Install
    VBRExplorersInstall - Veeam Backup & Replication Explorers Install
    VEMPrereqCheck - Veeam Backup Enterprise Manager Pre-Requisites Check
    VEMPrereqInstall - Veeam Backup Enterprise Manager Pre-Requisites Install
    VEMServerInstall - Veeam Backup Enterprise Manager Install (Includes Prereq check and installation, plus Veeam Backup Catalog)
    VCCPortal - Veeam Cloud Connect Portal (Includes Veeam Backup Enterprise Manager)
    AIO - All In One (Includes Prerequisites, Veeam Backup & Replication Server/Console/Explorers, Veeam Backup Enterprise Manager)

.EXAMPLE
    .\Install_Veeam.ps1 -InstallOption AIO
.EXAMPLE
    .\Install_Veeam.ps1 -InstallOption VBRServerInstall

.LINK
    https://helpcenter.veeam.com/docs/backup/vsphere/silent_mode.html?ver=100

.LINK
    https://helpcenter.veeam.com/docs/backup/vsphere/upgrade_vbr.html?ver=100
#>

[CmdletBinding()]

Param
(
    [Parameter( Mandatory = $true,
        HelpMessage = 'This parameter set will select the option for the Veeam installation')]
    [ValidateSet("VBRPrereqCheck", "VBRPrereqInstall", "VBRServerInstall", "VBRConsoleInstall", "VBRExplorersInstall", "VEMPrereqCheck", "VEMPrereqInstall", "VEMServerInstall", "VCCPortal", "AIO")]
    [string]$InstallOption

)

#Script Path and additional PS1 files
$ScriptPath = (Split-Path ((Get-Variable MyInvocation).Value).MyCommand.Path)
$VeeamConfigVars = "$ScriptPath\VeeamConfigVariables.ps1"
$VeeamFunctions = "$ScriptPath\VeeamInstallFunctions.ps1"

#Import Variables & Functions
. $VeeamConfigVars
. $VeeamFunctions

#Run Environment Checks
Test-AdminPrivileges

Test-InstallSourceDir -InstallSource $Script:InstallSource

Test-LogsDir -InstallLogDir $Script:InstallLogDir

New-LogFile -InstallLogDir $Script:InstallLogDir

Test-PendingReboot

#region InstallOptions

if ($PSBoundParameters.InstallOption -eq 'VBRPrereqCheck' -OR $PSBoundParameters.InstallOption -eq 'VBRPrereqInstall' -OR $PSBoundParameters.InstallOption -eq 'VBRServerInstall' -OR $PSBoundParameters.InstallOption -eq 'VEMServerInstall' -OR $PSBoundParameters.InstallOption -eq 'AIO') {
    $RunVBRPrereqCheck = $true
}

if ($PSBoundParameters.InstallOption -eq 'VBRPrereqInstall' -OR $PSBoundParameters.InstallOption -eq 'VBRServerInstall' -OR $PSBoundParameters.InstallOption -OR $PSBoundParameters.InstallOption -eq 'AIO') {
    $RunVBRPrereqInstall = $true
}

if ($PSBoundParameters.InstallOption -eq 'VBRServerInstall' -OR $PSBoundParameters.InstallOption -eq 'AIO') {
    $RunVBRInstall = $true
}

if ($PSBoundParameters.InstallOption -eq 'VBRServerInstall' -OR $PSBoundParameters.InstallOption -eq 'VBRConsoleInstall' -OR $PSBoundParameters.InstallOption -eq 'AIO') {
    $RunVBCInstall = $true
}

if ($PSBoundParameters.InstallOption -eq 'VBRServerInstall' -OR $PSBoundParameters.InstallOption -eq 'VBRExplorersInstall' -OR $PSBoundParameters.InstallOption -eq 'AIO') {
    $RunVBRExplorerInstall = $true
}

if ($PSBoundParameters.InstallOption -eq 'VEMPrereqCheck' -OR $PSBoundParameters.InstallOption -eq 'VEMPrereqInstall' -OR $PSBoundParameters.InstallOption -eq 'VEMServerInstall' -OR $PSBoundParameters.InstallOption -eq 'AIO') {
    $RunVBREMPrereqCheck = $true
}

if ($PSBoundParameters.InstallOption -eq 'VEMPrereqInstall' -OR $PSBoundParameters.InstallOption -eq 'VEMServerInstall' -OR $PSBoundParameters.InstallOption -eq 'AIO') {
    $RunVBREMPrereqInstall = $true
}

if ($PSBoundParameters.InstallOption -eq 'VEMServerInstall' -OR $PSBoundParameters.InstallOption -eq 'AIO') {
    $RunVBREMInstall = $true
}

if ($PSBoundParameters.InstallOption -eq 'VEMServerInstall' -OR $PSBoundParameters.InstallOption -eq 'VCCPortal' -OR $PSBoundParameters.InstallOption -eq 'AIO') {
    $RunCCPInstall = $true
}

#endregion InstallOptions


if ($RunVBRPrereqCheck) {

    Write-Log -Path $LogFile -Severity 'Information' -LogOutput 'Beginning Veeam Backup & Replication Prerequisite Check'

    Find-dotNET

    Find-LicenseFile -LicenseFile $Script:LicenseFile

    Find-SQL2014CLR

    Find-SQL2014SMO

    Find-MSReportViewer2015

    if (!($Script:UseRemoteSQL)) {
        Find-MSSQL
    }

    $MissingComponents = [bool]($Script:dotNETRequired -OR $Script:LicenseFileMissing -OR $Script:SQL2014_CLR_Missing -OR $Script:SQL2014_SMO_Missing -OR $Script:MSReportViewer2015_Missing)

    if (!($MissingComponents) -AND $Script:SQLInstanceName) {
        [bool]$Script:VBRAllPrereqs = $true
        Write-Log -Path $LogFile -Severity 'Information' -LogOutput 'All Veeam Backup & Replication Prerequisites found, installation can continue'
    }

    Write-Log -Path $LogFile -Severity 'Information' -LogOutput 'Completed Veeam Backup & Replication Prerequisite Check'

}

if ($RunVBRPrereqInstall) {

    if ($Script:VBRAllPrereqs) {

        Write-Log -Path $LogFile -Severity 'Information' -LogOutput 'Prerequisites exist - skipping Veeam Backup & Replication Prerequisite Install'

    } else {

        Write-Log -Path $LogFile -Severity 'Information' -LogOutput 'Beginning Veeam Backup & Replication Prerequisite Install'

        #region .NET 4.7.2

        if ([bool]$Script:dotNETRequired) {

            Write-Log -Path $LogFile -Severity 'Information' -LogOutput 'Installing .NET 4.7.2'

            $dotNETProcess = Start-Process "$InstallSource\Redistr\NDP472-KB4054530-x86-x64-AllOS-ENU.exe" -ArgumentList '/q /norestart' -Wait -NoNewWindow -PassThru
            $returncode = $dotNETProcess.ExitCode

            switch ($returncode) {

                0 { $Result = "Installation completed successfully." }
                1641	{ $Result = "A restart is required to complete the installation. This message indicates success." }
                3010	{ $Result = "A restart is required to complete the installation. This message indicates success." }
                1602	{ $Result = "The user canceled installation." }
                1603	{ $Result = "A fatal error occurred during installation." }
                5100	{ $Result = "The user's computer does not meet system requirements." }

            }

            $Script:LogPath = "$InstallLogDir\_Prereq_00_.NET_4.7.2.txt"
            Copy-Item -Path "$Env:Temp\dd_NDP472-KB4054530-x86-x64-AllOS-ENU_decompression_log.txt" -Destination $Script:LogPath

            if ($returncode -eq '0') {
                Write-Log -Path $LogFile -Severity 'Information' -LogOutput ".NET 4.7.2 install results were: '$Result'."
                Write-Log -Path $LogFile -Severity 'Information' -LogOutput '.NET 4.7.2 Install Succeeded.'
                Remove-Variable dotNETProcess, returncode -ErrorAction SilentlyContinue
            } elseif ($returncode -eq '1641' -OR $returncode -eq '3010') {
                Write-Log -Path $LogFile -Severity 'Information' -LogOutput ".NET 4.7.2 install results were: '$Result'."
                Write-Log -Path $LogFile -Severity 'WARNING' -LogOutput '.NET 4.7.2 Install Succeeded, but reboot is required.'
                [bool]$Script:RebootNeeded = $True
                Remove-Variable dotNETProcess, returncode -ErrorAction SilentlyContinue
            } else {
                $VBR_Prereq_Failures += 1
                Write-Log -Path $LogFile -Severity 'ERROR' -LogOutput ".NET 4.7.2 install results were: '$Result'."
                Write-Log -Path $LogFile -Severity 'ERROR' -LogOutput '.NET 4.7.2 Install Failed'
                [bool]$Script:RebootNeeded = $True
                Remove-Variable dotNETProcess, returncode -ErrorAction SilentlyContinue
                throw ".NET 4.7.2 Install Failed, please check logs in '$InstallLogDir'."
            }

        }

        #endregion .NET 4.7.2

        #region SQL2014_CLR

        if ($Script:SQL2014_CLR_Missing) {

            Write-Log -Path $LogFile -Severity 'Information' -LogOutput 'Installing SQL 2014 CLR'

            $Script:MSIPath = "$InstallSource\Redistr\x64\SQLSysClrTypes.msi"
            $Script:LogPath = "$InstallLogDir\_Prereq_01_SQL2014_CLR.txt"
            $SQL2014_CLR_Arguments = $Script:MSIArgs -f $Script:MSIPath, $Script:LogPath

            Start-Process 'msiexec.exe' -ArgumentList $SQL2014_CLR_Arguments -Wait -NoNewWindow

            if (Select-String -Path $Script:LogPath -Pattern 'Installation success or error status: 0.') {
                Write-Log -Path $LogFile -Severity 'Information' -LogOutput 'SQL 2014 CLR Install Succeeded'
                Remove-Variable MSIPath, LogPath -ErrorAction SilentlyContinue
            } else {
                $VBR_Prereq_Failures += 1
                Write-Log -Path $LogFile -Severity 'ERROR' -LogOutput 'SQL 2014 CLR Install Failed'
                Remove-Variable MSIPath, LogPath -ErrorAction SilentlyContinue
                throw "SQL 2014 CLR Install Failed, please check logs in '$InstallLogDir'."
            }

        }

        #endregion SQL2014_CLR

        #region SQL2014_SMO

        if ($Script:SQL2014_SMO_Missing) {

            Write-Log -Path $LogFile -Severity 'Information' -LogOutput 'Installing SQL 2014 SMO'

            $Script:MSIPath = "$InstallSource\Redistr\x64\SharedManagementObjects.msi"
            $Script:LogPath = "$InstallLogDir\_Prereq_02_SQL2014_SMO.txt"
            $SQL2014_SMO_Arguments = $Script:MSIArgs -f $Script:MSIPath, $Script:LogPath

            Start-Process 'msiexec.exe' -ArgumentList $SQL2014_SMO_Arguments -Wait -NoNewWindow

            if (Select-String -Path $Script:LogPath -Pattern 'Installation success or error status: 0.') {
                Write-Log -Path $LogFile -Severity 'Information' -LogOutput 'SQL 2014 SMO Install Succeeded'
                Remove-Variable MSIPath, LogPath -ErrorAction SilentlyContinue
            } else {
                $VBR_Prereq_Failures += 1
                Write-Log -Path $LogFile -Severity 'ERROR' -LogOutput 'SQL 2014 SMO Install Failed'
                Remove-Variable MSIPath, LogPath -ErrorAction SilentlyContinue
                throw "SQL 2014 SMO Install Failed, please check logs in '$InstallLogDir'."
            }
        }

        #endregion SQL2014_SMO

        #region MSReportViewer2015

        if ($Script:MSReportViewer2015_Missing) {

            Write-Log -Path $LogFile -Severity 'Information' -LogOutput 'Installing MS Report Viewer 2015'

            $Script:MSIPath = "$InstallSource\Redistr\ReportViewer.msi"
            $Script:LogPath = "$InstallLogDir\_Prereq_03_MS_ReportViewer2015.txt"
            $MS2015_ReportViewer_Arguments = $Script:MSIArgs -f $Script:MSIPath, $Script:LogPath

            Start-Process 'msiexec.exe' -ArgumentList $MS2015_ReportViewer_Arguments -Wait -NoNewWindow

            if (Select-String -Path $Script:LogPath -Pattern 'Installation success or error status: 0.') {
                Write-Log -Path $LogFile -Severity 'Information' -LogOutput 'MS Report Viewer 2015 Install Succeeded'
                Remove-Variable MSIPath, LogPath -ErrorAction SilentlyContinue
            } else {
                $VBR_Prereq_Failures += 1
                Write-Log -Path $LogFile -Severity 'ERROR' -LogOutput 'MS Report Viewer 2015 Install Failed'
                Remove-Variable MSIPath, LogPath -ErrorAction SilentlyContinue
                throw "MS Report Viewer 2015 Install Failed, please check logs in '$InstallLogDir'."
            }
        }

        #endregion MSReportViewer2015

        #region SQL2016Express

        if ($Script:SQLServerServicesMissing -OR $Script:SQLServicesMissing -AND ($Script:UseRemoteSQL -eq $false)) {

            if ($Script:RebootNeeded) {
                Write-Log -Path $LogFile -Severity 'WARNING' -LogOutput 'SQL Express install detected required reboot.'
            } else {

                $TempDir = New-Item -Name 'SQLEXPR_x64_ENU' -Path $Env:TEMP -ItemType Directory -Force

                Write-Log -Path $LogFile -Severity 'Information' -LogOutput "Unpacking SQL Express 2016 SP2 to $TempDir"

                Start-Process "$InstallSource\Redistr\x64\SqlExpress\2016SP2\SQLEXPR_x64_ENU.exe" -ArgumentList "/x:$TempDir /q /u" -Wait

                Write-Log -Path $LogFile -Severity 'Information' -LogOutput 'Installing SQL Express 2016 SP2'

                $Script:LogPath = "$InstallLogDir\_Prereq_04_SQLExpress_2016SP2.txt"

                $Script:SQLExpress_Args = $Script:SQLExpress_Args -f $Script:SQLSysAdmins

                Start-Process "$TempDir\setup.exe" -ArgumentList $Script:SQLExpress_Args -Wait

                #Start-Process "$InstallSource\Redistr\x64\SqlExpress\2016SP2\SQLEXPR_x64_ENU.exe" -ArgumentList $SQLExpress_Args -Wait -NoNewWindow

                Copy-Item -Path "C:\Program Files\Microsoft SQL Server\130\Setup Bootstrap\Log\Summary.txt" -Destination $Script:LogPath

                if (Select-String -Path $Script:LogPath -Pattern "Exit code \(Decimal\):           0") {
                    Write-Log -Path $LogFile -Severity 'Information' -LogOutput 'SQL Express 2016 SP2 Install Succeeded'
                } else {
                    $VBR_Prereq_Failures += 1
                    Write-Log -Path $LogFile -Severity 'ERROR' -LogOutput 'SQL Express 2016 SP2 Install Failed'
                    throw "SQL Express 2016 SP2 Install Failed, please check logs in '$InstallLogDir'."
                }

            }

        }

        #endregion SQL2016Express

        if ($VBR_Prereq_Failures -gt 0) {
            Write-Log -Path $LogFile -Severity 'ERROR' -LogOutput 'One or more Veeam B&R or Enterprise Manager prerequisites failed to Install. Exiting install script.'
            throw "One or more Veeam B&R or Enterprise Manager prerequisites failed to Install, please check logs in '$InstallLogDir'. Exiting install script."
        }

        if ($Script:RebootNeeded) {
            Write-Log -Path $LogFile -Severity 'WARNING' -LogOutput 'Veeam B&R or Enterprise Manager prerequisites installation has completed, but reboot is required.'
            Write-Log -Path $LogFile -Severity 'WARNING' -LogOutput 'Please reboot the system before running the install script again.'
        }

        Write-Log -Path $LogFile -Severity 'Information' -LogOutput 'Completed Veeam Backup & Replication Prerequisite Install'

    }
}

if ($RunVBRInstall -OR $RunVBREMInstall -AND !($Script:RebootNeeded)) {

    Write-Log -Path $LogFile -Severity 'Information' -LogOutput 'Beginning Veeam Backup Catalog Install'

    $Script:MSIPath = $Script:VBRC_MSIFile
    $Script:LogPath = $Script:VBRC_LogPath
    $Backup_Catalog_MSIArguments = $Script:MSIArgs -f $Script:MSIPath, $Script:LogPath
    $Backup_Catalog_MSIArguments = $Backup_Catalog_MSIArguments + $Script:ThirdPartyLicenses

    Start-Process 'msiexec.exe' -ArgumentList $Backup_Catalog_MSIArguments -Wait -NoNewWindow

    if (Select-String -Path $Script:LogPath -Pattern 'Installation success or error status: 0.') {
        Write-Log -Path $LogFile -Severity 'Information' -LogOutput 'Veeam Backup Catalog Install Succeeded'
    } else {
        Write-Log -Path $LogFile -Severity 'ERROR' -LogOutput 'Veeam Backup Catalog Install Failed'
        throw "Veeam Backup Catalog Install Failed, please check logs in '$InstallLogDir'."
    }

    Write-Log -Path $LogFile -Severity 'Information' -LogOutput 'Completed Veeam Backup Catalog Install'

}

if ($RunVBRInstall -AND !($Script:RebootNeeded)) {

    Write-Log -Path $LogFile -Severity 'Information' -LogOutput 'Beginning Veeam Backup & Replication Server Install'

    Test-DirPath -Path $Script:vPowerNFSPath
    Test-DirPath -Path $Script:IRWriteCache

    $Script:MSIPath = $Script:VBR_MSIFile
    $Script:LogPath = $Script:VBR_LogPath

    if ($Script:vPowerNFSPath) {
        $Backup_Server_MSIArguments = $Backup_Server_MSIArguments + " VBR_NFSDATASTORE=`"$Script:vPowerNFSPath`""
    }

    if ($Script:IRWriteCache) {
        $Backup_Server_MSIArguments = $Backup_Server_MSIArguments + " VBR_IRCACHE=`"$Script:IRWriteCache`""
    }

    if (!($Script:VBR_Check_Updates)) {
        $Backup_Server_MSIArguments = $Backup_Server_MSIArguments + " VBR_CHECK_UPDATES=`"0`""
    }

    if ($Script:VBR_Upgrade_Components) {
        $Backup_Server_MSIArguments = $Backup_Server_MSIArguments + " VBR_AUTO_UPGRADE=`"1`""
    }

    $Backup_Server_MSIArguments = $Script:MSIArgs -f $Script:MSIPath, $Script:LogPath

    if ($Script:SQLInstanceName) {
        if ($Script:SQLInstanceName -eq "MSSQLSERVER") {
            $Backup_Server_MSIArguments = $Backup_Server_MSIArguments + " VBR_SQLSERVER_SERVER=`"$($env:COMPUTERNAME)`""
        } else {
        $Backup_Server_MSIArguments = $Backup_Server_MSIArguments + " VBR_SQLSERVER_SERVER=`"$($env:COMPUTERNAME + "\" + $Script:SQLInstanceName)`""
        }
    } else {
        $Backup_Server_MSIArguments = $Backup_Server_MSIArguments + " VBR_SQLSERVER_SERVER=`"$($env:COMPUTERNAME + "\VEEAMSQL2016")`""
    }

    $Backup_Server_MSIArguments = $Backup_Server_MSIArguments + " VBR_SQLSERVER_DATABASE=`"VeeamBackup`""

    $Backup_Server_MSIArguments = $Backup_Server_MSIArguments + $Script:ServerEULA + $Script:ThirdPartyLicenses

    if ($Script:LicenseFile -AND (!($Script:LicenseFileMissing))) {
        $Script:LicenseFileArg = ' VBR_LICENSE_FILE="{0}"' -f $Script:LicenseFile
        $Backup_Server_MSIArguments = $Backup_Server_MSIArguments + $Script:LicenseFileArg
    }

    Write-Output "VBR Args are: $Backup_Server_MSIArguments"

    Start-Process 'msiexec.exe' -ArgumentList $Backup_Server_MSIArguments -Wait -NoNewWindow

    if (Select-String -Path $Script:LogPath -Pattern 'Installation success or error status: 0.') {
        Write-Log -Path $LogFile -Severity 'Information' -LogOutput 'Veeam Backup & Replication Server Install Succeeded'
        Remove-Variable MSIPath, LogPath -ErrorAction SilentlyContinue
    } else {
        Write-Log -Path $LogFile -Severity 'ERROR' -LogOutput 'Veeam Backup & Replication Server Install Failed'
        Remove-Variable MSIPath, LogPath -ErrorAction SilentlyContinue
        throw "Veeam Backup & Replication Server Install Failed, please check logs in '$InstallLogDir'."
    }

    Write-Log -Path $LogFile -Severity 'Information' -LogOutput 'Completed Veeam Backup & Replication Server Install'

}

if ($RunVBCInstall -AND !($Script:RebootNeeded)) {

    Write-Log -Path $LogFile -Severity 'Information' -LogOutput 'Beginning Veeam Backup Console Install'

    $Script:MSIPath = $Script:VBC_MSIFile
    $Script:LogPath = $Script:VBC_LogPath
    $BackupConsole_Arguments = $Script:MSIArgs -f $Script:MSIPath, $Script:LogPath
    $BackupConsole_Arguments = $BackupConsole_Arguments + $Script:ServerEULA + $Script:ThirdPartyLicenses

    Start-Process 'msiexec.exe' -ArgumentList $BackupConsole_Arguments -Wait -NoNewWindow

    if (Select-String -Path $Script:LogPath -Pattern 'Installation success or error status: 0.') {
        Write-Log -Path $LogFile -Severity 'Information' -LogOutput 'Veeam Backup Console Install Succeeded'
        Remove-Variable MSIPath, LogPath -ErrorAction SilentlyContinue
    } else {
        Write-Log -Path $LogFile -Severity 'ERROR' -LogOutput 'Veeam Backup Console Install Failed'
        Remove-Variable MSIPath, LogPath -ErrorAction SilentlyContinue
        throw "Veeam Backup Console Install Failed, please check logs in '$InstallLogDir'."
    }

    Write-Log -Path $LogFile -Severity 'Information' -LogOutput 'Completed Veeam Backup Console Install'

}

if ($RunVBRExplorerInstall -AND !($Script:RebootNeeded)) {

    Write-Log -Path $LogFile -Severity 'Information' -LogOutput 'Beginning Veeam Explorers Install'

    #region AD Explorer

    $Script:MSIPath = $Script:ExplorerAD_MSIFile
    $Script:LogPath = $Script:ExplorerAD_LogPath
    $ExplorerAD_Arguments = $Script:MSIArgs -f $Script:MSIPath, $Script:LogPath
    $ExplorerAD_Arguments = $ExplorerAD_Arguments + $Script:ExplorerEULA + $Script:ThirdPartyLicenses

    Write-Log -Path $LogFile -Severity 'Information' -LogOutput 'Installing Veeam Active Directory Explorer'

    Start-Process 'msiexec.exe' -ArgumentList $ExplorerAD_Arguments -Wait -NoNewWindow

    if (Select-String -Path $Script:LogPath -Pattern 'Installation success or error status: 0.') {
        Write-Log -Path $LogFile -Severity 'Information' -LogOutput 'Veeam Active Directory Explorer Install Succeeded'
        Remove-Variable MSIPath, LogPath -ErrorAction SilentlyContinue
    } else {
        Write-Log -Path $LogFile -Severity 'ERROR' -LogOutput 'Veeam Active Directory Explorer Install Failed'
        Remove-Variable MSIPath, LogPath -ErrorAction SilentlyContinue
        throw "Veeam Active Directory Explorer Install Failed, please check logs in '$InstallLogDir'."
    }

    #endregion AD Explorer

    #region Exchange Explorer

    $Script:MSIPath = $Script:ExplorerExchange_MSIFile
    $Script:LogPath = $Script:ExplorerExchange_LogPath
    $ExplorerExchange_Arguments = $Script:MSIArgs -f $Script:MSIPath, $Script:LogPath
    $ExplorerExchange_Arguments = $ExplorerExchange_Arguments + $Script:ExplorerEULA + $Script:ThirdPartyLicenses

    Write-Log -Path $LogFile -Severity 'Information' -LogOutput 'Installing Veeam Exchange Explorer'

    Start-Process 'msiexec.exe' -ArgumentList $ExplorerExchange_Arguments -Wait -NoNewWindow

    if (Select-String -Path $Script:LogPath -Pattern 'Installation success or error status: 0.') {
        Write-Log -Path $LogFile -Severity 'Information' -LogOutput 'Veeam Exchange Explorer Install Succeeded'
        Remove-Variable MSIPath, LogPath -ErrorAction SilentlyContinue
    } else {
        Write-Log -Path $LogFile -Severity 'ERROR' -LogOutput 'Veeam Exchange Explorer Install Failed'
        Remove-Variable MSIPath, LogPath -ErrorAction SilentlyContinue
        throw "Veeam Exchange Explorer Install Failed, please check logs in '$InstallLogDir'."
    }

    #endregion Exchange Explorer

    #region Oracle Explorer

    $Script:MSIPath = $Script:ExplorerOracle_MSIFile
    $Script:LogPath = $Script:ExplorerOracle_LogPath
    $ExplorerOracle_Arguments = $Script:MSIArgs -f $Script:MSIPath, $Script:LogPath
    $ExplorerOracle_Arguments = $ExplorerOracle_Arguments + $Script:ExplorerEULA + $Script:ThirdPartyLicenses

    Write-Log -Path $LogFile -Severity 'Information' -LogOutput 'Installing Veeam Oracle Explorer'

    Start-Process 'msiexec.exe' -ArgumentList $ExplorerOracle_Arguments -Wait -NoNewWindow

    if (Select-String -Path $Script:LogPath -Pattern 'Installation success or error status: 0.') {
        Write-Log -Path $LogFile -Severity 'Information' -LogOutput 'Veeam Oracle Explorer Install Succeeded'
        Remove-Variable MSIPath, LogPath -ErrorAction SilentlyContinue
    } else {
        Write-Log -Path $LogFile -Severity 'ERROR' -LogOutput 'Veeam Oracle Explorer Install Failed'
        Remove-Variable MSIPath, LogPath -ErrorAction SilentlyContinue
        throw "Veeam Oracle Explorer Install Failed, please check logs in '$InstallLogDir'."
    }

    #endregion Oracle Explorer

    #region SharePoint Explorer

    $Script:MSIPath = $Script:ExplorerSharePoint_MSIFile
    $Script:LogPath = $Script:ExplorerSharePoint_LogPath
    $ExplorerSharePoint_Arguments = $Script:MSIArgs -f $Script:MSIPath, $Script:LogPath
    $ExplorerSharePoint_Arguments = $ExplorerSharePoint_Arguments + $Script:ExplorerEULA + $Script:ThirdPartyLicenses

    Write-Log -Path $LogFile -Severity 'Information' -LogOutput 'Installing Veeam SharePoint Explorer'

    Start-Process 'msiexec.exe' -ArgumentList $ExplorerSharePoint_Arguments -Wait -NoNewWindow

    if (Select-String -Path $Script:LogPath -Pattern 'Installation success or error status: 0.') {
        Write-Log -Path $LogFile -Severity 'Information' -LogOutput 'Veeam SharePoint Explorer Install Succeeded'
        Remove-Variable MSIPath, LogPath -ErrorAction SilentlyContinue
    } else {
        Write-Log -Path $LogFile -Severity 'ERROR' -LogOutput 'Veeam SharePoint Explorer Install Failed'
        Remove-Variable MSIPath, LogPath -ErrorAction SilentlyContinue
        throw "Veeam SharePoint Explorer Install Failed, please check logs in '$InstallLogDir'."
    }

    #endregion SharePoint Explorer

    #region SQL Explorer

    $Script:MSIPath = $Script:ExplorerSQL_MSIFile
    $Script:LogPath = $Script:ExplorerSQL_LogPath
    $ExplorerSQL_Arguments = $Script:MSIArgs -f $Script:MSIPath, $Script:LogPath
    $ExplorerSQL_Arguments = $ExplorerSQL_Arguments + $Script:ExplorerEULA + $Script:ThirdPartyLicenses

    Write-Log -Path $LogFile -Severity 'Information' -LogOutput 'Installing Veeam SQL Explorer'

    Start-Process 'msiexec.exe' -ArgumentList $ExplorerSQL_Arguments -Wait -NoNewWindow

    if (Select-String -Path $Script:LogPath -Pattern 'Installation success or error status: 0.') {
        Write-Log -Path $LogFile -Severity 'Information' -LogOutput 'Veeam SQL Explorer Install Succeeded'
        Remove-Variable MSIPath, LogPath -ErrorAction SilentlyContinue
    } else {
        Write-Log -Path $LogFile -Severity 'ERROR' -LogOutput 'Veeam SQL Explorer Install Failed'
        Remove-Variable MSIPath, LogPath -ErrorAction SilentlyContinue
        throw "Veeam SQL Explorer Install Failed, please check logs in '$InstallLogDir'."
    }

    #endregion SQL Explorer

    Write-Log -Path $LogFile -Severity 'Information' -LogOutput 'Completed Veeam Explorers Install'

}

if ($RunVBREMPrereqCheck -AND !($Script:RebootNeeded)) {

    Write-Log -Path $LogFile -Severity 'Information' -LogOutput 'Beginning Veeam Enterprise Manager Prerequisite Check'

    if (!($RunVBRPrereqInstall)) {

        Find-dotNET

        Find-LicenseFile -LicenseFile $Script:LicenseFile

        Find-SQL2014CLR

        Find-SQL2014SMO

        Find-MSReportViewer2015

        if (!($Script:UseRemoteSQL)) {
            Find-MSSQL
        }

    }

    Find-WindowsFeatures

    Find-URLRewrite

    Write-Log -Path $LogFile -Severity 'Information' -LogOutput 'Completed Veeam Enterprise Manager Prerequisite Check'

}

if ($RunVBREMPrereqInstall -AND !($Script:RebootNeeded)) {

    Write-Log -Path $LogFile -Severity 'Information' -LogOutput 'Beginning Veeam Enterprise Manager Prerequisite Install'

    #region EnableWindowsFeatures

    try {

        Write-Log -Path $LogFile -Severity 'Information' -LogOutput 'Enabling required Windows features'

        $OSVersion = [version](Get-WmiObject Win32_OperatingSystem).Version

        if ($OSVersion.Major -ge 6.2) {

            foreach ($WindowsFeature in $Script:WindowsFeatureMissing) {
                Write-Log -Path $LogFile -Severity 'Information' -LogOutput "Enabling Windows feature: $WindowsFeature"
                Install-WindowsFeature -Name $WindowsFeature
            }

        } else {

            foreach ($WindowsFeature in $Script:WindowsFeatureMissing) {
                Write-Log -Path $LogFile -Severity 'Information' -LogOutput "Enabling Windows feature: $WindowsFeature"
                Add-WindowsFeature -Name $WindowsFeature
            }

        }

    } catch {
        $VBREM_Prereq_Failures += 1
        Write-Log -Path $LogFile -Severity 'ERROR' -LogOutput 'Failed to enable one of more Windows features'
        throw "Failed to enable one of more Windows features"
    }

    #endregion EnableWindowsFeatures

    #region URLRewrite

    $Script:MSIPath = "$InstallSource\Redistr\x64\rewrite_amd64.msi"
    $Script:LogPath = "$InstallLogDir\_Prereq_05_URLRewrite_IIS.txt"
    $URLRewrite_IIS_Arguments = $Script:MSIArgs -f $Script:MSIPath, $Script:LogPath

    Write-Log -Path $LogFile -Severity 'Information' -LogOutput 'Installing Microsoft IIS URL Rewrite Module 2'

    Start-Process 'msiexec.exe' -ArgumentList $URLRewrite_IIS_Arguments -Wait -NoNewWindow

    if (Select-String -Path $Script:LogPath -Pattern 'Installation success or error status: 0.') {
        Write-Log -Path $LogFile -Severity 'Information' -LogOutput 'Microsoft IIS URL Rewrite Module 2 Succeeded'
        Remove-Variable MSIPath, LogPath -ErrorAction SilentlyContinue
    } else {
        $VBREM_Prereq_Failures += 1
        Write-Log -Path $LogFile -Severity 'ERROR' -LogOutput 'Microsoft IIS URL Rewrite Module 2 Failed'
        Remove-Variable MSIPath, LogPath -ErrorAction SilentlyContinue
        throw "Microsoft IIS URL Rewrite Module 2 Install Failed, please check logs in '$InstallLogDir'."
    }

    #endregion URLRewrite

    if ($VBREM_Prereq_Failures -gt 0) {
        Write-Log -Path $LogFile -Severity 'ERROR' -LogOutput 'One or more Enterprise Manager prerequisites failed to Install. Exiting install script.'
        throw"One or more Veeam Enterprise Manager prerequisites failed to install, please check logs in '$InstallLogDir'. Exiting install script."
    }

    Write-Log -Path $LogFile -Severity 'Information' -LogOutput 'Completed Veeam Enterprise Manager Prerequisite Install'

}

if ($RunVBREMInstall -AND !($Script:RebootNeeded)) {

    Write-Log -Path $LogFile -Severity 'Information' -LogOutput 'Beginning Veeam Enterprise Manager Web Install'

    $Script:MSIPath = $Script:VBREM_MSIFile
    $Script:LogPath = $Script:VBREM_LogPath
    $Enterprise_Manager_Web_Arguments = $Script:MSIArgs -f $Script:MSIPath, $Script:LogPath
    $Enterprise_Manager_Web_Arguments = $Enterprise_Manager_Web_Arguments + $Script:ServerEULA + $Script:ThirdPartyLicenses


    Start-Process 'msiexec.exe' -ArgumentList $Enterprise_Manager_Web_Arguments -Wait -NoNewWindow

    if (Select-String -Path $Script:LogPath -Pattern 'Installation success or error status: 0.') {
        Write-Log -Path $LogFile -Severity 'Information' -LogOutput 'Veeam Enterprise Manager Web Install Succeeded'
        Remove-Variable MSIPath, LogPath -ErrorAction SilentlyContinue
    } else {
        Write-Log -Path $LogFile -Severity 'ERROR' -LogOutput 'Veeam Enterprise Manager Web Install Failed'
        Remove-Variable MSIPath, LogPath -ErrorAction SilentlyContinue
        throw "Veeam Enterprise Manager Web Install Failed, please check logs in '$InstallLogDir'."
    }

    Write-Log -Path $LogFile -Severity 'Information' -LogOutput 'Completed Veeam Enterprise Manager Web Install'

}

if ($RunCCPInstall -AND !($Script:RebootNeeded)) {

    Write-Log -Path $LogFile -Severity 'Information' -LogOutput 'Beginning Veeam Cloud Connect Portal Install'

    $Script:MSIPath = $Script:CCP_MSIFile
    $Script:LogPath = $Script:CCP_LogPath
    $Cloud_Connect_Portal_Arguments = $Script:MSIArgs -f $Script:MSIPath, $Script:LogPath
    $Cloud_Connect_Portal_Arguments = $Cloud_Connect_Portal_Arguments + $Script:ServerEULA + $Script:ThirdPartyLicenses

    Start-Process 'msiexec.exe' -ArgumentList $Cloud_Connect_Portal_Arguments -Wait -NoNewWindow

    if (Select-String -Path $Script:LogPath -Pattern 'Installation success or error status: 0.') {
        Write-Log -Path $LogFile -Severity 'Information' -LogOutput 'Veeam Cloud Connect Portal Install Succeeded'
        Remove-Variable MSIPath, LogPath -ErrorAction SilentlyContinue
    } else {
        Write-Log -Path $LogFile -Severity 'ERROR' -LogOutput 'Veeam Cloud Connect Portal Install Failed'
        Remove-Variable MSIPath, LogPath -ErrorAction SilentlyContinue
        throw "Veeam Cloud Connect Portal Install Failed, please check logs in '$InstallLogDir'."
    }

    Write-Log -Path $LogFile -Severity 'Information' -LogOutput 'Completed Veeam Cloud Connect Portal Install'


}

Write-Log -Path $LogFile -Severity 'Information' -LogOutput "Reached end of Veeam Install script, log file can be found at'$LogFile'."
