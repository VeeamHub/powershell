# Veeam Service Provider Console (VSPC) Company Management Scripts

## Author

Chris Arceneaux (@chris_arceneaux)

## Function

This collection of scripts serve as an example of how to automate Company and Cloud Connect Tenant creation and mapping using the Veeam Service Provider Console API.

### Get-Companies.ps1

Retrieves all Companies from VSPC.

### Get-Sites.ps1

Retrieve Cloud Connect sites information from VSPC.

### Get-Tenants.ps1

Retrieves Cloud Connect Tenants from VSPC.

### Connect-Company.ps1

This script will link an existing company to a new/existing Cloud Connect tenant. If the tenant is already mapped to another company, the script will error out.

Additional parameters can be added to the body of the POST request in order to customize new tenant settings. [See VSPC REST API documentation for more details.](https://helpcenter.veeam.com/references/vac/9.1/rest)

### New-Company.ps1

This script will create a new company and will link it to a new Cloud Connect tenant. Please note that this script only asks for required parameters to create a new company.

Additional parameters can be added to the body of the POST request in order to customize the new company and tenant settings. [See VSPC REST API documentation for more details.](https://helpcenter.veeam.com/references/vac/9.1/rest)

#### Requirements

* Veeam Service Provider Console v9.1
  * Portal Administrator account used to access the REST API
* Network connectivity
  * The machine executing the script needs to be able to access the VSPC REST API
* PowerShell 7

#### Usage

All scripts contains built-in documentation including examples!

Get-Help .\New-Company.ps1 -Full
