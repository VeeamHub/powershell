#Below are the command sets for Secure Restore

$server= Get-VBRServer -Name tpm01-112.aperaturelabs.biz
$rp = Find-VBRViResourcePool -Server $server -Name TPM04-MC
$b = Get-VBRBackup -Name "Backup Job - Secure Restore"
$rr = Get-VBRRestorePoint -Backup $b | Sort-Object –Property CreationTime –Descending | Select -First 1
$r = $rr[0]
$ds = Find-VBRViDatastore -server $server -name "SolidFireSWING002"
$cred = Get-VBRCredentials -name "minwinpc\administrator"

Start-VBRInstantRecovery -RestorePoint $r -Server $server -VMName "TPM04-SecureRestore-01-Demo" -ResourcePool $rp -Datastore $ds -EnableAntivirusScan -VirusDetectionAction DisableNetwork -Powerup
