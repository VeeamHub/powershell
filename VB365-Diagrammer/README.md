# Diagram the implemented component of Veeam Backup for Microsoft 365 infrastructure

## Author

Jonathan Colon (@rebelinux)

## Function

Get-VB365Diagram is a powershell script use to automatically generate Veeam Backup for Microsoft 365 topology diagram. The script use PSgraph to generate a DOT (Graphviz) type code that can be exported to PNG,PDF,SVG,Base64 format.


***NOTE:*** Before executing this script in a production environment, I strongly recommend you:

* Fully understand what the script is doing
* Test the script in a lab environment

## Known Issues

* *No known issues*

## Requirements

* Veeam Backup for Microsoft 365 powershell modules (Veeam.Archiver.PowerShell)
  * v6 or newer
* Diagrammer.Core module v0.1.9 or newer (Install-Module -Name Diagrammer.Core)
* Windows account with Administrator access to the Veeam VB365 console

## Usage

Script contains built-in documentation which can be accessed using the typical PowerShell method:

```powershell
Import-Module .\Get-VB365Diagram.ps1 -Force
Get-Help Get-VB365Diagram -Full
```

Script is designed to be interactive. As such, no parameters are required during execution:

```powershell
Import-Module .\Get-VB365Diagram.ps1 -Force
Get-VB365Diagram -Target veeam-vb365.domain.local -Username 'domain\username' -Password password -Format png -OutputFolderPath C:\Users\god\ -Filename Out.png 
```
