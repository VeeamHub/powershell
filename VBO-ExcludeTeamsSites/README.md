## VeeamHub
Veeamhub projects are community driven projects, and are not created by Veeam R&D nor validated by Veeam Q&A. They are maintained by community members which might be or not be Veeam employees.

## Project Notes
Author: David Bewernick (Veeam Software)
Function: Script to exclude the SharePoint Sites related to MS Teams in backup jobs

ATTENTION: 
	A job to protect MS Teams does not backup the complete SharePoint Site related to this Team.
	So be aware that you might not protect data that has been added or changed outsite of a Team!

Requires: Veeam Backup for Microsoft Office 365 v5

## Usage

Modify these values to fit to your needs:
$LogFile = "C:\scripts\logs\VBO-excludeTeamsSites.log"
$OrgName = "YOURORGNAME"
$SPjobName = "YOURJOB"

To enable (1) or disable (0) logging modify the $LogEnable variable

## 🤝🏾 License
Copyright (c) 2021 VeeamHub

- [MIT License](LICENSE)
