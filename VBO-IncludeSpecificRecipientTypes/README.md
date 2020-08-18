## VeeamHub

Veeamhub projects are community driven projects, and are not created by Veeam R&D nor validated by Veeam Q&A. They are maintained by community members which might be or not be Veeam employees.

## Project Notes
Author: Wouter Oltlammers & Rico Wezenberg (Veeam Software)

Function: Script to use for automatically and dynamically adding specific Mailbox Recipient types like SharedMailbox, EquipmentMailbox, RoomMailboxes to a VBO backup job. 

Description: With this script, these RecipientType details are pulled from O365, stored in a temp file, and then compared to your VBO job:
If not added yet to the job, this script will automatically add the UPN to the job.
If already added to the job, this script will filter out those accounts already added.
If a specific Mailbox may not be added to the job, write this UPN in the Filter file created by this script. With each run, the script will compare the newly found mailboxes against the filter list and exclude all that matches the filter.

During the first run of this script, the script will automatically create a folder structure in which the temp-output file, log files, filter files, and credential files are stored. Please feel free to adjust those folders and file names to your own needs.

Second, during the first interactive run of the script, the script will ask for the O365 credentials to be used for pulling the information from O365. It's recommended that you use an MFA-Enabled service account with a preconfigured App password to securely login to O365. See the following link to create an App password for an MFA-Enabled service account: http://vee.am/App-Password.
 
The credentials used during this first run will be stored encrypted in the cred.xml file stored in the Cred folder and will be used each run (interactive or scheduled). If you want to change the credentials used, just delete the credentials file and run the script interactively again to add the new credentials to be used.

This script will automatically create audit logs in which you can found which account is added on which run and which accounts are skipped due to the filter match. 

To use the filter just add the upn of the user or mailbox you want to exclude on a row by row bases.

Full list of tested RecipientType values:
EquipmentMailbox,GroupMailbox,RoomMailbox,SharedMailbox,TeamMailbox,UserMailbox

You can specify multiple values separated by commas in the script.

Requires: Veeam Backup for Microsoft Office 365 and ExchangeOnlineManagement 1.0.1 PowerShell modules.

##Changelog:

Changes 18-08-2020 (v1.2)
Tested with MFA-Enabled service account with App password, changed login information in the script.
Cleaned up input fields with default names.
Rearranged input fields to beginning of script
Updated documentation to use this script with MFA-Enabled service account.

Changes 13-08-2020 (v1.1)
Cleaned up input fields and information in the script.

Changes 13-08-2020 (v1.0)
Initial commit.

## Distributed under MIT license
Copyright (c) 2020 VeeamHub
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
