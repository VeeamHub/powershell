<#
.SYNOPSIS
    Determines if the Microsoft Teams Protected API is enabled for an M365 Tenant.

.DESCRIPTION
    This script leverages Veeam Backup for 365 cmdlets and Microsoft Azure AD / Graph API cmdlets to validate whether access is present for the Microsoft Teams Protected API referenced in the KB article listed in the links.
    
.PARAMETER TenantId
    Microsoft 365 tenant ID

.PARAMETER AppId
    Azure app registration ID

.PARAMETER CertThumbprint
    Azure app registration certificate thumbprint

.OUTPUTS
    Get-ProtectedAPIStatus.ps1 returns string output to guide the user

.EXAMPLE
    Get-ProtectedAPIStatus.ps1

    Description
    -----------
    Must be run on the VB365 server! As no parameters are specified, the user first logs in to Azure AD to determine then Tenant Id. Then, the AppId and CertThumbprint are pulled using VB365 cmdlets. Protected API status is then returned.

.EXAMPLE
    Get-ProtectedAPIStatus.ps1 -TenantId "46c4fd38-f62b-4ff6-ac91-d1165a427804" -AppId "19ea5b98-ec35-4a4d-c6f9-9690403c6948" -CertThumbprint "60F50AEB325B119BB63929D0C430AAB223938ABF"

    Description
    -----------
    Certificate must be installed on the computer where this is run! As all parameters are specified, a VB365 server is not required. Graph API is accessed immediately and then Protected API status is returned.

.EXAMPLE
    Get-ProtectedAPIStatus.ps1 -Verbose

    Description
    -----------
    Verbose output is supported

.NOTES
    NAME: Get-ProtectedAPIStatus.ps1
    VERSION: 1.0
    AUTHOR: Chris Arceneaux, Fabian Kessler

.LINK
    https://www.veeam.com/kb4322

.LINK
    https://community.veeam.com/script-library-67/verify-access-to-the-protected-teams-api-2931

#>

[CmdletBinding(DefaultParametersetName="None")]
param(
    [Parameter(Mandatory=$true, ParameterSetName="UseParams")]
        [string]$TenantId,
    [Parameter(Mandatory=$true, ParameterSetName="UseParams")]
        [string]$AppId,
    [Parameter(Mandatory=$true, ParameterSetName="UseParams")]
        [string]$CertThumbprint
)

# if parameters specified
if ($TenantId) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Find-PackageProvider -Name Nuget -ForceBootstrap -IncludeDependencies -Force | Out-Null
    # Determine if Microsoft.Graph module is already present
    if ( -not(Get-Module -ListAvailable -Name Microsoft.Graph)){
    Install-Module -Name Microsoft.Graph -SkipPublisherCheck -Force -ErrorAction Stop
    Write-Host "Microsoft.Graph module installed successfully" -ForegroundColor Green
    } else {
    Write-Host "Microsoft.Graph module already present" -ForegroundColor Green
    }
}
# if no parameters specified
else {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Find-PackageProvider -Name Nuget -ForceBootstrap -IncludeDependencies -Force | Out-Null
    # Determine if Microsoft.Graph module is already present
    if ( -not(Get-Module -ListAvailable -Name Microsoft.Graph)){
    Install-Module -Name Microsoft.Graph -SkipPublisherCheck -Force -ErrorAction Stop
    Write-Host "Microsoft.Graph module installed successfully" -ForegroundColor Green
    } else {
    Write-Host "Microsoft.Graph module already present" -ForegroundColor Green
    }
    # determine if AzureAd module is already present
    if ( -not(Get-Module -ListAvailable -Name AzureAd)){
        Install-Module -Name AzureAD -SkipPublisherCheck -Force -ErrorAction Stop
        Write-Host "AzureAD module installed successfully" -ForegroundColor Green
    } else {
        Write-Host "AzureAD module already present" -ForegroundColor Green
    }

    Write-Host ""

    # connecting to Azure AD
    try {
        Write-Verbose "Connecting to Azure AD account"
        $ad = Connect-AzureAD -ErrorAction Stop
        Write-Host "$($ad.Account.Id) is now connected to Microsoft Azure AD" -ForegroundColor Green
        # setting M365 tenant ID
        $TenantId = $ad.TenantId.Guid
    }
    catch {
        Write-Error "An issue occurred while logging into Microsoft Azure AD. Please double-check your credentials and ensure you have sufficient access."
        throw $_
    }

    Write-Host ""

    # choosing VB365 Organization
    $org = Get-VBOOrganization -Name $ad.TenantDomain
    if ($null -eq $org) {
        throw "Organization ($($ad.TenantDomain)) not found on this VB365 server. Please make sure you're running the script on the correct server."
    }

    # retrieving azure app ID and certificate thumbprint
    if ($org.Office365ExchangeConnectionSettings.AuthenticationType -eq "ApplicationOnly") {
        Write-Host "Application ID ($($org.Office365ExchangeConnectionSettings.ApplicationId.Guid)) and Certificate Thumbprint ($($org.Office365ExchangeConnectionSettings.ApplicationCertificateThumbprint)) found!"
        $AppId = $org.Office365ExchangeConnectionSettings.ApplicationId.Guid
        $CertThumbprint = $org.Office365ExchangeConnectionSettings.ApplicationCertificateThumbprint
    }
}

# retrieving cert using thumbprint
try {
    $cert = Get-ChildItem Cert:\LocalMachine\My\$CertThumbprint
}
catch {
    Write-Error "Unable to retrieve certificate. Please make sure the certificate exists on this server."
    throw $_
}

# connecting to Microsoft Graph API
try {
    Write-Verbose "Connecting to Microsoft Graph API"
    Connect-MgGraph -AppId $AppId -TenantId $TenantId -Certificate $cert -ErrorAction Stop
}
catch {
    Write-Error "An issue occurred while logging into Microsoft Graph API. Please double-check your credentials and ensure you have sufficient access."
    throw $_
}

Write-Host ""

# Get all M365 group (unified group) and use the ID to query a list of messages for a single team (second one, first one is the default group without a team attached)
try {
    $teams = Get-MgGroup -Filter "groupTypes/any(c:c eq 'Unified')" | Select-Object Id
    Get-MgTeamChannelMessage -TeamID $teams.Id[1] -ErrorAction Stop | Out-Null
    Write-Host "Teams Protected API is accessible!" -ForegroundColor Green
}
catch {
    Write-Host "Teams Protected API is not available." -ForegroundColor Yellow
    Write-Host "If you haven't already, you can request access to this API using the instructions highlighed in the below KB article:"
    Write-Host ""
    Write-Host "https://www.veeam.com/kb4322"
}

# logging out of remote sessions
Write-Verbose "Logging out of Azure AD account"
Disconnect-AzureAD | Out-Null
Write-Verbose "Logging out of Microsoft Graph API"
Disconnect-MgGraph | Out-Null