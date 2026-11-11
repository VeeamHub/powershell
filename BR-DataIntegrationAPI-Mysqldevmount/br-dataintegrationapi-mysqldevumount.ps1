param(
$mountserver = "127.0.0.1",
$backupserver = "127.0.0.1",
$username = "admin",
$key = "C:\keys\sshkey",
$namevm = "mysql",
$diskid = 0,
$diskname = "/dev/sdb2",
$mysqlsrcdir = "/var/lib/mysql",
$mysqltgtdir = "/var/lib/mysql"
)

asnp veeampssnapin
$mount = @([Veeam.Backup.PowerShell.Infos.VBRBackupContentPublicationSession]::GetAll() | ? { $_.oibname -eq $namevm })
if ($mount.Count -ne 1) {
    Write-Error "could not find mount sessions or too many"
    exit
} else {
    $mount = $mount[0]
}

$pubcontent = Get-VBRPublishedBackupContentInfo -Session $mount
$iqn = ($pubcontent.Disks[0].AccessLink -replace ":LUN\([0-9]+\)","")


$corepath = (Get-ItemPropertyValue -Path 'HKLM:\SOFTWARE\Veeam\Veeam Backup and Replication' -Name corepath)
$dll = join-path $corepath "Renci.SshNet.dll"
if (Test-Path $dll) {
    try {
        $null = [System.Reflection.Assembly]::LoadFile($dll)
        $rkey = [Renci.SshNet.PrivateKeyFile]::new($key)
        $sshclient = [Renci.SshNet.SshClient]::new($mountserver,$username,$rkey)
        $sshclient.Connect()
        

        #start the db
        $c = $sshclient.CreateCommand(("sudo systemctl stop mysql"))
        $async = $c.BeginExecute();$end = $c.EndExecute($async)
        $c.Result
        if ($c.Error -ne "") { throw ("Could not stop db {0}" -f $c.Error) }

        #umount everything
        $c = $sshclient.CreateCommand(("sudo umount {0};sudo umount /mnt/mysqlrecovery" -f $mysqltgtdir))
        $async = $c.BeginExecute();$end = $c.EndExecute($async)
        $c.Result
        if ($c.Error -ne "") { throw ("Could not unmount {0}" -f $c.Error) }


        #cleanup
        $c = $sshclient.CreateCommand(("sudo rm -rf {0};sudo mv {0}.backup {0};sudo systemctl start mysql" -f $mysqltgtdir))
        $async = $c.BeginExecute();$end = $c.EndExecute($async)
        $c.Result
        if ($c.Error -ne "") { throw ("Could not cleanup and put back db {0}" -f $c.Error) }


        #umount iscsi volume in system
        $c = $sshclient.CreateCommand(("sudo iscsiadm --mode node --targetname {0} --portal {1} --logout" -f $iqn,$backupserver))
        $async = $c.BeginExecute();$end = $c.EndExecute($async)
        $c.Result
        if ($c.Error -ne "") { throw ("Could not umount iscsi volume {0}" -f $c.Error) }

        $c.Dispose()
        $sshclient.Disconnect()
    } catch {
        Write-Error ("Something went wrong in ssh connection {0}" -f $_)
    }
}

Unpublish-VBRBackupContent $mount