# Enable Change Block Tracking (CBT)

## VeeamHub

Veeamhub projects are community driven projects, and are not created by Veeam R&D nor validated by Veeam Q&A. They are maintained by community members which might be or not be Veeam employees. 

## Distributed under MIT license
Copyright (c) 2023 VeeamHub

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


## Project Notes

**Author:** Johan Huttenga (@johanhuttenga)

**Version:** 0.0.0.1

**Function:** Starts a PowerShell script background process that orchestrates Veeam Data Integration API publishing and antivirus scanning using Microsoft Defender for secure restore. In total this consists of three parts:

- BR-DataIntegrationAPIPostJobHook which is added as a post-job script to a Backup Job.
- BR-DataIntegrationAPIScheduler which orchestrates Veeam Data Integration API publishing across of available Windows servers in your backup infrastructure, outputting a CSV and HTML file with results
- BR-BR-DataIntegrationAPIModule which contains all the dependencies required.

Requires: Script validated with VMware vSphere backups and requires Veeam Backup & Replication v12. These scripts all run in a different user space associated with the Veeam service account, which means certain defaults have to be set correctly. If there are other defaults that need to be set in this user space be sure to address this as well.