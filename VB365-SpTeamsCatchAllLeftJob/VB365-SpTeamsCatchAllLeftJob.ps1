<# 
   .SYNOPSIS
   Creating a VB365 Backup Job that includes the whole organization for SharePoint and Teams but exclude everything already in a different job 

   .DESCRIPTION
   This script will create or update a job with the goal to catch all SharePoint Sites and Teams which are not already in any other job.
   It is using job exclusions to be able to use the entire organisation for the job selection and protect every new SharePoint or Teams object.
   It can be run once or multiple times to update the exclusions if needed.
    
   .NOTES 
   Version:        0.1
   Author:         David Bewernick (david.bewernick@veeam.com)
   Creation Date:  21.02.2024
   Purpose/Change: Initial script development

   .CHANGELOG
   v0.1   21.02.2024   Script created

 #>

$timestampFileName = get-date -Format "yyyy-mm-dd_HH-mm-ss"
$jobSPExcludeItems = New-Object System.Collections.ArrayList
$jobTeamsExcludeItems = New-Object System.Collections.ArrayList
$jobAllExcludeItems = New-Object System.Collections.ArrayList
$unprotectesSites = New-Object System.Collections.ArrayList
$unprotectesTeams = New-Object System.Collections.ArrayList

# Set some variables to your need
[string]$Script:LogFile = "vb365_SpTeams_ChatchLeftJob.log" #logfile name, can be a full path
[string]$orgName = "dabew.onmicrosoft.com" #for which organization should this be processed?
[string]$catchallJobName = "SpTeamsCatchAll" #the catch all job name
[string]$repoName = "repo04-minio" #the backup repository name
[switch]$enableSP = $true #should SharePoint Sites be processed?
[switch]$enableTeams = $true #should SharePoint Sites be processed?
[switch]$excludePersonalSites = $true #should Personal SharePoint Sites be excluded?

function Write-Log($Info, $Status){
    $timestamp = get-date -Format "yyyy-mm-dd HH:mm:ss"
    switch($Status){
        Info    {Write-Host "$timestamp $Info" -ForegroundColor Green  ; "$timestamp $Info" | Out-File -FilePath $LogFile -Append}
        Status  {Write-Host "$timestamp $Info" -ForegroundColor Yellow ; "$timestamp $Info" | Out-File -FilePath $LogFile -Append}
        Warning {Write-Host "$timestamp $Info" -ForegroundColor Yellow ; "$timestamp $Info" | Out-File -FilePath $LogFile -Append}
        Error   {Write-Host "$timestamp $Info" -ForegroundColor Red -BackgroundColor White; "$timestamp $Info" | Out-File -FilePath $LogFile -Append}
        default {Write-Host "$timestamp $Info" -ForegroundColor white "$timestamp $Info" | Out-File -FilePath $LogFile -Append}
    }
}
Write-Log -Info "-----------------------" -Status Info
Write-Log -Info "Script started" -Status Info
Write-Log -Info "-----------------------" -Status Info

$org = Get-VBOOrganization -Name $orgName
$repo = Get-VBORepository -Name $repoName

#make sure the arraylists are empty
$jobSPExcludeItems.Clear()
$jobTeamsExcludeItems.clear()
$unprotectesSites.Clear()
$unprotectesTeams.Clear()

### get all protected SP and Teams items in VB365 Jobs

# get all jobs for the organization
$jobs = Get-VBOJob -Organization $org
foreach ($job in $jobs){

    #get all SharePoint items in the job
    if ($enableSP){
        $jobItems = Get-VBOBackupItem -Job $job -Sites
            if ($jobItems) {
                foreach ($item in $jobItems){
                    $jobSPExcludeItems.Add($item)
                }
            }
            else {
                Write-Log -Info "$job has no SharePoint items" -Status Info
            }
        
    }

    #get all Teams items in the job
    if ($enableTeams){
        $jobItems = Get-VBOBackupItem -Job $job -Teams
            if ($jobItems) {
                foreach ($item in $jobItems){
                    $jobTeamsExcludeItems.Add($item)
                }
            }
            else {
                Write-Log -Info "$job has no Teams items" -Status Info
            }
    }
}

#create a list with all the Site names to exclude and write it to the log
$jobSPList = ($jobSPExcludeItems.Site.Name -join ", ")
Write-Log -Info "All SharePoint Sites found in Jobs: $jobSPList" -Status Info

#create a list with all the Teams names to exclude and write it to the log
$jobTeamsList = ($jobTeamsExcludeItems.Team.DisplayName -join ", ")
Write-Log -Info "All Teams found in Jobs: $jobTeamsList" -Status Info

### get all unprotected SP Sites
#$unprotectesSites = Get-VBOOrganizationSite -Organization $org -NotInJob
#$unprotectesTeams = Get-VBOOrganizationTeam -Organization $org -NotInJob

#merge all SharePoint Sites, Teams and the personal sites (if enabled) to exclude into one ArrayList
if ($excludePersonalSites){
    $excludedItemPersonalSites = New-VBOBackupItem -PersonalSites
    $jobAllExcludeItems = $jobSPExcludeItems + $jobTeamsExcludeItems + $excludedItemPersonalSites
}
else{
    $jobAllExcludeItems = $jobSPExcludeItems + $jobTeamsExcludeItems
}

#check if the catch all job exists
$catchallJob = get-vbojob -Organization $org -Name $catchallJobName

Write-Log -Info "-----------------------" -Status Info
#if the job exists, add the excluded items
if ($catchallJob){
    Write-Log -Info "$catchallJob found" -Status Info
    Set-VBOJob -Job $catchallJob -ExcludedItems $jobAllExcludeItems
    Write-Log -Info "$catchallJob has been updated" -Status Info
}

#if the job does not exist, create it and add the excluded items
else{
    Write-Log -Info "$catchallJob not found" -Status Info
    $selectedItems = New-VBOBackupItem -Organization $org -Sites -Teams
    Add-VBOJob -Organization $org -Name $catchallJobName -Repository $repo -SelectedItems $selectedItems -ExcludedItems $jobAllExcludeItems
    Write-Log -Info "$catchallJob has been created" -Status Info
}
Write-Log -Info "-----------------------" -Status Info