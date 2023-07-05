## VeeamHub

Veeamhub projects are community driven projects, and are not created by Veeam R&D nor validated by Veeam Q&A. They are maintained by community members which might be or not be Veeam employees.

## Author

Wouter Oltlammers, Marc Molleman & Rico Wezenberg (Veeam Software)

## Function

Script to use for automatically and dynamically adding specific Mailbox Recipient types like SharedMailbox, EquipmentMailbox, RoomMailboxes to a VBO backup job. 

## Description

 With this script, these RecipientType details are pulled from M365, stored in a temp file, and then compared to your VB365 job:
If not added yet to the job, this script will automatically add the UPN to the job.
If already added to the job, this script will filter out those accounts already added.
If a specific Mailbox may not be added to the job, write this UPN in the Filter file created by this script. With each run, the script will compare the newly found mailboxes against the filter list and exclude all that matches the filter.

## Known Issues

* *No known issues*

## Requirements

* Veeam Backup for Microsoft 365 v7
  * *Other versions are untested*
* ExchangeOnlineManagement 3.1.0 PowerShell module
  * *Other versions are untested*

## Usage
During the first run of this script, the script will automatically create a folder structure in which the temp-output file, log files, filter files, and credential files are stored. Please feel free to adjust those folders and file names to your own needs.

Second, during the first interactive run of the script, the script will ask for the M365 credentials to be used for pulling the information from M365. It's recommended that you use an MFA-Enabled service account with a preconfigured App password to securely login to M365. See the following link to create an App password for an MFA-Enabled service account: http://vee.am/App-Password.
 
The credentials used to connect to your M365 tenant will be stored encrypted in a <user>.txt file. If you want to change the credentials used, just delete the credentials file and run the script interactively again to add the new credentials to be used.

This script will automatically create audit logs in which you can found which account is added on which run and which accounts are skipped due to the filter match. 

To use the filter just add the upn of the user or mailbox you want to exclude on a row by row bases.

Full list of tested RecipientType values:
EquipmentMailbox,GroupMailbox,RoomMailbox,SharedMailbox,TeamMailbox,UserMailbox

You can specify multiple values separated by commas in the script.

##Changelog:

Changes 04-07-2023 (v2.0)
Updated code to use the new 3.1.0 PowerShell modules
Some arguments are moved to the command line instead of hardcoded in the script
Updated authentication mechanism and credential storage location
Added the option to run the script from a different server
Cleaned up input fields and information in the script.

Changes 18-08-2020 (v1.2)
Tested with MFA-Enabled service account with App password, changed login information in the script.
Cleaned up input fields with default names.
Rearranged input fields to the beginning of the script
Updated documentation to use this script with an MFA-Enabled service account.

Changes 13-08-2020 (v1.1)
Cleaned up input fields and information in the script.

Changes 13-08-2020 (v1.0)
Initial commit.

## Distributed under MIT license
Copyright (c) 2023 VeeamHub
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
