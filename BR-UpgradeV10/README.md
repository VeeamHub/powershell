# Automated Upgrade from Veeam 9.5 Update 4b to Veeam v10

## Author

Chris Arceneaux (@chris_arceneaux)

## Function

This script will upgrade Veeam Backup Enterprise Manager and/or Veeam Backup & Replication Server from version 9.5 Update 4b to version 10 depending on the software installed. The script is designed to be executed on the server to be upgraded. It's also possible to execute the script from a remote PowerShell session.

This script was written to work with standard Veeam Backup & Replication environments as well as Cloud Connect Veeam Backup & Replication environments that a Service Provider (VCSP) would administer.

***NOTE:*** Before executing this script in a production environment, I strongly recommend you:

* Read [Veeam's Upgrade Documentation](https://helpcenter.veeam.com/docs/backup/vsphere/upgrade_vbr.html?ver=100)
* Fully understand what the script is doing
* Test the script in a lab environment

## Known Issues

* If Veeam software other than Veeam Backup Enterprise Manager or Veeam Backup & Replication Server is installed on the same server, this software will be taken offline during the upgrade.
* After the upgrade, any Agent-base backups (VAW, VAL) that Veeam administers will need to be upgraded.

## Requirements

* Veeam Backup & Replication 9.5 Update 4b
  * Veeam Backup & Replication 9.5 Update 3/4/4a *(might work but untested)*
* Windows account with Administrator access to the Veeam server

## Usage

Get-Help .\Update-Veeam.ps1 -Full

Here's a high-level view of the upgrade process:

### VEEAM BACKUP ENTERPRISE MANAGER UPGRADE

1. Veeam Backup Catalog
2. Veeam Backup Enterprise Manager
3. Veeam Cloud Connect Portal (if installed)

### VEEAM BACKUP & REPLICATION SERVER UPGRADE

1. Veeam Backup Catalog
2. Veeam Backup & Replication Server
3. Veeam Backup & Replication Console
4. Veeam Explorer for Microsoft Active Directory
5. Veeam Explorer for Microsoft Exchange
6. Veeam Explorer for Microsoft SharePoint
7. Veeam Explorer for Microsoft SQL Server
8. Veeam Explorer for Oracle
9. Veeam Distribution Service
10. Veeam Installer Service
11. Veeam Agent for Linux Redistributable
12. Veeam Agent for Microsoft Windows Redistributable
13. Veeam Mount Service
14. Veeam Backup Transport
15. Veeam Backup vPowerNFS
16. Veeam Backup Cloud Gateway (if installed)
