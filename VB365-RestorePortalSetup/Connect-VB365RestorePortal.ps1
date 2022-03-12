<#
.SYNOPSIS
	Enables a Microsoft 365 environment to use a Service Provider's Restore Portal.

.DESCRIPTION
  The script logs in to a tenant Microsoft 365 environment and grants the required permissions so the tenant can leverage a service provider's Veeam Backup for Microsoft 365 Restore Portal.
	
.PARAMETER ApplicationId
	Service Provider (Enterprise Application) Application ID. THIS IS PROVIDED BY YOUR SERVICE PROVIDER.

.OUTPUTS
	Connect-VB365RestorePortal returns string output to guide the user

.EXAMPLE
	Connect-VB365RestorePortal.ps1 -ApplicationId 58a0f8e1-97bd-4804-ba69-bde1db293223

	Description
	-----------
	Connects a Microsoft 365 environment to the specified (Enterprise Application) Application ID

.EXAMPLE
	Connect-VB365RestorePortal.ps1 -ApplicationId 58a0f8e1-97bd-4804-ba69-bde1db293223 -Verbose

	Description
	-----------
	Verbose output is supported

.NOTES
	NAME:  Connect-VB365RestorePortal.ps1
	VERSION: 1.0
	AUTHOR: Chris Arceneaux
	TWITTER: @chris_arceneaux
	GITHUB: https://github.com/carceneaux

.LINK
  https://helpcenter.veeam.com/docs/vbo365/guide/ssp_configuration.html

.LINK
  https://helpcenter.veeam.com/docs/vbo365/guide/ssp_ad_application_permissions.html

.LINK
  https://docs.microsoft.com/en-us/powershell/module/azuread/new-azureadserviceprincipal

.LINK
  https://f12.hu/2021/01/13/grant-admin-consent-to-an-azuread-application-via-powershell/

.LINK
	https://arsano.ninja/

#>
#Requires -Modules Az.Accounts, AzureAd

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


# creating link to Service Provider Enterprise Application
try {
  Write-Verbose "Creating new Azure AD Service Principal"
  $sp = New-AzureADServicePrincipal -AppId $ApplicationId -ErrorAction Stop
  Write-Host "$($sp.DisplayName) ($($sp.AppId)) has been linked your account" -ForegroundColor Green
} catch {
  Write-Error "An unexpected error occurred while linking the Enterprise Application to your account."
  throw $_
}


# granting admin consent
$token = [Microsoft.Azure.Commands.Common.Authentication.AzureSession]::Instance.AuthenticationFactory.Authenticate($context.Account, $context.Environment, $context.Tenant.TenantId, $null, "Never", $null, "74658136-14ec-4630-ad9b-26e160ff0fc6")
$headers = @{
  'Authorization' = 'Bearer ' + $token.AccessToken
  'X-Requested-With'= 'XMLHttpRequest'
  'x-ms-client-request-id'= [guid]::NewGuid()
  'x-ms-correlation-id' = [guid]::NewGuid()
}
$url = "https://main.iam.ad.ext.azure.com/api/RegisteredApplications/$($sp.AppId)/Consent?onBehalfOfAll=true"
Write-Verbose "Granting admin consent to the newly linked Azure AD Service Principal"

# loop waiting for change to actually take place
while ($true){
  try {
    Invoke-RestMethod -Uri $url -Headers $headers -Method POST -ErrorAction Stop | Out-Null
    break
  } catch {
    Write-Host "Waiting to grant admin consent... (this can take up to 15 minutes)" 
    Start-Sleep -Seconds 5
  }
}
Write-Host "$($sp.DisplayName) ($($sp.AppId)) has been granted admin consent" -ForegroundColor Green
Write-Host "You can now login to the Service Provider's VB365 Restore Portal!" -ForegroundColor Green

# logging out of remote sessions
Write-Verbose "Logging out of Azure AD account"
Disconnect-AzureAD | Out-Null
Write-Verbose "Logging out of Microsoft Azure account"
Disconnect-AzAccount | Out-Null
