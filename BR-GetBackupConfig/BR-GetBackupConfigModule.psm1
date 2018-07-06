$LogFile = "BR-GetBackupConfig.log"
$CurrentPid = ([System.Diagnostics.Process]::GetCurrentProcess()).Id
add-type -Path "$(${env:ProgramFiles(x86)})\MySQL\Connector NET 8.0\Assemblies\v4.5.2\MySql.Data.dll"

enum ECollectionMode {
    Full = 0
    Incremental = 1
}

enum EHostOsType {
    Other = 0
    Xp = 1
    Win2003 = 2
    Win2008 = 3
    Vista = 4
    WinServer2008R2 = 5
    Win7 = 6
    WinServer2012 = 7
    Win8 = 8
    WinServer2012R2 = 9
    Win81 = 10
    WinServer2016 = 11
    Win10 = 12
    WinServer2016Nano = 13
    WinServer201709 = 14
    Linux = 64
    FreeHyperVServer2012 = 107
    FreeHyperVServer2012R2 = 109
    FreeHyperVServer2016 = 111
}

enum EHostType {
    ESX = 0
	VC = 1
	Linux = 2
	Local = 3
	Windows = 5
	ESXi = 6
	HvServer = 7
	HvCluster = 8
	Scvmm = 9
	BackupServer = 10
	SanHost = 11
	SmbServer = 12
	SmbCluster = 13
	VcdSystem = 14
	Cloud = 15
	AzureWinServer = 16
	VmSnapshotStorageHost = 17
	ConfigurationService = 19
	Unknown = 1000
}

enum EJobType
{
    Unknown = 666
    Backup = 0
    Replica = 1
    Copy = 2
    DRV = 3
    RestoreVm = 4
    RestoreVmFiles = 5
    RestoreFiles = 6
    Failover = 7
    QuickMigration = 8
    UndoFailover = 9
    FileLevelRestore = 10
    LinuxFileLevelRestore = 11
    InstantRecovery = 12
    RestoreHdd = 13
    Failback = 14
    PermanentFailover = 15
    UndoFailback = 16
    CommitFailback = 17
    ShellRun = 18
    VolumesDiscover = 19
    HvCtpRescan = 20
    CatCleanup = 21
    SanRescan = 22
    CreateSanSnapshot = 23
    SanMonitor = 30
    DeleteSanSnapshot = 31
    FileTapeBackup = 24
    FileTapeRestore = 25
    TapeValidate = 26
    TapeInventory = 27
    VmTapeBackup = 28
    VmTapeRestore = 29
    TapeErase = 32
    TapeEject = 33
    TapeExport = 34
    TapeImport = 35
    TapeCatalog = 36
    TapeLibrariesDiscover = 37
    PowerShellScript = 38
    VmReconfig = 39
    VmStart = 40
    VcdVAppRestore = 41
    VcdVmRestore = 42
    HierarchyScan = 46
    ViVmConsolidation = 47
    ApplicationLevelRestore = 48
    RemoteReplica = 50
    BackupCopy = 51
    SqlLogBackup = 52
    LicenseAutoUpdate = 53
    OracleLogBackup = 54
    ConfBackup = 100
    ConfRestore = 101
    ConfResynchronize = 102
    WaGlobalDedupFill = 103
    DatabaseMaintenance = 104
    RepositoryMaintenance = 105
    InfrastructureRescan = 106
    HvLabDeploy = 200
    HvLabDelete = 201
    FailoverPlan = 202
    UndoFailoverPlan = 203
    FailoverPlanTask = 204
    UndoFailoverPlanTask = 205
    PlannedFailover = 206
    ViLabDeploy = 207
    ViLabDelete = 208
    ViLabStart = 209
    Cloud = 300
    CloudApplDeploy = 301
    HardwareQuotasProcessing = 302
    ReconnectVpn = 303
    DisconnectVpn = 304
    OrchestratedTask = 304
    ViReplicaRescan = 400
    AzureApplDeploy = 401
    EndpointBackup = 4000
    BackupCacheSync = 4010
    EndpointSqlLogBackup = 4020
    EndpointOracleLogBackup = 4021
    CloudBackup = 5000
    RestoreVirtualDisks = 6000
    InfraItemSave = 7000
    InfraItemUpgrade = 7001
    InfraItemDelete = 7002
    FileLevelRestoreByEnterprise = 8000
    RepositoryEvacuate = 9000
    LogsExport = 10000
    InfraStatistic = 10001
    AzureVmRestore = 11000
    EpAgentManagement = 12000
    EpAgentDiscovery = 12001
    EpAgentTestCreds = 12004
    EpAgentPolicy = 12002
    EpAgentBackup = 12003
    VmbApiPolicyTempJob = 14000
}

enum EPlatform {
    VMware = 0
    HyperV = 1
    Test = 2
    Vcd = 4
    Tape = 5
    WindowsPhysical = 6
    LinuxPhysical = 7
    CustomPlatform = 8
    Configuration = 10
}

enum EJobRetentionPolicy
{
    None = 0
    Simple = 1
    GFS = 2
}

enum EResult
{
	None = -1
	Success = 0
	Warning = 1
	Failed = 2
}

enum EState
{
	Stopped = -1
	Starting = 3
	Stopping = 4
	Working = 5
	Pausing = 6
	Resuming = 7
	WaitingTape = 8
	Idle = 9
	Postprocessing = 10
	WaitingRepository = 11
}

enum ESessionState
{
    Success = 0
	Failed = 2
	Warning = 3
	InProgress = 5
	Pending = 6
}

enum ETaskAlgorithm {
    None = -1
    Full = 0
    Synthetic = 1
    Increment = 2
}

enum EProxyType {
	VMware = 0
	HvOnHost = 1
	HvOffhost = 2
	Tape = 3
	Azure = 4
}

enum EProxyTransportMode {
    Auto = 0
    DirectStorageAccess = 1
    HotAdd = 2
    Nbd = 3
}

enum ERepositoryType {
	WinLocal = 0
	LinuxLocal = 1
	CifsShare = 2
	DDBoost = 3
	Cloud = 4
	HPStoreOnce = 5
	ExaGrid = 6
	Foreign = 7
	SanSnapshotOnly = 8
	HPStoreOnceIntegration = 9
	ExtendableRepository = 10
}

enum ERepositoryState {
	Enabled = 0
	MaintenancePending = 1
	Maintenance = 2
	Evacuating = 4
}

enum EOijSource
{
	Job = 0
	BackupOrFromInfrastructure = 1
}

enum EHvObjectType {
    Host = 0
    Vm = 1
    Cluster = 2
    HostGroup = 3
    Scvmm = 4
    LocalVolume = 5
    Csv = 6
    Tag = 7
}

enum EVcdObjectType {
    VcdSystem = 0
    Organization = 1
    OrgVdc = 2
    Vapp = 3
    Vm = 4
    VappTemplate = 5
    VmTemplate = 6
    Catalog = 7
    Datastore = 8
    ProvVdc = 9
    VC = 10
    OrgVdcStorageProfile = 11
}

enum EViObjectType {
    Vm = 1
    Host = 2
	Cluster = 3
    Template = 4
	VirtualApp = 5
	Vc = 6
	Datacenter = 7
	Folder = 8
	Datastore = 9
	ComputeResource = 10
	ResourcePool = 11
    Tag = 12
    StoragePod = 13
	Category = 14
    VMFTCheckPoint = 15
	VMFTLegacy = 16
}

Function Write-Log {
    param([string]$str)      
    Write-Host $str
    $dt = (Get-Date).toString("yyyy.MM.dd HH:mm:ss")
    $str = "[$dt] <$CurrentPid> $str"
    Add-Content $LogFile -value $str
}

Function Connect-SQL {
    Param($Server, $Credential, $Database = $null, $Port = 3306)
    $ConnectionString = "server=$($Server);port=$Port;uid=$($Credential.GetNetworkCredential().UserName);pwd=$($Credential.GetNetworkCredential().Password)"
    if ($Database -ne $null) {
        $ConnectionString += ";database=$($Database)"
    }
    $SQLConnection = [MySql.Data.MySqlClient.MySqlConnection]@{ConnectionString=$ConnectionString}
    $SQLConnection.Open()
    $sql = New-Object MySql.Data.MySqlClient.MySqlCommand
    $sql.Connection = $SQLConnection
    return $sql
}

Function Invoke-SQLNonQuery {
    param($Connection, $String)
    Write-Log ("[SQL] Executing: $($String)")
    $Connection.CommandText = $String
    $Connection.ExecuteNonQuery()
}

Function InitializeSQLDatabase {
    param($Connection, $Database)
    Invoke-SQLNonQuery -Connection $Connection -String "CREATE DATABASE IF NOT EXISTS ``$($Database)`` DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci;"
    Invoke-SQLNonQuery -Connection $Connection -String "USE ``$($Database)``"
    Invoke-SQLNonQuery -Connection $Connection -String "CREATE TABLE IF NOT EXISTS ``vbr_servers`` (``InstanceId`` varchar(36) NOT NULL,``ParentHostId`` varchar(36),``HostName`` text,``HostType`` text,``HostOSType`` text,``HostOSInfo`` text,``HostRAM`` int,``HostCpuCount`` int,``HostCpuCores`` int, PRIMARY KEY (``InstanceId``)) ENGINE=InnoDB DEFAULT CHARSET=utf8 AUTO_INCREMENT=1 ;"
    Invoke-SQLNonQuery -Connection $Connection -String "CREATE TABLE IF NOT EXISTS ``vbr_proxies`` (``InstanceId`` varchar(36) NOT NULL, ``ParentHostId`` varchar(36), ``ParentHostName`` text, ``ParentHostOSInfo`` text, ``ParentHostRAM`` int, ``ParentHostCpuCount`` int, ``ParentHostCpuCores`` int, ``ProxyName`` text, ``ProxyType`` text, ``ProxyTransportMode`` text, ``ProxyTransportAllowNbdFailover`` text, ``ProxyConcurrentJobs`` text, ``ProxyVersion`` text, ``ProxyVersionIsLatest`` text, ``ProxyThrottlingEnabled`` text, ``ProxyEnabled`` text, PRIMARY KEY (``InstanceId``)) ENGINE=InnoDB DEFAULT CHARSET=utf8 AUTO_INCREMENT=1 ;"
    Invoke-SQLNonQuery -Connection $Connection -String "CREATE TABLE IF NOT EXISTS ``vbr_repositories`` (``InstanceId`` varchar(36) NOT NULL,``ParentHostId`` varchar(36),``ParentHostName`` text,``ParentHostOSInfo`` text,``ParentHostRAM`` int,``ParentHostCpuCount`` int,``ParentHostCpuCores`` int,``RepositoryName`` text,``RepositoryType`` text,``RepositoryState`` text,``RepositoryConcurrentJobs`` text,``RepositoryVersionIsLatest`` text,``RepositoryDiskSize`` long,``RepositoryDiskFree`` long,``RepositoryUsePerObjectChains`` text,``RepositoryAvailable`` text, PRIMARY KEY (``InstanceId``)) ENGINE=InnoDB DEFAULT CHARSET=utf8 AUTO_INCREMENT=1 ;"
    Invoke-SQLNonQuery -Connection $Connection -String "CREATE TABLE IF NOT EXISTS ``vbr_backupjobs`` (``InstanceId`` varchar(36) NOT NULL,``JobName`` text,``JobType`` text,``JobPlatform`` text,``JobRestorePointsToKeep`` text,``JobResult`` text,``CreatedBy`` text,``CreatedOn`` timestamp,``JobNextRunTime`` timestamp,``JobLastRunTime`` timestamp,``JobEnabled`` text,``JobObjects`` text,``JobObjectNames`` text,``JobObjectIds`` text,``JobRestorePoints`` text,``JobSizeOnDisk`` long,``TargetRepositoryId`` varchar(36), PRIMARY KEY (``InstanceId``)) ENGINE=InnoDB DEFAULT CHARSET=utf8 AUTO_INCREMENT=1 ;"
    Invoke-SQLNonQuery -Connection $Connection -String "CREATE TABLE IF NOT EXISTS ``vbr_copyjobs`` (``InstanceId`` varchar(36) NOT NULL,``JobName`` text,``JobType`` text,``JobPlatform`` text,``JobRestorePointsToKeep`` text,``JobResult`` text,``CreatedBy`` text,``CreatedOn`` timestamp,``JobNextRunTime`` timestamp,``JobLastRunTime`` timestamp,``JobEnabled`` text,``JobObjects`` text,``JobObjectNames`` text,``JobObjectIds`` text,``JobRestorePoints`` text,``JobSizeOnDisk`` long,``TargetRepositoryId`` varchar(36), PRIMARY KEY (``InstanceId``)) ENGINE=InnoDB DEFAULT CHARSET=utf8 AUTO_INCREMENT=1 ;"
    Invoke-SQLNonQuery -Connection $Connection -String "CREATE TABLE IF NOT EXISTS ``vbr_replicajobs`` (``InstanceId`` varchar(36) NOT NULL,``JobName`` text,``JobType`` text,``JobPlatform`` text,``JobRestorePointsToKeep`` text,``JobResult`` text,``CreatedBy`` text,``CreatedOn`` timestamp,``JobNextRunTime`` timestamp,``JobLastRunTime`` timestamp,``JobEnabled`` text,``JobObjects`` text,``JobObjectNames`` text,``JobObjectIds`` text,``JobRestorePoints`` text,``JobSizeOnDisk`` long,``TargetRepositoryId`` varchar(36), PRIMARY KEY (``InstanceId``)) ENGINE=InnoDB DEFAULT CHARSET=utf8 AUTO_INCREMENT=1 ;"
    Invoke-SQLNonQuery -Connection $Connection -String "CREATE TABLE IF NOT EXISTS ``vbr_jobobjects`` (``InstanceId`` varchar(36) NOT NULL, ``ObjectName`` text,``ObjectPlatform`` text,``ObjectType`` text,``ObjectSource`` text,``ParentJobId`` varchar(36), ``ParentJobName`` text,``ParentHostId`` varchar(36), ``ParentHostName`` text,``ParentHostHierarchyRef`` text, PRIMARY KEY (``InstanceId``)) ENGINE=InnoDB DEFAULT CHARSET=utf8 AUTO_INCREMENT=1 ;"
    Invoke-SQLNonQuery -Connection $Connection -String "CREATE TABLE IF NOT EXISTS ``vbr_jobevents`` (``InstanceId`` varchar(36) NOT NULL, ``Event`` text, PRIMARY KEY (``InstanceId``)) ENGINE=InnoDB DEFAULT CHARSET=utf8 AUTO_INCREMENT=1 ;"
    Invoke-SQLNonQuery -Connection $Connection -String "CREATE TABLE IF NOT EXISTS ``vbr_jobhistory`` (``InstanceId`` varchar(36) NOT NULL,``ParentJobId`` varchar(36), ``SourceObjectId`` varchar(36),``SourceObject`` text,``TargetRestorePointId`` varchar(36),``TaskEventId`` varchar(36),``TaskEventData`` text,``TaskStart`` timestamp,``TaskEnd`` timestamp,``TaskState`` text,``TaskTotalSize`` long,``TaskProcessedUsedSize`` long,``TaskTransferredSize`` long,``SessionStart`` timestamp,``SessionEnd`` timestamp,``SessionState`` text,``SessionResult`` text,``SessionEventId`` varchar(36),``SessionEventData`` text, ``SessionBackedUpSize`` long, PRIMARY KEY (``InstanceId``)) ENGINE=InnoDB DEFAULT CHARSET=utf8 AUTO_INCREMENT=1 ;"
    Invoke-SQLNonQuery -Connection $Connection -String "CREATE TABLE IF NOT EXISTS ``vbr_restorepoints`` (``InstanceId`` varchar(36) NOT NULL,``RestorePointPath`` text,``RestorePointObjects`` text,``RestorePointSizeOnDisk`` long,``CreatedOn`` timestamp,``ParentBackupId`` varchar(36),``ParentRepositoryExtentId`` varchar(36),``CompressionRatio`` int, ``DeduplicationRatio`` int, PRIMARY KEY (``InstanceId``)) ENGINE=InnoDB DEFAULT CHARSET=utf8 AUTO_INCREMENT=1 ;"
}

Function Export-SQL {
    [cmdletbinding()]
    Param ($Objects, $Connection, $Database, $Table)
    foreach($o in $Objects) {
        $SQLCmd = "INSERT INTO $($Table) ("
        foreach($p in $o.PsObject.Members) {
            if ($p.MemberType -eq "NoteProperty") { $SQLCmd += $p.Name + "," }
        }
        $SQLCmd = $SQLCmd.Trim(',')
        $SQLCmd += ") VALUES("
        foreach($p in $o.PsObject.Members) {
            if ($p.MemberType -eq "NoteProperty") {
                $val = "NULL"
                if ($p.TypeNameOfValue -eq "System.Int32") { 
                    if ($p.Value -ne $null) { $val = $p.Value.ToString() }
                    $SQLCmd += $val + ","
                }
                elseif ($p.TypeNameOfValue -eq "System.DateTime") { 
                    if (!($p.Value -eq $null -or $p.Value.Length -eq 0)) { $val = '"' + $p.Value.ToString("yyyy-MM-dd HH:mm:ss") + '"' }
                    $SQLCmd += " " + $p.Name + '=' + $val + ','
                }
                else {
                    if ($p.Value -ne $null) { $val = '"' + $p.Value.ToString() + '"' }
                    $SQLCmd += $val + ','
                }
            }
        }
        $SQLCmd = $SQLCmd.Trim(',')
        $SQLCmd += ") ON DUPLICATE KEY UPDATE "
        foreach($p in $o.PsObject.Members) {
            if ($p.MemberType -eq "NoteProperty") {
                $val = ""
                if ($p.Value -ne $null) { $val = $p.Value.ToString() }
                if ($p.TypeNameOfValue -eq "System.Int32") { 
                    if ($p.Value -eq $null -or $p.Value.Length -eq 0) { $val = "NULL" }
                    $SQLCmd += " " + $p.Name + "=" + $val + ","
                }
                elseif ($p.TypeNameOfValue -eq "System.DateTime") { 
                    if ($p.Value -eq $null -or $p.Value.Length -eq 0) { $val = "NULL" }
                    else { $val = $p.Value.ToString("yyyy-MM-dd HH:mm:ss") }
                    $SQLCmd += " " + $p.Name + '="' + $val + '",'
                }
                else {
                    $SQLCmd += " " + $p.Name + '="' + $val + '",'
                }
            }
        }
        $SQLCmd = $SQLCmd.Trim(',')
        Invoke-SQLNonQuery -Connection $Connection -Database $Database -Table $Table -String $SQLCmd
    }
}

Function QueryWmi {
    param($Server, $Namespace = "root\VeeamBS", $Class)
    $result = $null
    $qs = [System.DateTime]::Now
    try { $result = Get-WmiObject -ComputerName $($Server.Name) -Namespace "root\VeeamBS" -Class $Class -Credential $($Server.Credential) }
    catch { $qe = ([System.DateTime]::Now).Subtract($qs)
        Write-Log("[WMI] Query  (" + $Server.Name + "\" + $Namespace + "\" + $Class + ") failed after " + $qe.Milliseconds + " ms with error: " + $_.Exception.Message)
    }
    $qe = ([System.DateTime]::Now).Subtract($qs)
    Write-Log("[WMI] Query (" + $Server.Name + "\" + $Namespace + "\" + $Class + ") completed in " + $qe.Milliseconds + " ms.")
    return $result
}

Function ResolveHostName {
    param($HostName) 
    $result = $HostName
    try { $rs = [system.net.dns]::Resolve($HostName) }
    catch {} 
    if ($rs -ne $null -and $rs.AddressList.Count -gt 0) {
        try { $result = [system.net.dns]::GetHostByAddress($rs.AddressList[0]).HostName }
        catch {}
    }
    return $result
}

Function GetVBRHosts {
    param($Server)
    $hosts = @{}
    $objects = QueryWmi -Server $Server -Class "HostSystem"
    foreach($obj in $objects) {
        $hostname = $obj.Name
        if ($obj.DnsName.Length -gt 0) { $hostname =$obj.DnsName }
        if ($hostname -Like "This server") { $hostname = $Server.Name }
        $hostname = ResolveHostName $hostname
        $h = @{
                'InstanceId'=$obj.InstanceUid
                'ParentHostId'=$obj.ParentHostUid
                'HostName'=$hostname
                'HostType'=([EHostType]$obj.Type).ToString()
                'HostOSType'=([EHostOsType]$obj.OsType).ToString()
                'HostOSInfo'=$obj.Info
                'HostRAM'=[math]::Round($obj.RamTotalSize/[math]::Pow(1024,2))
                'HostCpuCount'=$obj.CpuCount
                'HostCpuCores'=$obj.CoresCount
        }
        $hosts["$($obj.InstanceUid)"] = New-Object -TypeName PSObject -Prop $h
    }
    return $hosts
}

# Function GetVBRProxies

Function GetVBRProxies {
    param($Server)
    $proxies = @{}
    $objects = QueryWmi -Server $Server -Class "Proxy"
    foreach($obj in $objects) {
        $h = @{
                'InstanceId'=$obj.InstanceUid
                'ParentHostId'=$obj.HostUid
                'ParentHostName'=$null
                'ParentHostOSInfo'=$null
                'ParentHostRAM'=$null
                'ParentHostCpuCount'=$null
                'ParentHostCpuCores'=$null
                'ProxyName'=$obj.Name
                'ProxyType'=([EProxyType]$obj.Type).ToString()
                'ProxyTransportMode'=([EProxyTransportMode]$obj.TransportMode).ToString()
                'ProxyTransportAllowNbdFailover'=$obj.FailoverToNbdAllowed
                'ProxyConcurrentJobs'=$obj.ConcurrentJobsMax
                'ProxyVersion'=$obj.Version
                'ProxyVersionIsLatest'=(!$obj.OutOfDate)
                'ProxyThrottlingEnabled'=$obj.ThrottlingEnabled
                'ProxyEnabled'=(!$obj.Disabled)
        }
        $proxies["$($obj.InstanceUid)"] = New-Object -TypeName PSObject -Prop $h
    }
    return $proxies
}

# Function GetVBRRepositories

Function GetVBRRepositories {
    param($Server)
    $repositories = @{}
    $objects = QueryWmi -Server $Server -Class "Repository"
    foreach($obj in $objects) {
        $h = @{
                'InstanceId'=$obj.InstanceUid
                'ParentHostId'=$obj.HostUid
                'ParentHostName'=$null
                'ParentHostOSInfo'=$null
                'ParentHostRAM'=$null
                'ParentHostCpuCount'=$null
                'ParentHostCpuCores'=$null
                'RepositoryName'=$obj.Name
                'RepositoryType'=([ERepositoryType]$obj.Type).ToString()
                'RepositoryState'=([ERepositoryState]$obj.State).ToString()
                'RepositoryConcurrentJobs'=$obj.ConcurrentJobsMax
                'RepositoryVersionIsLatest'=(!$obj.OutOfDate)
                'RepositoryDiskSize'=[math]::Round($obj.Capacity/[math]::Pow(1024,2))
                'RepositoryDiskFree'=[math]::Round($obj.FreeSpace/[math]::Pow(1024,2))
                'RepositoryUsePerObjectChains'=$obj.OneBackupFilePerVm
                'RepositoryAvailable'=$obj.IsAvailable
        }
        $repositories["$($obj.InstanceUid)"] = New-Object -TypeName PSObject -Prop $h
    }
    return $repositories
}

Function GetVBRLastJobSession {
    param($Sessions, $ParentId)
    $lastruntime = $null
    if ($Sessions.ParentCache.ContainsKey($ParentId)) {
        $jindex = $Sessions.ParentCache[$ParentId].Split(',')
        $n = [DateTime]::Now
        $lastdiff = -1
        foreach($s in $jindex) {
            if ($s.Length -gt 0) {
                $sessionstart = $Sessions.JobSessions[$s].SessionStart
                if ($sessionstart -ne $null) {
                    $currdiff = $n.Subtract($sessionstart).TotalMinutes
                    $currtime = $sessionstart
                    if (($lastdiff -eq -1) -or ($lastdiff -gt $currdiff)) {
                        $lastruntime = $sessionstart
                        $lastdiff = $currdiff
                    }
                }
            }
        }
    }
    return $lastruntime
}

Function GetVBRJobRestorePointData {
    Param($Backups, $RestorePoints, $ParentId)
    $rcount = $null
    $rsize = 0;
    if ($Backups.ParentCache.ContainsKey($ParentId)) {
        $bindex = $Backups.ParentCache[$ParentId].Split(',')
        $rcount = 0
        foreach($b in $bindex) {
            if (($b.Length -gt 0) -and ($RestorePoints.ParentCache.ContainsKey($b))) {
                $rindex = $RestorePoints.ParentCache[$b].Split(',')
                foreach($r in $rindex) {
                    if ($r.Length -gt 0) { 
                        $rcount++
                        $rsize += [long] $RestorePoints.RestorePoints[$r].RestorePointSizeOnDisk
                    }
                }
            }
        }
    }
    $o = @{
        'RestorePointCount'=$rcount
        'RestorePointSize'=$rsize
    }
    return New-Object -TypeName PSObject -Prop $o;
}

Function GetVBRJobObjectData {
    Param($JobObjects, $ParentId)
    $oijcount = $null
    $oijidlist = ""
    $oijnamelist = ""
    if ($JobObjects.ParentCache.ContainsKey($ParentId)) {
        $jindex = $JobObjects.ParentCache[$ParentId].Split(',')
        $oijcount = 0
        foreach($j in $jindex) {
            if ($j.Length -gt 0) {
                $oijcount ++;
                $oijidlist += "$j,"
                $oijnamelist += "$($JobObjects.JobObjects[$j].ObjectName),"
            }
        }
    }
    $o = @{
        'JobObjectCount'=$oijcount
        'JobObjectNames'=$oijnamelist
        'JobObjectIds'=$oijidlist
    }
    return New-Object -TypeName PSObject -Prop $o;
}

Function GetVBRConfig {
    param($Server)
    $jobs = @{}
    $objects = QueryWmi -Server $Server -Class "Job"
    
    $Backups = GetVBRBackups -Server $Server
    $RestorePoints = GetVBRRestorePoints -Server $Server
    $Sessions = GetVBRJobSessions -Server $Server
    $JobObjects = GetVBRJobObjects -Server $Server

    foreach($obj in $objects) {
        $jobtype = ([EJobType]$obj.Type).ToString()
        # support Backup and Replica only for now
        if ($jobtype -eq 'Backup' -or $jobtype -eq 'Replica' -or $jobtype -eq 'BackupCopy') {

            $nextruntime = $null
            if ($obj.IsNextRunTimeUtcSpecified) {
                $nextruntime = $obj.NextRuntimeUtc
            }
            
            $lastruntime = (GetVBRLastJobSession -Sessions $Sessions -ParentId "$($obj.InstanceUid)")
            $rpdata = (GetVBRJobRestorePointData -Backups $Backups -RestorePoints $RestorePoints -ParentId "$($obj.InstanceUid)")
            $oijdata = (GetVBRJobObjectData -JobObjects $JobObjects -ParentId "$($obj.InstanceUid)")

            $j = @{
                'InstanceId'=$obj.InstanceUid
                'JobName'=$obj.Name
                'JobType'=$jobtype
                'JobPlatform'=([EPlatform]$obj.Platform).ToString()
                'JobRestorePointsToKeep'=$obj.RetentionPolicy
                'JobResult'=([EResult]$obj.Status).ToString()
                'CreatedBy'=$obj.CreatedBy
                'CreatedOn'=ConvertToDateTime($obj.CreationDateUtc)
                'JobNextRunTime'=ConvertToDateTime($nextruntime)
                'JobLastRunTime'=$lastruntime
                'JobEnabled'=$obj.ScheduleEnabled
                'JobObjects'=$oijdata.JobObjectCount
                'JobObjectNames'=$oijdata.JobObjectNames
                'JobObjectIds'=$oijdata.JobObjectIds
                'JobRestorePoints'=$rpdata.RestorePointCount
                'JobSizeOnDisk'=$rpdata.RestorePointSize
                'TargetRepositoryId'=$obj.RepositoryId
            }
            $jobs["$($obj.InstanceUid)"] = New-Object -TypeName PSObject -Prop $j
        }
    }
    $o = @{
        'Jobs'=$jobs
        'JobObjects'=$jobobjects
        'Sessions'=$Sessions
        'Backups'=$Backups
        'RestorePoints'=$RestorePoints
    }
    return New-Object -TypeName PSObject -Prop $o;
}

# Function GetVBRBackups
Function GetVBRBackups {
    param($Server)
    $backups = @{}
    $ParentCache = @{}
    $objects = QueryWmi -Server $Server -Class "Backup"
    foreach($obj in $objects) { 
        $jobtype = ([EJobType]$obj.JobType).ToString()
        # support Backup and Replica only for now
        if ($jobtype -eq 'Backup' -or $jobtype -eq 'Replica' -or $jobtype -eq 'BackupCopy') {
            $r = @{
                'InstanceId'=$obj.InstanceUid
                'JobName'=$obj.Name
                'JobType'=$jobtype
                'JobPlatform'=([EPlatform]$obj.Platform).ToString()
                'ParentJobId'=$obj.JobUid
                'ParentRepositoryId'=$obj.RepositoryUid
            }
            $ParentCache["$($obj.JobUid)"] += $obj.InstanceUid + ","
            $backups["$($obj.InstanceUid)"] = New-Object -TypeName PSObject -Prop $r
        }
    }
    $o = @{
        'Backups'=$backups
        'ParentCache'=$ParentCache
    }
    return New-Object -TypeName PSObject -Prop $o;
}

# Function GetVBRRestorePoints
Function GetVBRRestorePoints {
    param($Server, $Mode = [ECollectionMode]::Full, $Interval = -1)
    $restorepoints = @{}
     $ParentCache = @{}
    $objects = QueryWmi -Server $Server -Class "RestorePoint"
    foreach($obj in $objects) { 
        $createdon = $obj.BackupDateUtc
        if (($Mode -eq [ECollectionMode]::Full) -or ($Mode -eq [ECollectionMode]::Incremental -and (IsNullOrWithin -TimeString $createdon -LessThanXMinutesAgo $Interval))) {
            $r = @{
                'InstanceId'=$obj.InstanceUid
                'RestorePointPath'=$obj.FilePath
                'RestorePointObjects'=$obj.VmRestorePoints
                'RestorePointSizeOnDisk'=[math]::Round($obj.BackupSize/[math]::Pow(1024,2))
                'CreatedOn'=ConvertToDateTime($createdon)
                'ParentBackupId'=$obj.BackupUid
                'ParentRepositoryExtentId'=$obj.RepoExtendId
                'CompressionRatio'=$obj.CompressionRatio
                'DeduplicationRatio'=$obj.DeduplicationRatio
            }
            $ParentCache["$($obj.BackupUid)"] += $obj.InstanceUid + ","
            $restorepoints["$($obj.InstanceUid)"] = New-Object -TypeName PSObject -Prop $r
        }
    }
    $o = @{
        'RestorePoints'=$restorepoints
        'ParentCache'=$ParentCache
    }
    return New-Object -TypeName PSObject -Prop $o;
}



Function GetIPAddressesFromString {
    param($String)
    $result = @()
    $regex=[regex]"\b(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b"
    foreach($match in $regex.Matches($String)) {
        $result += $match.Value
    }
    return $result
}

Function ParseVBREventData {
    param($Message, $Objects)
    $result = @{}
    $values = @{}
    $count = 0

    # remove unique message data and store seperately
    $regex=[regex]"(?:VM\s'(.*)'\s\(ref:\s'(.*)'\))"
    foreach($match in $regex.Matches($Message)) {
        $values[$count++] = $match.Groups[1].Value;
        $Message = $Message.Replace("$($match.Groups[1].Value)","__$($count)") 
        $values[$count++] = $match.Groups[2].Value;
        $Message = $Message.Replace("$($match.Groups[2].Value)","__$($count)") 
    }
    $ipaddresses = GetIPAddressesFromString -String $Message
    foreach($ip in $ipaddresses) {
        $values[$count++] = $ip;
        $Message = $Message.Replace("$ip","__$($count)") 
    }
    $regex=[regex]"(?:Timeout: (.*) sec)"
    foreach($match in $regex.Matches($Message)) {
        $values[$count++] = $match.Groups[1].Value;
        $Message = $Message.Replace("$($match.Groups[1].Value)","__$($count)") 
    }
    $regex=[regex]"(?:undo failover for (.*))"
    foreach($match in $regex.Matches($Message)) {
        $values[$count++] = $match.Groups[1].Value;
        $Message = $Message.Replace("$($match.Groups[1].Value)","__$($count)") 
    }
    $regex=[regex]"(?:task for VM (.*) Error:)"
    foreach($match in $regex.Matches($Message)) {
        $values[$count++] = $match.Groups[1].Value;
        $Message = $Message.Replace("$($match.Groups[1].Value)","__$($count)") 
    }
    $regex=[regex]"(?:Processing VM: (.*))"
    foreach($match in $regex.Matches($Message)) {
        $values[$count++] = $match.Groups[1].Value;
        $Message = $Message.Replace("$($match.Groups[1].Value)","__$($count)") 
    }
    $regex=[regex]"(?:Processing (.*) Error:)"
    foreach($match in $regex.Matches($Message)) {
        if (!($match.Groups[1].Value -like "*__*")) {
        $values[$count++] = $match.Groups[1].Value;
        $Message = $Message.Replace("$($match.Groups[1].Value)","__$($count)") 
        }
    }
    $regex=[regex]"(?:finished with (warning|error) at (.*))"
    foreach($match in $regex.Matches($Message)) {
        $values[$count++] = $match.Groups[2].Value;
        $Message = $Message.Replace("$($match.Groups[2].Value)","__$($count)") 
    }
    $regex=[regex]"(?:Job finished at (.*))"
    foreach($match in $regex.Matches($Message)) {
        $values[$count++] = $match.Groups[1].Value;
        $Message = $Message.Replace("$($match.Groups[1].Value)","__$($count)") 
    }
    $regex=[regex]"(?:host\s\[(.*)\]\s)"
    foreach($match in $regex.Matches($Message)) {
        $values[$count++] = $match.Groups[1].Value;
        $Message = $Message.Replace("$($match.Groups[1].Value)","__$($count)") 
    }
    $regex=[regex]"(?:datastore\s\[(.*)\]:)"
    foreach($match in $regex.Matches($Message)) {
        $values[$count++] = $match.Groups[1].Value
        $Message = $Message.Replace("$($match.Groups[1].Value)","__$($count)") 
    }
    $regex=[regex]"(?:by\suser\s(.*\.*))"
    foreach($match in $regex.Matches($Message)) {
        $values[$count++] = $match.Groups[1].Value
        $Message = $Message.Replace("$($match.Groups[1].Value)","__$($count)")
    }
    $regex=[regex]"(?:^Processing\s(\w*|\w*\.\w*\.\w*)$)"
    foreach($match in $regex.Matches($Message)) {
        if (!($match.Groups[1].Value -like "*configuration*")) {
            $values[$count++] = $match.Groups[1].Value
            $Message = $Message.Replace("$($match.Groups[1].Value)","__$($count)")
        }
    }
    if ($Objects -ne $null) {
        foreach($obj in $Objects) {
            if ($obj -ne $null -and $obj.Length -gt 0) {
                if ($Message -like "*$($obj)*") { 
                    $values[$count++] = $obj
                    $Message = $Message.Replace("$($obj)","__$($count)") 
                }
            }
        } 
    }
    # transpose generic message and variable ordering
    $regex=[regex]"(?:__(\d){1,2})"
    $index = 0
    $lastmatch = $null
    foreach($match in $regex.Matches($Message)) {
        $currmatch = "$($match.Groups[0].Value)"
        if ($lastmatch -ne $currmatch) { 
            $Message = $Message.Replace("$($match.Groups[0].Value)", "$" + $index)
            $oldindex = $match.Groups[1].Value
            $lastmatch = $currmatch
            $index++
        }
        if ($index -ne $oldindex) {
            $values[$index] = $values[$oldindex]
            $values.Remove($oldindex) 
        }
    }
    $r = @{
        'Event'=$Message
        'Data'=$Values
    }
    return New-Object -TypeName PSObject -Prop $r
}

Function ParseVBREvent {
    param($Message, $Objects = @(), $EventCache = @{})
    $msgid = $null; $msgdata = $null
    if ($Message -ne $null -and $Message.Length -gt 0) {
        $Message = $Message.Trim()
        $msg = ParseVBREventData -Message $Message -Objects $Objects
        $matchevent = $false
        foreach($val in $EventCache.Values) {
            if ($val -eq $msg.Event) { $matchevent = $true; break; }
        }
        if (!$matchevent) { $msgid = [System.Guid]::NewGuid().ToString(); $EventCache[$msgid] = "$($msg.Event)" }
        else { foreach ($k in $EventCache.Keys) { if ($EventCache[$k] -eq "$($msg.Event)") { $msgid = $k; break; }} }
        foreach($k in $msg.Data.Keys | Sort-Object) { $msgdata += $msg.Data[$k] + ";" }
    }
    $r = @{
        'Id'=$msgid
        'Data'=$msgdata
        'EventCache'=$EventCache
    }
    return New-Object -TypeName PSObject -Prop $r
}

Function ConvertToDateTime {
    param($String)
    if ($String -ne $null -and $String.Length -gt 0) {
        $yyyy = $String.Substring(0,4)
        $MM = $String.Substring(4,2)
        $dd = $String.Substring(6,2)
        $hour = $String.Substring(8,2)
        $min = $String.Substring(10,2)
        $sec = $String.Substring(12,2)
        $time = [DateTime]::Parse("$($yyyy)-$($MM)-$($dd)T$($hour):$($min):$($sec)")
        return $time
    }
    else { return $null }
}

Function IsNullOrWithin {
    param($TimeString, $LessThanXMinutesAgo)
    if ($Time -eq $null) { return $true }
    $t = ConvertToDateTime($Time)
    $n = ([DateTime]::Now)
    $diff = $n.Subtract($t)
    return ($diff.TotalMinutes -lt $LessThanXMinutesAgo)
}

# Function GetVBRJobSessions
Function GetVBRJobSessions {
    param($Server, $EventCache = @{}, $Mode = [ECollectionMode]::Full, $Interval = -1)
    $jobsessions = @{}
    $ParentCache = @{}
    $jobsessionrestorepoints = GetVBRJobSessionRestorePoints -Server $Server
    $jobsessiontasks = GetVBRJobSessionTasks -Server $Server -EventCache $EventCache
    $jobsessiontaskparentcache = $jobsessiontasks.ParentCache
    $objects = QueryWmi -Server $Server -Class "JobSession"
    foreach($obj in $objects) { 
        
        $jobtype = ([EJobType]$obj.JobType).ToString()
        # support Backup and Replica only for now
        if ($jobtype -eq 'Backup' -or $jobtype -eq 'Replica' -or $jobtype -eq 'BackupCopy') { 

            $starttime = $obj.StartTimeUtc
            $endtime = $null
            if ($obj.IsEndTimeUtcSpecified) { $endtime = $obj.EndTimeUtc }
            if (($Mode -eq [ECollectionMode]::Full) -or ($Mode -eq [ECollectionMode]::Incremental -and (IsNullOrWithin -TimeString $endtime -LessThanXMinutesAgo $Interval))) {

                $sessiontasks = @{}
                $jobobjectnames = @()
                $jobobjectids = @()
                $sessiontaskids = $jobsessiontaskparentcache["$($obj.InstanceUid)"]
                if ($sessiontaskids -ne $null) {
                    foreach($t in $jobsessiontaskparentcache["$($obj.InstanceUid)"].Split(',')){
                        if ($t.Length -gt 0) {
                            $task = $jobsessiontasks.SessionTasks["$($t)"]
                            $sessiontasks["$($task.InstanceId)"] = $task; 
                            $jobobjectnames += $task.TaskObject
                            $jobobjectids += $task.TaskObjectId
                        }
                    }
                }

                $restorepoint = $null
                if ($jobsessionrestorepoints.ContainsKey("$($obj.InstanceUid)")) {
                    $restorepoint = $jobsessionrestorepoints["$($obj.InstanceUid)"].RestorePointId
                }
                $uniqueobjects = $jobobjectnames
                $uniqueobjects += $obj.JobName
                $uniqueobjects += $obj.JobUid

                $sessiondetails = ParseVBREvent -Message $obj.JobDetails -Objects $uniqueobjects -EventCache $jobsessiontasks.EventCache
                $sessionevent = ParseVBREvent -Message $obj.FailureMessage -Objects $uniqueobjects -EventCache $sessiondetails.EventCache
                $EventCache = $sessionevent.EventCache

                $r = @{
                    'InstanceId'=$obj.InstanceUid
                    'JobName'=$obj.JobName
                    'JobType'=$jobtype
                    'ParentJobId'=$obj.JobUid
                    'SessionDetailId'=$sessiondetails.Id
                    'SessionDetailData'=$sessiondetails.Data
                    'SessionEventId'=$sessionevent.Id
                    'SessionEventData'=$sessionevent.Data
                    'SessionBackedUpSize'=[math]::Round($obj.BackedUpSize/[math]::Pow(1024,2))
                    'OriginalSessionId'=$obj.OriginalSessionId
                    'SessionDuration'=$obj.Duration
                    'SessionStart'=ConvertToDateTime($starttime)
                    'SessionEnd'=ConvertToDateTime($endtime)
                    'SessionState'=([EState]$obj.State).ToString()
                    'SessionResult'=([EResult]$obj.Result).ToString()
                    'SessionTasks'=$sessiontasks
                    'SourceObjectNames'=[string]::Concat($jobobjectnames,",")
                    'SourceObjectIds'=[string]::Concat($jobobjectids,",")
                    'TargetRestorePointId'=$restorepoint
                }
                $ParentCache["$($obj.JobUid)"] += $obj.InstanceUid + ","
                $jobsessions["$($obj.InstanceUid)"] = New-Object -TypeName PSObject -Prop $r
            }
        }
    }
    $o = @{
        'JobSessions'=$jobsessions
        'EventCache'=$EventCache
        'ParentCache'=$ParentCache
    }
    return New-Object -TypeName PSObject -Prop $o;
}

# Function GetVBRJobSessionRestorePoints
Function GetVBRJobSessionRestorePoints {
    $jobsessionstorestorepoints = @{}
    $objects = QueryWmi -Server $Server -Class "JobSessionToRestorePoint"
    foreach($obj in $objects) { 
        $jobsessionid = $obj.Antecedent.Split('=')[1].Replace('"','')
        $r = @{
            'JobSessionId'= $jobsessionid
            'RestorePointId'=$obj.Dependent.Split('=')[1].Replace('"','')
        }
        $jobsessionstorestorepoints["$($jobsessionid)"] = New-Object -TypeName PSObject -Prop $r
    }
    return $jobsessionstorestorepoints
}

# Function GetVBRJobSessionTasks
Function GetVBRJobSessionTasks {
    param($Server, $Session = "*", $EventCache = @{})
    $sessiontasks = @{}
    $ParentCache = @{}
    $objects = QueryWmi -Server $Server -Class "SessionTask" -Filter "WHERE JobSessionUid LIKE $($Session)"
    foreach($obj in $objects) { 
        
        $endtime = $null
        if ($obj.IsEndTimeUtcSpecified) { $endtime = $obj.EndTimeUtc }
        
        $taskdetails = ParseVBREvent -Message $obj.FailureMessage -Objects @("$($obj.VmName)","$($obj.VmUid)") -EventCache $EventCache
        $EventCache = $taskdetails.EventCache

        $r = @{
            'InstanceId'=$obj.InstanceUid
            'ParentSessionId'=$obj.JobSessionUid
            'TaskEventId'=$taskdetails.Id
            'TaskEventData'=$taskdetails.Data
            'TaskDuration'=$obj.Duration
            'TaskStart'=ConvertToDateTime($obj.StartTimeUtc)
            'TaskEnd'=ConvertToDateTime($endtime)
            'TaskState'=([ESessionState]$obj.Status).ToString()
            'TaskTotalObjects'=$obj.TaskTotalObjects
            'TaskProcessedObjects'=$obj.ProcessedObjects
            'TaskTotalSize'=[math]::Round($obj.TotalVmSize/[math]::Pow(1024,2))
            'TaskProcessedUsedSize'=[math]::Round($obj.ProcessedUsedSize/[math]::Pow(1024,2))
            'TaskTransferredSize'=[math]::Round($obj.Transferred/[math]::Pow(1024,2))
            'TaskObject'=$obj.VmName
            'TaskObjectId'=$obj.VmUid
        }
        $ParentCache["$($obj.JobSessionUid)"] += $obj.InstanceUid + ","
        $sessiontasks["$($obj.InstanceUid)"] = New-Object -TypeName PSObject -Prop $r
    }
    $o = @{
        'SessionTasks'=$sessiontasks
        'EventCache'=$EventCache
        'ParentCache'=$ParentCache
    }
    return New-Object -TypeName PSObject -Prop $o;
}

Function GetVBRJobObjects {
    param($Server)
    $jobobjects = @{}
    $ParentCache = @{}
    $objects = QueryWmi -Server $Server -Class "ObjectInJob"
    foreach($obj in $objects) {
            $objecttype = $null
            $objectplatform = ([EPlatform]$obj.Platform).ToString()
            if ($objectplatform -eq "VMware")
            {
                $objecttype = ([EViObjectType]$obj.Type).ToString()
            }
            elseif ($objectplatform -eq "Vcd")
            {
                $objecttype = ([EVcdObjectType]$obj.Type).ToString()
            }
            elseif ($objectplatform -eq "HyperV")
            {
                $objecttype = ([EHvObjectType]$obj.Type).ToString()
            }
            $j = @{
                'InstanceId'=$obj.InstanceUid
                'ObjectName'=$obj.Name
                'ObjectPlatform'=$objectplatform
                'ObjectType'=$objecttype
                'ObjectSource'=([EOijSource]$obj.OijType).ToString()
                'ParentJobId'=$obj.JobUid
                'ParentJobName'=$null
                'ParentHostId'=$obj.HostUid
                'ParentHostName'=$null
                'ParentHostHierarchyRef'=$obj.HierarchyRef
            } 
            $ParentCache["$($obj.JobUid)"] += $obj.InstanceUid + ","
            $jobobjects["$($obj.InstanceUid)"] = New-Object -TypeName PSObject -Prop $j
    }
    $o = @{
        'JobObjects'=$jobobjects
        'ParentCache'=$ParentCache
    }
    return New-Object -TypeName PSObject -Prop $o;
}
