<# 
   .Synopsis 
    Allows you to auto unmount the vPower NFS datastore via Windows Task Manager
   .Example 
	Run the code via a Windows Task Manager process
   .Notes 
    NAME: AutoUnmountVpowerNFS
    AUTHOR: Niels Engelen
    LASTEDIT: 02-08-2018 
    KEYWORDS: Scheduling, Veeam
 #> 
 # Script to unmount Veeam vPower NFS datastore
 
# Fill in the information below
# vCenter server address (FQDN or IP)
$vcenter = "vcenterhostname"
# vCenter Username
$user = "DOMAIN\Username"
# Password
$pass = "PASSWORD"

# DO NOT TOUCH BELOW!!
 
# Connect to vCenter
Connect-VIServer -Server $vcenter -Username $user -Password $pass | Out-Null

$hosts = Get-VMHost
foreach ($VMHost in $hosts) {
    $veeamshare = Get-Datastore | where {$_.type -eq "NFS" -and $_.name -Match "VeeamBackup_*"} 
    Remove-Datastore -VMHost $VMHost -Datastore $veeamshare -confirm:$false
}
 
# Disconnect from vCenter
Disconnect-VIServer -Server $vcenter -Confirm:$false | Out-Null