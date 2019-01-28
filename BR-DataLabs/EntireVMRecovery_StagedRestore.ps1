$point = Get-VBRBackup -name "Backup Only Job" | Get-VBRRestorePoint -Name "TPM04-MGMT-01" | Sort-Object –Property CreationTime –Descending | Select -First 1
$server= Get-VBRServer -Name tpm01-112.aperaturelabs.biz
$rp = Find-VBRViEntity -Name TPM04-MC
$ds = Find-VBRViDatastore -server $server -name "SolidFireSWING002"
$folder = Find-VBRViFolder -server $server -name "TPM04-MC"

$cred = Get-VBRCredentials -name "TPM04-MGMT-01\administrator"
$vlab = Get-VSBVirtualLab -Name "TPM04-DataLab-03"
$options = $options = New-VBRApplicationGroupStartupOptions -MaximumBootTime 100 -ApplicationInitializationTimeout 100 -MemoryAllocationPercent 200
$appgroup = Get-VSBApplicationGroup

#Start-VBRRestoreVM -RestorePoint $point -Server $server -ResourcePool $rp -Datastore $ds -Folder $folder -VMName "TPM04-MGMT-01-NoScriptRestore" -Reason "Normal Entire VM Recovery"

Start-VBRRestoreVM -RestorePoint $point -Server $server -ResourcePool $rp -Datastore $ds -Folder $folder -VMName "TPM04-MGMT-01-NoAppGroup" -Reason "Staged Restore Demo No Application Group Required" -EnableStagedRestore -StagingScript "C:\Users\admin-michaelcade\Desktop\Simple_StagedRestoreScript.ps1" -StagingCredentials $cred -StagingVirtualLab $vlab -StagingStartupOptions $options

#Start-VBRRestoreVM -RestorePoint $point -Server $server -ResourcePool $rp -Datastore $ds -Folder $folder -VMName "TPM04-MGMT-01_AppGroupEnabled" -diskType Thin -Reason "Staged Restore Demo Application Group Required" -EnableStagedRestore -StagingScript "C:\Users\admin-michaelcade\Desktop\Simple_StagedRestoreScript.ps" -StagingCredentials $cred -StagingVirtualLab $vlab -StagingApplicationGroup $appgroup -StagingStartupOptions $options
