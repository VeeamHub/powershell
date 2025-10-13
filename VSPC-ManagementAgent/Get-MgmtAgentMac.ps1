<#
.SYNOPSIS
Veeam Service Provider Console (VSPC) Download Management Agent for macOS

.DESCRIPTION
This script will download a management agent from VSPC for the specified organization. The management agent can only be installed on a machine running the macOS operating system. Please note that CloudTenantId is not required if the organization is the service provider.

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

.PARAMETER PackageType
Setup file extension type (zip/sh). Default is sh.

.PARAMETER AllowSelfSignedCerts
Flag allowing self-signed certificates (insecure)

.OUTPUTS
Get-MgmtAgentMac.ps1 downloads a VSPC management agent for the macOS operating system to the current folder and then returns a string containing the file path of the downloaded agent.

.EXAMPLE
Get-MgmtAgentMac.ps1 -Server "vspc.contoso.local" -OrgId "78a906f5-1005-4ced-9db4-9b147d36efb6" -LocationId "f0b8ef9f-bfe7-4e95-84e6-5f8f7b5a5bc6" -CloudTenantId "53047af7-9ddf-4faf-b8db-286bb3454408" -Username "contoso\jsmith" -Password "password"

Description
-----------
Connect to the specified VSPC server using the API key specified and download a management agent for the specified organization, location, and Cloud Connect tenant.

.EXAMPLE
Get-MgmtAgentMac.ps1 -Server "vspc.contoso.local" -OrgId "78a906f5-1005-4ced-9db4-9b147d36efb6" -LocationId "f0b8ef9f-bfe7-4e95-84e6-5f8f7b5a5bc6" -CloudTenantId "53047af7-9ddf-4faf-b8db-286bb3454408" -Credential (Get-Credential)

Description
-----------
PowerShell credentials object is supported

.EXAMPLE
Get-MgmtAgentMac.ps1 -Server "vspc.contoso.local" -OrgId "78a906f5-1005-4ced-9db4-9b147d36efb6" -LocationId "f0b8ef9f-bfe7-4e95-84e6-5f8f7b5a5bc6" -CloudTenantId "53047af7-9ddf-4faf-b8db-286bb3454408" -Username "contoso\jsmith"

Description
-----------
When not using a credentials object, the password will be prompted for if not specified.

.EXAMPLE
Get-MgmtAgentMac.ps1 -Server "vspc.contoso.local" -Port 9999 -OrgId "78a906f5-1005-4ced-9db4-9b147d36efb6" -LocationId "f0b8ef9f-bfe7-4e95-84e6-5f8f7b5a5bc6" -CloudTenantId "53047af7-9ddf-4faf-b8db-286bb3454408" -Username "contoso\jsmith" -Password "password"

Description
-----------
Connecting to a VSPC server using a non-standard API port

.EXAMPLE
Get-MgmtAgentMac.ps1 -Server "vspc.contoso.local" -OrgId "78a906f5-1005-4ced-9db4-9b147d36efb6" -LocationId "f0b8ef9f-bfe7-4e95-84e6-5f8f7b5a5bc6" -CloudTenantId "53047af7-9ddf-4faf-b8db-286bb3454408" -Username "contoso\jsmith" -Password "password" -AllowSelfSignedCerts

Description
-----------
Connecting to a VSPC server that uses Self-Signed Certificates (insecure)

.NOTES
NAME:  Get-MgmtAgentMac.ps1
VERSION: 1.0
AUTHOR: Chris Arceneaux
GITHUB: https://github.com/carceneaux

.LINK
https://helpcenter.veeam.com/docs/vac/rest/reference/vspc-rest.html?ver=9

.LINK
https://helpcenter.veeam.com/rn/vspc_9_release_notes.html#system-requirements-veeam-management-agents-macos

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
	[guid]$OrgId,
	[Parameter(Mandatory = $true)]
	[guid]$LocationId,
	[Parameter(Mandatory = $false)]
	[guid]$CloudTenantId,
	[Parameter(Mandatory = $false)]
	[ushort]$ExpirationDays = 365,
	[Parameter(Mandatory = $false)]
	[ValidateSet("zip", "sh")]
	[string]$PackageType = "zip",
	[Parameter(Mandatory = $false)]
	[Switch] $AllowSelfSignedCerts
)

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
[string] $vspcApiVersion = "3.6"
$filePath = Join-Path -Path $PSScriptRoot -ChildPath ("\VeeamManagementAgentMac_" + $OrgId + "." + $PackageType) # File path of downloaded agent

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
	Write-Error "ERROR: Authorization Failed! Make sure the valid server, port, and credentials were specified."
	throw
}

### Download Management Agent ###

# GET - /api/v3/infrastructure/managementAgents/packages/mac
Write-Verbose "Downloading Management Agent for macOS..."
[string] $url = $baseUrl + "/api/v3/infrastructure/managementAgents/packages/mac?organizationUid=$OrgId&locationUid=$LocationId&cloudTenantUid=$CloudTenantId&tokenExpiryPeriodDays=$ExpirationDays&packageType=$PackageType"

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
