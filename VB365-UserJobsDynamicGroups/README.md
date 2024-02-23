# Create Dynamic Groups in Azure AD and the related backup jobs in VB365

## Version:
1.1

## Author

* David Bewernick (@d-works42)

## Function

This script creates Azure AD dynamic groups to split up the users of a whole tenant based on the first two characters of their ObjectID. 
The number of groups beeing created is depending on the array of first and second character.
Per default, this script will create 64 groups, since the first charakter will be from "0" to "f" and the second character will be grouped in 4 expression ranges.
VB365 backup jobs will be created for every dynamic group and separatly for Exchange Online and OneDrive.

## Requirements

* Veeam Backup for Microsoft 365 v7
  * *Other versions are untested*
* AzureADPreview Module and a Microsoft subscription which includes at least Azure AD Premium P1 features.
   You need to use the Microsoft AzureADPreview module since the parameter "MembershipRule" is only available in the beta of GraphAPI.
   -> Install-Module AzureADPreview -Scope CurrentUser -AllowClobber

## Usage

Adjust the variables within the script before running it.
