<#
.SYNOPSIS
The following script is to be used as an example to prove that it is both possible as well as easy to completely automate the deployment of the Veeam Agent for Windows.

.DESCRIPTION
To Setup This Sample:
1.) Download the most recent bits of Veeam Agent for Windows from Veeam.com
2.) Manually install and then export out the configuration of your backup
    a.) This is done via the Veeam.Agent.Configurator.exe -export command that's run from "c:\program files\veeam\endpoint backup\"
3.) Place your installation in a central location - Create a Network Share that is accessible to everyone
4.) Create a source directory C:\VAW and put your license file as well as the Config.xml file that was exported.
    a.) The default location for export is "C:\ProgramData\Veeam\Endpoint\!Configuration\Config.xml"
    b.) Don't forget to show hidden files

.PARAMETER Installer
This provides the path to the Veeam Agent for Windows

.PARAMETER LicenseFile
This provides the path to your Veeam Agent for Windows .LIC file

.PARAMETER ConfigFile
This provides the path to your Veeam Agent for Windows Config.xml file

.PARAMETER TenantAccount
This is the Tenant Account for the CC Repository

.PARAMETER TenantAccount
This is the password for the Tenant Account for the CC Repository

.PARAMETER VeeamAgentInstallDirectory
This is the location where Veeam Agent for Windows is installed

.EXAMPLE
No Parameters are required. This will run using the default values.
VAWInstall.ps1

.EXAMPLE
VAWInstall.ps1 -TenantAccount "MyTaccount" -TenantPassword "MyP@ssword"

.EXAMPLE
VAWInstall.ps1 -TenantAccount "MyTaccount" -TenantPassword "MyP@ssword" -Configfile "C:\VAW\ExportedConfig.xml"

.NOTES
Version 1.0.1
Author: Clint Wyckoff @ Veeam
Updated October 12, 2017
Fixed:
Parameter change from Beta to GA version of VAW - This has been validated to work with VAW 2.0.700
#>

Param (
    [string]$Installer = "\\phx-dc1.phx.aperaturelabs.biz\VAW\2.0.0.700\Source\VeeamAgentWindows_2.0.0.700.exe",
    [string]$LicenseFile = "\\phx-dc1.phx.aperaturelabs.biz\VAW\2.0.0.700\Extras\veeam_agent_windows_nfr_2_5.lic",
    [string]$ConfigFile = "\\phx-dc1.phx.aperaturelabs.biz\VAW\2.0.0.700\Extras\Config.xml",
    [string]$TenantAccount = "backup",
    [string]$TenantPassword = "password",
    [string]$VeeamAgentInstallDirectory = "C:\Program Files\Veeam\Endpoint Backup"
)

$VeeamAgentInstallDirectory = $VeeamAgentInstallDirectory -Replace "\\*$"
If ((Test-Path $LicenseFile) -eq $False) {
    Write-Host -ForegroundColor Red "Cannot find the License file at $LicenseFile"
    Exit 1
}
If ((Test-Path $ConfigFile) -eq $False) {
    Write-Host -ForegroundColor Red "Cannot find the Configuration file at $ConfigFile"
    Exit 2
}
If ((Test-Path $Installer) -eq $False) {
    Write-Host -ForegroundColor Red "Cannot find the Installer at $Installer"
    Exit 3
}

Write-Host -ForegroundColor Green "Step #1: Installing Veeam Agent for Windows. Please wait a minute."
$Process = (Split-Path $Installer -leaf) -Replace ".exe$"
Start-Process -FilePath $Installer -Verb runas -ArgumentList "/silent /accepteula"
$counter = 0
Do {
    Start-Sleep -Seconds 2
    If ($counter % 10 -eq 0) {
        Write-Host -ForegroundColor Green "Waiting for installer to complete."
    }
    $counter++;
} While (Get-Process $Process -ErrorAction SilentlyContinue)

Stop-Process -Name "Veeam.EndPoint.Tray" -Force -ErrorAction SilentlyContinue

Write-Host -ForegroundColor Green "Step #2: Applying your License File to the Protected Host"
Set-Location $VeeamAgentInstallDirectory
./Veeam.Agent.Configurator.exe -license /f:"$LicenseFile"

Write-Host -ForegroundColor Green "Step #3: Applying your Desired Configuration to the Protected Host"
.\Veeam.Agent.Configurator.exe -import /f:"$ConfigFile"

Start-Process "$VeeamAgentInstallDirectory\Veeam.EndPoint.Tray.exe"