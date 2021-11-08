function Test-AdminPrivileges {

  Write-Verbose 'Checking Administrator credentials'
  If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) {
    Write-Warning 'You are not running this as an Administrator!`nRe-running script and will prompt for administrator credentials.'
    Start-Process -Verb 'RunAs' -File PowerShell.exe -Argument "-STA -NoProfile -File $($MyInvocation.MyCommand.Definition)"
    Break
  }

}

function Test-InstallSourceDir {

  param(
    [Parameter(Mandatory = $True)]
    [string]$InstallSource
  )

  if (!(Test-Path -Path $InstallSource)) {
    New-Item -Path $InstallSource -ItemType Directory | Out-Null
  }

}

function Test-LogsDir {

  param(
    [Parameter(Mandatory = $True)]
    [string]$InstallLogDir
  )

  if (!(Test-Path -Path $InstallLogDir)) {
    New-Item -Path $InstallLogDir -ItemType Directory | Out-Null
  }

}

function New-LogFile {

  param(
    [Parameter(Mandatory = $True)]
    [string]$InstallLogDir
  )

  [string]$LogFileName = "Veeam_v10_Install_" + $(Get-Date -Format MM-dd-yyyy_HH-mm-ss) + ".log"
  $Script:LogFile = New-Item -Path "$InstallLogDir\$LogFileName" -ItemType File
  Write-Output "New installation log file created at '$Script:LogFile'."

}

function Write-Log {

  param (
    [Parameter(Mandatory = $True)]
    [array]$LogOutput,
    [Parameter(Mandatory = $True)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet('Information', 'Warning', 'Error')]
    [string]$Severity,
    [Parameter(Mandatory = $True)]
    [string]$Path
  )

  $CurrentDate = (Get-Date -UFormat "%d-%m-%Y")
  $CurrentTime = (Get-Date -UFormat "%T")
  $LogOutput = $LogOutput -join (" ")
  "[$CurrentDate $CurrentTime] $Severity | $LogOutput" | Out-File $Path -Append
  Write-Output $($Severity + ": " + $LogOutput)
}

function Test-PendingReboot {

  if (Get-ChildItem 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending' -EA Ignore) {
    $RebootPending = $True
  }

  if (Get-Item 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired' -EA Ignore) {
    $RebootRequired = $True
  }

  if (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name PendingFileRenameOperations -EA Ignore) {
    $RenamePending = $True
  }

  try {
    $Util = [wmiclass]'\\.\root\ccm\clientsdk:CCM_ClientUtilities'
    $Status = $Util.DetermineIfRebootPending()
    if (($null -ne $Status) -and $Status.RebootPending) {
      $CCMRebootPending = $True
    }
  } catch { }

  if ($RebootPending -or $RebootRequired -or $RenamePending -or $CCMRebootPending) {
    $Script:RebootNeeded = $True
    Write-Log -Path $LogFile -Severity 'ERROR' -LogOutput 'Reboot is required. Please reboot and run script again.'
  }

  else {
    $Script:RebootNeeded = $False
    Write-Log -Path $LogFile -Severity 'Information' -LogOutput  'Reboot check performed, reboot is not required.'
  }

}


function Test-LocalUser {
  if ($Script:User_Account_Type -eq 'Local') {
    try {
      & net user $Script:All_Service_Username
    } catch {
      [bool]$Script:LocalUserMissing = $true
      Write-Log -Path $LogFile -Severity 'ERROR' -LogOutput 'Local user account does not exist; SQL installation will fail.'
    }
  }
}
function Find-dotNET {

  [string]$dotNetPath = 'HKLM:SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full'

  try {
    $Script:dotNETVersion = (Get-ItemProperty -Path $dotNetPath -Name 'Release' -ErrorAction Stop).Release
  } catch {
    [bool]$Script:dotNETRegMissing = $true
  }

  [bool]$Script:dotNetMinimum = ($Script:dotNETVersion -ge '461808')

  if ($Script:dotNETRegMissing) {
    [bool]$Script:dotNETRequired = $true
    Write-Log -Path $LogFile -Severity 'ERROR' -LogOutput 'Missing required .NET of version 4.7.2 or higher; .NET 4.7.2 will be installed.'
  }

  if (($null -eq $Script:dotNETRegMissing) -AND (!($Script:dotNetMinimum))) {
    [bool]$Script:dotNETRequired = $true
    Write-Log -Path $LogFile -Severity 'WARNING' -LogOutput 'Detected .NET, but not required version 4.7.2 or higher; .NET 4.7.2 will be installed.'
  }

  if ($Script:dotNetMinimum) {
    Write-Log -Path $LogFile -Severity 'Information' -LogOutput 'Detected required .NET version 4.7.2 or higher.'
  }

}

function Find-LicenseFile {

  param(
    [Parameter(Mandatory = $True)]
    [string]$LicenseFile
  )

  if (!(Test-Path -Path $LicenseFile)) {
    $Script:LicenseFileMissing
    Write-Log -Path $LogFile -Severity 'WARNING' -LogOutput 'License File not detected, Veeam Backup & Recovery will install in Community Edition mode.  Enterprise Manager installations will fail.'
  } else {
    Write-Log -Path $LogFile -Severity 'Information' -LogOutput 'File found at license file path, Veeam Backup & Recovery will attempt to use this.'
    Write-Log -Path $LogFile -Severity 'Information' -LogOutput 'NOTE: This check does not ensure a valid license file, only that it exists.'
  }
}

function Test-DirPath {

  param(
    [Parameter(Mandatory = $True)]
    [string]$Path
  )

  if (!(Test-Path -Path $Path)) {
    $Path = New-Item -Path $Path -ItemType Directory
  }

}

function Find-SQL2014CLR {

  [version]$CLRVersion = '12.0.2402.11'
  [string]$CLRRegPath = 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server 2014 Redist\SQL Server System CLR Types\CurrentVersion'

  try {
    $CLRRegVersion = [version]((Get-ItemProperty -Path $CLRRegPath -Name 'Version' -ErrorAction Stop).Version)
  } catch {
    [bool]$Script:CLRRegMissing = $true
  }

  if ($CLRRegMissing -OR ($CLRRegVersion -lt $CLRVersion)) {
    [bool]$Script:SQL2014_CLR_Missing = $true
    Write-Log -Path $LogFile -Severity 'WARNING' -LogOutput 'Microsoft System CLR Types for SQL Server 2014 component not detected; component will be installed.'
  } else {
    Write-Log -Path $LogFile -Severity 'Information' -LogOutput 'Microsoft System CLR Types for SQL Server 2014 component detected.'
  }

}

function Find-SQL2014SMO {

  [version]$SMOVersion = '12.0.2000.8'
  [string]$SMORegPath = 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server 2014 Redist\SharedManagementObjects\1033\CurrentVersion'
  try {
    $SMORegVersion = [version]((Get-ItemProperty -Path $SMORegPath -Name 'Version' -ErrorAction Stop).Version)
  } catch {
    [bool]$Script:SMORegMissing = $true
  }

  if ($SMORegMissing -OR ($SMORegVersion -lt $SMOVersion)) {
    [bool]$Script:SQL2014_SMO_Missing = $true
    Write-Log -Path $LogFile -Severity 'WARNING' -LogOutput 'Microsoft SQL Server 2014 Management Objects (x64) component not detected; component will be installed.'
  } else {
    Write-Log -Path $LogFile -Severity 'Information' -LogOutput 'Microsoft SQL Server 2014 Management Objects (x64) component detected.'
  }

}

function Find-MSReportViewer2015 {

  [version]$ReportViewerVersion = '12.0.2402.15'
  [string]$ReportViewerRegPath = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Microsoft SQL Server 2014 Redist\Microsoft Report Viewer 2015 Runtime'

  try {
    $ReportViewerRegVersion = [version]((Get-ItemProperty -Path $ReportViewerRegPath -Name 'Version' -ErrorAction Stop).Version)
  } catch {
    [bool]$Script:ReportViewerRegMissing = $true
  }

  if (($null -eq $ReportViewerRegVersion) -OR ($ReportViewerRegVersion -lt $ReportViewerVersion)) {
    $Script:MSReportViewer2015_Missing = $true
    Write-Log -Path $LogFile -Severity 'WARNING' -LogOutput 'Microsoft Report Viewer 2015 Runtime component not detected; component will be installed.'
  } else {
    Write-Log -Path $LogFile -Severity 'Information' -LogOutput 'Microsoft Report Viewer 2015 Runtime component detected.'
  }

}

function Find-MSSQL {

  $SQLServices = Get-ChildItem -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\' | Where-Object Name -Like "*SQL*"

  if ($SQLServices) {
    $SQLServerServices = $SQLServices | ForEach-Object { $PSItem | Where-Object { $($_.GetValue('ImagePath')) -like "*sqlservr.exe*" } }

    if ($SQLServerServices) {
      $SQLServerServices.GetValue('DisplayName') -match '.+\s\((.+)\)' | Out-Null
      [string]$Script:SQLInstanceName = $Matches[1]
      Write-Log -Path $LogFile -Severity 'Information' -LogOutput "SQL server service detected; found SQL instance: '$Script:SQLInstanceName'."
    }

    else {
      [bool]$Script:SQLServerServicesMissing = $true
      Write-Log -Path $LogFile -Severity 'WARNING' -LogOutput 'SQL server service not detected; SQL Express 2016SP2 will be installed.'
    }

  }

  else {
    [bool]$Script:SQLServicesMissing = $true
    Write-Log -Path $LogFile -Severity 'WARNING' -LogOutput 'SQL services not detected; SQL Express 2016SP2 will be installed.'
  }

}

function Find-WindowsFeatures {

  $WindowsFeatureList = 'Web-Server', 'Web-WebServer', 'Web-Common-Http', 'Web-Default-Doc', 'Web-Dir-Browsing', 'Web-Http-Errors', 'Web-Static-Content', 'Web-Health', 'Web-Http-Logging', 'Web-Performance', 'Web-Stat-Compression', 'Web-Security', 'Web-Filtering', 'Web-Windows-Auth', 'Web-App-Dev', 'Web-Net-Ext45', 'Web-Asp-Net45', 'Web-ISAPI-Ext', 'Web-ISAPI-Filter', 'Web-WebSockets', 'Web-Mgmt-Tools', 'Web-Mgmt-Console', 'NET-Framework-45-ASPNET'

  $WindowsFeatureResults = Get-WindowsFeature -Name $WindowsFeatureList

  $Script:WindowsFeatureMissing = $WindowsFeatureResults | Where-Object { $_.InstallState -ne 'Installed' } | Select-Object -ExpandProperty Name

  if ($Script:WindowsFeatureMissing) {
    [string]$WindowsFeatureString = $Script:WindowsFeatureMissing -join ','
    Write-Log -Path $LogFile -Severity 'WARNING' -LogOutput 'Some Windows features were not detected, these features will be installed.'
    Write-Log -Path $LogFile -Severity 'WARNING' -LogOutput "Windows features to be installed are: '$WindowsFeatureString'."
  }

}

function Find-URLRewrite {

  [int]$URLRewriteInstalled = '1'
  [string]$URLRewriteRegPath = 'HKLM:\SOFTWARE\Microsoft\IIS Extensions\URL Rewrite'

  try {
    $URLRewriteInstalledValue = [int]((Get-ItemProperty -Path $URLRewriteRegPath -Name 'Install' -ErrorAction Stop).Install)
  } catch {
    [bool]$Script:URLRewriteRegMissing = $true
  }

  if (($null -eq $URLRewriteInstalledValue) -OR ($URLRewriteInstalledValue -ne $URLRewriteInstalled)) {
    $Script:URLRewrite_Missing = $true
    Write-Log -Path $LogFile -Severity 'WARNING' -LogOutput 'Microsoft IIS URL Rewrite Module 2 component not detected; component will be installed.'
  }

}

