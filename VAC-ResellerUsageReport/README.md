# Veeam Availability Console (VAC) Reseller Usage Report

## Authors

Chris Arceneaux (@chris_arceneaux)
Tim Hudson (@vL0bster)

## Function

This script will return VAC point in time reseller usage.

## Known Issues

* While editions (Standard, Enterprise, Enterprise Plus) are captured, Veeam ONE is not.
* Cloud Connect Replication usage/quota is not retrieved

## Requirements

* Veeam Availability Console 3.x
  * Portal Administrator account used to access the REST API.
* Network connectivity
  * The server executing the script needs to be able to access REST API for VAC

***NOTE:***

* In order to get usage numbers as accurate as possible, the script should be scheduled to run on the last day of the month sometime before midnight.
* For usage report numbers to be accurate and holistic, **all** Veeam Backup & Replication (VBR) servers must be managed by VAC. More information on allowing VAC to manage VBR servers can be found in the [Veeam Availablility Console Documentation](https://helpcenter.veeam.com/docs/vac/provider_user/connect_backup_servers.html). If multiple VAC instances are used, then this script must be run against all VAC intances with the usage report numbers totalled.

## Usage

Get-Help .\vac-resellerusage.ps1 -Full