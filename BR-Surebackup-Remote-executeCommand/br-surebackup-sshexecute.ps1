<#
accepts certifs automatically
#>
param(
$fexist = "/veeam/oracle_start.sh",
$plink = "C:\Program Files\Veeam\Backup and Replication\Backup\Putty\plink.exe",
#test lab vm information
$ip = "your vm ip",
$username = "root",
$password = "your password"
)

write-host "Running $fexist @ $ip"
$argplink = @("-v", $ip, "-l", $username, "-pw", $password, "bash /veeam/oracle_start.sh")

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
$p.WaitForExit()

$stdout = $p.StandardOutput.ReadToEnd()
$stderr = $p.StandardError.ReadToEnd()

if($stdout) {
    write-host ("Output: {0}" -f $stdout.trim())
    exit 0
} else {
    write-host "No output returned or something went wrong... dumping $stderr"
    $stderr >> c:\bin\log.txt
    exit 1
}
