## VeeamHub
Veeamhub projects are community driven projects, and are not created by Veeam R&D nor validated by Veeam Q&A. They are maintained by community members which might be or not be Veeam employees.

## Distributed under MIT license
Copyright (c) 2018 VeeamHub
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

# Project Notes
PowerShell script that creates a new Self Service Tenant and Default Policy Jobs in the Veeam vCD Self Service Portal

- Creates a new tenant via the Veeam Enterprise Manager API in the vCD Self Service Portal. 
- Then creates a number of vCD Backup and/or Backup Copy Jobs for that tenant at the Virtual Datacenter level. 
- Final step is to import Backup Jobs into Self Service Portal

To generate the service-veeam.xml file needed to authenticate against the API you need to do the following to generate the file:

```

$Credential = Get-Credential
cmdlet Get-Credential at command pipeline position 1
Supply values for the following parameters:
User: service.veeam
Password for user service.veeam: ***********
$Credential | Export-CliXml -Path service-veeam.xml

```

- Note: If Tenant and Jobs are already created new jobs will be added with the same names
- Note: To be run on a Server installed with the Veeam Backup & Replicaton Console

> Set desired Veeam Backup, Backup Copy Job, vCloud Director Tenant and Org Details and Repository and Quota tenant Variables in config.json 
