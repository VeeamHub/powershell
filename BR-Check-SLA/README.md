# check-SLA.ps1

This script will read all the most recent restore points from all backup jobs of a single or multiple VBR servers. SLA compliance ratio (in percent) is calculated based on which percentage of the restore points have been created within the given backup window in comparison to the total number of restore points.
Per default, all backup jobs and VMs (or computers in cas of agent jobs) will be processed. To exclude particular jobs or VMs from the SLA calculation, parameters `excludeJobs` and `excludeVMs` can be used as described below.

Requires [Veeam Powershell module].

> **Note:** If a VM within a particular job has NEVER been backed up successfully (i.e., no restore points exist for this VM at all), or if a job didn't run at least successfully once, this script will not be able report these as being 'outside of backup window' as it simply cannot process something that doesn't exist.

> **2nd Note:** If a restore point is newer than the backup window end time, it will be ignored and the next (older) restore point will be checked for backup window compliance instead.

## Parameters:
### Mandatory
- `vbrServer` = Veeam backup server name or IP to connect to (can be a pipelined value to process multiple VBR servers)
### Not mandatory
- `lookBackDays` = how many days should the script look back for the backup window start? (int, default `1` can be changed in `Param()`-section)
- `backupWindowStart` = at which time of day starts the backup window? (string in 24h format, default `"20:00"` can be changed in `Param()`-section)
- `backupWindowEnd` = at which time of day ends the backup window? (string in 24h format, default `"07:00"` can be changed in `Param()`-section)
- `displayGrid` = switch to display results in PS-GridViews (default = `$false`)
- `outputDir` = where to write the output files (folder must exist, otherwise defaulting to script folder)
- `excludeJobs` = jobs including this string in their **description** field will be ignored (case-insensitive, default = empty string, i.e. no exclusions)
- `excludeVMs` = VMs (or computers) that have this string as part of their name will be ignored (case-insensitive,default = empty string, i.e. no exclusions)


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
            -excludeJobs "#noSLA" `
            -excludeVMs "_test" `
            -displayGrid
```

<!-- referenced links -->
[Veeam PowerShell module]: https://helpcenter.veeam.com/docs/backup/powershell/getting_started.html
