# Upgrade Outdated Veeam Backup for Microsoft 365 Repositories

## Author

Chris Arceneaux (@chris_arceneaux)

## Function

This script retrieves all backup repositories configured in Veeam Backup for Microsoft 365, filters those marked as outdated, and upgrades each one sequentially. A timestamped log file is written to the same directory as the script detailing upgrade results.

If an upgrade fails, the script stops immediately and the failure — including the error message received — is recorded in the log file.

## Known Issues

* *None*

## Requirements

* Veeam Backup for Microsoft 365 8+
* Script must be executed on the Veeam Backup for Microsoft 365 server

#### Usage

`Get-Help .\Start-RepositoryUpgrades.ps1 -Full`
