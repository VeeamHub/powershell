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
$latestrp = Get-VBRRestorePoint -Name $namevm | Sort-Object -Property completiontimeutc -Descending | select -First 1
$iscsipublish = Publish-VBRBackupContent -RestorePoint $latestrp -AllowedIps $mountserver
$pubcontent = Get-VBRPublishedBackupContentInfo -Session $iscsipublish
$iqn = ($pubcontent.Disks[0].AccessLink -replace ":LUN\([0-9]+\)","")


$corepath = (Get-ItemPropertyValue -Path 'HKLM:\SOFTWARE\Veeam\Veeam Backup and Replication' -Name corepath)
$dll = join-path $corepath "Renci.SshNet.dll"
if (Test-Path $dll) {
    try {
        $null = [System.Reflection.Assembly]::LoadFile($dll)
        $rkey = [Renci.SshNet.PrivateKeyFile]::new($key)
        $sshclient = [Renci.SshNet.SshClient]::new($mountserver,$username,$rkey)
        $sshclient.Connect()
        
        #mount iscsi volume in system
        $c = $sshclient.CreateCommand(("sudo iscsiadm --mode discovery -t sendtargets --portal {1};sudo iscsiadm --mode node --targetname {0} --portal {1} --login" -f $iqn,$backupserver))
        $async = $c.BeginExecute();$end = $c.EndExecute($async)
        $c.Result
        if ($c.Error -ne "") { throw ("Could not mount disk {0}" -f $c.Error) }

        #create temp mount point and mount the disk
        $c = $sshclient.CreateCommand(("sudo mkdir -p /mnt/mysqlrecovery;sudo mount {0} /mnt/mysqlrecovery" -f $diskname))
        $async = $c.BeginExecute();$end = $c.EndExecute($async)
        $c.Result
        if ($c.Error -ne "") { throw ("Could not mount disk to directory {0}" -f $c.Error) }

        #stop mysql and mv current data set
        $c = $sshclient.CreateCommand(("sudo systemctl stop mysql;sudo mv {0} {0}.backup" -f $mysqltgtdir))
        $async = $c.BeginExecute();$end = $c.EndExecute($async)
        $c.Result
        if ($c.Error -ne "") { throw ("Backing up current mysql failed {0}" -f $c.Error) }


        #mkdir, mount and set permissions ok
        $c = $sshclient.CreateCommand(("sudo mkdir {1};sudo mount --bind /mnt/mysqlrecovery/{0} {1};sudo chown -R mysql:mysql {1}" -f $mysqlsrcdir,$mysqltgtdir))
        $async = $c.BeginExecute();$end = $c.EndExecute($async)
        $c.Result
        if ($c.Error -ne "") { throw ("Preparing db failed {0}" -f $c.Error) }

        #start the db
        $c = $sshclient.CreateCommand(("sudo systemctl start mysql"))
        $async = $c.BeginExecute();$end = $c.EndExecute($async)
        $c.Result
        if ($c.Error -ne "") { throw ("Starting db failed {0}" -f $c.Error) }

        $c.Dispose()
        $sshclient.Disconnect()
    } catch {
        Write-Error ("Something went wrong in ssh connection {0}" -f $_)
    }
}