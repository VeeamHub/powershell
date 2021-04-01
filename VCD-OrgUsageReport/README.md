# Veeam Usage Report for VMware Cloud Director

## Author

* Chris Arceneaux (@chris_arceneaux)

A big thanks to Yuri Sukhov ([@wombatairlines](https://twitter.com/wombatairlines))! I used his [code](https://github.com/wombatonfire/veeam-powershell/tree/master/New-OrgBackupReport) as a starting point for this project.

## Function

The script retrieves Veeam backup usage for VMware Cloud Director (VCD) Organizations. For each organization, the following is provided:

* Total number of VMs in backups
* Total amount of space used in repositories

The usage data can be aggregated on the Organization-level or the Org VDC-level. This is useful when backups for different Org VDCs are billed differently.

The scope of the usage returned is also customizable. It can be limited to self-service backups, created by the [Veeam Self-Service Portal (VSSP) for VCD](https://helpcenter.veeam.com/docs/backup/em/em_managing_vms_in_vcd_org.html?ver=110), or it can also include backups created directly on the backup server by the provider.

***NOTE:*** Before using this script in a production environment, I recommend you verify that numbers match up to your environment. This script uses undocumented API calls so it's subject to change.

## Known Issues

* *There are no known issues for VSSP backup usage.*
* `-IncludeAllVcdBackups` does not include VCD Replication job storage usage.
* `-IncludeAllVcdBackups` reports usage correctly but repository specified may be incorrect.

## Requirements

* Veeam Backup & Replication 11
  * _Does not work with previous versions_
* Backups must be stored in a Backup Repository with [per-machine backup files enabled](https://helpcenter.veeam.com/docs/backup/vsphere/repository_repository.html?ver=110)
  * This is because the size of the backups is calculated using backup files, and it's impossible to reliably attribute per-machine consumption to the correct Organization/Org VDC when a backup file contains several VMs from different Organizations/Org VDCs.

## Usage

Get-Help .\Get-VcdOrgUsage.ps1 -Full
