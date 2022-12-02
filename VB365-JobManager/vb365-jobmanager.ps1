
<#PSScriptInfo

.VERSION 0.7.0

.GUID f3795945-b130-4740-84f4-e8248a847263

.AUTHOR Stefan Zimmermann <stefan.zimmermann@veeam.com>

.COMPANYNAME

.COPYRIGHT

.TAGS Veeam Backup for Microsoft 365

.LICENSEURI https://github.com/VeeamHub/powershell/blob/master/LICENSE

.PROJECTURI https://github.com/VeeamHub/powershell

.ICONURI

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES
IN DEVELOPMENT

.PRIVATEDATA

#>

#Requires -Module Veeam.Archiver.PowerShell

<# 

.DESCRIPTION 
 Script to automatically create and maintain Sharepoint and Teams backup jobs in Veeam Backup for Microsoft 365.
 The script delivers the following major features:
 - Creates backup jobs for all processed objects respecing a maximum number of objects per job
 - Round robins through a list of repositories for created jobs
 - Reuses jobs matching the naming scheme which can still hold objects
 - Puts Sharepoint sites and matching teams to the same job
 - Schedules created jobs with a delay to not start all at the same time
 - Can work with include and exclude patterns
 
#> 
[CmdletBinding()]
Param(        
    [Parameter()]
    # Maximum number of objects per job
    # When backing up teams the maximum is this number-1 because teams should be grouped with sites
    [int] $objectsPerJob = 500,

    # Limit processed service to either only SharePoint or Teams
    [String][ValidateSet("SharePoint", "Teams")] $limitServiceTo = $null,

    # Format string to build the jobname. {0} will be replaced with the number of the job and can be formatted as PowerShell format string
    # {0:d3} will create a padded number. 2 will become 002, 12 will become 012
    [string] $jobNamePattern = "SharePointTeams-{0:d3}",

    # Include chats in Teams backups
    [switch] $withTeamsChats = $false,

    # Base schedule for 1st job
    # Must be a VBO Schedule Policy like created with `New-VBOSchedulePolicy`
    [Object] $baseSchedule = $null,

    # Delay between the starttime of two jobs in HH:MM:SS format
    [string] $scheduleDelay = "00:30:00",

    # Path to file with patterns to include when building jobs
    # Checks patterns against Site/Teams names and SharePoint URLs
    # Patterns are case sensitive matched with regular expression syntax
    # Specify one pattern per line and all will be checked    
    # Includes will be processed before excludes
    # If not set will try to load a file with the same name as the script and ending ".includes"    
    [string] $includeFile = $null,

    # Path to file with patterns to exclude when building jobs 
    # Checks patterns against Site/Teams names and SharePoint URLs
    # Patterns are case sensitive matched with regular expression syntax
    # Specify one pattern per line and all will be checked
    # Excluded objects won't  won't be added to jobs, they won't be excluded
    # Excludes will be processed after includes
    # If not set will try to load a file with the same name as the script and ending ".excludes"    
    [string] $excludeFile = $null,

    # Recurse through SharePoint sites to count subsites when sizing jobs
    [switch] $recurseSP = $false,

    # Check if backups exist in given repositories and align objects to jobs pointing to these repositories
    [switch] $checkBackups = $false,

    # Count a Team as this many objects. 
    # Teams consist of Exchange, SharePoint and Teams objects, thus having higher object load than other services
    [int] $countTeamAs = 3,
    
    # Read grouping patterns from JSON formatted file
    # Entries like:
    # {	'jobnamePattern' : 'ing-group-{0:d2}', 'matchPattern': '^.*ing$' }
    # Matches Teams/Site names and SharePoint URLs as includes/excludes
    # If not set will try to load a file with the same name as the script and ending ".excludes"    
    [string] $groupFile = $null


)
DynamicParam {
    Import-Module Veeam.Archiver.PowerShell
    $RuntimeParameterDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary 

    # Organizations
    $OrganizationParameter = 'Organization'        
    $AttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
    $ParameterAttribute = New-Object System.Management.Automation.ParameterAttribute    
    $ParameterAttribute.Mandatory = $true
    $AttributeCollection.Add($ParameterAttribute)    
    $arrSet = Get-VBOOrganization | select -ExpandProperty Name    
    $ValidateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute($arrSet)    
    $AttributeCollection.Add($ValidateSetAttribute)    
    $ValidateNotNullOrEmptyAttribute = New-Object System.Management.Automation.ValidateNotNullOrEmptyAttribute
    $AttributeCollection.Add($ValidateNotNullOrEmptyAttribute)
    $RuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($OrganizationParameter, [string], $AttributeCollection)    
    $RuntimeParameterDictionary.Add($OrganizationParameter, $RuntimeParameter)

    # Repositories
    $RepositoryParameter = 'Repository'        
    $AttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]    
    $ParameterAttribute = New-Object System.Management.Automation.ParameterAttribute    
    $ParameterAttribute.Mandatory = $true
    $AttributeCollection.Add($ParameterAttribute)    
    $arrSet = Get-VBORepository | select -ExpandProperty Name    
    $ValidateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute($arrSet)
    $AttributeCollection.Add($ValidateSetAttribute)
    $AttributeCollection.Add($ValidateNotNullOrEmptyAttribute)
    $RuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($RepositoryParameter, [string[]], $AttributeCollection)
    $RuntimeParameterDictionary.Add($RepositoryParameter, $RuntimeParameter)

    return $RuntimeParameterDictionary
}

BEGIN {
    $global:version = '0.7.0'
    filter timelog { "$(Get-Date -Format "yyyy-mm-dd HH:mm:ss"): $_" }

    # Save in global variables for easier use in classes
    $global:countTeamAs = $countTeamAs
    $global:recurseSP = $recurseSP

    # From https://4sysops.com/archives/convert-json-to-a-powershell-hash-table/
    function ConvertTo-Hashtable {
        [CmdletBinding()]
        [OutputType('hashtable')]
        param (
            [Parameter(ValueFromPipeline)]
            $InputObject
        )
        process {
            ## Return null if the input is null. This can happen when calling the function
            ## recursively and a property is null
            if ($null -eq $InputObject) {
                return $null
            }
            ## Check if the input is an array or collection. If so, we also need to convert
            ## those types into hash tables as well. This function will convert all child
            ## objects into hash tables (if applicable)
            if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
                $collection = @(
                    foreach ($object in $InputObject) {
                        ConvertTo-Hashtable -InputObject $object
                    }
                )
                ## Return the array but don't enumerate it because the object may be pretty complex
                Write-Output -NoEnumerate $collection
            } elseif ($InputObject -is [psobject]) { ## If the object has properties that need enumeration
                ## Convert it to its own hash table and return it
                $hash = @{}
                foreach ($property in $InputObject.PSObject.Properties) {
                    $hash[$property.Name] = ConvertTo-Hashtable -InputObject $property.Value
                }
                $hash
            } else {
                ## If the object isn't an array, collection, or other object, it's already a hash table
                ## So just return it.
                $InputObject
            }
        }
    }

    class ManagedObject {
        [Veeam.Archiver.PowerShell.Model.BackupItems.VBOBackupItem] $VBOBackupItem
        [string] $Id
        [int] $Weight

        ManagedObject ([Veeam.Archiver.PowerShell.Model.BackupItems.VBOBackupItem] $BackupItem, [int] $Weight) {
            $this.VBOBackupItem = $BackupItem
            $this.Weight = $Weight
            $this.Id = $this.GetId()            
        }

        ManagedObject ([Veeam.Archiver.PowerShell.Model.BackupItems.VBOBackupItem] $BackupItem) {
            $this.VBOBackupItem = $BackupItem
            $this.Weight = $this.GetWeight()
            $this.Id = $this.GetId()   
        }

        [string] GetId() {
            if ($this.VBOBackupItem.Type -eq "Team") {
                return ([Veeam.Archiver.PowerShell.Model.BackupItems.VBOBackupTeam] $this.VBOBackupItem).Team.OfficeId                
            } else {
                return ([Veeam.Archiver.PowerShell.Model.BackupItems.VBOBackupSite] $this.VBOBackupItem).Site.SiteId                
            }
        }

        [int] GetWeight() {
            if ($this.VBOBackupItem.Type -eq "Team") {
                return $global:countTeamAs
            } else {
                if ($global:recurseSP) { 
                    return (Get-VBOOrganizationSite -Site ([Veeam.Archiver.PowerShell.Model.BackupItems.VBOBackupSite] $this.VBOBackupItem).Site -Recurse).Count
                } else {
                    return 1
                }
            }
        }

        [int] GetWeightFromTable($WeightTable) {
            if ($WeightTable[($this.VBOItem.Type.ToString())].ContainsKey($this.Id)) {
                return $WeightTable[$this.VBOItem.Type.ToString()][$this.Id]
            } else {
                return $this.GetWeight()
            }            
        }

        [Object] GetWeightTableEntry() {
            return (@{ $this.Id = $this.Weight })
        }

        [string] ToString() {
            return $this.VBOBackupItem.ToString()
        }
               

    }

    class ManagedJob {
        [Veeam.Archiver.PowerShell.Model.VBOJob] $VBOJob
        [ManagedObject[]] $ManagedObjects
        [Object] $WeightTable
        [string] $DescriptionDelimiter = '%%%%%%'

        ManagedJob ([Veeam.Archiver.PowerShell.Model.VBOJob] $VBOJob) {
            $this.VBOJob = $VBOJob
            $this.ManagedObjects = $this.GetManagedObjects()
        }

        # Create a new managed Job
        ManagedJob([Veeam.Archiver.PowerShell.Model.VBOOrganization] $Organization, [string] $JobName, [ManagedObject[]] $addingObjects, [Veeam.Archiver.PowerShell.Model.VBORepository] $Repository, [Veeam.Archiver.PowerShell.Model.VBOJobSchedulePolicy] $SchedulePolicy) {            
            $this.VBOJob = Add-VBOJob -Organization $Organization -Name $JobName -SelectedItems $addingObjects[0].VBOBackupItem -Repository $Repository -SchedulePolicy $SchedulePolicy -Description $this.GetNewJobDescription()
            # TODO: Not optimal - recalulating the weight which is already present
            
            # Add all objects to populate weighttable - redoing so for the initial added object doesn't hurt
            $this.AddObjects($addingObjects)
            
        }

        [string] GetNewJobDescription() {
            return "Created by VB365 JobManager v{0} on {1}`n{2}" -f $global:version,(Get-Date),$this.DescriptionDelimiter
        }

        [ManagedObject[]] GetManagedObjects() {

            #TODO: Is there any need to get the weight at this point for already present objects?
            
            $this.LoadWeightTable()
            
            $VBOBackupItems = Get-VBOBackupItem -Job $this.VBOJob

            ## Check if item is in weighttable and add as managed object with it's weight

            $objects = $VBOBackupItems | ForEach-Object { [ManagedObject]::new($_) }
                        
            return $objects
        }

        # Read the description of the backup job and extract the weight table
        # WeightTable is JSON [ { 'id' : objectId, 'weight: weight }, ... ]
        LoadWeightTable () {
            # !!! -split splits on string, .Split() on CharArray
            $description = $this.VBOJob.Description -split $this.DescriptionDelimiter
            if ($description.Count -eq 2 -and $description[-1]) {
                $this.WeightTable = $description[-1] | ConvertFrom-Json | ConvertTo-Hashtable                            
            } else {
                # No table written yet, creating empty one
                $this.WeightTable = @{ Team = New-Object System.Collections.ArrayList; Site = New-Object System.Collections.ArrayList }
            }
        }

        [int] GetWeight() {
            if (!$this.WeightTable) {
                $this.LoadWeightTable()                
            }
            return ($this.WeightTable.Values.Values | Measure-Object -Sum).Sum
        }

        WriteWeightTable () {
            if (!$this.WeightTable) {
                $this.LoadWeightTable()
            }
            # !!! -split splits on string, .Split() on CharArray
            $description = $this.VBOJob.Description -split $this.DescriptionDelimiter
            $table = $this.WeightTable | ConvertTo-Json -Compress
            if ($description.Count -eq 2) {
                $description[-1] = $table 
            } else {
                throw "Job description is not in the right format, likely missing delimiter {0}" -f $this.DescriptionDelimiter
                break
            }
            Set-VBOJob -Job $this.VBOJob -Description ($description -join $this.DescriptionDelimiter)
        }

        AddObjects([ManagedObject[]] $ManagedObjects) {
            $ManagedObjects | ForEach-Object { $this.AddObject($_) }
        }

        AddObject([ManagedObject] $ManagedObject) {
            $this.AddObject($ManagedObject.VBOBackupItem, $ManagedObject.Weight)
        }

        AddObject ([Veeam.Archiver.PowerShell.Model.BackupItems.VBOBackupItem] $BackupObject) {
            $this.AddObject($BackupObject, 1)
        }
        
        AddObject ([Veeam.Archiver.PowerShell.Model.BackupItems.VBOBackupItem] $BackupObject, [int] $ObjectWeight) {
            if (!$this.WeightTable) {
                $this.LoadWeightTable()
            }
            if ($BackupObject.Type -eq "Team") {
                [Veeam.Archiver.PowerShell.Model.BackupItems.VBOBackupTeam] $team =  $BackupObject                
                $this.WeightTable.Team += @{ id = $team.Team.OfficeId; weight = $ObjectWeight }
            } else {
                [Veeam.Archiver.PowerShell.Model.BackupItems.VBOBackupSite] $site = $BackupObject                
                $this.WeightTable.Site += @{ id = $site.Site.SiteId; weight = $ObjectWeight }
            }
            Add-VBOBackupItem -Job $this.VBOJob -BackupItem $BackupObject
            $this.WriteWeightTable()
        }

        [string] ToString() {
            return $this.VBOJob.Name
        }

    }

    class JobManager {
        [Veeam.Archiver.PowerShell.Model.VBOOrganization] $org
        [string] $JobnamePattern = $null
        [ManagedJob[]] $Jobs
        [int] $NextJobNumber = 1
        [int] $ObjectLimit
        [Veeam.Archiver.PowerShell.Model.VBORepository[]] $Repositories
        [System.Collections.Queue] $RepoQueue = [System.Collections.Queue]::new()
        [hashtable] $AddObjectList = @{ "any" = [System.Collections.ArrayList]::new(); }

        JobManager([Veeam.Archiver.PowerShell.Model.VBOOrganization] $Organization, [string] $JobnamePattern, [int] $ObjectLimit, [Veeam.Archiver.PowerShell.Model.VBORepository[]] $Repositories) {
            $this.org = $Organization
            $this.JobnamePattern = $JobnamePattern
            $this.ObjectLimit = $ObjectLimit
            $this.Jobs = $this.GetJobs()            
            $this.Repositories = $Repositories

            $this.Repositories | ForEach-Object { $this.AddObjectList.Add($_.Id, [System.Collections.ArrayList]::new()) }
        }

        [ManagedJob[]] GetJobs() {            
            $myjobs = New-Object System.Collections.ArrayList
            while ($true) {
                $checkName = $this.JobnamePattern -f $this.NextJobNumber
                $checkJob = Get-VBOJob -Organization $this.org -Name $checkName
                if ($checkJob) { 
                    $this.NextJobNumber++
                    $myjobs.Add(([ManagedJob]::new($checkJob)))
                } else {                    
                    break
                }
            }
            return $myjobs
        }

        [Veeam.Archiver.PowerShell.Model.VBORepository] FindNextRepo() {
            if ($this.RepoQueue.Count -eq 0) {
                $this.Repositories | Foreach-Object { $this.RepoQueue.Enqueue($_) }
            }

            $nextRepo = $this.RepoQueue.Dequeue()

            return $nextRepo
        }

        # Returns a random job with free space for the given repository
        [ManagedJob] FindFreeJob([Veeam.Archiver.PowerShell.Model.VBORepository] $Repository, [int] $FreeSpace) {
            if ($Repository -eq $null) {
                $matchedJobs =  $this.Jobs | Where-Object { ($_.GetWeight()+$FreeSpace) -le $this.ObjectLimit }
            } else {
                $matchedJobs = $this.Jobs | Where-Object { $_.VBOJob.Repository -eq $Repository -and ($_.GetWeight()+$FreeSpace) -le $this.ObjectLimit }
            }
            
            if ($matchedJobs.Count -ne 0) {                
                return ($matchedJobs | Get-Random)
            }
            return $null
        }

        # Enqueue a backup item to be added to the given repository
        # If $Repository is $null it will be added to the "any" queue
        Add([Veeam.Archiver.PowerShell.Model.BackupItems.VBOBackupItem] $Object, [Veeam.Archiver.PowerShell.Model.VBORepository] $Repository) {
            $managed = [ManagedObject]::new($Object)
            
            if ($null -eq $Repository) {            
                $this.AddObjectList["any"] += $managed
            } else {
                $this.AddObjectList[$Repository.Id] += $managed
            }
        }

        [ManagedJob] CreateNewJob([ManagedObject[]] $ManagedObjects, [Veeam.Archiver.PowerShell.Model.VBORepository] $Repository) {            
            $nextJobName = $this.JobnamePattern -f $this.NextJobNumber
            # TODO: Get next schedule for this repo (this proxy) - from managedjob?
            $nextSchedule = New-VBOJobSchedulePolicy -EnableSchedule -Type Daily -DailyType Everyday -DailyTime '22:00'
            $newJob = [ManagedJob]::new($this.org, $nextJobName, $ManagedObjects, $Repository, $nextSchedule)            
            $this.Jobs += $newJob
            $this.NextJobNumber++
            return $newJob
            
            #if ($lastSchedule) {
            #             $lastSchedule = $currentSchedule                    
            #             $currentSchedule = New-VBOJobSchedulePolicy -EnableSchedule -Type $lastSchedule.Type -DailyType $lastSchedule.DailyType -DailyTime ($lastSchedule.DailyTime+$scheduleDelay)
            #         }                
            #         $useRepo = if ($assignedRepo) { $assignedRepo } else { $repoQueue.Dequeue() }
            #         $usedObject = $objectQueue.Dequeue()
            #         $weightTable = @{ "Sites" = @{}; "Teams" = @{} }
            #         if ($usedObject.object.Type -eq "Site") {
            #             $weightTable.Sites.Add("$($usedObject.object.Site.SiteId)", $usedObject.weight)
            #         } else {
            #             $weightTable.Teams.Add("$($usedObject.object.OfficeId)", $usedObject.weight)
            #         }
            #         $weightTableJson = $weightTable | Convertto-Json -Compress
            #         $currentJob = Add-VBOJob -Organization $org -Name $jobName -SchedulePolicy $currentSchedule -Repository $useRepo -SelectedItems $usedObject.object -Description $weightTableJson
            #         "No usable job found - created new job {0} and added {1}" -f $currentJob,$usedObject.object | timelog
        }

        # Save all enqueued objects to jobs matching the given repositories
        Save() {
            foreach ($aol in $this.AddObjectList.GetEnumerator()) {
                if ($null -ne $aol.Value -and $aol.Value.Count -gt 0) {
                    $sumWeight = ($aol.value | Measure-Object -Property Weight -Sum).Sum
                    $repo = $this.Repositories | ? { $_.Id -eq $aol.Name }
                    $freeJob = $this.FindFreeJob($repo, $sumWeight)
                    if (!$freeJob) {
                        if (!$repo) { $repo = $this.FindNextRepo() }
                        $freeJob = $this.CreateNewJob($aol.Value, $repo)                        
                    } else {
                        $freeJob.AddObjects($aol.Value)
                    }                                        
                }
            }
            # Clear the object list
            $this.AddObjectList = @{}
            $this.Repositories | ForEach-Object { $this.AddObjectList.Add($_.Id, [System.Collections.ArrayList]::new()) }
            $this.AddObjectList["any"] = [System.Collections.ArrayList]::new()
        }

        [String] ToString() {
            return "JobManager {0}" -f $this.JobnamePattern
        }
        
    }

    $organization = $PsBoundParameters[$OrganizationParameter]
    $repository = $PsBoundParameters[$RepositoryParameter]

    if (!$baseSchedule) {        
        $baseSchedule = New-VBOJobSchedulePolicy -EnableSchedule -Type Daily -DailyType Everyday -DailyTime "22:00:00"
    }

    $basename = $MyInvocation.MyCommand.Name.Split(".")[0]
    
    if (!$includeFile -and (Test-Path -PathType Leaf -Path "${PSScriptRoot}\${basename}.includes")) {
        $includeFile = "${PSScriptRoot}\${basename}.includes"        
    }

    if (!$excludeFile -and (Test-Path -PathType Leaf -Path "${PSScriptRoot}\${basename}.excludes")) {
        $excludeFile = "${PSScriptRoot}\${basename}.excludes"        
    }

    if (!$groupFile -and (Test-Path -PathType Leaf -Path "${PSScriptRoot}\${basename}.groups")) {
        $groupFile = "${PSScriptRoot}\${basename}.groups"
    }

    
    $includes = @()
    if ($includeFile) {
        $includes = Get-Content $includeFile
    }

    $excludes = @()
    if ($excludeFile) {
        $excludes = Get-Content $excludeFile
    }

    $groups = New-Object System.Collections.Generic.List[hashtable]
    if ($groupFile) {
        $groupsJson = Get-Content $groupFile | ConvertFrom-Json
        $groupsJson | Foreach-Object { 
            [hashtable] $myGroup = @{}
            foreach ($property in $_.PSObject.Properties) {
                $myGroup[$property.Name] = $property.Value
            } 
            if (!$myGroup.ContainsKey('jobnamePattern') -or !$myGroup.ContainsKey('matchPattern')) {
                "Missing a required key in group specification: $_" | timelog
                exit 1
            } elseif (!$myGroup.ContainsKey('groupName')) {
                $myGroup['groupName'] = $mygroup['matchPattern'] -f 0
            }
            $myGroup['jobCounter'] = 1            
            $groups += $myGroup            
        }
    }
    Start-Transcript -IncludeInvocationHeader -Path "${PSScriptRoot}\logs\vb365-spo-teams-jobs-$(get-Date -Format FileDateTime).log" -NoClobber
}

PROCESS {
    $org = Get-VBOOrganization -Name $organization
    $repos = $repository | ForEach-Object { Get-VBORepository -Name $_ }    

    $sites = @()
    $teams = @()

    if (!$limitServiceTo -or $limitServiceTo -eq "SharePoint") {
        "Reading SharePoint sites from organization - this can take a while" | timelog
        $sites = Get-VBOOrganizationSite -Organization $org -NotInJob -WarningAction:SilentlyContinue   
        "Found {0} SharePoint sites not yet in backup jobs" -f $sites.Count | timelog
    }

    if (!$limitServiceTo -or $limitServiceTo -eq "Teams") {
        "Reading Teams from organization - this can take a while" | timelog
        $teams = Get-VBOOrganizationTeam -NotInJob -Organization $org 
        "Found {0} Teams not yet in backup jobs" -f $teams.Count | timelog
    }

    # Iterate through teams only if no SP is selected, otherwise SP is always leading processing
    # Sort by UUIDs for randomizing and better load balancing
    $objects = if ($limitServiceTo -eq "Teams") { $teams | Sort-Object -Property OfficeId } else { $sites | Sort-Object -Property SiteId } 

    if ($includes) {
        "Adding {0} include patterns to process from {1}" -f $includes.Count,$includeFile | timelog
    }
    
    if ($excludes) {
        "Adding {0} exclude patterns to process from {1}" -f $excludes.Count,$excludeFile | timelog
    }

    if ($groups) {        
        "Adding {0} group patterns to process from {1}" -f $groups.Count,$groupFile | timelog
    }

    $jobCounter = 1
    [Veeam.Archiver.PowerShell.Model.VBOJob] $currentJob = $null    
    [Veeam.Archiver.PowerShell.Model.VBOJobSchedulePolicy] $currentSchedule = $baseSchedule    
    [Veeam.Archiver.PowerShell.Model.VBOJobSchedulePolicy] $lastSchedule = $null
    [System.Collections.Queue] $repoQueue = New-Object System.Collections.Queue    
    [System.Collections.Queue] $objectQueue = New-Object System.Collections.Queue
    
    $objCounter = 0
    $teamCounter = 0
    $jobTouchedCounter = 0
    $jobCreatedCounter = 0    
    
    # Counts also not matching includes
    $excludeObjectCounter = 0

    # Adapt minimum free objects in job to stay below maximum when adding SP and Teams
    $minFreeObjects = if ($noTeams -or $noSharepoint) { 1 } else { 1+$countTeamsAs }
    "Minimum free objects is set to {0}" -f $minFreeObjects | timelog 

    $jobManager = [JobManager]::new($org, $jobNamePattern, $objectsPerJob, $repos)

    foreach ($o in $objects) {
        
        $assignedGroup = $null
        $assignedRepo = $null
        $bObjects = @()

        if ($includes) {
            $include = $includes | Where-Object { $o.toString() -cmatch $_ -or (($limitServiceTo -ne "Teams") -and ($o.URL -cmatch $_ )) }            
            if ($include) {
                "Include {0} because of pattern {1}" -f $o.toString(),$include | timelog
            } else {
                $excludeObjectCounter++                
                continue
                
            }
        }

        if ($excludes) {
            $exclude = $excludes | Where-Object { $o.toString() -cmatch $_ -or (($limitServiceTo -ne "Teams") -and ($o.URL -cmatch $_ )) }
            if ($exclude) {
                "Exclude {0} because of pattern {1}" -f $o.toString(),$exclude | timelog
                $excludeObjectCounter++
                continue
            }
        }
        
        if ($checkBackups) {            
            if ($limitServiceTo -eq "Teams") {
                $repos | ForEach-Object { 
                    if (Get-VBOEntityData -Repository $_ -Team $o) {
                        $assignedRepo = $_                        
                    }
                }
            } else {
                $repos | ForEach-Object { 
                    if (Get-VBOEntityData -Repository $_ -Site $o) {
                        $assignedRepo = $_                        
                    }
                }
            }

            if ($assignedRepo) {
                "Found {0} in repository {1} - adding it to a corresponding job" -f $o,$assignedRepo | timelog                
            }
        }


        if ($limitServiceTo -eq "Teams") {            
            $jobManager.Add((New-VBOBackupItem -Team $o -TeamsChats:$withTeamsChats), $assignedRepo)            
            #$bObjects += New-VBOBackupItem -Team $o -TeamsChats:$withTeamsChats            
            #$bWeight = $countTeamsAs                                      
            #$bObjects += @{"object" = $bObject; "weight" = $bWeight}                        
        } else {            
            $jobManager.Add((New-VBOBackupItem -Site $o), $assignedRepo)
            #$bObjects += New-VBOBackupItem -Site $o                        
            #$bWeight = if ($recurseSP -eq $true) { (Get-VBOOrganizationSite -Site $site -Recurse).Count } else { 1 }
            #$bObjects += @{"object" = $bObject; "weight" = $bWeight}
            
            # If any service limit is set either do not process teams (limit to SP) or teams are already processed on $o level (limit to Teams)
            if (!$limitServiceTo) {
                $url = [uri] $o.URL
                $urlName = $url.Segments[-1]
                $matchedTeam = $teams | ? { ($_.Mail -split "@")[0] -eq $urlName }
                if ($matchedTeam) {
                    $jobManager.Add((New-VBOBackupItem -Team $matchedTeam -TeamsChats:$withTeamsChats), $assignedRepo)
                    #$bObjects += New-VBOBackupItem -Team $matchedTeam -TeamsChats:$withTeamsChats                                
                    #$bObjects += @{"object" = $bTeam; "weight" = $countTeamsAs}
                    "Found matching Team to SP site {0}: {1}" -f $o,$matchedTeam | timelog                    
                }
            }
        }

        $jobManager.Save()

        # Grouping is just done on the primary loop object. Subsites & matching Teams follow
        #if ($groups) {
        #    $assignedGroup = $groups | Where-Object { $o.toString() -cmatch $_['matchPattern'] -or (($limitServiceTo -ne "Teams") -and ($o.URL -cmatch $_['matchPattern'] )) }
        #    if ($assignedGroup) {
        #        "Grouping object in group {0}" -f $assignedGroup['groupName'] | timelog                                
        #    } 
        #}


        #if ($checkBackups) 
        #{            
        #    if ($limitServiceTo -eq "Teams") {
        #        $repos | ForEach-Object { 
        #            if (Get-VBOEntityData -Repository $_ -Team $o) {
        #                $assignedRepo = $_                        
        #            }
        #        }
        #    } else {
        #        $repos | ForEach-Object { 
        #            if (Get-VBOEntityData -Repository $_ -Site $o) {
        #               $assignedRepo = $_                        
        #            }
        #       }
        #    }
        #
        #    if ($assignedRepo) {
        #        "Found {0} in repository {1} - adding it to a corresponding job" -f $o,$assignedRepo | timelog                
        #    }
        #}

        #if ($assignedGroup) { 
        #    $groupKey = $assignedGroup['groupName'] 
        #    $namePattern = $assignedGroup['jobnamePattern']
        #    $counter = [Ref] $assignedGroup['jobCounter']            
        #} else { 
        #    $groupKey = "any" 
        #    $namePattern = $jobNamePattern
        #    $counter = [Ref] $jobCounter
        #}
        #$repoKey = if ($assignedRepo) { $assignedRepo.Id } else { "any" }

        #$bObjects | Foreach-Object { $objectQueue.Enqueue($_) }         

        # while (!$currentJob) {            
        #     $jobName = $namePattern -f $counter.Value

        #     if ($repoQueue.Count -eq 0) {
        #         $repos | % { $repoQueue.Enqueue($_) }
        #     }
            
        #     # Verify if job exists and if new objects can still be added to this one
        #     $currentJob = Get-VBOJob -Organization $org -Name $jobName -ErrorAction:SilentlyContinue
        #     if ($currentJob) {
        #         $currentJobObjects = Get-VBOBackupItem -Job $currentJob
        #         "Found existing job {0} with {1} objects" -f $currentJob,$currentJobObjects.Count | timelog
        #         if (($objectsPerJob - $currentJobObjects.Count) -ge ($bObjects | Foreach-Object { $_.weight } | Measure-Object -Sum).Sum) {
        #             #$currentJobObjects.Count -gt ($objectsPerJob - $minFreeObjects)) {
        #             "Skipping job, object limit already reached ({0})" -f $objectsPerJob | timelog
        #             $lastSchedule = $currentJob.SchedulePolicy
               
        #             # Won't use this job, search for next
        #             $currentJob = $null
        #             $counter.Value++
        #             continue
        #         }
        #         if ($assignedRepo -and $currentJob.Repository -ne $assignedRepo) {
        #             "Job {0} not matching repository {1}" -f $currentJob,$assignedRepo | timelog
        #             counter++
        #             continue
        #         }
        #         "Adding objects to job {0}" -f $currentJob | timelog
        #         $jobTouchedCounter++                
        #     } else {                
        #         if ($lastSchedule) {
        #             $lastSchedule = $currentSchedule                    
        #             $currentSchedule = New-VBOJobSchedulePolicy -EnableSchedule -Type $lastSchedule.Type -DailyType $lastSchedule.DailyType -DailyTime ($lastSchedule.DailyTime+$scheduleDelay)
        #         }                
        #         $useRepo = if ($assignedRepo) { $assignedRepo } else { $repoQueue.Dequeue() }
        #         $usedObject = $objectQueue.Dequeue()
        #         $weightTable = @{ "Sites" = @{}; "Teams" = @{} }
        #         if ($usedObject.object.Type -eq "Site") {
        #             $weightTable.Sites.Add("$($usedObject.object.Site.SiteId)", $usedObject.weight)
        #         } else {
        #             $weightTable.Teams.Add("$($usedObject.object.OfficeId)", $usedObject.weight)
        #         }
        #         $weightTableJson = $weightTable | Convertto-Json -Compress
        #         $currentJob = Add-VBOJob -Organization $org -Name $jobName -SchedulePolicy $currentSchedule -Repository $useRepo -SelectedItems $usedObject.object -Description $weightTableJson
        #         "No usable job found - created new job {0} and added {1}" -f $currentJob,$usedObject.object | timelog

        #         $jobTouchedCounter++
        #         $jobCreatedCounter++
        #     }            
        # }
        
        # foreach ($bObject in $objectQueue.GetEnumerator()) {           
        #     Add-VBOBackupItem -Job $currentJob -BackupItem $bObject.object
        #     if ($bObject.object.Type -eq "Site") {
                
        #     }
        # }
        # "Added object to job {0}: {1}" -f $currentJob,$o | timelog
        # #Set-VBOJob -Job $currentJob -Description
        # $objCounter++
        
        # If any service limit is set either do not process teams (limit to SP) or teams are already processed on $o level (limit to Teams)
        #if (!$limitServiceTo) {
        #    $url = [uri] $o.URL
        #    $urlName = $url.Segments[-1]
        #    $matchedTeam = $teams | ? { ($_.Mail -split "@")[0] -eq $urlName }
        #    if ($matchedTeam) {
        #        $bTeam = New-VBOBackupItem -Team $matchedTeam -TeamsChats:$withTeamsChats                                
        #        Add-VBOBackupItem -Job $currentJob -BackupItem $bTeam
        #        "Added matching Team to job {0}: {1}" -f $currentJob,$matchedTeam | timelog
        #        $teamCounter++
        #    }
        #}
        
        # $currentJobObjects = Get-VBOBackupItem -Job $currentJob
        # if ($currentJobObjects.Count -gt ($objectsPerJob - $minFreeObjects)) {
        #     "Reached object limit ({0})" -f $objectsPerJob | timelog
        #     # Won't use this job, search for next
        #     $currentJob = $null
        #     $jobCounter++
        #     continue                    
        # }
    }

    $primaryObject = if ($limitServiceTo -eq "Teams") { "Teams" } else { "Sharepoint Sites" }
    $teamCountText = if (!$limitServiceTo) { "and ${teamCounter} teams " } else { "" }

    "Added ${objCounter} ${primaryObject} ${teamCountText}to ${jobTouchedCounter} touched and ${jobCreatedCounter} created backup jobs"  | timelog
    "Excluded {0} objects through include and exclude filters" -f $excludeObjectCounter | timelog    

}

END {
    Stop-Transcript 
}