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


#install enterprise manager
start-process -filepath msiexec -ArgumentList "/i `"$source\EnterpriseManager\BackupWeb_x64.msi`" /l*v $logdir\15entmgr.txt /qn ACCEPTEULA=`"YES`" VBREM_LICENSE_FILE=`"$licensefile`" VBREM_SERVICE_USER=`"$fulluser`" VBREM_SERVICE_PASSWORD=`"$password`" VBREM_SQLSERVER_SERVER=`"$computername\VEEAMSQL2012`" " -PassThru | Wait-Process
start-process -filepath msiexec -ArgumentList "/i `"$source\Cloud Portal\BackupCloudPortal_x64.msi`" /l*v $logdir\16cloudportal.txt /qn ACCEPTEULA=`"YES`"" -PassThru | Wait-Process

#update to the latest version
#Unblock-File $update
#start-process -filepath $update -ArgumentList "/silent /noreboot /log $logdir\15update.txt VBR_AUTO_UPGRADE=1"  -PassThru | Wait-Process

