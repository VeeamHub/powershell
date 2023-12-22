<#
.SYNOPSIS
Veeam Service Provider Console (VSPC) Hosted Usage Report

.DESCRIPTION
This script will return VSPC point in time usage for VMware Cloud Director backup jobs. Usage is separated for each VSPC Company.

.PARAMETER Server
VSPC Server IP or FQDN

.PARAMETER User
VSPC Portal Administrator account username

.PARAMETER Pass
VSPC Portal Administrator account password

.PARAMETER Credential
VSPC Portal Administrator account PS Credential Object

.PARAMETER Port
VSPC Rest API port

.PARAMETER Detailed
Flag to include detailed usage in the output

.PARAMETER AllowSelfSignedCerts
Flag allowing self-signed certificates (insecure)

.OUTPUTS
Get-VspcHostedUsage.ps1 returns a PowerShell Object containing all data

.EXAMPLE
Get-VspcHostedUsage.ps1 -Server "vspc.contoso.local" -Username "contoso\jsmith" -Password "password"

Description
-----------
Connect to the specified VSPC server using the username/password specified

.EXAMPLE
Get-VspcHostedUsage.ps1 -Server "vspc.contoso.local" -Credential (Get-Credential)

Description
-----------
PowerShell credentials object is supported

.EXAMPLE
Get-VspcHostedUsage.ps1 -Server "vspc.contoso.local" -Username "contoso\jsmith" -Password "password" -Port 9999

Description
-----------
Connecting to a VSPC server using a non-standard API port

.EXAMPLE
Get-VspcHostedUsage.ps1 -Server "vspc.contoso.local" -Username "contoso\jsmith" -Password "password" -Detailed

Description
-----------
Include detailed usage in the output results

.EXAMPLE
Get-VspcHostedUsage.ps1 -Server "vspc.contoso.local" -Username "contoso\jsmith" -Password "password" -AllowSelfSignedCerts

Description
-----------
Connecting to a VSPC server that uses Self-Signed Certificates (insecure)

.NOTES
NAME:  Get-VspcHostedUsage.ps1
VERSION: 1.0
AUTHOR: Chris Arceneaux
TWITTER: @chris_arceneaux
GITHUB: https://github.com/carceneaux

.LINK
https://arsano.ninja/

.LINK
https://helpcenter.veeam.com/docs/vac/rest/about_rest.html?ver=80

#>
#Requires -Version 6.2
[CmdletBinding(DefaultParametersetName = "UsePass")]
param(
	[Parameter(Mandatory = $true)]
	[string] $Server,
	[Parameter(Mandatory = $true, ParameterSetName = "UsePass")]
	[string] $User,
	[Parameter(Mandatory = $false, ParameterSetName = "UsePass")]
	[string] $Pass = $true,
	[Parameter(Mandatory = $true, ParameterSetName = "UseCred")]
	[System.Management.Automation.PSCredential]$Credential,
	[Parameter(Mandatory = $false)]
	[Int] $Port = 1280,
	[Parameter(Mandatory = $false)]
	[Switch] $Detailed,
	[Parameter(Mandatory = $false)]
	[Switch] $AllowSelfSignedCerts
)


Function Confirm-Value {
	param($value)

	# If value exists, return value.
	if ($value) {
		return $value
	}
 else {
		# Otherwise, return zero.
		return 0
	}
}

Function Get-AsyncAction {
	param(
		[string] $ActionId,
		[System.Collections.Generic.Dictionary[[string], [string]]] $Headers
	)

	# Removing x-request-id header as it's not needed
	$Headers.Remove("x-request-id")

	# GET - /api/v3/asyncActions/{actionId} - Retrieve Async Action
	[string] $url = $baseUrl + "/api/v3/asyncActions/" + $actionId
	Write-Verbose "GET - $url"

	:loop while ($true) {
		$response = Invoke-RestMethod $url -Method 'GET' -Headers $headers -ErrorAction Stop -SkipCertificateCheck:$AllowSelfSignedCerts
		switch ($response.data.status) {
			"running" {
				Start-Sleep -Seconds 10
				break
			}
			"succeed" {
				break loop
			}
			"canceled" {
				throw "Async Action ID (" + $actionId + ") was cancelled."
			}
			"failed" {
				throw "Async Action ID (" + $actionId + ") failed with the following error message(s): " + $response.errors.message
			}
			Default	{ throw "An unknown Async Action response was detected." }
		}
	}

	# Action complete...obtaining result...
	[string] $url = $baseUrl + "/api/v3/asyncActions/" + $actionId + "/result"
	Write-Verbose "GET - $url"
	$response = Invoke-RestMethod $url -Method 'GET' -Headers $headers -ErrorAction Stop -SkipCertificateCheck:$AllowSelfSignedCerts

	return $response
	# End Retrieve Async Action
}

Function Get-PaginatedResults {
	param(
		[string] $URL,
		[System.Collections.Generic.Dictionary[[string], [string]]] $Headers,
		[PSCustomObject] $Response
	)

	# Initializing API object
	$results = [System.Collections.ArrayList]::new()
	[ref] $null = $results.Add($Response.data)

	# Determine page count
	$pageTotal = [math]::ceiling($response.meta.pagingInfo.total / $response.meta.pagingInfo.count)
	Write-Verbose "Total Pages: $pageTotal"

	# Retrieving remaining results
	$page = 0
	while ($page -ne $pageTotal) {
		# Setting offset variable
		$page++
		$offset = $page * 500  # 500 is limit
		Write-Verbose ("GET - {0}&offset={1}" -f $URL, $offset)

		# Updating x-request-id
		$guid = (New-Guid).Guid
		$Headers."x-request-id" = $guid
		Write-Verbose "x-request-id: $guid"

		$response = Invoke-RestMethod ("{0}&offset={1}" -f $URL, $offset) -Method 'GET' -Headers $Headers -ErrorAction Stop -SkipCertificateCheck:$AllowSelfSignedCerts -StatusCodeVariable responseCode
		if (202 -eq $responseCode) {
			# retrieve async action response
			$response = Get-AsyncAction -ActionId $guid -Headers $headers
		}
		[ref] $null = $results.Add($response.data)
	}

	return $results
}

Function Get-VspcApiResult {
	param(
		[string] $URL,
		[string] $Token,
		[string] $Type
	)

	try {
		# Initializing API object
		$result = [System.Collections.ArrayList]::new()

		# Setting headers
		$headers = New-Object "System.Collections.Generic.Dictionary[[string],[string]]"
		$headers.Add("Authorization", "Bearer $Token")
		$guid = (New-Guid).Guid
		$headers.Add("x-request-id", $guid)
		$headers.Add("x-client-version", $vspcApiVersion)  # API versioning using for backwards compatibility

		# Making API call
		Write-Verbose "GET - $URL"
		Write-Verbose "x-request-id: $guid"
		$response = Invoke-RestMethod $URL -Method 'GET' -Headers $headers -ErrorAction Stop -SkipCertificateCheck:$AllowSelfSignedCerts -StatusCodeVariable responseCode
		if ($null -eq $response) { return $null }  # return empty response
		if (202 -eq $responseCode) {
			# retrieve async action response
			$response = Get-AsyncAction -ActionId $guid -Headers $headers
		}

		# Is there more than 1 page of results?
		if ($response.meta.pagingInfo.count -lt $response.meta.pagingInfo.total) {
			$result = Get-PaginatedResults -URL $URL -Response $response -Headers $headers
		}
		else {
			[ref] $null = $result.Add($response.data)
		}

		return $result
	}
	catch {
		Write-Error "ERROR: Retrieving $Type Failed!"
		throw
	}
}

# Processing credentials
if ($Credential) {
	$User = $Credential.GetNetworkCredential().Username
	$Pass = $Credential.GetNetworkCredential().Password
}
else {
	if ($Pass -eq $true) {
		[securestring] $secureString = Read-Host "Enter password for '$($User)'" -AsSecureString
		[string] $Pass = [System.Net.NetworkCredential]::new("", $secureString).Password
	}
}

# Initializing global variables
[string] $baseUrl = "https://" + $Server + ":" + $Port
[string] $vspcApiVersion = "3.4"
[datetime] $date = Get-Date -Day 1 -Hour 0 -Minute 0 -Second 0
$usage = [System.Collections.ArrayList]::new()

# Logging into VSPC API
[string] $url = $baseUrl + "/api/v3/token"
Write-Verbose "POST - $url"
$headers = New-Object "System.Collections.Generic.Dictionary[[string],[string]]"
$headers.Add("Content-Type", "application/x-www-form-urlencoded")
$headers.Add("x-client-version", $vspcApiVersion)  # API versioning using for backwards compatibility
$body = "grant_type=password&username=$User&password=$Pass"
try {
	$response = Invoke-RestMethod $url -Method 'POST' -Headers $headers -Body $body -ErrorAction Stop -SkipCertificateCheck:$AllowSelfSignedCerts
	[string] $token = $response.access_token
}
catch {
	Write-Error "ERROR: Authorization Failed! Make sure the correct server and port were specified."
	throw
}

### Checking for active alarms that could cause incorrect numbers on the report

# Retrieving unique alarm IDs for the following built-in VSPC Alarms...
# Alarm 17: Veeam Service Provider Console lost connection to the managed Veeam Backup & Replication server.
[string] $url = $baseUrl + "/api/v3/alarms/templates?filter=[{'property':'internalId','operation':'equals','value':17}]"
$alarmUids = Get-VspcApiResult -URL $url -Type "Alarm IDs" -Token $token

# Retrieving active alarms for the specified ID
[string] $url = $baseUrl + "/api/v3/alarms/active?filter=[{'property':'alarmTemplateUid','operation':'equals','value':'$($alarmUids[0].instanceUid)'}]&limit=500"
$alarm17 = Get-VspcApiResult -URL $url -Type "Active Alarms $($alarmUids[0].instanceUid)" -Token $token

if ($alarm17) {
	# Retrieve hosted VBR servers
	[string] $url = $baseUrl + "/api/v3/infrastructure/backupServers?filter=[{'property':'backupServerRoleType','operation':'equals','value':'Hosted'}]&limit=500"
	$servers = Get-VspcApiResult -URL $url -Type "Hosted VBR Servers" -Token $token

	$alarms = [System.Collections.ArrayList]::new()
	foreach ($event in $alarm17) {
		# Is alarm resolved?
		if ("Resolved" -eq $event.lastActivation.status) {
			# Skip to next alarm event in loop
			Continue
		}
		
		# Checking to see if server is hosted.
		# - As this script is retrieving usage hosted VBR servers, we don't care about the rest.
		[PSCustomObject]$server = $servers | Where-Object { $_.instanceUid -eq $event.object.objectUid }
		if ($server) {
			[ref] $null = $alarms.Add($server)
		}
		Clear-Variable -Name server
	}

	# Display warning if alarms found
	if ($alarms) {
		Write-Warning "`nActive alarms are present that will cause usage report numbers to be inaccurate.`nPlease resolve these alarms and re-run this script to ensure accurate numbers.`nVeeam Service Provider Console lost connection to the following managed Veeam Backup & Replication server(s):`n$(
			$alarms | ForEach-Object {
				"`n- $($_.name) ($($_.instanceUid))"
			}
		)"
	}

	Clear-Variable -Name servers, alarms
}

### End - Checking for active alarms

### Retrieving usage numbers

# Retrieve Service Provider
[string] $url = $baseUrl + "/api/v3/organizations?filter=[{'property':'type','operation':'equals','value':'Provider'}]"
$provider = Get-VspcApiResult -URL $url -Type "Service Provider Organization" -Token $token

# Retrieve Companies
[string] $url = $baseUrl + "/api/v3/organizations/companies?expand=Organization&limit=500"
$companies = Get-VspcApiResult -URL $url -Type "Companies" -Token $token

# Retrieve VCD backup jobs
[string] $url = $baseUrl + "/api/v3/infrastructure/backupServers/jobs/backupVmJobs?expand=BackupServerJob&filter=[{'property':'subtype','operation':'equals','collation':'ignorecase','value':'vcd'}]&limit=500"
$jobs = Get-VspcApiResult -URL $url -Type "VCD Backup Jobs" -Token $token

# Loop through each job
$vms = [System.Collections.ArrayList]::new()
foreach ($job in $jobs) {

	# Retrieve VMs protected by job
	[string] $url = $baseUrl + "/api/v3/protectedWorkloads/virtualMachines?filter=[{'property':'jobUid','operation':'equals','collation':'ignorecase','value':'$($job.instanceUid)'}]&limit=500"
	$response = Get-VspcApiResult -URL $url -Type "VMs" -Token $token
	$response | ForEach-Object {
		[ref] $null = $vms.Add($_)
	}
	Clear-Variable -Name response
}

### End - Retrieving usage numbers

### Calculating per-Company usage

# Are there still unassigned VCD backup jobs?
$filteredJobs = $jobs | Where-Object { $_._embedded.backupServerJob.mappedOrganizationUid -eq $provider.instanceUid }
if ($filteredJobs) {
	Write-Warning "`nThe following VCD backup job(s) are still unassigned. This will cause usage report numbers to be inaccurate. Please ensure all VCD Organizations are mapped to a VSPC Company in the 'VcdOrganizationMapping.csv' CSV file:`n$($filteredJobs | ForEach-Object {"`n- $($_._embedded.backupServerJob.name) ($($_.instanceUid))"})"
}

# Loop through each company
foreach ($company in $companies) {
	Write-Verbose "Retrieving usage for $($company.Name) ($($company.instanceUid))"

	# Filtering usage to the specified Company Id
	$filteredJobs = $jobs | Where-Object { $_._embedded.backupServerJob.mappedOrganizationUid -eq $company.instanceUid }
	$filteredVms = $vms | Where-Object { $_.organizationUid -eq $company.instanceUid }

	# Calculating licensed workloads
	$licensedVms = $filteredVms | Where-Object { $_.latestRestorePointDate -gt $date }

	# Calculating storage
	$storage = $filteredVms | Measure-Object totalRestorePointSize -Sum

	# Generating usage object
	if ($Detailed) {
		$object = [PSCustomObject] @{
			CompanyName    = $company.name
			CompanyId      = $company.instanceUid
			# Protected is number of unique VMs protected in backups
			ProtectedCount = Confirm-Value -Value $filteredVms.count
			# Licensed is number of unique VMs protected within the current calendar month
			LicensedCount  = Confirm-Value -Value $licensedVms.count
			StorageGB      = [math]::round($storage.Sum / 1Gb, 2) #convert bytes to GB
			Jobs           = $filteredJobs
			VMs            = $filteredVms
		}
		[ref] $null = $usage.Add($object)
	}
 else {
		$object = [PSCustomObject] @{
			CompanyName    = $company.name
			CompanyId      = $company.instanceUid
			# Protected is number of unique VMs protected in backups
			ProtectedCount = Confirm-Value -Value $filteredVms.count
			# Licensed is number of unique VMs protected within the current calendar month
			LicensedCount  = Confirm-Value -Value $licensedVms.count
			StorageGB      = [math]::round($storage.Sum / 1Gb, 2) #convert bytes to GB
		}
		[ref] $null = $usage.Add($object)
	}
	Clear-Variable -Name filteredJobs, filteredVms, licensedVms, object
}
### End - Calculating per-Company usage

return $usage
