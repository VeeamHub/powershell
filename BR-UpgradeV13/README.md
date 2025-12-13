# Automated Upgrade to Veeam Backup & Replication v13

## Author

Chris Arceneaux (@chris_arceneaux)

## Function

This script will upgrade Veeam Backup Enterprise Manager and/or Veeam Backup & Replication Server from 12.3.1 or later to version 13. The script is designed to be executed on the server to be upgraded. It's also possible to execute the script from a remote PowerShell session.

This script was written to work with standard Veeam Backup & Replication environments as well as Cloud Connect Veeam Backup & Replication environments that a Service Provider (VCSP) would administer.

***NOTE:*** Before executing this script in a production environment, I strongly recommend you:

* Read [Veeam's Upgrade Checklist Documentation](https://helpcenter.veeam.com/docs/vbr/userguide/upgrade_vbr_byb.html?ver=13)
* Fully understand what the script is doing
* Test the script in a lab environment

## Known Issues

* If Veeam software other than Veeam Backup Enterprise Manager or Veeam Backup & Replication Server is installed on the same server, this software will be taken offline during the upgrade.
* After the upgrade, any Veeam Agents (VAW/VAL/VAM/VAU) managed by Veeam Backup & Replication will need to be upgraded.
* This script does NOT backup the Enterprise Manager database. Prior to upgrade, it's recommended to perform a DB backup.

## Requirements

* Veeam Backup & Replication
  * 12.3.1 (build 12.3.1.1139) or newer
* Windows account with Administrator access to the Veeam server
* Microsoft Windows Server 2022 or 2025
  * *might work with other Windows versions but untested*

## Usage

```powershell
Get-Help .\Update-Veeam.ps1 -Full
```
