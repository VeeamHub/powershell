<#
.SYNOPSIS
Veeam Service Provider Console (VSPC) Retrieve Organization Information

.DESCRIPTION
This script will retrieve Organization information from VSPC. Information is separated for each VSPC Organization.

.PARAMETER Server
VSPC Server IP or FQDN

.PARAMETER Port
VSPC Rest API port

.PARAMETER ApiKey
VSPC API Key

.PARAMETER AllowSelfSignedCerts
Flag allowing self-signed certificates (insecure)

.OUTPUTS
Get-OrgInfo.ps1 returns a PowerShell Object containing all data

.EXAMPLE
Get-OrgInfo.ps1 -Server "vspc.contoso.local" -ApiKey "3240bf0c-79e2-4654-894b-92d21c4f7bbe..."

Description
-----------
Connect to the specified VSPC server using the API key specified

.EXAMPLE
Get-OrgInfo.ps1 -Server "vspc.contoso.local" -Port 9999 -ApiKey "3240bf0c-79e2-4654-894b-92d21c4f7bbe..."

Description
-----------
Connecting to a VSPC server using a non-standard API port

.EXAMPLE
Get-OrgInfo.ps1 -Server "vspc.contoso.local" -ApiKey "3240bf0c-79e2-4654-894b-92d21c4f7bbe..." -AllowSelfSignedCerts

Description
-----------
Connecting to a VSPC server that uses Self-Signed Certificates (insecure)

.NOTES
NAME:  Get-OrgInfo.ps1
VERSION: 1.0
AUTHOR: Chris Arceneaux
TWITTER: @chris_arceneaux
GITHUB: https://github.com/carceneaux

.LINK
https://helpcenter.veeam.com/docs/vac/rest/reference/vspc-rest.html?ver=9

.LINK
https://helpcenter.veeam.com/docs/vac/provider_admin/api_keys.html?ver=9

#>
#Requires -Version 6.2
[CmdletBinding()]
param(
	[Parameter(Mandatory = $true)]
	[string] $Server,
	[Parameter(Mandatory = $false)]
	[Int] $Port = 1280,
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
$output = [System.Collections.ArrayList]::new()
$token = $ApiKey

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

# Retrieve Organizations (excluding Resellers)
[string] $url = $baseUrl + "/api/v3/organizations?filter=[{'property':'type','operation':'notEquals','collation':'ignorecase','value':'Reseller'}]&limit=500"
$organizations = Get-VspcApiResult -URL $url -Type "Organizations" -Token $token

# Retrieve Locations
[string] $url = $baseUrl + "/api/v3/organizations/locations?limit=500"
$locations = Get-VspcApiResult -URL $url -Type "Locations" -Token $token

# Retrieve Cloud Connect Tenants
[string] $url = $baseUrl + "/api/v3/infrastructure/sites/tenants?limit=500"
$tenants = Get-VspcApiResult -URL $url -Type "Cloud Connect Tenants" -Token $token

# Loop through each Organization
foreach ($organization in $organizations) {
	Write-Verbose "Retrieving info for $($organization.Name) ($($organization.instanceUid))"

	# Generating location object
	$location = $locations | Where-Object { $_.organizationUid -eq $organization.instanceUid } | Select-Object "name", "instanceUid", "type"

	# Generating output object
	$object = [PSCustomObject] @{
		Name          = $organization.name
		Type          = $organization.type
		OrgId         = $organization.instanceUid
		Location      = $location
		CloudTenantId = ($tenants | Where-Object { $_.assignedForCompany -eq $organization.instanceUid }).instanceUid
	}
	[ref] $null = $output.Add($object)
}
Clear-Variable -Name object

### End Script - Outputting results ###

return $output
