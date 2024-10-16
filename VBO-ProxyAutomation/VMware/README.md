# Veeam Backup for Microsoft 365 VMware Proxy Automation

## Author

Tyson Fewins (tfewins)

## Function

This script is designed to run as a scheduled task on the VB365 server and automate the power state and maintenance mode state of VB365 proxies running as VMware VMs. VMware was used in the lab to test this functionality with the ultimate goal of using the script in Azure and AWS to save on the cost of proxy VMs by dealocating the VMs when not needed. 

***NOTE:*** Before executing this script in a production environment, I strongly recommend you:

* Read the Veeam Backup for Microsoft 365 User Guide
* Fully understand what the script is doing
* Test the script in a lab environment
* Understand how VB365 Proxies work in V8

## Known Issues

None currently

## Requirements

* Veeam Backup for Microsoft 365 v8 or later
  * Proxies must be part of a Proxy Pool that you designate in the script to be automated
* Install VMware PowerCLI on the VB365 server
  * For PowerCLI install:
    Documentation:
	  https://developer.broadcom.com/powercli/installation-guide

## Additional Information

* Modify the parameters found at the beginning of the script
  * Code comments explain the values and use of each parameter

* Create a Windows scheduled task on the VB365 server to run the script at intervals
  * Adjust the $CheckTime variable to fit within your scheduled task interval
    * Ex. If the task runs every 5 minutes, then I can set $Checktime = 4 so that it checks for running job sessions for 4 minutes and then the script will complete and restart at the 5th minute unless a job is found and the automation kicks in. 
