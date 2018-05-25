# Re-Ip Linux Replicas in Veeam Failover Plan
## VeeamHub
Veeamhub projects are community driven projects, and are not created by Veeam R&D nor validated by Veeam Q&A. They are maintained by community members which might be or not be Veeam employees. 

## Distributed under MIT license
Copyright (c) 2018 VeeamHub

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

## Project Notes
**Author:** Johan Huttenga (@johanhuttenga)

**Version:** 0.1.0.3

**Function:** Starts a PowerShell background process that watches a Veeam Backup & Replication Failover Plan. This in turn waits for virtual machines to failover and changes their IP Addresses (for Red Hat and CentOs) based on source Replication Job settings. In total this consists of three parts:

1. BR-WatchFailover which is added as a pre-failover script to a Failover Plan.
2. BR-UpdateReplicaIp which watches the Failover Plan while it executes and Re-Ips the virtual machines as they fail over.
3. BR-UpdateReplicaIpModule which contains all the dependencies required.

**Requires:** Script supports VMware vSphere only and requires Veeam Backup & Replication v9 or v9.5.  Re-IP rules (ReIpRulesOptions) and Guest OS credentials (VssOptions.LinCreds or VssOptions.WinCreds) have to be set in the source Replication Job. Application consistency itself can be disabled. These scripts all run in a different user space associated with the Veeam service account, which means certain defaults have to be set correctly. To allow successful connectivity this script sets PowerCLI to ignore invalid SSL certificates in this user space. If there are other defaults that need to be set in this user space be sure to address this as well.

**Usage:** 
Add BR-WatchFailover as pre-failover script to Veeam Failover Plan. No parameters required.
