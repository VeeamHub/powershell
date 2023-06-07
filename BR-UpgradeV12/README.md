# Automated Upgrade to Veeam Backup & Replication v12

## Author

Chris Arceneaux (@chris_arceneaux)

## Function

This script will upgrade Veeam Backup Enterprise Manager and/or Veeam Backup & Replication Server from 10a or later to version 12. The script is designed to be executed on the server to be upgraded. It's also possible to execute the script from a remote PowerShell session.

This script was written to work with standard Veeam Backup & Replication environments as well as Cloud Connect Veeam Backup & Replication environments that a Service Provider (VCSP) would administer.

***NOTE:*** Before executing this script in a production environment, I strongly recommend you:

* Read [Veeam's Upgrade Documentation](https://helpcenter.veeam.com/docs/backup/vsphere/upgrade_vbr.html?ver=120)
* Fully understand what the script is doing
* Test the script in a lab environment

## Known Issues

* If Veeam software other than Veeam Backup Enterprise Manager or Veeam Backup & Replication Server is installed on the same server, this software will be taken offline during the upgrade.
* After the upgrade, any Veeam Agents (VAW/VAL/VAM/VAU) managed by Veeam Backup & Replication will need to be upgraded.
* This script does NOT backup the Enterprise Manager database. Prior to upgrade, it's recommended to perform a DB backup.

## Requirements

* Veeam Backup & Replication
  * v10a (build 10.0.1.4854) or newer
* Windows account with Administrator access to the Veeam server
* Microsoft Windows Server 2019 or 2022
  * *might work with other Windows versions but untested*

## Usage

```powershell
Get-Help .\Update-Veeam.ps1 -Full
```

Here's a high-level view of the upgrade process:

### VEEAM BACKUP ENTERPRISE MANAGER UPGRADE #######

1. Veeam Backup Catalog
2. Veeam Backup Enterprise Manager
3. Veeam Cloud Connect Portal (if installed)

### VEEAM BACKUP & REPLICATION SERVER UPGRADE #######

1. Veeam Backup Catalog
2. Veeam Backup & Replication Server
3. Veeam Backup & Replication Console
4. Veeam Explorer for Microsoft Active Directory
5. Veeam Explorer for Microsoft Exchange
6. Veeam Explorer for Oracle
7. Veeam Explorer for PostgreSQL
8. Veeam Explorer for Microsoft SharePoint
9. Veeam Explorer for Microsoft SQL Server
10. Veeam Explorer for Microsoft Teams
11. Veeam Distribution Service
12. Veeam Installer Service
13. Veeam Plug-ins for Enterprise Applications Redistributable
14. Veeam Agent for Linux Redistributable
15. Veeam Agent for MacOS Redistributable
16. Veeam Agent for Microsoft Windows Redistributable
17. Veeam Agent for Unix Redistributable
18. Veeam Cloud Plug-ins (AWS/Azure/GCP)
19. Veeam Backup for Nutanix AHV
20. Veeam Backup for Red Hat Virtualization
21. Veeam Plug-in for Kasten K10
22. Veeam Backup Cloud Gateway (if installed)
