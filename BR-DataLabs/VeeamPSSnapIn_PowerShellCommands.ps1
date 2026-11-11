#Below are the command sets to find VBRRestoreVM (Entire VM Recovery) & options

Add-PSSnapin VeeamPSSnapin
Get-Command | Where-Object{$_.PSSnapin.Name -eq "VeeamPSSnapin"} | Export-Csv -Path "c:\Veeam95Update3.csv"
Get-Command Start-VBRRestoreVM -ShowCommandInfo
Get-Command Start-VBRInstantRecovery -ShowCommandInfo


#Below are the command sets for Staged Restore

$point = Get-VBRBackup -name "Backup Only Job" | Get-VBRRestorePoint -Name "TPM04-MGMT-01" | Sort-Object –Property CreationTime –Descending | Select -First 1
$server= Get-VBRServer -Name tpm01-112.aperaturelabs.biz
$rp = Find-VBRViEntity -Name TPM04-MC
$ds = Find-VBRViDatastore -server $server -name "SolidFireSWING002"
$folder = Find-VBRViFolder -server $server -name "TPM04-MC"

$cred = Get-VBRCredentials -name "TPM04-MGMT-01\administrator"
$vlab = Get-VSBVirtualLab -Name "TPM04-DataLab-03"
$options = $options = New-VBRApplicationGroupStartupOptions -MaximumBootTime 100 -ApplicationInitializationTimeout 100 -MemoryAllocationPercent 200
$appgroup = Get-VSBApplicationGroup

Start-VBRRestoreVM -RestorePoint $point -Server $server -ResourcePool $rp -Datastore $ds -Folder $folder -VMName "TPM04-MGMT-01-NoScriptRestore" -Reason "Normal Entire VM Recovery"

Start-VBRRestoreVM -RestorePoint $point -Server $server -ResourcePool $rp -Datastore $ds -Folder $folder -VMName "TPM04-MGMT-01-NoAppGroup" -Reason "Staged Restore Demo No Application Group Required" -EnableStagedRestore -StagingScript "C:\Users\admin-michaelcade\Desktop\Simple_StagedRestoreScript.ps1" -StagingCredentials $cred -StagingVirtualLab $vlab -StagingStartupOptions $options

Start-VBRRestoreVM -RestorePoint $point -Server $server -ResourcePool $rp -Datastore $ds -Folder $folder -VMName "TPM04-MGMT-01_AppGroupEnabled" -diskType Thin -Reason "Staged Restore Demo Application Group Required" -EnableStagedRestore -StagingScript "C:\Users\admin-michaelcade\Desktop\Simple_StagedRestoreScript.ps" -StagingCredentials $cred -StagingVirtualLab $vlab -StagingApplicationGroup $appgroup -StagingStartupOptions $options

#Below are the command sets for Secure Restore

$server= Get-VBRServer -Name tpm01-112.aperaturelabs.biz
$rp = Find-VBRViResourcePool -Server $server -Name TPM04-MC
$b = Get-VBRBackup -Name "Backup Only Job"
$rr = Get-VBRRestorePoint -Backup $b
$r = $rr[0]
$ds = Find-VBRViDatastore -server $server -name "SolidFireSWING002"
$cred = Get-VBRCredentials -name "minwinpc\administrator"

#I am not sure what these commands mean apart from the last one. 
$scc = $sc[0]
$scr = "C:\t.bat"
$lab = Get-VSBVirtualLab

Start-VBRRestoreVM -RestorePoint $r -Server $server -VMName "TPM04-SecureRestore-01-Demo" -ResourcePool $rp -Datastore $ds -EnableAntivirusScan -EnableEntireVolumeScan -VirusDetectionAction DisableNetwork
