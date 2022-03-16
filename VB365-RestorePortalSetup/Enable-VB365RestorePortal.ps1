<#
.SYNOPSIS
	Enables a Microsoft 365 environment to use a Service Provider's Restore Portal.

.DESCRIPTION
  The script logs in to a tenant Microsoft 365 environment and grants the required permissions so the tenant can leverage a service provider's Veeam Backup for Microsoft 365 Restore Portal.
	
.PARAMETER ApplicationId
	Service Provider (Enterprise Application) Application ID. THIS IS PROVIDED BY YOUR SERVICE PROVIDER.

.OUTPUTS
	Enable-VB365RestorePortal returns string output to guide the user

.EXAMPLE
	Enable-VB365RestorePortal.ps1 -ApplicationId 37a0f8e1-97bd-4804-ba69-bde1db293273

	Description
	-----------
	Connects a Microsoft 365 environment to the specified (Enterprise Application) Application ID

.EXAMPLE
	Enable-VB365RestorePortal.ps1 -Verbose

	Description
	-----------
	Verbose output is supported

.NOTES
	NAME:  Enable-VB365RestorePortal.ps1
	VERSION: 1.0
	AUTHOR: Chris Arceneaux
	TWITTER: @chris_arceneaux
	GITHUB: https://github.com/carceneaux

.LINK
  https://helpcenter.veeam.com/docs/vbo365/guide/ssp_configuration.html

.LINK
  https://helpcenter.veeam.com/docs/vbo365/guide/ssp_ad_application_permissions.html

.LINK
  https://f12.hu/2021/01/13/grant-admin-consent-to-an-azuread-application-via-powershell/

.LINK
  https://docs.microsoft.com/en-us/powershell/module/azuread/?view=azureadps-2.0#applications
  
.LINK
	https://arsano.ninja/

#>

[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)]
    [string]$ApplicationId
)

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



#Get Service Principal of Microsoft Graph Resource API 
$graphSP =  Get-AzureADServicePrincipal -All $true | Where-Object {$_.DisplayName -eq "Microsoft Graph"}
 
#Initialize RequiredResourceAccess for Microsoft Graph Resource API 
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

#Add required resource accesses
$requiredResourcesAccess = New-Object System.Collections.Generic.List[Microsoft.Open.AzureAD.Model.RequiredResourceAccess]
$requiredResourcesAccess.Add($requiredGraphAccess)

# creating App registration
$app = New-AzureADApplication -DisplayName "Restore Portal Test" -AvailableToOtherTenants $true -RequiredResourceAccess $requiredResourcesAccess -PublicClient $true
#-ReplyUrls @("https://vb365.arsano.ninja")
#Set-AzureADApplication -ObjectId $app.ObjectId -IdentifierUris "api://$($app.AppId)"

# settin current user as owner
$currentUser = (Get-AzureADUser -ObjectId (Get-AzureADCurrentSessionInfo).Account.Id)
Add-AzureADApplicationOwner -ObjectId $app.ObjectId -RefObjectId $currentUser.ObjectId

# creating self-signed certificate
$cert = New-SelfSignedCertificate -Type Custom -KeyExportPolicy Exportable -KeyUsage None -KeyAlgorithm RSA -KeyLength 2048 -HashAlgorithm SHA1 -NotAfter (Get-Date).AddYears(10) -Subject "CN=vb365.arsano.ninja" -FriendlyName "VB365 Restore Portal"

# exporting PFX certificate for storage
$pwd = ConvertTo-SecureString -String "testing" -Force -AsPlainText
Export-PfxCertificate -Cert $cert -FilePath "C:\Users\chris\Documents\vb365.arsano.ninja.pfx" -Password $pwd | Out-Null

# adding certificate to application
$bin = $cert.GetRawCertData()
$base64Value = [System.Convert]::ToBase64String($bin)
$bin = $cert.GetCertHash()
$base64Thumbprint = [System.Convert]::ToBase64String($bin)
New-AzureADApplicationKeyCredential -ObjectId $app.ObjectId -CustomKeyIdentifier $base64Thumbprint -Type AsymmetricX509Cert -Usage Verify -Value $base64Value -StartDate ([System.DateTime]::Now) -EndDate $cert.GetExpirationDateString() | Out-Null

# retrieving newly created application object
$object = Get-AzureADMSApplication -ObjectId $app.ObjectId
$api = $object.Api
$scopes = New-Object System.Collections.Generic.List[Microsoft.Open.MsGraph.Model.PermissionScope]

# checking if default API scope already exists
if ($api.Oauth2PermissionScopes){
  # updating default API scope
  $permissionScope = New-Object Microsoft.Open.MsGraph.Model.PermissionScope
  $permissionScope.Id = $api.Oauth2PermissionScopes[0].Id
} else { 
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
$webApplication = New-Object Microsoft.Open.MSGraph.Model.WebApplication
$webApplication.ImplicitGrantSettings = New-Object Microsoft.Open.MSGraph.Model.ImplicitGrantSettings
$webApplication.ImplicitGrantSettings.EnableAccessTokenIssuance = $false
$webApplication.ImplicitGrantSettings.EnableIdTokenIssuance = $false

# updating application object
Set-AzureADMSApplication -ObjectId $object.Id -Api $api -IdentifierUris "api://$($app.AppId)" -Web $webApplication

# creating single page application
$redirectUris = @("https://vb365.arsano.ninja")
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

##### Create Enterprise Application
#Provide Application (client) Id
$appId=$app.AppId
#$appId="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
$servicePrincipal = New-AzureADServicePrincipal -AppId $appId -Tags @("WindowsAzureActiveDirectoryIntegratedApp")

##### ONLY REQUIRED IF SERVICE PROVIDER WANTS TO USE RESTORE PORTAL FOR THEIR OWN MICROSOFT 365 ENVIRONMENT
# granting admin consent
$token = [Microsoft.Azure.Commands.Common.Authentication.AzureSession]::Instance.AuthenticationFactory.Authenticate($context.Account, $context.Environment, $context.Tenant.TenantId, $null, "Never", $null, "74658136-14ec-4630-ad9b-26e160ff0fc6")
$headers = @{
  'Authorization' = 'Bearer ' + $token.AccessToken
  'X-Requested-With'= 'XMLHttpRequest'
  'x-ms-client-request-id'= New-Guid
  'x-ms-correlation-id' = New-Guid
}
$url = "https://main.iam.ad.ext.azure.com/api/RegisteredApplications/$($app.AppId)/Consent?onBehalfOfAll=true"


# # creating link to Service Provider Enterprise Application
# try {
#   Write-Verbose "Creating new Azure AD Service Principal"
#   $sp = New-AzureADServicePrincipal -AppId $ApplicationId -ErrorAction Stop
#   Write-Host "$($sp.DisplayName) ($($sp.AppId)) has been linked your account" -ForegroundColor Green
# } catch {
#   Write-Error "An unexpected error occurred while linking the Enterprise Application to your account."
#   throw $_
# }


# # granting admin consent
# $token = [Microsoft.Azure.Commands.Common.Authentication.AzureSession]::Instance.AuthenticationFactory.Authenticate($context.Account, $context.Environment, $context.Tenant.TenantId, $null, "Never", $null, "74658136-14ec-4630-ad9b-26e160ff0fc6")
# $headers = @{
#   'Authorization' = 'Bearer ' + $token.AccessToken
#   'X-Requested-With'= 'XMLHttpRequest'
#   'x-ms-client-request-id'= [guid]::NewGuid()
#   'x-ms-correlation-id' = [guid]::NewGuid()
# }
# $url = "https://main.iam.ad.ext.azure.com/api/RegisteredApplications/$($sp.AppId)/Consent?onBehalfOfAll=true"
# Write-Verbose "Granting admin consent to the newly linked Azure AD Service Principal"

# # loop waiting for change to actually take place
# while ($true){
#   try {
#     Invoke-RestMethod -Uri $url -Headers $headers -Method POST -ErrorAction Stop | Out-Null
#     break
#   } catch {
#     Write-Host "Waiting to grant admin consent... (this can take up to 15 minutes)" 
#     Start-Sleep -Seconds 5
#   }
# }
# Write-Host "$($sp.DisplayName) ($($sp.AppId)) has been granted admin consent" -ForegroundColor Green
# Write-Host "You can now login to the Service Provider's VB365 Restore Portal!" -ForegroundColor Green

# logging out of remote sessions
Write-Verbose "Logging out of Azure AD account"
Disconnect-AzureAD | Out-Null
Write-Verbose "Logging out of Microsoft Azure account"
Disconnect-AzAccount | Out-Null
