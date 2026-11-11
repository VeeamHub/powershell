# Get Windows Defender Status of VMs in Veeam Backup Job
## VeeamHub
Veeamhub projects are community driven projects, and are not created by Veeam R&D nor validated by Veeam Q&A. They are maintained by community members which might be or not be Veeam employees. 

## Distributed under MIT license
Copyright (c) 2022 VeeamHub

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

## Project Notes
**Author:** Johan Huttenga (@johanhuttenga)

**Version:** 0.0.0.1

**Function:** Starts a PowerShell background process that watches a Veeam Backup Job. This in turn runs a process that gets the Windows Defender Status of the VMs in the job. In total this consists of three parts:

1. BR-MPPreJobWatch which is added as a pre-job script to a Backup Job
2. BR-MPPreJobStatus which gets the Windows Defender status via WMI for each VM in the backup job.
3. BR-MPPreJobModule which contains all the dependencies required.

**Requires:** Script supports Windows only and requires Veeam Backup & Replication v11 or higher.  Credentials have to be available for the machines in the job. These scripts all run in a different user space associated with the Veeam service account, which means certain defaults have to be set correctly.

**Usage:**
Add BR-MPPreJobWatch as pre-job script to Veeam Failover Plan. No parameters required.
