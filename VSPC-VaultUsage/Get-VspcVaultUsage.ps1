<#
.SYNOPSIS
Veeam Service Provider Console (VSPC) Vault Usage Report

.DESCRIPTION
This script will return point in time usage of all Veeam Data Cloud Vault repositories connected to Veeam Backup & Replication servers managed by VSPC. Usage is separated by each Vault for each VSPC Company.

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
Get-VspcVaultUsage.ps1 returns a PowerShell Object containing all data

.EXAMPLE
Get-VspcVaultUsage.ps1 -Server "vspc.contoso.local" -Username "contoso\jsmith" -Password "password"

Description
-----------
Connect to the specified VSPC server using the username/password specified

.EXAMPLE
Get-VspcVaultUsage.ps1 -Server "vspc.contoso.local" -Credential (Get-Credential)

Description
-----------
PowerShell credentials object is supported

.EXAMPLE
Get-VspcVaultUsage.ps1 -Server "vspc.contoso.local" -Username "contoso\jsmith" -Password "password" -Port 9999

Description
-----------
Connecting to a VSPC server using a non-standard API port

.EXAMPLE
Get-VspcVaultUsage.ps1 -Server "vspc.contoso.local" -Username "contoso\jsmith" -Password "password" -Detailed

Description
-----------
Include detailed usage in the output results

.EXAMPLE
Get-VspcVaultUsage.ps1 -Server "vspc.contoso.local" -Username "contoso\jsmith" -Password "password" -AllowSelfSignedCerts

Description
-----------
Connecting to a VSPC server that uses Self-Signed Certificates (insecure)

.EXAMPLE
Get-VspcVaultUsage.ps1 -Server "vspc.contoso.local" -Username "contoso\jsmith" -Password "password" -Verbose

Description
-----------
Enables verbose output for troubleshooting

.NOTES
NAME:  Get-VspcVaultUsage.ps1
VERSION: 1.0
AUTHOR: Chris Arceneaux
TWITTER: @chris_arceneaux
GITHUB: https://github.com/carceneaux

.LINK
https://helpcenter.veeam.com/references/vac/9.1/rest/tag/Backup-Servers#operation/GetBackupRepositories

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
[string] $vspcApiVersion = "3.6.1"  # API versioning using for backwards compatibility
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
	foreach ($alarmEvent in $alarm17) {
		# Is alarm resolved?
		if ("Resolved" -eq $alarmEvent.lastActivation.status) {
			# Skip to next alarm alarm event in loop
			Continue
		}
		else {
			[ref] $null = $alarms.Add($alarmEvent)
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

### Retrieving usage numbers

# Retrieve Vault Repositories
[string] $url = $baseUrl + "/api/v3/infrastructure/backupServers/repositories?expand=BackupRepositoryInfo&filter=[{'property':'_embedded.type','operation':'equals','value':'VeeamVault'}]&limit=500"
$vaults = Get-VspcApiResult -URL $url -Type "Vaults" -Token $token

# If no vaults found, exit script
if ($vaults.count -eq 0) {
	Write-Warning "No Veeam Data Cloud Vault repositories were found in this VSPC environment. Exiting script."
	return $null
}

# Retrieve Service Provider
[string] $url = $baseUrl + "/api/v3/organizations?filter=[{'property':'type','operation':'equals','value':'Provider'}]"
$provider = Get-VspcApiResult -URL $url -Type "Service Provider Organization" -Token $token

# Retrieve Companies
[string] $url = $baseUrl + "/api/v3/organizations/companies?expand=Organization&limit=500"
$companies = Get-VspcApiResult -URL $url -Type "Companies" -Token $token
$companies += $provider  # Including Service Provider in the list of Companies

# Retrieve Backup servers managed by VSPC
[string] $url = $baseUrl + "/api/v3/infrastructure/backupServers?limit=500"
$backupServers = Get-VspcApiResult -URL $url -Type "Backup Servers" -Token $token

### End - Retrieving usage numbers

### Calculating per-Company usage

# Loop through each company
foreach ($company in $companies) {
	Write-Verbose "Retrieving Vault usage for $($company.Name) ($($company.instanceUid))"

	# Filtering backup servers to only those assigned to the current Company
	$companyBackupServers = $backupServers | Where-Object { $_.organizationUid -eq $company.instanceUid }

	# Filtering vault repositories to only those assigned to the current Company's backup servers
	$companyVaults = $vaults | Where-Object { $_.backupServerUid -in $companyBackupServers.instanceUid }
	if ($companyVaults.count -eq 0) {
		Write-Verbose "No Vault repositories found for $($company.Name) ($($company.instanceUid)). Skipping to next Company."
		continue
	}

	foreach ($vault in $companyVaults) {
		# Generating usage object
		if ($Detailed) {
			$object = [PSCustomObject] @{
				CompanyName      = $company.name
				CompanyId        = $company.instanceUid
				BackupServerId   = $vault.backupServerUid
				VaultName        = $vault.name
				VaultId          = $vault.instanceUid
				ImmutabilityDays = $vault._embedded.immutabilityInterval / 60 / 60 / 24 #convert seconds to days
				CapacityGB       = [math]::round($vault._embedded.capacity / 1Gb, 3) #convert bytes to GB
				FreeSpaceGB      = [math]::round($vault._embedded.freeSpace / 1Gb, 3) #convert bytes to GB
				UsedSpaceGB      = [math]::round($vault._embedded.usedSpace / 1Gb, 3) #convert bytes to GB
				BackupSizeGB     = [math]::round($vault._embedded.backupSize / 1Gb, 2) #convert bytes to GB
			}
			[ref] $null = $usage.Add($object)
		}
		else {
			$object = [PSCustomObject] @{
				CompanyName = $company.name
				VaultName   = $vault.name
				UsedGB      = [math]::round($vault._embedded.usedSpace / 1Gb, 3) #convert bytes to GB
			}
			[ref] $null = $usage.Add($object)
		}
		Clear-Variable -Name companyBackupServers, companyVaults, object
	}
}
### End - Calculating per-Company usage

return $usage
