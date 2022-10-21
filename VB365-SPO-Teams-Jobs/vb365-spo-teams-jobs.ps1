
<#PSScriptInfo

.VERSION 0.2.0

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
    [string] $jobNamePattern = "SharePointTeams-{0:d2}",

    # Include chats in Teams backups
    [switch] $withTeamsChats = $false,

    # Base schedule for 1st job
    # Must be a VBO Schedule Policy like created with `New-VBOSchedulePolicy`
    [Object] $baseSchedule = $null,

    # Delay between the starttime of two jobs in HH:MM:SS format
    [string] $scheduleDelay = "00:30:00",

    # Path to file with patterns to include when building jobs
    # Includes will be processed before excludes
    # If not set will try to load a file with the same name as the script and ending ".include"
    # Patterns are case sensitive matched with regular expression syntax
    # Specify one pattern per line and all will be checked
    [string] $includeFile = $null,

    # Path to file with patterns to exclude when building jobs (Excludes won't be added to jobs, they won't be excluded)
    # Excludes will be processed after includes
    # If not set will try to load a file with the same name as the script and ending ".exclude"
    # Patterns are case sensitive matched with regular expression syntax
    # Specify one pattern per line and all will be checked
    [string] $excludeFile = $null

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
    # Add .onmicrosoft.com name in case organization was renamed
    $arrSet += Get-VBOOrganization | select -ExpandProperty OfficeName
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
    $organization = $PsBoundParameters[$OrganizationParameter]
    $repository = $PsBoundParameters[$RepositoryParameter]

    if (!$baseSchedule) {        
        $baseSchedule = New-VBOJobSchedulePolicy -EnableSchedule -Type Daily -DailyType Everyday -DailyTime "22:00:00"
    }

    $basename = $MyInvocation.MyCommand.Name.Split(".")[0]

    if (!$includeFile -and (Test-Path -PathType Leaf -Path "${PSScriptRoot}\${basename}.include")) {
        $includeFile = "${PSScriptRoot}\${basename}.include"        
    }

    if (!$excludeFile -and (Test-Path -PathType Leaf -Path "${PSScriptRoot}\${basename}.exclude")) {
        $excludeFile = "${PSScriptRoot}\${basename}.exclude"        
    }

    
    if ($includeFile) {
        $includes = Get-Content $includeFile
    }

    if ($excludeFile) {
        $excludes = Get-Content $excludeFile
    }

    Start-Transcript -IncludeInvocationHeader -Path "${PSScriptRoot}\logs\vb365-spo-teams-jobs-$(get-Date -Format FileDateTime).log" -NoClobber
}

PROCESS {
    $org = Get-VBOOrganization -Name $organization
    $repos = $repository | % { Get-VBORepository -Name $_ }    

    $sites = @()
    $teams = @()

    if (!$limitServiceTo -or $limitServiceTo -eq "SharePoint") {
        $sites = Get-VBOOrganizationSite -Organization $org -NotInJob -WarningAction:SilentlyContinue    
        "Found {0} SharePoint sites not yet in backup jobs" -f $sites.Count
    }

    if (!$limitServiceTo -or $limitServiceTo -eq "Teams") {
        $teams = Get-VBOOrganizationTeam -NotInJob -Organization $org 
        "Found {0} Teams not yet in backup jobs" -f $teams.Count
    }

    # Iterate through teams only if no SP is selected, otherwise SP is always leading processing
    # Sort by UUIDs for randomizing and better load balancing
    $objects = if ($limitServiceTo -eq "Teams") { $teams | sort -Property OfficeId } else { $sites | sort -Property SiteId } 
    

    if ($includes) {
        "Adding {0} include patterns to process from {1}" -f $includes.Count,$includeFile
    }
    
    if ($excludes) {
        "Adding {0} exclude patterns to process from {1}" -f $excludes.Count,$excludeFile
    }

    $jobCounter = 1
    [Veeam.Archiver.PowerShell.Model.VBOJob] $currentJob = $null    
    [Veeam.Archiver.PowerShell.Model.VBOJobSchedulePolicy] $currentSchedule = $baseSchedule    
    [Veeam.Archiver.PowerShell.Model.VBOJobSchedulePolicy] $lastSchedule = $null
    [System.Collections.Queue] $repoQueue = New-Object System.Collections.Queue    
    
    $objCounter = 0
    $teamCounter = 0
    $jobTouchedCounter = 0
    $jobCreatedCounter = 0 

    # Adapt minimum free objects in job to stay below maximum when adding SP and Teams
    $minFreeObjects = if ($noTeams -or $noSharepoint) { 1 } else { 2 } 


    foreach ($o in $objects) {

        if ($includes) {
            $include = $includes | Where-Object { $o.toString() -cmatch $_ }
            if ($limitServiceTo -ne "Teams") { $include += $includes | Where-Object { $o.URL -cmatch $_ } }
            if ($include) {
                "Include {0} because of pattern {1}" -f $o.toString(),$include
            } else {
                continue
            }
        }

        if ($excludes) {
            $exclude = $excludes | Where-Object { $o.toString() -cmatch $_ }
            if ($limitServiceTo -ne "Teams") { $include += $includes | Where-Object { $o.URL -cmatch $_ } }
            if ($exclude) {
                "Exclude {0} because of pattern {1}" -f $o.toString(),$exclude
                continue
            }
        }

        if ($limitServiceTo -eq "Teams") {            
            $bObject = New-VBOBackupItem -Team $o -TeamsChats:$withTeamsChats                                
        } else {            
            $bObject = New-VBOBackupItem -Site $o            
        }

        while (!$currentJob) {
            $jobName = $jobNamePattern -f $jobCounter

            if ($repoQueue.Count -eq 0) {
                $repos | % { $repoQueue.Enqueue($_) }
            }
            
            # Verify if job exists and if new objects can still be added to this one
            $currentJob = Get-VBOJob -Organization $org -Name $jobName -ErrorAction:SilentlyContinue
            if ($currentJob) {
                $currentJobObjects = Get-VBOBackupItem -Job $currentJob
                "Found existing job {0} with {1} objects" -f $currentJob,$currentJobObjects.Count
                if ($currentJobObjects.Count -gt ($objectsPerJob - $minFreeObjects)) {
                    "Skipping job, object limit already reached ({0})" -f $objectsPerJob
                    $lastSchedule = $currentJob.SchedulePolicy
               
                    # Won't use this job, search for next
                    $currentJob = $null
                    $jobCounter++
                    continue
                }
                "Adding objects to job {0}" -f $currentJob
                $jobTouchedCounter++
                
            } else {                
                if ($lastSchedule) {
                    $lastSchedule = $currentSchedule                    
                    $currentSchedule = New-VBOJobSchedulePolicy -EnableSchedule -Type $lastSchedule.Type -DailyType $lastSchedule.DailyType -DailyTime ($lastSchedule.DailyTime+$scheduleDelay)
                }                
                $currentJob = Add-VBOJob -Organization $org -Name $jobName -SchedulePolicy $currentSchedule -Repository $repoQueue.Dequeue() -SelectedItems $bObject -Description "Created by vbo-spo-teams-jobs v$($version) on $(Get-Date)"
                "No usable job found - created new job {0}" -f $currentJob
                $jobTouchedCounter++
                $jobCreatedCounter++
            }            
        }
        
        Add-VBOBackupItem -Job $currentJob -BackupItem $bObject
        "Added object to job {0}: {1}" -f $currentJob,$o
        $objCounter++
        
        # If any service limit is set either do not process teams (limit to SP) or teams are already processed on $o level (limit to Teams)
        if (!$limitServiceTo) {
            $url = [uri] $o.URL
            $urlName = $url.Segments[-1]
            $matchedTeam = $teams | ? { ($_.Mail -split "@")[0] -eq $urlName }
            if ($matchedTeam) {
                $bTeam = New-VBOBackupItem -Team $matchedTeam -TeamsChats:$withTeamsChats                                
                Add-VBOBackupItem -Job $currentJob -BackupItem $bTeam
                "Added matching Team to job {0}: {1}" -f $currentJob,$matchedTeam
                $teamCounter++
            }
        }
        
        $currentJobObjects = Get-VBOBackupItem -Job $currentJob
        if ($currentJobObjects.Count -gt ($objectsPerJob - $minFreeObjects)) {
            Write-Host "Reached object limit (${objectsPerJob})"
            # Won't use this job, search for next
            $currentJob = $null
            $jobCounter++
            continue                    
        }
    }

    $primaryObject = if ($limitServiceTo -eq "Teams") { "Teams" } else { "Sharepoint Sites" }
    $teamCountText = if (!$limitServiceTo) { "and ${teamCounter} teams " } else { "" }

    Write-Host "Added ${objCounter} ${primaryObject} ${teamCountText}to ${jobTouchedCounter} touched and ${jobCreatedCounter} created backup jobs"     

}

END {
    Stop-Transcript 
}