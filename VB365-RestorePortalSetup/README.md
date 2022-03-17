# Scripts to automate setup of the VB365 Restore Portal

## Author

* Chris Arceneaux (@chris_arceneaux)

## Function

A collection of scripts used to automate setup and configuration of the [Veeam Backup for Microsoft 365 Restore Portal](https://helpcenter.veeam.com/docs/vbo365/guide/ssp_configuration.html). These scripts can be used for VB365 environments with a single Microsoft 365 Organization and for those with multiple Microsoft 365 Organizations in a multi-tenant setup (like in a Service Provider scenario).

## Known Issues

* *There's currently no method for automating configuration of a standalone RESTful API server.*

## Requirements

All scripts are designed to be executed on the VB365 server.

* Veeam Backup for Microsoft 365 v6
* Both scripts (*Connect-VB365RestorePortal.ps1/New-VB365EnterpriseApplication.ps1*) require the following PowerShell modules:
  * [Azure AD](https://www.powershellgallery.com/packages/AzureAD)
  * [Az.Accounts](https://www.powershellgallery.com/packages/Az.Accounts)

## Usage

* Create the Azure Enterprise Application
  * ***Name:*** Name of the Enterprise Application to be created
  * ***URL:*** URL to be provided to customers to access the Restore Portal

```powershell
New-VB365EnterpriseApplication.ps1 -Name "Veeam Restore Portal" -URL "https://veeam.domain:4443"
```

* Enable the VB365 Restore Portal
  * Follows steps outlined in [Veeam documentation](https://helpcenter.veeam.com/docs/vbo365/guide/ssp_configuration.html)
  * ***AppId:*** Enterprise Application Id (created in previous step)
  * ***AppThumbprint:*** Certificate thumbprint used when creating the Enterprise Application
  * ***SaveCerts:*** (optional) Saves RESTful API & Restore Portal certificates to the script folder
    * This is useful when configuring REST API on a [separate computer](https://helpcenter.veeam.com/docs/vbo365/guide/vbo_installing_rest.html?ver=60).

```powershell
Enable-VB365RestorePortal.ps1 -AppId 37a0f8e1-97bd-4804-ba69-bde1db293273 -AppThumbprint ccf2c168a2a4253532e27dba7e0093d6b6351f93 -SaveCerts
```

* Provide script to tenant so they can perform a one-time authorization for the Restore Portal
  * *This step is not required if only a single Microsoft 365 Organization is being protected.*
  * Follows steps outlined in [Veeam documentation](https://helpcenter.veeam.com/docs/vbo365/guide/ssp_configuration.html)
  * The Enterprise Application ID needs to be added to the script. In this way, all the tenant does is run the script.

```powershell
Connect-VB365RestorePortal.ps1
```
