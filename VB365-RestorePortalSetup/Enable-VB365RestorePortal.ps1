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
    [string]$AppId,
  [Parameter(Mandatory=$true)]
    [string]$AppThumbprint,
  [Parameter(Mandatory=$false)]
    [int]$Port = 4443
)

function Get-RandomPassword {
  param (
      [Parameter(Mandatory)]
      [int] $length,
      [int] $amountOfNonAlphanumeric = 1
  )
  Add-Type -AssemblyName 'System.Web'
  return [System.Web.Security.Membership]::GeneratePassword($length, $amountOfNonAlphanumeric)
}

# setting default PowerShell action to halt on error
$ErrorActionPreference = "Stop"

# importing Veeam PowerShell modules
Import-Module "C:\Program Files\Veeam\Backup365\Veeam.Archiver.PowerShell\Veeam.Archiver.PowerShell.psd1"
Import-Module "C:\Program Files\Veeam\Backup and Replication\Explorers\Exchange\Veeam.Exchange.PowerShell\Veeam.Exchange.PowerShell.psd1"
Import-Module "C:\Program Files\Veeam\Backup and Replication\Explorers\SharePoint\Veeam.SharePoint.PowerShell\Veeam.SharePoint.PowerShell.psd1"
Import-Module "C:\Program Files\Veeam\Backup and Replication\Explorers\Teams\Veeam.Teams.PowerShell\Veeam.Teams.PowerShell.psd1"

# determine if connected to Veeam
try {
  if (Get-VBORestAPISettings) {
    Write-Host "Connected to Veeam Backup for Microsoft 365" -ForegroundColor Green
  }
} catch {
  Write-Error "An error was encountered when accessing Veeam. Please ensure you have sufficient access."
  throw $_
}

# initializing variables
$server = [System.Net.Dns]::GetHostByName($env:computerName).HostName
$folder = $PSScriptRoot

# performing REST API configuration
try {
  # creating self-signed certificate for REST API
  Write-Verbose "Creating self-signed certificate for the REST API"
  $cert = New-SelfSignedCertificate -Type Custom -KeyExportPolicy Exportable -KeyUsage None -KeyAlgorithm RSA -KeyLength 2048 -HashAlgorithm SHA256 -NotAfter (Get-Date).AddYears(10) -Subject "CN=$server" -FriendlyName "VB365 REST API"
  Write-Verbose "Certificate $($cert.Thumbprint) has been created and saved to the Local Machine certificate store"

  # exporting certificate so it can be used for REST API configuration
  Write-Verbose "Exporting newly created certificate ($($cert.Thumbprint))"
  $securestring = ConvertTo-SecureString -String "$(Get-RandomPassword 50)" -Force -AsPlainText
  Export-PfxCertificate -Cert $cert -FilePath "$folder\temp.pfx" -Password $securestring | Out-Null

  # enabling the REST API
  Write-Verbose "Enabling the VB365 RESTful API"
  Set-VBORestAPISettings -EnableService -CertificateFilePath "$folder\temp.pfx" -CertificatePassword $securestring -HTTPSPort $Port | Out-Null
  Write-Host "VB365 RESTful API has been enabled successfully" -ForegroundColor Green

  # deleting exported certificate
  Remove-Item "$folder\temp.pfx" -Force
} catch {
  Write-Error "An unexpected error occurred while configuring the VB365 RESTful API."
  throw $_
}

# performing Operator Authentication configuration
try {
  # creating self-signed certificate for Operator Authentication
  Write-Verbose "Creating self-signed certificate for Operator Authentication"
  $cert = New-SelfSignedCertificate -Type Custom -KeyExportPolicy Exportable -KeyUsage None -KeyAlgorithm RSA -KeyLength 2048 -HashAlgorithm SHA256 -NotAfter (Get-Date).AddYears(10) -Subject "CN=$server" -FriendlyName "VB365 Operator Authentication"
  Write-Verbose "Certificate $($cert.Thumbprint) has been created and saved to the Local Machine certificate store"

  # exporting certificate so it can be used for Operator Authentication configuration
  Write-Verbose "Exporting newly created certificate ($($cert.Thumbprint))"
  $securestring = ConvertTo-SecureString -String "$(Get-RandomPassword 50)" -Force -AsPlainText
  Export-PfxCertificate -Cert $cert -FilePath "$folder\temp.pfx" -Password $securestring | Out-Null

  # enabling Operator Authentication
  Write-Verbose "Enabling VB365 Operator Authentication"
  Set-VBOOperatorAuthenticationSettings -EnableAuthentication -CertificateFilePath "$folder\temp.pfx" -CertificatePassword $securestring | Out-Null
  Write-Host "VB365 Operator Authentication has been enabled successfully" -ForegroundColor Green

  # deleting exported certificate
  Remove-Item "$folder\temp.pfx" -Force
} catch {
  Write-Error "An unexpected error occurred while configuring Operator Authentication."
  throw $_
}

# performing Tenant Authentication configuration
try {
  # creating self-signed certificate for Tenant Authentication
  Write-Verbose "Creating self-signed certificate for Tenant Authentication"
  $cert = New-SelfSignedCertificate -Type Custom -KeyExportPolicy Exportable -KeyUsage None -KeyAlgorithm RSA -KeyLength 2048 -HashAlgorithm SHA256 -NotAfter (Get-Date).AddYears(10) -Subject "CN=$server" -FriendlyName "VB365 Tenant Authentication"
  Write-Verbose "Certificate $($cert.Thumbprint) has been created and saved to the Local Machine certificate store"

  # exporting certificate so it can be used for Tenant Authentication configuration
  Write-Verbose "Exporting newly created certificate ($($cert.Thumbprint))"
  $securestring = ConvertTo-SecureString -String "$(Get-RandomPassword 50)" -Force -AsPlainText
  Export-PfxCertificate -Cert $cert -FilePath "$folder\temp.pfx" -Password $securestring | Out-Null

  # enabling Tenant Authentication
  Write-Verbose "Enabling VB365 Tenant Authentication"
  Set-VBOTenantAuthenticationSettings -EnableAuthentication -CertificateFilePath "$folder\temp.pfx" -CertificatePassword $securestring | Out-Null
  Write-Host "VB365 Tenant Authentication has been enabled successfully" -ForegroundColor Green

  # deleting exported certificate
  Remove-Item "$folder\temp.pfx" -Force
} catch {
  Write-Error "An unexpected error occurred while configuring Tenant Authentication."
  throw $_
}

# performing Restore Portal configuration
try {
  # exporting certificate so it can be used for Restore Portal configuration
  Write-Verbose "Exporting Enterprise Application certificate ($($cert.Thumbprint))"
  $cert = Get-ChildItem -Path cert:\localMachine\my | Where-Object {$_.Thumbprint -eq $AppThumbprint}
  $securestring = ConvertTo-SecureString -String "$(Get-RandomPassword 50)" -Force -AsPlainText
  Export-PfxCertificate -Cert $cert -FilePath "$folder\temp.pfx" -Password $securestring | Out-Null

  # enabling Restore Portal
  Write-Verbose "Enabling the VB365 Restore Portal"
  Set-VBORestorePortalSettings -EnableService -ApplicationId $AppId -CertificateFilePath "$folder\temp.pfx" -CertificatePassword $securestring | Out-Null
  Write-Host "VB365 Restore Portal has been enabled successfully" -ForegroundColor Green

  # deleting exported certificate
  Remove-Item "$folder\temp.pfx" -Force
} catch {
  Write-Error "An unexpected error occurred while configuring the VB365 Restore Portal."
  throw $_
}

# logging out of Veeam session
Disconnect-VBOServer
