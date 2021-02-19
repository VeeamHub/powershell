# Enable NAS Backup from Nutanix Files SMB Snapshots
## VeeamHub
Veeamhub projects are community driven projects, and are not created by Veeam R&D nor validated by Veeam Q&A. They are maintained by community members which might be or not be Veeam employees. 

## Distributed under MIT license
Copyright (c) 2021 VeeamHub

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

###NAS Backup from Nutanix Files Snapshot

## Project Notes
**Author:** Ronn Martin (ronn.martin@veeam.com)

**Function:** Add as pre-NAS backup job script for Nutanix Files SMB backup

**Requires:** Veeam Powershell (v10 snapin, v11 module), Nutanix Files - To enable Files snapshots “Enable Self Service Restore” must be selected for the share(s) that will be targeted by Veeam for NAS backup from snapshot 

**Usage:** Copy the BR-NASBackup4NutanixFilesSMB.ps1 script to the VBR server.  From the NAS backup job “Storage” dialog select “Advanced”/“Scripts” and enable “Run the following script before the job:” Browse to the script and select.  Enclose the script path in double quotes and add the file share(s) included in the backup job e.g.

	“\Users\Administrator\Downloads\BR-NASBackup4NutanixFilesSMB.ps1" \\ntnxfs\ntnxsmb \\ntnxfs\profiles 

**Parameters:** List of shares processed by the backup job NOTE: NO trailing "\", names must match VBR fileshare names

**Troubleshooting**
Note that VBR Powershell interface through v10 was snapin-based.  Beginning with v11 we’ve switched to a Powershell module.  Be sure to adjust the script accordingly by commenting out the Veeam Powershell option that does not match your VBR platform.

If the script fails it may be run standalone as the only VBR changes it will effect will be the file share backup source.
The most likely cause of failure will be that the VBR backup service user context does not have permissions for Files shares.  Since Files SMB is tied to Active Directory a workgroup VBR server may not have permission to correctly execute the following Powershell enumeration of a given share’s snapshot folder.  For example –

	Get-ChildItem -Directory \\ntnxfs\ntnxsmb\.SNAPSHOT

If the preceding Powershell cmdlet does not function correctly on the VBR server for a valid Files share the script will fail.

