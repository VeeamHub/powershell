#Requires -Version 7
#Requires -Modules PSSendGrid

<#
.Synopsis
  Generates report of relevant data on all customers known to a given Veeam Service Provider Console Server. Uses the new v3 API so your milage may vary.
.Notes
   Version: 0.6
   Author: Jim Jones
   Modified Date: 8/21/2020

   If running for the first time a new computer You will need to run to store the credentials
    $credpath='c:\creds\myadmincred.xml'
    GET-CREDENTIAL –Credential (Get-Credential) | EXPORT-CLIXML $credpath
.EXAMPLE
  .\vspcCompanyReport.ps1 -vacServer 'vac.mydomain.com' -authPath 'c:\creds\myadmincred.xml'
#>
[CmdletBinding()]
Param (
    [string]$vacServer = "vac.mydomain.com",
    [string]$authPath = 'c:\creds\myadmincred.xml'
)

#Email Variables
$date = Get-Date
$sgToken        = "SendGridToken"
$fromAddress    = "myvac@mydomain.com"
$fromName       = "US VAC"
$toName         = "NetOps"
$toAddress      = "me@me.com"
$emailBody      = "See attached Company Backup Resource Report for $date"

$Credentials = IMPORT-CLIXML -path $authPath
$RESTAPIUser = $Credentials.UserName
$RESTAPIPassword = $Credentials.GetNetworkCredential().Password

$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Content-Type", "application/x-www-form-urlencoded")

$body = "grant_type=password&username=$RestAPIUser&password=$RestAPIPassword"

$response = Invoke-RestMethod "https://$vacServer/api/v3/token" -Method 'POST' -Headers $headers -Body $body
$token = $response.access_token

$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Authorization", "Bearer $token")

#List of Servers for later reference
[System.Collections.ArrayList]$AllVBRServers = @()
$backupServers  = Invoke-RestMethod "https://$vacserver/api/v3/infrastructure/backupServers?limit=500" -Method 'GET' -Headers $headers -Body $body
    foreach ($backupServer in $backupServers.data) {
        $vbrObj = New-Object PSObject -Property @{
            serverUid     = $backupServer.instanceUid
            serverName    = $backupServer.name
            serverType    = $backupServer.backupServerRoleType #should be cloudConnect    
        }
        $AllVBRServers += $vbrObj
    }
    #$AllVBRServers

#Let's grab some repos also for later reference
[System.Collections.ArrayList]$AllRepos = @()
$repos = Invoke-RestMethod "https://$vacserver/api/v3/infrastructure/backupServers/repositories?limit=500" -Method 'GET' -Headers $headers -Body $body
    foreach ($repo in $repos.data) {
        $vbrServerDetail    = $AllVBRServers | Where-Object {$_.serverUid -eq $repo.backupServerUid}
        $repoObj = New-Object PSObject -Property @{
            repoUid         = $repo.instanceUid
            repoServer      = $repo.backupServerUid
            repoPath        = $repo.path
            repoHost        = $repo.hostName
            repoType        = $repo.type
            repoName        = $repo.name
            vbrName         = $vbrServerDetail.serverName
            vbrType         = $vbrServerDetail.serverType
        }
        $AllRepos += $repoObj
    }

#Let's get the tenant information
[System.Collections.ArrayList]$AllTenants = @()
$i = 0
$limit = 500
$tenantResults = Invoke-RestMethod "https://$vacServer/api/v3/infrastructure/sites/tenants" -Method 'GET' -Headers $headers -Body $body
$totalTenantCount = $tenantResults.meta.pagingInfo.total
while ($i -lt $totalTenantCount){        
    $tenantResults = Invoke-RestMethod "https://$vacServer/api/v3/infrastructure/sites/tenants?limit=$limit&offset=$i" -Method 'GET' -Headers $headers -Body $body
    foreach ($tenant in $tenantResults.data){
        $tenantObj = New-Object PSObject -Property @{
            tenantUid    = $tenant.instanceUid            
            tenantName   = $tenant.name
        }
        $AllTenants += $tenantObj
    }
    $i = $i + $limit
}

#Let's get the site information
[System.Collections.ArrayList]$AllSites = @()
$i = 0
$limit = 500
$siteResults = Invoke-RestMethod "https://$vacServer/api/v3/organizations/companies/sites" -Method 'GET' -Headers $headers -Body $body
$totalSitesCount = $siteResults.meta.pagingInfo.total
while ($i -lt $totalSitesCount){        
    $siteresults = Invoke-RestMethod "https://$vacServer/api/v3/organizations/companies/sites?limit=$limit&offset=$i" -Method 'GET' -Headers $headers -Body $body
    foreach ($site in $siteresults.data){
        $tenantDetail = $AllTenants | Where-Object {$_.tenantUid -eq $site.cloudTenantUid}
        $sitesObj = New-Object PSObject -Property @{
            siteUid     = $site.siteUid
            companyUid  = $site.companyUid
            tenantUid   = $site.cloudTenantUid
            Threads     = $site.maxConcurrentTask
            RIPEnabled  = $site.backupProtectionEnabled
            RIPDays     = $site.backupProtectionPeriodDays
            tenantName  = $tenantDetail.tenantName
        }
        $AllSites += $sitesObj
    }
    $i = $i + $limit    
}

#Let's get all the company information
[System.Collections.ArrayList]$AllCompanies = @()
$i = 0
$limit = 500
$companyResults = Invoke-RestMethod "https://$vacServer/api/v3/organizations/companies" -Method 'GET' -Headers $headers -Body $body
$totalCompanyCount = $companyResults.meta.pagingInfo.total
while ($i -lt $totalCompanyCount) {    
    $companyResults = Invoke-RestMethod "https://$vacServer/api/v3/organizations/companies?limit=$limit&offset=$i" -Method 'GET' -Headers $headers -Body $body
    foreach ($company in $companyResults.data){    
        $companyObj = New-Object PSObject -Property @{
            companyUid  = $company.instanceUid
            name        = $company.name
            status      = $company.status
        }            
        $AllCompanies += $companyObj
    }
    $i = $i + $limit
}

#Let's get all the Backup Resources
[System.Collections.ArrayList]$AllBResources = @()
$i = 0
$limit = 500
$bResourcesresults = Invoke-RestMethod "https://$vacServer/api/v3/organizations/companies/sites/backupResources" -Method 'GET' -Headers $headers -Body $body
$totalbResourcesCount = $bResourcesresults.meta.pagingInfo.total
while ($i -lt $totalbResourcesCount){        
    $bResourcesresults = Invoke-RestMethod "https://$vacServer/api/v3/organizations/companies/sites/backupResources?limit=$limit&offset=$i" -Method 'GET' -Headers $headers -Body $body
    foreach ($bResource in $bResourcesresults.data){
        $bCompanyUid = $bResource.companyUid
        #$bSiteUid = $bResource.siteUid
        #Query to get their storage usage
        #$bstorageUsage = Invoke-RestMethod "https://$vacServer/api/v3/organizations/companies/$bCompanyUid/sites/$bSiteUid/backupResources/usage?limit=$limit&offset=$i" -Method 'GET' -Headers $headers -Body $body
         #   $usedStorageQuota = $bstorageUsage.data.usedStorageQuota

        $companyDetail = $AllCompanies | Where-Object {$_.companyUid -eq $bCompanyUid}
        $siteDetail = $AllSites | Where-Object {$_.companyUid -eq $bCompanyUid}
        $repoDetail = $AllRepos | Where-Object {$_.repoUid -eq $bResource.repositoryUid}
        $storageQuotaGB = [math]::round($bResource.storageQuota /1Tb, 2)
        #$storageUsageGB = [math]::round($usedStorageQuota /1Tb, 2)        
        $siteDetail.tenantName

        $bResourcesObj = New-Object PSObject -Property @{
            companyName     = $companyDetail.name
            companyStatus   = $companyDetail.status
            vbrServer       = $repoDetail.vbrName            
            tenantName      = $siteDetail.tenantName
            Threads         = $siteDetail.Threads
            RIPEnabled      = $siteDetail.RIPEnabled
            RIPDays         = $siteDetail.RIPDays
            repoHost        = $repoDetail.repoHost
            repoName        = $repoDetail.repoName
            repoPath        = $repoDetail.repoPath
            storageQuotaTB  = $storageQuotaGB
            #storageUsageTB  = $storageUsageGB
        }
        $AllBResources += $bResourcesObj
    }
    $i = $i + $limit
}
$AllBResources | Export-Csv -Path ".\CompanyBackupResourcesReport.csv" -NoTypeInformation

#Send Mail
Import-Module PSSendGrid

$Parameters = @{
    FromAddress = $FromAddress
    ToAddress   = $ToAddress 
    Subject     = "Company Backup Resource Report for $date"
    Body        = $emailBody
    Token       = $sgToken
    FromName    = $fromName
    ToName      = $toName 
    AttachmentPath        = ".\CompanyBackupResourcesReport.csv"    
}
Send-PSSendGridMail @Parameters
