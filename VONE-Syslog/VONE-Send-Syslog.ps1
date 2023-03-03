param([string]$SyslogServer,[string]$AlarmName,[string]$Summary,[string]$NodeName,[string]$Status,[string]$ID)
If ($Status -eq "Resolved"){
    $Status= "Notice"
    Send-SyslogMessage -Server $($SyslogServer) -Facility 'mail' -ApplicationName "$($NodeName)" -ProcessID "$($ID)" -Message "$($AlarmName), $($Summary)" -Severity "$($Status)"
}
else{
    Send-SyslogMessage -Server $($SyslogServer) -Facility 'mail' -ApplicationName "$($NodeName)" -ProcessID "$($ID)" -Message "$($AlarmName), $($Summary)" -Severity "$($Status)"
}