<# 
   .SYNOPSIS
   Add all IP subnets of an AWS region to network throttling rules
   .DESCRIPTION
   This script gets the IPv4 subnets which are used for S3 service of any region specified
   .PARAMETER Name
   This parameter is used to create a rule name like "Location-To-A.B.C.D" for every source network to S3 rule
   .PARAMETER SourceIPSubnet
   This is the source ip subnet e.g. 192.168.178.0/24
   .PARAMETER AwsRegion
   For which AWS region do you want to add the networks. e.g. "eu-central-1"
   .PARAMETER ThrottlingValue
   This is the throttling value which is used in combination with ThrottlingUnit. Example
   .PARAMETER ThrottlingUnit
   You can choose the throttling unit. You have the selection between MbitPerSec, MbytePerSec and KbytePerSec
   .PARAMETER LogFile
   You can set your own path for log file from this script. Default filename is "C:\ProgramData\awssubnet.log"

   .Example
   This example will create several rules with "test-To-A.B.C.D" and throttle this rules to 5 MBitPerSec

   .\Add-AwsTrafficRules.ps1 -Name test -SourceIPSubnet 192.168.33.0/24 -AwsRegion eu-central-1 -ThrottlingValue 5 -ThrottlingUnit MbitPerSec
   
   .Notes 
   Version:        1.0
   Author:         Marco Horstmann (marco.horstmann@veeam.com)
   Creation Date:  21 October 2020
   Purpose/Change: Initial Release
   
   .LINK https://github.com/marcohorstmann/powershell
   .LINK https://horstmann.in
 #> 
[CmdletBinding(DefaultParameterSetName="__AllParameterSets")]
Param(
   [Parameter(Mandatory=$True)]
   [string]$Name,

   [Parameter(Mandatory=$True)]
   [string]$SourceIPSubnet,
   
   [Parameter(Mandatory=$True)]
   [string]$AwsRegion,

   [Parameter(Mandatory=$True)]
   [int]$ThrottlingValue,

   [ValidateSet(“MbitPerSec”,”MbytePerSec”,"KbytePerSec")]
   [Parameter(Mandatory=$True)]
   [string]$ThrottlingUnit,

   [Parameter(Mandatory=$False)]
   [string]$LogFile="C:\ProgramData\awssubnet.log"
)


    # This function is used to log status to console and also the given logfilename.
    # Usage: Write-Log -Status [Info, Status, Warning, Error] -Info "This is the text which will be logged
    function Write-Log($Info, $Status)
    {
        switch($Status)
        {
            NewLog {Write-Host $Info -ForegroundColor Green  ; $Info | Out-File -FilePath $LogFile}
            Info    {Write-Host $Info -ForegroundColor Green  ; $Info | Out-File -FilePath $LogFile -Append}
            Status  {Write-Host $Info -ForegroundColor Yellow ; $Info | Out-File -FilePath $LogFile -Append}
            Warning {Write-Host $Info -ForegroundColor Yellow ; $Info | Out-File -FilePath $LogFile -Append}
            Error   {Write-Host $Info -ForegroundColor Red -BackgroundColor White; $Info | Out-File -FilePath $LogFile -Append}
            default {Write-Host $Info -ForegroundColor white $Info | Out-File -FilePath $LogFile -Append}
        }
    } #end function 

function IP-toINT64 () { 
  param ($ip) 
 
  $octets = $ip.split(".") 
  return [int64]([int64]$octets[0]*16777216 +[int64]$octets[1]*65536 +[int64]$octets[2]*256 +[int64]$octets[3]) 
} 
 
function INT64-toIP() { 
  param ([int64]$int) 

  return (([math]::truncate($int/16777216)).tostring()+"."+([math]::truncate(($int%16777216)/65536)).tostring()+"."+([math]::truncate(($int%65536)/256)).tostring()+"."+([math]::truncate($int%256)).tostring() )
} 



#Install-Module -Name AWSPowerShell.NetCore

#load-module AWSPowerShell.NetCore
add-pssnapin veeampssnapin


 # Check if AWS Modules are installed
    Write-Log -Status Info -Info "Checking if AWS Modules are installed ..."
    if(get-module -Name "AWSPowerShell.NetCore") {
        Write-Log -Status Info -Info "AWS Modules are already installed... SKIPPED"
    } else {
        Write-Log -Status Status -Info "AWS Modules are not installed... INSTALLING..."
        try {
            Install-Module -Name AWSPowerShell.NetCore -Force -Confirm:$False
            Write-Log -Info "AWS Modules was installed... DONE" -Status Info
        } catch  {
            Write-Log -Info "$_" -Status Error
            Write-Log -Info "Installing AWS Modules... FAILED" -Status Error
            exit 99
        }
    }
    # Check if Veeam Module can be loaded
    Write-Log -Status Info -Info "Trying to load Veeam PS Snapins ..."
    try {
        Add-PSSnapin VeeamPSSnapin
        Write-Log -Info "Veeam PS Snapin loaded" -Status Info
    } catch  {
        Write-Log -Info "$_" -Status Error
        Write-Log -Info "Failed to load Veeam PS Snapin" -Status Error
        exit 99
    }

    #Validate AWS Region
    Write-Log -Status Info -Info "Checking AWS Region"
    if(Get-AWSregion | where {$_.Region -ilike $AwsRegion }) {
        Write-Log -Info "AWS Region ... FOUND" -Status Info
    } else  {
        Write-Log -Info "AWS Region ... NOT FOUND" -Status Error
        exit 99
    }

#Build source details

$source_subnet = $SourceIPSubnet.Split("/")
try { 
    $sourceipaddr = [Net.IPAddress]::Parse($source_subnet[0])
} catch {
    Write-Log -Info "$_" -Status Error
    Write-Log -Info "Failed to validate source IP subnet" -Status Error
    exit 99
}
$sourcemaskaddr = [Net.IPAddress]::Parse((INT64-toIP -int ([convert]::ToInt64(("1"*$source_subnet[1]+"0"*(32-$source_subnet[1])),2))))
$sourcenetworkaddr = new-object net.ipaddress ($sourcemaskaddr.address -band $sourceipaddr.address)
$sourcebroadcastaddr = new-object net.ipaddress (([system.net.ipaddress]::parse("255.255.255.255").address -bxor $sourcemaskaddr.address -bor $sourcenetworkaddr.address))
$sourcestartaddr = IP-toINT64 -ip $sourcenetworkaddr.ipaddresstostring 
$sourceendaddr = IP-toINT64 -ip $sourcebroadcastaddr.ipaddresstostring
$sourcestartaddrip = INT64-toIP -int $sourcestartaddr
$sourceendaddrip = INT64-toIP -int $sourceendaddr

$aws_subnets = Get-AWSPublicIpAddressRange -ServiceKey S3 -Region $AwsRegion | where {$_.IpAddressFormat -eq "Ipv4"} | select IpPrefix


ForEach($aws_subnet IN $aws_subnets) {
    $current_subnet = $aws_subnet.IpPrefix.Split("/")
    
    $ipaddr = [Net.IPAddress]::Parse($current_subnet[0])
    $maskaddr = [Net.IPAddress]::Parse((INT64-toIP -int ([convert]::ToInt64(("1"*$current_subnet[1]+"0"*(32-$current_subnet[1])),2))))
    $networkaddr = new-object net.ipaddress ($maskaddr.address -band $ipaddr.address)
    $broadcastaddr = new-object net.ipaddress (([system.net.ipaddress]::parse("255.255.255.255").address -bxor $maskaddr.address -bor $networkaddr.address))
    $startaddr = IP-toINT64 -ip $networkaddr.ipaddresstostring 
    $endaddr = IP-toINT64 -ip $broadcastaddr.ipaddresstostring

    $targetstartaddr = INT64-toIP -int $startaddr
    $targetendaddr = INT64-toIP -int $endaddr

    echo "Die Range geht von $startaddrip bis $endaddrip"

    if(!($rulecheck = Get-VBRNetworkTrafficRule -Name $($name+"-To-"+$targetstartaddr))) {
        Add-VBRNetworkTrafficRule -Name $($name+"-To-"+$targetstartaddr) -SourceIPStart $sourcestartaddrip -SourceIPEnd $sourceendaddrip -TargetIPStart $targetstartaddr -TargetIPEnd $targetendaddr -EnableThrottling -ThrottlingValue $ThrottlingValue -ThrottlingUnit $ThrottlingUnit
    } else {
        Write-Log -Info "Network traffic rule already EXISTS" -Status Info
    }
}
