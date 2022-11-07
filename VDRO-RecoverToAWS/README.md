# Automated Veeam DR Orchestrator Recovery to AWS 

## Author

Marty Williams (@skitch210)

## Function

This script is designed to help automate the recovery of VMs in a backup job and Orchestrator Recovery Plan to AWS


***NOTE:*** Before executing this script in a production environment, I strongly recommend you:

* Read look over the AWS Hardware compatability for recovery
* Fully understand what the script is doing
* Test the script in a lab environment
* Understand how Veeam Restore to AWS works

## Known Issues

* VMs with multiple harddisks need to have it set to inlude both disks
* Linux GPT disks are not supported on AWS, neeed to convert to MPR
* If using NFS location - please check AIX NFS capability
* VM IP addresses are not adjusted for running in AWS
* AWS CLI needs to be installed on Veeam BNR server
  * For AWS Recovery need AWS CLI:
    Documentation:
	  https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html

	  Download:
	  https://awscli.amazonaws.com/AWSCLIV2.msi

	  Run installer on command line:
	  msiexec.exe /i https://awscli.amazonaws.com/AWSCLIV2.msi

    Create IAM role in AWS Console:
	  https://docs.aws.amazon.com/cli/latest/userguide/getting-started-prereqs.html

    Run - aws configure - command to set default perimeters:
	  Access key
	  Secret key
	  Default region
	  Default Output format
      Run the aws configure as the Orchestrator service account

## Requirements

* Veeam Backup & Replication 11a or later
* Install AWS CLI
  * Configure AWS CLI

## Additional Information

Rename aws-info.csv.template to aws-info.csv and place in a C:\VDRO\Scripts folder on Veeam BNR server


In the Orchestration plan - Plan Steps
* Add a Step Parameter
    Name has to be VMName
    Text type with Default value = %source_vm_name%
