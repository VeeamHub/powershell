<#
.SYNOPSIS
	Veeam Availability Console (VAC) License Usage Report

.DESCRIPTION
	This script will return VAC point in time license usage that will be
	nearly identical to the VAC monthly usage report generated at the
	beginning of the month.
	
.PARAMETER Server
	VAC Server IP or FQDN

.PARAMETER UserName
	VAC Portal Administrator account username

.PARAMETER Password
	VAC Portal Administrator account password

.PARAMETER Credential
	VAC Portal Administrator account PS Credential Object

.PARAMETER Port
	VAC Rest API port

.PARAMETER AllowSelfSignedCerts
	Flag allowing self-signed certificates (insecure)

.PARAMETER Detailed
	Flag to include a list of all metrics gathered

.OUTPUTS
	VAC-UsageReport returns a PowerShell Object containing all data

.EXAMPLE
	VAC-UsageReport.ps1 -Server "vac.contoso.local" -Username "contoso\jsmith" -Password "password"

	Description 
	-----------     
	Connect to the specified VAC server using the username/password specified

.EXAMPLE
	VAC-UsageReport.ps1 -Server "vac.contoso.local" -Credential (Get-Credential)

	Description 
	-----------     
	PowerShell credentials object is supported

.EXAMPLE
	VAC-UsageReport.ps1 -Server "vac.contoso.local" -Credential $cred_vac -Detailed

	Description 
	-----------     
	Includes a detailed list of all metrics (and then some) used to generate the monthly usage report

.EXAMPLE
	VAC-UsageReport.ps1 -Server "vac.contoso.local" -Username "contoso\jsmith" -Password "password" -Port 9999

	Description 
	-----------     
	Connecting to a VAC server using a non-standard API port

.EXAMPLE
	VAC-UsageReport.ps1 -Server "vac.contoso.local" -Username "contoso\jsmith" -Password "password" -AllowSelfSignedCerts

	Description 
	-----------     
	Connecting to a VAC server that uses Self-Signed Certificates (insecure)

.NOTES
	NAME:  VAC-UsageReport.ps1
	VERSION: 1.0
	AUTHOR: Chris Arceneaux
	TWITTER: @chris_arceneaux
	GITHUB: https://github.com/carceneaux

.LINK
	https://arsano.ninja/

.LINK
	https://helpcenter.veeam.com/docs/vac/rest/license_usage.html?ver=30
#>
[CmdletBinding(DefaultParametersetName="UsePass")]
param(
    [Parameter(Mandatory=$true)]
		[String] $Server,
	[Parameter(Mandatory=$true, ParameterSetName="UsePass")]
		[String] $Username,
	[Parameter(Mandatory=$true, ParameterSetName="UsePass")]
		[String] $Password,
	[Parameter(Mandatory=$true, ParameterSetName="UseCred")]
		[System.Management.Automation.PSCredential]$Credential,
	[Parameter(Mandatory=$false)]
		[Int] $Port = 1281,
	[Parameter(Mandatory=$false)]
		[Switch] $AllowSelfSignedCerts,
	[Parameter(Mandatory=$false)]
		[Switch] $Detailed
)

Function Get-CloudConnectUsage{
	param([String] $tenantId)

	# GET - /v2/tenants/{tenantId}/licensing/cloudConnectUsage
	[String] $url = "https://" + $Server + ":" + $Port + "/v2/tenants/$tenantId/licensing/cloudConnectUsage"
	Write-Verbose "Cloud Connect Usage Url: $url"
	$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
	$headers.Add("Authorization", "Bearer $token")
	try {
		$response = Invoke-RestMethod $url -Method 'GET' -Headers $headers -ErrorAction Stop
		return $response
	} catch {
		Write-Error "`nERROR: Retrieving Cloud Connect Usage for Tenant ID $tenantId Failed!"
		Exit 1
	}
	# End Cloud Connect Usage

}

Function Get-VbrServerUsage{
	param([String] $tenantId)

	# GET - /v2/tenants/{id}/backupServers
	[String] $url = "https://" + $Server + ":" + $Port + "/v2/tenants/$tenantId/backupServers"
	Write-Verbose "VBR Server Usage Url: $url"
	$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
	$headers.Add("Authorization", "Bearer $token")
	try {
		$response = Invoke-RestMethod $url -Method 'GET' -Headers $headers -ErrorAction Stop
		return $response
	} catch {
		Write-Error "`nERROR: Retrieving VBR Server Usage for Tenant ID $tenantId Failed!"
		Exit 1
	}
	# End VBR Server Usage

}

Function Get-VbrAgentUsage{
	param([String] $tenantId)

	# GET - /v2/tenants/{tenantId}/licensing/backupServerUsage
	[String] $url = "https://" + $Server + ":" + $Port + "/v2/tenants/$tenantId/licensing/backupServerUsage"
	Write-Verbose "VBR Agent Usage Url: $url"
	$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
	$headers.Add("Authorization", "Bearer $token")
	try {
		$response = Invoke-RestMethod $url -Method 'GET' -Headers $headers -ErrorAction Stop
		return $response
	} catch {
		Write-Error "`nERROR: Retrieving VBR Agent Usage for Tenant ID $tenantId Failed!"
		Exit 1
	}
	# End VBR Agent Usage

}

Function Get-ServerAgentUsage{
	param([String] $tenantId)

	# GET - /v2/tenants/{tenantId}/licensing/availabilityConsoleUsage
	[String] $url = "https://" + $Server + ":" + $Port + "/v2/tenants/$tenantId/licensing/availabilityConsoleUsage"
	Write-Verbose "VAC Agent Usage Url: $url"
	$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
	$headers.Add("Authorization", "Bearer $token")
	try {
		$response = Invoke-RestMethod $url -Method 'GET' -Headers $headers -ErrorAction Stop
		return $response
	} catch {
		Write-Error "`nERROR: Retrieving VAC Agent Usage for Tenant ID $tenantId Failed!"
		Exit 1
	}
	# End VAC Agent Usage

}

Function Get-ServerAlarmEvents{
	param([String] $alarmId)

	# GET - /v2/notifications/alarmTemplates/{id}/events
	[String] $url = "https://" + $Server + ":" + $Port + "/v2/notifications/alarmTemplates/$alarmId/events" +
		'?$filter=' + "lastActivation%2Fstatus%20ne%20'Resolved'" # Filters out only active alarms
	Write-Verbose "VAC Alarm Events Url: $url"
	$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
	$headers.Add("Authorization", "Bearer $token")
	try {
		$response = Invoke-RestMethod $url -Method 'GET' -Headers $headers -ErrorAction Stop
		return $response
	} catch {
		Write-Error "`nERROR: Retrieving VAC Alarm Events for Alarm ID $alarmId Failed!"
		Exit 1
	}
	# End VAC Alarm Check

}

Function Check-Value{
	param($value)

	# If value exists, return value.
	if ($value){
		return $value
	} else {
		# Otherwise, return zero.
		return 0
	}
}

# Allow Self-Signed Certificates (not recommended)
if ($AllowSelfSignedCerts){
	add-type -TypeDefinition  @"
        using System.Net;
        using System.Security.Cryptography.X509Certificates;
        public class TrustAllCertsPolicy : ICertificatePolicy {
            public bool CheckValidationResult(
                ServicePoint srvPoint, X509Certificate certificate,
                WebRequest request, int certificateProblem) {
                return true;
            }
        }
"@
    [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
}

# Processing Credentials
if ($Credential){
	$Username = $Credential.GetNetworkCredential().Username
	$Password = $Credential.GetNetworkCredential().Password
}

# POST - /token - Authorization
[String] $url = "https://" + $Server + ":" + $Port + "/token"
Write-Verbose "Authorization Url: $url"
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Content-Type", "application/x-www-form-urlencoded")
$body = "grant_type=password&username=$Username&password=$Password"
try {
	$response = Invoke-RestMethod $url -Method 'POST' -Headers $headers -Body $body -ErrorAction Stop
	$token = $response.access_token
} catch {
	Write-Error "`nERROR: Authorization Failed!"
	Exit 1
}
# End Authorization

# GET - /v2/tenants - Retrieve Tenants (Companies)
[String] $url = "https://" + $Server + ":" + $Port + "/v2/tenants"
Write-Verbose "Tenants Url: $url"
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Authorization", "Bearer $token")
try {
	$response = Invoke-RestMethod $url -Method 'GET' -Headers $headers -ErrorAction Stop
	$tenants = $response
} catch {
	Write-Error "`nERROR: Retrieving Tenants Failed!"
	Exit 1
}
# End Retrieve Tenants (Companies)

# GET - /v2/licensing/backupserverLicenses - Retrieve VBR Licenses
[String] $url = "https://" + $Server + ":" + $Port + "/v2/licensing/backupserverLicenses"
Write-Verbose "VBR Licenses Url: $url"
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Authorization", "Bearer $token")
try {
	$response = Invoke-RestMethod $url -Method 'GET' -Headers $headers -ErrorAction Stop
	$vbrLicenses = $response
} catch {
	Write-Error "`nERROR: Retrieving VBR Licenses Failed!"
	Exit 1
}
# End Retrieve VBR Licenses

# Checking for active alarms that could cause incorrect numbers on the report
$alarms = $false
$alarm15 = Get-ServerAlarmEvents -AlarmId 15 # Veeam Availability Console lost connection to the managed Veeam Backup & Replication server.
$alarm42 = Get-ServerAlarmEvents -AlarmId 42 # Veeam Availability Console has lost connection to the Cloud Connect server.
if ($alarm15){
	Write-Warning "`nActive alarms are present that will cause usage report numbers to be inaccurate.`nPlease resolve these alarms and re-run this script to ensure accurate numbers."
	$alarms = $true
	Write-Output "`nVeeam Availability Console lost connection to the following managed Veeam Backup & Replication server(s):`n"
	foreach ($event in $alarm15){
		Write-Output $event.computerName
	}
}
if ($alarm42){
	Write-Warning "`nActive alarms are present that will cause usage report numbers to be inaccurate.`nPlease resolve these alarms and re-run this script to ensure accurate numbers."
	$alarms = $true
	Write-Output "`nVeeam Availability Console has lost connection to the following Cloud Connect server(s):`n"
	foreach ($event in $alarm42){
		Write-Output $event.computerName
	}
}
# End - Checking for active alarms

# Get Tenant License Usage
$detailedUsage = @()
foreach ($tenant in $tenants){
	$ccUsage = Get-CloudConnectUsage -TenantId $tenant.id
	$vbrServerUsage = Get-VbrServerUsage -TenantId $tenant.id
	$vbrAgentUsage = Get-VbrAgentUsage -TenantId $tenant.id
	$vacAgentUsage = Get-ServerAgentUsage -TenantId $tenant.id

	# Parsing Cloud Connect Usage Numbers
	$ccSrvBackup = $ccUsage | Where-Object {$_.type -eq "CC_Server_Backup"}
	$ccWsBackup = $ccUsage | Where-Object {$_.type -eq "CC_Workstation_Backup"}
	$ccVmBackup = $ccUsage | Where-Object {$_.type -eq "CC_VM_Backup"}
	$ccVmReplica = $ccUsage | Where-Object {$_.type -eq "CC_VM_Replica"}

	# Parsing VBR Server Usage Numbers
	$licenseUsage = @()
	if ($vbrServerUsage){
		# Pulling license(s) tied to tenant
		$tenantVbrLicenses = (
			$vbrServerUsage |
			Where-Object {$_.serverUid -ne "00000000-0000-0000-0000-000000000000"} | # excluding perpetual licenses
			Where-Object {$_.isCloudConnect -eq $false} | # excluding Cloud Connect server licenses
			Select-Object "serverUid" -Unique # removing duplicates
		).serverUid

		# Pulling usage for the licenses identified
		foreach ($license in $tenantVbrLicenses){

			# Finding corresponding VBR license
			$vbr = $vbrLicenses | Where-Object {$_.id -eq $license}
			$vbrLicensesObject = [PSCustomObject] @{
				Id = $vbr.id
				BackupServerName = $vbr.backupServerName
				Edition = $vbr.edition
				CompanyName = $vbr.companyName
				SupportId = $vbr.supportID
				UsedVMs = $vbr.usedVMs
				NewVMs = $vbr.newVMs
				TotalInstances = $vbr.totalInstances
				UsedInstances = $vbr.usedInstances
			}
			$licenseUsage += $vbrLicensesObject
		}
	}

	# Parsing VBR Agent Usage Numbers
	$vbrWindowsSrvAgent = $vbrAgentUsage | Where-Object {$_.type -eq "VBR_Windows_Server_Agent"}
	$vbrWindowsWsAgent = $vbrAgentUsage | Where-Object {$_.type -eq "VBR_Windows_Workstation_Agent"}

	# Parsing VAC Agent Usage Numbers
	$vacWindowsSrvAgent = $vacAgentUsage | Where-Object {$_.type -eq "VAC_Windows_Server_Agent"}
	
	$tenantObject = [PSCustomObject] @{
		# Basic Tenant Information
		TenantName = $tenant.name
		TenantId = $tenant.id
		TenantType = $tenant.tenantType
		IsEnabled = $tenant.isEnabled
		SiteName = $tenant.siteName
		# Veeam Backup & Replication for VMware/Hyper-V - VM
		VBR_VmBackups = $licenseUsage
		# Veeam Cloud Connect Backup - Workstation
		CC_WsBackupRentalCount = Check-Value -Value $ccWsBackup.rentalCount
		CC_WsBackupNewCount = Check-Value -Value $ccWsBackup.newCount
		CC_WsBackupUsedCount = Check-Value -Value $ccWsBackup.usedCount
		# Veeam Cloud Connect Backup - VM
		CC_VmBackupRentalCount = Check-Value -Value $ccVmBackup.rentalCount
		CC_VmBackupNewCount = Check-Value -Value $ccVmBackup.newCount
		CC_VmBackupUsedCount = Check-Value -Value $ccVmBackup.usedCount
		# Veeam Cloud Connect Backup - Server
		CC_SrvBackupRentalCount = Check-Value -Value $ccSrvBackup.rentalCount
		CC_SrvBackupNewCount = Check-Value -Value $ccSrvBackup.newCount
		CC_SrvBackupUsedCount = Check-Value -Value $ccSrvBackup.usedCount
		# Veeam Cloud Connect Replication - VM
		CC_VmReplicaRentalCount = Check-Value -Value $ccVmReplica.rentalCount
		CC_VmReplicaNewCount = Check-Value -Value $ccVmReplica.newCount
		CC_VmReplicaUsedCount = Check-Value -Value $ccVmReplica.usedCount
		# Veeam Agent for Windows/Linux - Workstation
		VBR_WindowsWsAgentRentalCount = Check-Value -Value $vbrWindowsWsAgent.rentalCount
		VBR_WindowsWsAgentNewCount = Check-Value -Value $vbrWindowsWsAgent.newCount
		VBR_WindowsWsAgentUsedCount = Check-Value -Value $vbrWindowsWsAgent.usedCount
		# Veeam Agent for Windows/Linux - Server
		VBR_WindowsSrvAgentRentalCount = Check-Value -Value $vbrWindowsSrvAgent.rentalCount
		VBR_WindowsSrvAgentNewCount = Check-Value -Value $vbrWindowsSrvAgent.newCount
		VBR_WindowsSrvAgentUsedCount = Check-Value -Value $vbrWindowsSrvAgent.usedCount
		# VAC Managed - Veeam Agent for Windows/Linux - Server
		VAC_WindowsSrvAgentRentalCount = Check-Value -Value $vacWindowsSrvAgent.rentalCount
		VAC_WindowsSrvAgentNewCount = Check-Value -Value $vacWindowsSrvAgent.newCount
		VAC_WindowsSrvAgentUsedCount = Check-Value -Value $vacWindowsSrvAgent.usedCount
	}
	$detailedUsage += $tenantObject
}
# End - Get Tenant License Usage

# Adding up Veeam Backup & Replication for VMware/Hyper-V - VM
$editionEnterprisePlusVBR = ($detailedUsage | Where-Object {$_.VBR_VmBackups.Edition -eq "Enterprise Plus"}).VBR_VmBackups.UsedVms
$editionEnterpriseVBR = ($detailedUsage | Where-Object {$_.VBR_VmBackups.Edition -eq "Enterprise"}).VBR_VmBackups.UsedVms
$editionStandardVBR = ($detailedUsage | Where-Object {$_.VBR_VmBackups.Edition -eq "Standard"}).VBR_VmBackups.UsedVms

# Adding up Veeam Agent for Windows/Linux - Server
$vbrSrvAgent = ($detailedUsage.VBR_WindowsSrvAgentUsedCount | Measure-Object -Sum).Sum
$vacSrvAgent = ($detailedUsage.VAC_WindowsSrvAgentUsedCount | Measure-Object -Sum).Sum
$srvAgent = $vbrSrvAgent + $vacSrvAgent # Adding both VBR & VAC managed agent-based backups for total count

# Creating combined usage object
if ($Detailed){ # Detailed metrics requested
	$usageObject = [PSCustomObject] @{
		Alarms = $alarms
		VBR_EntPlus_Total = ($editionEnterprisePlusVBR | Measure-Object -Sum).Sum
		VBR_Ent_Total = ($editionEnterpriseVBR | Measure-Object -Sum).Sum
		VBR_Standard_Total = ($editionStandardVBR | Measure-Object -Sum).Sum
		CC_WsBackup_Total = ($detailedUsage.CC_WsBackupUsedCount | Measure-Object -Sum).Sum
		CC_VmBackup_Total = ($detailedUsage.CC_VmBackupUsedCount | Measure-Object -Sum).Sum
		CC_SrvBackup_Total = ($detailedUsage.CC_SrvBackupUsedCount | Measure-Object -Sum).Sum
		CC_VmReplica_Total = ($detailedUsage.CC_VmReplicaUsedCount | Measure-Object -Sum).Sum
		Agent_Ws_Total = ($detailedUsage.VBR_WindowsWsAgentUsedCount | Measure-Object -Sum).Sum
		Agent_Srv_Total = $srvAgent
		Detailed_Metrics = $detailedUsage
	}
} else { # Detailed metrics not requested
	$usageObject = [PSCustomObject] @{
		Alarms = $alarms
		VBR_EntPlus_Total = ($editionEnterprisePlusVBR | Measure-Object -Sum).Sum
		VBR_Ent_Total = ($editionEnterpriseVBR | Measure-Object -Sum).Sum
		VBR_Standard_Total = ($editionStandardVBR | Measure-Object -Sum).Sum
		CC_WsBackup_Total = ($detailedUsage.CC_WsBackupUsedCount | Measure-Object -Sum).Sum
		CC_VmBackup_Total = ($detailedUsage.CC_VmBackupUsedCount | Measure-Object -Sum).Sum
		CC_SrvBackup_Total = ($detailedUsage.CC_SrvBackupUsedCount | Measure-Object -Sum).Sum
		CC_VmReplica_Total = ($detailedUsage.CC_VmReplicaUsedCount | Measure-Object -Sum).Sum
		Agent_Ws_Total = ($detailedUsage.VBR_WindowsWsAgentUsedCount | Measure-Object -Sum).Sum
		Agent_Srv_Total = $srvAgent
	}
}

# Outputting PowerShell object
return $usageObject
