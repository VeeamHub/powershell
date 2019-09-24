# Veeam Backup Session Report
## VeeamHub
Veeamhub projects are community driven projects, and are not created by Veeam R&D nor validated by Veeam Q&A. They are maintained by community members which might be or not be Veeam employees. 

## Distributed under MIT license
Copyright (c) 2016 VeeamHub

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

## Project Notes
**Author:** Joe Houghes (@joehoughes)

**Version:** 0.1.0.8

**Function:** This script contains functions which will display an overview of license file details, usage of instance licenses (type, count and sum of license weight), and details of instance licenses (name, type, ID, registered time, and license weight.)

**Requires:** Veeam Backup & Replication v9.5 Update 4 or higher. If not run in an administrator console, the script will relaunch for UAC elevation. Needs to be run on the VBR server itself. For remoting use Enter-PSSession or some other remote execution option.

**Usage:** 

Import-Module .\BR-InstanceLicenseUsage.ps1  
Get-VBRLicenseDetails  
Get-VBRInstanceLicenseUsage  
Get-VBRInstanceLicenseUsageDetails  
