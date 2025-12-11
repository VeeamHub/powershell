<#
.SYNOPSIS
Veeam Service Provider Console (VSPC) Link Existing Company to Cloud Connect Tenant

.DESCRIPTION
This script will link an existing company to a new/existing Cloud Connect tenant. If the tenant is already mapped to another company, the script will error out. Please note that this script only asks for required parameters to link an existing company. Additional parameters can be added to the body of the POST request in order to customize the tenant settings. See VSPC REST API documentation link below for more details.

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
Name of the company to be linked to the Cloud Connect tenant.

.PARAMETER OwnerUser
Username of the owner for the Cloud Connect tenant. This is also the name of the tenant.

.PARAMETER OwnerPass
Password of the owner for the new company

.PARAMETER OwnerCredential
PowerShell Credential Object for the owner of the new company

.PARAMETER SiteName
Name of the Cloud Connect site where the tenant exists or will be created (only required if multiple sites exist)

.PARAMETER NewTenant
Flag indicating whether to create a new Cloud Connect tenant. If present, OwnerPass is required.

.PARAMETER AllowSelfSignedCerts
Flag allowing self-signed certificates (insecure)

.OUTPUTS
Connect-Company.ps1 returns a PowerShell Object containing all data about the mapped Cloud Connect Tenant.

.EXAMPLE
Connect-Company.ps1 -Server "vspc.contoso.local" -User "contoso\jsmith" -Password "password" -Company "Fabrikam" -OwnerUser "Fabrikam"

Description
-----------
Connect to the specified VSPC server using the username/password specified and map the company (Fabrikam) to an existing Cloud Connect tenant (fabrikam).

.EXAMPLE
Connect-Company.ps1 -Server "vspc.contoso.local" -User "contoso\jsmith" -Password "password" -Company "Fabrikam" -OwnerUser "Fabrikam" -OwnerPass "password" -NewTenant

Description
-----------
Connect to the specified VSPC server using the username/password specified and create a new Cloud Connect tenant (fabrikam) mapped to the company (Fabrikam).

.EXAMPLE
Connect-Company.ps1 -Server "vspc.contoso.local" -Credential (Get-Credential) -Company "Fabrikam" -OwnerCredential (Get-Credential) -NewTenant

Description
-----------
PowerShell credentials object is supported for both VSPC login and the new Cloud Connect tenant.

.EXAMPLE
Connect-Company.ps1 -Server "vspc.contoso.local" -User "contoso\jsmith" -Company "Fabrikam" -OwnerUser "Fabrikam" -SiteName "SiteA"

Description
-----------
When multiple Cloud Connect sites exist, the SiteName parameter must be used to specify which Cloud Connect site will be used for the tenant.

.EXAMPLE
Connect-Company.ps1 -Server "vspc.contoso.local" -User "contoso\jsmith" -Company "Fabrikam" -OwnerUser "Fabrikam" -NewTenant

Description
-----------
When not using a credentials object, the password will be prompted for if not specified. This example will prompt for both the VSPC user password and the new company owner password.

.EXAMPLE
Connect-Company.ps1 -Server "vspc.contoso.local" -Port 9999 -User "contoso\jsmith" -Password "password" -Company "Fabrikam" -OwnerUser "Fabrikam"

Description
-----------
Connecting to a VSPC server using a non-standard API port

.EXAMPLE
Connect-Company.ps1 -Server "vspc.contoso.local" -Port 9999 -User "contoso\jsmith" -Password "password" -Company "Fabrikam" -OwnerUser "Fabrikam" -AllowSelfSignedCerts

Description
-----------
Connecting to a VSPC server that uses Self-Signed Certificates (insecure)

.EXAMPLE
Connect-Company.ps1 -Server "vspc.contoso.local" -Port 9999 -User "contoso\jsmith" -Password "password" -Company "Fabrikam" -OwnerUser "Fabrikam" -Verbose

Description
-----------
Verbose output is supported for troubleshooting purposes

.NOTES
NAME:  Connect-Company.ps1
VERSION: 1.0
AUTHOR: Chris Arceneaux
GITHUB: https://github.com/carceneaux

.LINK
https://helpcenter.veeam.com/references/vac/9.1/rest/tag/Cloud-Connect#operation/CreateTenant

.LINK
https://helpcenter.veeam.com/references/vac/9.1/rest/tag/Cloud-Connect#operation/PatchTenant

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
	[Parameter(Mandatory = $false)]
	[string] $OwnerUser,
	[Parameter(Mandatory = $false)]
	[string] $OwnerPass = $true,
	[Parameter(Mandatory = $false)]
	[System.Management.Automation.PSCredential]$OwnerCredential,
	[Parameter(Mandatory = $false)]
	[string] $SiteName = "",
	[Parameter(Mandatory = $false)]
	[Switch] $NewTenant,
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
	}
 else {
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
elseif ($Pass -eq $true) {
	[securestring] $secureString = Read-Host "Enter password for '$($User)'" -AsSecureString
	[string] $Pass = [System.Net.NetworkCredential]::new("", $secureString).Password
}

# Processing Company Owner credentials
if ($OwnerCredential) {
	$OwnerUser = $Credential.GetNetworkCredential().Username
	$OwnerPass = $Credential.GetNetworkCredential().Password
}
elseif ($NewTenant -and ($OwnerPass -eq $true)) {
	[securestring] $secureString = Read-Host "Enter password for '$($OwnerUser)'" -AsSecureString
	[string] $OwnerPass = [System.Net.NetworkCredential]::new("", $secureString).Password
	if ($OwnerPass -eq "") { throw "OwnerPass cannot be empty when creating a new tenant." }
}
else {
	Write-Verbose "All required parameters are present."
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
if ($null -eq $existing) {
	throw ("A Company with the name '{0}' was not found on the VSPC server. Please specify a new company name or use the 'New-Company.ps1' script to create a new Company." -f $Company)
}
else {
	Write-Verbose ("Existing Company named '{0}' found." -f $Company)
	$companyId = $existing.instanceUid
}
Clear-Variable -Name existing

# Retrieve Cloud Connect Tenants
[string] $url = $baseUrl + "/api/v3/infrastructure/sites/$siteId/tenants?limit=500"
$tenants = Get-VspcApiResult -URL $url -Type "Cloud Connect Tenants" -Token $token

# Does the Cloud Connect Tenant already exist?
$existing = $tenants | Where-Object { $_.name -eq $OwnerUser }
if (($null -eq $existing) -and (-not $NewTenant)) {
	throw ("A Cloud Connect Tenant with the name '{0}' was not found on the specified Cloud Connect Site '{1}'. Please enter a name of an existing tenant or use the -NewTenant flag to create a new tenant." -f $OwnerUser, $SiteName)
}
elseif (($null -ne $existing) -and $NewTenant) {
	throw ("A Cloud Connect Tenant with the name '{0}' already exists on the specified Cloud Connect Site '{1}'. Please specify a different tenant name or remove the -NewTenant flag." -f $OwnerUser, $SiteName)
}
elseif (($null -eq $existing) -and $NewTenant) {
	Write-Verbose ("No existing Cloud Connect Tenant named '{0}' found. A new tenant will be created." -f $OwnerUser)
}
elseif ($companyId -eq $existing.assignedForCompany) {
	Write-Warning ("The company '{0}' is already mapped to the specified Cloud Connect tenant '{1}'." -f $Company, $OwnerUser)
	Exit 0
}
elseif ($null -ne $existing.assignedForCompany) {
	throw ("A company is already mapped to the specified Cloud Connect tenant '{0}'. Please specify a different tenant." -f $OwnerUser)
}
else {
	Write-Verbose ("Existing Cloud Connect Tenant named '{0}' found." -f $OwnerUser)
	$tenantId = $existing.instanceUid
}
Clear-Variable -Name existing

### End Validation Checks ###

### Creating New Cloud Connect Tenant ###

if ($NewTenant) {
	# Setting URL and Body for New Cloud Connect Tenant
	[string] $url = $baseUrl + "/api/v3/infrastructure/sites/$siteId/tenants"
	$body = @{
		credentials        = @{
			userName = $OwnerUser
			password = $OwnerPass
		}
		assignedForCompany = $companyId
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
	Write-Verbose ("Body: {0}" -f $jsonBody)
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
	$tenant = $response.data
	Write-Verbose ("New Cloud Connect tenant '{0}' created successfully." -f $tenant.name)
}

### End Creating New Cloud Connect Tenant ###

### Map Existing Cloud Connect Tenant ###

if (-not $NewTenant) {
	# Setting URL and Body for New Cloud Connect Tenant
	[string] $url = $baseUrl + "/api/v3/infrastructure/sites/tenants/$tenantId"
	$body = @(@{
		value = $companyId
		path  = "/assignedForCompany"
		op    = "replace"
	})
	$jsonBody = ConvertTo-Json -InputObject $body -Depth 10
	# Setting headers
	$headers = New-Object "System.Collections.Generic.Dictionary[[string],[string]]"
	$headers.Add("Authorization", "Bearer $token")
	$guid = (New-Guid).Guid
	$headers.Add("x-request-id", $guid)
	$headers.Add("x-client-version", $vspcApiVersion)
	$headers.Add("Content-Type", "application/json")

	# Making API call
	Write-Verbose "PATCH - $url"
	Write-Verbose "x-request-id: $guid"
	Write-Verbose ("Body: {0}" -f $jsonBody)
	try {
		$response = Invoke-RestMethod $url -Method 'PATCH' -Headers $headers -Body $jsonBody -ErrorAction Stop -SkipCertificateCheck:$AllowSelfSignedCerts -StatusCodeVariable responseCode
	}
	catch {
		throw "An error occurred while mapping the Cloud Connect Tenant." + $_
	}
	if (202 -eq $responseCode) {
		# retrieve async action response
		$response = Get-AsyncAction -ActionId $guid -Headers $headers
	}
	$tenant = $response.data
	Write-Verbose ("Tenant '{0}' mapped successfully to Company '{1}'." -f $tenant.name, $Company)
}

### End Map Existing Cloud Connect Tenant ###

### End Script - Outputting results ###

return [PSCustomObject] @{
	# Company Information
	CompanyId   = $companyId
	CompanyName = $Company
	TenantId    = $tenant.instanceUid
	TenantName  = $tenant.name
}
