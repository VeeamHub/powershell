# Automated Upgrade from Veeam 9.5 Update 4b to Veeam v10

## Author

Chris Arceneaux (@chris_arceneaux)

## Function

This script will upgrade Veeam Backup Enterprise Manager and/or Veeam Backup & Replication Server from version 9.5 Update 4b to version 10 depending on the software installed. The script is designed to be executed on the server to be upgraded. It's also possible to execute the script from a remote PowerShell session.

***NOTE:*** Before executing this script in a production environment, I strongly recommend you:

* Read [Veeam's Upgrade Documentation](https://helpcenter.veeam.com/docs/backup/vsphere/upgrade_vbr.html?ver=100)
* Fully understand what the script is doing
* Test the script in a lab environment

## Known Issues

* If Veeam software other than Veeam Backup Enterprise Manager or Veeam Backup & Replication is installed on the same server, this software will be taken offline during the upgrade.

## Requirements

* Veeam Backup & Replication 9.5 Update 4b
  * Veeam Backup & Replication 9.5 Update 3/4/4a *(might work but untested)*
* Windows account with Administrator access to the Veeam server

## Usage

Get-Help .\Update-Veeam.ps1 -Full
