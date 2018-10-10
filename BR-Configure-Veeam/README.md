## VeeamHub
Veeamhub projects are community driven projects, and are not created by Veeam R&D nor validated by Veeam Q&A. They are maintained by community members which might be or not be Veeam employees.

### Distributed under MIT license
Copyright (c) 2018 VeeamHub
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

# Automated Configuration of Veeam Backup & Replication Server Infrastructure, Repositories and Jobs
PowerShell script to configure a freshly installed Veeam Backup & Replication Server ready for use with local and cloud based repositories with default Tag based Backup Job Policies created

    Performs a number of configuration actions against a Veeam Backup & Replication Server as per the included functions.

    - Attach a vCenter
    - Add and configure Cloud Connect Backup and/or Replication Provider
    - Add and configure a Linux Based Repository
    - Create vSphere Tag Catagories and Tags
    - Create a set of default Tag Based Policy Backup Jobs
    - Clears all configured settings

    Note: To be run on a Server installed with the Veeam Backup & Replicaton Console
    Note: There is no error checking or halt on error function
    Note: To add Linux Repository you need key based access configured and the corresponding private key file
    Note: Set desired Veeam and vCenter variables in config.json

## Requirements
- Veeam Backup & Replication Console
- Veeam Backup & Replication Details and Credentials
- vSphere Details and Credentials
- Linux Server Details and Credentials*
- Veeam Cloud Connect Provider Credentials*

*Can be excluded from config

## Getting Started

    PARAMETER Runall - Runs all the functions
    PARAMETER RunVBRConfigure - Runs all the functions to configure the Veeam Backup & Replication Server
    PARAMETER CloudConnectOnly - Used on it's own to configure a Cloud Connect Provider 
    PARAMETER CloudConnectNEA - When used with RunAll or RunVBRConfigure will deploy and configure the Cloud Connect Network Extension Appliance
    PARAMETER NoCloudConnect - When used with RunAll or RunVBRConfigure or CloudConnectOnly will not configure the Cloud Connect component
    PARAMETER NoLinuxRepo - When used with RunAll or RunVBRConfigure will not add and configure the Linux Repository
    PARAMETER ClearVBRConfig - Will clear all previously configured settings and return Veeam Backup & Replication Server to default install

    EXAMPLE - PS C:\>configure_veeam.ps1 -RubVBRConfigure -NoLinuxRepo
    EXAMPLE - PS C:\>configure_veeam.ps1 -ClearVBRConfig

## config.json Breakdown
All of the variables are configured in the config.json file. Nothing is required to be changed in the main configure script.

    {
        "LinuxRepo": {
                        "VBRServer":"localhost",
                        "IpAddress":"",
                        "Username": "centos",
                        "Key":"C:\\veeam_aws_vmc_2509\\KEY-VEEAM-03.pem",
                        "RepoName":"AWS-US-1-REPO-01",
                        "RepoFolder":"/home/repo01"
                },
        "VCCProvider": {
                        "VBRServer":"172.17.0.229",
                        "vCenterServer":"lab-vc-01.sliema.lab",
                        "vCenterDVS":"LAB-DVS-00",
                        "vCenterPortGroup":"VM-Management",
                        "vCenterDatastore":"HDD-1",
                        "vCenterResPool":"SDDC",
                        "ESXiHost":"lab-node-01.sliema.lab",
                        "CCUserName":"VCC_USERNAME",
                        "CCPassword":"VCC_PASSWORD",
                        "CCServerAddress":"VCC_PROVIDER_ENDPOINT",
                        "CCRepoName":"VCC_REPO",
                        "CCPort":"6180",
                        "NEAIPAddress":"192.168.1.239",
                        "NEASubnetMask":"255.255.255.0",
                        "NEAGateway":"192.168.1.254"
                },
        "VBRCredentials": {
                        "VBRServer":"192.168.1.231",
                        "Username":"USERNAME",
                        "Password":"PASSWORD"
                },
        "VMCCredentials": {
                        "vCenter":"lab-vc-01.sliema.lab",
                        "Username":"USERNAME",
                        "Password":"PASSWORD"
                },
        "VBRJobDetails": {
                        "DefaultRepo1":"Default Backup Repository",
                        "Job1":"CCR-01",
                        "Job2":"CCB-02",        
                        "Job3":"CCB-03",
                        "TagCatagory1":"Backup",
                        "TagCatagory2":"Replication",
                        "Tag1":"TIER-1",
                        "Tag2":"TIER-2",
                        "Tag3":"TIER-3",
                        "FullDay":"Friday",
                        "Time1":"22:00",
                        "Time2":"02:00",
                        "RestorePoints1":"7",
                        "RestorePoints2":"30"
                }
    }

### Improvements and Enhancements

- [ ] Error Checking
- [ ] Add Option for External Windows Repository
- [ ] Creat Default Cloud Connect Replication 
