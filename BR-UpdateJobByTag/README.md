# Populate Veeam Jobs using VMware Tags
## VeeamHub
Veeamhub projects are community driven projects, and are not created by Veeam R&D nor validated by Veeam Q&A. They are maintained by community members which might be or not be Veeam employees. 

## Distributed under MIT license
Copyright (c) 2018 VeeamHub

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

## Project Notes
**Author:** Johan Huttenga (@johanhuttenga), Olivier Rossi

**Version:** 0.1.0.1

**Function:** 
Run this script as an elevated scheduled task, every 15-30 minutes. This will query any vCenters connected to Veeam Backup & Replication for virtual machine and tag data. This is compared with the contents of existing VBR jobs, and new VMs will be added automatically, or a new job is created depending on job size constraints. 

VMware Tags are used. You should create tags in vCenter with tag category 'Veeam Backup Policy' and name 'Veeam_<tag>'.
VBR Templates jobs are used. You should create a template job per tag, named '<tag>_Template'.

The script queries VMware and Veeam Backup & Replication for virtual machines and job objects:
1. If a job has a vm that no longer exists in vCenter it is removed.
2. If a tag for a vm is set to the exclusion tag 'Veeam_No_Backup' it is removed. 
3. If a tag for a vm has changed it is removed and put in the appropriate job.
4. If a vm with a tag is newly found it is put in the appropriate job.

Removal is pretty straightforward. Adding a vm to a job has the following constraints: whether the job is running, whether the max job size has been reach or whether the maximum object count has been reached. If a maximum has been reached and a template is found a new job is created. 

**Requires:** Script supports VMware vSphere only and requires Veeam Backup & Replication v9.5. These scripts all run in a different user space associated with the Veeam service account, which means certain defaults have to be set correctly. To allow successful connectivity this script sets PowerCLI to ignore invalid SSL certificates in this user space. If there are other defaults that need to be set in this user space be sure to address this as well.

**Usage:** 
Add BR-UpdateJobByTag as an elevated scheduled task on the Veeam server set to repeat every 15-30 minutes. 