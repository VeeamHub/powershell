# A script to automate the creation and operation of SharePoint and Teams jobs

## Author

* AUTHOR Tim Smith (https://tsmith.co)
  
## Help

```
SYNTAX
     .\remove-deleted-sites.ps1 -Organization <String> [-JobNamePattern <String>] [-EmptyJobAction <String>]
    
    
DESCRIPTION
     The `remove-deleted-sites.ps1` script identifies SharePoint sites that fail with HTTP 404 errors in recent Veeam Backup for Microsoft 365 job sessions and removes them from their respective backup jobs. It uses job session logs to detect inaccessible sites (e.g., deleted in Microsoft 365) and updates jobs accordingly. If removing a site would leave a job with no items (which Veeam prohibits), the script can disable and rename the job, remove it, or disable it without renaming, based on the `-EmptyJobAction` parameter.
     
     The script logs all actions to a timestamped file in a `logs` subfolder for auditing and troubleshooting.
    

PARAMETERS
    - Organization <String>
        Description: The name of the Microsoft 365 organization (e.g., "M365x75724141.onmicrosoft.com").
        Mandatory: Yes
        Example: `-Organization "M365x75724141.onmicrosoft.com"`

    -JobNamePattern <String>`
        Description: The naming pattern for jobs to process. Uses a format string with a numeric placeholder (e.g., "SharePointTeams-{0:d3}" for "SharePointTeams-001").
        Mandatory: No
        Default: "SharePointTeams-{0:d3}"
        Example: `-JobNamePattern "MyBackupJobs-{0:d2}"`

    - EmptyJobAction <String>`
        Description**: Specifies what to do if removing sites would empty a job (Veeam requires at least one item per job).
        Mandatory: No
        Default: "DisableAndRename"
        Valid Values:
          `DisableAndRename`: Disables the job and renames it (e.g., "SharePointTeams-001_Empty_Disabled").
          `Remove`: Deletes the job entirely.
          `DisableOnly`: Disables the job without renaming.
        Example: `-EmptyJobAction "Remove"`
```



## Limitations

* Scope: Only processes SharePoint sites (not Teams or other object types) identified by 404 errors in job logs.
* Job Session Dependency: Requires recent job runs with "Warning" or "Failed" status to detect inaccessible sites. If no recent logs exist, no sites will be removed.
* Veeam Constraint: Cannot remove the last item from a job due to Veeam’s requirement of at least one item per job, hence the `-EmptyJobAction` handling.
* PowerShell Only: Disabling via `Disable-VBOJob` prevents runs, but some UI states (e.g., full gray-out) might depend on Veeam’s internal flags not fully exposed in PowerShell v8.

## Known Issues

 * Trailing Periods in Logs: Early versions failed to match URLs due to trailing periods in job log entries (e.g., "https://.../ContosoBrand."). Fixed in v1.0.2 by stripping these periods.
* Parameter Errors: Initial attempts used invalid parameters like `Set-VBOJob -EnableSchedule` (fixed in v1.0.4) and schedule manipulation (v1.0.5), now resolved with `Disable-VBOJob` in v1.0.6.
* No Validation: Doesn’t verify if `Remove-VBOBackupItem` or `Disable-VBOJob` succeeds (e.g., due to permissions). Errors are silently ignored with `-WarningAction:SilentlyContinue`.

## Glossary

### 404 Error 
HTTP status code indicating a site is not found, typically because it was deleted in Microsoft 365.
### VBO
Veeam Backup for Microsoft 365. Also known as VB365
### Job Session
A record of a backup job’s execution, including logs of successes and failures.
### Backup Item
An object (e.g., SharePoint site) included in a Veeam backup job.


## Requirements

All scripts are designed to be executed on the VB365 server.

* PowerShell Version**: 5.0 or later
* Module: `Veeam.Archiver.PowerShell` (part of Veeam Backup for Microsoft 365 v8)
* Permissions: User must have rights to manage Veeam jobs (e.g., read job sessions, modify/remove items, disable jobs).
* Environment: Veeam Backup for Microsoft 365 v8 installed and configured with access to the target organization.

## Usage Examples

Adds all SharePoint sites which are currently not in backup to jobs and search for matching Teams during the process to add them to the same job.
Limit the counted objects to 200 per job while each SP site will be counted as 1 and each team as 3.

 1. **Default Run (Disable and Rename Empty Jobs)**:

    ```powershell
    .\remove-deleted-sites-jobstatus.ps1 -Organization "M365x75724141.onmicrosoft.com"
    ```

    - Removes deleted sites from jobs matching "SharePointTeams-{0:d3}".
    - Disables and renames jobs that would become empty (e.g., "SharePointTeams-022_Empty_Disabled").

 2. **Remove Empty Jobs**:

    ```powershell
    .\remove-deleted-sites-jobstatus.ps1 -Organization "M365x75724141.onmicrosoft.com" -EmptyJobAction "Remove"
    ```

    - Deletes jobs entirely if they’d become empty after removing deleted sites.

 3. **Disable Only (No Rename)**:

    ```powershell
    .\remove-deleted-sites-jobstatus.ps1 -Organization "M365x75724141.onmicrosoft.com" -EmptyJobAction "DisableOnly"
    ```

    - Disables jobs that would become empty without changing their names.

 4. **Custom Job Pattern**:

    ```powershell
    .\remove-deleted-sites-jobstatus.ps1 -Organization "M365x75724141.onmicrosoft.com" -JobNamePattern "CustomBackup-{0:d2}"
    ```

    - Targets jobs like "CustomBackup-01" instead of the default pattern.


## Sample Log Output

 ```
 2025-03-19 23:XX:XX: Starting deleted sites removal using job status
 2025-03-19 23:XX:XX: Organization: M365x75724141.onmicrosoft.com
 2025-03-19 23:XX:XX: JobNamePattern: SharePointTeams-{0:d3}
 2025-03-19 23:XX:XX: EmptyJobAction: DisableAndRename
 2025-03-19 23:XX:XX: Found 25 jobs
 2025-03-19 23:XX:XX: Identified 3 inaccessible sites: https://m365x75724141.sharepoint.com/sites/Design, https://m365x75724141.sharepoint.com/sites/give, https://m365x75724141.sharepoint.com/sites/ContosoBrand
 2025-03-19 23:XX:XX: Processing job: SharePointTeams-022
 2025-03-19 23:XX:XX: Job SharePointTeams-022 would become empty after removal
 2025-03-19 23:XX:XX: Disabling and renaming job SharePointTeams-022 to SharePointTeams-022_Empty_Disabled
 2025-03-19 23:XX:XX: Processing job: SharePointTeams-024
 2025-03-19 23:XX:XX: Removing site https://m365x75724141.sharepoint.com/sites/ContosoBrand (ID: 0f0e18c0-fc1a-4cf7-8acc-446d2c136455) from job SharePointTeams-024
 2025-03-19 23:XX:XX: Removed 1 deleted sites and modified 2 jobs
 ```