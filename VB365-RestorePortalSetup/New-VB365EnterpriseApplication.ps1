<#
.SYNOPSIS
	Creates an Enterprise Application for use with the Veeam Backup for Microsoft 365 Restore Portal.

.DESCRIPTION
  The script logs in to a Microsoft 365 environment and creates an Enterprise Application (and App Registration) with permissions that's required for the Veeam Backup for Microsoft 365 Restore Portal.
	
.PARAMETER Name
	Name of the Enterprise Application to be created

.PARAMETER URL
	URL to be provided to customers to access the Restore Portal

.OUTPUTS
	New-VB365EnterpriseApplication.ps1 returns string output to guide the user

.EXAMPLE
	New-VB365EnterpriseApplication.ps1 -Name "Veeam Restore Portal" -URL "https://veeam.domain:4443"

	Description
	-----------
	Creates an Enterprise Application in Azure AD with the specified name using the specified redirect URL

.EXAMPLE
	New-VB365EnterpriseApplication.ps1 -Name "Veeam Restore Portal" -URL "https://veeam.domain:4443" -Verbose

	Description
	-----------
	Verbose output is supported

.NOTES
	NAME:  New-VB365EnterpriseApplication.ps1
	VERSION: 1.0
	AUTHOR: Chris Arceneaux
	TWITTER: @chris_arceneaux
	GITHUB: https://github.com/carceneaux

.LINK
  https://helpcenter.veeam.com/docs/vbo365/guide/ssp_configuration.html

.LINK
  https://helpcenter.veeam.com/docs/vbo365/guide/ssp_ad_application_permissions.html

.LINK
  https://docs.microsoft.com/en-us/powershell/module/azuread/?view=azureadps-2.0#applications

.LINK
	https://arsano.ninja/

#>
#Requires -Modules Az.Accounts, AzureAd

[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)]
    [string]$Name,
  [Parameter(Mandatory=$true)]
    [string]$URL
)

# Setting default PowerShell action to halt on error
$ErrorActionPreference = "Stop"

# connecting to all things Microsoft
try {
  Write-Verbose "Connecting to Microsoft Azure account"
  Connect-AzAccount -ErrorAction Stop | Out-Null
  $context = Get-AzContext
  Write-Verbose "Connecting to Azure AD account"
  Connect-AzureAD -TenantId $context.Tenant.TenantId -AccountId $context.Account.Id -ErrorAction Stop | Out-Null
  Write-Host "$($context.Account.Id) is now connected to Microsoft Azure" -ForegroundColor Green
} catch {
  Write-Error "An issue occurred while logging into Microsoft. Please double-check your credentials and ensure you have sufficient access."
  throw $_
}

# creating App registration
Write-Verbose "Creating Azure AD Application ($Name)"
$app = New-AzureADApplication -DisplayName $Name -AvailableToOtherTenants $true -PublicClient $true
Write-Host "Application ($($app.AppId)) has been created" -ForegroundColor Green

# creating self-signed certificate
Write-Verbose "Creating self-signed certificate to be used as a shared key for the Restore Portal"
$cn = $URL -replace "https://",""
$cert = New-SelfSignedCertificate -Type Custom -KeyExportPolicy Exportable -KeyUsage None -KeyAlgorithm RSA -KeyLength 2048 -HashAlgorithm SHA1 -NotAfter (Get-Date).AddYears(10) -Subject "CN=$cn" -FriendlyName $Name
Write-Host "Certificate $($cert.Thumbprint) has been created and saved to the Local Machine certificate store" -ForegroundColor Green

# adding certificate to application
$bin = $cert.GetRawCertData()
$base64Value = [System.Convert]::ToBase64String($bin)
$bin = $cert.GetCertHash()
$base64Thumbprint = [System.Convert]::ToBase64String($bin)
New-AzureADApplicationKeyCredential -ObjectId $app.ObjectId -CustomKeyIdentifier $base64Thumbprint -Type AsymmetricX509Cert -Usage Verify -Value $base64Value -StartDate ([System.DateTime]::Now) -EndDate $cert.GetExpirationDateString() | Out-Null
Write-Verbose "Certificate has been added to the Application"

# retrieving newly created application object
Write-Verbose "Retrieving newly create application object ($($app.ObjectId))"
$object = Get-AzureADMSApplication -ObjectId $app.ObjectId
$api = $object.Api
$scopes = New-Object System.Collections.Generic.List[Microsoft.Open.MsGraph.Model.PermissionScope]

# checking if default API scope already exists
Write-Verbose "Checking for already existing API permissions..."
if ($api.Oauth2PermissionScopes){
  Write-Verbose "PERMISSIONS FOUND: Updating permissions"
  # updating default API scope
  $permissionScope = New-Object Microsoft.Open.MsGraph.Model.PermissionScope
  $permissionScope.Id = $api.Oauth2PermissionScopes[0].Id
} else { 
  Write-Verbose "NO PERMISSIONS: Creating permissions"
  # creating new API scope
  $permissionScope = New-Object Microsoft.Open.MsGraph.Model.PermissionScope
  $permissionScope.Id = New-Guid  
}
$permissionScope.Value = "access_as_user"
$permissionScope.Type = "Admin"
$permissionScope.IsEnabled = $true
$permissionScope.UserConsentDisplayName = "Access Veeam Backup for Microsoft 365 Restore Portal"
$permissionScope.UserConsentDescription = "Allows access to Veeam Backup for Microsoft 365 Restore Portal on your behalf"
$permissionScope.AdminConsentDisplayName = "Access Veeam Backup for Microsoft 365 Restore Portal"
$permissionScope.AdminConsentDescription = "Allows access to Veeam Backup for Microsoft 365 Restore Portal as the signed-in user"

# adding access_as_user permission scope
$scopes.Add($permissionScope)
$api.Oauth2PermissionScopes = $scopes

# creating web application
Write-Verbose "Disabling default web application configuration"
$webApplication = New-Object Microsoft.Open.MSGraph.Model.WebApplication
$webApplication.ImplicitGrantSettings = New-Object Microsoft.Open.MSGraph.Model.ImplicitGrantSettings
$webApplication.ImplicitGrantSettings.EnableAccessTokenIssuance = $false
$webApplication.ImplicitGrantSettings.EnableIdTokenIssuance = $false

# updating application object
Set-AzureADMSApplication -ObjectId $object.Id -Api $api -Web $webApplication
Write-Host "Application object $($object.Id) has been updated successfully with API permissions and new web application configuration" -ForegroundColor Green

#Get Service Principal of Microsoft Graph Resource API
Write-Verbose "Gathering remainder of permissions (User.Read & access_as_user)"
$graphSP =  Get-AzureADServicePrincipal -All $true | Where-Object {$_.DisplayName -eq "Microsoft Graph"}

#Initialize RequiredResourceAccess object
$requiredResourcesAccess = New-Object System.Collections.Generic.List[Microsoft.Open.AzureAD.Model.RequiredResourceAccess]

#### adding permissions for User.Read
$requiredGraphAccess = New-Object Microsoft.Open.AzureAD.Model.RequiredResourceAccess
$requiredGraphAccess.ResourceAppId = $graphSP.AppId
$requiredGraphAccess.ResourceAccess = New-Object System.Collections.Generic.List[Microsoft.Open.AzureAD.Model.ResourceAccess]

#Get required delegated permission
$reqPermission = $graphSP.Oauth2Permissions | Where-Object {$_.Value -eq 'User.Read'}
$resourceAccess = New-Object Microsoft.Open.AzureAD.Model.ResourceAccess
$resourceAccess.Type = "Scope"
$resourceAccess.Id = $reqPermission.Id

#Add required delegated permission
$requiredGraphAccess.ResourceAccess.Add($resourceAccess)
$requiredResourcesAccess.Add($requiredGraphAccess)

#### adding permissions for access_as_user
$requiredGraphAccess = New-Object Microsoft.Open.AzureAD.Model.RequiredResourceAccess
$requiredGraphAccess.ResourceAppId = $app.AppId
$requiredGraphAccess.ResourceAccess = New-Object System.Collections.Generic.List[Microsoft.Open.AzureAD.Model.ResourceAccess]

#Get required delegated permission
$object = Get-AzureADMSApplication -ObjectId $app.ObjectId
$resourceAccess = New-Object Microsoft.Open.AzureAD.Model.ResourceAccess
$resourceAccess.Type = "Scope"
$resourceAccess.Id = $object.Api.Oauth2PermissionScopes[0].Id

#Add required delegated permission
$requiredGraphAccess.ResourceAccess.Add($resourceAccess)
$requiredResourcesAccess.Add($requiredGraphAccess)

# adding required resource access to application
Write-Verbose "Setting permissions (User.Read & access_as_user)"
Set-AzureADApplication -ObjectId $app.ObjectId -RequiredResourceAccess $requiredResourcesAccess
Write-Host "Application permissions (User.Read & access_as_user) have been successfully applied" -ForegroundColor Green

# creating single page application
Write-Verbose "Creating Single Page Application (enables SSO)"
$redirectUris = @($URL)
$accesstoken = (Get-AzAccessToken -Resource "https://graph.microsoft.com/").Token
$header = @{
    'Content-Type' = 'application/json'
    'Authorization' = 'Bearer ' + $accesstoken
}
$body = @{
    'spa' = @{
        'redirectUris' = $redirectUris
    }
} | ConvertTo-Json
Invoke-RestMethod -Method Patch -Uri "https://graph.microsoft.com/v1.0/applications/$($app.ObjectId)" -Headers $header -Body $body
Write-Host "Single Page Application has been created and assigned the following redirect URL: $URL" -ForegroundColor Green

# adding application identifier
Write-Verbose "Adding application identifier: api://$($app.AppId)"
Set-AzureADMSApplication -ObjectId $object.Id -IdentifierUris "api://$($app.AppId)"

##### Create Enterprise Application
Write-Verbose "Creating Enterprise Application"
$servicePrincipal = New-AzureADServicePrincipal -AppId $app.AppId -Tags @("WindowsAzureActiveDirectoryIntegratedApp")
Write-Host "Enterprise Application ($($servicePrincipal.AppId)) successfully created" -ForegroundColor Green

##### ONLY REQUIRED IF SERVICE PROVIDER WANTS TO USE RESTORE PORTAL FOR THEIR OWN MICROSOFT 365 ENVIRONMENT
# granting admin consent
Write-Verbose "Granting admin consent to the Enterprise Application"
$token = [Microsoft.Azure.Commands.Common.Authentication.AzureSession]::Instance.AuthenticationFactory.Authenticate($context.Account, $context.Environment, $context.Tenant.TenantId, $null, "Never", $null, "74658136-14ec-4630-ad9b-26e160ff0fc6")
$headers = @{
  'Authorization' = 'Bearer ' + $token.AccessToken
  'X-Requested-With'= 'XMLHttpRequest'
  'x-ms-client-request-id'= New-Guid
  'x-ms-correlation-id' = New-Guid
}
$url = "https://main.iam.ad.ext.azure.com/api/RegisteredApplications/$($app.AppId)/Consent?onBehalfOfAll=true"

# loop waiting for change to actually take place
while ($true){
  try {
    Invoke-RestMethod -Uri $url -Headers $headers -Method POST -ErrorAction Stop | Out-Null
    break
  } catch {
    Write-Host "Waiting to grant admin consent... (this can take up to 15 minutes)" 
    Write-Verbose "Error: $_"
    Start-Sleep -Seconds 5
  }
}
Write-Host "$($servicePrincipal.DisplayName) ($($servicePrincipal.AppId)) has been granted admin consent" -ForegroundColor Green
##### END REGION

Write-Host "Use the following information when configuring the Restore Portal:`n" -ForegroundColor Green
Write-Host "Application ID: $($servicePrincipal.AppId)" -ForegroundColor Green
Write-Host "Cert Thumbprint: $($cert.Thumbprint)" -ForegroundColor Green
Write-Host "Cert Friendly Name: $Name" -ForegroundColor Green

# logging out of remote sessions
Write-Verbose "Logging out of Azure AD account"
Disconnect-AzureAD | Out-Null
Write-Verbose "Logging out of Microsoft Azure account"
Disconnect-AzAccount | Out-Null
