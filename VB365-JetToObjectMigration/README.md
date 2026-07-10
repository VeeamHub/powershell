# Veeam Backup for Microsoft 365 - Jet to Object Storage Migration
This project has the goal to support in migrating backup data from disk Repositories to object storage Repositories.

## Important note:
Please be aware that the provided code is only seen as examples and is not officially tested and supported by Veeam. The used commands themself are supported, since they are offered directly through the product.
Always check the offical Veeam Backup for Microsoft 365 PowerShell Reference in this limited access [Helpcenter](https://helpcenter.veeam.com/archive/vbo365/8.5/powershell_private/backup_data.html) version including the hidden comdlets.

## Hint for commands
Most commands require some objects to run. For example, the Start-VBODataMigration cmdlet requires objects like job, repositories or proxy, depending on the run mode. These objects can be created with Get-VBORepository and Get-VBOProxy etc.

## Important to know
- **Veeam Backup for Microsoft 365** will be called **VB365** as an acronym in this document.
- the commands must be run in PowerShell v7, which is default if started from the VB365 GUI.
- It is highly recommended to run migrations with **VB365 v8.5 or newer**.
- This migration option is only supported from **Jet to Object Storage Repositories**.
- The target Object Storage Repository can **not** have immutability enabled.
- Migration from multiple Jet Repositories to a single Object Storage Repository is currently **not** supported.
- Make sure that port 9193 is opened between the proxy servers, including the default proxy on the VB365 server.
- Disk repositories are always bound to a single windows-based Proxy.
- Subsequence migration runs can use bookmarks stored in the target repositories for Mailbox folder/items, Pharepoint list items and Sharepoint list views. Fully processed during re-runs are other data like sites, list metadata, web change tokens, web parts and most Teams data. The data is not duplicated in the target Repository but currently needs to be read and processed for consistency checks from source repository by the assigned proxy to the target proxy.
- The -Full parameter of Start-VBODataMigration will force wipe out related bookmarks in the target repository and read all items fully from source again. No duplication will be done on the target repository if the items are identical.
- Monitor the saturation of source and target Proxy, VB365 Controller (Server), PostgreSQL server and NATS server during migrations. It might be necessary to temporarily add additional compute resources, especially when running source jobs in parallel. From experiences of runs in production environments it is recommended to add around 50% more CPU and MEM on the source Proxy holding the Jet Repository.

## Workflow overview

1. Disable retention on the source proxy
2. Enable Data Migration feature
3. Start migration to an empty target repository
4. Monitor status until you see Success or Warning
5. Manage migrations
6. Verify data consistency by comparing source and target repository inventory reports
7. Remove migration lock to enable regular use of the target repository
8. (optional) Enable retention on the source proxy

## Migration Scenarios
### Single source job
#### Situation
    A single source job is writing to a Jet Repository. 
    The Schedule is frequently and might be running in between the initial migration run.
    The migration should target an object storage Repository.
#### Advice
    This is a supported scenario and the -SwitchJobToTargetRepository paramter should be used. 
    Use the -Job parameter to target the migration for this specific source job.
    If the -SwitchJobToTargetRepository parameter was true, the source job will be disabled once the migration could successfully finish.

### Multiple source jobs on same Repository
#### Situation
    Multiple source jobs are writing to the same Jet Repository. 
    The Schedule is frequently and might be running in between the initial migration run.
    The migration should target an object storage Repository. 
#### Advice
    This is a supported scenario and the -SwitchJobToTargetRepository paramter can be used when planned. 
    Use the -Organization parameter to target the migration for the whole source Repository. This will effect all jobs targeting this repository and if the -SwitchJobToTargetRepository parameter was true, the jobs will be disabled once the migration could successfully finish.
    It is possible to use job based migration from the same source repository as long as the MigrationLock is on place on the target repository.
    Only use Remove-VBODataMigrationLock once all data has been migrated!

### Multiple source Repositories to a single Repository
#### Situation
    Multiple source jobs are writing to different Jet Repositories.
    The migration should target a single object storage Repository for these multiple source Jet Repositories.
#### Advice
    This is not a supported scenario!

## Workflow steps in detail
### 1. Disable retention on the source proxy

#### Purpose
Prevents the retention cleanup job from deleting recently migrated data, which can cause verification errors.
#### Outcome
Disables retention for the source repository, ensuring all data remains on the source during migration.
#### Execute
```
Set-VBOConfigurationParameter -XPath "/Veeam/Archiver/RepositoryConfig" -Key "RetentionDisabled" -Value "True" -Proxy {proxy}
```
#### Notes
The {proxy} parameter is a VB365 Proxy object which needs to be created with the Get-VBOProxy cmdlet. 
Example:
```
$proxy = Get-VBOProxy -Hostname proxy01
Set-VBOConfigurationParameter -XPath "/Veeam/Archiver/RepositoryConfig" -Key "RetentionDisabled" -Value "True" -Proxy $proxy
```
### 2. Enable Data Migration feature
#### Purpose
Some Data Migration related cmdlets are disabled by default and they must be enabled first.
#### Execute
```
[Environment]::SetEnvironmentVariable("VEEAM_DATA_MIGRATION_ENABLED", "true")
```
#### Notes
Setting this in a PowerShell session is only kept for the current session. If needed frequently please add this variable globally in the system.

### 3. Start migration to an empty target repository
#### Purpose
Begins the migration of data from a source repository to a target repository
#### Prerequisites 
The target repository must be empty. Starting a migration creates a migration lock on the target repository, restricting its use to ongoing migration only.
#### Execute
An example script with a GUI wrapper can be found within in this folder: *VB365-JetToOsrMigration-GUI.ps1*

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
Returns a migration session ID (JobId) for tracking progress if run with *-RunAsync*
#### Notes
If you use the *-SwitchJobToTargetRepository* parameter, the job switches only after a successful migration. If themigration finishes with errors or warnings, the switch does not occur. After switching, the job remains disabled until you perform the migration verification check and remove migration lock.

### 4. Monitor status
#### Purpose
Tracks the status of the migration session using the session ID.
Key status values:
- Success: Migration completed successfully.
- Warning: Migration completed with non critical warnings.
- Failed: Migration failed.
- Running, Stopped, etc.: Indicates current progress/state.
#### Execute
To get the status of all migration jobs:
```
Get-VBODataMigration
```
To get the status of a specific migration job:
```
Get-VBODataMigration -id <JobID>
```

### 5. Manage migration jobs
In case it is needed to suspend or stop a migration job, the commands 
*Suspend-VBODataMigration* , *Resume-VBODataMigration* and *Stop-vBODataMigration* can be used.
#### Execute
Get the object for the migration to manage:
```
$migration = Get-VBODataMigration -id <JobID>
```
Suspend a migration:
```
Suspend-VBODataMigration -migration $migration
```
Resume a migration:
```
Resume-VBODataMigration -migration $migration [-RunAsync]
```
Stop a migration and end the process:
```
Stop-VBODataMigration -migration $migration
```
#### Notes
When a migration is stopped, no switch of the backup job or unlocking is taking place.
Managing migration jobs with these commands might take a moment to complete.

### 6. Verify Data Consistency
#### Purpose
Export inventory reports from both the source and target repositories for comparison, in order to verify that all items were successfully migrated. The Verification PowerShell Script *VB365-JetToOsrVerification-GUI.ps1* in this folder can be used to compare the data.
#### Outcome 
No differences should be found between source and target. If any differences are detected, it could indicate a data loss during the migration process. In such case, try to run the migration again and if the issue persists, open a support ticket.
#### Execute
Run the *VB365-JetToOsrVerification-GUI.ps1* and perform the selections as needed before starting the verification.
#### Notes
The provided script in this folder is provided to ease the process for data verification.

### 7. Remove Migration Lock 
#### Purpose
Removes the migration lock from the target repository and enables the jobs to allow normal operations such as backups and retention jobs.
#### Execute 
```
$repository = Get-VBORepository -id <RepositoryID>
Remove-VBODataMigrationLock -Repository $repository
```
#### Note
Once the lock is removed, you cannot repeat the migration for the same data set. You can use the *Remove-VBODataMigrationLock-GUI.ps1* script to do this in a graphical UI.

### 8. Enable retention 
#### Purpose
Put back the retention cleanup for the source repositories on a proxy.
#### Outcome
Enables back the retention for all repositories on the source proxy
#### Execute
```
Set-VBOConfigurationParameter -XPath "/Veeam/Archiver/RepositoryConfig" -Key "RetentionDisabled" -Value "False" -Proxy <proxy>
```
#### Notes
Only perform this step once all required migrations from this proxy are completed.