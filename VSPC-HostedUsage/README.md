# Veeam Service Provider Console (VSPC) Hosted Usage Scripts

## Author

Chris Arceneaux (@chris_arceneaux)

## Function

Veeam Service Provider Console v8 includes enhanced support for hosted Veeam Backup & Replication servers. Scripts located here expand on this already amazing feature! See below for a list of scripts in this collection and their function:

[Sync-VcdOrganizationMapping.ps1](#sync-vcdorganizationmappingps1)

### Sync-VcdOrganizationMapping.ps1

This script identifies VMware Cloud Director (VCD) Organizations using the specified Veeam Backup & Replication (VBR) server and then attempts to map each Organization to a Veeam Service Provider Console (VSPC) Company. Mappings are stored in a CSV file (`VcdOrganizationMapping.csv`). Organizations that cannot be mapped will be identified in the output.

Four different methods of mapping are available:

1. `cloud_connect`: VCD-backed Cloud Connect Tenants
2. `name`: Identical names (VCD Organization/VSPC Company)
3. `different_vspc`: Mapping from already existing mappings (different VSPC servers)
4. `manual`: Manual (outside of script)

Any organization mapping that cannot be completed using methods 1-3 will be listed as `INCOMPLETE` and must be mapped manually using the CSV file.

## Known Issues

* *None*

## Requirements

* Veeam Service Provider Console v8
  * Portal Administrator account used to access the REST API
* Veeam Backup & Replication v12.1
* Network connectivity
  * The server executing the script needs to be able to access the VSPC REST API and/or the VBR REST API
* PowerShell Core

## Usage

Get-Help .\Sync-VcdOrganizationMapping.ps1

![sample output](sample_sync.png)
