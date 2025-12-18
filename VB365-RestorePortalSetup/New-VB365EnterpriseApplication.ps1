<#
.SYNOPSIS
	Creates an Enterprise Application for use with the Veeam Backup for Microsoft 365 Restore Portal.

.DESCRIPTION
  The script logs in to a Microsoft 365 environment and creates an Enterprise Application (and App Registration) with permissions that's required for the Veeam Backup for Microsoft 365 Restore Portal.

.PARAMETER Name
	Name of the Enterprise Application to be created

.PARAMETER URL
	URL to be provided to customers to access the Restore Portal

.PARAMETER GrantAdminConsent
  Flag to automatically grant admin consent to the application. Only use this if you plan on using the Restore Portal for your own Microsoft 365 environment. Otherwise, leave this parameter off and have your customers grant admin consent using the Connect-VB365RestorePortal script.

.OUTPUTS
	New-VB365EnterpriseApplication.ps1 returns string output to guide the user

.EXAMPLE
	New-VB365EnterpriseApplication.ps1 -Name "Veeam Restore Portal" -URL "https://veeam.domain:4443"

	Description
	-----------
	Creates an Enterprise Application in Azure AD with the specified name using the specified redirect URL

.EXAMPLE
  New-VB365EnterpriseApplication.ps1 -Name "Veeam Restore Portal" -URL "https://veeam.domain:4443" -GrantAdminConsent

  Description
  -----------
  Grants admin consent to the application so it can be used in the current Microsoft 365 environment

.EXAMPLE
	New-VB365EnterpriseApplication.ps1 -Name "Veeam Restore Portal" -URL "https://veeam.domain:4443" -Verbose

	Description
	-----------
	Verbose output is supported

.NOTES
	NAME:  New-VB365EnterpriseApplication.ps1
	VERSION: 1.2
	AUTHOR: Chris Arceneaux
	TWITTER: @chris_arceneaux
	GITHUB: https://github.com/carceneaux

.LINK
  https://helpcenter.veeam.com/docs/vbo365/guide/ssp_configuration.html#on-service-provider-side

.LINK
  https://helpcenter.veeam.com/docs/vbo365/guide/ssp_ad_application_permissions.html

.LINK
  https://www.powershellgallery.com/packages/Microsoft.Graph

#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$Name,
  [Parameter(Mandatory = $true)]
  [string]$URL,
  [Parameter(Mandatory = $false)]
  [switch]$GrantAdminConsent
)

# Setting default PowerShell action to halt on error
$ErrorActionPreference = "Stop"

Write-Host "Installing required PowerShell module...Microsoft.Graph"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Find-PackageProvider -Name Nuget -ForceBootstrap -IncludeDependencies -Force | Out-Null
# Determine if Microsoft.Graph module is already present
if ( -not(Get-Module -ListAvailable -Name Microsoft.Graph)) {
  Install-Module -Name Microsoft.Graph -SkipPublisherCheck -Force -ErrorAction Stop
  Write-Host "Microsoft.Graph module installed successfully" -ForegroundColor Green
}
else {
  Write-Host "Microsoft.Graph module already present" -ForegroundColor Green
}

try {
  Write-Verbose "Connecting to Microsoft Graph..."
  Connect-MgGraph -Scopes @(
    "Application.ReadWrite.All"
  ) -ErrorAction Stop | Out-Null

  Write-Host "Connected to Microsoft Graph." -ForegroundColor Green
}
catch {
  Write-Error "An issue occurred while logging into Microsoft Graph. Check credentials/permissions."
  throw
}

# -------------------------------------------------------------------
# 1) Create App Registration
# -------------------------------------------------------------------
Write-Verbose "Creating Entra ID Application ($Name)"
$app = New-MgApplication `
  -DisplayName $Name `
  -SignInAudience "AzureADMultipleOrgs" `
  -ErrorAction Stop

Write-Host "Application ($($app.AppId)) has been created" -ForegroundColor Green

Write-Verbose "Adding Identifier URI: api://$($app.AppId)"
Update-MgApplication -ApplicationId $app.Id -IdentifierUris @("api://$($app.AppId)") -ErrorAction Stop

# -------------------------------------------------------------------
# 2) Create self-signed certificate (local machine store) and add to app (KeyCredential)
# -------------------------------------------------------------------
Write-Verbose "Creating self-signed certificate to be used as a shared key for the Restore Portal"
$cn = $URL -replace "^https://", ""
$cert = New-SelfSignedCertificate `
  -Type Custom `
  -KeyExportPolicy Exportable `
  -KeyUsage None `
  -KeyAlgorithm RSA `
  -KeyLength 2048 `
  -HashAlgorithm SHA1 `
  -NotAfter (Get-Date).AddYears(10) `
  -Subject "CN=$cn" `
  -FriendlyName $Name

Write-Host "Certificate $($cert.Thumbprint) has been created and saved to the Local Machine certificate store" -ForegroundColor Green

$keyCredential = @{
  type                = "AsymmetricX509Cert"
  usage               = "Verify"
  key                 = $cert.GetRawCertData()
  customKeyIdentifier = $cert.GetCertHash()
  startDateTime       = (Get-Date).ToUniversalTime()
  endDateTime         = $cert.NotAfter.ToUniversalTime()
  displayName         = "SelfSignedCert-$Name"
}

Update-MgApplication `
  -ApplicationId $app.Id `
  -KeyCredentials @($keyCredential) `
  -ErrorAction Stop

Write-Verbose "Certificate has been added to the Application"

# -------------------------------------------------------------------
# 3) Create/Update custom permission scope "access_as_user" + disable implicit grant
# -------------------------------------------------------------------
$permissionScope = @{
  id                      = [Guid]::NewGuid()
  value                   = "access_as_user"
  type                    = "Admin"
  isEnabled               = $true
  userConsentDisplayName  = "Access Veeam Backup for Microsoft 365 Restore Portal"
  userConsentDescription  = "Allows access to Veeam Backup for Microsoft 365 Restore Portal on your behalf"
  adminConsentDisplayName = "Access Veeam Backup for Microsoft 365 Restore Portal"
  adminConsentDescription = "Allows access to Veeam Backup for Microsoft 365 Restore Portal as the signed-in user"
}
$scopes = @($permissionScope)

$api = $app.Api
$api.Oauth2PermissionScopes = $scopes

Write-Verbose "Disabling default web application configuration (implicit grant)"
$web = $app.Web
$web.ImplicitGrantSettings = @{
  EnableAccessTokenIssuance = $false
  EnableIdTokenIssuance     = $false
}

Update-MgApplication `
  -ApplicationId $app.Id `
  -Api $api `
  -Web $web `
  -ErrorAction Stop

Write-Host "Application object $($app.Id) has been updated successfully with API permissions and new web application configuration" -ForegroundColor Green

# -------------------------------------------------------------------
# 4) Set RequiredResourceAccess: Graph(User.Read) + your API(access_as_user)
# -------------------------------------------------------------------
Write-Verbose "Gathering remainder of permissions (User.Read & access_as_user)"

# Microsoft Graph resource service principal
$graphSp = Get-MgServicePrincipal -Filter "appId eq '00000003-0000-0000-c000-000000000000'" -ErrorAction Stop

# Delegated scope id for Graph User.Read
$userReadScope = $graphSp.Oauth2PermissionScopes | Where-Object { $_.Value -eq "User.Read" }

# Refresh app to get scope id we just set (access_as_user)
$api = (Get-MgApplication -ApplicationId $app.Id -Property "api" -ErrorAction Stop).Api
$accessAsUserScopeId = $api.Oauth2PermissionScopes[0].Id

$requiredResourcesAccess = @(
  # Microsoft Graph -> User.Read (delegated)
  @{
    ResourceAppId  = $graphSp.AppId
    ResourceAccess = @(
      @{
        Id   = $userReadScope.Id
        Type = "Scope"
      }
    )
  },

  # This API -> access_as_user (delegated)
  @{
    ResourceAppId  = $app.AppId
    ResourceAccess = @(
      @{
        Id   = $accessAsUserScopeId
        Type = "Scope"
      }
    )
  }
)

Write-Verbose "Setting permissions (User.Read & access_as_user)"
Update-MgApplication `
  -ApplicationId $app.Id `
  -RequiredResourceAccess $requiredResourcesAccess `
  -ErrorAction Stop

Write-Host "Application permissions (User.Read & access_as_user) have been successfully applied" -ForegroundColor Green

# -------------------------------------------------------------------
# 5) Create Enterprise Application (Service Principal)
# -------------------------------------------------------------------
Write-Verbose "Creating Enterprise Application (Service Principal)"
$sp = New-MgServicePrincipal -AppId $app.AppId -Tags @("WindowsAzureActiveDirectoryIntegratedApp") -ErrorAction Stop
Write-Host "Enterprise Application ($($sp.AppId)) successfully created" -ForegroundColor Green

# -------------------------------------------------------------------
# 6) Configure SPA redirect URIs
# -------------------------------------------------------------------
Write-Verbose "Creating Single Page Application (enables SSO) and setting redirect URI: $URL"
Update-MgApplication `
  -ApplicationId $app.Id `
  -BodyParameter @{
  spa = @{
    redirectUris = @($URL)
  }
} `
  -ErrorAction Stop

Write-Host "Single Page Application has been created and assigned the following redirect URL: $URL" -ForegroundColor Green

# -------------------------------------------------------------------
# 7) Grant Admin Consent (optional)
# -------------------------------------------------------------------
if ($GrantAdminConsent) {
  Write-Verbose "Granting admin consent to the Enterprise Application ($($sp.AppId))"
  New-MgOauth2PermissionGrant `
    -ClientId $sp.Id `
    -ConsentType "AllPrincipals" `
    -ResourceId $graphSp.Id `
    -Scope "User.Read" `
    -ErrorAction Stop | Out-Null
  New-MgOauth2PermissionGrant `
    -ClientId $sp.Id `
    -ConsentType "AllPrincipals" `
    -ResourceId $sp.Id `
    -Scope "access_as_user" `
    -ErrorAction Stop | Out-Null
  Write-Host "Admin consent has been granted to the Enterprise Application ($($sp.AppId))" -ForegroundColor Green
}

# -------------------------------------------------------------------
# Final Output and Cleanup
# -------------------------------------------------------------------

Write-Host "Use the following information when configuring the Restore Portal:`n" -ForegroundColor Green
Write-Host "Application ID: $($sp.AppId)" -ForegroundColor Green
Write-Host "Cert Thumbprint: $($cert.Thumbprint)" -ForegroundColor Green
Write-Host "Cert Friendly Name: $Name" -ForegroundColor Green
Write-Host "Portal URI: $URL`n" -ForegroundColor Green

# logging out of remote sessions
Write-Verbose "Logging out of Microsoft Graph API"
Disconnect-MgGraph | Out-Null
