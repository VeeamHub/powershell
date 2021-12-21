# Cloud Connect Orphaned Backups Report

## Author

Chris Arceneaux (@chris_arceneaux)

## Function

This script looks for backups that are no longer tied to an active Backup Job and then filters the results depending on the parameters specified.

***NOTE:*** This script is designed to be executed on a Veeam Backup & Replication server that sends backups to a (Cloud Connect) Cloud Repository. IT WILL NOT WORK IF EXECUTED ON A CLOUD CONNECT SERVER.

## Known Issues

* No known issues

## Requirements

* Veeam Backup & Replication
  * v11
  * *might work with other versions but untested*

## Usage

Get-Help .\Find-VCCOrphanedBackups.ps1 -Full

![Sample output](sample-output.png)

![Sample output](sample-output2.png)
