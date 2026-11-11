<#

*Prerequirements*
Download dotnet connector https://dev.mysql.com/downloads/connector/net/ 
Tested with v8.0.19

Help from :
https://www.techtrek.io/connecting-powershell-to-mysql-database/

Make a user:
CREATE USER 'surebackup'@'%' IDENTIFIED  WITH mysql_native_password BY 'securepass';
GRANT SELECT ON * . * TO 'surebackup'@'%';

Make sure to open remote access in my.cnf / mysqld.cnf 
Look for bind-address. If you comment it out, it will bind to all addresses

#>
param(
$server = "127.0.0.1",
$port = "3306",
$user = "surebackup",
$password = "securepass",
$query = "select * from database.tablename",
$minreply = 1
)
$exitcode = 1


function write-surelog {
    param($text)
    write-host "[surebackup-mysql] $text"
}
$connectorpath = (Get-ItemPropertyValue -Path "hklm:\SOFTWARE\WOW6432Node\MySQL AB\MySQL Connector/Net" -name location -ErrorAction SilentlyContinue)
if($connectorpath) {
    $dll = join-path $connectorpath "Assemblies\v4.5.2\MySql.Data.dll"
    if (Test-Path $dll) {
        [System.Reflection.Assembly]::LoadFrom($dll) | out-null
        $mysqlcon = [MySql.Data.MySqlClient.MySqlConnection]::new()
        $mysqlcon.ConnectionString = ("Server={0};Port={1};Uid={2};Pwd={3};" -f $server,$port,$user,$password)
        try {
            $mysqlcon.open()
        } catch {
            write-surelog ("Error while opening {0}" -f $error[0])
        }
        if ( $mysqlcon.State -eq "open") {
            $cmd = [MySql.Data.MySqlClient.MySqlCommand]::new()
            $cmd.Connection = $mysqlcon
            $cmd.CommandText = $query
            try {
                $res = $cmd.ExecuteScalar()
                if ($res -ge $minreply) {
                    $exitcode = 0
                    write-surelog ("Got enough response $res to $query")
                } else {
                    write-surelog ("Not enough rows {0} < {1}" -f $res,$minreply)
                }       
            } catch {
             write-surelog ("Error while quering {0}" -f $error[0])
            }
            $mysqlcon.Close()
            write-surelog ("Closing db")
        } else {
            write-surelog ("Could not open connection to {0}" -f $server)
        }
    } else {
        write-surelog "Could not find mysql data.dll ($dll)"
    }
}
else {
    write-surelog "Could not find path for mysql dll"
}

exit $exitcode 
