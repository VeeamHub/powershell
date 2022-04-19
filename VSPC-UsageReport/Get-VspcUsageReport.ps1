<#
.SYNOPSIS
Veeam Service Provider Console (VSPC) License Usage Report

.DESCRIPTION
This script will return VSPC point in time license usag for
the current calendar month.
	
.PARAMETER Server
VSPC Server IP or FQDN

.PARAMETER UserName
VSPC Portal Administrator account username

.PARAMETER Password
VSPC Portal Administrator account password

.PARAMETER Credential
VSPC Portal Administrator account PS Credential Object

.PARAMETER Port
VSPC Rest API port

.PARAMETER AllowSelfSignedCerts
Flag allowing self-signed certificates (insecure)

.PARAMETER Detailed
Flag to include a list of all metrics gathered

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
Get-VspcUsageReport.ps1 -Server "vspc.contoso.local" -Credential $cred_vac -Detailed

Description 
-----------     
Includes a detailed list of all metrics (and then some) used to generate the monthly usage report

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
VERSION: 2.1
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
	[String] $Server,
	[Parameter(Mandatory = $true, ParameterSetName = "UsePass")]
	[String] $Username,
	[Parameter(Mandatory = $false, ParameterSetName = "UsePass")]
	[String] $Password = $true,
	[Parameter(Mandatory = $true, ParameterSetName = "UseCred")]
	[System.Management.Automation.PSCredential]$Credential,
	[Parameter(Mandatory = $false)]
	[Int] $Port = 1280,
	[Parameter(Mandatory = $false)]
	[Switch] $AllowSelfSignedCerts,
	[Parameter(Mandatory = $false)]
	[Switch] $Detailed
)

Function Get-AsyncAction {
	param([String] $asyncUrl)

	$asyncUrl -match "([^\/]+$)"
	$actionId = $Matches[0]

	# GET - /api/v3/asyncActions/{actionId} - Retrieve Async Action
	[String] $url = "https://" + $Server + ":" + $Port + "/api/v3/asyncActions/" + $actionId
	Write-Verbose "GET - $url"
	$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
	$headers.Add("Authorization", "Bearer $token")
	try {
		:loop while ($true)
		{
			$response = Invoke-RestMethod $url -Method 'GET' -Headers $headers -ErrorAction Stop -SkipCertificateCheck:$AllowSelfSignedCerts
			switch ($response.data.status) {
				"running"
				{
					Start-Sleep -Seconds 10
					break
				}
				"succeed"
				{
					break loop
				}
				"canceled"
				{
					throw "Async Action ID (" + $actionId + ") was cancelled."
				}
				"failed"
				{
					throw "Async Action ID (" + $actionId + ") failed with the following error message(s): " + $response.errors.message
				}
				Default	{throw "An unknown response was detected."}
			}
		}
	}
	catch {
		throw
	}
	# End Retrieve Async Action
}

# Function Get-VbrServerUsage {
# 	param([String] $tenantId)

# 	# GET - /v2/tenants/{id}/backupServers
# 	[String] $url = "https://" + $Server + ":" + $Port + "/v2/tenants/$tenantId/backupServers"
# 	Write-Verbose "VBR Server Usage Url: $url"
# 	$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
# 	$headers.Add("Authorization", "Bearer $token")
# 	try {
# 		$response = Invoke-RestMethod $url -Method 'GET' -Headers $headers -ErrorAction Stop
# 		return $response
# 	}
#  catch {
# 		Write-Error "`nERROR: Retrieving VBR Server Usage for Tenant ID $tenantId Failed!"
# 		Exit 1
# 	}
# 	# End VBR Server Usage

# }

# Function Get-VbrAgentUsage {
# 	param([String] $tenantId)

# 	# GET - /v2/tenants/{tenantId}/licensing/backupServerUsage
# 	[String] $url = "https://" + $Server + ":" + $Port + "/v2/tenants/$tenantId/licensing/backupServerUsage"
# 	Write-Verbose "VBR Agent Usage Url: $url"
# 	$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
# 	$headers.Add("Authorization", "Bearer $token")
# 	try {
# 		$response = Invoke-RestMethod $url -Method 'GET' -Headers $headers -ErrorAction Stop
# 		return $response
# 	}
#  catch {
# 		Write-Error "`nERROR: Retrieving VBR Agent Usage for Tenant ID $tenantId Failed!"
# 		Exit 1
# 	}
# 	# End VBR Agent Usage

# }

# Function Get-ServerAgentUsage {
# 	param([String] $tenantId)

# 	# GET - /v2/tenants/{tenantId}/licensing/availabilityConsoleUsage
# 	[String] $url = "https://" + $Server + ":" + $Port + "/v2/tenants/$tenantId/licensing/availabilityConsoleUsage"
# 	Write-Verbose "VSPC Agent Usage Url: $url"
# 	$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
# 	$headers.Add("Authorization", "Bearer $token")
# 	try {
# 		$response = Invoke-RestMethod $url -Method 'GET' -Headers $headers -ErrorAction Stop
# 		return $response
# 	}
#  catch {
# 		Write-Error "`nERROR: Retrieving VSPC Agent Usage for Tenant ID $tenantId Failed!"
# 		Exit 1
# 	}
# 	# End VSPC Agent Usage

# }

# Function Get-ServerAlarmEvents {
# 	param([String] $alarmId)

# 	# GET - /v2/notifications/alarmTemplates/{id}/events
# 	[String] $url = "https://" + $Server + ":" + $Port + "/v2/notifications/alarmTemplates/$alarmId/events" +
# 	'?$filter=' + "lastActivation%2Fstatus%20ne%20'Resolved'" # Filters out only active alarms
# 	Write-Verbose "VSPC Alarm Events Url: $url"
# 	$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
# 	$headers.Add("Authorization", "Bearer $token")
# 	try {
# 		$response = Invoke-RestMethod $url -Method 'GET' -Headers $headers -ErrorAction Stop
# 		return $response
# 	}
#  catch {
# 		Write-Error "`nERROR: Retrieving VSPC Alarm Events for Alarm ID $alarmId Failed!"
# 		Exit 1
# 	}
# 	# End VSPC Alarm Check

# }

# Function Check-Value {
# 	param($value)

# 	# If value exists, return value.
# 	if ($value) {
# 		return $value
# 	}
#  else {
# 		# Otherwise, return zero.
# 		return 0
# 	}
# }

# Processing Credentials
if ($Credential) {
	$Username = $Credential.GetNetworkCredential().Username
	$Password = $Credential.GetNetworkCredential().Password
} else {
    if ($Password -eq $true) {
        $secPass = Read-Host "Enter password for '$($Username)'" -AsSecureString
        $Password = ConvertFrom-SecureString -SecureString $secPass -AsPlainText
    }
}

# POST - /token - Authorization
[String] $url = "https://" + $Server + ":" + $Port + "/api/v3/token"
Write-Verbose "GET - $url"
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Content-Type", "application/x-www-form-urlencoded")
$body = "grant_type=password&username=$Username&password=$Password"
try {
	$response = Invoke-RestMethod $url -Method 'POST' -Headers $headers -Body $body -ErrorAction Stop -SkipCertificateCheck:$AllowSelfSignedCerts
	$token = $response.access_token
}
catch {
	Write-Error "ERROR: Authorization Failed! Make sure the correct server and port were specified."
	throw
}
# End Authorization

# GET - /api/v3/organizations - Retrieve Organizations (Service Provider, Resellers, & Companies)
[String] $url = "https://" + $Server + ":" + $Port + "/api/v3/organizations"
Write-Verbose "GET - $url"
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Authorization", "Bearer $token")
try {
	while ($true)
	{
		$response = Invoke-RestMethod $url -Method 'GET' -Headers $headers -ErrorAction Stop -SkipCertificateCheck:$AllowSelfSignedCerts
		$orgs = $response
		Write-Verbose "Organizations found: $($orgs.meta.pagingInfo.total)"
	}
}
catch {
	Write-Error "ERROR: Retrieving Tenants Failed!"
	throw
}
# End Retrieve Organizations

return $orgs

# # Checking for active alarms that could cause incorrect numbers on the report
# $alarms = $false
# $alarm15 = Get-ServerAlarmEvents -AlarmId 15 # Veeam Service Provider Console lost connection to the managed Veeam Backup & Replication server.
# $alarm42 = Get-ServerAlarmEvents -AlarmId 42 # Veeam Service Provider Console has lost connection to the Cloud Connect server.
# if ($alarm15) {
# 	Write-Warning "`nActive alarms are present that will cause usage report numbers to be inaccurate.`nPlease resolve these alarms and re-run this script to ensure accurate numbers."
# 	$alarms = $true
# 	Write-Output "`nVeeam Availability Console lost connection to the following managed Veeam Backup & Replication server(s):`n"
# 	foreach ($event in $alarm15) {
# 		Write-Output $event.computerName
# 	}
# }
# if ($alarm42) {
# 	Write-Warning "`nActive alarms are present that will cause usage report numbers to be inaccurate.`nPlease resolve these alarms and re-run this script to ensure accurate numbers."
# 	$alarms = $true
# 	Write-Output "`nVeeam Availability Console has lost connection to the following Cloud Connect server(s):`n"
# 	foreach ($event in $alarm42) {
# 		Write-Output $event.computerName
# 	}
# }
# # End - Checking for active alarms

# # Get Tenant License Usage
# $detailedUsage = @()
# foreach ($tenant in $tenants) {
# 	$ccUsage = Get-CloudConnectUsage -TenantId $tenant.id
# 	$vbrServerUsage = Get-VbrServerUsage -TenantId $tenant.id
# 	$vbrAgentUsage = Get-VbrAgentUsage -TenantId $tenant.id
# 	$vacAgentUsage = Get-ServerAgentUsage -TenantId $tenant.id

# 	# Parsing Cloud Connect Usage Numbers
# 	$ccSrvBackup = $ccUsage | Where-Object { $_.type -eq "CC_Server_Backup" }
# 	$ccWsBackup = $ccUsage | Where-Object { $_.type -eq "CC_Workstation_Backup" }
# 	$ccVmBackup = $ccUsage | Where-Object { $_.type -eq "CC_VM_Backup" }
# 	$ccVmReplica = $ccUsage | Where-Object { $_.type -eq "CC_VM_Replica" }

# 	# Parsing VBR Server Usage Numbers
# 	$licenseUsage = @()
# 	if ($vbrServerUsage) {
# 		# Pulling license(s) tied to tenant
# 		$tenantVbrLicenses = (
# 			$vbrServerUsage |
# 			Where-Object { $_.serverUid -ne "00000000-0000-0000-0000-000000000000" } | # excluding perpetual licenses
# 			Where-Object { $_.isCloudConnect -eq $false } | # excluding Cloud Connect server licenses
# 			Select-Object "serverUid" -Unique # removing duplicates
# 		).serverUid

# 		# Pulling usage for the licenses identified
# 		foreach ($license in $tenantVbrLicenses) {

# 			# Finding corresponding VBR license
# 			$vbr = $vbrLicenses | Where-Object { $_.id -eq $license }
# 			$vbrLicensesObject = [PSCustomObject] @{
# 				Id               = $vbr.id
# 				BackupServerName = $vbr.backupServerName
# 				Edition          = $vbr.edition
# 				CompanyName      = $vbr.companyName
# 				SupportId        = $vbr.supportID
# 				UsedVMs          = $vbr.usedVMs
# 				NewVMs           = $vbr.newVMs
# 				TotalInstances   = $vbr.totalInstances
# 				UsedInstances    = $vbr.usedInstances
# 			}
# 			$licenseUsage += $vbrLicensesObject
# 		}
# 	}

# 	# Parsing VBR Agent Usage Numbers
# 	$vbrWindowsSrvAgent = $vbrAgentUsage | Where-Object { $_.type -eq "VBR_Windows_Server_Agent" }
# 	$vbrWindowsWsAgent = $vbrAgentUsage | Where-Object { $_.type -eq "VBR_Windows_Workstation_Agent" }

# 	# Parsing VSPC Agent Usage Numbers
# 	$vacWindowsSrvAgent = $vacAgentUsage | Where-Object { $_.type -eq "VAC_Windows_Server_Agent" }
	
# 	$tenantObject = [PSCustomObject] @{
# 		# Basic Tenant Information
# 		TenantName                     = $tenant.name
# 		TenantId                       = $tenant.id
# 		TenantType                     = $tenant.tenantType
# 		IsEnabled                      = $tenant.isEnabled
# 		SiteName                       = $tenant.siteName
# 		# Veeam Backup & Replication for VMware/Hyper-V - VM
# 		VBR_VmBackups                  = $licenseUsage
# 		# Veeam Cloud Connect Backup - Workstation
# 		CC_WsBackupRentalCount         = Check-Value -Value $ccWsBackup.rentalCount
# 		CC_WsBackupNewCount            = Check-Value -Value $ccWsBackup.newCount
# 		CC_WsBackupUsedCount           = Check-Value -Value $ccWsBackup.usedCount
# 		# Veeam Cloud Connect Backup - VM
# 		CC_VmBackupRentalCount         = Check-Value -Value $ccVmBackup.rentalCount
# 		CC_VmBackupNewCount            = Check-Value -Value $ccVmBackup.newCount
# 		CC_VmBackupUsedCount           = Check-Value -Value $ccVmBackup.usedCount
# 		# Veeam Cloud Connect Backup - Server
# 		CC_SrvBackupRentalCount        = Check-Value -Value $ccSrvBackup.rentalCount
# 		CC_SrvBackupNewCount           = Check-Value -Value $ccSrvBackup.newCount
# 		CC_SrvBackupUsedCount          = Check-Value -Value $ccSrvBackup.usedCount
# 		# Veeam Cloud Connect Replication - VM
# 		CC_VmReplicaRentalCount        = Check-Value -Value $ccVmReplica.rentalCount
# 		CC_VmReplicaNewCount           = Check-Value -Value $ccVmReplica.newCount
# 		CC_VmReplicaUsedCount          = Check-Value -Value $ccVmReplica.usedCount
# 		# Veeam Agent for Windows/Linux - Workstation
# 		VBR_WindowsWsAgentRentalCount  = Check-Value -Value $vbrWindowsWsAgent.rentalCount
# 		VBR_WindowsWsAgentNewCount     = Check-Value -Value $vbrWindowsWsAgent.newCount
# 		VBR_WindowsWsAgentUsedCount    = Check-Value -Value $vbrWindowsWsAgent.usedCount
# 		# Veeam Agent for Windows/Linux - Server
# 		VBR_WindowsSrvAgentRentalCount = Check-Value -Value $vbrWindowsSrvAgent.rentalCount
# 		VBR_WindowsSrvAgentNewCount    = Check-Value -Value $vbrWindowsSrvAgent.newCount
# 		VBR_WindowsSrvAgentUsedCount   = Check-Value -Value $vbrWindowsSrvAgent.usedCount
# 		# VSPC Managed - Veeam Agent for Windows/Linux - Server
# 		VAC_WindowsSrvAgentRentalCount = Check-Value -Value $vacWindowsSrvAgent.rentalCount
# 		VAC_WindowsSrvAgentNewCount    = Check-Value -Value $vacWindowsSrvAgent.newCount
# 		VAC_WindowsSrvAgentUsedCount   = Check-Value -Value $vacWindowsSrvAgent.usedCount
# 	}
# 	$detailedUsage += $tenantObject
# }
# # End - Get Tenant License Usage

# # Adding up Veeam Backup & Replication for VMware/Hyper-V - VM
# $editionEnterprisePlusVBR = ($detailedUsage | Where-Object { $_.VBR_VmBackups.Edition -eq "Enterprise Plus" }).VBR_VmBackups.UsedVms
# $editionEnterpriseVBR = ($detailedUsage | Where-Object { $_.VBR_VmBackups.Edition -eq "Enterprise" }).VBR_VmBackups.UsedVms
# $editionStandardVBR = ($detailedUsage | Where-Object { $_.VBR_VmBackups.Edition -eq "Standard" }).VBR_VmBackups.UsedVms

# # Adding up Veeam Agent for Windows/Linux - Server
# $vbrSrvAgent = ($detailedUsage.VBR_WindowsSrvAgentUsedCount | Measure-Object -Sum).Sum
# $vacSrvAgent = ($detailedUsage.VAC_WindowsSrvAgentUsedCount | Measure-Object -Sum).Sum
# $srvAgent = $vbrSrvAgent + $vacSrvAgent # Adding both VBR & VSPC managed agent-based backups for total count

# # Creating combined usage object
# if ($Detailed) {
#  # Detailed metrics requested
# 	$usageObject = [PSCustomObject] @{
# 		Alarms             = $alarms
# 		VBR_EntPlus_Total  = ($editionEnterprisePlusVBR | Measure-Object -Sum).Sum
# 		VBR_Ent_Total      = ($editionEnterpriseVBR | Measure-Object -Sum).Sum
# 		VBR_Standard_Total = ($editionStandardVBR | Measure-Object -Sum).Sum
# 		CC_WsBackup_Total  = ($detailedUsage.CC_WsBackupUsedCount | Measure-Object -Sum).Sum
# 		CC_VmBackup_Total  = ($detailedUsage.CC_VmBackupUsedCount | Measure-Object -Sum).Sum
# 		CC_SrvBackup_Total = ($detailedUsage.CC_SrvBackupUsedCount | Measure-Object -Sum).Sum
# 		CC_VmReplica_Total = ($detailedUsage.CC_VmReplicaUsedCount | Measure-Object -Sum).Sum
# 		Agent_Ws_Total     = ($detailedUsage.VBR_WindowsWsAgentUsedCount | Measure-Object -Sum).Sum
# 		Agent_Srv_Total    = $srvAgent
# 		Detailed_Metrics   = $detailedUsage
# 	}
# }
# else {
#  # Detailed metrics not requested
# 	$usageObject = [PSCustomObject] @{
# 		Alarms             = $alarms
# 		VBR_EntPlus_Total  = ($editionEnterprisePlusVBR | Measure-Object -Sum).Sum
# 		VBR_Ent_Total      = ($editionEnterpriseVBR | Measure-Object -Sum).Sum
# 		VBR_Standard_Total = ($editionStandardVBR | Measure-Object -Sum).Sum
# 		CC_WsBackup_Total  = ($detailedUsage.CC_WsBackupUsedCount | Measure-Object -Sum).Sum
# 		CC_VmBackup_Total  = ($detailedUsage.CC_VmBackupUsedCount | Measure-Object -Sum).Sum
# 		CC_SrvBackup_Total = ($detailedUsage.CC_SrvBackupUsedCount | Measure-Object -Sum).Sum
# 		CC_VmReplica_Total = ($detailedUsage.CC_VmReplicaUsedCount | Measure-Object -Sum).Sum
# 		Agent_Ws_Total     = ($detailedUsage.VBR_WindowsWsAgentUsedCount | Measure-Object -Sum).Sum
# 		Agent_Srv_Total    = $srvAgent
# 	}
# }

# Outputting PowerShell object
# return $usageObject
