# Veeam Backup for Microsoft 365 - Jet to Object Storage Migration
The goal of this project is to support the migration of backup data from disk (Jet) repositories to object storage repositories.

## Important note
Please be aware that the provided code is intended as examples only and is not officially tested or supported by Veeam. The commands used are themselves supported, since they are offered directly through the product.

**This is an advanced manual process. If you are unsure what to do, it is recommended to contact your technical Veeam partner for assistance.**

Always check the Veeam Backup for Microsoft 365 PowerShell Reference in this limited-access version of the [Help Center](https://helpcenter.veeam.com/archive/vbo365/8.6/powershell_private/backup_data.html), which includes the hidden cmdlets.

## Hints for commands
Most commands require objects as input. For example, the Start-VBODataMigration cmdlet requires a job or organization object and repository objects, depending on the run mode. These objects can be retrieved with Get-VBOJob, Get-VBOOrganization and Get-VBORepository.

## Important to know
- **Veeam Backup for Microsoft 365** is abbreviated as **VB365** in this document.
- The commands must be run in **PowerShell v7**, which is the default if started from the VB365 GUI.
- It is highly recommended to run migrations with **VB365 v8.6 or newer**.
- Import the VB365 PowerShell module by its DLL path in PowerShell 7: Import-Module 'C:\Program Files\Veeam\Backup365\Veeam.Archiver.PowerShell.dll'. Some cmdlets used in this process, such as Get-VBORepositoryInventoryReport, are only available when the module is imported this way. They are described in the limited-access reference mentioned above. The scripts in this folder import the DLL by default (parameter -ArchiverModulePath).
- Migration job log files are stored only on the target proxy that processes the migration. If the target object storage repository is bound to a proxy pool, check the logs on all proxies in the pool.
- This migration option is only supported from **Jet repositories to object storage repositories**.
- You can migrate from Jet repositories with item-based retention to object storage repositories with snapshot-based retention. Be aware that the target repository retention settings will be used once the migration lock has been removed. Additionally, take into consideration that the first backup job run on the object storage repository might download new data to fulfill the snapshot-based retention. It is recommended that you become familiar with the two different types of retention: [Help Center - Retention](https://helpcenter.veeam.com/docs/vbo365/guide/retention_policy.html).
- The target object storage repository **must not** have immutability enabled.
- Migration from multiple Jet repositories to a single object storage repository is currently **not** supported.
- Make sure that port 9193 is open between the proxy servers, including the default proxy on the VB365 server.
- Disk repositories are always bound to a single Windows-based proxy.
- Subsequence migration runs can use bookmarks stored in the target repositories for Mailbox folder/items, SharePoint list items and SharePoint list views. Fully processed during re-runs are other data like sites, list metadata, web change tokens, web parts and most Teams data. The data is not duplicated in the target Repository but currently needs to be read and processed for consistency checks from source repository by the assigned proxy to the target proxy.
- The -Full parameter of Start-VBODataMigration will force wipe out related bookmarks in the target repository and read all items fully from source again. No duplication will be done on the target repository if the items are identical.
- Monitor the saturation of source and target proxy, VB365 Controller (Server), PostgreSQL server and NATS server during migrations. It might be necessary to temporarily add additional compute resources, especially when running source jobs in parallel. Based on experience from production environments, it is recommended to add around 50% more CPU and RAM on the source proxy holding the Jet repository.

## Workflow overview

1. Disable retention on the source proxy
2. Enable Data Migration feature
3. Start migration to an empty target repository
4. Monitor status until you see Success or Warning
5. Manage migration jobs
6. Verify data consistency by comparing source and target repository inventory reports
7. Remove migration lock to enable regular use of the target repository
8. (optional) Enable retention on the source proxy

## Migration scenarios
### Single source job
#### Situation
    A single source job is writing to a Jet repository.
    The job runs on a frequent schedule and might run during the initial migration.
    The migration should target an object storage repository.
#### Advice
    This is a supported scenario and the -SwitchJobToTargetRepository parameter should be used.
    Use the -Job parameter to target the migration for this specific source job.
    If the -SwitchJobToTargetRepository parameter was used, the source job will be disabled once the migration has finished successfully.

### Multiple source jobs on the same repository
#### Situation
    Multiple source jobs are writing to the same Jet repository.
    The job runs on a frequent schedule and might run during the initial migration.
    The migration should target an object storage repository.
#### Advice
    This is a supported scenario and the -SwitchJobToTargetRepository parameter can be used if desired.
    Use the -Organization parameter to target the migration for the whole source repository. This will affect all jobs targeting this repository and if the -SwitchJobToTargetRepository parameter was used, the jobs will be disabled once the migration has finished successfully.
    It is possible to use job-based migration from the same source repository as long as the migration lock is in place on the target repository.
    Only use Remove-VBODataMigrationLock once all data has been migrated!

### Multiple source repositories to a single repository
#### Situation
    Multiple source jobs are writing to different Jet repositories.
    The migration should target a single object storage repository for these multiple source Jet repositories.
#### Advice
    This is not a supported scenario!

## Workflow steps in detail
### 1. Disable retention on the source proxy

#### Purpose
Prevents the retention cleanup job from deleting recently migrated data, which can cause verification errors.
#### Outcome
Disables retention for all repositories on the source proxy, ensuring all data remains on the source during migration.
#### Execute
```
Set-VBOConfigurationParameter -XPath "/Veeam/Archiver/RepositoryConfig" -Key "RetentionDisabled" -Value "True" -Proxy <proxy>
```
#### Notes
The <proxy> parameter is a VB365 proxy object, which can be retrieved with the Get-VBOProxy cmdlet.
Example:
```
$proxy = Get-VBOProxy -Hostname proxy01
Set-VBOConfigurationParameter -XPath "/Veeam/Archiver/RepositoryConfig" -Key "RetentionDisabled" -Value "True" -Proxy $proxy
```
### 2. Enable Data Migration feature
#### Purpose
Some data migration-related cmdlets are disabled by default and must be enabled first.
#### Execute
```
[Environment]::SetEnvironmentVariable("VEEAM_DATA_MIGRATION_ENABLED", "true")
```
#### Notes
A variable set this way persists only for the current PowerShell session. If you need it frequently, set it as a system-wide environment variable.

### 3. Start migration to an empty target repository
#### Purpose
Begins the migration of data from a source repository to a target repository.
#### Prerequisites
The target repository must be empty. Starting a migration creates a migration lock on the target repository, restricting its use to the ongoing migration only.
#### Execute
An example script with a GUI wrapper can be found in this folder: *VB365-JetToOsrMigration-GUI.ps1*

The manual start of a migration can be done in the following ways:

Job mode:
```
Start-VBODataMigration -Job <VBOJob> -To <VBORepository> [-SwitchJobToTargetRepository] [-RunAsync]
```
Organization mode:
```
Start-VBODataMigration -Organization <VBOOrganization> -From <VBORepository> -To <VBORepository> [-SwitchJobToTargetRepository] [-RunAsync]
```
#### Outcome
Returns a migration session object including the JobID for tracking progress. If run with the *-RunAsync* parameter, the object will be returned immediately.
#### Notes
If you use the *-SwitchJobToTargetRepository* parameter, the job switches only after a successful migration. If the migration finishes with errors or warnings, the switch does not occur. After switching, the job remains disabled until you perform the migration verification check and remove the migration lock.

### 4. Monitor status
#### Purpose
Tracks the status of the migration session using the job ID.
Key status values:
- Success: Migration completed successfully.
- Warning: Migration completed with non-critical warnings.
- Failed: Migration failed.
- Running, Stopped, etc.: Indicates current progress/state.
#### Execute
To get the status of all migration jobs:
```
Get-VBODataMigration
```
To get the status of a specific migration job:
```
Get-VBODataMigration -Id <JobID>
```

### 5. Manage migration jobs
If you need to suspend, resume or stop a migration job, use the
*Suspend-VBODataMigration*, *Resume-VBODataMigration* and *Stop-VBODataMigration* cmdlets.
#### Execute
Get the object for the migration to manage:
```
$migration = Get-VBODataMigration -Id <JobID>
```
Suspend a migration:
```
Suspend-VBODataMigration -Migration $migration
```
Resume a migration:
```
Resume-VBODataMigration -Migration $migration [-RunAsync]
```
Stop a migration and end the process:
```
Stop-VBODataMigration -Migration $migration
```
#### Notes
When a migration is stopped, the backup job is not switched and the target repository is not unlocked.
Managing migration jobs with these commands might take a moment to complete.

### 6. Verify Data Consistency
#### Purpose
Export inventory reports from both the source and target repositories for comparison, in order to verify that all items were successfully migrated. The Verification PowerShell Script *VB365-JetToOsrVerification.ps1* in this folder can be used to compare the data.
#### Outcome
No differences should be found between source and target. If any differences are detected, it could indicate data loss during the migration process. In such a case, run the migration again, and if the issue persists, open a support ticket.
#### Execute
Run the *VB365-JetToOsrVerification.ps1* script and make the required selections before starting the verification.
```
.\VB365-JetToOsrVerification.ps1 [-ReportPath <String>] [-ArchiverModulePath <String>]
```
- *-ReportPath*: base folder for the reports (default: `C:\VBOMigrationVerificationReports`). It is created if it does not exist.
- *-ArchiverModulePath*: path to the VB365 PowerShell module DLL (default: `C:\Program Files\Veeam\Backup365\Veeam.Archiver.PowerShell.dll`).

The manual equivalent uses the *Get-VBORepositoryInventoryReport* cmdlet for the source and the target repository:
```
Get-VBORepositoryInventoryReport -OutputPath <String> -BackupTime <DateTime> -Repository <VBORepository> -Organization <VBOOrganization> [-IncludeDeleted] [-IncludeAllVersions]
Get-VBORepositoryInventoryReport -OutputPath <String> -BackupTime <DateTime> -Repository <VBORepository> -Job <VBOJob> [-IncludeDeleted] [-IncludeAllVersions]
```
#### Output
Each run writes into its own subfolder named after the run start time, e.g. `C:\VBOMigrationVerificationReports\20261118_150211\`:
- Inventory report CSV files (Mailboxes, SharePoint sites, Teams, OneDrive) for source and target.
- *MismatchSummary.txt* (only if mismatches are found): organization, validation scope, source/target repository, restore point and the mismatching records per data type.

Exit code: `0` if no differences were found, `1` if mismatches were found (shown as a warning in the console).
#### Notes
The script in this folder is provided to simplify data verification.

### 7. Remove migration lock
#### Purpose
Removes the migration lock from the target repository and enables the jobs to allow normal operations such as backups and retention jobs.
#### Execute
```
$repository = Get-VBORepository -Id <RepositoryID>
Remove-VBODataMigrationLock -Repository $repository
```
#### Notes
Once the lock is removed, you cannot start any further data migration into this repository. You can use the *Remove-VBODataMigrationLock-GUI.ps1* script to do this using a graphical interface.

### 8. (Optional) Enable retention on the source proxy
#### Purpose
Re-enables retention cleanup for the source repositories on a proxy.
#### Outcome
Re-enables retention for all repositories on the source proxy.
#### Execute
```
Set-VBOConfigurationParameter -XPath "/Veeam/Archiver/RepositoryConfig" -Key "RetentionDisabled" -Value "False" -Proxy <proxy>
```
#### Notes
Only perform this step once all required migrations from this proxy are completed.
