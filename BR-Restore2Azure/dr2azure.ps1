##
## Automated restore to Azure
## By Dustin Albertson @ Veeam
##

#Please Update the variables below 
$vbrserver = "CHANGE_ME"
# VBR ServerName
$vbruser = "CHANGE_ME"
#VBR Username
$vbrpwd = "CHANGE_ME"
#VBR Password
$cust_csv = "C:\Example\dr2azure.csv"
#Location of the csv file with the azure/vm details

## Script Below Edit at your own risk 

$csv = import-csv $cust_csv
asnp “VeeamPSSnapIn” -ErrorAction SilentlyContinue
Connect-VBRServer #-Server $vbrserver -User $vbruser -Password $vbrpwd

    $csv | ForEach-Object {
    $vm_name = $_.VM_NAME
    $vm_size = $_.vm_size
    $vm_location = $_.Location
    $vm_rg = $_.Resource_Group
    $vm_subnet = $_.vm_subnet
    $vm_network = $_.vm_network
    $az_proxy = $_.az_proxy_name
    $az_subscription = $_.az_subscription
    $az_storage_acct = $_.az_storage_acct
    $az_account = $_.az_account_login
  

    $restorepoint = Get-VBRRestorePoint -Name $vm_name | Sort-Object -Property CreationTime -Descending | Select -First 1 
    $account = Get-VBRAzureAccount -Type ResourceManager -Name $az_account
    $subscription = Get-VBRAzureSubscription -Account $account -Name "$az_subscription"
    $storageaccount = Get-VBRAzureStorageAccount -Subscription $subscription -Name $az_storage_acct
    $location = Get-VBRAzureLocation -Subscription $subscription -Name $vm_location
    $vmsize = Get-VBRAzureVMSize -Subscription $subscription -Location $location -Name $vm_size
    $network = Get-VBRAzureVirtualNetwork -Subscription $subscription -Name $vm_network
    $subnet = Get-VBRAzureVirtualNetworkSubnet -Network $network -Name $vm_subnet
    $resourcegroup = Get-VBRAzureResourceGroup -Subscription $subscription -Name $vm_rg
    $proxy = Get-VBRServer -Name $az_proxy

    Start-VBRVMRestoreToAzure -RestorePoint $restorepoint -Subscription $subscription -StorageAccount $storageaccount -VmSize $vmsize -VirtualNetwork $network -VirtualSubnet $subnet -ResourceGroup $resourcegroup -VmName $vm_name -Reason "Scripted Restores" -GatewayServer $proxy
    }
Disconnect-VBRServer

