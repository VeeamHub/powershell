# Veeam Backup for Microsoft 365 Azure Proxy Automation

## Author

Tyson Fewins (tfewins)

## Function

This script is designed to run as a scheduled task on the VB365 server and automate the power state and maintenance mode state of VB365 proxies running as AWS EC2 Instances. The purpose of the script is to save on the cost of proxy VMs by stopping/deallocating the VMs when not needed. 

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

* Install AWS Tools for Powershell on the VB365 server (EC2 module is the only one required)
  * For AWS Tools for Powershell installation:
    * The following commands are used to verify the installation in the script:
        * Install-Module AWS.Tools.Installer
        * Install-AWSToolsModule AWS.Tools.Ec2
    * Documentation:
	  * https://docs.aws.amazon.com/powershell/latest/userguide/pstools-getting-set-up-windows.html

* Create an AWS Service Role for the VB365 server
  * This Service Role will need permissions to get and set the power state for the proxy VMs
    * For testing, I created a role with 'customer inline permission' to only be able to power on/off instances matching a specified tag (see inline_policy.json for an example)
    	* Documentation:
    		* https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_create_for-service.html

## Additional Information

* Modify the parameters found at the beginning of the script
  * Code comments explain the values and use of each parameter

* Create a Windows scheduled task on the VB365 server to run the script at intervals
  * Adjust the $CheckTime variable to fit within your scheduled task interval
    * Ex. If the task runs every 5 minutes, then I can set $Checktime = 4 so that it checks for running job sessions for 4 minutes and then the script will complete and restart at the next 5 minute mark unless a job is found and the automation kicks in. 

* The "Primary" proxy is designated to run all the time since the VB365 jobs and repository using the proxy pool will show as 'Disconnected' if all proxies are offline/unavailable and this will prevent jobs from running.
    * VB365 v8 allows you to deploy undersized proxies without error. To further reduce cloud spend, you can deploy the "Primary" proxy on a free-tier instance type (I used an instance type of t2.micro in my testing) and then have the full sized proxies set to "Auto" to bring them up and down when needed.  
