<#
.SYNOPSIS
	Enforces retention standards for Veeam Jobs
.DESCRIPTION
    This script looks for both VMware Backup Jobs & vCloud Backup Jobs, retrieves their current retention setting (Restore Points), compares the retention against the published standard (joblist.csv), and adjusts the configuration where needed.
.OUTPUTS
	Set-VeeamJobRetention.ps1 returns a PowerShell object containing a list of all reviewed Backup Jobs
.PARAMETER Server
	Veeam Backup & Replication server
.PARAMETER User
	Veeam Backup & Replication Administrator account username
.PARAMETER Pass
	Veeam Backup & Replication Administrator account password
.PARAMETER Credential
	Veeam Backup & Replication Administrator account PS Credential Object
.EXAMPLE
	Set-VeeamJobRetention.ps1 -Server "vbr.contoso.local" -Username "contoso\jdoe" -Password "password"
	Description
	-----------
	Compares VBR job retention settings against standards using the specified VBR server using the username/password specified
.EXAMPLE
	Set-VeeamJobRetention.ps1 -Server "vbr.contoso.local" -Username "contoso\jdoe"
	Description
	-----------
	If the password is omitted, you will be asked for it later in the script
.EXAMPLE
	Set-VeeamJobRetention.ps1 -Server "vbr.contoso.local" -Credential (Get-Credential)
	Description
	-----------
	PowerShell credentials object is supported
.EXAMPLE
	Set-VeeamJobRetention.ps1 -Server "vbr.contoso.local" -Credential $Credential -Verbose
	Description
	-----------
	Verbose output is supported
.EXAMPLE
	Set-VeeamJobRetention.ps1 -WhatIf
	Description
	-----------
	WhatIf flag is supported
.NOTES
	NAME:  Set-VeeamJobRetention.ps1
	VERSION: 1.0
	AUTHOR: Chris Arceneaux
	TWITTER: @chris_arceneaux
	GITHUB: https://github.com/carceneaux
.LINK
	https://arsano.ninja/
.LINK
    https://helpcenter.veeam.com/docs/backup/vsphere/silent_mode.html?ver=110
.LINK
    https://helpcenter.veeam.com/docs/backup/vsphere/upgrade_vbr.html?ver=110
#>
[CmdletBinding(
    DefaultParameterSetName = "UsePass",
    SupportsShouldProcess = $true
)]
param(
    [Parameter(Mandatory = $true)]
    [String] $Server,
    [Parameter(Mandatory = $true, ParameterSetName = "UsePass")]
    [String] $User,
    [Parameter(Mandatory = $false)]
    [string] $Pass = $true,
    [Parameter(Mandatory = $true, ParameterSetName = "UseCred")]
    [System.Management.Automation.PSCredential]$Credential
)

# Initializing Variables
$location = Split-Path -Parent $MyInvocation.MyCommand.Definition
$standards = Import-Csv -Path "$location/joblist.csv"
$output = New-Object -TypeName System.Collections.Generic.List[PSCustomObject]

# Generating PSCredential object if required
if (-Not $Credential) {
    if ($Pass -eq $true) {
        $secPass = Read-Host "Enter password for '$($User)'" -AsSecureString

    }
    else {
        $secPass = ConvertTo-SecureString $Pass -AsPlainText -Force
    }
    $Credential = New-Object System.Management.Automation.PSCredential ($User, $secPass)
}

# Accounts for switch from PSSnapin to Module in v11
if (-Not (Get-Module -ListAvailable -Name Veeam.Backup.PowerShell)) {
    Add-PSSnapin -PassThru VeeamPSSnapIn -ErrorAction Stop | Out-Null
}

Write-Verbose "Connecting to VBR Server"
Connect-VBRServer -Server $server -Credential $Credential

# Validating successful connection to VBR server
if (-Not (Get-VBRServerSession)) {
    Write-Warning "$($server): Connection failed - Please make sure the server was not misspelled and valid credentials were used."

    # Exiting script
    exit
}

Write-Verbose "Retrieving all VBR Jobs (VMware/vCloud)"
$jobs = Get-VBRJob -WarningAction SilentlyContinue | Where-Object { ($_.TypeToString -eq "VMware Backup") -or ($_.TypeToString -eq "vCloud Backup") }

Write-Verbose "Beginning loop through VBR Backup Jobs"
foreach ($job in $jobs) {
    $changed = $false

    Write-Verbose ""
    Write-Verbose "Retrieving retention settings and standards for Job: $($job.Name)"
    $options = $job.GetOptions()
    $standard = $standards | Where-Object { $_.JobName -eq $job.Name }
    if (-Not $standard) {
        Write-Verbose "Job not defined in joblist.csv...using default retention standard"
        $standard = $standards | Where-Object { ($_.JobName -eq "default") -and ($_.JobType -eq $job.TypeToString) }
    }

    Write-Verbose "Comparing current setting ($($options.BackupStorageOptions.RetainCycles)) to standard ($($standard.RestorePoints))"
    # 1. Does retention configured match standard?
    # 2. Is the retention type set to Restore Points?
    # Cycles == Restore Points
    # Days == Days
    if (($standard.RestorePoints -ne $options.BackupStorageOptions.RetainCycles) -or ($options.BackupStorageOptions.RetentionType -ne "Cycles")) {
        Write-Verbose "Variance discovered. Updating Job retention to match standard."
        $changed = $true

        # WhatIf support
        if ($PSCmdlet.ShouldProcess($job.Name, "Update Job Retention")) {
            # Updates Restore Point
            $options.BackupStorageOptions.RetainCycles = $standard.RestorePoints
            # Updates Retention Type (Restore Points/Days)
            $options.BackupStorageOptions.RetentionType = "Cycles"
            # Actually updates the job
            Set-VBRJobOptions $job $options | Out-Null
        }
    }

    $output.Add([PSCustomObject]@{
            ID      = $job.Id;
            Name    = $job.Name;
            Type    = $job.TypeToString;
            Updated = $changed
        })
}

Write-Verbose "Disconnecting from VBR Server"
Disconnect-VBRServer

Write-Verbose "Returning PSObject"
return $output
