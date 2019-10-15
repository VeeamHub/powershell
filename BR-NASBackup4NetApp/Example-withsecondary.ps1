<#
   .SYNOPSIS
   Splatting script to easier read the command parameter of Invoke-NASBackup
   .Notes 
   Version:        1.0
   Author:         Marco Horstmann (marco.horstmann@veeam.com)
   Creation Date:  15 October 2019
   Purpose/Change: Reworked documentation and commenting of code.
   
   .LINK https://github.com/veeamhub/powershell
   .LINK https://horstmann.in
#>

# Please enter below all data which are needed to process snapshots.

$arguments = @{
   #
   # Enter here the name or ip adress of the cluster where the share is located.
   #
   PrimaryCluster = "192.168.1.220"
   #
   # Enter here the name of the SVM which sharing files.
   #
   PrimarySVM = "lab-netapp94-svm1"
   #
   # Enter here the name of the share you want to snapshot.
   #
   PrimaryShare = "vol_cifs"
   #
   # Enter the filename of the XML file which was created to store credentials for the primary storage system.
   #
   PrimaryClusterCredentials = "C:\scripts\saved_credentials_Administrator.xml"
   #
   # Enter here the name or ip adress of the secondary cluster where the backup share is located.
   #
   SecondaryCluster = "192.168.1.225"
   #
   # Enter here the name of the SVM which has the backup share.
   #
   SecondarySVM = "lab-netapp94-svm2"
   #
   # Enter here the name of the share you want to use as alternative data path.
   #
   SecondaryShare = "vol_cifs_vault" 
   #
   # Enter the filename of the XML file which was created to store credentials for the secondary storage system.
   #
   SecondaryCredentials = "C:\scripts\saved_credentials_Administrator.xml"
}
# 


& $PSScriptRoot\Invoke-NASBackup.ps1 @arguments -UseSecondaryDestination

