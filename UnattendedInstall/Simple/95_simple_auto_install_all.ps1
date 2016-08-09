#TEST OS 	: 2016 TP 5 
#ISO		: VeeamBackup&Replication_9.5.0.XXX.Beta.iso
$source = "D:"
$licensefile = "C:\silent\eplus veeam_availability_suite_nfr_12_12.lic"
#$update = "C:\silent\veeam_backup_9.5.0.xxxx.updatex_setup.exe"

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

#catalog server
$catalog = "c:\vbrcatalog"
new-item  -ItemType Directory -path $catalog -ErrorAction SilentlyContinue
start-process -filepath msiexec -ArgumentList "/i `"$source\Catalog\VeeamBackupCatalog64.msi`" /l*v $logdir\05catalog.txt /qn VM_CATALOGPATH=`"$catalog`" VBRC_SERVICE_USER=`"$fulluser`" VBRC_SERVICE_PASSWORD=`"$password`"" -PassThru | Wait-Process

#backup server
$vpower = "c:\vpowernfs"
new-item  -ItemType Directory -path $vpower -ErrorAction SilentlyContinue
start-process -filepath msiexec -ArgumentList "/i `"$source\Backup\Server.x64.msi`" /l*v $logdir\06backup.txt /qn ACCEPTEULA=`"YES`" VBR_LICENSE_FILE=`"$licensefile`" VBR_SERVICE_USER=`"$fulluser`" VBR_SERVICE_PASSWORD=`"$password`" PF_AD_NFSDATASTORE=`"$vpower`" VBR_SQLSERVER_SERVER=`"$computername\VEEAMSQL2012`" " -PassThru | Wait-Process
 
#backup console
start-process -filepath msiexec -ArgumentList "/i `"$source\Backup\Shell.x64.msi`" /l*v $logdir\07shell.txt /qn ACCEPTEULA=`"YES`"" -PassThru | Wait-Process

#explorers
start-process -filepath msiexec -ArgumentList "/i `"$source\Explorers\VeeamExplorerForActiveDirectory.msi`" /l*v $logdir\08vead.txt /qn ACCEPTEULA=`"YES`"" -PassThru | Wait-Process
start-process -filepath msiexec -ArgumentList "/i `"$source\Explorers\VeeamExplorerForExchange.msi`" /l*v $logdir\09vex.txt /qn ACCEPTEULA=`"YES`"" -PassThru | Wait-Process
start-process -filepath msiexec -ArgumentList "/i `"$source\Explorers\VeeamExplorerForSQL.msi`" /l*v $logdir\10vesql.txt /qn ACCEPTEULA=`"YES`"" -PassThru | Wait-Process
start-process -filepath msiexec -ArgumentList "/i `"$source\Explorers\VeeamExplorerForOracle.msi`" /l*v $logdir\11veoracle.txt /qn ACCEPTEULA=`"YES`"" -PassThru | Wait-Process
start-process -filepath msiexec -ArgumentList "/i `"$source\Explorers\VeeamExplorerForSharePoint.msi`" /l*v $logdir\12vesp.txt /qn ACCEPTEULA=`"YES`"" -PassThru | Wait-Process

#enterprise requirements
#if installed separate, also install CLR, Shared Management Objects and DB
Install-windowsfeature Web-Default-Doc,Web-Dir-Browsing,Web-Http-Errors,Web-Static-Content,Web-Windows-Auth
Install-WindowsFeature Web-Http-Logging,Web-Stat-Compression,Web-Filtering,Web-Net-Ext45,Web-Asp-Net45,Web-ISAPI-Ext,Web-ISAPI-Filter,Web-Mgmt-Console
start-process -FilePath msiexec -ArgumentList "/i `"$source\Redistr\x64\rewrite_amd64.msi`" /l*v $logdir\14rewrite.txt /quiet /norestart" -PassThru | Wait-Process

#install enterprise manager
start-process -filepath msiexec -ArgumentList "/i `"$source\EnterpriseManager\BackupWeb_x64.msi`" /l*v $logdir\15entmgr.txt /qn ACCEPTEULA=`"YES`" VBREM_LICENSE_FILE=`"$licensefile`" VBREM_SERVICE_USER=`"$fulluser`" VBREM_SERVICE_PASSWORD=`"$password`" VBREM_SQLSERVER_SERVER=`"$computername\VEEAMSQL2012`" " -PassThru | Wait-Process
start-process -filepath msiexec -ArgumentList "/i `"$source\Cloud Portal\BackupCloudPortal_x64.msi`" /l*v $logdir\16cloudportal.txt /qn ACCEPTEULA=`"YES`"" -PassThru | Wait-Process

#update to the latest version
#Unblock-File $update
#start-process -filepath $update -ArgumentList "/silent /noreboot /log $logdir\15update.txt VBR_AUTO_UPGRADE=1"  -PassThru | Wait-Process

