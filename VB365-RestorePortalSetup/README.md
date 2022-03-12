# Automated setup of the Veeam Backup for MS 365 Restore Portal

## Author

* Chris Arceneaux (@chris_arceneaux)

## Function

A collection of scripts used to automate setup and configuration of the [Veeam Backup for Microsoft 365 Restore Portal](https://helpcenter.veeam.com/docs/vbo365/guide/ssp_configuration.html). These scripts can be used for VB365 environments with a single Microsoft 365 Organization and for those with multiple Microsoft 365 Organizations being protected (like in a Service Provider scenario).

## Known Issues

* *There are no known issues.*

## Requirements

* Veeam Backup for Microsoft 365 v6
* Both scripts require the following PowerShell modules to be installed:
  * [Azure AD](https://www.powershellgallery.com/packages/AzureAD)
  * [Az.Accounts](https://www.powershellgallery.com/packages/Az.Accounts)

## Usage

### *Enable-VB365RestorePortal.ps1*

Performs initial setup and configuration of the [Veeam Backup for Microsoft 365 Restore Portal](https://helpcenter.veeam.com/docs/vbo365/guide/ssp_configuration.html).

Get-Help .\Enable-VB365RestorePortal.ps1 -Full

### *Connect-VB365RestorePortal.ps1*

Enables a Microsoft 365 environment to use a Service Provider's Restore Portal.

Get-Help .\Connect-VB365RestorePortal.ps1 -Full

***NOTE:*** If you'd like the following additional metrics, you can uncomment corresponding lines 350-379 in the script:

* VCD UID
* Organization UID
* Org VDC UID
* Backup Repository UID
* VSSP Quota UID
