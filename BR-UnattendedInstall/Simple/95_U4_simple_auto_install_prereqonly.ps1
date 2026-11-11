#Confirmed on Windows Server 2016
#Confirmed on Veeam Backup Replication versions 9.5U4, 9.5U4a, and 9.5U4b
#Confirmed ISO: VeeamBackup&Replication_9.5.4.2615.Update4.iso
#Confirmed ISO: VeeamBackup&Replication_9.5.4.2753.Update4a.iso
#Confirmed ISO: VeeamBackup&Replication_9.5.4.2866.Update4b_.iso

$InstallSource = 'D:\'

$LogDir = 'C:\InstallLogs'

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