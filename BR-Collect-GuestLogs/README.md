# Collect-GuestLogs

# 📗 Documentation

## Project Notes
**Author:** Chris Evans <br>

## **Description:**
Automated collection of Windows guest OS logs for troubleshooting of Veeam Backup jobs with Application Aware Processing enabled (SQL/Exchange/Active Directory/SharePoint/Oracle).

## **Requires:** <br>
Local Administrator or higher privileges on Guest OS where logs are collected.

## **Background:** <br>
Manually collecting logs isn't fun, and having to follow more than one KB article just to collect all the needed logs is even less fun. Why do things the hard way when you can do them the easy way, save time, and collect just about every log that could possibly be needed for 95% of cases so you don't have to play log scavenger hunt with your support engineer.

## **Usage:** <br>
Execute on guest OS server locally (run with Administrator privileges):
```
.\Collect-GuestLogs.ps1
```
To generate logs on guest OS from remote server (run with Administrator privileges):
```
Invoke-Command -FilePath <PATH_TO_THIS_SCRIPT> -ComputerName <GUEST_OS_SERVERNAME> -Credentials (Get-Credential) 
```
**NOTE:** You will need to collect the generated log bundle from the guest OS once completed. Default location is _"C:\ProgramData\Veeam\Backup\Case_Logs\"_

## **Features**
This script will collect the following logs and details about the guest OS:

* Collects GuestHelper, GuestIndexer and other logs located in %ProgramData%\Veeam\Backup\ (or alternate configured directory)
* Collects output of various VSSAdmin commands: Writers/Shadows/ShadowStorage/Providers
* Collects output of SystemInfo.exe
* Collects various registry values (Veeam Backup and Replication/SCHANNEL/System) to check for various settings that affect in-guest processing
* Checks for Veeam registry values which may have leading or trailing whitespace which would cause them not to work as intended
* Collects list of installed software
* Collects permissions for all SQL users for each database if running SQL instances have been detected
* Collects information about connected volumes
* Collects list of accounts with Local Administrator permissions
* Collects status of Windows Services
* Checks if 'File and Printer Sharing' is enabled/disabled
* Collects Application and System Event Viewer logs
* Collects VMMS Event Viewer logs if Hyper-V role is detected
* Collects status of Windows Firewall profiles
* Collects settings of attached NICs
* Collects list of installed features/roles

### VeeamHub
Veeamhub projects are community driven projects, and are not created by Veeam R&D nor validated by Veeam Q&A. They are maintained by community members which might be or not be Veeam employees. 

### 🤝🏾 License
Copyright (c) 2022 VeeamHub

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

### ✍ Contributions

I welcome contributions from the community! I encourage you to create issues for bugs & feature requests and submit pull requests.

### 🤔 Questions

If you have any questions or something is unclear, please don't hesitate to reach out to me.
