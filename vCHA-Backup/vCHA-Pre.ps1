#vCenter variables
$vcenter = "vcenter.domain.com"
$username = "myuser@mydomain.com"
$password = "password123!"
#Veeam variables
$jobname = "vcha-backup"


#####Begin work section#####
Add-PSSnapin VeeamPSSnapin
###Connect to vCenter###
Connect-VIserver $vcenter -User $username -Password $password
###Determine state of the vCHA cluster and find passive node.###
$vcHAClusterManager = Get-View failoverClusterManager
$healthInfo = $vcHAClusterManager.GetVchaClusterHealth()
$vcClusterState = $healthInfo.RuntimeInfo.ClusterState
$nodeState = $healthInfo.RuntimeInfo.NodeInfo
$passiveNode = $nodeState | where {$_.NodeRole -eq "passive"}
###Map the passive node's IP to a VM name in inventory.###
$VBRVMToDisable = Get-VM | Where {$_.guest.IPAddress -contains $passiveNode.NodeIP}
#Write-Output "The vCHA passive VM to be excluded from the job is $VBRVMToDisable.Name."
###Exclude the passive node by adding it to the job, then excluding it explicitly.###
Add-VBRViJobObject -Job $jobname -Entities (Find-VBRViEntity -Name $VBRVMToDisable.Name)
Get-VBRJobObject -Job $jobname -Name $VBRVMToDisable.Name | Remove-VBRJobObject
