<#
.SYNOPSIS
	Start the job based migration of Jet Repositories to Object Storage Repositories

.DESCRIPTION
  This script need to be run on the VB365 Controller. It reads the configuration to make a selection for a certain job possible.
  After the selections have been made, the related proxy is getting modified and the migration started.

.OUTPUTS
	Start the Start-VBODataMigration process for a specific selected job, switch over to the new target and leaves the job disabled. 
    Before re-enabling the job, the migration needs to be verified by using the verification script.

.NOTES
	NAME:  VB365-JetToObjectMigration.ps1
	VERSION: 0.5
	AUTHOR: David Bewernick
	GITHUB: https://github.com/d-works

#>

# If VBO is installed in a different path, please replace it with your own path.
Import-Module 'C:\Program Files\Veeam\Backup365\Veeam.Archiver.PowerShell.dll'

#enable the migration option (on VB365 server)
[Environment]::SetEnvironmentVariable("VEEAM_DATA_MIGRATION_ENABLED", "true")

# Selection of organization, job, source and target repository
# Organization selection
Write-Host "Select Organization:"
$orgs = Get-VBOOrganization | Sort-Object Name
for($i=0; $i -lt $orgs.count; $i++) { Write-Host $i. $orgs[$i].name }
$organisationNum = Read-Host "Enter organization number"
$organization = $orgs[$organisationNum]
Write-Host

# Validation type selection
Write-Host "Select validation type:"
Write-Host "0. Organization"
Write-Host "1. Job"
$validationTypeNum = Read-Host "Enter validation type number"
Write-Host

if ($validationTypeNum -eq "1") {
    # Job selection
    Write-Host "Select Job:"
    $jobs = Get-VBOJob -Organization $organization | Sort-Object Name
    for($i=0; $i -lt $jobs.count; $i++) { Write-Host $i. $jobs[$i].name }
    $jobNum = Read-Host "Enter job number"
    $selectedJob = $jobs[$jobNum]
    $validationTarget = $selectedJob
    $validationType = "Job"
    $inventoryDataIdColumnName = "Backup Job Id"
    Write-Host

	# get the proxy object (holding the Jet based repository)
	$proxy = $selectedJob.Repository.Proxy

	# get the source repository (Jet based) from the job settings
	$sourceRepository = $selectedJob.Repository

} else {
	# Source Repository selection
	Write-Host "Select Source Repository:"
	$sourceRepos = Get-VBORepository | Where-Object{($_.ObjectStorageRepository -eq $Null) -and (Get-VBOEntityData -Repository $_ -Type Organization -Name $organization.Name) -ne $Null} | Sort-Object Name
	for($i=0; $i -lt $sourceRepos.count; $i++) { Write-Host $i.  $sourceRepos[$i].name }
	$sourceRepoNum = Read-Host  "Enter Source repository number"
	$sourceRepository = $sourceRepos[$sourceRepoNum]
	Write-Host

	# get the proxy object (holding the Jet based repository)
	$proxy = $sourceRepository.Proxy
}

# Target Repository selection
Write-Host "Select Target Repository:"
$targetRepos = Get-VBORepository | Where-Object{($_.ObjectStorageRepository -ne $Null)} | Sort-Object Name
for($i=0; $i -lt $targetRepos.count; $i++) { Write-Host $i. $targetRepos[$i].name }
$targetRepoNum = Read-Host  "Enter Target repository number"
$targetRepository = $targetRepos[$targetRepoNum]
Write-Host

# Switch job to target repository during migration?
Write-Host "Switch job to target repository during migration? (y/n)"
$switchJob = Read-Host

# disable the retention for the proxy
Set-VBOConfigurationParameter -XPath "/Veeam/Archiver/RepositoryConfig" -Key "RetentionDisabled" -Value "True" -Proxy $proxy

if ($validationTypeNum -eq "0") {
	# start the job mode migration process
	if($switchJob -eq "y") { 
		Start-VBODataMigration -Organization $organization -From $sourceRepository -To $targetRepository -SwitchJobToTargetRepository -RunAsync 
	}
	else { 
		Start-VBODataMigration -Organization $organization -From $sourceRepository -To $targetRepository -RunAsync 
	}
}

if ($validationTypeNum -eq "1") {
	# start the job mode migration process
	if($switchJob -eq "y") { 
		Start-VBODataMigration -Job $selectedJob -From $sourceRepository -To $targetRepository -SwitchJobToTargetRepository -RunAsync 
	}
	else { 
		Start-VBODataMigration -Job $selectedJob -From $sourceRepository -To $targetRepository -RunAsync 
	}
}



# -------------------
# wait until migration run is finished. to check the status, start a new console and run:
# [Environment]::SetEnvironmentVariable("VEEAM_DATA_MIGRATION_ENABLED", "true")
# Get-VBODataMigration
# -------------------

# !! validate source and target with script  "Jet to OSR migration script.ps1"!!

# Remove taget repository lock
# Remove-VBODataMigrationLock -Repository $targetRepository

# enable the retention for the proxy after validation is successful
# Set-VBOConfigurationParameter -XPath "/Veeam/Archiver/RepositoryConfig" -Key "RetentionDisabled" -Value "False" -Proxy $proxy