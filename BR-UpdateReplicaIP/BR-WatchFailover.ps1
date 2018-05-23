# Johan Huttenga, 20180425

# location is hardcoded because this script is called directly from Veeam Backup & Replication

$parentpid = (Get-WmiObject Win32_Process -Filter "processid='$pid'").parentprocessid.ToString()
$parentcmd = (Get-WmiObject Win32_Process -Filter "processid='$parentpid'").CommandLine
if ($parentcmd) { $parentcmds = $parentcmd.Split('"') }
if (($parentcmds) -and ($parentcmds.length -ge 11)) {
  $jobid = $parentcmds[9]; $sessionid = $parentcmds[11]
} else {
  Write-Host -ForegroundColor red -BackgroundColor black "Error: This script was called outside of a Veeam Backup & Replication job. Cannot continue."
  return
}
Start-Process powershell -ArgumentList "C:\Scripts\BR-UpdateReplicaIp\BR-UpdateReplicaIP.ps1 -JobId $jobid -SessionId $sessionid" -WorkingDirectory "C:\Scripts\BR-UpdateReplicaIp"