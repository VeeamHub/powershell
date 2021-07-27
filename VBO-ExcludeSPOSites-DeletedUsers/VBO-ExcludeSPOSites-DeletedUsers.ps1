<#

.SYNOPSIS
----------------------------------------------------------------------
VBO-ExcludeSPOSites-DeletedUsers.ps1
----------------------------------------------------------------------
Version : 0.9 (July 27th, 2021)
Requires: Veeam Backup for Office 365 v4 or later
Author  : Danilo Chiavari (@danilochiavari)
Blog    : https://www.danilochiavari.com
GitHub  : https://www.github.com/dchiavari
.DESCRIPTION
*** Please note this script is unofficial and is not created nor supported by Veeam Software. ***
This script automatically excludes from backup Sharepoint Online personal sites belonging to non-existing (deleted) users.
For help or comments, contact the author on Twitter (@danilochiavari) or via e-mail (danilo.chiavari -at- gmail (.) com)
This script has been tested with the following versions of Veeam Backup for Office 365:
   - v5.0.1.225

Notes:
   - You will be asked to enter a credential. That credential will be used to connect to Azure AD and Sharepoint Online
   - Organization / Office 365 Tenant and Sharepoint Online Admin URL are automatically obtained based on the supplied credential
.PARAMETER Job
(optional) The backup job where exclusions will be created. If not specified (or the provided one does not exist) the script will let you pick from a list of existing jobs for the selected Organization
.PARAMETER MFA
(optional) When set to $True, allows use of a MFA-secured user account when logging in. If not specified, a standard (non-MFA) user account is assumed (Thanks to user @kosli for implementing and testing MFA, plus fixing an issue with obtaining admin URLs)
.EXAMPLE
PS> .\VBO-ExcludeSPOSites-DeletedUsers.ps1 -Job MyBackupJob

#>

Param (
   [string]$Job,
   [Switch]$MFA
)

if (-not $MFA) {
    # Get credential and use it to connect to Azure AD and Sharepoint Online
    $Cred = Get-Credential
}

# Connect to VBO365 Server (localhost)
Write-Host -ForegroundColor Yellow Connecting to Veeam Backup for Office 365...
Connect-VBOServer

Write-Host -ForegroundColor Yellow Connecting to Azure AD...
if ($MFA) {
    Connect-AzureAD >$null 2>&1
} else{
    Connect-AzureAD -Credential $cred >$null 2>&1
}

# Get Microsoft 365 tenant name based on the used credential (taking the first object in the VerifiedDomains array)
$Tenant = (Get-AzureADTenantDetail).VerifiedDomains[0].Name

# Get VBO365 Organization object based on the Microsoft 365 tenant name
$BackupOrg = Get-VBOOrganization | ? {$_.OfficeName -eq $Tenant}
if (-not $BackupOrg) {
    Write-Host -ForegroundColor Red "ERROR: the Organization you have logged on to was **NOT** found in Veeam Backup for Office 365 configuration. Exiting..."
    Disconnect-VBOServer
    Disconnect-AzureAD
    Exit(1)
}

# Initialize BackupJob variable
$BackupJob = $null

# Check if no jobs exist in VBO365 for the selected Organization - if that's the case, exit with an error
if (-not $(Get-VBOJob -Organization $BackupOrg)) {
    Write-Host -ForegroundColor Red "ERROR: NO jobs were found in Veeam Backup for Office 365 for the Organization you have logged on to. Exiting..."
    Disconnect-VBOServer
    Disconnect-AzureAD
    Exit(1)
}
# If a job name was not specified (or if the job does not exist) let the user pick a job interactively    
if ($Job) {$BackupJob = Get-VBOJob -Name $Job}
if (-not $BackupJob) {$BackupJob = Get-VBOJob -Organization $BackupOrg | Out-GridView -OutputMode Single -Title "*** PLEASE SELECT THE SHAREPOINT ONLINE BACKUP JOB TO PROCESS EXCLUSIONS FOR ***"}
if (-not $BackupJob) {
    Write-Host -ForegroundColor Red "ERROR: NO jobs were selected, operation was cancelled. Exiting..."
    Disconnect-VBOServer
    Disconnect-AzureAD
    Exit(1)
}

# Connect to Sharepoint Online (constructing the default SPO admin URL based on tenant name)
Write-Host -ForegroundColor Yellow Connecting to Sharepoint Online...

if ($MFA) {
    Connect-SPOService -Url https://$($Tenant -replace ".onmicrosoft.com$")-admin.sharepoint.com
} else {
    Connect-SPOService -Credential $Cred -Url https://$($Tenant -replace ".onmicrosoft.com$")-admin.sharepoint.com
}

# Get Sharepoint Online Personal Sites 
$PersonalSites = Get-SPOSite -IncludePersonalSite $true -Filter "Url -like '-my.sharepoint.com/personal/'" -Limit ALL

# Initialize Exclusions array
$Exclusions = @()

# Cycle through each Personal Site
ForEach ($Site in $PersonalSites) {
    Write-Host "Processing Site:" $Site.Url
    $SiteOwner = $Site.Owner.ToString()
    #Write-Host "Site owner:" $SiteOwner
    # Check if Site's owner exists in Azure AD
    $UserCheck = Get-AzureADUser -All $True | ? {$_.UserPrincipalName -eq $SiteOwner}
    If ($UserCheck -eq $null) {
        Write-Host -ForegroundColor Yellow User $SiteOwner was **NOT** found in Azure AD - Exclusion will be applied `n
        $Exclusions += New-VBOBackupItem -Site $(Get-VBOOrganizationSite -Organization $BackupOrg -URL $Site.Url)
        }
        #else {Write-Host User $SiteOwner was correctly found in Azure AD. Site will not be excluded`n}
}

Write-Host -Foregroundcolor Green `n $Exclusions.Count "exclusions will be added to the backup job:" $BackupJob.Name `n
If ($Exclusions.Count -ne 0) {Add-VBOExcludedBackupItem -Job $BackupJob -BackupItem $Exclusions}

Disconnect-AzureAD
Disconnect-SPOService
Disconnect-VBOServer
