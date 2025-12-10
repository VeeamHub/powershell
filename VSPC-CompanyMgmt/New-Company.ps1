<#
.SYNOPSIS
Veeam Service Provider Console (VSPC) Create new company

.DESCRIPTION
This script will create a new company and will link it to a new Cloud Connect tenant. Please note that this script only asks for required parameters to create a new company. Additional parameters can be added to the body of the POST request in order to customize the new company and tenant settings. See VSPC REST API documentation link below for more details.

.PARAMETER Server
VSPC Server IP or FQDN

.PARAMETER Port
VSPC Rest API port

.PARAMETER User
VSPC username

.PARAMETER Pass
VSPC password

.PARAMETER Credential
VSPC PowerShell Credential Object

.PARAMETER Company
Name of the new company to be created

.PARAMETER OwnerUser
Username of the owner for the new company. New Cloud Connect tenant will use this as name as well.

.PARAMETER OwnerPass
Password of the owner for the new company

.PARAMETER OwnerCredential
PowerShell Credential Object for the owner of the new company

.PARAMETER SiteName
Name of the Cloud Connect site where the tenant will be created (only required if multiple sites exist)

.PARAMETER AllowSelfSignedCerts
Flag allowing self-signed certificates (insecure)

.OUTPUTS
New-Company.ps1 returns a PowerShell Object containing all data about the created company.

.EXAMPLE
New-Company.ps1 -Server "vspc.contoso.local" -User "contoso\jsmith" -Password "password" -Company "Fabrikam" -OwnerUser "owner" -OwnerPass "password"

Description
-----------
Connect to the specified VSPC server using the username/password specified, create a new company with the specified owner credentials, and create a new Cloud Connect tenant linked to the new company.

.EXAMPLE
New-Company.ps1 -Server "vspc.contoso.local" -Credential (Get-Credential) -Company "Fabrikam" -OwnerCredential (Get-Credential)

Description
-----------
PowerShell credentials object is supported for both VSPC login and new company owner credentials.

.EXAMPLE
New-Company.ps1 -Server "vspc.contoso.local" -User "contoso\jsmith" -Company "Fabrikam" -OwnerUser "owner" -SiteName "SiteA"

Description
-----------
When multiple Cloud Connect sites exist, the SiteName parameter can be used to specify which site the new tenant will be created under.

.EXAMPLE
New-Company.ps1 -Server "vspc.contoso.local" -User "contoso\jsmith" -Company "Fabrikam" -OwnerUser "owner"

Description
-----------
When not using a credentials object, the password will be prompted for if not specified. This example will prompt for both the VSPC user password and the new company owner password.

.EXAMPLE
New-Company.ps1 -Server "vspc.contoso.local" -Port 9999 -User "contoso\jsmith" -Password "password" -Company "Fabrikam" -OwnerUser "owner" -OwnerPass "password"

Description
-----------
Connecting to a VSPC server using a non-standard API port

.EXAMPLE
New-Company.ps1 -Server "vspc.contoso.local" -User "contoso\jsmith" -Password "password"  -Company "Fabrikam" -OwnerUser "owner" -OwnerPass "password" -AllowSelfSignedCerts

Description
-----------
Connecting to a VSPC server that uses Self-Signed Certificates (insecure)

.EXAMPLE
New-Company.ps1 -Server "vspc.contoso.local" -User "contoso\jsmith" -Password "password" -Company "Fabrikam" -OwnerUser "owner" -OwnerPass "password" -Verbose

Description
-----------
Verbose output is supported for troubleshooting purposes

.NOTES
NAME:  New-Company.ps1
VERSION: 1.0
AUTHOR: Chris Arceneaux
GITHUB: https://github.com/carceneaux

.LINK
https://helpcenter.veeam.com/references/vac/9.1/rest/tag/Companies#operation/CreateCompany

.LINK
https://helpcenter.veeam.com/references/vac/9.1/rest/tag/Cloud-Connect#operation/CreateTenant

#>
#Requires -Version 6.2
[CmdletBinding(DefaultParametersetName = "UsePass")]
param(
    [Parameter(Mandatory = $true)]
	[string] $Server,
	[Parameter(Mandatory = $false)]
	[ushort] $Port = 1280,
    [Parameter(Mandatory = $true, ParameterSetName = "UsePass")]
    [string] $User,
    [Parameter(Mandatory = $false, ParameterSetName = "UsePass")]
    [string] $Pass = $true,
    [Parameter(Mandatory = $true, ParameterSetName = "UseCred")]
    [System.Management.Automation.PSCredential]$Credential,
	[Parameter(Mandatory = $true)]
	[string] $Company,
	[Parameter(Mandatory = $true, ParameterSetName = "UsePass")]
    [string] $OwnerUser,
    [Parameter(Mandatory = $false, ParameterSetName = "UsePass")]
    [string] $OwnerPass = $true,
    [Parameter(Mandatory = $true, ParameterSetName = "UseCred")]
    [System.Management.Automation.PSCredential]$OwnerCredential,
	[Parameter(Mandatory = $false)]
	[string] $SiteName = "",
	[Parameter(Mandatory = $false)]
	[Switch] $AllowSelfSignedCerts
)

Function Test-Parameter {
	param(
		[string] $ParamString,
		[string] $ParamName
	)

	if ($ParamString -match "[^A-Za-z0-9!@#$&'()\-_^.{}]") {
    	Write-Verbose "Unsupported character(s) found in '$ParamName': $($Matches[0])"
		throw "'$ParamName' contains unsupported character(s). Only alphanumeric characters and the following special characters are allowed: ! @ # $ & ' ( ) - _ ^ . { }"
	} else {
		Write-Verbose "No unsupported characters found in '$ParamName'"
		return
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

# Processing VSPC credentials
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

# Processing Company Owner credentials
if ($OwnerCredential) {
	$OwnerUser = $Credential.GetNetworkCredential().Username
	$OwnerPass = $Credential.GetNetworkCredential().Password
}
else {
	if ($OwnerPass -eq $true) {
		[securestring] $secureString = Read-Host "Enter password for '$($OwnerUser)'" -AsSecureString
		[string] $OwnerPass = [System.Net.NetworkCredential]::new("", $secureString).Password
	}
}

# Performing input validation
Test-Parameter -ParamString $Company -ParamName "Company"
Test-Parameter -ParamString $OwnerUser -ParamName "OwnerUser"

# Initializing global variables
[string] $baseUrl = "https://" + $Server + ":" + $Port
[string] $vspcApiVersion = "3.6.1"

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

### Validation Checks ###

# Retrieve Cloud Connect Sites
[string] $url = $baseUrl + "/api/v3/infrastructure/sites?limit=500"
$sites = Get-VspcApiResult -URL $url -Type "Cloud Connect Sites" -Token $token

# Determine which site to use
switch ($sites.Count) {
	0 {
		throw "No Cloud Connect Sites were found on the specified VSPC server. A Cloud Connect Site is required to create a new Cloud Connect Tenant."
	}
	1 {
		# Only one site found...using that site
		$SiteName = $sites[0].siteName
		$siteId = $sites[0].siteUid
		Write-Verbose ("Using Cloud Connect Site: '{0}'" -f $SiteName)
	}
	Default {
		# Multiple sites found...checking for specified site name
		if ($SiteName) {
			$siteId = ($sites | Where-Object { $_.siteName -eq $SiteName }).siteUid
			if ($null -eq $siteId) {
				throw ("The specified Cloud Connect Site '{0}' was not found on the VSPC server." -f $SiteName)
			}
			else {
				Write-Verbose ("Using Cloud Connect Site: '{0} ({1})'" -f $SiteName, $siteId)
			}
		}
		else {
			throw "Multiple Cloud Connect Sites were found on the specified VSPC server. Please specify the SiteName parameter to indicate which site to use."
		}
	}
}

# Retrieve Organizations (Service Provider/Reseller/Company)
[string] $url = $baseUrl + "/api/v3/organizations?limit=500"
$organizations = Get-VspcApiResult -URL $url -Type "Organizations" -Token $token

# Ensure Company does not already exist
$existing = $organizations | Where-Object { $_.name -eq $Company }
if ($null -ne $existing) {
	throw ("A Company with the name '{0}' already exists on the VSPC server. Please specify a new company name or use the 'Connect-Company.ps1' script to connect an already existing company to a Cloud Connect Tenant." -f $Company)
}
Clear-Variable -Name existing

# Retrieve Cloud Connect Tenants
[string] $url = $baseUrl + "/api/v3/infrastructure/sites/$siteId/tenants?limit=500"
$tenants = Get-VspcApiResult -URL $url -Type "Cloud Connect Tenants" -Token $token

# Ensure Tenant does not already exist
$existing = $tenants | Where-Object { $_.name -eq $OwnerUser }
if ($null -ne $existing) {
	throw ("A Cloud Connect Tenant with the name '{0}' already exists on the specified Cloud Connect Site '{1}'." -f $OwnerUser, $SiteName)
}
Clear-Variable -Name existing

### End Validation Checks ###

### Creating New Company ###

# Setting URL and Body for New Company
[string] $url = $baseUrl + "/api/v3/organizations/companies"
$body = @{
    organizationInput = @{
		name = $Company
	}
	ownerCredentials = @{
		userName = $OwnerUser
		password = $OwnerPass
	}
}
$jsonBody = $body | ConvertTo-Json -Depth 10

# Setting headers
$headers = New-Object "System.Collections.Generic.Dictionary[[string],[string]]"
$headers.Add("Authorization", "Bearer $token")
$guid = (New-Guid).Guid
$headers.Add("x-request-id", $guid)
$headers.Add("x-client-version", $vspcApiVersion)
$headers.Add("Content-Type", "application/json")

# Making API call
Write-Verbose "POST - $url"
Write-Verbose "x-request-id: $guid"
try {
	$response = Invoke-RestMethod $url -Method 'POST' -Headers $headers -Body $jsonBody -ErrorAction Stop -SkipCertificateCheck:$AllowSelfSignedCerts -StatusCodeVariable responseCode
}
catch {
	throw "An error occurred while creating the new Company." + $_
}
if (202 -eq $responseCode) {
	# retrieve async action response
	$response = Get-AsyncAction -ActionId $guid -Headers $headers
}
$newCompany = $response.data
Write-Verbose ("New Company '{0}' created successfully." -f $newCompany.name)

### End Creating New Company ###

### Creating New Cloud Connect Tenant ###

# Setting URL and Body for New Cloud Connect Tenant
[string] $url = $baseUrl + "/api/v3/infrastructure/sites/$siteId/tenants"
$body = @{
	credentials = @{
		userName = $OwnerUser
		password = $OwnerPass
	}
	assignedForCompany = $newCompany.instanceUid
}
$jsonBody = $body | ConvertTo-Json -Depth 10

# Setting headers
$headers = New-Object "System.Collections.Generic.Dictionary[[string],[string]]"
$headers.Add("Authorization", "Bearer $token")
$guid = (New-Guid).Guid
$headers.Add("x-request-id", $guid)
$headers.Add("x-client-version", $vspcApiVersion)
$headers.Add("Content-Type", "application/json")

# Making API call
Write-Verbose "POST - $url"
Write-Verbose "x-request-id: $guid"
try {
	$response = Invoke-RestMethod $url -Method 'POST' -Headers $headers -Body $jsonBody -ErrorAction Stop -SkipCertificateCheck:$AllowSelfSignedCerts -StatusCodeVariable responseCode
}
catch {
	throw "An error occurred while creating the new Cloud Connect Tenant." + $_
}
if (202 -eq $responseCode) {
	# retrieve async action response
	$response = Get-AsyncAction -ActionId $guid -Headers $headers
}
$newTenant = $response.data
Write-Verbose ("New Company '{0}' created successfully." -f $newCompany.name)

### End Creating New Cloud Connect Tenant ###

### End Script - Outputting results ###

return [PSCustomObject] @{
	# Company Information
	CompanyId         = $newCompany.instanceUid
	CompanyName       = $newCompany.name
	TenantId		  = $newTenant.instanceUid
	TenantName        = $newTenant.name
}
