<#
.SYNOPSIS
    Automatically create jobs for SharePoint Online Sites and corresponding Teams which can be distributed accross
.DESCRIPTION
    TO BE DONE

    Requires Veeam.Archiver.PowerShell module on the system.
.EXAMPLE
    TO BE DONE
.INPUTS
    TO BE DONE
.OUTPUTS
    TO BE DONE
.NOTES
    Written by Stefan Zimmermann <stefan.zimmermann@veeam.com>
#>
#requires -modules Veeam.Archiver.PowerShell
[CmdletBinding()]
Param(        
    [Parameter()]
    # Maximum number of objects per job
    # When backing up teams the maximum is this number-1 because teams should be grouped with sites
    [int] $objectsPerJob = 10,

    # Include teams when building jobs
    [switch] $withTeams = $true,

    # Format string to build the jobname. {0} will be replaced with the number of the job and can be formatted as PowerShell format string
    # {0:d3} will create a padded number. 2 will become 002, 12 will become 012
    [string] $jobNamePattern = "SharePointTeams-{0:d2}",

    # Include Teams Chats, only used if `withTeams` is $true
    [switch] $withTeamsChats = $false,

    # Base schedule for 1st job
    [Object] $baseSchedule,

    # Delay between the starttime of two jobs in HH:MM:SS format
    [string] $scheduleDelay = "00:10:00"


)
DynamicParam {
    Import-Module Veeam.Archiver.PowerShell
    $RuntimeParameterDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary 

    # Organizations
    $OrganizationParameter = 'Organization'        
    $AttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
    $ParameterAttribute = New-Object System.Management.Automation.ParameterAttribute
    # Change back to true after debugging
    $ParameterAttribute.Mandatory = $false        
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
    # Change back to true after debugging
    $ParameterAttribute.Mandatory = $false        
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
    #$organization = "90d"
    #$repository = "Local-Item","Local-Snapshot"

    if (!$baseSchedule) {        
        $baseSchedule = New-VBOJobSchedulePolicy -EnableSchedule -Type Daily -DailyType Everyday -DailyTime "22:00:00"
    }

    Start-Transcript -IncludeInvocationHeader -Path ".\logs\vb365-spo-teams-jobs-$(get-Date -Format FileDateTime).log" -NoClobber
}

PROCESS {
    $org = Get-VBOOrganization -Name $organization
    $repos = $repository | % { Get-VBORepository -Name $_ }
    # Sort by SiteId to make sure pages are properly distributed
    $sites = Get-VBOOrganizationSite -Organization $org -NotInJob -WarningAction:SilentlyContinue | sort -Property SiteId
    "Found {0} sites not yet in jobs" -f $sites.Count
    
    $teams = @()
    if ($withTeams) { 
        $teams = Get-VBOOrganizationTeam -NotInJob -Organization $org 
        "Found {0} Teams not in jobs" -f $teams.Count
    } 

    $jobCounter = 1
    [Veeam.Archiver.PowerShell.Model.VBOJob] $currentJob = $null    
    [Veeam.Archiver.PowerShell.Model.VBOJobSchedulePolicy] $currentSchedule = $baseSchedule    
    [Veeam.Archiver.PowerShell.Model.VBOJobSchedulePolicy] $lastSchedule = $null
    [System.Collections.Queue] $repoQueue = New-Object System.Collections.Queue    
    
    $siteCounter = 0
    $teamCounter = 0
    $jobTouchedCounter = 0
    $jobCreatedCounter = 0 

    # When to add objects to an existing job
    $minFreeObjects = if ($withTeams) { 2 } else { 1} 


    # Map Teams to SPO sites to include them in the same job to put them on the same repo
    foreach ($site in $sites) {

        $bSite = New-VBOBackupItem -Site $site

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
                    Write-Host "Skipping job, object limit already reached (${objectsPerJob})"
                    $lastSchedule = $currentJob.SchedulePolicy
               
                    # Won't use this job, search for next
                    $currentJob = $null
                    $jobCounter++
                    continue
                }
                Write-Host "Adding objects to job"
                $jobTouchedCounter++
                
            } else {                
                if ($lastSchedule) {
                    $lastSchedule = $currentSchedule                    
                    $currentSchedule = New-VBOJobSchedulePolicy -EnableSchedule -Type $lastSchedule.Type -DailyType $lastSchedule.DailyType -DailyTime ($lastSchedule.DailyTime+$scheduleDelay)
                }                
                $currentJob = Add-VBOJob -Organization $org -Name $jobName -SchedulePolicy $currentSchedule -Repository $repoQueue.Dequeue() -SelectedItems $bSite                
                Write-Host "No usable job found - created new job $currentJob"
                $jobTouchedCounter++
                $jobCreatedCounter++
            }            
        }
        
        Add-VBOBackupItem -Job $currentJob -BackupItem $bSite
        Write-Host "Added SPO site to job ${currentJob}: $site"
        $siteCounter++
        
        if ($withTeams) {
            $url = [uri] $site.URL
            $urlName = $url.Segments[-1]
            $matchedTeam = $teams | ? { ($_.Mail -split "@")[0] -eq $urlName }
            if ($matchedTeam) {
                $bTeam = New-VBOBackupItem -Team $matchedTeam -TeamsChats:$withTeamsChats                                
                Add-VBOBackupItem -Job $currentJob -BackupItem $bTeam
                Write-Host "Added Team to job ${currentJob}: ${matchedTeam}"
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

    Write-Host "Added ${siteCounter} sites and ${teamCounter} teams to ${jobTouchedCounter} touched and ${jobCreatedCounter} created backup jobs"     

}

END {
    Stop-Transcript 
}