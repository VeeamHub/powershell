<#
    Version cmdlets
#>
function Get-VHMVersion {
	return (Get-Module VeeamHubModule).Version.ToString()
}
function Get-VHMVBRVersion {
	$versionstring = "Unknown Version"

    $pssversion = (Get-PSSnapin VeeamPSSnapin -ErrorAction SilentlyContinue)
    if ($pssversion -ne $null) {
        $versionstring = ("{0}.{1}" -f $pssversion.Version.Major,$pssversion.Version.Minor)
    }

    $corePath = Get-ItemProperty -Path "HKLM:\Software\Veeam\Veeam Backup and Replication\" -Name "CorePath" -ErrorAction SilentlyContinue
    if ($corePath -ne $null) {
        $depDLLPath = Join-Path -Path $corePath.CorePath -ChildPath "Packages\VeeamDeploymentDll.dll" -Resolve -ErrorAction SilentlyContinue
        if ($depDLLPath -ne $null -and (Test-Path -Path $depDLLPath)) {
            $file = Get-Item -Path $depDLLPath -ErrorAction SilentlyContinue
            if ($file -ne $null) {
                $versionstring = $file.VersionInfo.ProductVersion
            }
        }
    }
    $clientPath = Get-ItemProperty -Path "HKLM:\Software\Veeam\Veeam Mount Service\" -name "installationpath" -ErrorAction SilentlyContinue
    if ($clientPath -ne $null) {
        $depDLLPath = Join-Path -Path $clientPath.installationpath -ChildPath  "Packages\VeeamDeploymentDll.dll" -Resolve -ErrorAction SilentlyContinue
        if ($depDLLPath -ne $null -and (Test-Path -Path $depDLLPath)) {
            $file = Get-Item -Path $depDLLPath -ErrorAction SilentlyContinue
            if ($file -ne $null) {
                $versionstring = $file.VersionInfo.ProductVersion
            }
        }
    }
	return $versionstring
}

<#
    SQL Direct Query support
#>

<#
.SYNOPSIS
Builds up the connection to the SQL server

.DESCRIPTION
Uses underlying Dotnet calls to directly connect to the database. Use this to build the session. Later you can use the result (connection) to query from the db

.PARAMETER SQLLogin
The login if you want to use SQL authentication. In case you leave the parameter blank, the connection will use Windows Basic Authentication (works well on the local server if you are admin)

.PARAMETER SQLPassword
Password for SQL authentication as a SecureString

.PARAMETER SQLPlainTextPassword
Converts this plaintext into a SecureString and overrides SQL Password. Do not use in production or in script, but can be convenient on the command line

.PARAMETER SQLServer
The SQL server hosting the VeeamBackup DB

.PARAMETER SQLINSTANCE
The instance the database is hosted on. The default is VEEAMSQL2012

.PARAMETER SQLDB
The default the database is hosted on

.EXAMPLE 
$conn = New-VHMSQLConnection
Get-VHMSQLRepository -VHMSQLConnection $conn | Format-VHMSQLQuery

On a local server

.EXAMPLE
$conn = New-VHMSQLConnection -SQLLogin veeamquery -SQLPlainTextPassword mysupersecretpassword -SQLServer 10.1.1.1
Get-VHMSQLRepository -VHMSQLConnection $conn | Format-VHMSQLQuery

On a remote server, with sqlauthentication

.NOTES
If you use SQL Authentication, remember that by default mixed mode is not enabled.

Also create a seperate user with only view right on the server to lower the security risk. 

#>
function New-VHMSQLConnection {
    <#
        securestring from plaintext : ConvertTo-SecureString -String "mypassword" -AsPlainText -Force
    #>
    [cmdletbinding()]
    param(
        [string]$SQLLogin="",
        [System.Security.SecureString]$SQLPassword=$null,
        [string]$SQLPlainTextPassword="",
        [string]$SQLServer="localhost",
        [string]$SQLInstance="VEEAMSQL2012",
        [string]$SQLDB="VeeamBackup"
    )

    if ($SQLPlainTextPassword -ne "") {
        $SQLPassword = ConvertTo-SecureString -String $SQLPlainTextPassword -AsPlainText -Force
    }

    $VHMSQLConnection = $null
    $conn = $null
    <#
        if null try windows basic authenication, otherwise failover to sql authentication
    #>
    $connstring = ("Persist Security Info=true;Integrated Security=true;Initial Catalog={2};server={0}\{1}" -f $SQLServer,$SQLInstance,$SQLDB)

    if($SQLLogin -eq "") {
        write-Verbose "Login not set, trying Integrated Security"
        $conn = [System.Data.SqlClient.SqlConnection]::new($connstring)
    } else {
        write-Verbose "Using SQL Authentication"
        $connstring = ("Persist Security Info=true;Integrated Security=False;Initial Catalog={2};server={0}\{1}" -f $SQLServer,$SQLInstance,$SQLDB)
        $SQLPassword.MakeReadOnly()
        $sqlauth = [System.Data.SqlClient.SqlCredential]::new($SQLLogin,$SQLPassword)
        $conn = [System.Data.SqlClient.SqlConnection]::new($connstring,$sqlauth)
    }

    if ($conn -eq $null) {
        throw [System.Exception]::New("Connection was not set up")
    }
    
    write-verbose "Trying to connect to DB"
    try {
        $command = [System.Data.SqlClient.SqlCommand]::new("SELECT [VeeamProductID] FROM [VeeamBackup].[dbo].[VeeamProductVersion]",$conn)
        $conn.Open()
        write-verbose ("Opened connection, trying to query version hash")
        $result = $command.ExecuteScalar()
        if ($result -ne $null) {
            write-verbose ("Version hash queried succesfully, returning connection")
            $VHMSQLConnection = New-Object -TypeName psobject -Property @{Version=$result;Connection=$conn}
        }
        $conn.Close()
    } catch {
        throw [System.Exception]::New(("Connection was not set up, {0}" -f $_.Exception.Message))
    }
    return $VHMSQLConnection
}
<#
.SYNOPSIS
Helper function that runs queries against the connection

.DESCRIPTION
Helper function that does queries for the get function. Avoid using. If you have a use case for using invoke-vhmsqlquery, you most likely have a use case to build your own get-vhmsql... function

In that case, fork veeamhub, and contribute 

.PARAMETER VHMSQLConnection
Connection you make with New-VHMSQLConnection

.PARAMETER scalar
Means you only expect one row, one column, single value result

.PARAMETER query
The query you want to execute

#>
function Invoke-VHMSQLQuery {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory=$true)]$VHMSQLConnection=$null,
        [Parameter(Mandatory=$true)][string]$query=$null,
        [switch]$scalar=$false
    )

    $result = $null
    [System.Data.SqlClient.SqlConnection]$conn = $VHMSQLConnection.Connection
    $command = [System.Data.SqlClient.SqlCommand]::new($query,$conn)
    if($conn.State -ne "Open") {
        $conn.Open()
    }
    
    if($scalar) {
        <#if you just one to have a single value (1row/1column) returned#>
        $result = $command.ExecuteScalar()
    } else {
        [System.Collections.ArrayList]$result = new-object -type System.Collections.ArrayList
        $reader = $command.ExecuteReader()
       
        $result = new-object -Type System.Collections.ArrayList

        while($reader.Read()) {
           $row = [object[]]::new($reader.FieldCount)
           $colcount = $reader.getvalues($row)
           <#Wrapping so that powershell does not try to convert it to one large array#>
           $result.Add($row) | out-null
           
        }
        $reader.Close()
    }
    $conn.Close()
    return $result
}

<#
.SYNOPSIS
Reformats the SQL query output that you will get with Get-VHMSQL... commands.

.DESCRIPTION
Reformating takes a lot of processing power. If you need to extract data in scripts, using the format function might slow down the script significantly.

However if you want to see the output on screen or you want to dump to a file, this can prettify the output

.PARAMETER names
Instead of using COLXXXXX as a column name, you can specifiy alternative names. Might be prettier on screens and for exporting

.PARAMETER select
Array of Integers. Tells Format-VHMSQLQuery to select only those colums specified

.EXAMPLE
Get-VHMSQLStoragesOnRepository -VHMSQLConnection $sql | Format-VHMSQLQuery

.EXAMPLE 
Get-VHMSQLStoragesOnRepository -VHMSQLConnection $sql | Format-VHMSQLQuery -select 8,6,9 -names "Server","Repository","File"

Selecting only certain columns and naming them instead of using COLXXXXX approach

.NOTES
#>
function Format-VHMSQLQuery {
    param(
        [Parameter(Mandatory=$True,ValueFromPipeline=$True)]
        $row,
        $names = @(),
        $select = @()
    )
    begin {
    }
    process {
        $eo = New-Object -type psobject -Property @{}
        if ($select.count -eq 0) {
            for($i=0;$i -lt $row.count;$i++) {
                $name = ("COL{0:D5}" -f $i)
                if($names.count -gt $i) {
                    $name = $names[$i]
                }
                $eo | Add-Member -NotePropertyName $name -NotePropertyValue $row[$i]
            }
        } else {
            for($i=0;$i -lt $select.count;$i++) {
                $selector = $select[$i]
                if ($selector -lt $row.count) {
                    $name = ("COL{0:D5}" -f $i)
                    if($names.count -gt $i) {
                        $name = $names[$i]
                    }
                    $eo | Add-Member -NotePropertyName $name -NotePropertyValue $row[$selector]
                } else {
                    write-error "Selector $selector out of range"
                }
            }
        }
        $eo
    }
    end {
    }
}

<#
.SYNOPSIS
Gets the list of repositories

.DESCRIPTION
The object return is a multidimensional array (technically an arraylist of array)

Every item at the toplevel is a row

Every item at the second level is a column

    0 id - id of repo
    1 name - name of repository
    2 host_id - server hosting the repository
    3 path - path to the backup files
    4 meta_repo_id - id of the cluster, this means this repository is an extent
    5 type - if type is 10, it seems to be a scale-out backup repository
    6 custom - if is sobr cluster or not, instead of checking type, use this so changes can be checked in this module

.PARAMETER VHMSQLConnection
Connection you make with New-VHMSQLConnection

.PARAMETER name
Name if you want to return a specific repository

.PARAMETER id
Id if you want to return a specific repository

.PARAMETER columns
Is a predefined list of parameters that will be select from the query. Try to avoid overridding the columns parameter unless you check the DB structure and you know for sure what you need

.EXAMPLE
Get-VHMSQLRepository -VHMSQLConnection $conn 

Raw Query

.EXAMPLE
$query = Get-VHMSQLRepository -VHMSQLConnection $conn
foreach($row in $query) {
    write-host ("{0,-30} | {1,-30} | {2}" -f $row[1],$row[3],$row[4])
}

Making your own table (show you how you can foreach the query result). Use this kind of setup if you are planning to use the query in a script

.EXAMPLE
Get-VHMSQLRepository -VHMSQLConnection $conn | Format-VHMSQLQuery

Format to show on screen


.EXAMPLE
Get-VHMSQLRepository -VHMSQLConnection $conn | Format-VHMSQLQuery -select 1,3,4 -names "Repo","Server","Path" | ft

Format but select only certain columns

.EXAMPLE
Get-VHMSQLRepository -VHMSQLConnection $conn | Format-VHMSQLQuery -select 1,3,4 -names "Repo","Server","Path" | Convertto-csv

Format and pipe it to converto-csv if you want to make a dump

Selecting only certain columns and naming them instead of using COLXXXXX approach
#>
function Get-VHMSQLRepository {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory=$true)]$VHMSQLConnection=$null,
        $name=$null,
        $id=$null,
        $columns=@("[repo].[id]","[repo].[name]","[host_id]","[host].[name]","[path]","[extrarepo].[meta_repo_id]","[repo].[type]","CAST(CASE WHEN [repo].[type] = '10' THEN 1 ELSE 0 END AS int) as ScaleOut")
    )
    $query = (@"
SELECT {0}
FROM [VeeamBackup].[dbo].[BackupRepositories] as repo
LEFT JOIN [VeeamBackup].[dbo].[Backup.ExtRepo.ExtRepos] AS extrarepo ON [repo].[id] = [extrarepo].[dependant_repo_id]
LEFT JOIN [VeeamBackup].[dbo].[Hosts] as host ON [repo].[host_id] = [host].[id] 
"@ -f ($columns -join ","))

    
    if ($name -ne $null) { $query += ("WHERE [repo].[name] = '{0}'" -f $name)}
    elseif ($id -ne $null) { $query += ("WHERE [repo].[id] = CAST('{0}' AS UNIQUEIDENTIFIER) " -f $id)}

    write-verbose $query

    return Invoke-VHMSQLQuery -VHMSQLConnection $VHMSQLConnection -query $query
}

<#
.SYNOPSIS
Gets the list of repositories

.DESCRIPTION
The object return is a multidimensional array (technically an arraylist of array)

Every item at the toplevel is a row

Every item at the second level is a column

    0 id - file_id
    1 file_path - as in db, please use scripted path for sobr overview
    2 dir_path - as in db, please use scripted path for sobr overview
    3 repo_id - if it is a regular repository, id of the repo, if it is on a scaleout cluster, it is cluster id 
    4 ext_id - if the file is on a cluster, this is the repository id it is really located on, otherwise $null
    5 physical_repo_id - id of the repository the file is physically located on regardless if it is on sobr
    6 physical_repo_name - name of the repository the file is physically located on regardless if it is on sobr
    7 physical_repo_host_id - id of the host hosting the physical repo, in case of cifs, will be empty
    8 physical_repo_host_name - name of the host hosting the physical repo, in case of cifs, will be empty
    9 full_file_path - scripted full path that should work on both regular repositories as extends

.PARAMETER VHMSQLConnection
Connection you make with New-VHMSQLConnection

.PARAMETER physrepoid
ID of the repository that host the file (not the cluster but the extent)

.PARAMETER physreponame
name of the repository that host the file (not the cluster but the extent)

.PARAMETER hostid
name of the server on which the repository that host the file (not the cluster but the extent) is hosted

null in case of cifs share

.PARAMETER hostname
name of the server on which the repository that host the file (not the cluster but the extent) is hosted

null in case of cifs share

.PARAMETER WHERE
Custom where clase, try to avoid unless you know what you are doing

.PARAMETER columns
Is a predefined list of parameters that will be select from the query. Try to avoid overridding the columns parameter unless you check the DB structure and you know for sure what you need

.EXAMPLE
Get-VHMSQLStoragesOnRepository -VHMSQLConnection $conn

.EXAMPLE
Get-VHMSQLStoragesOnRepository -VHMSQLConnection $conn -physreponame "Backup Repository 1"  | Format-VHMSQLQuery

.EXAMPLE
$res = Get-VHMSQLStoragesOnRepository -VHMSQLConnection $conn
foreach($row in $res) {
    write-host ("{0,-20} | {1,-20} | {2}" -f $row[8],$row[6],$row[9])
}

.EXAMPLE
Get-VHMSQLStoragesOnRepository -VHMSQLConnection $conn | Format-VHMSQLQuery

.EXAMPLE
Get-VHMSQLStoragesOnRepository -VHMSQLConnection $conn | Format-VHMSQLQuery

.EXAMPLE 
Get-VHMSQLStoragesOnRepository -VHMSQLConnection $conn | Format-VHMSQLQuery -select 8,6,9 -names "Server","Repository","File"

#>
function Get-VHMSQLStoragesOnRepository {
       [cmdletbinding()]
    param(
        [Parameter(Mandatory=$true)]$VHMSQLConnection=$null,
        $physrepoid=$null,
        $physreponame=$null,
        $hostid=$null,
        $hostname=$null,
        $where=$null,
        $columns=@("[stgs].[id]",
            "[stgs].[file_path]",
            "[dir_path]",
            "[repository_id]",
            "[extrepos].[dependant_repo_id]",
            "[physrepo].[id]  as [physical_backup_repository_id]",
            "[physrepo].[name] as [physical_backup_repository_name]",
            "[physrepohost].[id]",
            "[physrepohost].[name]",
            "(CASE WHEN [extrepos].dependant_repo_id IS NULL THEN file_path ELSE CONCAT(physrepo.path,'\',dir_path,'\',file_path) END) as full_file_path")
    )
    $query = (@"
select {0}
from [VeeamBackup].[dbo].[Backup.Model.Storages] AS stgs
LEFT JOIN [VeeamBackup].[dbo].[Backup.Model.Backups] AS backups ON [backups].[id] = [stgs].[backup_id]
LEFT JOIN [VeeamBackup].[dbo].[Backup.ExtRepo.Storages] AS extstgs ON [extstgs].[storage_id] = [stgs].[id]
LEFT JOIN [VeeamBackup].[dbo].[Backup.ExtRepo.ExtRepos] AS extrepos ON [extrepos].[id] = [extstgs].[dependant_repo_id]
LEFT JOIN [VeeamBackup].[dbo].[BackupRepositories] AS physrepo ON (ISNULL ([extrepos].dependant_repo_id,[repository_id])) = physrepo.id
LEFT JOIN [VeeamBackup].[dbo].[Hosts] AS physrepohost ON physrepo.host_id = physrepohost.id 
"@ -f ($columns -join ","))

    
    if ($physrepoid -ne $null) { $query += ("WHERE physrepo.id = '{0}'" -f  $physrepoid)}
    if ($physreponame -ne $null) { $query += ("WHERE physrepo.name = '{0}'" -f $physreponame)}
    if ($hostid -ne $null) { $query += ("WHERE physrepo.host_id = '{0}'" -f $hostid)}
    if ($hostname -ne $null) { $query += ("WHERE physrepohost.name = '{0}'" -f $hostname)}
    if ($where -ne $null) { $query += ("WHERE {0}") -f $where}
    write-verbose $query

    return Invoke-VHMSQLQuery -VHMSQLConnection $VHMSQLConnection -query $query 
}



<#
    Generic functions
#>
function Get-VHMVBRWinServer {
    return [Veeam.Backup.Core.CWinServer]::GetAll($true)
}

<#
    Schedule Info  
#>

function New-VHM24x7Array {
    param([int]$defaultvalue=0)
    $a = (New-Object 'int[][]' 7,24) 
    foreach($d in (0..6)) {
        foreach($h in (0..23)) {
            $a[$d][$h] = $defaultvalue
        }
    }
    return $a
}
function Format-VHMVBRScheduleInfo {
    param([parameter(ValueFromPipeline,Mandatory=$true)][Veeam.Backup.Common.UI.Controls.Scheduler.ScheduleInfo]$schedule)
    $days = 'S','M','T','W','T','F','S'

    $cells = $schedule.GetCells()
    foreach($d in (0..6)) {
        write-host ("{0} | {1} |" -f $days[$d],($cells[$d] -join " | ")) 
    }
}

function New-VHMVBRScheduleInfo {
    param(
        [ValidateSet("Anytime","BusinessHours","WeekDays","Weekend","Custom","Never")]$option,
        [int[]]$hours = (0..23),
        [int[]]$days = (0..6)
    )
    $result = $null
    switch($option) {
        "Anytime" {
            $result = [Veeam.Backup.Common.UI.Controls.Scheduler.ScheduleInfo]::CreateAllPermitted()
        }
        "BusinessHours" {
            $a = New-VHM24x7Array -defaultvalue 1
            foreach($d in (1..5)) {
                foreach($h in (8..17)) {
                    $a[$d][$h] = 0
                }
            }
            $result = [Veeam.Backup.Common.UI.Controls.Scheduler.ScheduleInfo]::new($a)
        }
        "WeekDays" {
            $a = New-VHM24x7Array -defaultvalue 1
            foreach($d in (1..5)) {
                foreach($h in (0..23)) {
                    $a[$d][$h] = 0
                }
            }
            $result = [Veeam.Backup.Common.UI.Controls.Scheduler.ScheduleInfo]::new($a)
        }
        "Weekend" {
            $a = New-VHM24x7Array -defaultvalue 1
            foreach($d in @(0,6)) {
                foreach($h in (0..23)) {
                    $a[$d][$h] = 0
                }
            }
            $result = [Veeam.Backup.Common.UI.Controls.Scheduler.ScheduleInfo]::new($a)
        }
        "Custom" {
            $a = New-VHM24x7Array -defaultvalue 1
            foreach($d in $days) {
                foreach($h in $hours) {
                    $a[$d][$h] = 0
                }
            }
            $result = [Veeam.Backup.Common.UI.Controls.Scheduler.ScheduleInfo]::new($a)
        }
        "Never" {
            $a = New-VHM24x7Array -defaultvalue 1
            $result = [Veeam.Backup.Common.UI.Controls.Scheduler.ScheduleInfo]::new($a)
        }
    }
    return $result
}

<#
    Traffic rules
    //Implementing hacks from Tom Sightler on : https://forums.veeam.com/powershell-f26/backup-proxy-traffic-throttling-rules-t31732.html#p228501
#>

function Get-VHMVBRTrafficRule {
    param(
        $ruleId=$null
    )
    $rls = [Veeam.Backup.Core.SBackupOptions]::GetTrafficThrottlingRules().GetRules()
    if($ruleId -ne $null) {
        $rls = $rls | ? { $_.RuleId -eq $ruleId }
    }
    return $rls
}


function Update-VHMVBRTrafficRule {
    [cmdletbinding()]
    param(
        [parameter(ValueFromPipeline)][Veeam.Backup.Model.CTrafficThrottlingRule]$TrafficRule
    )
    #Seems like the object needs to be removed by the same instance that returned them 
    begin {
        $ttr = [Veeam.Backup.Core.SBackupOptions]::GetTrafficThrottlingRules()
        $rules = $ttr.GetRules()
    }
    process {
        $m = $rules | ? { $_.RuleId -eq $TrafficRule.RuleId } 
        if ($m -ne $null) {
            Write-Verbose ("Updated rule {0}" -f $TrafficRule.RuleId)
            $m.SpeedLimit = $TrafficRule.SpeedLimit
            $m.SpeedUnit = $TrafficRule.SpeedUnit
            $m.AlwaysEnabled = $TrafficRule.AlwaysEnabled
            $m.EncryptionEnabled = $TrafficRule.EncryptionEnabled
            $m.ThrottlingEnabled = $TrafficRule.ThrottlingEnabled
            $m.SetScheduleInfo($TrafficRule.GetScheduleInfo())
            $m.FirstDiapason.FirstIp = $TrafficRule.FirstDiapason.FirstIp
            $m.FirstDiapason.LastIp = $TrafficRule.FirstDiapason.LastIp
            $m.SecondDiapason.FirstIp = $TrafficRule.SecondDiapason.FirstIp
            $m.SecondDiapason.LastIp = $TrafficRule.SecondDiapason.LastIp
            
        } else {
            Write-Verbose ("Did not found match for {0}" -f $TrafficRule.RuleId)
        }
    }
    end {
        [Veeam.Backup.Core.SBackupOptions]::SaveTrafficThrottlingRules($ttr)
    }
}
function New-VHMVBRTrafficRule {
    param(
        [Parameter(Mandatory=$true)][ValidateScript({$_ -match [IPAddress]$_ })]$SourceFirstIp="",
        [Parameter(Mandatory=$true)][ValidateScript({$_ -match [IPAddress]$_ })]$SourceLastIp="",
        [Parameter(Mandatory=$true)][ValidateScript({$_ -match [IPAddress]$_ })]$TargetFirstIp="",
        [Parameter(Mandatory=$true)][ValidateScript({$_ -match [IPAddress]$_ })]$TargetLastIp="",
        $SpeedLimit=10,
        $SpeedUnit="Mbps",
        $AlwaysEnabled=$true,
        $EncryptionEnabled=$false,
        $ThrottlingEnabled=$true,
        [Veeam.Backup.Common.UI.Controls.Scheduler.ScheduleInfo]$Schedule=[Veeam.Backup.Common.UI.Controls.Scheduler.ScheduleInfo]::CreateAllPermitted()
    )
    $ttr = [Veeam.Backup.Core.SBackupOptions]::GetTrafficThrottlingRules()

    # Add a new default traffic throttling rule to existing rules
    $nttr = $ttr.AddRule()

    # Set options for the new traffic throttling rule
    $nttr.SpeedLimit = $SpeedLimit
    $nttr.SpeedUnit = $SpeedUnit
    $nttr.AlwaysEnabled = $AlwaysEnabled
    $nttr.EncryptionEnabled = $EncryptionEnabled
    $nttr.ThrottlingEnabled = $ThrottlingEnabled
    $nttr.SetScheduleInfo($schedule)
    $nttr.FirstDiapason.FirstIp = $SourceFirstIp
    $nttr.FirstDiapason.LastIp = $SourceLastIp
    $nttr.SecondDiapason.FirstIp = $TargetFirstIp
    $nttr.SecondDiapason.LastIp = $TargetLastIp

    # Save new traffic throttiling rules
    [Veeam.Backup.Core.SBackupOptions]::SaveTrafficThrottlingRules($ttr)
    return $nttr
}

function Remove-VHMVBRTrafficRule {
    [cmdletbinding()]
    param(
        [parameter(ValueFromPipeline)][Veeam.Backup.Model.CTrafficThrottlingRule]$TrafficRule
    )
    #Seems like the object needs to be removed by the same instance that returned them 
    begin {
        $ttr = [Veeam.Backup.Core.SBackupOptions]::GetTrafficThrottlingRules()
        $rules = $ttr.GetRules()
    }
    process {
        $m = $rules | ? { $_.RuleId -eq $TrafficRule.RuleId } 
        if ($m -ne $null) {
            Write-Verbose ("Removed rule {0}" -f $TrafficRule.RuleId)
            $ttr.RemoveRule($m)
        } else {
            Write-Verbose ("Did not found match for {0}" -f $TrafficRule.RuleId)
        }
    }
    end {
        [Veeam.Backup.Core.SBackupOptions]::SaveTrafficThrottlingRules($ttr)
    }
}


<#
    Guest interaction proxies
    //Implementing hacks from Tom Sightler on :  https://forums.veeam.com/powershell-f26/set-guest-interaction-proxy-server-t35234.html#p272191
#>


function Add-VHMVBRViGuestProxy {
    param(
        [Parameter(Mandatory=$True)][Veeam.Backup.Core.CBackupJob]$job,
        [Parameter(Mandatory=$True)][Veeam.Backup.Core.CWinServer[]]$proxies= $null
    )  
    $gipspids = [Veeam.Backup.Core.CJobProxy]::GetJobProxies($job.id) | ? { $_.Type -eq "EGuest" } | % { $_.ProxyId }
    foreach($proxy in $proxies) {
            if($proxy.Id -notin $gipspids) {
                [Veeam.Backup.Core.CJobProxy]::Create($job.id,$proxy.Id,"EGuest")
            }
    }
}
function Remove-VHMVBRViGuestProxy {
    param(
        [Parameter(Mandatory=$True)][Veeam.Backup.Core.CBackupJob]$job,
        [Parameter(Mandatory=$True)][Veeam.Backup.Core.CWinServer[]]$proxies= $null
    )    
    $gips = [Veeam.Backup.Core.CJobProxy]::GetJobProxies($job.id) | ? { $_.Type -eq "EGuest" }
    $pids = $proxies.id

    foreach($gip in $gips) {
        if($gip.ProxyId -in $pids) {
            [Veeam.Backup.Core.CJobProxy]::Delete($gip.id)           
        }
    } 
}
function Set-VHMVBRViGuestProxy {
    [CmdletBinding(DefaultParameterSetName='Auto')]
    param(
        [Parameter(Mandatory=$True)][Veeam.Backup.Core.CBackupJob]$job,
        [Parameter(Mandatory = $true, ParameterSetName = 'Auto')][switch]$auto,
        [Parameter(Mandatory = $true, ParameterSetName = 'Manual')][switch]$manual,
        [Parameter(Mandatory = $true, ParameterSetName = 'Manual')][Veeam.Backup.Core.CWinServer[]]$proxies= $null
    )
    if($manual) {
        $o = $job.GetVssOptions()
        $o.GuestProxyAutoDetect = $false
        $job.SetVssOptions($o)
    }
    if($auto) {
        $o = $job.GetVssOptions()
        $o.GuestProxyAutoDetect = $true
        $job.SetVssOptions($o)
    }
    if($proxies -ne $null) {
        $gips = [Veeam.Backup.Core.CJobProxy]::GetJobProxies($job.id) | ? { $_.Type -eq "EGuest" }
        $pids = $proxies.id

        foreach($gip in $gips) {
            if($gip.ProxyId -notin $pids) {
                [Veeam.Backup.Core.CJobProxy]::Delete($gip.id)           
            }
        }
        $gipspids = [Veeam.Backup.Core.CJobProxy]::GetJobProxies($job.id) | ? { $_.Type -eq "EGuest" } | % { $_.ProxyId }
        foreach($proxy in $proxies) {
            if($proxy.Id -notin $gipspids) {
                [Veeam.Backup.Core.CJobProxy]::Create($job.id,$proxy.Id,"EGuest")
            }
        }

    }
}
function Get-VHMVBRViGuestProxy {
    param(
        [Parameter(Mandatory=$True)][Veeam.Backup.Core.CBackupJob]$job
    )
    return [Veeam.Backup.Core.CJobProxy]::GetJobProxies($job.id) | ? { $_.Type -eq "EGuest" }
}


<#
    User Roles
    //Implementing hacks from Tom Sightler on : https://forums.veeam.com/powershell-f26/add-user-to-users-and-roles-per-ps-t41011.html#p271679
#>

function Add-VHMVBRUserRoleMapping {
    Param (
        [string]$UserOrGroupName, 
        [ValidateSet('Veeam Restore Operator','Veeam Backup Operator','Veeam Backup Administrator','Veeam Backup Viewer')][string]$RoleName
     )

    $CDBManager = [Veeam.Backup.DBManager.CDBManager]::CreateNewInstance()

    # Find the SID for the named user/group
    $AccountSid = [Veeam.Backup.Common.CAccountHelper]::FindSid($UserOrGroupName)

    # Detect if account is a User or Group
    If ([Veeam.Backup.Common.CAccountHelper]::IsUser($AccountSid)) {
        $AccountType = [Veeam.Backup.Model.AccountTypes]::User
    } Else {
        $AccountType = [Veeam.Backup.Model.AccountTypes]::Group
    }

    # Parse out full name (with domain component) and short name
    $FullAccountName = [Veeam.Backup.Common.CAccountHelper]::GetNtAccount($AccountSid).Value;
    $ShortAccountName = [Veeam.Backup.Common.CAccountHelper]::ParseUserName($FullAccountName);

    # Check if account already exist in Veeam DB, add if required
    If ($CDBManager.UsersAndRoles.FindAccount($AccountSid.Value)) {
        $Account = $CDBManager.UsersAndRoles.FindAccount($AccountSid.Value)
    } else {
        $Account = $CDBManager.UsersAndRoles.CreateAccount($AccountSid.Value, $ShortAccountName, $FullAccountName, $AccountType);
    }

    # Get the Role object for the named Role
    $Role = $CDBManager.UsersAndRoles.GetRolesAll() | ?{$_.Name -eq $RoleName}

    # Check if account is already assigned to Role and assign if not
    if ($CDBManager.UsersAndRoles.GetRolesByAccountId($Account.Id)) {
        write-host "Account $UserOrGroupName is already assigned to role $RoleName"
    } else {
        $CDBManager.UsersAndRoles.CreateRoleAccount($Role.Id,$Account.Id)
    }

    $CDBManager.Dispose()
}

function Remove-VHMVBRUserRoleMapping {
    Param ([string]$UserOrGroupName, 
    [ValidateSet('Veeam Restore Operator','Veeam Backup Operator','Veeam Backup Administrator','Veeam Backup Viewer')][string]$RoleName)
    $CDBManager = [Veeam.Backup.DBManager.CDBManager]::CreateNewInstance()

    # Find the SID for the named user/group
    $AccountSid = ([Veeam.Backup.Common.CAccountHelper]::FindSid($UserOrGroupName)).Value

    # Get the Veeam account ID using the SID
    $Account = $CDBManager.UsersAndRoles.FindAccount($AccountSid)

    # Get the Role ID for the named Role
    $Role = $CDBManager.UsersAndRoles.GetRolesAll() | ?{$_.Name -eq $RoleName}

    # Check if name user/group is assigned to role and delete if so
    if ($CDBManager.UsersAndRoles.GetRoleAccountByAccountId($Account.Id)) {
        $CDBManager.UsersAndRoles.DeleteRoleAccount($Role.Id,$Account.Id)
    } else {
        write-host "Account $UserOrGroupName is not assigned to role $RoleName"
    }

    $CDBManager.Dispose()
}

function Get-VHMVBRUserRoleMapping {
    $CDBManager = [Veeam.Backup.DBManager.CDBManager]::CreateNewInstance()

    $mappings = @()
    $accounts = $CDBManager.UsersAndRoles.GetAccountsAll()

    foreach( $r in ($CDBManager.UsersAndRoles.GetRolesAll())) {
        $roleaccounts = $CDBManager.UsersAndRoles.GetRoleAccountByRoleId($r.Id)
        foreach($ra in $roleaccounts) {
            $account = $accounts | ? { $ra.AccountId -eq $_.Id }
            $mappings += (New-Object -TypeName psobject -Property @{
                AccountName=$account.Nt4Name
                RoleName=$r.Name;
                RoleAccount=$ra;
                Role=$r;
                Account=$account
            })
        }
    }
    return $mappings
}


function Export-VHMVBRJob
{
    Param(
        [string]$Name,
        [string]$Path
    )

    ## initialize config object
    $v = Get-VHMVBRVersion
    $j = [Veeam.Backup.Core.CBackupJob]::Get($Name)
    $jo = $j.GetObjectsInJob()
    $h = $null
    $hd = $null
    if ([System.Guid]::new($j.TargetHostId) -ne [System.Guid]::Empty) {
        $h = [Veeam.Backup.Core.Common.CHost]::Get([System.Guid]::new($j.TargetHostId))
        $hd = [Veeam.Backup.Core.CPhysicalHost]::Get([System.Guid]::new($h.PhysHostId))
    }
    $r = $null
    $rh = $null
    $rhd = $null
    if ([System.Guid]::new($j.Info.TargetRepositoryId) -ne [System.Guid]::Empty) {
        $r = [Veeam.Backup.Core.CBackupRepository]::Get([Guid]::new($j.Info.TargetRepositoryId))
        if ([System.Guid]::new($r.HostId) -ne [System.Guid]::Empty) {
            $rh = [Veeam.Backup.Core.Common.CHost]::Get([System.Guid]::new($r.HostId))
            $rhd = [Veeam.Backup.Core.CPhysicalHost]::Get([System.Guid]::new($rh.PhysHostId))
        }
    }
    $p = @{
        'Version'=$v
        'Job'=$j
        'JobObjects'=$jo
        'TargetHost'=$h
        'TargetHostDetails'=$hd
        'TargetRepository'=$r
        'TargetRepositoryHost'=$rh
        'TargetRepositoryHostDetails'=$rhd
    }

    $o = New-Object -TypeName PSObject -Prop $p

    ## cleanup config object
    $_json = ($o | ConvertTo-Json -Depth 99).Split("`n")
    $json = [System.Text.StringBuilder]::new()
    $skip = $false
    for($i = 0; $i -lt $_json.count; $i++) { 
        if ($_json[$i] -like "*RootNode*") { $skip = $true } elseif ($skip -and $_json[$i] -like '*"*') { $skip = $false; $json.Append("},") | Out-Null; }; 
        if (!$skip) { $json.Append(($_json[$i] + "`n")) | Out-Null }
    }

    if ($Path.length -gt 0) { $json.ToString() | Out-File -FilePath "$Path\$Name.bcx" }
    else { return $json.ToString() }
}

function Compare-VHMVBRJob {
    param($SourceJob, $TargetJob, $SourceConfig, $TargetConfig, $Node = "Job", $Property)

    if ((($SourceJob -eq $null) -and ($SourceConfig -eq $null)) -or ($($TargetJob -eq $null) -and ($TargetConfig -eq $null)))
    {
        Write-Host -ForegroundColor red -BackgroundColor black "You must specify a source (-SourceJob or -SourceConfig) and target (-TargetJob or -TargetConfig) to compare."
        return $null;
    }

    $Source = $null
    if ($SourceJob -ne $null) { $Source = (Export-VHMVBRJob $SourceJob | Out-String | ConvertFrom-Json) }
    elseif ($SourceConfig -ne $null) { $Source = (Get-Content $SourceConfig | Out-String | ConvertFrom-Json) }

    $Target = $null
    if ($TargetJob -ne $null) { $Target = (Export-VHMVBRJob $TargetJob | Out-String | ConvertFrom-Json) }
    elseif ($TargetConfig -ne $null) { $Target = (Get-Content $TargetConfig | Out-String | ConvertFrom-Json) }

    $diffs = $null
    if ($Source.$Node -and $Target.$Node) {
        if ($Property.length -gt 0) {
            $diffs = Compare-Object -ReferenceObject ($Source.$Node.$Property | Get-Member -MemberType Properties) -DifferenceObject ($Target.$Node.$Property | Get-Member -MemberType Properties) | Sort-Object { $_.InputObject.Name }
        }
        else {
            if ($Node -eq "JobObjects") {
                $p = @{
                    'Objects'=''
                }
                $SourceObjects = New-Object -TypeName PSObject -Prop $p
                $TargetObjects = New-Object -TypeName PSObject -Prop $p
                foreach ($n in $Source.$Node) { $SourceObjects.Objects += $n.Location + "," }
                foreach ($n in $Target.$Node) { $TargetObjects.Objects += $n.Location + "," }
                Write-Host $SourceObjects.Count
                Write-Host $TargetObjects.Count
                $diffs = Compare-Object -ReferenceObject ($SourceObjects | Get-Member -MemberType Properties) -DifferenceObject ($TargetObjects | Get-Member -MemberType Properties) | Sort-Object { $_.InputObject.Name }
            }
            else {
                $diffs = Compare-Object -ReferenceObject ($Source.$Node | Get-Member -MemberType Properties) -DifferenceObject ($Target.$Node | Get-Member -MemberType Properties) | Sort-Object { $_.InputObject.Name }
            }
        }
    }
    else {
        Write-Host -ForegroundColor red -BackgroundColor Black "`nError: Incorrect configuration data for source or target job.`n"
        return
    }

    $processed = ""
    if ($diffs.length -eq 0) {
        Write-Host -ForegroundColor green "`n[Compare] $($Source.Job.Name) and $($Target.Job.Name) are identical.`n"
        return
    }
    else {
        if ($Property.length -eq 0) {
            Write-Host -ForegroundColor yellow "`n[Compare] $($diffs.length) differences found between '$($Source.Job.Name)' and '$($Target.Job.Name)'.`n"
        }
        else {
            Write-Host -ForegroundColor yellow "`n[Compare] $($diffs.length) differences found between [$($Property)] on '$($Source.Job.Name)' and '$($Target.Job.Name)'.`n"
        }
    }
    
    $compare = ""
    foreach ($d in $diffs) {
        $n = $d.InputObject.Name
        if (!$processed.Contains($n + ",")) {
            $processed += $n + ","
            Write-Host -ForegroundColor Yellow "$($n):`n"
            $compare = ""
            $srccmp = ""
            $trgcmp = ""
            foreach($e in $diffs) {
                if ($e.InputObject.Name -eq $n)
                {
                    if ($e.SideIndicator -eq "<=") {
                        $srccmp = " [Source ($($Source.Job.Name))] `n"
                        $srccmp += " $($e.InputObject.Definition) `n"
                    }
                    else {
                        $trgcmp = " [Target ($($Target.Job.Name))] `n"
                        $trgcmp += " $($e.InputObject.Definition) `n"
                    }
                }
            }
            $compare += $srccmp + $trgcmp
            "$($compare) `n"
        }
    }
}

function Find-VHMVBRRepository {
    Param($Id, $Name)
    $result = $null
    try { $result = [Veeam.Backup.Core.CBackupRepository]::Get([Guid]::new($Id)) } catch {}
    if ($result -eq $null) { try { $result = [Veeam.Backup.Core.CBackupRepository]::FindByName($Name) } catch {} }
    return $result
}

function Test-VHMVBRJobExists {
    Param($Id, $Name)
    $result = $false
    if ($Id.length -gt 0) {
        $result = [Veeam.Backup.Core.CBackupJob]::IsExists([Veeam.Backup.Core.CBackupJob]::GetAll(),$j.id)
    }
    elseif ($Name.Length -gt 0) {
        $value = $null
        try { $value = [Veeam.Backup.Core.CBackupJob]::Get($Name) } catch {}
        if ($value -ne $null) { $result = $true }
    }
    return $result
}

function Import-VHMVBRJobOptions {
    param($Options)
    $result = New-VBRJobOptions

    foreach ($i in $result) { 
        foreach ($entry in $i.PSObject.Properties) { 
            $k = $entry.Name
            foreach ($si in $result.$($k).PSObject.Properties) { 
                $sk = $si.Name 
                $attrib = $k+"."+$sk
                $AttributeSupported = $true
                $NestingRequired = $false
                if ($attrib -eq "Options.RootNode") { $AttributeSupported = $false }
                elseif($attrib -eq "ReIPRulesOptions.Rules") { $AttributeSupported = $false }
                elseif($attrib -eq "BackupTargetOptions.FullBackupMonthlyScheduleOptions") { $NestingRequired = $true }
                elseif($attrib -eq "GenerationPolicy.CompactFullBackupMonthlyScheduleOptions") { $NestingRequired = $true }
                elseif($attrib -eq "GenerationPolicy.RecheckBackupMonthlyScheduleOptions") { $NestingRequired = $true }
                elseif($attrib -eq "GenerationPolicy.MonthlyBackup") {  $AttributeSupported = $false }
                elseif($attrib -eq "GenerationPolicy.QuarterlyBackup") { $AttributeSupported = $false }
                elseif($attrib -eq "GenerationPolicy.YearlyBackup") { $AttributeSupported = $false }
                elseif($attrib -eq "GenerationPolicy.ActualRetentionRestorePoints") { $NestingRequired = $true }
                elseif($attrib -eq "GenerationPolicy.IsGfsActiveFullEnabled") { $AttributeSupported = $false }
                elseif($attrib -eq "GenerationPolicy.SyncIntervalStartTime") { $AttributeSupported = $false }
                elseif($attrib -eq "SanIntegrationOptions.DomSanStorageRepositoryOptions") { $AttributeSupported = $false }
                if ($NestingRequired -and $AttributeSupported) {
                    foreach ($ssi in $result.$($k).$($sk).PSObject.Properties) 
                    {
                        $ssk = $ssi.Name 
                        $result.$($k).$($sk).$($ssk) = $Options.$($k).$($sk).$($ssk)
                    }
                }
                elseif ($AttributeSupported) {
                    $result.$($k).$($sk) = $Options.$($k).$($sk)
                } 
            } 
        }
    }

    return $result
}

function Import-VHMVBRJob {
    Param(
        [string]$Path,
        [string]$Name,
        [bool]$Overwrite = $false
    )
    
    $o = (Get-Content $Path | Out-String | ConvertFrom-Json)
    $j = $o.Job
    $jo = $o.JobObjects
    $h = $o.TargetHostId
    $hd = $o.TargetHostDetails
    $r = $o.TargetRepository
    $rh = $o.TargetRepositoryHost
    $rhd = $o.TargetRepositoryHostDetails

    # add veeam snapin 
    #if ( (Get-PSSnapin -Name VeeamPSSnapin -ErrorAction SilentlyContinue) -eq $null ) { Add-PsSnapin VeeamPSSnapin }

    # check if job data is supported
    $JobDataSupported = $false
    $JobType = [Enum]::ToObject([Veeam.Backup.Model.EDbJobType],$j.JobType)
    $JobPlatform = [Veeam.Backup.Common.EPlatform]$j.BackupPlatform.Platform
    if ((($JobPlatform -eq [Veeam.Backup.Common.EPlatform]::EVMware) -and ($JobType -eq [Veeam.Backup.Model.EDbJobType]::Backup))) {
        $JobDataSupported = $true;
    } elseif ((($JobPlatform -eq [Veeam.Backup.Common.EPlatform]::EHyperV) -and ($JobType -eq [Veeam.Backup.Model.EDbJobType]::Backup))) {
        $JobDataSupported = $true;
    } else {
        Write-Host -ForegroundColor red -BackgroundColor black "Importing Job data ($($j.id)) failed. Unsupported Job type ($($JobPlatform)-$($JobType))"
        return $null
    }
    
    if ($Overwrite) {
        ## change all applicable settings
        Write-Host "Importing job data in progress. Overwriting job ($($j.Name))."  

        Write-Host "Importing job data in progress. Preparing job options."  
        $Options = Import-VHMVBRJobOptions -Options $j.Options

        if (($JobPlatform -eq [Veeam.Backup.Common.EPlatform]::EVMware) -and ($JobType -eq [Veeam.Backup.Model.EDbJobType]::Backup))
        {
            $Entities = @()
            foreach($e in $j.JobObjects) { $Entities += Find-VBRViEntity -Name $e.Name -Server $e.Location.Split('\')[0] }
            Write-Host "Importing job data in progress. Adding job objects."  
            Add-VbrViJobObject -Job $j.Name -Entities $Entities
        } elseif (($JobPlatform -eq [Veeam.Backup.Common.EPlatform]::EHyperV) -and ($JobType -eq [Veeam.Backup.Model.EDbJobType]::Backup))
        {
            $Entities = @()
            foreach($e in $j.JobObjects) { $Entities += Find-VBRHvEntity -Name $e.Name -Server $e.Location.Split('\')[0] }
            Write-Host "Importing job data in progress. Adding job objects."  
            Add-VbrHvJobObject -Job $j.Name -Entities $Entities
        }
        Write-Host "Importing job data in progress. Overwriting job options."  
        Set-VbrJobOptions -Job $j.Name -Options $Options | Out-Null
    } else {
        ## create a new job

        # select target job name if unspecified
        if ($Name.Length -eq 0) { $Name = $j.Name }
        $_JobNameSelected = $false; $_JobNameSuffix = 0; $_JobName = $Name
        do {
            if (Test-VHMVBRJobExists -Name $Name) { $Name = $_JobName.Split('_')[0] + "_" + $_JobNameSuffix; $_JobNameSuffix++ }
            else { $_JobNameSelected = $true }
        } While (!$_JobNameSelected)

        # select target job id
        if (Test-VHMVBRJobExists -Id $j.Id)
        { 
            Write-Host  -ForegroundColor Yellow "Warning: Job id ($($j.Id)) already exists.`r`nCreating new job ($($Name)). Override with -Overwrite $true."
        } else {
            Write-Host "Importing job data in progress. Creating new job ($($Name))."
        }

        # select target job repository
        $TargetRepositoryName = (Find-VHMVBRRepository -Id $j.Info.TargetRepositoryId -Name $r.Name).Name
        if ($TargetRepositoryName -eq $null)
        {
            Write-Host  -ForegroundColor Yellow -BackgroundColor Black "Error: Target Repository $($r.Name) ($($j.Info.TargetRepositoryId)) not available."
        }

        Write-Host "Importing job data in progress. Preparing job options."  
        $Options = Import-VHMVBRJobOptions -Options $j.Options
        if (($JobPlatform -eq [Veeam.Backup.Common.EPlatform]::EVMware) -and ($JobType -eq [Veeam.Backup.Model.EDbJobType]::Backup))
        {
            $Entities = @()
            foreach($e in $jo) { $Entities += Find-VBRViEntity -Name $e.Name -Server $e.Location.Split('\')[0] }
            Write-Host "Importing job data in progress. Adding job objects."  
            Add-VbrViBackupJob -Name $Name -Entity $Entities -BackupRepository $TargetRepositoryName | Out-Null
        } elseif (($JobPlatform -eq [Veeam.Backup.Common.EPlatform]::EHyperV) -and ($JobType -eq [Veeam.Backup.Model.EDbJobType]::Backup))
        {
            $Entities = @()
            foreach($e in $jo) { $Entities += Find-VBRHvEntity -Name $e.Name -Server $e.Location.Split('\')[0] }
            Write-Host "Importing job data in progress. Adding job objects."  
            Add-VbrHvBackupJob -Name $Name -Entity $Entities -BackupRepository $TargetRepositoryName | Out-Null
        }
        Write-Host "Importing job data in progress. Setting job options."  
        Set-VbrJobOptions -Job $Name -Options $Options | Out-Null
    }

    #return $j
}

<#
gc .\veeamhubmodule.psm1 | Select-String "^function (.*) {"  | % { "Export-ModuleMember -Function {0}" -f $_.Matches.groups[1].value }
gc .\veeamhubmodule.psm1 | Select-String "^Export-ModuleMember -Function (.*)"  | % { "`t'{0}'," -f $_.Matches.groups[1].value }
#>

Export-ModuleMember -Function Get-VHMVersion
Export-ModuleMember -Function Get-VHMVBRVersion
Export-ModuleMember -Function New-VHMSQLConnection
Export-ModuleMember -Function Invoke-VHMSQLQuery
Export-ModuleMember -Function Format-VHMSQLQuery
Export-ModuleMember -Function Get-VHMSQLRepository
Export-ModuleMember -Function Get-VHMSQLStoragesOnRepository
Export-ModuleMember -Function Get-VHMVBRWinServer
Export-ModuleMember -Function New-VHM24x7Array
Export-ModuleMember -Function Format-VHMVBRScheduleInfo
Export-ModuleMember -Function New-VHMVBRScheduleInfo
Export-ModuleMember -Function Get-VHMVBRTrafficRule
Export-ModuleMember -Function Update-VHMVBRTrafficRule
Export-ModuleMember -Function New-VHMVBRTrafficRule
Export-ModuleMember -Function Remove-VHMVBRTrafficRule
Export-ModuleMember -Function Add-VHMVBRViGuestProxy
Export-ModuleMember -Function Remove-VHMVBRViGuestProxy
Export-ModuleMember -Function Set-VHMVBRViGuestProxy
Export-ModuleMember -Function Get-VHMVBRViGuestProxy
Export-ModuleMember -Function Add-VHMVBRUserRoleMapping
Export-ModuleMember -Function Remove-VHMVBRUserRoleMapping
Export-ModuleMember -Function Get-VHMVBRUserRoleMapping
Export-ModuleMember -Function Export-VHMVBRJob
Export-ModuleMember -Function Compare-VHMVBRJob
Export-ModuleMember -Function Find-VHMVBRRepository
Export-ModuleMember -Function Test-VHMVBRJobExists
Export-ModuleMember -Function Import-VHMVBRJobOptions
Export-ModuleMember -Function Import-VHMVBRJob