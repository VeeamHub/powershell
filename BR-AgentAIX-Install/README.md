# Automated Veeam Agent for AIX version 4 Install and configure

## Author

Marty Williams (@skitch210)

## Function

This script is designed to help automate the install of Veeam Agent for AIX deployments. It is designed to run on the Veeam Backup Server.


***NOTE:*** Before executing this script in a production environment, I strongly recommend you:

* Read [Veeam's Agent for AIX Documentation](https://helpcenter.veeam.com/docs/agentforaix/userguide/integrate.html?ver=40)
* Fully understand what the script is doing
* Test the script in a lab environment
* Understand how the AIX agent interacts with the Veeam Backup Infrastructure

## Known Issues

* External SSH commands have limited error/success return codes
* Verify Login credentials work whether password or using a certificate file
* If using NFS location - please check AIX NFS capability
  * set AIX NFS domain - chnfsdom {domain.name}
  * Start NFS domain daemon - startsrc -s nfsrgyd
  * AIX NFS random port issue - nfso -p -o nfs_use_reserved_ports=1
* Recommend extracting the .tar.gz and .tar before uploading
  * mlocate.xxx.xxx
  * VeeamAgent-xx.xxx
* Microsoft Windows Server 2016
  * *Enable LTS 1.2*
  * "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12"

## Requirements

* Veeam Backup & Replication 11a or later
  * Build Protection Group on Veeam server
  * Upload mlocate, VeeamAgent, and .xml config file to NFS location
* Install Posh-SSH powershell module on Veeam Server
  * Open Powershell command
  * Find-Module Posh-SSH
  * Install-Module -Name Posh-SSH

## Additional Information

If using a certificate file for authentication instead of a password:
* SSH Private Key must be in OpenSSH format. Can use PuttyGen to convert.
* Change script to use below inplace of creds from csv file

  ```powershell
  $Credential = Get-Credential
  $KeyFile = 'path to keyfile'
  $Sesh = New-SSHSession -ComputerName 'IP or FQDN' -Credential $Credential -KeyFile $KeyFile -Verbose
  Get-SSHTrustedHost
  Get-SSHSession | fl 
```

Posh-SSH Info:
* https://powershellmagazine.com/2014/07/03/posh-ssh-open-source-ssh-powershell-module/
* https://github.com/darkoperator/Posh-SSH/tree/master/docs
