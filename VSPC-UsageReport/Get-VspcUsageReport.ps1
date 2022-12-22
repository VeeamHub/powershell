<#
.SYNOPSIS
Veeam Service Provider Console (VSPC) License Usage Report

.DESCRIPTION
This script will return VSPC point in time license usage for
the current calendar month.

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
Get-VspcUsageReport returns a PowerShell Object containing all data

.EXAMPLE
Get-VspcUsageReport.ps1 -Server "vspc.contoso.local" -Username "contoso\jsmith" -Password "password"

Description
-----------
Connect to the specified VSPC server using the username/password specified

.EXAMPLE
Get-VspcUsageReport.ps1 -Server "vspc.contoso.local" -Credential (Get-Credential)

Description
-----------
PowerShell credentials object is supported

.EXAMPLE
Get-VspcUsageReport.ps1 -Server "vspc.contoso.local" -Username "contoso\jsmith" -Password "password" -Port 9999

Description
-----------
Connecting to a VSPC server using a non-standard API port

.EXAMPLE
Get-VspcUsageReport.ps1 -Server "vspc.contoso.local" -Username "contoso\jsmith" -Password "password" -AllowSelfSignedCerts

Description
-----------
Connecting to a VSPC server that uses Self-Signed Certificates (insecure)

.NOTES
NAME:  Get-VspcUsageReport.ps1
VERSION: 2.2
AUTHOR: Chris Arceneaux
TWITTER: @chris_arceneaux
GITHUB: https://github.com/carceneaux

.LINK
https://arsano.ninja/

.LINK
https://helpcenter.veeam.com/docs/vac/rest/reference/vspc-rest.html?ver=60

.LINK

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
		[securestring] $secPass = Read-Host "Enter password for '$($User)'" -AsSecureString
		[string] $Pass = ConvertFrom-SecureString -SecureString $secPass -AsPlainText
	}
}

# Initializing global variables
[string] $baseUrl = "https://" + $Server + ":" + $Port
$output = [System.Collections.ArrayList]::new()

# Logging into VSPC API
[string] $url = $baseUrl + "/api/v3/token"
Write-Verbose "POST - $url"
$headers = New-Object "System.Collections.Generic.Dictionary[[string],[string]]"
$headers.Add("Content-Type", "application/x-www-form-urlencoded")
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
[bool] $alarms = $false

# Retrieving unique alarm IDs for the following built-in VSPC Alarms...
# Alarm 17: Veeam Service Provider Console lost connection to the managed Veeam Backup & Replication server.
# Alarm 41: Veeam Service Provider Console has lost connection to the Cloud Connect server.
[string] $url = $baseUrl + "/api/v3/alarms/templates?filter=[{'operation':'or','items':[{'property':'internalId','operation':'equals','value':17},{'property':'internalId','operation':'equals','value':41}]}]"
$alarmUids = Get-VspcApiResult -URL $url -Type "Alarm IDs" -Token $token

# Retrieving active alarms for the specified ID
[string] $url = $baseUrl + "/api/v3/alarms/active?filter=[{'property':'alarmTemplateUid','operation':'equals','value':'$($alarmUids[0].instanceUid)'}]"
$alarm17 = Get-VspcApiResult -URL $url -Type "Active Alarms $($alarmUids[0].instanceUid)" -Token $token

if ($alarm17) {
	$alarms = $true
	Write-Warning "`nActive alarms are present that will cause usage report numbers to be inaccurate.`nPlease resolve these alarms and re-run this script to ensure accurate numbers.`nVeeam Service Provider Console lost connection to the following managed Veeam Backup & Replication server(s):`n$(foreach ($event in $alarm17) {"`n$($event.object.computerName) ($($event.object.instanceUid))"})"
}

# Retrieving active alarms for the specified ID
[string] $url = $baseUrl + "/api/v3/alarms/active?filter=[{'property':'alarmTemplateUid','operation':'equals','value':'$($alarmUids[1].instanceUid)'}]"
$alarm42 = Get-VspcApiResult -URL $url -Type "Active Alarms $($alarmUids[1].instanceUid)" -Token $token

if ($alarm42) {
	$alarms = $true
	Write-Warning "`nActive alarms are present that will cause usage report numbers to be inaccurate.`nPlease resolve these alarms and re-run this script to ensure accurate numbers.`nVeeam Service Provider Console has lost connection to the following Cloud Connect server(s):`n$(foreach ($event in $alarm42) {"`n$($event.object.computerName) ($($event.object.instanceUid))"})"
}
### End - Checking for active alarms

### Retrieving usage numbers

# Retrieve Companies
[string] $url = $baseUrl + "/api/v3/organizations/companies?expand=Organization&limit=500"
$companies = Get-VspcApiResult -URL $url -Type "Companies" -Token $token

# Retrieve Resellers
[string] $url = $baseUrl + "/api/v3/organizations/resellers?limit=500"
$resellers = Get-VspcApiResult -URL $url -Type "Resellers" -Token $token

# Retrieve Cloud Connect license usage
[string] $url = $baseUrl + "/api/v3/licensing/sites/usage/companies?limit=500"
$vcc = Get-VspcApiResult -URL $url -Type "Cloud Connect License Usage" -Token $token

# Retrieve Veeam Backup & Replication license usage
[string] $url = $baseUrl + "/api/v3/licensing/backupServers/usage/companies?limit=500"
$vbr = Get-VspcApiResult -URL $url -Type "Veeam Backup & Replication License Usage" -Token $token

# Retrieve Veeam Service Provider Console license usage
[string] $url = $baseUrl + "/api/v3/licensing/console/usage/companies?limit=500"
$vspc = Get-VspcApiResult -URL $url -Type "Veeam Service Provider Console License Usage" -Token $token

# Retrieve Veeam ONE license usage
[string] $url = $baseUrl + "/api/v3/licensing/voneServers/usage/companies?limit=500"
$one = Get-VspcApiResult -URL $url -Type "Veeam ONE License Usage" -Token $token

# Retrieve Veeam Backup for Microsoft 365 license usage
[string] $url = $baseUrl + "/api/v3/licensing/vbm365Servers/usage/companies?limit=500"
$vb365 = Get-VspcApiResult -URL $url -Type "Veeam Backup for Microsoft 365 License Usage" -Token $token

### End - Retrieving usage numbers

### Calculating per-Company usage

# Get Company License Usage
foreach ($company in $companies) {
	Write-Verbose "Retrieving usage for $($company.Name) ($($company.instanceUid))"

	# Filtering usage to the specified Company Id
	$vccUsage = $vcc | Where-Object { $_.companyUid -eq $company.instanceUid }
	$vbrUsage = $vbr | Where-Object { $_.companyUid -eq $company.instanceUid }
	$vspcUsage = $vspc | Where-Object { $_.companyUid -eq $company.instanceUid }
	$oneUsage = $one | Where-Object { $_.companyUid -eq $company.instanceUid }
	$vb365Usage = $vb365 | Where-Object { $_.companyUid -eq $company.instanceUid }

	# All usage, if it exists, is located in the "counters" property
	if ($vccUsage.PSobject.Properties.name -match "counters") { $vccUsage = $vccUsage.counters }
	if ($vbrUsage.PSobject.Properties.name -match "counters") { $vbrUsage = $vbrUsage.counters }
	if ($vspcUsage.PSobject.Properties.name -match "counters") { $vspcUsage = $vspcUsage.counters }
	if ($oneUsage.PSobject.Properties.name -match "counters") { $oneUsage = $oneUsage.counters }
	if ($vb365Usage.PSobject.Properties.name -match "counters") { $vb365Usage = $vb365Usage.counters }

	# Parsing VCC license usage numbers
	$vccSrvBackup = $vccUsage | Where-Object { $_.type -eq "CC_Server_Backup" }
	$vccWsBackup = $vccUsage | Where-Object { $_.type -eq "CC_Workstation_Backup" }
	$vccVmBackup = $vccUsage | Where-Object { $_.type -eq "CC_VM_Backup" }
	$vccVmReplica = $vccUsage | Where-Object { $_.type -eq "CC_VM_Replica" }

	# Parsing VBR server rental license usage numbers
	$vbrVsphereVm = $vbrUsage | Where-Object { $_.type -eq "VBR_vSphere_VM" }
	$vbrHyperVVm = $vbrUsage | Where-Object { $_.type -eq "VBR_HyperV_VM" }
	$vbrAhvVm = $vbrUsage | Where-Object { $_.type -eq "VBR_AHV_VM" }
	$vbrNasBackup = $vbrUsage | Where-Object { $_.type -eq "VBR_NAS_Backup" }
	$vbrCloudVm = $vbrUsage | Where-Object { $_.type -eq "VBR_Cloud_VM" }
	$vbrApplicationPlugins = $vbrUsage | Where-Object { $_.type -eq "VBR_Application_Plugins" }
	$vbrServerAgent = $vbrUsage | Where-Object { $_.type -eq "VBR_Server_Agent" }
	$vbrWorkstationAgent = $vbrUsage | Where-Object { $_.type -eq "VBR_Workstation_Agent" }
	$vbrRhvVm = $vbrUsage | Where-Object { $_.type -eq "VBR_RHV_VM" }

	# Parsing VSPC managed agents license usage numbers
	$vspcServerAgent = $vspcUsage | Where-Object { $_.type -eq "VAC_Server_Agent" }
	$vspcWorkstationAgent = $vspcUsage | Where-Object { $_.type -eq "VAC_Workstation_Agent" }

	# Parsing ONE license usage numbers
	$oneFileShare = $oneUsage | Where-Object { $_.type -eq "FileShare" }
	$oneVm = $oneUsage | Where-Object { $_.type -eq "VM" }
	$oneCloudVm = $oneUsage | Where-Object { $_.type -eq "CloudVM" }
	$oneServerAgent = $oneUsage | Where-Object { $_.type -eq "ServerAgent" }
	$oneWorkstationAgent = $oneUsage | Where-Object { $_.type -eq "WorkstationAgent" }

	# Parsing VB365 license usage numbers
	$vb365User = $vb365Usage | Where-Object { $_.type -eq "User" }

	# Is the Company managed by a Reseller?
	[string] $resellerName = ''
	[bool] $isResellerManaged = $false
	if ($null -ne $company.resellerUid) {
		$isResellerManaged = $true
		[string] $resellerName = ($resellers | Where-Object { $_.instanceUid -eq $company.resellerUid }).name
	}

	$object = [PSCustomObject] @{
		# Company Information
		CompanyName                     = $company.name
		CompanyId                       = $company.instanceUid
		IsResellerManaged               = $isResellerManaged
		ResellerName                    = $resellerName
		ResellerId                      = $company.resellerUid
		# Veeam Cloud Connect Backup - VM
		CC_VmBackupRentalCount          = Confirm-Value -Value $vccVmBackup.rentalCount
		CC_VmBackupNewCount             = Confirm-Value -Value $vccVmBackup.newCount
		CC_VmBackupUsedCount            = Confirm-Value -Value $vccVmBackup.usedCount
		# Veeam Cloud Connect Backup - Server
		CC_SrvBackupRentalCount         = Confirm-Value -Value $vccSrvBackup.rentalCount
		CC_SrvBackupNewCount            = Confirm-Value -Value $vccSrvBackup.newCount
		CC_SrvBackupUsedCount           = Confirm-Value -Value $vccSrvBackup.usedCount
		# Veeam Cloud Connect Backup - Workstation
		CC_WsBackupRentalCount          = Confirm-Value -Value $vccWsBackup.rentalCount
		CC_WsBackupNewCount             = Confirm-Value -Value $vccWsBackup.newCount
		CC_WsBackupUsedCount            = Confirm-Value -Value $vccWsBackup.usedCount
		# Veeam Cloud Connect Replication - VM
		CC_VmReplicaRentalCount         = Confirm-Value -Value $vccVmReplica.rentalCount
		CC_VmReplicaNewCount            = Confirm-Value -Value $vccVmReplica.newCount
		CC_VmReplicaUsedCount           = Confirm-Value -Value $vccVmReplica.usedCount
		# Veeam Backup & Replication - vSphere VM
		VBR_VsphereVmNewCount           = Confirm-Value -Value $vbrVsphereVm.newCount
		VBR_VsphereVmUsedCount          = Confirm-Value -Value $vbrVsphereVm.usedCount
		# Veeam Backup & Replication - HyperV VM
		VBR_HyperVVmNewCount            = Confirm-Value -Value $vbrHyperVVm.newCount
		VBR_HyperVVmUsedCount           = Confirm-Value -Value $vbrHyperVVm.usedCount
		# Veeam Backup & Replication - AHV VM
		VBR_AhvVmNewCount               = Confirm-Value -Value $vbrAhvVm.newCount
		VBR_AhvVmUsedCount              = Confirm-Value -Value $vbrAhvVm.usedCount
		# Veeam Backup & Replication - NAS Backup
		VBR_NasBackupNewCount           = Confirm-Value -Value $vbrNasBackup.newCount
		VBR_NasBackupUsedCount          = Confirm-Value -Value $vbrNasBackup.usedCount
		# Veeam Backup & Replication - Public Cloud VM
		VBR_CloudVmNewCount             = Confirm-Value -Value $vbrCloudVm.newCount
		VBR_CloudVmUsedCount            = Confirm-Value -Value $vbrCloudVm.usedCount
		# Veeam Backup & Replication - Application Plugins
		VBR_ApplicationPluginsNewCount  = Confirm-Value -Value $vbrApplicationPlugins.newCount
		VBR_ApplicationPluginsUsedCount = Confirm-Value -Value $vbrApplicationPlugins.usedCount
		# Veeam Backup & Replication - Veeam Agent - Server
		VBR_SrvAgentNewCount            = Confirm-Value -Value $vbrServerAgent.newCount
		VBR_SrvAgentUsedCount           = Confirm-Value -Value $vbrServerAgent.usedCount
		# Veeam Backup & Replication - Veeam Agent - Workstation
		VBR_WsAgentNewCount             = Confirm-Value -Value $vbrWorkstationAgent.newCount
		VBR_WsAgentUsedCount            = Confirm-Value -Value $vbrWorkstationAgent.usedCount
		# Veeam Backup & Replication - RHV VM
		VBR_RhvVmNewCount               = Confirm-Value -Value $vbrRhvVm.newCount
		VBR_RhvVmUsedCount              = Confirm-Value -Value $vbrRhvVm.usedCount
		# Veeam Service Provider Console - Veeam Agent - Server
		VSPC_SrvAgentNewCount           = Confirm-Value -Value $vspcServerAgent.newCount
		VSPC_SrvAgentUsedCount          = Confirm-Value -Value $vspcServerAgent.usedCount
		# Veeam Service Provider Console - Veeam Agent - Workstation
		VSPC_WsAgentNewCount            = Confirm-Value -Value $vspcWorkstationAgent.newCount
		VSPC_WsAgentUsedCount           = Confirm-Value -Value $vspcWorkstationAgent.usedCount
		# Veeam ONE - File Share
		ONE_FileShareNewCount           = Confirm-Value -Value $oneFileShare.newCount
		ONE_FileShareUsedCount          = Confirm-Value -Value $oneFileShare.usedCount
		# Veeam ONE - VM
		ONE_VmNewCount                  = Confirm-Value -Value $oneVm.newCount
		ONE_VmUsedCount                 = Confirm-Value -Value $oneVm.usedCount
		# Veeam ONE - Public Cloud VM
		ONE_CloudVmNewCount             = Confirm-Value -Value $oneCloudVm.newCount
		ONE_CloudVmUsedCount            = Confirm-Value -Value $oneCloudVm.usedCount
		# Veeam ONE - Veeam Agent - Server
		ONE_SrvAgentNewCount            = Confirm-Value -Value $oneServerAgent.newCount
		ONE_SrvAgentUsedCount           = Confirm-Value -Value $oneServerAgent.usedCount
		# Veeam ONE - Veeam Agent - Workstation
		ONE_WsAgentNewCount             = Confirm-Value -Value $oneWorkstationAgent.newCount
		ONE_WsAgentUsedCount            = Confirm-Value -Value $oneWorkstationAgent.usedCount
		# Veeam Backup for Microsoft 365 - User
		VB365_UserNewCount              = Confirm-Value -Value $vb365User.newCount
		VB365_UserUsedCount             = Confirm-Value -Value $vb365User.usedCount
	}
	[ref] $null = $output.Add($object)
	Clear-Variable -Name object
}
### End - Calculating per-Company usage

return $output
