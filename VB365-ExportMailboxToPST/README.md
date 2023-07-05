# Exporting M365 Mailbox to PST

## Author

* Chris Arceneaux (@chris_arceneaux)

## Function

This script is designed to be executed on a Veeam Backup for Microsoft 365 (VB365) server as it leverages both VB365 & Veeam Explorer for MS Exchange cmdlets. It's interactive so no parameters are required. Upon execution, the script polls for information which culminates in the specified user mailbox being exported to a PST file.

## Known Issues

* *No known issues*

## Requirements

* Veeam Backup for Microsoft 365 v6
  * *Other versions are untested*
* Must be executed on Veeam Backup for Microsoft 365 server

## Usage

Script contains built-in documentation which can be accessed using the typical PowerShell method:

```powershell
Get-Help .\Export-UserMailbox.ps1 -Full
```

Script is designed to be interactive. As such, no parameters are required during execution:

```powershell
Export-UserMailbox.ps1
```
