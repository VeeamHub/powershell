<#
	.SYNOPSIS
	Veeam Cloud Connect Usage Report
  
	.DESCRIPTION
	This Script will Report Cloud Connect Tenant Statistics
        
	.EXAMPLE
	VCC-UsageReport.ps1 -Server VeeamEM.lan.local -HTTPS:$True -Authentication <yourBase64>

	.EXAMPLE
	VCC-UsageReport.ps1 -Server VeeamEM.lan.local -HTTPS:$False -Authentication <yourBase64>
	
	.Notes
	NAME:  VCC-UsageReport.ps
	LASTEDIT: 08/22/2016
	VERSION: 1.2
	KEYWORDS: Veeam, Cloud Connect
    BASED ON: http://mycloudrevolution.com/2016/08/16/prtg-veeam-cloud-connect-monitoring/
   
	.Link
	http://mycloudrevolution.com/
 
 #Requires PS -Version 3.0  
 #>
[cmdletbinding()]
param(
    [Parameter(Position=0, Mandatory=$true)]
    	[String] $Server,
	[Parameter(Position=1, Mandatory=$true)]
		[String] $Authentication,
	[Parameter(Position=2, Mandatory=$false)]
		[Boolean] $HTTPS = $True


)

#region: Workaround for SelfSigned Cert
add-type @"
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
#endregion

#region: Switch Http/s
if ($HTTPS -eq $True) {$Proto = "https"; $Port = "9398"} else {$Proto = "http"; $Port = "9399"}
#endregion

#region: POST - Authorization
[String] $URL = $Proto + "://" + $Server + ":" + $Port + "/api/sessionMngr/?v=v1_2"
Write-Verbose "Authorization Url: $URL"
$Auth = @{uri = $URL;
                   Method = 'POST';
                   Headers = @{Authorization = 'Basic ' + $Authentication;
           }
   }
try {$AuthXML = Invoke-WebRequest @Auth -ErrorAction Stop} catch {Write-Error "`nERROR: Authorization Failed!";Exit 1}
#endregion

#region: GET - Session Statistics
[String] $URL = $Proto + "://" + $Server + ":" + $Port + "/api/cloud/tenants"
Write-Verbose "Session Statistics Url: $URL"
$Tenants = @{uri = $URL;
                   Method = 'GET';
				   Headers = @{'X-RestSvcSessionId' = $AuthXML.Headers['X-RestSvcSessionId'];
           } 
	}
try {$TenantsXML = Invoke-RestMethod @Tenants -ErrorAction Stop} catch {Write-Error "`nERROR: Get Session Statistics Failed!";Exit 1}
#endregion

#region: Get Tenant Details
[Array] $Hrefs	= $TenantsXML.EntityReferences.Ref.Href
$VCCBillings	= @()

for ( $i = 0; $i -lt $Hrefs.Count; $i++){
	[String] $URL = $Hrefs[$i] + "?format=Entity"
	Write-Verbose "Tenant Detail Url: $URL"
	$TenantsDetails = @{uri = $URL;
    	               Method = 'GET';
					   Headers = @{'X-RestSvcSessionId' = $AuthXML.Headers['X-RestSvcSessionId'];
           	} 
		}
	try {$TenantsDetailsXML = Invoke-RestMethod @TenantsDetails -ErrorAction Stop} catch {Write-Error "`nERROR: Get Tenant Details Failed!";Exit 1}
#endregion

#region: Build Report	
# Customer Name
[String] $CustomerName = $TenantsDetailsXML.CloudTenant.Name
# Customer BaaS and DRaaS Objects
[Int] $BackupCount = $TenantsDetailsXML.CloudTenant.BackupCount
[Int] $ReplicaCount = $TenantsDetailsXML.CloudTenant.ReplicaCount
# Customer BaaS Quotas
[Array] $BackupUsedQuota = $TenantsDetailsXML.CloudTenant.Resources.CloudTenantResource.RepositoryQuota.UsedQuota
[Int] $BackupUsedQuota = (($BackupUsedQuota) | Measure-Object -Sum).Sum
[Array] $BackupQuota = $TenantsDetailsXML.CloudTenant.Resources.CloudTenantResource.RepositoryQuota.Quota
[Int] $BackupQuota = (($BackupQuota) | Measure-Object -Sum).Sum
# Customer DRaaS Quotas
[Array]  $ReplicaMemoryUsageMb = $TenantsDetailsXML.CloudTenant.ComputeResources.CloudTenantComputeResource.ComputeResourceStats.MemoryUsageMb
if ($null -eq $ReplicaMemoryUsageMb) {$ReplicaMemoryUsageMb = 0}
[Int] $ReplicaMemoryUsageMb = (($ReplicaMemoryUsageMb) | Measure-Object -Sum).Sum
[Array]  $ReplicaCPUCount = $TenantsDetailsXML.CloudTenant.ComputeResources.CloudTenantComputeResource.ComputeResourceStats.CPUCount
if ($null -eq $ReplicaCPUCount) {$ReplicaCPUCount = 0}
[Int] $ReplicaCPUCount = (($ReplicaCPUCount) | Measure-Object -Sum).Sum
[Array]  $ReplicaStorageUsageGb = $TenantsDetailsXML.CloudTenant.ComputeResources.CloudTenantComputeResource.ComputeResourceStats.StorageResourceStats.StorageResourceStat.StorageUsageGb
if ($null -eq $ReplicaStorageUsageGb) {$ReplicaStorageUsageGb = 0}
[Int] $ReplicaStorageUsageGb = (($ReplicaStorageUsageGb) | Measure-Object -Sum).Sum
[Array]  $ReplicaStorageLimitGb = $TenantsDetailsXML.CloudTenant.ComputeResources.CloudTenantComputeResource.ComputeResourceStats.StorageResourceStats.StorageResourceStat.StorageLimitGb
if ($null -eq $ReplicaStorageLimitGb) {$ReplicaStorageLimitGb = 0; $ReplicaStorageUsedPerc = 0}
[Int] $ReplicaStorageLimitGb = (($ReplicaStorageLimitGb) | Measure-Object -Sum).Sum

if ($ReplicaStorageLimitGb -gt 0) {
	$ReplicaStorageUsedPerc =  [Math]::Round(($ReplicaStorageUsageGb / $ReplicaStorageLimitGb) * 100,0)	
	}

$VCCObject = [PSCustomObject] @{
	CustomerName  = $CustomerName
	BackupCount = $BackupCount
	ReplicaCount = $ReplicaCount
	BackupQuotaGb = $BackupQuota
	BackupUsedQuotaGb = $BackupUsedQuota
	BackupQuotaUsedPerc = [Math]::Round(($BackupUsedQuota / $BackupQuota) * 100,0)
	ReplicaMemoryUsageMb = $ReplicaMemoryUsageMb
	ReplicaCPUCount = $ReplicaCPUCount
	ReplicaStorageLimitGb = $ReplicaStorageLimitGb
	ReplicaStorageUsageGb = $ReplicaStorageUsageGb
	ReplicaStorageUsedPerc = $ReplicaStorageUsedPerc
}
$VCCBillings += $VCCObject
}
#endregion

#region: Report Output
$VCCBillings | Format-Table * -Autosize
#endregion