# Add Veeam Backup for O365 Jobs by Organizational Unit
## VeeamHub
Veeamhub projects are community driven projects, and are not created by Veeam R&D nor validated by Veeam Q&A. They are maintained by community members which might be or not be Veeam employees. 

## Distributed under MIT license
Copyright (c) 2016 VeeamHub

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

## Project Notes
**Author:** Carlos Talbot (@tusc00)

# Add_VBO_Job.ps1
Powershell script to create Veeam Backup O365 jobs by Organizational unit.

This script allows you to create a Veeam Office 365 backup job based on Organizational unit. This comes in handy when you want to define a job based on a subset of the users in a given Exchange organization without having to click hundreds of user accounts from the GUI.

The script, Add_VBO_Job.ps1,  builds a list of mailboxes that are then passed to the  Add-VBOJob cmdlet for creating a new job. If the job already exists it updates it with Set-VBOJob.

# Excl_VBO_Job.ps1
Powershell script to create Veeam Backup O365 jobs with an exclusion list by Organizational unit.

This script allows you to create a Veeam Office 365 backup job with an exclusion list based on Organizational unit. This comes in handy when you want to define a job with an exlucsion of users in a given Exchange organization and not having to click hundreds of user accounts from the GUI.

The script, Excl_VBO_Job.ps1, builds a list of mailboxes to exclude that are then passed to the  Add-VBOJob cmdlet for creating a new job. If the job already exists it updates it with Set-VBOJob.

# Split_VBO_Job.ps1
Powershell script to create multiple Veeam Backup O365 jobs within an organization.

This scipt is just an example of how to create multiple VBO Jobs, spliting up the mailboxes within an Organization. Currenly it only points to one repository. It could be further enhanced to create jobs with multiple unique repositories.

It will prompt for the number of jobs to create. From there it will evenly divide the number of mailboxes in the organization and create the multiple jobs.
