<#
.SYNOPSIS
Veeam Service Provider Console (VSPC) Retrieve CSV License Usage Report

.DESCRIPTION
This script will retrieve the most recent monthly license usage report for the service provider from VSPC in the CSV format. If the IncludeResellers flag is present, a CSV report will also be downloaded for each reseller.

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

.PARAMETER IncludeResellers
Flag indicating whether to include reseller license usage reports (if applicable)

.PARAMETER AllowSelfSignedCerts
Flag allowing self-signed certificates (insecure)

.OUTPUTS
Get-CsvLicenseUsageReport.ps1 returns a PowerShell Object containing metadata about the downloaded CSV report(s)

.EXAMPLE
Get-CsvLicenseUsageReport.ps1 -Server "vspc.contoso.local" -Username "contoso\jsmith" -Password "password"

Description
-----------
Connect to the specified VSPC server using the username/password specified

.EXAMPLE
Get-CsvLicenseUsageReport.ps1 -Server "vspc.contoso.local" -Username "contoso\jsmith" -Password "password" -IncludeResellers

Description
-----------
Connect to the specified VSPC server and download license usage reports for the service provider and all resellers

.EXAMPLE
Get-CsvLicenseUsageReport.ps1 -Server "vspc.contoso.local" -Credential (Get-Credential)

Description
-----------
PowerShell credentials object is supported

.EXAMPLE
Get-CsvLicenseUsageReport.ps1 -Server "vspc.contoso.local" -Username "contoso\jsmith"

Description
-----------
When not using a credentials object, the password will be prompted for if not specified.

.EXAMPLE
Get-CsvLicenseUsageReport.ps1 -Server "vspc.contoso.local" -Port 9999 -Username "contoso\jsmith" -Password "password"

Description
-----------
Connecting to a VSPC server using a non-standard API port

.EXAMPLE
Get-CsvLicenseUsageReport.ps1 -Server "vspc.contoso.local" -Username "contoso\jsmith" -Password "password" -AllowSelfSignedCerts

Description
-----------
Connecting to a VSPC server that uses Self-Signed Certificates (insecure)

.EXAMPLE
Get-CsvLicenseUsageReport.ps1 -Server "vspc.contoso.local" -Username "contoso\jsmith" -Password "password" -Verbose

Description
-----------
Verbose output is supported

.NOTES
NAME:  Get-CsvLicenseUsageReport.ps1
VERSION: 1.0
AUTHOR: Chris Arceneaux
GITHUB: https://github.com/carceneaux

.LINK
https://helpcenter.veeam.com/docs/vac/rest/reference/vspc-rest.html?ver=9#tag/Licensing/operation/DownloadLicensingReportCsv

.LINK
https://helpcenter.veeam.com/docs/vac/provider_admin/view_license_usage_report.html?ver=9

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
	[Parameter(Mandatory = $false)]
	[Switch] $IncludeResellers,
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

Function Save-CsvReport {
	param(
		[string] $URL,
		[string] $FilePath,
		[string] $Token
	)

	try {
		# Setting headers
		$headers = New-Object "System.Collections.Generic.Dictionary[[string],[string]]"
		$headers.Add("Authorization", "Bearer $Token")
		$headers.Add("x-client-version", $vspcApiVersion)  # API versioning using for backwards compatibility
		$headers.Add("accept", "application/octet-stream")

		# Making API call to download CSV report
		Write-Verbose "GET - $URL"
		$response = Invoke-WebRequest -Uri $URL -Method 'GET' -Headers $headers -ErrorAction Stop -SkipCertificateCheck:$AllowSelfSignedCerts -OutFile $FilePath

		return $response
	}
	catch {
		Write-Error "ERROR: CSV Report Download Failed! $($_.Exception.Message)"
		throw
	}
}

Function New-FileName {
	param(
		[string] $BaseName,
		[string] $OrgName,
		[datetime] $Date,
		[string] $Extension
	)

	# Remove invalid filename characters from organization name
	$OrgName = $OrgName -replace '[\\/:*?"<>|]', ''

	# Replace spaces from organization name with hyphens
	$OrgName = $OrgName -replace ' ', '-'

	# Format date into string to be used in filename
	[string] $date = $Date.ToString("MMddyyyy-HHmmss")

	# Generating file name
	[string] $fileName = "{0}-{1}-{2}.{3}" -f $BaseName, $OrgName, $date, $Extension

	return $fileName
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
[string] $vspcApiVersion = "3.6"
$output = [System.Collections.ArrayList]::new()

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

# Retrieve Organizations (excluding Companies)
[string] $url = $baseUrl + "/api/v3/organizations?filter=[{'property':'type','operation':'notEquals','collation':'ignorecase','value':'Company'}]&limit=500"
$organizations = Get-VspcApiResult -URL $url -Type "Organizations" -Token $token

# Retrieve ID of latest license usage report (service provider & resellers)
[string] $url = $baseUrl + "/api/v3/licensing/reports/latest"
$reports = Get-VspcApiResult -URL $url -Type "License Usage Reports" -Token $token

### Download CSV License Usage Report(s) ###

# Loop through each report
foreach ($report in $reports) {
	# Chec
	$org = $organizations | Where-Object { $_.instanceUid -eq $report.reportParameters.organizationUid }
	Write-Verbose ("Processing Report for '{0}' ({1})" -f $report.reportParameters.organizationName, $org.type)

	if ($org.type -eq "Reseller") {
		if ($IncludeResellers) {
			[string] $fileName = New-FileName -BaseName "LicenseUsageReport-Reseller" -OrgName $report.reportParameters.organizationName -Date $report.reportParameters.generationDate -Extension "csv"
		}
		else {
			Write-Verbose ("Skipping Reseller Report for '{0}'" -f $report.reportParameters.organizationName)
			continue
		}
	}
	else { # Service Provider
		[string] $fileName = New-FileName -BaseName "LicenseUsageReport-Provider" -OrgName $report.reportParameters.organizationName -Date $report.reportParameters.generationDate -Extension "csv"
	}


	[string] $filePath = Join-Path -Path $PSScriptRoot -ChildPath $fileName # File path of downloaded CSV report
	Write-Verbose ("Downloading CSV License Usage Report for '{0}' to '{1}'" -f $report.reportParameters.organizationName, $filePath)

	# Downloading CSV report
	[string] $url = "{0}/api/v3/licensing/reports/{1}/csv" -f $baseUrl, $report.reportParameters.reportId
	$response = Save-CsvReport -URL $url -FilePath $filePath -Token $token

	# Generating output object
	$object = [PSCustomObject] @{
		Name          = $report.reportParameters.organizationName
		Type          = $org.type
		OrgId         = $report.reportParameters.organizationUid
		ReportPath    = $filePath
	}
	[ref] $null = $output.Add($object)
	Clear-Variable -Name org, object
}

### End Script - Outputting CSV report file path(s) ###

return $output
