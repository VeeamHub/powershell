# A script to automate the creation and operation of SharePoint and Teams jobs

## Author

* Stefan Zimmermann ([StefanZ8n](https://github.com/StefanZ8n))
  
## Help

```
SYNTAX
    .\vb365-JobManager.ps1 -Organization <OrganizationName> -Repository <Repo1>[,Repo2,...] [[-objectsPerJob] <Int32>] [[-limitServiceTo] <String>] [[-jobNamePattern] <String>] [-withTeamsChats] [[-baseSchedule] <Object>] [[-scheduleDelay] <String>] [[-includeFile] <String>] [[-excludeFile] <String>] [-recurseSP] [-checkBackups] [[-countTeamAs] <Int32>] [<CommonParameters>]
    
    
DESCRIPTION
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
    

PARAMETERS
    -Organization <OrganizationName>
      The name of in VB365 registered M365 organization.
      This parameter resolves automatically and tab-completion can be used.

    -Repository <Repo1>[,<Repo2>,...]
      A list of repositories to use when building new backup jobs.
      When multiple repositories are given the created jobs will be distributed randomly on the repositories.
      This parameter resolves automatically and tab-completion can be used.

    -objectsPerJob <Int32>
        Maximum number of objects per job
        When backing up teams the maximum is this number-1 because teams should be grouped with sites
        
    -limitServiceTo <String>
        Limit processed service to either only SharePoint or Teams
        
    -jobNamePattern <String>
        Format string to build the jobname. {0} will be replaced with the number of the job and can be formatted as PowerShell format string
        {0:d3} will create a padded number. 2 will become 002, 12 will become 012
        
    -withTeamsChats [<SwitchParameter>]
        Include chats in Teams backups
        
    -baseSchedule <Object>
        Base schedule for 1st job
        Must be a VBO Schedule Policy like created with `New-VBOJobSchedulePolicy`
        
    -scheduleDelay <String>
        Delay between the starttime of two jobs in HH:MM:SS format
        
    -includeFile <String>
        Path to file with patterns to include when building jobs
        Checks patterns against Site/Teams names and SharePoint URLs
        Patterns are case sensitive matched with regular expression syntax
        Specify one pattern per line and all will be checked    
        Includes will be processed before excludes
        If not set will try to load a file with the same name as the script and ending ".includes"
        
    -excludeFile <String>
        Path to file with patterns to exclude when building jobs 
        Checks patterns against Site/Teams names and SharePoint URLs
        Patterns are case sensitive matched with regular expression syntax
        Specify one pattern per line and all will be checked
        Excluded objects won't  won't be added to jobs, they won't be excluded
        Excludes will be processed after includes
        If not set will try to load a file with the same name as the script and ending ".excludes"
        
    -recurseSP [<SwitchParameter>]
        Recurse through SharePoint sites to count subsites when sizing jobs
        
    -checkBackups [<SwitchParameter>]
        Check if backups exist in given repositories and align objects to jobs pointing to these repositories
        
    -countTeamAs <Int32>
        Count a Team as this many objects. 
        Teams consist of Exchange, SharePoint and Teams objects, thus having higher object load than other services
```



## Limitations

* Matching of SPO sites and Teams is based on the SPO URL and the Team's e-mail address. 
  Both don't change when a team is renamed, but it's not guaranteed to match, e.g. when SP sites are in the bin with the same name a `-2` is added for a new team.
* Includes and excludes will only work on primary site level
* Scheduling delays will be based on repository expecting one repository per proxy (so two jobs on two proxies can start at the same time)
* There is currently no way to update the json meta-data in the description
* Not all schedule options will be used for new jobs. 
  Only Type, DailyType and DailyTime are taken from the base schedule.

## Known Issues

* When the jobname sequence is interrupted not all jobs will be considered and the need to create two more jobs will fail
  e.g. when the jobs `job-01`, `job-02` and `job-04` exist, `job-04` won't be considered for load balancing objects and after creating `job-03` creating the next job will fail (as `job-04` already exists)
* If no jobs are present the first one will be scheduled at base-schedule + schedule delay (resulting schedule will be `22:30` by default)
* If objects are removed from the backup job the internal count for objects in the job does not change (it is based on the json data in the description)
* Periodic schedules might not work

## Glossary

### Object Weight
You will find **weight** or **object weight** across the documentation and script.
VB365 sizing is based on object counts, but not each object is the same.
That's why I came up with the **weight** of an object.

Here are two examples:

Let's assume we have to SP sites.
SiteA is a simple site with no subsites, while SiteB has 100 subsites.
From a joblevel you just add SiteA and SiteB and they'll appear as two objects within  the job configuration in VB365.
At runtime the sites will be resolved and SiteA resolves to a single object, while SiteB resolves to 101 objects.
This resolving will happen at script runtime with the paramter `-recurseSP` to add SiteB with a weight of 101 to the job instead of just a weight of 1.

Teams consist of multiple services and such are more to handle for VB365. 
Each Team has an Exchange Mailbox, a SharePoint site and Teams-native components.
As a Mailbox and a SharePoint site for itself would count as 2 objects, the weight of a Team can be estimated as 3 objects (default).
This factor can be changed with the `-countTeamsAs` parameter.

## Requirements

All scripts are designed to be executed on the VB365 server.

* Veeam Backup for Microsoft 365 v6

## Usage Examples

Adds all SharePoint sites which are currently not in backup to jobs and search for matching Teams during the process to add them to the same job.
Limit the counted objects to 200 per job while each SP site will be counted as 1 and each team as 3.

```powershell
./vb365-JobManager.ps1 -Organization "my-org.onmicrosoft.com" -Repository Proxy1-Repo1,Proxy1-Repo2,Proxy2-Repo1,Proxy2-Repo2 -objectsPerJob 200
```

Adds all SPO and teams to backup jobs but recurses every single SP site for subsites to calculate the real object weight which will be respected for `-objectsPerJob`

```powershell
./vb365-JobManager.ps1 -Organization "my-org.onmicrosoft.com" -Repository Proxy1-Repo1,Proxy1-Repo2 -recurseSP -objectsPerJob 200
```

