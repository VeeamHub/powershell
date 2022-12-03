# A script to automate the creation and operation of SharePoint and Teams jobs

## Author

* Stefan Zimmermann ([StefanZ8n](https://github.com/StefanZ8n))
  
## Function

Create and maintain SharePoint Online and Teams jobs in VB365. 
The script offers the following major features:

- Creates backup jobs for all processed objects respecing a maximum number of objects per job
- Round robins through a list of repositories for created jobs
- Reuses jobs matching the naming scheme which can still hold objects
- Puts Sharepoint sites and matching teams to the same job
- Schedules created jobs with a delay to not start all at the same time
- Can work with include and exclude patterns from files (regex)
- Object count can be configured for Teams
- Sharepoint subsites can be counted as objects and are respected in the objectcount (`-recurseSP`)

## Paramters

**Usage**
```powershell
.\VB365-JobManager.ps1 -Organization <OrganizationName> -Repository <Repo1>[,Repo2,...] [-objectsPerJob <number>] [-limitServiceTo SharePoint|Teams] [-withTeamsChats] [-baseSchedule <VBOSchedulePolicy>] [-scheduleDelay "HH:MM:SS"] [-includeFile <FilePath>] [-excludeFile <FilePath>] [-recurseSP] [-checkBackups] [-countTeamAs <int>]
```

`-Organization <OrganizationName>` (required)
> The name of in VB365 registered M365 organization.
> This parameter resolves automatically and tab-completion can be used.

`-Repository <Repo1>[,<Repo2>,...]` (required)
> A list of repositories to use when building new backup jobs.
> When multiple repositories are given the created jobs will be distributed randomly on the repositories.
> This parameter resolves automatically and tab-completion can be used.

## Limitations

* Matching of SPO sites and Teams is based on the SPO URL and the Team's e-mail address. 
  Both don't change when a team is renamed.
* Includes and Excludes will only work on primary site level

## Known Issues

* When the jobname sequence is interrupted not all jobs will be considered and the need to create two more jobs will fail
  e.g. when the jobs `job-01`, `job-02` and `job-04` exist, `job-04` won't be considered for load balancing objects and after creating `job-03` creating the next job will fail (as `job-04` already exists)
* The base schedule will be delayed for every job in sequence, but not based on which proxy they are configured

## Requirements

All scripts are designed to be executed on the VB365 server.

* Veeam Backup for Microsoft 365 v6

## Usage Examples

```powershell
./vb365-JobManager.ps1 -Organization "my-org.onmicrosoft.com" -Repositories Proxy1-Repo1,Proxy1-Repo2,Proxy2-Repo1,Proxy2-Repo2 -objectsPerJob 200
```

Will add all SharePoint sites which are currently not in backup to jobs and search for matching Teams during the process to add them to the same job.


