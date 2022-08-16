# Scripts to assist in exporting M365 Mailboxes to PST

## Author

* Chris Arceneaux (@chris_arceneaux)

## Function

A collection of scripts used to assist when exporting a Microsoft 365 protected mailbox to a PST file. 

`Export-UserMailbox.ps1`: This script is designed to be executed on a Veeam Backup for Microsoft 365 (VB365) server as it leverages both VB365 & Veeam Explorer for MS Exchange cmdlets. It's interactive so no parameters are required. Upon execution, the script polls for information which culminates in the specified user mailbox being exported to a PST file.

`Export-TenantMailbox.ps1`: This script can be used in the scenario where a Veeam Cloud & Service Provider (VCSP) is protecting your Microsoft 365 Organization. If the VCSP has enabled self-service restores using the Veeam Explorer for MS Exchange, as described in [Veeam documentation](https://helpcenter.veeam.com/docs/vbo365/guide/vbo_baas_tenant.html?ver=60), you can use this script to export a user mailbox to a PST file.

## Known Issues

* *No known issues*

## Requirements

All scripts were tested using *Veeam Backup for Microsoft 365 v6*.

`Export-UserMailbox.ps1`: Must be executed on Veeam Backup for Microsoft 365 server.

`Export-TenantMailbox.ps1`: Must be executed on tenant Veeam Backup & Replication server ***after*** the steps discussed in [Veeam documentation](https://helpcenter.veeam.com/docs/vbo365/explorers/vex_add_sp_database.html?ver=60) have been completed.

## Usage

All scripts contain built-in documentation which can be accessed using the typical PowerShell method:

```powershell
Get-Help .\Export-UserMailbox.ps1
Get-Help .\Export-TenantMailbox.ps1
```

All scripts are designed to be interactive. As such, no parameters are required when executing them.

```powershell
Export-UserMailbox.ps1
```
