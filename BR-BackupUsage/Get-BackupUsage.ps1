<#
.SYNOPSIS
	Veeam Backup & Replication (VBR) Backup Usage

.DESCRIPTION
    This script will allow you to pull VBR Backup usage
    including space used in Backup Repositories and SOBR (Performance & Capacity).

.PARAMETER Server
	Veeam Backup & Replication server

.PARAMETER Username
	Veeam Backup & Replication Administrator account username

.PARAMETER Password
	Veeam Backup & Replication Administrator account password

.PARAMETER Credential
	Veeam Backup & Replication Administrator account PS Credential Object

.OUTPUTS
    Get-BackupUsage returns a PowerShell object containing VBR Backup usage

.EXAMPLE
	Get-BackupUsage.ps1 -Server "vbr.contoso.local" -Username "contoso\jdoe" -Password "password"

	Description 
	-----------     
	Pulling VBR Backup usage using the specified VBR server using the username/password specified

.EXAMPLE
	Get-BackupUsage.ps1 -Server "vbr.contoso.local" -Username "contoso\jdoe"

	Description 
	-----------     
	If the password is omitted, you will be asked for it later in the script

.EXAMPLE
	Get-BackupUsage.ps1 -Server "vbr.contoso.local" -Credential (Get-Credential)

	Description 
	-----------     
	PowerShell credentials object is supported

.EXAMPLE
	Get-BackupUsage.ps1 -Server "vbr.contoso.local" -Credential $Credential -Verbose

	Description 
	-----------     
	Verbose output is supported

.NOTES
	NAME:  Get-BackupUsage.ps1
	VERSION: 1.0
	AUTHOR: Chris Arceneaux
	TWITTER: @chris_arceneaux
	GITHUB: https://github.com/carceneaux

.LINK
	https://arsano.ninja/
#>
[CmdletBinding(DefaultParametersetName="UsePass")]
param(
    [Parameter(Mandatory=$true)]
		[String] $Server,
	[Parameter(Mandatory=$true, ParameterSetName="UsePass")]
		[String] $Username,
	[Parameter(Mandatory=$false)]
		[string] $Password = $true,
	[Parameter(Mandatory=$true, ParameterSetName="UseCred")]
		[System.Management.Automation.PSCredential]$Credential
)

# Initializing Variables
$location = Split-Path -Parent $MyInvocation.MyCommand.Definition
if (-Not $Credential) {
    if ($Password -eq $true) {
        $secPass = Read-Host "Enter password for '$($Username)'" -AsSecureString
        
    } else {
        $secPass = ConvertTo-SecureString $Password -AsPlainText -Force
    }
    $Credential = New-Object System.Management.Automation.PSCredential ($Username, $secPass)
}

# Registering VeeamPSSnapin if necessary
$registered = $false
foreach ($snapin in (Get-PSSnapin)) {
    if ($snapin.Name -eq "veeampssnapin") { $registered = $true }
}
if ($registered -eq $false) { add-pssnapin veeampssnapin }

Write-Verbose "Connecting to VBR Server"
Connect-VBRServer -Server $server -Credential $Credential

# Validating successful connection to VBR server
if (-Not (Get-VBRServerSession)){
    Write-Warning "$($server): Connection failed - Please make sure the server was not misspelled and valid credentials were used."
    
    # Exiting script
    exit
}

Write-Verbose "Retrieving all VBR Jobs"
$jobs = Get-VBRJob

Write-Verbose "Retrieving all VBR Backups"
$backups = Get-VBRBackup

Write-Verbose "Beginning loop through VBR Backup Jobs"
$usage = @()
foreach ($job in $jobs) {

    Write-Verbose "Pulling usage for Job: $($job.Name)"

    # Zeroing out space usage
    $usedBlock = 0
    $usedObject = 0
    
    # Retrieving Backups Sessions for Job
    $backupFiles = $null
    $backup = $backups | Where-Object { $_.Name -eq $job.Name }

    # Does the job have Backup Sessions?
    if ($backup) {
        
        # Determine Job type
        switch ($job.JobType) {
            "Backup" { #Backup
                Write-Verbose "$($job.Name) is a Backup Job: Retrieving Restore Points"
                $backupFiles += $backup.GetAllStorages()
                break
            }
            "BackupSync" { #Backup Copy
                Write-Verbose "$($job.Name) is a Backup Copy Job: Retrieving Restore Points"
                $backupFiles += $backup.GetAllStorages()
                break
            }
            "EpAgentPolicy" { #Agent Policy Backup (Protection Group)
                Write-Verbose "$($job.Name) is an Agent Policy (Protection Group): Retrieving Restore Points"
                $backupFiles += $backup.GetAllChildrenStorages()
                break
            }
            "EpAgentBackup" { #Agent Backup
                Write-Verbose "$($job.Name) is an Agent Backup Job: Retrieving Restore Points"
                $backupFiles += $backup.GetAllChildrenStorages()
                break
            }
            default { #Unsupported Job Type
                Write-Warning "$($job.Name): JobType - $($job.JobType) - is currently unsupported in this script. Skipping..."
                continue
            }
        }
    }

    # Does the job have Child Jobs?
    $childJobs = $job.GetChildJobs()
    
    # Looping through Child Jobs
    foreach ($childJob in $childJobs) {

        Write-Verbose "Child Job found: $($childJob.Name)"

        # Finding Child Backup Sessions
        $backup = $backups | Where-Object { $_.Name -eq $childJob.Name }

        # Does the Child Job have Backup Sessions?
        if ($backup) {

            # Determine Child Job type
            switch ($childJob.JobType) {
                "SqlLogBackup" { #SQL Transaction Log Backup
                    Write-Verbose "$($childJob.Name) is a SQL Log Backup Job: Retrieving Restore Points"
                    $backupFiles += $backup.GetAllStorages()
                    break
                }
                default { #Unsupported Child Job Type
                    Write-Warning "$($childJob.Name): JobType - $($childJob.JobType) - is currently unsupported in this script. Skipping..."
                    break
                }
            }
        }
    }

    # Checking for Restore Points - each backup file is a RP
    if ($backupFiles) {

        Write-Verbose "Restore Points found: Calculating storage usage"

        # Split up Restore Points by tier
        $performance = $backupFiles | Where-Object { $_.IsContentExternal -eq $false }
        $capacity = $backupFiles | Where-Object { $_.IsContentExternal -eq $true }

        # Calculate block storage usage (Backup Repository & SOBR Performance Tier)
        $total = ($performance.Stats.BackupSize | Measure-Object -Sum).sum
        $usedBlock += [math]::round($total / 1Gb, 2) #convert from bytes to GB

        # Calculate object storage usage (SOBR Capacity Tier)
        $total = ($capacity.Stats.BackupSize | Measure-Object -Sum).sum
        $usedObject += [math]::round($total / 1Gb, 2) #convert bytes to GB
    }

    # Creating PSObject for Job usage
    $obj = New-Object PSObject -Property @{
        Id = $job.Id.Guid
        Name = $job.Name
        Description = $job.Description
        Enabled = $job.info.IsScheduleEnabled
        UsedBlockGB = $usedBlock
        UsedObjectGB = $usedObject
        BackupFiles = $backupFiles
    }
    $usage += $obj
}

# Terminating VBR server session
Disconnect-VBRServer

# Returning usage
return $usage
