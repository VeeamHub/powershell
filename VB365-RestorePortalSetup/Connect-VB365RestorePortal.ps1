##### Service Provider Configuration Area  #####
# Modify the variable below to match your Enterprise Application ID
$applicationId = "<change-me>"
##### Warning: Do not edit the lines below #####

function Connect-VB365RestorePortal {
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
	Connect-VB365RestorePortal -ApplicationId 58a0f8e1-97bd-4804-ba69-bde1db293223

	Description
	-----------
	Connects a Microsoft 365 environment to the specified (Enterprise Application) Application ID

.EXAMPLE
	Connect-VB365RestorePortal -ApplicationId 58a0f8e1-97bd-4804-ba69-bde1db293223 -Verbose

	Description
	-----------
	Verbose output is supported

.NOTES
	NAME:  Connect-VB365RestorePortal
	VERSION: 1.2
	AUTHOR: Chris Arceneaux
	TWITTER: @chris_arceneaux
	GITHUB: https://github.com/carceneaux

.LINK
  https://helpcenter.veeam.com/docs/vbo365/guide/ssp_configuration.html#on-tenant-side

.LINK
  https://helpcenter.veeam.com/docs/vbo365/guide/ssp_ad_application_permissions.html

.LINK
	https://learn.microsoft.com/en-us/powershell/module/microsoft.graph.identity.signins/new-mgoauth2permissiongrant?view=graph-powershell-1.0

#>

  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$ApplicationId
  )

  # connecting to all things Microsoft
  try {
    Write-Verbose "Connecting to Microsoft Graph API"
    Connect-MgGraph -Scopes "Application.ReadWrite.All", "Directory.ReadWrite.All" -NoWelcome
  }
  catch {
    Write-Error "An issue occurred while logging into Microsoft. Please double-check your credentials and ensure you have sufficient permissions (Global Administrator OR Application Administrator)."
    throw $_
  }

  # check if Enterprise Application already exists
  $sp = Get-MgServicePrincipal -Filter "appId eq '$ApplicationId'"
  if ($sp) {
    Write-Verbose "Enterprise Application ($ApplicationId) is already linked to your Entra ID tenant"
  }
  else {
    # creating link to Service Provider Enterprise Application
    try {
      Write-Verbose "Creating new Azure AD Service Principal"
      $sp = New-MgServicePrincipal -AppId $ApplicationId -ErrorAction Stop
      Write-Host "$($sp.DisplayName) ($($sp.AppId)) has been linked your account" -ForegroundColor Green
    }
    catch {
      Write-Error "An unexpected error occurred while linking the Enterprise Application to your account."
      throw $_
    }
  }

  try {
    # Do grants already exist?
    $grants = Get-MgOauth2PermissionGrant -Filter "clientId eq '$($sp.Id)'"

    if ($grants.count -ne 2) {
      # Retrieving Microsoft Graph Service Principal
      $graphSp = Get-MgServicePrincipal -Filter "appId eq '00000003-0000-0000-c000-000000000000'"

      # granting admin consent to the Service Provider Enterprise Application
      # see LINK for reference documentation
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

      Write-Host "$($sp.DisplayName) ($($sp.AppId)) has been granted admin consent" -ForegroundColor Green
      Write-Host "You can now login to the Service Provider's VB365 Restore Portal!" -ForegroundColor Green
      Write-Warning "If you receive an error, wait 15 minutes and attempt login again."
    }
    else {
      Write-Host "$($sp.DisplayName) ($($sp.AppId)) is already present and trusted. Nothing else to do here..." -ForegroundColor Green
      Write-Host "You can now login to the Service Provider's VB365 Restore Portal!" -ForegroundColor Green
    }
  }
  catch {
    throw "An unexpected error occurred while granting admin consent to the Enterprise Application." + $_
  }

  # logging out of remote sessions
  Write-Verbose "Logging out of Microsoft Graph API"
  Disconnect-MgGraph | Out-Null
}

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

Connect-VB365RestorePortal -ApplicationId $applicationId
#Connect-VB365RestorePortal -ApplicationId $applicationId -Verbose
