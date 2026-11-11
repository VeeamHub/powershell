# Johan Huttenga, 20220308

$parentpid = (Get-WmiObject Win32_Process -Filter "processid='$pid'").parentprocessid.ToString()
$parentcmd = (Get-WmiObject Win32_Process -Filter "processid='$parentpid'").CommandLine
if ($parentcmd) { $parentcmds = $parentcmd.Split('"') }
if (($parentcmds) -and ($parentcmds.length -ge 11)) {
  $jobid = $parentcmds[9]; $sessionid = $parentcmds[11]
} else {
  Write-Host -ForegroundColor red -BackgroundColor black "Error: This script was called outside of a Veeam Backup & Replication job. Cannot continue."
  return
}

$LogFile = "$($MyInvocation.MyCommand.Name).log"
$CurrentPid = ([System.Diagnostics.Process]::GetCurrentProcess()).Id

Function Write-Log {
    param([string]$str, $consoleout = $true, $foregroundcolor = (get-host).ui.rawui.ForegroundColor, $backgroundcolor = (get-host).ui.rawui.BackgroundColor)      
    if ($consoleout) { Write-Host -ForegroundColor $foregroundcolor -BackgroundColor $backgroundcolor $str }
    $dt = (Get-Date).toString("yyyy.MM.dd HH:mm:ss")
    $str = "[$dt] <$CurrentPid> $str"
    Add-Content $LogFile -value $str
}   

try {
  Write-Log "Starting C:\Scripts\BR-MPPreJobStatus\BR-MPPreJobStatus.ps1 -JobId $($jobid) -SessionId $($sessionid) ..."
  Start-Process "powershell.exe" -ArgumentList "C:\Scripts\BR-MPPreJobStatus\BR-MPPreJobStatus.ps1 -JobId $jobid -SessionId $sessionid" -WorkingDirectory "C:\Scripts\BR-MPPreJobStatus"
}
catch {
  Write-Log "Error has occurred: $($_) $($_.ScriptStackTrace)"
  exit 1
}
