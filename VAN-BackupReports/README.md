# Veeam AHV Session & Protected VMs Reports
## VeeamHub
VeeamHub projects are community driven projects, and are not created by Veeam R&D nor validated by Veeam Q&A. They are maintained by community members which might be or not be Veeam employees. 

## Distributed under MIT license
Copyright (c) 2020 VeeamHub

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

## Project Notes
**Author:** Joe Houghes (@jhoughes)

**Function:** Reports to output details similar to the GUI view of AHV backups, and the VeeamOne Protected VMs report

**Tested Against:** Veeam Backup & Replication v10

**Usage:** 

**Get-VeeamAHVProtectedVMsReport:**

.EXAMPLE  
  Get-VeeamAHVProtectedVMsReport  
.EXAMPLE  
  Get-VeeamAHVProtectedVMsReport -VBRServer ausveeambr | Format-Table -Autosize  
.EXAMPLE  
  Get-VeeamAHVProtectedVMsReport -VBRServer ausveeambr | Export-Csv C:\Temp\VeeamBackupSessionReport.csv -NoTypeInformation  

**Get-VeeamAHVBackupSessionReport:**

.EXAMPLE  
  Get-VeeamAHVBackupSessionReport -LastDays 10  
.EXAMPLE  
  Get-VeeamAHVBackupSessionReport -VBRServer ausveeambr -LastDays 10 | Format-Table -Autosize  
.EXAMPLE  
  Get-VeeamAHVBackupSessionReport -VBRServer ausveeambr -LastDays 10 | Export-Csv C:\Temp\VeeamAHVBackupSessionReport.csv -NoTypeInformation  
