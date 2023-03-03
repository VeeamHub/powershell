## VeeamHub

Veeamhub projects are community driven projects, and are not created by Veeam R&D nor validated by Veeam Q&A. They are maintained by community members which might be or not be Veeam employees.

## Project Notes
Author(s): Timothy Dewin / @tdewin

Function: Example scripts to use Veeam Backup & Replication Data Integration API to live mount a MySQL server

Requires: Veeam Backup & Replication v10

Usage:

### READ THIS FIRST
Before you use this script, make sure that
- The mountserver is a vanilla clean system that is not in any use as the database will be stopped and replaced
- Make sure that you have upload public key to the account so that the script can authenticate with the private key. If you used puttygen, the sshkey private key should be in openssh format
- Make sure that you enabled NOPASSWD for the user as every command is prefixed with sudo (sudo visudo // timothy ALL=(ALL) NOPASSWD: ALL)
- The backupserver IP is used on the mount server to target the publisher so make sure that the mountserver has access to this server


### Parameters
- mountserver : The target where you want to do the livemount (not to be confused with the mountserver for the repository)
- backupserver : From which ip the content is published. If you are unsure, you can get the information from running a manually mount and then check serverips as shown in the sample below
- username : linux user
- key : file on disk that contains an openssh key that is used to access the server

```
$namevm = "mysql"
asnp veeampssnapin
$latestrp = Get-VBRRestorePoint -Name $namevm | Sort-Object -Property completiontimeutc -Descending | select -First 1
$iscsipublish = Publish-VBRBackupContent -RestorePoint $latestrp -AllowedIps $mountserver
$pubcontent = Get-VBRPublishedBackupContentInfo -Session $iscsipublish
$pubcontent.serverips
Unpublish-VBRBackupContent $iscsipublish
```


### Running it

In a first step, mount the database
```
.\br-dataintegrationapi-mysqldevmount.ps1 -mountserver "172.17.193.194" -backupserver "172.17.193.200" -username timothy -key C:\keys\sshkey
```

When you are done, umount the database
```
.\br-dataintegrationapi-mysqldevumount.ps1 -mountserver "172.17.193.194" -backupserver "172.17.193.200" -username timothy -key C:\keys\sshkey
```



## 🤝🏾 License
Copyright (c) 2020 VeeamHub

- [MIT License](LICENSE)