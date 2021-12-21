# Cloud Connect Orphaned Backups Report

## Author

Chris Arceneaux (@chris_arceneaux)

## Function

This script looks for backups that are no longer tied to an active Backup Job and then filters the results depending on the parameters specified.

Further background info on this script... When a Copy Job (or Backup Job) is deleted that was sending its backups to a (Cloud Connect) Cloud Repository, the backup files are not deleted by default. This behavior is great as it enables a backup administrator to hold on to the backups according to their company's retention policy. Sometimes, though, these backups are forgotten which results in additional storage consumed in the Cloud Repository which translates to higher storage costs. This script provides an automated method of identifying these backups so they aren't forgotten.

***NOTE:*** This script is designed to be executed on a Veeam Backup & Replication server that sends backups to a Cloud Repository. **It will not work if executed on a Cloud Connect server.**

## Known Issues

* No known issues

## Requirements

* Veeam Backup & Replication v11
  * *might work with other versions but untested*

## Usage

Get-Help .\Find-VCCOrphanedBackups.ps1 -Full

![Sample output](sample-output.png)

![Sample output](sample-output2.png)
