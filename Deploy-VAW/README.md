# Deploy Veeam Agent for Windows
## VeeamHub
Veeamhub projects are community driven projects, and are not created by Veeam R&D nor validated by Veeam Q&A. They are maintained by community members which might be or not be Veeam employees. 

## Distributed under MIT license
Copyright (c) 2016 VeeamHub

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

## Project Notes
**Author:** Clint Wyckoff (@ClintWyckoff)

DESCRIPTION
To Setup This Sample:
1.) Download the most recent bits of Veeam Agent for Windows from Veeam.com
2.) Manually install and then export out the configuration of your backup
    a.) This is done via the Veeam.Agent.Configurator.exe -export command that's run from "c:\program files\veeam\endpoint backup\"
3.) Place your installation in a central location - Create a Network Share that is accessible to everyone
4.) Create a source directory C:\VAW and put your license file as well as the Config.xml file that was exported.
    a.) The default location for export is "C:\ProgramData\Veeam\Endpoint\!Configuration\Config.xml"
    b.) Don't forget to show hidden files

PARAMETERS

-Installer
This provides the path to the Veeam Agent for Windows

-LicenseFile
This provides the path to your Veeam Agent for Windows .LIC file

-ConfigFile
This provides the path to your Veeam Agent for Windows Config.xml file

-TenantAccount
This is the Tenant Account for the CC Repository

-TenantAccount
This is the password for the Tenant Account for the CC Repository

-VeeamAgentInstallDirectory
This is the location where Veeam Agent for Windows is installed

EXAMPLE

Deploy-VAW.ps1 -LicenseFile ".\Extras\veeam_agent_windows_trial_10_new.lic" -ConfigFile ".\Extras\Config.xml"

