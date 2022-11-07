# Teams Protected API Check

## Author

* Chris Arceneaux (@chris_arceneaux)
* Fabian Kessler

## Function

This script leverages Veeam Backup for 365 (VB365) cmdlets and Microsoft Azure AD / Graph API cmdlets to validate whether access is present for the Microsoft Teams Protected API referenced in the [KB article](https://www.veeam.com/kb4322).

More information on why this script is beneficial can be found [here](https://community.veeam.com/script-library-67/verify-access-to-the-protected-teams-api-2931).

## Known Issues

* _Currently no known issues_

## Requirements

When executing this script without parameters:

`Ex: Get-ProtectedAPIStatus.ps1`

* Veeam Backup for Microsoft 365 v6a
* The application certificate **must** be installed on the server
  * _This is most likely already the case._
* The following PowerShell modules are required (and will be installed automagically if they are not present):
  * [Azure AD](https://www.powershellgallery.com/packages/AzureAD)
  * [Microsoft.Graph](https://www.powershellgallery.com/packages/Microsoft.Graph)

When executing this script with parameters:

`Ex: Get-ProtectedAPIStatus.ps1 -TenantId "46c4fd38-f62b-4ff6-ac91-d1165a427804" -AppId "19ea5b98-ec35-4a4d-c6f9-9690403c6948" -CertThumbprint "60F50AEB325B119BB63929D0C430AAB223938ABF"`


* The application certificate **must** be installed on the server
* The following PowerShell module is required (and will be installed automagically if it is not present):
  * [Microsoft.Graph](https://www.powershellgallery.com/packages/Microsoft.Graph)

## Usage

Script contains built-in documentation which can be accessed using the typical PowerShell method:

```powershell
Get-Help .\Get-ProtectedAPIStatus.ps1 -Full
```
