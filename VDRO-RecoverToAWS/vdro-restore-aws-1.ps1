param([string]$VMName)

Write-Host $VMName

$cTime = "CreationTime"
#Pick latest restore point and VM from backup job
$RestorePoint = Get-VbrRestorePoint -Name $VMName | Sort-Object -Property $cTime -Descending | Select-Object -First 1
Write-Host "RestorePoint:" $RestorePoint.Info.CommonInfo.CreationTimeUtc.Value "UTC"

$VMcpu = $RestorePoint.AuxData.NumCpus
Write-Host "VM CPU Cores:" $VMcpu "Cores"

$VMram = $RestorePoint.AuxData.MemSizeMb.InMegabytes
Write-Host "VM RAM:" $VMram "MB"

Write-Host "Set AWS Info"

#Please Update the aws-info.csv for your settings
$awsCSV = "C:\VDRO\Scripts\aws-info.csv" #CSV File to read from.
$awsInfo =Import-Csv $awsCSV

$Env:AWS_ACCESS_KEY_ID=$awsInfo.accessKey
$Env:AWS_SECRET_ACCESS_KEY=$awsInfo.secretKey
$Env:AWS_DEFAULT_REGION=$awsInfo.region

#Set Amazon account
$Account = Get-VBRAmazonAccount -accesskey $awsInfo.accessKey
Write-Host "Account:" $Account.Name

#Set Amazon region
$Region = Get-VBRAmazonEC2Region -Account $Account -RegionType Global -Name $awsInfo.region
Write-Host "Region:" $Region.Name

$RegionName = $Region.Name

Write-Host "Matching equivelant T Class x86_64 EC2 instance type"

$AwsCmd = "C:\Program Files\Amazon\AWSCLIV2\aws.exe"
$Param1 = "ec2 describe-instance-types"
$Param1 = $Param1.Split(" ")
$Param2 = "--region $RegionName"
$Param2 = $Param2.Split(" ")
$Param3 = "--filters Name=vcpu-info.default-vcpus,Values=$VMcpu"
$Param3 = $Param3.Split(" ")
$Param4 = "Name=memory-info.size-in-mib,Values=$VMram"
$Param4 = $Param4.Split(" ")
$Param5 = "Name=instance-type,Values=t*"
$Param5 = $Param5.Split(" ")
$Param6 = "Name=processor-info.supported-architecture,Values=x86_64"
$Param6 = $Param6.Split(" ")
$Param7 = "--query InstanceTypes[].{InstnaceType:InstanceType,vCPUs:VCpuInfo.DefaultVCpus,RAM:MemoryInfo.SizeInMiB}"
$Param7 = $Param7.Split(" ")
$Ec2Instances = & "$AwsCmd" $Param1 $Param2 $Param3 $Param4 $Param5 $Param6 $Param7 | ConvertFrom-Json

#Set the disk type based on vm disk
$VMdisk = Get-VBRFilesInRestorePoint -RestorePoint $RestorePoint | Where FileName -Like "*flat.vmdk*"
$VolumeConfig = New-VBRAmazonEC2DiskConfiguration -DiskName $VMdisk.FileName -Include -DiskType GeneralPurposeSSD
Write-Host "VolumeInfo:" $VolumeConfig.DiskName "is of type:" $VolumeConfig.DiskType

#Set instant type/size
$ec2inst = $Ec2Instances[0].InstnaceType
$Instance = Get-VBRAmazonEC2InstanceType -Region $Region -Name $ec2inst
Write-Host "Instance:" $ec2inst

#Set VPC
$VPC = Get-VBRAmazonEC2VPC -Region $Region -AWSObjectID $awsInfo.VPC
Write-Host "VPC:" $VPC.Name

#Set security group
$Ec2SecGroup = Get-VBRAmazonEC2SecurityGroup -VPC $VPC -Name $awsInfo.ec2SecGrp
Write-Host "Ec2SecGroup: " $Ec2SecGroup.Name

#Set Subnet 
$Subnet = Get-VBRAmazonEC2Subnet -VPC $VPC -Name $awsInfo.ec2Subnet
Write-Host "Subnet:" $Subnet

#Set Proxy Subnet 
$prxSubnet = Get-VBRAmazonEC2Subnet -VPC $VPC -Name $awsInfo.prxSubnet
Write-Host " Proxy Subnet:" $prxSubnet

#Set Proxy Appliance Security Group
$PrxSecGroup = Get-VBRAmazonEC2SecurityGroup -VPC $vpc -Name $awsInfo.prxGrp
Write-Host "PrxSecGroup:" $PrxSecGroup

#Set Proxy Appliance Config

$ProxyEc2Size = Get-VBRAmazonEC2InstanceType -Region $Region -Name $awsInfo.prxEc2
$ProxyConfig = New-VBRAmazonEC2ProxyAppliance -InstanceType $ProxyEc2Size -Subnet $prxSubnet -SecurityGroup $PrxSecGroup -RedirectorPort 443
Write-Host "ProxyConfig: " $ProxyConfig.InstanceType.Name

#Set EC2Tag to prep for auto recovery back on-prem
$ec2Tag = New-VBRAmazonEC2Tag -Key backup -Value recover

#Start recovery
Start-VBRVMRestoreToAmazon -RestorePoint $RestorePoint -Region $Region -LicenseType BYOL -InstanceType $Instance `
-VMName $VMName -DiskConfiguration $VolumeConfig -VPC $VPC -SecurityGroup $Ec2SecGroup -Subnet $Subnet -ProxyAppliance $ProxyConfig `
-Reason "Data recovery" -AmazonEC2Tag $ec2Tag

Write-Host "Recovering" $VMName

Write-Host "Recovery execution of complete. Please see VBR server for status!"

Write-Host "Disconnecting from servers"
Disconnect-VBRServer