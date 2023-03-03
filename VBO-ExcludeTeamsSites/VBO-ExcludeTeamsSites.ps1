<# 
.NAME
    Exclude Teams SharePoint Site in Veeam Backup for Microsoft Office 365 
.SYNOPSIS
    Script to exclude the SharePoint Sites related to MS Teams in backup jobs
.DESCRIPTION
    This script reads the available MS Teams and adds their names as an exclude to a backup job.
	
	ATTENTION: 
	A job to protect MS Teams does not backup the complete SharePoint Site related to this Team.
	So be aware that you might not protect data that has been added or changed outsite of a Team! 
	
	Developed with Veeam Backup for Microsoft Office 365 build version 5.0.1.179.
	To be used under the MIT license.
.LINK
    https://github.com/wcbuerste
#>

# Load the required Veeam Backup for Microsoft Office 365 PowerShell modules if you have PowerShell version 2.0
# Import-Module Veeam.Archiver.PowerShell
# Import-Module Veeam.SharePoint.PowerShell
# Import-Module Veeam.Teams.PowerShell

# enable (1) or disable (0) logging
$LogEnable = 1

# modify to fit to you organization
$OrgName = "YOURORGNAME"

# modify to fit to your SharePoint backup job
$SPjobName = "YOURJOB"

# set the logfile path
$LogFile = "C:\scripts\logs\VBO-excludeTeamsSites_$SPjobName.log"

function Write-Log($Info, $Status){
	if ($LogEnable -eq 1){
		$timestamp = get-date -Format "yyyy-mm-dd HH:mm:ss"
		switch($Status){
			Info    {Write-Host "$timestamp $Info" -ForegroundColor Green  ; "$timestamp $Info" | Out-File -FilePath $LogFile -Append}
			Status  {Write-Host "$timestamp $Info" -ForegroundColor Yellow ; "$timestamp $Info" | Out-File -FilePath $LogFile -Append}
			Warning {Write-Host "$timestamp $Info" -ForegroundColor Yellow ; "$timestamp $Info" | Out-File -FilePath $LogFile -Append}
			Error   {Write-Host "$timestamp $Info" -ForegroundColor Red -BackgroundColor White; "$timestamp $Info" | Out-File -FilePath $LogFile -Append}
			default {Write-Host "$timestamp $Info" -ForegroundColor white "$timestamp $Info" | Out-File -FilePath $LogFile -Append}
		}
	}
}

Write-Log -Info " " -Status Info
Write-Log -Info "-------------- NEW SESSION --------------" -Status Info
Write-Log -Info " " -Status Info

# Connecto to the local Veeam Backup for Microsoft Office 365 Server
try {
		Connect-VBOServer
		Write-Log -Info "Connected to VBO server" -Status Info
	} 
	catch  {
		Write-Log -Info "$_" -Status Error
		Write-Log -Info "Failed to connecto to VBo server" -Status Error
		exit
	}

# get the organization
try {
		$Org = Get-VBOOrganization -Name $OrgName
		Write-Log -Info "Got details for $Org" -Status Info
	} 
	catch  {
		Write-Log -Info "$_" -Status Error
		Write-Log -Info "Failed to load details for $Org" -Status Error
		exit
	}

# get the MS Teams
try {
		$Teams = Get-VBOOrganizationTeam -Organization $org
		Write-Log -Info "Got Teams in $org" -Status Info
	} 
	catch  {
		Write-Log -Info "$_" -Status Error
		Write-Log -Info "Failed to load Teams in $org" -Status Error
		exit
	}
	
# get the SharePoint Sites
try {
		$Sites = Get-VBOOrganizationSite -Organization $org
		Write-Log -Info "Got Sites in $org" -Status Info
	} 
	catch  {
		Write-Log -Info "$_" -Status Error
		Write-Log -Info "Failed to load Sites in $org" -Status Error
		exit
	}

# get the SharePoint job
try {
		$Job = get-VBOJob -Name $SPjobName
		Write-Log -Info "Got details for $SPjobName" -Status Info
	} 
	catch  {
		Write-Log -Info "$_" -Status Error
		Write-Log -Info "Failed to load details for $SPjobName" -Status Error
		exit
	}

#get the excluded items in the job
try {
		$JobExclusions = Get-VBOExcludedBackupitem -Job $job
		Write-Log -Info "Got exclusions for $job" -Status Info
	} 
	catch  {
		Write-Log -Info "$_" -Status Error
		Write-Log -Info "Failed to load exclusions for $job" -Status Error
		exit
	}
	

foreach ($Team in $Teams) {
	$TeamName = $Team.DisplayName
	Write-Host "Team name: $TeamName"
	if ($JobExclusions.Site.Name -contains $TeamName)
	{
		Write-Log -Info "$TeamName is alread excluded" -Status Status
	}	
	else {
		try {
			$ExcludeSite = $Sites | Where-Object -Property Name -EQ $TeamName
			Write-Host "ExcludeSite: $ExcludeSite"
			$ExcludeItem = New-VBOBackupItem -Site $ExcludeSite
			Write-Host "ExcludeItem: $ExcludeItem"
			Add-VBOExcludedBackupItem -Job $Job -BackupItem $ExcludeItem
			Write-Log -Info "Excluded $TeamName in $job" -Status Info
		} 
		catch  {
			Write-Log -Info "$_" -Status Error
			Write-Log -Info "Failed to exclude $TeamName in $job" -Status Error
			exit
		}
	}
}
Disconnect-VBOServer