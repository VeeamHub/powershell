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

## Limitations

* Matching of SPO sites and Teams is based on the SPO URL and the Team's e-mail address. 
  Both don't change when a team is renamed.
* Includes and Excludes will only work on primary site level

## Known Issues

* New jobs will currently always be created starting with the first repo in the list
* The base schedule will be delayed for every job in sequence, but not based on which proxy they are configured

## Requirements

All scripts are designed to be executed on the VB365 server.

* Veeam Backup for Microsoft 365 v6

## Usage Examples

```powershell
./vb365-spo-teams-jobs.ps1 -Organization "my-org.onmicrosoft.com" -Repositories Proxy1-Repo1,Proxy1-Repo2,Proxy2-Repo1,Proxy2-Repo2 -objectsPerJob 200
```

Will add all SharePoint sites which are currently not in backup to jobs and search for matching Teams during the process to add them to the same job.


