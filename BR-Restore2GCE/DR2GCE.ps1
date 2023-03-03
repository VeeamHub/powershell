##
## Automated restore to GCE
## By Cody Ault @ Veeam
##

#Please Update the variables below 
$vbrserver = “localhost”
# VBR ServerName
$vbruser = “USERNAME”
#VBR Username
$vbrpwd = “PASSWORD”
#VBR Password
$CloudUser = "ACCOUNT-NAME"
#Account name from Cloud Credential in VBR (IE the cloud account you wish to use)
$cust_csv = "C:/example/dr2gce.csv"
#Location of the csv file with the GCE/vm details

## Script Below Edit at your own risk 
## For DiskType, set to appropriate value for workload: BalancedPersistent, StandardPersistent, SSDPersistent

$csv = import-csv $cust_csv
Connect-VBRServer #-Server $vbrserver -User $vbruser -Password $vbrpwd


$csv | ForEach-Object {
    $vm_name = $_.VM_NAME
    $vm_instance = $_.instance_type
    $vm_region = $_.Region
    $vm_cz = $_.CZ
    $vm_vpc = $_.VPC_Name 
    $snname = $_.SubnetName
    $disktype = $_.disktype
        
    $restorepoint = Get-VBRRestorePoint -Name $vm_name | Sort-Object –Property CreationTime –Descending | Select -First 1
    $account = Get-VBRGoogleCloudComputeAccount -Name $CloudUser
    $region = Get-VBRGoogleCloudComputeRegion -Account $account -Name $vm_region
    $zone = Get-VBRGoogleCloudComputeZone -Region $region -Name $vm_cz
    $vm_disk = Get-VBRFilesInRestorePoint -RestorePoint $restorepoint | Where FileName -Like '*flat.vmdk*'
    $vm_disk = $vm_disk.FileName
    $config = foreach ($i in $vm_disk) {New-VBRGoogleCloudComputeDiskConfiguration -DiskName $i -DiskType $disktype}
    $instance = Get-VBRGoogleCloudComputeInstanceType -Zone $zone -Name $vm_instance
    $vpc = Get-VBRGoogleCloudComputeVPC -Account $account -Name $vm_vpc
    $subnet = Get-VBRGoogleCloudComputeSubnet -Region $region -VPC $vpc -Name $snname
    #If using shared subnet, comment out previous line and uncomment following line:
    #subnet = Get-VBRGoogleCloudComputeSubnet -Account $account -Region $region -Name $snname

    Start-VBRVMRestoreToGoogleCloud -RestorePoint $restorepoint -Zone $zone -InstanceType $instance -VMName $vm_name -DiskConfiguration $config -Subnet $subnet -Reason "Data recovery"
    }

Disconnect-VBRServer
