# Veeam Backup for Microsoft 365 Azure Proxy Automation

## Author

Tyson Fewins (tfewins)

Brad Barker 

## Function

This script is designed to run as a scheduled task on the VB365 server and automate the power state and maintenance mode state of VB365 proxies running as Azure VMs. The purposer of the script is to save on the cost of proxy VMs by dealocating the VMs when not needed. 

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
* Install Azure Powershell on the VB365 server
  * For Azure Powershell install:
    * Documentation:
	  * https://learn.microsoft.com/en-us/powershell/azure/install-azps-windows?view=azps-12.4.0&tabs=powershell&pivots=windows-psgallery
* Create a Azure Managed Identity for the VB365 server
  * This MI will need permissions to get and set the power state for the proxy VMs
    * For testing, we used the "Virtual Machine Contributer" role
    	* Documentation:
    		* https://learn.microsoft.com/en-us/entra/identity/managed-identities-azure-resources/how-to-configure-managed-identities?pivots=qs-configure-portal-windows-vm
    		* https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/compute#classic-virtual-machine-contributor

## Additional Information

* Modify the parameters found at the beginning of the script
  * Code comments explain the values and use of each parameter

* Create a Windows scheduled task on the VB365 server to run the script at intervals
  * Adjust the $CheckTime variable to fit within your scheduled task interval
    * Ex. If the task runs every 5 minutes, then I can set $Checktime = 4 so that it checks for running job sessions for 4 minutes and then the script will complete and restart at the 5th minute unless a job is found and the automation kicks in.
   
* The "Primary" proxy is designated to run all the time since the VB365 jobs and repository using the proxy pool will show as 'Disconnected' if all proxies are offline/unavailable and this will prevent jobs from running.
    * VB365 v8 allows you to deploy undersized proxies without error. To further reduce cloud spend, you can deploy the "Primary" proxy on a free-tier instance type and then have the full-sized proxies set to "Auto" to bring them up and down when needed.  
