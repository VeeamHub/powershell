# check-SLA.ps1

## Function

This script will read all the most recent restore points from all backup jobs of a single or multiple VBR servers. SLA compliance ratio (in percent) is calculated based on which percentage of the restore points have been created within the given backup window in comparison to the total number of restore points.
Per default, all backup jobs and VMs (or computers in case of agent jobs) will be processed. If a VM is processed by multiple jobs, onle the job which created the most recent restore point will be considered for this VM. To exclude particular jobs or VMs from the SLA calculation, parameters `excludeJobs`, `excludeVMs` and `excludeVMFile` can be used as described below.

> **Note:** If a VM within a particular job has NEVER been backed up successfully (i.e., no restore points exist for this VM at all), or if a job didn't run at least successfully once, this script will not be able report these as being 'outside of backup window' as it simply cannot process something that doesn't exist.

> **2nd Note:** If a restore point is newer than the backup window end time, it will be ignored and the next (older) restore point will be checked for backup window compliance instead.

## Requirements
- [Veeam Backup & Replication] v11 or newer
  - script has been tested against v11, v11a and v12 only
- [Veeam Powershell module]

## Parameters:
### Mandatory
- `vbrServer` = Veeam backup server name or IP to connect to (can be a pipelined value to process multiple VBR servers)
### Not mandatory
- `lookBackDays` = how many days should the script look back for the backup window start? (int, default `1` can be changed in `Param()`-section)
- `backupWindowStart` = at which time of day starts the backup window? (string in 24h format, default `"20:00"` can be changed in `Param()`-section)
- `backupWindowEnd` = at which time of day ends the backup window? (string in 24h format, default `"07:00"` can be changed in `Param()`-section)
- `displayGrid` = switch to display results in PS-GridViews (default = `$false`)
- `outputDir` = where to write the output files (folder must exist, otherwise defaulting to script folder)
- `excludeVMs` = VMs (or computers) that have this string as part of their name will be ignored (case-insensitive,default = empty string, i.e. no exclusions)
- `excludeVMsFile` = filename containing list of either VM names or VM Name + VM-ID combination to be excluded explicitly (textfile, one VM name / VM name + VM-ID per line, default = "`exclude-VMs.txt`", see example below)
- `separatorChar` = character for separation of VM name and VM-ID (optional) on each line of the VM exclusions file (default = "`,`" (comma), see example below)
- `excludeJobs` = jobs including this string in their **description** field will be ignored (case-insensitive, default = empty string, i.e. no exclusions)
- `excludeJobsFile` = filename containing list of backup jobs to be excluded explicitly (textfile, one job name per line, default = "`exclude-Jobs.txt`")


Backup window **start** will be calculated as follows:  
- Day  = today minus parameter `lookBackDays`
- Time = time of day set in parameter `backupWindowStart`

Backup window **end** will be calculated as follows:
- Day  = today, if `backupWindowEnd` is in the past; yesterday otherwise.
- Time = time of day set in parameter `backupWindowEnd`

Two output files will be created in the output folder:
1. CSV file containing most recent restore points with some details and whether they comply to backup window  
   (new file for each script run, file name prefixed with date/time)
2. CSV file containing summary of SLA compliance  
   (appending to this file for each script run)

## Example
This example uses all parameters to check the backup window starting at 22:00 on the day before yesterday (because `lookBackDays` is set to 2) and ending today at 05:00 (if the script is run after 5:00am on the current day; otherwise backup window end is set to yesterday 5:00am). CSV files will be created in folder `C:\Temp`. Jobs with the string "*#noSLA*" in their description and VMs with the string "*_test*" in their name will **not** be processed. Additionally to creating CSV files, results will be displayed in GridViews after processing.
```
./check-SLA -vbrServer "vbr-1.domain.tld" `
            -lookBackDays 2 `
            -backupWindowStart "22:00" `
            -backupWindowEnd "05:00" `
            -outputDir "C:\temp" `
            -excludeVMs "_test" `
            -excludeJobs "#noSLA" `
            -displayGrid
```
### Example VM exclusion file `excludeVMs.txt`
- Syntax: One VM entry per line, VM-ID can be optionally added after separator character (VM IDs can be retrieved from vCenter using the free [RVTools utility](https://www.robware.net/rvtools/), it shows on the "vInfo" page in column "VM ID").
- Default separator character is "`,`" (comma), it can be customized by parameter `separatorChar`.

```
srv1           # VM 'srv1' will be excluded, regardless of its VM-ID
vmA,vm-305     # VM 'vmA' will be excluded, but only if its VM-ID is 'vm-305'

```
(Comments in the example above are for this readme only, __do not use comments__ in your real exception file!)

## Version History
Date | Comments
---  | ---
2022.12.09 | initial release 
2023.08.07 | added support for VBR v12 job type "PerVMParentBackup" (new backup chain format of v12)
2023.11.13 | fixed a bug which lead to restore points being ignored when a job was changed to target a different repository

<!-- referenced links -->
[Veeam Backup & Replication]: https://www.veeam.com/vm-backup-recovery-replication-software.html
[Veeam PowerShell module]: https://helpcenter.veeam.com/docs/backup/powershell/getting_started.html
