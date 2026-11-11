#TEST OS 	: 2016 TP 5 
#ISO		: VeeamBackup&Replication_9.5.0.XXX.Beta.iso
$source = "D:"

#logdir
$logdir = "c:\logdir" 
new-item  -ItemType Directory -path $logdir  -ErrorAction SilentlyContinue

#create local admin
$computername = net user | ? { $_ -match "\\\\(.+)" } | % { $Matches[1] }
$username = "veeamsvc"
$password = ("Vmca12345")
net user $username $password /add /PASSWORDCHG:NO 
wmic UserAccount where ("Name='{0}'" -f $username) set PasswordExpires=False
net localgroup  "administrators" $username /add
$fulluser = "$computername\$username"
write-host "Created user $fulluser  with password $password"


#2012 System CLR Types
start-process -filepath msiexec -ArgumentList "/i `"$source\Redistr\x64\SQLSysClrTypes.msi`" /l*v $logdir\01clr.txt /quiet /norestart" -PassThru | Wait-Process

#2012 Shared management objects
start-process -filepath msiexec -ArgumentList "/i `"$source\Redistr\x64\SharedManagementObjects.msi`" /l*v $logdir\02shared.txt /quiet /norestart" -PassThru | Wait-Process

#sql express
#https://msdn.microsoft.com/en-us/library/ms144259.aspx
start-process -filepath "$source\Redistr\x64\SQLEXPR_x64_ENU.exe"  -ArgumentList "/HIDECONSOLE /Q /IACCEPTSQLSERVERLICENSETERMS /ACTION=install /FEATURES=SQLEngine,SNAC_SDK /INSTANCENAME=VEEAMSQL2012 /SQLSVCACCOUNT=`"NT AUTHORITY\SYSTEM`" /SQLSYSADMINACCOUNTS=`"$fulluser`" `"Builtin\Administrators`" /TCPENABLED=1 /NPENABLED=1 /UpdateEnabled=0"   -PassThru | Wait-Process


#enterprise requirements
#if installed separate, also install CLR, Shared Management Objects and DB
Install-windowsfeature Web-Default-Doc,Web-Dir-Browsing,Web-Http-Errors,Web-Static-Content,Web-Windows-Auth
Install-WindowsFeature Web-Http-Logging,Web-Stat-Compression,Web-Filtering,Web-Net-Ext45,Web-Asp-Net45,Web-ISAPI-Ext,Web-ISAPI-Filter,Web-Mgmt-Console
start-process -FilePath msiexec -ArgumentList "/i `"$source\Redistr\x64\rewrite_amd64.msi`" /l*v $logdir\14rewrite.txt /quiet /norestart" -PassThru | Wait-Process

