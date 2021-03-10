##
## Automated restore to EC2
## By Dustin Albertson @ Veeam
##

#Please Update the variables below 
$vbrserver = “localhost”
# VBR ServerName
$vbruser = “USERNAME”
#VBR Username
$vbrpwd = “PASSWORD”
#VBR Password
$accesskey = "ACCESSKEY"
#Access Key from Cloud Credential in VBR (IE the cloud account you wish to use)
$cust_csv = "C:/example/dr2ec2.csv"
#Location of the csv file with the AWS/vm details

## Script Below Edit at your own risk 

$csv = import-csv $cust_csv
asnp “VeeamPSSnapIn” -ErrorAction SilentlyContinue
Connect-VBRServer #-Server $vbrserver -User $vbruser -Password $vbrpwd


    $csv | ForEach-Object {
    $vm_name = $_.VM_NAME
    $vm_instance = $_.instance_size
    $vm_region = $_.Region
    $vm_az = $_.AZ
    $vm_vpc = $_.VPC_ID 
    $sgname = $_.SecurityGroupName
    $sn_cidr = $_.SubnetCIDR
        
    $restorepoint = Get-VBRRestorePoint -Name $vm_name | Sort-Object –Property CreationTime –Descending | Select -First 1
    $account = Get-VBRAmazonAccount -accesskey $accesskey
    $region = Get-VBRAmazonEC2Region -Account $account -RegionType Global -Name $vm_region
    $vm_disk = Get-VBRFilesInRestorePoint -RestorePoint $restorepoint | Where FileName -Like ‘*flat.vmdk*'
    $vm_disk = $vm_disk.FileName
    $config = foreach ($i in $vm_disk) {New-VBRAmazonEC2DiskConfiguration -DiskName $i -Include -DiskType GeneralPurposeSSD}
    $instance = Get-VBRAmazonEC2InstanceType -Region $region -Name $vm_instance
    $vpc = Get-VBRAmazonEC2VPC -Region $region -AWSObjectId $vm_vpc
    $sgroup = Get-VBRAmazonEC2SecurityGroup -VPC $vpc -Name $sgname
    $subnet = Get-VBRAmazonEC2Subnet -VPC $vpc -Name $sn_cidr

    Start-VBRVMRestoreToAmazon -RestorePoint $restorepoint -Region $region -LicenseType  ProvidedByAWS -InstanceType $instance -VMName $vm_name -DiskConfiguration $config -VPC $vpc -SecurityGroup $sgroup -Subnet $subnet -Reason "Data recovery"
    }

Disconnect-VBRServer
