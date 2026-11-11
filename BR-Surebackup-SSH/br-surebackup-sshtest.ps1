param(
$server="127.0.0.1",
$username="root",
$password="",
$servicecheck="service mysql status",
$matchoutput="active [(]running[)]"
)

$goterrors = 1

function write-surelog {
    param($text) 
    write-host ("[surebackup-sshtest] {0}" -f $text)
}

$corepath = (Get-ItemPropertyValue -Path 'HKLM:\SOFTWARE\Veeam\Veeam Backup and Replication' -Name corepath)
$dll = join-path $corepath "Renci.SshNet.dll"
if (Test-Path $dll) {
    try {
        $null = [System.Reflection.Assembly]::LoadFile($dll)
        $sshclient = [Renci.SshNet.SshClient]::new($server,$username,$password)
        $sshclient.Connect()
        write-surelog ("Got connected ? {0} " -f $sshclient.IsConnected)
        $c = $sshclient.CreateCommand($servicecheck)
        $async = $c.BeginExecute()
        $end = $c.EndExecute($async)

        if( $c.Result -match $matchoutput) {
            write-surelog $c.Result
            write-surelog "Seems OK"
            $goterrors = 0
        } else {
            write-surelog ("[result stream] {0}" -f $c.Result)
            write-surelog ("[error stream] {0}" -f $c.Error)
            write-surelog "Result didn't match"
        }
        $c.Dispose()
        $sshclient.Disconnect()
    } catch {
        write-surelog ("Error {0}" -f $_)
    }
}
exit $goterrors
