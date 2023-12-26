<#
.SYNOPSIS
Veeam Service Provider Console (VSPC) Storage Usage Report

.DESCRIPTION
This script will return usage and metadata for all backup repositories for the specified VSPC server.

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

.PARAMETER AllowSelfSignedCerts
Flag allowing self-signed certificates (insecure)

.OUTPUTS
Get-VspcStorageUsage.ps1 returns a PowerShell Object containing all data

.EXAMPLE
Get-VspcStorageUsage.ps1 -Server "vspc.contoso.local" -Username "contoso\jsmith" -Password "password"

Description
-----------
Connect to the specified VSPC server using the username/password specified

.EXAMPLE
Get-VspcStorageUsage.ps1 -Server "vspc.contoso.local" -Credential (Get-Credential)

Description
-----------
PowerShell credentials object is supported

.EXAMPLE
Get-VspcStorageUsage.ps1 -Server "vspc.contoso.local" -Username "contoso\jsmith" -Password "password" -Port 9999

Description
-----------
Connecting to a VSPC server using a non-standard API port

.EXAMPLE
Get-VspcStorageUsage.ps1 -Server "vspc.contoso.local" -Username "contoso\jsmith" -Password "password" -AllowSelfSignedCerts

Description
-----------
Connecting to a VSPC server that uses Self-Signed Certificates (insecure)

.NOTES
NAME:  Get-VspcStorageUsage.ps1
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
	[Switch] $AllowSelfSignedCerts
)

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
	$alarms = [System.Collections.ArrayList]::new()
	foreach ($event in $alarm17) {
		# Is alarm resolved?
		if ("Resolved" -eq $event.lastActivation.status) {
			# Skip to next alarm event in loop
			Continue
		}
		else {
			[ref] $null = $alarms.Add($event)
		}
	}

	# Display warning if alarms found
	if ($alarms) {
		Write-Warning "`nActive alarms are present that will cause usage report numbers to be inaccurate.`nPlease resolve these alarms and re-run this script to ensure accurate numbers.`nVeeam Service Provider Console has lost connection to the following managed Veeam Backup & Replication server(s):`n$(
			$alarms | ForEach-Object {
				"`n- $($_.object.computerName) ($($_.object.objectUid))"
			}
		)"
	}
}

# Alarm 41: Veeam Service Provider Console has lost connection to the Cloud Connect server.
[string] $url = $baseUrl + "/api/v3/alarms/templates?filter=[{'property':'internalId','operation':'equals','value':41}]"
$alarmUids = Get-VspcApiResult -URL $url -Type "Alarm IDs" -Token $token

# Retrieving active alarms for the specified ID
[string] $url = $baseUrl + "/api/v3/alarms/active?filter=[{'property':'alarmTemplateUid','operation':'equals','value':'$($alarmUids[0].instanceUid)'}]&limit=500"
$alarm41 = Get-VspcApiResult -URL $url -Type "Active Alarms $($alarmUids[0].instanceUid)" -Token $token


if ($alarm41) {
	$alarms = [System.Collections.ArrayList]::new()
	foreach ($event in $alarm41) {
		# Is alarm resolved?
		if ("Resolved" -eq $event.lastActivation.status) {
			# Skip to next alarm event in loop
			Continue
		}
		else {
			[ref] $null = $alarms.Add($event)
		}
	}

	# Display warning if alarms found
	if ($alarms) {
		Write-Warning "`nActive alarms are present that will cause usage report numbers to be inaccurate.`nPlease resolve these alarms and re-run this script to ensure accurate numbers.`nVeeam Service Provider Console has lost connection to the following Cloud Connect server(s):`n$(
			$alarms | ForEach-Object {
				"`n- $($_.object.computerName) ($($_.object.objectUid))"
			}
		)"
	}
}

### End - Checking for active alarms

### Retrieving usage numbers

# Retrieve Organizations
[string] $url = $baseUrl + "/api/v3/organizations?limit=500"
$organizations = Get-VspcApiResult -URL $url -Type "Organizations" -Token $token

# Retrieve Repositories
[string] $url = $baseUrl + "/api/v3/infrastructure/backupServers/repositories?limit=500"
$repositories = Get-VspcApiResult -URL $url -Type "Repositories" -Token $token

# Retrieve Servers
[string] $url = $baseUrl + "/api/v3/infrastructure/backupServers?limit=500"
$servers = Get-VspcApiResult -URL $url -Type "Servers" -Token $token

### End - Retrieving usage numbers

### Generating usage object for output

# Loop through each repository
foreach ($repo in $repositories) {
	Write-Verbose "Retrieving usage for $($repo.Name) ($($repo.instanceUid))"

	# Identifying backup server
	[PSCustomObject]$server = $servers | Where-Object { $_.instanceUid -eq $repo.backupServerUid }

	# Identifying organization
	[PSCustomObject]$organization = $organizations | Where-Object { $_.instanceUid -eq $server.organizationUid }

	# Generating usage object
	# Converts bytes to GB - [math]::round( $value / 1Gb, 2)
	$object = [PSCustomObject] @{
		Name                  = $repo.name
		Id                    = $repo.instanceUid
		CapacityGB            = [math]::round( $repo.capacity / 1Gb, 2)
		FreeSpaceGB           = [math]::round( $repo.freeSpace / 1Gb, 2)
		UsedSpaceGB           = [math]::round( $repo.usedSpace / 1Gb, 2) # used space as reported by storage
		BackupSizeGB          = [math]::round( $repo.backupSize / 1Gb, 2) # sum of all backups located on repo
		# Is available?
		IsCapacityAvailable   = $repo.isCapacityAvailable
		IsFreeSpaceAvailable  = $repo.isCapacityAvailable
		IsUsedAvailable       = $repo.isCapacityAvailable
		# Is immutability enabled?
		IsImmutabilityEnabled = $repo.isImmutabilityEnabled
		ImmutabilityIntervalDays  = $repo.immutabilityInterval / 60 / 60 / 24 # converting seconds to days
		# Metadata...
		OrganizationName      = $organization.name
		OrganizationUid       = $organization.instanceUid
		BackupServerName      = $server.name
		BackupServerUid       = $repo.backupServerUid
		ParentRepositoryUid   = $repo.parentRepositoryUid
		Status                = $repo.status
		Type                  = $repo.type
		PerVmBackupFiles      = $repo.perVMBackupFiles
		IsCloud               = $repo.IsCloud
		CloudRepositoryUid    = $repo.cloudRepositoryUid
		IsOutOfDate           = $repo.isOutOfDate
		Path                  = $repo.path
		HostName              = $repo.hostName
		HostUid               = $repo.hostUid
	}
	[ref] $null = $usage.Add($object)
	Clear-Variable -Name server, organization, object
}
### End - Generating usage object for output

return $usage
