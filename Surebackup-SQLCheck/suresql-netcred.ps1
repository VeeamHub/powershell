param(
	$server = "localhost",
    $instance = "MSSQLSERVER",
	$instancefull = "$server\$instance",
    $minimumdb = 4
)
#$instancefull = "manual\override"

$connectionString = "Server=$instancefull;Integrated Security=True;"

$connection = New-Object System.Data.SqlClient.SqlConnection
$connection.ConnectionString = $connectionString

$failure = 1
$mustfail = $false

$q = 'use master;SELECT name, state FROM sys.databases;'


try {
    $connection.Open()

    write-host ("Connected on {0}" -f $connectionString)
    #As long as there was no connection to the database, it is set 'online' until the point it has been conneted
    #so first list the databases
    #try to query there tables, and then reread the databases status
    $datatable = @()
    $cmd = $connection.CreateCommand()
    $cmd.CommandText = $q
    $reader = $cmd.ExecuteReader()
    while($reader.Read()) {
        $datatable += New-Object -TypeName psobject -Property @{name=$reader["name"];state=$reader["state"];}
    }
    $reader.Close()

    if($datatable.Count -ge $minimumdb) {
        $datatable | % {
                $dbname = $_.name
                $lcmd = $connection.CreateCommand()
                $lcmd.CommandText = ("USE [{0}];select name from sys.tables;" -f $dbname )
                try {
                    $null = $lcmd.ExecuteScalar()
               
                } catch { 
                    $mustfail = $true
                    write-host ("Something bad on {0}, ignoring for now {1}" -f $dbname,$error[0]) 
                    
                    if($connection.state -ne 'Open')
                    {
                        write-host "Need to reopen the db, ..."
                        try { $connection.Open() } catch { write-host "Something is really bad, exiting with failure";exit 1 }
                    }
                }
        }
    

        #rereading the table
        $datatable = @()
        $cmd = $connection.CreateCommand()
        $cmd.CommandText = $q

        $reader = $cmd.ExecuteReader()
        while($reader.Read())
        {
            $datatable += New-Object -TypeName psobject -Property @{name=$reader["name"];state=$reader["state"];}
        }
        $reader.Close()
        $connection.Close()
    
    
        $allonline = $true
        $off = @()
        $datatable | % {
            if ( $_.state -eq 0 ) {
                write-host ("online : {0}" -f $_.name)
            } else {
                $allonline = $false
                #state codes : https://msdn.microsoft.com/en-us/library/ms178534.aspx
                write-host ("code {0} : {1}" -f $_.state,$_.name)
                $off += $_.name
            }
        }
        if ($allonline -and (-not $mustfail) ) { $failure = 0; write-host ("All {0} databases online !" -f $datatable.count) } 
        elseif ($allonline -and $mustfail) { $failure = 1;write-host ("All {0} databases online where online but initial query on all dbs failed somewhere, please look for ""Something bad on""" -f $datatable.count)}
        else { $failure = 1;write-host ("Not online db detected : {0}" -f ($off -join ",")) }
    } else {
        $failure = 1;write-host ("Query should at least give back {0} databases" -f $minimumdb)
    }
} catch {
    write-host ("Query failed or could not open connection {1} : {0} " -f $error[0],$connectionString)
    $failure = 1
} finally {
    $connection.Close()
}


exit $failure