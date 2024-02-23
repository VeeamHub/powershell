# Create a catch-all-the-rest job for SharePoint and Teams

## Version:
1.0

## Author

* David Bewernick (@d-works42)

## Function

This script reads all the SharePoint sites and Teams present in any backup job for the defined organization. 
It then creates or updates a SharePoint and Teams backup job for the Organization and adds all the previously found objects as exclusions.
The idea is to run this script only once and have a dynamic job that captures all new SharePoint Sites and Teams. If changes to other jobs have been made (adding or revoming objects to backup), this here can be run again to re-populate the exclusion list with an up-to-date staus.

## Requirements

* Veeam Backup for Microsoft 365 v7
  * *Other versions are untested*

## Usage

Adjust the variables within the script before running it.