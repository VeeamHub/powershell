<#
.SYNOPSIS
Veeam Service Provider Console (VSPC) Download Management Agent for Linux OS

.DESCRIPTION
This script will download a management agent from VSPC for the specified organization. The management agent can only be installed on a machine running a Veeam-supported Linux operating system. Please note that CloudTenantId is not required if the organization is the service provider.

.PARAMETER Server
VSPC Server IP or FQDN

.PARAMETER Port
VSPC Rest API port

.PARAMETER OrgId
VSPC Organization ID

.PARAMETER LocationId
VSPC Location ID

.PARAMETER CloudTenantId
VSPC Cloud Connect Tenant ID

.PARAMETER ExpirationDays
Time period for which you want to verify the management agent, in days. The recommended value is less than 182 days. Default is 365 days.

.PARAMETER ApiKey
VSPC API Key

.PARAMETER AllowSelfSignedCerts
Flag allowing self-signed certificates (insecure)

.OUTPUTS
Get-MgmtAgentLinux.ps1 downloads a VSPC management agent for the Linux operating system to the current folder and then returns a string containing the file path of the downloaded agent.

.EXAMPLE
Get-MgmtAgentLinux.ps1 -Server "vspc.contoso.local" -OrgId "78a906f5-1005-4ced-9db4-9b147d36efb6" -LocationId "f0b8ef9f-bfe7-4e95-84e6-5f8f7b5a5bc6" -CloudTenantId "53047af7-9ddf-4faf-b8db-286bb3454408" -ApiKey "3240bf0c-79e2-4654-894b-92d21c4f7bbe..."

Description
-----------
Connect to the specified VSPC server using the API key specified and download a management agent for the specified organization, location, and Cloud Connect tenant.

.EXAMPLE
Get-MgmtAgentLinux.ps1 -Server "vspc.contoso.local" -Port 9999 -OrgId "78a906f5-1005-4ced-9db4-9b147d36efb6" -LocationId "f0b8ef9f-bfe7-4e95-84e6-5f8f7b5a5bc6" -CloudTenantId "53047af7-9ddf-4faf-b8db-286bb3454408" -ApiKey "3240bf0c-79e2-4654-894b-92d21c4f7bbe..."

Description
-----------
Connecting to a VSPC server using a non-standard API port

.EXAMPLE
Get-MgmtAgentLinux.ps1 -Server "vspc.contoso.local" -OrgId "78a906f5-1005-4ced-9db4-9b147d36efb6" -LocationId "f0b8ef9f-bfe7-4e95-84e6-5f8f7b5a5bc6" -CloudTenantId "53047af7-9ddf-4faf-b8db-286bb3454408" -ApiKey "3240bf0c-79e2-4654-894b-92d21c4f7bbe..." -AllowSelfSignedCerts

Description
-----------
Connecting to a VSPC server that uses Self-Signed Certificates (insecure)

.NOTES
NAME:  Get-MgmtAgentLinux.ps1
VERSION: 1.0
AUTHOR: Chris Arceneaux
TWITTER: @chris_arceneaux
GITHUB: https://github.com/carceneaux

.LINK
https://helpcenter.veeam.com/docs/vac/rest/reference/vspc-rest.html?ver=9

.LINK
https://helpcenter.veeam.com/docs/vac/provider_admin/api_keys.html?ver=9

.LINK
https://helpcenter.veeam.com/rn/vspc_9_release_notes.html#system-requirements-veeam-management-agents-linux-os

#>
#Requires -Version 6.2
[CmdletBinding()]
param(
	[Parameter(Mandatory = $true)]
	[string] $Server,
	[Parameter(Mandatory = $false)]
	[Int] $Port = 1280,
	[Parameter(Mandatory = $true)]
	[guid]$OrgId,
	[Parameter(Mandatory = $true)]
	[guid]$LocationId,
	[Parameter(Mandatory = $false)]
	[guid]$CloudTenantId,
	[Parameter(Mandatory = $false)]
	[ushort]$ExpirationDays = 365,
	[Parameter(Mandatory = $true)]
	[string]$ApiKey,
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

# Initializing global variables
[string] $baseUrl = "https://" + $Server + ":" + $Port
[string] $vspcApiVersion = "3.6"
$token = $ApiKey
$filePath = Join-Path -Path $PSScriptRoot -ChildPath ("\VeeamManagementAgentLinux_" + $OrgId + ".sh")

# Validating VSPC API authentication
[string] $url = $baseUrl + "/api/v3/about"
Write-Verbose "GET - $url"
try {
	$response = Get-VspcApiResult -URL $url -Type "Authentication Validation" -Token $token
	Write-Verbose "Authorization Successful"
}
catch {
	Write-Error "ERROR: Authorization Failed! Make sure the valid server, port, and API key were specified."
	throw
}

### Download Management Agent ###

# GET - /api/v3/infrastructure/managementAgents/packages/linux
Write-Verbose "Downloading Management Agent for Linux OS..."
[string] $url = $baseUrl + "/api/v3/infrastructure/managementAgents/packages/linux?organizationUid=$OrgId&locationUid=$LocationId&cloudTenantUid=$CloudTenantId&tokenExpiryPeriodDays=$ExpirationDays"

# Setting headers
$headers = New-Object "System.Collections.Generic.Dictionary[[string],[string]]"
$headers.Add("Authorization", "Bearer $token")
$headers.Add("x-client-version", $vspcApiVersion)  # API versioning using for backwards compatibility
$headers.Add("accept", "application/octet-stream")

# Making API call to download management agent
try {
	Write-Verbose "GET - $URL"
	$response = Invoke-WebRequest -Uri $URL -Method 'GET' -Headers $headers -ErrorAction Stop -SkipCertificateCheck:$AllowSelfSignedCerts -OutFile $filePath
}
catch {
	Write-Error "ERROR: Download Failed! $($_.Exception.Message)"
	throw
}

### End Script - Outputting file path of downloaded agent ###

return $filePath
