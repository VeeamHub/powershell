$server = "172.17.193.194"
$username = "timothy"
$key = "C:\keys\sshkey"


$corepath = (Get-ItemPropertyValue -Path 'HKLM:\SOFTWARE\Veeam\Veeam Backup and Replication' -Name corepath)
$dll = join-path $corepath "Renci.SshNet.dll"
if (Test-Path $dll) {
    try {
        $null = [System.Reflection.Assembly]::LoadFile($dll)
        $rkey = [Renci.SshNet.PrivateKeyFile]::new($key)
        $sshclient = [Renci.SshNet.SshClient]::new($server,$username,$rkey)
        $sshclient.Connect()
        
        $c = $sshclient.CreateCommand("sudo ip addr sh")
        $async = $c.BeginExecute()
        $end = $c.EndExecute($async)
        $c.Result
        
        $c.Dispose()
        $sshclient.Disconnect()
    } catch {
        Write-Error ("Something went wrong in ssh connection {0}" -f $_)
    }
}