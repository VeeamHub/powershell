#Confirmed on Windows Server 2016
#Confirmed on Veeam Backup Replication versions 9.5U4, 9.5U4a, and 9.5U4b
#Confirmed ISO: VeeamBackup&Replication_9.5.4.2615.Update4.iso
#Confirmed ISO: VeeamBackup&Replication_9.5.4.2753.Update4a.iso
#Confirmed ISO: VeeamBackup&Replication_9.5.4.2866.Update4b_.iso

#region: Variables
$InstallSource = 'D:\'
$LogDir = 'C:\InstallLogs'
$licensefile = 'C:\VAS_EntPlus_U4_50instances.lic'
$username = 'svc_veeam_poc'
$fulluser = $env:COMPUTERNAME + '\' + $username
$password = 'Passw0rd!'
$CatalogPath = 'C:\VBRCatalog'
$vPowerPath = 'C:\vPowerNFS'
#endregion

if (!(Test-Path -Path $LogDir)) {
  $LogDir = New-Item -Path 'C:\InstallLogs' -ItemType Directory
}

$PreReq_LogFile = "$LogDir\_PreReqOnly_Setup.txt"
Start-Transcript -Path $PreReq_LogFile

#region: New Local Administrator
$username = 'svc_veeam_br'
$fulluser = $env:COMPUTERNAME + '\' + $username
$password = 'Passw0rd!'

Write-Host "Creating local user '$fulluser' with password '$password' ..." -ForegroundColor Cyan
New-LocalUser -Name $username -Password ($password | ConvertTo-SecureString -AsPlainText -Force) -Description "Service Account for Veeam" -AccountNeverExpires -ErrorAction Stop | Out-Null
Add-LocalGroupMember -Group "Administrators" -Member $username -ErrorAction Stop
If (Get-LocalUser -Name $username) {
  Write-Host "     Created local user '$fulluser'" -ForegroundColor Green
}
#endregion New Local Administrator

#region: Install Veeam B&R Prerequisites

Write-Host "Installing Veeam Prerequisites" -ForegroundColor Cyan
Write-Host "------------------------------" -ForegroundColor Cyan

Write-Host "Installing SQL 2014 CLR" -ForegroundColor Cyan

$SQL2014_CLR_Arguments = @(
  "/i"
  "$InstallSource\Redistr\x64\SQLSysClrTypes.msi"
  "/qn"
  "/norestart"
  "/L*v"
  "$LogDir\_Prereq_01_SQL2014_CLR.txt"
)

Start-Process C:\Windows\System32\msiexec.exe -ArgumentList $SQL2014_CLR_Arguments -Wait -NoNewWindow

if (Select-String -Path "$LogDir\_Prereq_01_SQL2014_CLR.txt" -Pattern "Installation success or error status: 0.") {
  Write-Host "     SQL 2014 CLR Install Succeeded" -ForegroundColor Green
}
else {
  $VBR_Prereq_Failures += 1
  throw "SQL 2014 CLR Install Failed"
}

Write-Host "Installing SQL 2014 SMO"  -ForegroundColor Cyan
$SQL2014_SMO_Arguments = @(
  "/i"
  "$InstallSource\Redistr\x64\SharedManagementObjects.msi"
  "/qn"
  "/norestart"
  "/L*v"
  "$LogDir\_Prereq_02_SQL2014_SMO.txt"
)

Start-Process C:\Windows\System32\msiexec.exe -ArgumentList $SQL2014_SMO_Arguments -Wait -NoNewWindow

if (Select-String -Path "$LogDir\_Prereq_02_SQL2014_SMO.txt" -Pattern "Installation success or error status: 0.") {
  Write-Host "     SQL 2014 SMO Install Succeeded" -ForegroundColor Green
}
else {
  $VBR_Prereq_Failures += 1
  throw "SQL 2014 SMO Install Failed"
}

Write-Host "Installing SQL Express 2016 SP1" -ForegroundColor Cyan
$SQLExpress_Arguments = "/HIDECONSOLE /Q /IACCEPTSQLSERVERLICENSETERMS /ACTION=install /FEATURES=SQLEngine,SNAC_SDK /INSTANCENAME=VEEAMSQL2016 /SQLSVCACCOUNT=`"NT AUTHORITY\SYSTEM`" /SQLSYSADMINACCOUNTS=`"$fulluser`" `"Builtin\Administrators`" /TCPENABLED=1 /NPENABLED=1 /UpdateEnabled=0"
Start-Process "$InstallSource\Redistr\x64\SqlExpress\2016SP1\SQLEXPR_x64_ENU.exe" -ArgumentList $SQLExpress_Arguments -Wait -NoNewWindow

Copy-Item -Path "C:\Program Files\Microsoft SQL Server\130\Setup Bootstrap\Log\Summary.txt" -Destination "$LogDir\_Prereq_03_SQLExpress_2016SP1.txt"

if (Select-String -Path "$LogDir\_Prereq_03_SQLExpress_2016SP1.txt" -Pattern "Exit code \(Decimal\):           0") {
  Write-Host "     SQL Express 2016 SP1 Install Succeeded" -ForegroundColor Green
}
else {
  $VBR_Prereq_Failures += 1
  throw "SQL Express 2016 SP1 Install Failed"
}

Write-Host "Installing MS Report Viewer 2015" -ForegroundColor Cyan
$MS2015_ReportViewer_Arguments = @(
  "/i"
  "$InstallSource\Redistr\ReportViewer.msi"
  "/qn"
  "/norestart"
  "/L*v"
  "$LogDir\_Prereq_04_MS_ReportViewer2015.txt"
)

Start-Process C:\Windows\System32\msiexec.exe -ArgumentList $MS2015_ReportViewer_Arguments -Wait -NoNewWindow

if (Select-String -Path "$LogDir\_Prereq_04_MS_ReportViewer2015.txt" -Pattern "Installation success or error status: 0.") {
  Write-Host "     MS Report Viewer 2015 Install Succeeded" -ForegroundColor Green
}
else {
  $VBR_Prereq_Failures += 1
  throw "MS Report Viewer 2015 Install Failed"
}

If ($VBR_Prereq_Failures -gt 0) {
  throw "One or more Veeam B&R prerequisites failed to Install.  Exiting Build Script"
}

Write-Host "------------------------------" -ForegroundColor Cyan
if (!$VBR_Prereq_Failures) {
  Write-Host "     Veeam B&R Prerequisites have been successfully installed" -ForegroundColor Green
}
else {
  throw "Installation of $VBR_Prereq_Failures Veeam B&R prerequisites failed"
}

#endregion Install Veeam B&R Prerequisites

#region: Install Enterprise Manager Prerequisites
Write-Host "`n"
Write-Host "Installing Enterprise Manager Prerequisites" -ForegroundColor Cyan
Write-Host "------------------------------" -ForegroundColor Cyan
Install-WindowsFeature Web-Default-Doc, Web-Dir-Browsing, Web-Http-Errors, Web-Static-Content, Web-Windows-Auth -Restart:$false -ErrorVariable WindowsFeatureFailure | Out-Null
if ($WindowsFeatureFailure) {
  $WindowsFeatureFailure | Out-File "$LogDir\_Prereq_05_WindowsFeatures.txt" -Append
  Remove-Variable WindowsFeatureFailure
  $EntMgr_Prereq_Failures += 1
  throw "Windows Features Install Failed"
}

Install-WindowsFeature Web-Http-Logging, Web-Stat-Compression, Web-Filtering, Web-Net-Ext45, Web-Asp-Net45, Web-ISAPI-Ext, Web-ISAPI-Filter, Web-Mgmt-Console -Restart:$false -ErrorVariable WindowsFeatureFailure | Out-Null
if ($WindowsFeatureFailure) {
  $WindowsFeatureFailure | Out-File "$LogDir\_Prereq_05_WindowsFeatures.txt" -Append
  Remove-Variable WindowsFeatureFailure
  $EntMgr_Prereq_Failures += 1
  throw "Windows Features Install Failed"
}

$WindowsFeatureResults = Get-WindowsFeature -Name Web-Default-Doc, Web-Dir-Browsing, Web-Http-Errors, Web-Static-Content, Web-Windows-Auth, Web-Http-Logging, Web-Stat-Compression, Web-Filtering, Web-Net-Ext45, Web-Asp-Net45, Web-ISAPI-Ext, Web-ISAPI-Filter, Web-Mgmt-Console
$WindowsFeatureResults | Out-File "$LogDir\_Prereq_05_WindowsFeatures.txt" -Append

if (($WindowsFeatureResults | Select-Object -ExpandProperty InstallState -Unique) -eq 'Installed') {
  Write-Host "     Windows Features Install Succeeded" -ForegroundColor Green
}
else {
  Write-Output 'Not all Windows features installed properly' | Out-File "$LogDir\_Prereq_05_WindowsFeatures.txt" -Append
  throw "Windows Features Install Failed"
}

$URLRewrite_IIS_MSIArguments = @(
  "/i"
  "$InstallSource\Redistr\x64\rewrite_amd64.msi"
  "/qn"
  "/norestart"
  "/L*v"
  "$LogDir\_Prereq_06_URLRewrite_IIS.txt"
  "ACCEPTEULA=YES"
  "ACCEPT_THIRDPARTY_LICENSES=`"1`""
)
Start-Process "msiexec.exe" -ArgumentList $URLRewrite_IIS_MSIArguments -Wait -NoNewWindow

if (Select-String -path "$LogDir\_Prereq_06_URLRewrite_IIS.txt" -pattern "Installation success or error status: 0.") {
  Write-Host "     URL Rewrite Module for IIS Install Succeeded" -ForegroundColor Green
}
else {
  $EntMgr_Prereq_Failures += 1
  throw "URL Rewrite Module for IIS Install Failed"
}

Write-Host "------------------------------" -ForegroundColor Cyan
if (!$EntMgr_Prereq_Failures) {
  Write-Host "     Veeam Enterprise Manager Prerequisites have been successfully installed" -ForegroundColor Green
}
else {
  throw "Installation of $VBR_Prereq_Failures Veeam Enterprise Manager prerequisites failed"
}

#endregion: Install Enterprise Manager Prerequisites

Stop-Transcript

$VBR_BEM_LogFile = "$LogDir\VBR_BEM_Setup.txt"
Start-Transcript -Path $VBR_BEM_LogFile

#region: Install Veeam Components
Write-Host "`n"
Write-Host "Installing Veeam Backup & Replication" -ForegroundColor Cyan
Write-Host "------------------------------" -ForegroundColor Cyan

#region: Install Backup Catalog
Write-Host "Installing Veeam Backup Catalog" -ForegroundColor Cyan
New-Item -ItemType Directory -path $CatalogPath | Out-Null

$Backup_Catalog_MSIArguments = @(
  "/i"
  "$InstallSource\Catalog\VeeamBackupCatalog64.msi"
  "/qn"
  "/norestart"
  "/L*v"
  "$LogDir\01_VeeamBackupCatalog.txt"
  "ACCEPT_THIRDPARTY_LICENSES=`"1`""
  "VM_CATALOGPATH=$CatalogPath"
  "VBRC_SERVICE_USER=$fulluser"
  "VBRC_SERVICE_PASSWORD=$password"
)

Start-Process "msiexec.exe" -ArgumentList $Backup_Catalog_MSIArguments -Wait -NoNewWindow

if (Select-String -path "$LogDir\01_VeeamBackupCatalog.txt" -pattern "Installation success or error status: 0.") {
  Write-Host "     Backup Catalog Install Succeeded" -ForegroundColor Green
}
else {
  throw "Backup Catalog Install Failed"
}
#endregion: Install Backup Catalog

#region: Install Backup Server
Write-Host "Installing Veeam Backup Server" -ForegroundColor Cyan
New-Item -ItemType Directory -path $vPowerPath | Out-Null

$Backup_Server_MSIArguments = @(
  "/i"
  "$InstallSource\Backup\Server.x64.msi"
  "/qn"
  "/norestart"
  "/L*v"
  "$LogDir\02_VeeamBackupServer.txt"
  "ACCEPTEULA=YES"
  "ACCEPT_THIRDPARTY_LICENSES=`"1`""
  "VBR_LICENSE_FILE=$licensefile"
  "VBR_SERVICE_USER=$fulluser"
  "VBR_SERVICE_PASSWORD=$password"
  "VBR_NFSDATASTORE=$vPowerPath"
  "VBR_SQLSERVER_SERVER=$env:COMPUTERNAME\VEEAMSQL2016"
)

Start-Process "msiexec.exe" -ArgumentList $Backup_Server_MSIArguments -Wait -NoNewWindow

if (Select-String -path "$LogDir\02_VeeamBackupServer.txt" -pattern "Installation success or error status: 0.") {
  Write-Host "     Backup Server Install Succeeded" -ForegroundColor Green
}
else {
  throw "Backup Server Install Failed"
}

#endregion: Install Backup Server

#region: Install Backup Console
Write-Host "Installing Veeam Backup Console" -ForegroundColor Cyan

$Backup_Console_MSIArguments = @(
  "/i"
  "$InstallSource\Backup\Shell.x64.msi"
  "/qn"
  "/norestart"
  "/L*v"
  "$LogDir\03_VeeamBackupConsole.txt"
  "ACCEPTEULA=YES"
  "ACCEPT_THIRDPARTY_LICENSES=`"1`""
)

Start-Process "msiexec.exe" -ArgumentList $Backup_Console_MSIArguments -Wait -NoNewWindow

if (Select-String -path "$LogDir\03_VeeamBackupConsole.txt" -pattern "Installation success or error status: 0.") {
  Write-Host "     Backup Console Install Succeeded" -ForegroundColor Green
}
else {
  throw "Setup Failed"
}
#endregion: Install Backup Console

#region: Install Explorers

#region: AD Explorer
Write-Host "Installing Veeam Explorer For Active Directory" -ForegroundColor Cyan

$Explorer_AD_MSIArguments = @(
  "/i"
  "$InstallSource\Explorers\VeeamExplorerForActiveDirectory.msi"
  "/qn"
  "/norestart"
  "/L*v"
  "$LogDir\04_VeeamExplorerForActiveDirectory.txt"
  "ACCEPT_EULA=`"1`""
  "ACCEPT_THIRDPARTY_LICENSES=`"1`""
)

Start-Process "msiexec.exe" -ArgumentList $Explorer_AD_MSIArguments -Wait -NoNewWindow

if (Select-String -path "$LogDir\04_VeeamExplorerForActiveDirectory.txt" -pattern "Installation success or error status: 0.") {
  Write-Host "     Veeam Explorer For Active Directory Install Succeeded" -ForegroundColor Green
}
else {
  throw "Veeam Explorer For Active Directory Install Failed"
}

#endregion: AD Explorer

#region: Exchange Explorer
Write-Host "Installing Veeam Explorer For Exchange" -ForegroundColor Cyan

$Explorer_Exchange_MSIArguments = @(
  "/i"
  "$InstallSource\Explorers\VeeamExplorerForExchange.msi"
  "/qn"
  "/norestart"
  "/L*v"
  "$LogDir\05_VeeamExplorerForExchange.txt"
  "ACCEPT_EULA=`"1`""
  "ACCEPT_THIRDPARTY_LICENSES=`"1`""
)

Start-Process "msiexec.exe" -ArgumentList $Explorer_Exchange_MSIArguments -Wait -NoNewWindow

if (Select-String -path "$LogDir\05_VeeamExplorerForExchange.txt" -pattern "Installation success or error status: 0.") {
  Write-Host "     Veeam Explorer For Exchange Install Succeeded" -ForegroundColor Green
}
else {
  throw "Veeam Explorer For Exchange Install Failed"
}

#endregion: Exchange Explorer

#region: SQL Explorer
Write-Host "Installing Veeam Explorer For SQL" -ForegroundColor Cyan

$Explorer_SQL_MSIArguments = @(
  "/i"
  "$InstallSource\Explorers\VeeamExplorerForSQL.msi"
  "/qn"
  "/norestart"
  "/L*v"
  "$LogDir\06_VeeamExplorerForSQL.txt"
  "ACCEPT_EULA=`"1`""
  "ACCEPT_THIRDPARTY_LICENSES=`"1`""
)

Start-Process "msiexec.exe" -ArgumentList $Explorer_SQL_MSIArguments -Wait -NoNewWindow

if (Select-String -path "$LogDir\06_VeeamExplorerForSQL.txt" -pattern "Installation success or error status: 0.") {
  Write-Host "     Veeam Explorer For SQL Succeeded" -ForegroundColor Green
}
else {
  throw "Veeam Explorer For SQL Install Failed"
}

#endregion: SQL Explorer

#region: Oracle Explorer
Write-Host "Installing Veeam Explorer For Oracle" -ForegroundColor Cyan

$Explorer_Oracle_MSIArguments = @(
  "/i"
  "$InstallSource\Explorers\VeeamExplorerForOracle.msi"
  "/qn"
  "/norestart"
  "/L*v"
  "$LogDir\07_VeeamExplorerForOracle.txt"
  "ACCEPT_EULA=`"1`""
  "ACCEPT_THIRDPARTY_LICENSES=`"1`""
)

Start-Process "msiexec.exe" -ArgumentList $Explorer_Oracle_MSIArguments -Wait -NoNewWindow

if (Select-String -path "$LogDir\07_VeeamExplorerForOracle.txt" -pattern "Installation success or error status: 0.") {
  Write-Host "     Veeam Explorer For Oracle Succeeded" -ForegroundColor Green
}
else {
  throw "Veeam Explorer For Oracle Install Failed"
}

#endregion: Oracle Explorer

#region: SharePoint Explorer
Write-Host "Installing Veeam Explorer For SharePoint" -ForegroundColor Cyan

$Explorer_Sharepoint_MSIArguments = @(
  "/i"
  "$InstallSource\Explorers\VeeamExplorerForSharePoint.msi"
  "/qn"
  "/norestart"
  "/L*v"
  "$LogDir\08_VeeamExplorerForSharePoint.txt"
  "ACCEPT_EULA=`"1`""
  "ACCEPT_THIRDPARTY_LICENSES=`"1`""
)

Start-Process "msiexec.exe" -ArgumentList $Explorer_Sharepoint_MSIArguments -Wait -NoNewWindow

if (Select-String -path "$LogDir\08_VeeamExplorerForSharePoint.txt" -pattern "Installation success or error status: 0.") {
  Write-Host "     Veeam Explorer For SharePoint Install Succeeded" -ForegroundColor Green
}
else {
  throw "Veeam Explorer For SharePoint Install Failed"
}

#endregion: SharePoint Explorer

#endregion: Install Explorers

#endregion: Install Veeam Components

#region: Install Enterprise Manager
Write-Host "`n"
Write-Host "Installing Enterprise Manager" -ForegroundColor Cyan
Write-Host "------------------------------" -ForegroundColor Cyan

#region: Install Enterprise Manager Web
Write-Host "Installing Enterprise Manager Web" -ForegroundColor Cyan

$Enterprise_Manager_Web_MSIArguments = @(
  "/i"
  "$InstallSource\EnterpriseManager\BackupWeb_x64.msi"
  "/qn"
  "/norestart"
  "/L*v"
  "$LogDir\09_EntWeb.txt"
  "ACCEPTEULA=YES"
  "ACCEPT_THIRDPARTY_LICENSES=`"1`""
  "VBREM_LICENSE_FILE=$licensefile"
  "VBREM_SERVICE_USER=$fulluser"
  "VBREM_SERVICE_PASSWORD=$password"
  "VBREM_SQLSERVER_SERVER=$env:COMPUTERNAME\VEEAMSQL2016"
)

Start-Process "msiexec.exe" -ArgumentList $Enterprise_Manager_Web_MSIArguments -Wait -NoNewWindow

if (Select-String -path "$LogDir\09_EntWeb.txt" -pattern "Installation success or error status: 0.") {
  Write-Host "     Enterprise Manager Web Install Succeeded" -ForegroundColor Green
}
else {
  throw "Enterprise Manager Web Install Failed"
}

#endregion: Install Enterprise Manager Web

<#
#region: Install Enterprise Manager Cloud Portal
Write-Host "Installing Enterprise Manager Cloud Portal" -ForegroundColor Cyan

$Enterprise_Manager_CloudPortal_MSIArguments = @(
    "/i"
    "$InstallSource\Cloud Portal\BackupCloudPortal_x64.msi"
    "/L*v"
    "$LogDir\10_EntCloudPortal.txt"
    "/qn"
    "ACCEPTEULA=YES"
)

Start-Process "msiexec.exe" -ArgumentList $Enterprise_Manager_CloudPortal_MSIArguments -Wait -NoNewWindow

if (Select-String -path "$LogDir\10_EntCloudPortal.txt" -pattern "Installation success or error status: 0.") {
    Write-Host "     Enterprise Manager Cloud Install Succeeded" -ForegroundColor Green
}
else {
    throw "Enterprise Manager Cloud Install Failed"
}

#endregion: Install Enterprise Manager Cloud Portal
#>

#endregion: Install Enterprise Manager

#region: Install Veeam 9.5U4 Patches

#region: Veeam 9.5U4a Patch
if (Test-Path -Path "$InstallSource\Updates\veeam_backup_9.5.4.2753.update4a_setup.exe") {
  Write-Host "Installing Veeam 9.4 U4a Patch" -ForegroundColor Cyan
  Write-Host "------------------------------" -ForegroundColor Cyan

  $Veeam_95_U4a_Patch_Arguments = @(
    "/silent"
    "/noreboot"
    "/log"
    "$LogDir\Patch_Veeam_9.5_U4a.log"
    "VBR_AUTO_UPGRADE=`"1`""
  )

  Start-Process "$InstallSource\Updates\veeam_backup_9.5.4.2753.update4a_setup.exe" -ArgumentList $Veeam_95_U4a_Patch_Arguments -Wait -NoNewWindow

  if (Select-String -Path "$LogDir\Patch_Veeam_9.5_U4a.log" -Pattern "Return value 0.") {
    Write-Host "     Veeam B&R version 9.5U4a Patch Install Succeeded" -ForegroundColor Green
  }
}

#endregion: Veeam 9.5U4a Patch

#region: Veeam 9.5U4b Patch
if (Test-Path -Path "$InstallSource\Updates\veeam_backup_9.5.4.2866.update4b_setup.exe") {
  Write-Host "Installing Veeam 9.4 U4b Patch" -ForegroundColor Cyan
  Write-Host "------------------------------" -ForegroundColor Cyan

  $Veeam_95_U4a_Patch_Arguments = @(
    "/silent"
    "/noreboot"
    "/log"
    "$LogDir\Patch_Veeam_9.5_U4b.log"
    "VBR_AUTO_UPGRADE=`"1`""
  )

  Start-Process "$InstallSource\Updates\veeam_backup_9.5.4.2866.update4b_setup.exe" -ArgumentList $Veeam_95_U4a_Patch_Arguments -Wait -NoNewWindow

  if (Select-String -Path "$LogDir\Patch_Veeam_9.5_U4b.log" -Pattern "Return value 0.") {
    Write-Host "     Veeam B&R version 9.5U4b Patch Install Succeeded" -ForegroundColor Green
  }

}

#endregion: Veeam 9.5U4b Patch

#endregion: Install Veeam 9.5U4 Patches

Stop-Transcript