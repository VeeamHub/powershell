param($VBRServer, $VBRCredential, $SQLServer, $SQLDatabase, $SQLCredential, $Mode = 0, $Interval = -1)

import-module .\BR-GetBackupConfigModule.psm1 -Force

if ($VBRServer -eq $null -or $VBRCredential -eq $null) {
    Write-Log "Veeam Backup & Replication server name and credentials required. Cannot continue."
    return
}
if ($SQLServer -eq $null -or $SQLServer -eq $null) {
    Write-Log "MySql server name and credentials required. Cannot continue."
    return
}
$s = @{
    "Name"=$VBRServer
    "Credential"=$VBRCredential
}

$Server = New-Object -TypeName PSObject -Prop $s
$SQLConnection = Connect-SQL -Server $SQLServer -Credential $SQLCredential
InitializeSQLDatabase -Connection $SQLConnection -Database $SQLDatabase
$CollectionMode = $Mode
$CollectionKeepMinutesIfIncremental = $Interval
$CollectionStart = "$((Get-Date).ToString('yyyyMMddHHmmss'))"

# read cachable event data
Write-Log "Reading previous event data from local cache."
$EventCache = @{}
$eventtable = Import-CSV -Path "cache\VBR.Events.csv"
foreach($e in $eventtable) {
    $EventCache[$e.Name] = $e.Value
}

# create new folder based on current collection time
Write-Log "Creating folder $($CollectionStart)-$($Server.Name)) to store data for upload."
$OutputFolder = New-Item -ItemType Directory -Path ".\$($CollectionStart)-$($Server.Name)"

# find last folder that was created
Write-Log "Connecting to Veeam Backup Server ($($Server.Name)) with account ($($Server.Credential.UserName))."

# export backup server information
Write-Log "Collecting host information."
$hostsystems = GetVBRHosts -Server $Server
$backupservers = @{}
foreach($h in $hostsystems.Keys) {
    if ($hostsystems[$h].HostType -eq "Local") {
        $backupservers[$h] = $hostsystems[$h]
    }
}
$backupservers.Values.GetEnumerator() | Select-Object InstanceId, ParentHostId, HostName, HostType, `
                                              HostOSType, HostOSInfo, HostRAM, HostCpuCount, HostCpuCores `
                                      | Export-CSV -Path ".\$($OutputFolder.Name)\VBR.Server.csv"
$backupservers.Values.GetEnumerator() | Select-Object InstanceId, ParentHostId, HostName, HostType, `
                                              HostOSType, HostOSInfo, HostRAM, HostCpuCount, HostCpuCores `
                                      | ForEach-Object { Export-SQL -Objects $_ -Connection $SQLConnection -Database $SQLDatabase -Table "vbr_servers" }

# export proxy server information
Write-Log "Collecting proxy information."
$proxies = GetVBRProxies -Server $Server
foreach($p in $proxies.Keys) {
    $proxy = $proxies[$p]
    if ($hostsystems.ContainsKey($proxy.ParentHostId)) {
        $hostsystem = $hostsystems[$proxy.ParentHostId]
        $proxy.ParentHostName = $hostsystem.HostName
        $proxy.ParentHostOSInfo = $hostsystem.HostOSInfo
        $proxy.ParentHostRAM = $hostsystem.HostRAM
        $proxy.ParentHostCpuCount = $hostsystem.HostCpuCount
        $proxy.ParentHostCpuCores = $hostsystem.HostCpuCores
    }
}
$proxies.Values.GetEnumerator() | Select-Object InstanceId, ParentHostId, ParentHostName, ParentHostOSInfo, `
                                        ParentHostRAM, ParentHostCpuCount, ParentHostCpuCores, ProxyName, `
                                        ProxyType, ProxyTransportMode, ProxyTransportAllowNbdFailover, `
                                        ProxyConcurrentJobs, ProxyVersion, ProxyVersionIsLatest, `
                                        ProxyThrottlingEnabled, ProxyEnabled `
                                 | Export-CSV -Path ".\$($OutputFolder.Name)\VBR.Proxies.csv"
$proxies.Values.GetEnumerator() | Select-Object InstanceId, ParentHostId, ParentHostName, ParentHostOSInfo, `
                                    ParentHostRAM, ParentHostCpuCount, ParentHostCpuCores, ProxyName, `
                                    ProxyType, ProxyTransportMode, ProxyTransportAllowNbdFailover, `
                                    ProxyConcurrentJobs, ProxyVersion, ProxyVersionIsLatest, `
                                    ProxyThrottlingEnabled, ProxyEnabled `
                                | ForEach-Object { Export-SQL -Objects $_ -Connection $SQLConnection -Database $SQLDatabase -Table "vbr_proxies" }

# export repository server information
Write-Log "Collecting repository information."
$repositories = GetVBRRepositories -Server $Server
foreach($r in $repositories.Keys) {
    $repo = $repositories[$r]
    if ($hostsystems.ContainsKey($repo.ParentHostId)) {
        $hostsystem = $hostsystems[$repo.ParentHostId]
        $repo.ParentHostName = $hostsystem.HostName
        $repo.ParentHostOSInfo = $hostsystem.HostOSInfo
        $repo.ParentHostRAM = $hostsystem.HostRAM
        $repo.ParentHostCpuCount = $hostsystem.HostCpuCount
        $repo.ParentHostCpuCores = $hostsystem.HostCpuCores
    }               
}
$repositories.Values.GetEnumerator() | Select-Object InstanceId, ParentHostId, ParentHostName, `
                                              ParentHostOSInfo, ParentHostRAM, ParentHostCpuCount, `
                                              ParentHostCpuCores, RepositoryName, RepositoryType, RepositoryState, `
                                              RepositoryConcurrentJobs, RepositoryVersionIsLatest, RepositoryDiskSize, `
                                              RepositoryDiskFree, RepositoryUsePerObjectChains, RepositoryAvailable `
                                     | Export-CSV -Path ".\$($OutputFolder.Name)\VBR.Repositories.csv"
$repositories.Values.GetEnumerator() | Select-Object InstanceId, ParentHostId, ParentHostName, `
                                              ParentHostOSInfo, ParentHostRAM, ParentHostCpuCount, `
                                              ParentHostCpuCores, RepositoryName, RepositoryType, RepositoryState, `
                                              RepositoryConcurrentJobs, RepositoryVersionIsLatest, RepositoryDiskSize, `
                                              RepositoryDiskFree, RepositoryUsePerObjectChains, RepositoryAvailable `
                                     | ForEach-Object { Export-SQL -Objects $_ -Connection $SQLConnection -Database $SQLDatabase -Table "vbr_repositories" }

# export job history and restore point information
Write-Log "Collecting job history and restore point information."
$config = GetVBRConfig -Server $Server
$backupjobs = @{}
$copyjobs = @{}
$replicajobs = @{}
$jobobjects = $config.JobObjects.JobObjects
$jobevents = $config.Sessions.EventCache
foreach ($j in $config.Jobs.Keys) {
    $job = $config.Jobs[$j]
    if ($job.JobType -eq "Backup") { $backupjobs[$j] = $job }
    elseif ($job.JobType -eq "BackupCopy") { $copyjobs[$j] = $job }
    elseif ($job.JobType -eq "Replica") { $replicajobs[$j] = $job }
}
foreach ($o in $jobobjects.Keys) {
    $object = $jobobjects[$o]
    $hostsystem = $hostsystems[$object.ParentHostId]
    $job = $config.Jobs[$object.ParentJobId]
    $object.ParentJobName = $job.JobName
    $object.ParentHostName = $hostsystem.HostName
}

# there is actually different data for each, eventually need to add specific data based on differences
$backupjobs.Values.GetEnumerator() | Select-Object InstanceId, JobName, JobType, JobPlatform, JobRestorePointsToKeep, `
                                                   JobResult, CreatedBy, CreatedOn, JobNextRunTime, JobLastRunTime, `
                                                   JobEnabled, JobObjects, JobObjectNames, JobObjectIds, JobRestorePoints, `
                                                   JobSizeOnDisk, TargetRepositoryId `
                                   | Export-CSV -Path ".\$($OutputFolder.Name)\VBR.BackupJobs.csv"
$backupjobs.Values.GetEnumerator() | Select-Object InstanceId, JobName, JobType, JobPlatform, JobRestorePointsToKeep, `
                                                   JobResult, CreatedBy, CreatedOn, JobNextRunTime, JobLastRunTime, `
                                                   JobEnabled, JobObjects, JobObjectNames, JobObjectIds, JobRestorePoints, `
                                                   JobSizeOnDisk, TargetRepositoryId `
                                   | ForEach-Object { Export-SQL -Objects $_ -Connection $SQLConnection -Database $SQLDatabase -Table "vbr_backupjobs" }

$copyjobs.Values.GetEnumerator() | Select-Object InstanceId, JobName, JobType, JobPlatform, JobRestorePointsToKeep, `
                                                   JobResult, CreatedBy, CreatedOn, JobNextRunTime, JobLastRunTime, `
                                                   JobEnabled, JobObjects, JobObjectNames, JobObjectIds, JobRestorePoints, `
                                                   JobSizeOnDisk, TargetRepositoryId `
                                   | Export-CSV -Path ".\$($OutputFolder.Name)\VBR.BackupCopyJobs.csv"
$copyjobs.Values.GetEnumerator() | Select-Object InstanceId, JobName, JobType, JobPlatform, JobRestorePointsToKeep, `
                                                   JobResult, CreatedBy, CreatedOn, JobNextRunTime, JobLastRunTime, `
                                                   JobEnabled, JobObjects, JobObjectNames, JobObjectIds, JobRestorePoints, `
                                                   JobSizeOnDisk, TargetRepositoryId `
                                   | ForEach-Object { Export-SQL -Objects $_ -Connection $SQLConnection -Database $SQLDatabase -Table "vbr_copyjobs" }

$replicajobs.Values.GetEnumerator() | Select-Object InstanceId, JobName, JobType, JobPlatform, JobRestorePointsToKeep, `
                                                   JobResult, CreatedBy, CreatedOn, JobNextRunTime, JobLastRunTime, `
                                                   JobEnabled, JobObjects, JobObjectNames, JobObjectIds, JobRestorePoints, `
                                                   JobSizeOnDisk, TargetRepositoryId `
                                   | Export-CSV -Path ".\$($OutputFolder.Name)\VBR.ReplicaJobs.csv"
$replicajobs.Values.GetEnumerator() | Select-Object InstanceId, JobName, JobType, JobPlatform, JobRestorePointsToKeep, `
                                                   JobResult, CreatedBy, CreatedOn, JobNextRunTime, JobLastRunTime, `
                                                   JobEnabled, JobObjects, JobObjectNames, JobObjectIds, JobRestorePoints, `
                                                   JobSizeOnDisk, TargetRepositoryId `
                                   | ForEach-Object { Export-SQL -Objects $_ -Connection $SQLConnection -Database $SQLDatabase -Table "vbr_replicajobs" }

$jobobjects.Values.GetEnumerator() | Select-Object InstanceId, ObjectName, ObjectPlatform, ObjectType, ObjectSource, `
                                                   ParentJobId, ParentJobName, ParentHostId, ParentHostName, ParentHostHierarchyRef `
                                   | Export-CSV -Path ".\$($OutputFolder.Name)\VBR.JobObjects.csv"
$jobobjects.Values.GetEnumerator() | Select-Object InstanceId, ObjectName, ObjectPlatform, ObjectType, ObjectSource, `
                                                   ParentJobId, ParentJobName, ParentHostId, ParentHostName, ParentHostHierarchyRef `
                                   | ForEach-Object { Export-SQL -Objects $_ -Connection $SQLConnection -Database $SQLDatabase -Table "vbr_jobobjects" }
                                   
$jobevents.Keys | Select @{l="InstanceId";e={$_}},@{l="Event";e={$eventcache[$_]}} | Export-CSV -Path ".\$($OutputFolder.Name)\VBR.JobEvents.csv"
$jobevents.Keys | Select @{l="InstanceId";e={$_}},@{l="Event";e={$eventcache[$_]}} | ForEach-Object { Export-SQL -Objects $_ -Connection $SQLConnection -Database $SQLDatabase -Table "vbr_jobevents" }

$restorepoints = $config.RestorePoints.RestorePoints
$jobsessions = $config.Sessions.JobSessions
$jobhistory = @{}
foreach($s in $jobsessions.Keys)
{
    $session = $jobsessions[$s]
    $sessiontasks = $session.SessionTasks
    foreach($t in $sessiontasks.Keys)
    {
        $task = $sessiontasks[$t]
        $r = @{ 
            'InstanceId' = $task.InstanceId
            'ParentJobId' = $session.ParentJobId
            'ParentSessionId' = $task.ParentSessionId
            'SourceObjectId' = $task.TaskObjectId
            'SourceObject' = $task.TaskObject
            'TargetRestorePointId' = $session.TargetRestorePointId
            'TaskEventId'= $task.TaskEventId
            'TaskEventData'= $task.TaskEventData
            'TaskStart'= $task.TaskStart
            'TaskEnd'= $task.TaskEnd
            'TaskState'= $task.TaskState
            'TaskTotalSize'= $task.TaskTotalSize
            'TaskProcessedUsedSize'= $task.TaskProcessedUsedSize
            'TaskTransferredSize'= $task.TaskTransferredSize
            'SessionStart'=$session.SessionStart
            'SessionEnd'=$session.SessionEnd
            'SessionState'=$session.SessionState
            'SessionResult'=$session.SessionResult
            'SessionEventId'=$session.SessionEventId
            'SessionEventData'=$session.SessionEventData
            'SessionBackedUpSize'=$session.SessionBackedUpSize
        }
        $jobhistory[$task.InstanceId] = New-Object -TypeName PSObject -Prop $r
    }
}
$jobhistory.Values.GetEnumerator() | Select-Object InstanceId, ParentJobId, SourceObjectId, `
                                                   SourceObject, TargetRestorePointId, TaskEventId, TaskEventData, `
                                                   TaskStart, TaskEnd, TaskState, TaskTotalSize, TaskProcessedUsedSize, `
                                                   TaskTransferredSize, SessionStart, SessionEnd, SessionState, SessionResult, `
                                                   SessionEventId, SessionEventData, SessionBackedUpSize `
                                   | Export-CSV -Path ".\$($OutputFolder.Name)\VBR.JobHistory.csv"
$jobhistory.Values.GetEnumerator() | Select-Object InstanceId, ParentJobId, SourceObjectId, `
                                                   SourceObject, TargetRestorePointId, TaskEventId, TaskEventData, `
                                                   TaskStart, TaskEnd, TaskState, TaskTotalSize, TaskProcessedUsedSize, `
                                                   TaskTransferredSize, SessionStart, SessionEnd, SessionState, SessionResult, `
                                                   SessionEventId, SessionEventData, SessionBackedUpSize `
                                   | ForEach-Object { Export-SQL -Objects $_ -Connection $SQLConnection -Database $SQLDatabase -Table "vbr_jobhistory" }

$restorepoints.Values.GetEnumerator() | Select-Object InstanceId, RestorePointPath, RestorePointObjects, RestorePointSizeOnDisk, CreatedOn, `
                                                      ParentBackupId, ParentRepositoryExtentId, CompressionRatio, DeduplicationRatio `
                                      | Export-CSV -Path ".\$($OutputFolder.Name)\VBR.RestorePoints.csv"
$restorepoints.Values.GetEnumerator() | Select-Object InstanceId, RestorePointPath, RestorePointObjects, RestorePointSizeOnDisk, CreatedOn, `
                                                      ParentBackupId, ParentRepositoryExtentId, CompressionRatio, DeduplicationRatio `
                                      | ForEach-Object { Export-SQL -Objects $_ -Connection $SQLConnection -Database $SQLDatabase -Table "vbr_restorepoints" }

# write cacheable event data
Write-Log "Storing event data to local cache."
$EventCache.GetEnumerator() | Select-Object Name, Value | Export-CSV -Path "cache\VBR.Events.csv"