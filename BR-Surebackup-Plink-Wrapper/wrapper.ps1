<#
	accepts certifs automatically
#>
param(
$fexist = "/root/hellodarknessmyoldfriend.txt",
$plink = "C:\bin\plink.exe",
$ip = "127.0.0.1",
$username = "root",
$password = "",
$logpref = "[linuxfexist]",
$timeout = 30
)

#prefix write-host with [linuxfexist] and a second prefix if $p is set (default "")
function write-wrapper {
    param($t,$p="") 
    $a = @($t)
    if ($p -ne "") { $p = "$p " }
    $a | % { if ($_ -ne $null -and $_ -ne "" -and $_.trim() -ne "") {write-host ("{0} {1}{2}" -f $logpref,$p,$_)}}
}

write-wrapper "Testing for $fexist @ $ip"
$exitcode = 1



if(test-path $plink) {
    #really making sure that if we say okay that some magic happened
    $fcmd = 'fftest="'+$fexist+'";if [ -e "$fftest" ];then echo "FFEXIST $fftest FFEXIST";else echo "DOES NOT EXIST $fftest";fi'

    $argplink = @("-v",$ip,"-l", $username, "-pw", $password,$fcmd)
    
    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = $plink
    $pinfo.RedirectStandardError = $true
    $pinfo.RedirectStandardOutput = $true
    $pinfo.RedirectStandardInput = $true
    $pinfo.UseShellExecute = $false
    $pinfo.Arguments = $argplink
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $pinfo
    $p.Start() | Out-Null
    $p.StandardInput.Write("yes")
    while($timeout -gt 0 -and -not $p.HasExited) { start-sleep -Seconds 1;$timeout-- }
    if($timeout -gt 0 -and $p.HasExited) {
        $stdout = ""
        $stderr = ""
        $stdout = $p.StandardOutput.ReadToEnd()
        $stderr = $p.StandardError.ReadToEnd()
        if($stdout.trim() -eq "FFEXIST $fexist FFEXIST") {
            write-wrapper ("File exists {0}" -f $stdout.trim())
            $exitcode = 0
        } else {
            write-wrapper "Something went wrong, ... dumping"
            write-wrapper -t $stderr.Split("`n") -p "stderr"
            write-wrapper -t $stdout.Split("`n") -p "stdout"
        }
    } else {
        $p.Kill()
        write-wrapper "Timeout, ... dumping"
        write-wrapper -t $stderr.Split("`n") -p "stderr"
        write-wrapper -t $stdout.Split("`n") -p "stdout"
    }
} else {
    write-wrapper "$plink path does not exist"
}
exit $exitcode