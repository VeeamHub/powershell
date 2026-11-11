# VBRJob [Veeam.Backup.Core.CBackupJob]
``` powershell
$VBRJob = @(Get-VBRJob)[0]
```
* $VBRJob.CanRunByScheduler()  Def [bool ISchedulableJob.CanRunByScheduler()]
* $VBRJob.CheckDeleteAllowed()  Def [void CheckDeleteAllowed()]
* $VBRJob.Delete()  Def [void Delete(Veeam.Backup.Model.CModifiedUserInfo initiator)]
* $VBRJob.DisableScheduler()  Def [void DisableScheduler(Veeam.Backup.Model.CModifiedUserInfo initiator)]
* $VBRJob.EnableScheduler()  Def [void EnableScheduler(Veeam.Backup.Model.CModifiedUserInfo initiator)]
* $VBRJob.FindChildEpSyncBackupJob()  Def [Veeam.Backup.Core.CBackupJob FindChildEpSyncBackupJob()]
* $VBRJob.FindChildOracleLogBackupJob()  Def [Veeam.Backup.Core.CBackupJob FindChildOracleLogBackupJob()]
* $VBRJob.FindChildSqlLogBackupJob()  Def [Veeam.Backup.Core.CBackupJob FindChildSqlLogBackupJob()]
* $VBRJob.FindInitialRepository()  Def [Veeam.Backup.Core.CBackupRepository FindInitialRepository()]
* $VBRJob.FindLastBackup()  Def [Veeam.Backup.Core.CBackup FindLastBackup()]
* $VBRJob.FindLastBaseSession()  Def [Veeam.Backup.Core.CBaseSession FindLastBaseSession()]
* $VBRJob.FindLastOib()  Def [Veeam.Backup.Core.COib FindLastOib(guid objId)]
* $VBRJob.FindLastSession()  Def [Veeam.Backup.Core.CBackupSession FindLastSession(), Veeam.Backup.Model.CBaseSessionInfo IJob.FindLastSession()]
* $VBRJob.FindParentJob()  Def [Veeam.Backup.Core.CBackupJob FindParentJob()]
* $VBRJob.FindSourceWanAccelerator()  Def [Veeam.Backup.Core.CWanAccelerator FindSourceWanAccelerator()]
* $VBRJob.FindTargetRepository()  Def [Veeam.Backup.Core.CBackupRepository FindTargetRepository()]
* $VBRJob.FindTargetWanAccelerator()  Def [Veeam.Backup.Core.CWanAccelerator FindTargetWanAccelerator()]
* $VBRJob.FindUserCryptoKey()  Def [Veeam.Backup.Core.CCryptoKey FindUserCryptoKey()]
* $VBRJob.GetChildJobs()  Def [Veeam.Backup.Core.CBackupJob[] GetChildJobs()]
* $VBRJob.GetCredsId()  Def [guid GetCredsId()]
* $VBRJob.GetDesktopOij()  Def [Veeam.Backup.Core.CObjectInJob GetDesktopOij()]
* $VBRJob.GetDiskEffectiveCompression()  Def [int GetDiskEffectiveCompression(Veeam.Backup.Core.IStorageCommander storageCommander, guid storageId)]
* $VBRJob.GetEndPointOijs()  Def [Veeam.Backup.Core.CEndPointOij[] GetEndPointOijs()]
* $VBRJob.GetFilesEffectiveCompression()  Def [int GetFilesEffectiveCompression(Veeam.Backup.Core.IStorageCommander storageCommander, guid storageId)]
* $VBRJob.GetGuestProcessingProxyHosts()  Def [Veeam.Backup.Core.Common.CHost[] GetGuestProcessingProxyHosts()]
* $VBRJob.GetGuestProxies()  Def [Veeam.Backup.Core.IProxyServer[] GetGuestProxies()]
* $VBRJob.GetHvOijs()  Def [Veeam.Backup.Core.HyperV.CHvOij[] GetHvOijs()]
* $VBRJob.GetImageBackupJob()  Def [Veeam.Backup.Core.CBackupJob GetImageBackupJob()]
* $VBRJob.GetInitialRepository()  Def [Veeam.Backup.Core.CBackupRepository GetInitialRepository()]
* $VBRJob.GetJobDisplayName()  Def [string GetJobDisplayName()]
* $VBRJob.GetLastBackup()  Def [Veeam.Backup.Core.CBackup GetLastBackup()]
* $VBRJob.GetLastResult()  Def [Veeam.Backup.Model.CBaseSessionInfo+EResult GetLastResult(), Veeam.Backup.Model.CBaseSessionInfo+EResult IJob.GetLastResult()]
* $VBRJob.GetLastState()  Def [Veeam.Backup.Model.CBaseSessionInfo+EState GetLastState(), Veeam.Backup.Model.CBaseSessionInfo+EState IJob.GetLastState()]
* $VBRJob.GetObjectsInJob()  Def [Veeam.Backup.Core.CObjectInJob[] GetObjectsInJob()]
* $VBRJob.GetOptions()  Def [Veeam.Backup.Model.CJobOptions GetOptions()]
* $VBRJob.GetProxy()  Def [System.Collections.Generic.IEnumerable[Veeam.Backup.Core.IBackupProxy] GetProxy()]
* $VBRJob.GetScheduleOptions()  Def [Veeam.Backup.Model.ScheduleOptions GetScheduleOptions()]
* $VBRJob.GetSourceOffHostHvProxies()  Def [Veeam.Backup.Core.CHvProxy[] GetSourceOffHostHvProxies()]
* $VBRJob.GetSourceViProxies()  Def [Veeam.Backup.Core.CViProxy[] GetSourceViProxies()]
* $VBRJob.GetSourceWanAccelerator()  Def [Veeam.Backup.Core.CWanAccelerator GetSourceWanAccelerator()]
* $VBRJob.GetTargetHost()  Def [Veeam.Backup.Core.Common.CHost GetTargetHost()]
* $VBRJob.GetTargetOffhostHvProxies()  Def [Veeam.Backup.Core.CHvProxy[] GetTargetOffhostHvProxies()]
* $VBRJob.GetTargetProxies()  Def [System.Collections.Generic.IEnumerable[Veeam.Backup.Core.IBackupProxy] GetTargetProxies()]
* $VBRJob.GetTargetRepository()  Def [Veeam.Backup.Core.CBackupRepository GetTargetRepository()]
* $VBRJob.GetTargetViProxies()  Def [Veeam.Backup.Core.CViProxy[] GetTargetViProxies()]
* $VBRJob.GetTargetWanAccelerator()  Def [Veeam.Backup.Core.CWanAccelerator GetTargetWanAccelerator()]
* $VBRJob.GetVcdOijs()  Def [Veeam.Backup.Core.CObjectInJob[] GetVcdOijs()]
* $VBRJob.GetViOijs()  Def [Veeam.Backup.Core.CObjectInJob[] GetViOijs()]
* $VBRJob.GetVssOptions()  Def [Veeam.Backup.Model.CGuestProcessingOptions GetVssOptions()]
* $VBRJob.IsBackupWindowAllowRunJobNow()  Def [bool IsBackupWindowAllowRunJobNow()]
* $VBRJob.IsCloudTargetJob()  Def [bool IsCloudTargetJob()]
* $VBRJob.IsEpAgentManagementClusterJob()  Def [bool IsEpAgentManagementClusterJob()]
* $VBRJob.IsFileCopy()  Def [bool IsFileCopy()]
* $VBRJob.IsInBackupWindow()  Def [bool IsInBackupWindow(datetime now)]
* $VBRJob.IsSanSnapshotOnly()  Def [bool IsSanSnapshotOnly()]
* $VBRJob.IsStopped()  Def [bool IsStopped()]
* $VBRJob.IsWanAcceleratorEnabled()  Def [bool IsWanAcceleratorEnabled()]
* $VBRJob.LogHvProxySettings()  Def [void LogHvProxySettings()]
* $VBRJob.LogJobOptions()  Def [void LogJobOptions(Veeam.Backup.Model.CDbBackupJobInfo+Mode mode)]
* $VBRJob.LogJobSession()  Def [void LogJobSession(Veeam.Backup.Core.CBackupSession jobSession, Veeam.Backup.Core.IBackupTask[] tasks)]
* $VBRJob.Reload()  Def [void Reload()]
* $VBRJob.ResetScheduleDependentJobs()  Def [void ResetScheduleDependentJobs(Veeam.Backup.Core.CBackupJob parentJob)]
* $VBRJob.SetCreds()  Def [void SetCreds(guid credsId)]
* $VBRJob.SetOptions()  Def [void SetOptions(Veeam.Backup.Model.CJobOptions jobOptions, Veeam.Backup.Model.CModifiedUserInfo initiator)]
* $VBRJob.SetScheduleDependentJobs()  Def [void SetScheduleDependentJobs(Veeam.Backup.Core.CBackupJob job)]
* $VBRJob.SetVssOptions()  Def [void SetVssOptions(Veeam.Backup.Model.CGuestProcessingOptions vssOptions)]
* $VBRJob.SureMoveObj()  Def [void SureMoveObj(guid objectId, Veeam.Backup.Model.CDbObjectInJobInfo+EType sourceType, Veeam.Backup.Model.CDbObjectInJobInfo+EType targetType)]
* $VBRJob.SureObjAdded()  Def [void SureObjAdded(guid objectId, Veeam.Backup.Model.CDbObjectInJobInfo+EType enType)]
* $VBRJob.Update()  Def [void Update()]
* $VBRJob.UpdateNextRunTime()  Def [void UpdateNextRunTime()]
* $VBRJob.AutoScheduleOptions \[Veeam.Backup.Model.CAutoScheduleOptions\]
* $VBRJob.AutoScheduleOptions.Serial()  Def [string Serial()]
* $VBRJob.AutoScheduleOptions.ActiveFullBackupDays \[System.DayOfWeek[]\]
* $VBRJob.AutoScheduleOptions.ActiveFullBackupDays.value__ \[System.Int32\]
* $VBRJob.AutoScheduleOptions.ActiveFullBackupKind \[Veeam.Backup.Model.EFullBackupScheduleKind\] \($null\)
* $VBRJob.AutoScheduleOptions.ActiveFullBackupMonthlyOption \[Veeam.Backup.Model.CDomFullBackupMonthlyScheduleOptions\]
* $VBRJob.AutoScheduleOptions.ActiveFullBackupMonthlyOption.Serial()  Def [void Serial(System.Xml.XmlNode node)]
* $VBRJob.AutoScheduleOptions.ActiveFullBackupMonthlyOption.DayNumberInMonth \[Veeam.Backup.Common.EDayNumberInMonth\]
* $VBRJob.AutoScheduleOptions.ActiveFullBackupMonthlyOption.DayNumberInMonth.value__ \[System.Int32\]
* $VBRJob.AutoScheduleOptions.ActiveFullBackupMonthlyOption.DayOfMonth \[Veeam.Backup.Model.CDayOfMonth\]
* $VBRJob.AutoScheduleOptions.ActiveFullBackupMonthlyOption.DayOfMonth.Build()  Def [string Build()]
* $VBRJob.AutoScheduleOptions.ActiveFullBackupMonthlyOption.DayOfMonth.MatchDate()  Def [bool MatchDate(datetime date)]
* $VBRJob.AutoScheduleOptions.ActiveFullBackupMonthlyOption.DayOfMonth.Day \[System.Int32\]
* $VBRJob.AutoScheduleOptions.ActiveFullBackupMonthlyOption.DayOfMonth.IsLast \[System.Boolean\] \($null\)
* $VBRJob.AutoScheduleOptions.ActiveFullBackupMonthlyOption.DayOfMonth.Value \[System.Int32\]
* $VBRJob.AutoScheduleOptions.ActiveFullBackupMonthlyOption.DayOfWeek \[System.DayOfWeek\]
* $VBRJob.AutoScheduleOptions.ActiveFullBackupMonthlyOption.DayOfWeek.value__ \[System.Int32\]
* $VBRJob.AutoScheduleOptions.ActiveFullBackupMonthlyOption.Months \[Veeam.Backup.Common.EMonth[]\]
* $VBRJob.AutoScheduleOptions.ActiveFullBackupMonthlyOption.Months.value__ \[System.Object[]\]
* $VBRJob.AutoScheduleOptions.PerformActiveFullBackup \[System.Boolean\] \($null\)
* $VBRJob.AutoScheduleOptions.PerformTransformToSyntethic \[System.Boolean\] \($null\)
* $VBRJob.AutoScheduleOptions.TransformToSyntethicDays \[System.DayOfWeek[]\]
* $VBRJob.AutoScheduleOptions.TransformToSyntethicDays.value__ \[System.Int32\]
* $VBRJob.BackupPlatform \[Veeam.Backup.Common.CPlatform\]
* $VBRJob.BackupPlatform.IsExternalInfrastructure()  Def [bool IsExternalInfrastructure()]
* $VBRJob.BackupPlatform.IsWellKnown()  Def [bool IsWellKnown()]
* $VBRJob.BackupPlatform.Serial()  Def [void Serial(System.Xml.XmlNode node)]
* $VBRJob.BackupPlatform.Platform \[Veeam.Backup.Common.EPlatform\] \($null\)
* $VBRJob.BackupPlatform.PlatformId \[System.Guid\]
* $VBRJob.BackupPolicyTag \[System.String\] \($null\)
* $VBRJob.BackupStorageOptions \[Veeam.Backup.Model.CDomBackupStorageOptions\]
* $VBRJob.BackupStorageOptions.TryGetRetainCycles()  Def [System.Nullable[int] TryGetRetainCycles()]
* $VBRJob.BackupStorageOptions.BackupIsAttached \[System.Boolean\]
* $VBRJob.BackupStorageOptions.CheckRetention \[System.Boolean\]
* $VBRJob.BackupStorageOptions.CompressionLevel \[System.Int32\]
* $VBRJob.BackupStorageOptions.EnableDeduplication \[System.Boolean\]
* $VBRJob.BackupStorageOptions.EnableDeletedVmDataRetention \[System.Boolean\]
* $VBRJob.BackupStorageOptions.EnableFullBackup \[System.Boolean\] \($null\)
* $VBRJob.BackupStorageOptions.EnableIntegrityChecks \[System.Boolean\]
* $VBRJob.BackupStorageOptions.KeepFirstFullBackup \[System.Boolean\] \($null\)
* $VBRJob.BackupStorageOptions.RetainCycles \[System.Int32\]
* $VBRJob.BackupStorageOptions.RetainDays \[System.Int32\]
* $VBRJob.BackupStorageOptions.StgBlockSize \[Veeam.Backup.Common.EKbBlockSize\]
* $VBRJob.BackupStorageOptions.StgBlockSize.value__ \[System.Int32\]
* $VBRJob.BackupStorageOptions.StorageEncryptionEnabled \[System.Boolean\] \($null\)
* $VBRJob.BackupTargetOptions \[Veeam.Backup.Model.CDomBackupTargetOptions\]
* $VBRJob.BackupTargetOptions.SetTemporaryAlgorithm()  Def [void SetTemporaryAlgorithm(Veeam.Backup.Model.EAlgorithm algorithm)]
* $VBRJob.BackupTargetOptions.Algorithm \[Veeam.Backup.Model.EAlgorithm\]
* $VBRJob.BackupTargetOptions.Algorithm.value__ \[System.Int32\]
* $VBRJob.BackupTargetOptions.FullBackupDays \[System.DayOfWeek[]\]
* $VBRJob.BackupTargetOptions.FullBackupDays.value__ \[System.Int32\]
* $VBRJob.BackupTargetOptions.FullBackupMonthlyScheduleOptions \[Veeam.Backup.Model.CDomFullBackupMonthlyScheduleOptions\]
* $VBRJob.BackupTargetOptions.FullBackupMonthlyScheduleOptions.Serial()  Def [void Serial(System.Xml.XmlNode node)]
* $VBRJob.BackupTargetOptions.FullBackupMonthlyScheduleOptions.DayNumberInMonth \[Veeam.Backup.Common.EDayNumberInMonth\]
* $VBRJob.BackupTargetOptions.FullBackupMonthlyScheduleOptions.DayNumberInMonth.value__ \[System.Int32\]
* $VBRJob.BackupTargetOptions.FullBackupMonthlyScheduleOptions.DayOfMonth \[Veeam.Backup.Model.CDayOfMonth\]
* $VBRJob.BackupTargetOptions.FullBackupMonthlyScheduleOptions.DayOfMonth.Build()  Def [string Build()]
* $VBRJob.BackupTargetOptions.FullBackupMonthlyScheduleOptions.DayOfMonth.MatchDate()  Def [bool MatchDate(datetime date)]
* $VBRJob.BackupTargetOptions.FullBackupMonthlyScheduleOptions.DayOfMonth.Day \[System.Int32\]
* $VBRJob.BackupTargetOptions.FullBackupMonthlyScheduleOptions.DayOfMonth.IsLast \[System.Boolean\] \($null\)
* $VBRJob.BackupTargetOptions.FullBackupMonthlyScheduleOptions.DayOfMonth.Value \[System.Int32\]
* $VBRJob.BackupTargetOptions.FullBackupMonthlyScheduleOptions.DayOfWeek \[System.DayOfWeek\]
* $VBRJob.BackupTargetOptions.FullBackupMonthlyScheduleOptions.DayOfWeek.value__ \[System.Int32\]
* $VBRJob.BackupTargetOptions.FullBackupMonthlyScheduleOptions.Months \[Veeam.Backup.Common.EMonth[]\]
* $VBRJob.BackupTargetOptions.FullBackupMonthlyScheduleOptions.Months.value__ \[System.Object[]\]
* $VBRJob.BackupTargetOptions.FullBackupScheduleKind \[Veeam.Backup.Model.EFullBackupScheduleKind\] \($null\)
* $VBRJob.BackupTargetOptions.TransformFullToSyntethic \[System.Boolean\] \($null\)
* $VBRJob.BackupTargetOptions.TransformIncrementsToSyntethic \[System.Boolean\] \($null\)
* $VBRJob.BackupTargetOptions.TransformToSyntethicDays \[System.DayOfWeek[]\]
* $VBRJob.BackupTargetOptions.TransformToSyntethicDays.value__ \[System.Int32\]
* $VBRJob.CloudReplicaTargetOptions \[Veeam.Backup.Model.CDomCloudReplicaTargetOptions\]
* $VBRJob.CloudReplicaTargetOptions.CloudConnectHost \[System.Guid\]
* $VBRJob.CloudReplicaTargetOptions.CloudConnectStorage \[System.Guid\]
* $VBRJob.CloudReplicaTargetOptions.ContainerReference \[System.String\] \($null\)
* $VBRJob.Description \[System.String\]
* $VBRJob.FreeBackupImpl \[$null\] \($null\)
* $VBRJob.HvReplicaTargetOptions \[Veeam.Backup.Model.CDomHvReplicaTargetOptions\]
* $VBRJob.HvReplicaTargetOptions.EnableInitialPass \[System.Boolean\] \($null\)
* $VBRJob.HvReplicaTargetOptions.InitialPassDir \[System.String\] \($null\)
* $VBRJob.HvReplicaTargetOptions.InitialSeeding \[System.Boolean\] \($null\)
* $VBRJob.HvReplicaTargetOptions.ReplicaNameSuffix \[System.String\] \($null\)
* $VBRJob.HvReplicaTargetOptions.TargetFolder \[System.String\]
* $VBRJob.HvReplicaTargetOptions.UseNetworkMapping \[System.Boolean\] \($null\)
* $VBRJob.HvReplicaTargetOptions.UseReIP \[System.Boolean\] \($null\)
* $VBRJob.HvReplicaTargetOptions.UseVmMapping \[System.Boolean\] \($null\)
* $VBRJob.HvSourceOptions \[Veeam.Backup.Model.CDomHvSourceOptions\]
* $VBRJob.HvSourceOptions.CanDoCrashConsistent \[System.Boolean\] \($null\)
* $VBRJob.HvSourceOptions.DirtyBlocksNullingEnabled \[System.Boolean\]
* $VBRJob.HvSourceOptions.EnableHvQuiescence \[System.Boolean\] \($null\)
* $VBRJob.HvSourceOptions.ExcludeSwapFile \[System.Boolean\]
* $VBRJob.HvSourceOptions.FailoverToOnHostBackup \[System.Boolean\]
* $VBRJob.HvSourceOptions.GroupSnapshotProcessing \[System.Boolean\]
* $VBRJob.HvSourceOptions.OffHostBackup \[System.Boolean\]
* $VBRJob.HvSourceOptions.UseChangeTracking \[System.Boolean\]
* $VBRJob.Id \[System.Guid\]
* $VBRJob.Info \[Veeam.Backup.Model.CDbBackupJobInfo\]
* $VBRJob.Info.GetAgentLogName()  Def [string GetAgentLogName()]
* $VBRJob.Info.GetAgentLogNameEx()  Def [string GetAgentLogNameEx(string postfix)]
* $VBRJob.Info.HasParent()  Def [bool HasParent()]
* $VBRJob.Info.IncrementVersion()  Def [long IncrementVersion(), long IConcurentTracking.IncrementVersion()]
* $VBRJob.Info.IsBackup()  Def [bool IsBackup()]
* $VBRJob.Info.IsBackupPolicy()  Def [bool IsBackupPolicy()]
* $VBRJob.Info.IsBackupSync()  Def [bool IsBackupSync()]
* $VBRJob.Info.IsCloudReplica()  Def [bool IsCloudReplica()]
* $VBRJob.Info.IsCopy()  Def [bool IsCopy()]
* $VBRJob.Info.IsEpPolicy()  Def [bool IsEpPolicy()]
* $VBRJob.Info.IsFileCopy()  Def [bool IsFileCopy()]
* $VBRJob.Info.IsFileTapeBackup()  Def [bool IsFileTapeBackup()]
* $VBRJob.Info.IsHyperV()  Def [bool IsHyperV()]
* $VBRJob.Info.IsNetwork()  Def [bool IsNetwork()]
* $VBRJob.Info.IsOracleLogBackup()  Def [bool IsOracleLogBackup()]
* $VBRJob.Info.IsReplica()  Def [bool IsReplica()]
* $VBRJob.Info.IsSanSnapshotOnly()  Def [bool IsSanSnapshotOnly()]
* $VBRJob.Info.IsSnapshotReplica()  Def [bool IsSnapshotReplica()]
* $VBRJob.Info.IsSqlLogBackup()  Def [bool IsSqlLogBackup()]
* $VBRJob.Info.IsTapeBackup()  Def [bool IsTapeBackup()]
* $VBRJob.Info.IsVcb()  Def [bool IsVcb()]
* $VBRJob.Info.IsVddk()  Def [bool IsVddk()]
* $VBRJob.Info.IsVmCopy()  Def [bool IsVmCopy()]
* $VBRJob.Info.IsVmTapeBackup()  Def [bool IsVmTapeBackup()]
* $VBRJob.Info.Serial()  Def [string Serial()]
* $VBRJob.Info.SetTargetDir()  Def [void SetTargetDir(Veeam.Backup.Common.CLegacyPath dir)]
* $VBRJob.Info.SetTargetRepositoryId()  Def [void SetTargetRepositoryId(guid id)]
* $VBRJob.Info.TypeToString()  Def [string TypeToString()]
* $VBRJob.Info.UpdateTargetDir()  Def [void UpdateTargetDir(Veeam.Backup.Common.CLegacyPath newTargetDir)]
* $VBRJob.Info.UpdateTargetRepository()  Def [void UpdateTargetRepository(guid repositoryId, string targetFile)]
* $VBRJob.Info.BackupPlatform \[Veeam.Backup.Common.CPlatform\]
* $VBRJob.Info.BackupPlatform.IsExternalInfrastructure()  Def [bool IsExternalInfrastructure()]
* $VBRJob.Info.BackupPlatform.IsWellKnown()  Def [bool IsWellKnown()]
* $VBRJob.Info.BackupPlatform.Serial()  Def [void Serial(System.Xml.XmlNode node)]
* $VBRJob.Info.BackupPlatform.Platform \[Veeam.Backup.Common.EPlatform\] \($null\)
* $VBRJob.Info.BackupPlatform.PlatformId \[System.Guid\]
* $VBRJob.Info.BackupPolicyTag \[System.String\] \($null\)
* $VBRJob.Info.CommonInfo \[Veeam.Backup.Model.CDbJobCommonInfo\]
* $VBRJob.Info.CommonInfo.Description \[System.String\]
* $VBRJob.Info.CommonInfo.ModifiedBy \[Veeam.Backup.Model.CModifiedUserInfo\]
* $VBRJob.Info.CommonInfo.ModifiedBy.Serialize()  Def [string Serialize(), void Serialize(System.Xml.XmlNode node)]
* $VBRJob.Info.CommonInfo.ModifiedBy.FullName \[System.String\]
* $VBRJob.Info.CommonInfo.ModifiedBy.LoginType \[Veeam.Backup.Model.EModifiedUserType\] \($null\)
* $VBRJob.Info.CommonInfo.Name \[System.String\]
* $VBRJob.Info.Description \[System.String\]
* $VBRJob.Info.DisplayName \[System.String\]
* $VBRJob.Info.ExcludedSize \[System.Int64\] \($null\)
* $VBRJob.Info.Id \[System.Guid\]
* $VBRJob.Info.IncludedSize \[System.Int64\]
* $VBRJob.Info.InitialRepositoryId \[System.Guid\]
* $VBRJob.Info.IsContinuousBackupJob \[System.Boolean\] \($null\)
* $VBRJob.Info.IsDeleted \[System.Boolean\] \($null\)
* $VBRJob.Info.IsScheduleEnabled \[System.Boolean\]
* $VBRJob.Info.JobType \[Veeam.Backup.Model.EDbJobType\] \($null\)
* $VBRJob.Info.LatestStatus \[Veeam.Backup.Model.CBaseSessionInfo+EResult\] \($null\)
* $VBRJob.Info.ModifiedBy \[Veeam.Backup.Model.CModifiedUserInfo\]
* $VBRJob.Info.ModifiedBy.Serialize()  Def [string Serialize(), void Serialize(System.Xml.XmlNode node)]
* $VBRJob.Info.ModifiedBy.FullName \[System.String\]
* $VBRJob.Info.ModifiedBy.LoginType \[Veeam.Backup.Model.EModifiedUserType\] \($null\)
* $VBRJob.Info.Name \[System.String\]
* $VBRJob.Info.NameWithDescription \[System.String\]
* $VBRJob.Info.Options \[Veeam.Backup.Common.CDomContainer\]
* $VBRJob.Info.Options.Clone()  Def [Veeam.Backup.Common.CDomContainer Clone()]
* $VBRJob.Info.Options.GetObjectData()  Def [void GetObjectData(System.Runtime.Serialization.SerializationInfo info, System.Runtime.Serialization.StreamingContext context), void ISerializable.GetObjectData(System.Runtime.Serialization.SerializationInfo info, System.Runtime.Serialization.StreamingContext context)]
* $VBRJob.Info.Options.Serial()  Def [void Serial(System.Xml.XmlNode node)]
* $VBRJob.Info.Options.Serialize()  Def [string Serialize()]
* $VBRJob.Info.Options.RootNode \[System.Xml.XmlElement\]
* $VBRJob.Info.OracleEnabled \[System.Boolean\] \($null\)
* $VBRJob.Info.ParentJobId \[$null\] \($null\)
* $VBRJob.Info.ParentScheduleId \[$null\] \($null\)
* $VBRJob.Info.Path \[System.String\]
* $VBRJob.Info.PwdKeyId \[System.Guid\]
* $VBRJob.Info.ScheduleOptions \[Veeam.Backup.Model.ScheduleOptions\]
* $VBRJob.Info.ScheduleOptions.Clone()  Def [Veeam.Backup.Model.ScheduleOptions Clone(), Veeam.Backup.Model.ScheduleOptions ICloneable[ScheduleOptions].Clone(), System.Object ICloneable.Clone()]
* $VBRJob.Info.ScheduleOptions.DisableEverything()  Def [void DisableEverything()]
* $VBRJob.Info.ScheduleOptions.FromXmlData()  Def [Veeam.Backup.Model.ScheduleOptions FromXmlData(Veeam.Backup.Common.COutputXmlData data)]
* $VBRJob.Info.ScheduleOptions.GetDays()  Def [System.DayOfWeek[] GetDays()]
* $VBRJob.Info.ScheduleOptions.Serial()  Def [void Serial(System.Xml.XmlNode node)]
* $VBRJob.Info.ScheduleOptions.BackupAtLock \[System.Boolean\] \($null\)
* $VBRJob.Info.ScheduleOptions.BackupAtLogoff \[System.Boolean\] \($null\)
* $VBRJob.Info.ScheduleOptions.BackupAtStartup \[System.Boolean\] \($null\)
* $VBRJob.Info.ScheduleOptions.BackupAtStorageAttach \[System.Boolean\] \($null\)
* $VBRJob.Info.ScheduleOptions.BackupCompetitionWaitingPeriodMin \[System.Int32\]
* $VBRJob.Info.ScheduleOptions.BackupCompetitionWaitingUnit \[Veeam.Backup.Model.ScheduleOptions+UnitOfTime\]
* $VBRJob.Info.ScheduleOptions.BackupCompetitionWaitingUnit.value__ \[System.Int32\]
* $VBRJob.Info.ScheduleOptions.EjectRemovableStorageOnBackupComplete \[System.Boolean\] \($null\)
* $VBRJob.Info.ScheduleOptions.EndDateTimeLocal \[System.DateTime\]
* $VBRJob.Info.ScheduleOptions.EndDateTimeSpecified \[System.Boolean\] \($null\)
* $VBRJob.Info.ScheduleOptions.FrequencyTimeUnit \[Veeam.Backup.Common.ETimeUnit\]
* $VBRJob.Info.ScheduleOptions.FrequencyTimeUnit.value__ \[System.Int32\]
* $VBRJob.Info.ScheduleOptions.IsContinious \[System.Boolean\] \($null\)
* $VBRJob.Info.ScheduleOptions.IsFakeSchedule \[System.Boolean\] \($null\)
* $VBRJob.Info.ScheduleOptions.IsServerMode \[System.Boolean\] \($null\)
* $VBRJob.Info.ScheduleOptions.LatestRecheckLocal \[System.DateTime\]
* $VBRJob.Info.ScheduleOptions.LatestRunLocal \[System.DateTime\]
* $VBRJob.Info.ScheduleOptions.LimitBackupsFrequency \[System.Boolean\] \($null\)
* $VBRJob.Info.ScheduleOptions.MaxBackupsFrequency \[System.Int32\]
* $VBRJob.Info.ScheduleOptions.NextRun \[System.String\]
* $VBRJob.Info.ScheduleOptions.OptionsBackupWindow \[Veeam.Backup.Model.CBackupWindowOptions\]
* $VBRJob.Info.ScheduleOptions.OptionsBackupWindow.Serial()  Def [void Serial(System.Xml.XmlNode node)]
* $VBRJob.Info.ScheduleOptions.OptionsBackupWindow.BackupWindow \[System.String\]
* $VBRJob.Info.ScheduleOptions.OptionsBackupWindow.IsEnabled \[System.Boolean\] \($null\)
* $VBRJob.Info.ScheduleOptions.OptionsContinuous \[Veeam.Backup.Model.CContinuousOptions\]
* $VBRJob.Info.ScheduleOptions.OptionsContinuous.GetDays()  Def [System.DayOfWeek[] GetDays()]
* $VBRJob.Info.ScheduleOptions.OptionsContinuous.Serial()  Def [void Serial(System.Xml.XmlNode node)]
* $VBRJob.Info.ScheduleOptions.OptionsContinuous.Enabled \[System.Boolean\] \($null\)
* $VBRJob.Info.ScheduleOptions.OptionsContinuous.Schedule \[System.String\]
* $VBRJob.Info.ScheduleOptions.OptionsDaily \[Veeam.Backup.Model.DailyOptions\]
* $VBRJob.Info.ScheduleOptions.OptionsDaily.GetDays()  Def [System.DayOfWeek[] GetDays()]
* $VBRJob.Info.ScheduleOptions.OptionsDaily.Serial()  Def [void Serial(System.Xml.XmlNode node)]
* $VBRJob.Info.ScheduleOptions.OptionsDaily.CompMode \[Veeam.Backup.Model.ECompMode\] \($null\)
* $VBRJob.Info.ScheduleOptions.OptionsDaily.DaysSrv \[System.DayOfWeek[]\]
* $VBRJob.Info.ScheduleOptions.OptionsDaily.DaysSrv.value__ \[System.Object[]\]
* $VBRJob.Info.ScheduleOptions.OptionsDaily.Enabled \[System.Boolean\]
* $VBRJob.Info.ScheduleOptions.OptionsDaily.Kind \[Veeam.Backup.Model.DailyOptions+DailyKinds\] \($null\)
* $VBRJob.Info.ScheduleOptions.OptionsDaily.TimeLocal \[System.DateTime\]
* $VBRJob.Info.ScheduleOptions.OptionsMonthly \[Veeam.Backup.Model.CMonthlyOptions\]
* $VBRJob.Info.ScheduleOptions.OptionsMonthly.Clone()  Def [Veeam.Backup.Model.CMonthlyOptions Clone(), Veeam.Backup.Model.CMonthlyOptions ICloneable[CMonthlyOptions].Clone(), System.Object ICloneable.Clone()]
* $VBRJob.Info.ScheduleOptions.OptionsMonthly.GetDays()  Def [System.DayOfWeek[] GetDays()]
* $VBRJob.Info.ScheduleOptions.OptionsMonthly.Serial()  Def [void Serial(System.Xml.XmlNode node)]
* $VBRJob.Info.ScheduleOptions.OptionsMonthly.DayNumberInMonth \[Veeam.Backup.Common.EDayNumberInMonth\]
* $VBRJob.Info.ScheduleOptions.OptionsMonthly.DayNumberInMonth.value__ \[System.Int32\]
* $VBRJob.Info.ScheduleOptions.OptionsMonthly.DayOfMonth \[Veeam.Backup.Model.CDayOfMonth\]
* $VBRJob.Info.ScheduleOptions.OptionsMonthly.DayOfMonth.Build()  Def [string Build()]
* $VBRJob.Info.ScheduleOptions.OptionsMonthly.DayOfMonth.MatchDate()  Def [bool MatchDate(datetime date)]
* $VBRJob.Info.ScheduleOptions.OptionsMonthly.DayOfMonth.Day \[System.Int32\]
* $VBRJob.Info.ScheduleOptions.OptionsMonthly.DayOfMonth.IsLast \[System.Boolean\] \($null\)
* $VBRJob.Info.ScheduleOptions.OptionsMonthly.DayOfMonth.Value \[System.Int32\]
* $VBRJob.Info.ScheduleOptions.OptionsMonthly.DayOfWeek \[System.DayOfWeek\]
* $VBRJob.Info.ScheduleOptions.OptionsMonthly.DayOfWeek.value__ \[System.Int32\]
* $VBRJob.Info.ScheduleOptions.OptionsMonthly.Enabled \[System.Boolean\] \($null\)
* $VBRJob.Info.ScheduleOptions.OptionsMonthly.Months \[Veeam.Backup.Common.EMonth[]\]
* $VBRJob.Info.ScheduleOptions.OptionsMonthly.Months.value__ \[System.Object[]\]
* $VBRJob.Info.ScheduleOptions.OptionsMonthly.TimeLocal \[System.DateTime\]
* $VBRJob.Info.ScheduleOptions.OptionsPeriodically \[Veeam.Backup.Model.PeriodicallyOptions\]
* $VBRJob.Info.ScheduleOptions.OptionsPeriodically.GetDays()  Def [System.DayOfWeek[] GetDays()]
* $VBRJob.Info.ScheduleOptions.OptionsPeriodically.Serial()  Def [void Serial(System.Xml.XmlNode node)]
* $VBRJob.Info.ScheduleOptions.OptionsPeriodically.Enabled \[System.Boolean\] \($null\)
* $VBRJob.Info.ScheduleOptions.OptionsPeriodically.FullPeriod \[System.Int32\]
* $VBRJob.Info.ScheduleOptions.OptionsPeriodically.HourlyOffset \[System.Int32\] \($null\)
* $VBRJob.Info.ScheduleOptions.OptionsPeriodically.Kind \[Veeam.Backup.Model.PeriodicallyOptions+PeriodicallyKinds\] \($null\)
* $VBRJob.Info.ScheduleOptions.OptionsPeriodically.Schedule \[System.String\]
* $VBRJob.Info.ScheduleOptions.OptionsScheduleAfterJob \[Veeam.Backup.Model.CScheduleAfterJobOptions\]
* $VBRJob.Info.ScheduleOptions.OptionsScheduleAfterJob.Serial()  Def [void Serial(System.Xml.XmlNode node)]
* $VBRJob.Info.ScheduleOptions.OptionsScheduleAfterJob.IsEnabled \[System.Boolean\] \($null\)
* $VBRJob.Info.ScheduleOptions.RepeatNumber \[System.Int32\]
* $VBRJob.Info.ScheduleOptions.RepeatSpecified \[System.Boolean\] \($null\)
* $VBRJob.Info.ScheduleOptions.RepeatTimeUnit \[System.String\]
* $VBRJob.Info.ScheduleOptions.RepeatTimeUnitMs \[System.Int32\]
* $VBRJob.Info.ScheduleOptions.ResumeMissedBackup \[System.Boolean\] \($null\)
* $VBRJob.Info.ScheduleOptions.RetrySpecified \[System.Boolean\]
* $VBRJob.Info.ScheduleOptions.RetryTimeout \[System.Int32\]
* $VBRJob.Info.ScheduleOptions.RetryTimes \[System.Int32\]
* $VBRJob.Info.ScheduleOptions.StartDateTimeLocal \[System.DateTime\]
* $VBRJob.Info.ScheduleOptions.WaitForBackupCompletion \[System.Boolean\]
* $VBRJob.Info.SheduleEnabledTime \[$null\] \($null\)
* $VBRJob.Info.SourceType \[Veeam.Backup.Model.CDbBackupJobInfo+ESourceType\]
* $VBRJob.Info.SourceType.value__ \[System.Int32\]
* $VBRJob.Info.SqlEnabled \[System.Boolean\] \($null\)
* $VBRJob.Info.TargetDir \[Veeam.Backup.Common.CLegacyPath\]
* $VBRJob.Info.TargetDir.AddDelimiterIfNeeded()  Def [Veeam.Backup.Common.CLegacyPath AddDelimiterIfNeeded(string delimiter)]
* $VBRJob.Info.TargetDir.FilterInvalidCharacters()  Def [Veeam.Backup.Common.CLegacyPath FilterInvalidCharacters(Veeam.Backup.Common.EPathCommanderType pathCommanderType)]
* $VBRJob.Info.TargetDir.GetSchema()  Def [System.Xml.Schema.XmlSchema GetSchema(), System.Xml.Schema.XmlSchema IXmlSerializable.GetSchema()]
* $VBRJob.Info.TargetDir.ReadXml()  Def [void ReadXml(System.Xml.XmlReader reader), void IXmlSerializable.ReadXml(System.Xml.XmlReader reader)]
* $VBRJob.Info.TargetDir.Trim()  Def [Veeam.Backup.Common.CLegacyPath Trim()]
* $VBRJob.Info.TargetDir.TrimDelimiter()  Def [Veeam.Backup.Common.CLegacyPath TrimDelimiter(char delimiter)]
* $VBRJob.Info.TargetDir.WriteXml()  Def [void WriteXml(System.Xml.XmlWriter writer), void IXmlSerializable.WriteXml(System.Xml.XmlWriter writer)]
* $VBRJob.Info.TargetDir.IsVbm \[System.Boolean\] \($null\)
* $VBRJob.Info.TargetFile \[System.String\]
* $VBRJob.Info.TargetHostId \[System.Guid\]
* $VBRJob.Info.TargetHostProtocol \[Veeam.Backup.Model.CDBHost+EProtocol\] \($null\)
* $VBRJob.Info.TargetRepositoryId \[System.Guid\]
* $VBRJob.Info.TargetType \[Veeam.Backup.Model.CDbBackupJobInfo+ETargetType\] \($null\)
* $VBRJob.Info.Usn \[System.Int64\]
* $VBRJob.Info.VcbHostId \[System.Guid\]
* $VBRJob.Info.Version \[System.Int64\]
* $VBRJob.Info.VssOptions \[Veeam.Backup.Model.CGuestProcessingOptions\]
* $VBRJob.Info.VssOptions.ApplyAppProcOptions()  Def [void ApplyAppProcOptions(Veeam.Backup.Model.CVssSnapshotOptions vssSnapshotOptions, Veeam.Backup.Model.CSqlBackupOptions sqlBackupOptions, Veeam.Backup.Model.COracleBackupOptions oracleBackupOptions, Veeam.Backup.Model.CSharePointBackupOptions sharePointBackupOptions, Veeam.Backup.Model.CExchangeBackupOptions exchangeBackupOptions, Veeam.Backup.Model.CGuestScriptsOptions scriptsOptions, Veeam.Backup.Model.CGuestFSExcludeOptions guestFSExcludeOptions), void ApplyAppProcOptions(Veeam.Backup.Model.CVssSnapshotOptions vssSnapshotOptions, Veeam.Backup.Model.CSqlBackupOptions sqlBackupOptions, Veeam.Backup.Model.CExchangeBackupOptions exchangeBackupOptions), void ApplyAppProcOptions(Veeam.Backup.Model.CVssSnapshotOptions vssSnapshotOptions), void ApplyAppProcOptions(Veeam.Backup.Model.CVssSnapshotOptions vssSnapshotOptions, Veeam.Backup.Model.CSqlBackupOptions sqlBackupOptions), void ApplyAppProcOptions(Veeam.Backup.Model.CVssSnapshotOptions vssSnapshotOptions, Veeam.Backup.Model.COracleBackupOptions oracleBackupOptions), void ApplyAppProcOptions(Veeam.Backup.Model.CVssSnapshotOptions vssSnapshotOptions, Veeam.Backup.Model.CSharePointBackupOptions sharePointBackupOptions), void ApplyAppProcOptions(Veeam.Backup.Model.CVssSnapshotOptions vssSnapshotOptions, Veeam.Backup.Model.CExchangeBackupOptions exchangeBackupOptions), void ApplyAppProcOptions(Veeam.Backup.Model.CVssSnapshotOptions vssSnapshotOptions, Veeam.Backup.Model.CGuestScriptsOptions scriptsOptions), void ApplyAppProcOptions(Veeam.Backup.Model.CVssSnapshotOptions vssSnapshotOptions, Veeam.Backup.Model.CGuestFSExcludeOptions guestFSExcludeOptions)]
* $VBRJob.Info.VssOptions.ApplyCreds()  Def [void ApplyCreds(guid winCredsId, guid linCredsId)]
* $VBRJob.Info.VssOptions.ApplyGuestFSIndexingOptions()  Def [void ApplyGuestFSIndexingOptions(Veeam.Backup.Model.CGuestFSIndexingOptions winGuestFSIndexingOptions, Veeam.Backup.Model.CGuestFSIndexingOptions linGuestFSIndexingOptions)]
* $VBRJob.Info.VssOptions.Clone()  Def [Veeam.Backup.Model.CGuestProcessingOptions Clone(), Veeam.Backup.Model.CGuestProcessingOptions ICloneable[CGuestProcessingOptions].Clone(), System.Object ICloneable.Clone()]
* $VBRJob.Info.VssOptions.CorrectByPolicyType()  Def [void CorrectByPolicyType(Veeam.Backup.Common.CPlatform platform, Veeam.Backup.Model.EEpPolicyType policyType)]
* $VBRJob.Info.VssOptions.IsBackupOracleRequired()  Def [bool IsBackupOracleRequired()]
* $VBRJob.Info.VssOptions.IsBackupSqlRequired()  Def [bool IsBackupSqlRequired()]
* $VBRJob.Info.VssOptions.IsCustomIndexing()  Def [bool IsCustomIndexing()]
* $VBRJob.Info.VssOptions.IsDontTruncateEnabled()  Def [bool IsDontTruncateEnabled()]
* $VBRJob.Info.VssOptions.IsGuestDbBackupEnabled()  Def [bool IsGuestDbBackupEnabled()]
* $VBRJob.Info.VssOptions.IsGuestFsExcludeOptionsRequired()  Def [bool IsGuestFsExcludeOptionsRequired()]
* $VBRJob.Info.VssOptions.IsIndexingRequired()  Def [bool IsIndexingRequired()]
* $VBRJob.Info.VssOptions.IsLinIndexingRequired()  Def [bool IsLinIndexingRequired()]
* $VBRJob.Info.VssOptions.IsScriptingAllowed()  Def [bool IsScriptingAllowed()]
* $VBRJob.Info.VssOptions.IsScriptingTurnedOn()  Def [bool IsScriptingTurnedOn()]
* $VBRJob.Info.VssOptions.IsSharePointProcessingAllowed()  Def [bool IsSharePointProcessingAllowed()]
* $VBRJob.Info.VssOptions.IsTransactionLogsProcessingAllowed()  Def [bool IsTransactionLogsProcessingAllowed()]
* $VBRJob.Info.VssOptions.IsTruncateSqlAllowed()  Def [bool IsTruncateSqlAllowed()]
* $VBRJob.Info.VssOptions.IsWinIndexingRequired()  Def [bool IsWinIndexingRequired()]
* $VBRJob.Info.VssOptions.ResetLinCreds()  Def [void ResetLinCreds()]
* $VBRJob.Info.VssOptions.ResetLinuxGuestFSCustomIndexing()  Def [void ResetLinuxGuestFSCustomIndexing()]
* $VBRJob.Info.VssOptions.ResetWinCreds()  Def [void ResetWinCreds()]
* $VBRJob.Info.VssOptions.Serial()  Def [void Serial(System.Xml.XmlNode node)]
* $VBRJob.Info.VssOptions.Serialize()  Def [string Serialize()]
* $VBRJob.Info.VssOptions.SetScriptingAllowed()  Def [void SetScriptingAllowed()]
* $VBRJob.Info.VssOptions.SetTransactionLogsProcessingAllowed()  Def [void SetTransactionLogsProcessingAllowed()]
* $VBRJob.Info.VssOptions.AreLinCredsSet \[System.Boolean\] \($null\)
* $VBRJob.Info.VssOptions.AreWinCredsSet \[System.Boolean\] \($null\)
* $VBRJob.Info.VssOptions.Enabled \[System.Boolean\] \($null\)
* $VBRJob.Info.VssOptions.ExchangeBackupOptions \[Veeam.Backup.Model.CExchangeBackupOptions\]
* $VBRJob.Info.VssOptions.ExchangeBackupOptions.Apply()  Def [void Apply(Veeam.Backup.Model.CExchangeBackupOptions options)]
* $VBRJob.Info.VssOptions.ExchangeBackupOptions.TransactionLogsProcessing \[Veeam.Backup.Model.ETransactionLogsProcessing\]
* $VBRJob.Info.VssOptions.ExchangeBackupOptions.TransactionLogsProcessing.value__ \[System.Int32\]
* $VBRJob.Info.VssOptions.ExcludedIndexingFolders \[System.String[]\] \($null\)
* $VBRJob.Info.VssOptions.GuestFSExcludeOptions \[Veeam.Backup.Model.CGuestFSExcludeOptions\]
* $VBRJob.Info.VssOptions.GuestFSExcludeOptions.Apply()  Def [void Apply(Veeam.Backup.Model.CGuestFSExcludeOptions options)]
* $VBRJob.Info.VssOptions.GuestFSExcludeOptions.BackupScope \[Veeam.Backup.Model.EGuestFSBackupScope\] \($null\)
* $VBRJob.Info.VssOptions.GuestFSExcludeOptions.ExcludeList \[System.String[]\] \($null\)
* $VBRJob.Info.VssOptions.GuestFSExcludeOptions.FileExcludeEnabled \[System.Boolean\] \($null\)
* $VBRJob.Info.VssOptions.GuestFSExcludeOptions.IncludeList \[System.String[]\] \($null\)
* $VBRJob.Info.VssOptions.GuestFSIndexingType \[Veeam.Backup.Model.EGuestFSIndexingType\] \($null\)
* $VBRJob.Info.VssOptions.GuestProxyAutoDetect \[System.Boolean\]
* $VBRJob.Info.VssOptions.GuestScriptsOptions \[Veeam.Backup.Model.CGuestScriptsOptions\]
* $VBRJob.Info.VssOptions.GuestScriptsOptions.Apply()  Def [void Apply(Veeam.Backup.Model.CGuestScriptsOptions options)]
* $VBRJob.Info.VssOptions.GuestScriptsOptions.CredsId \[System.Guid\]
* $VBRJob.Info.VssOptions.GuestScriptsOptions.IsAtLeastOneScriptSet \[System.Boolean\] \($null\)
* $VBRJob.Info.VssOptions.GuestScriptsOptions.LinScriptFiles \[Veeam.Backup.Model.CScriptFiles\]
* $VBRJob.Info.VssOptions.GuestScriptsOptions.LinScriptFiles.GetPostScriptFilePathWithoutQuotes()  Def [string GetPostScriptFilePathWithoutQuotes()]
* $VBRJob.Info.VssOptions.GuestScriptsOptions.LinScriptFiles.GetPreScriptFilePathWithoutQuotes()  Def [string GetPreScriptFilePathWithoutQuotes()]
* $VBRJob.Info.VssOptions.GuestScriptsOptions.LinScriptFiles.SetInXmlNode()  Def [void SetInXmlNode(System.Xml.XmlNode parentNode, string nodeName)]
* $VBRJob.Info.VssOptions.GuestScriptsOptions.LinScriptFiles.IsAtLeastOneScriptSet \[System.Boolean\] \($null\)
* $VBRJob.Info.VssOptions.GuestScriptsOptions.LinScriptFiles.PostScriptFilePath \[System.String\] \($null\)
* $VBRJob.Info.VssOptions.GuestScriptsOptions.LinScriptFiles.PreScriptFilePath \[System.String\] \($null\)
* $VBRJob.Info.VssOptions.GuestScriptsOptions.ScriptingMode \[Veeam.Backup.Model.EScriptingMode\] \($null\)
* $VBRJob.Info.VssOptions.GuestScriptsOptions.WinScriptFiles \[Veeam.Backup.Model.CScriptFiles\]
* $VBRJob.Info.VssOptions.GuestScriptsOptions.WinScriptFiles.GetPostScriptFilePathWithoutQuotes()  Def [string GetPostScriptFilePathWithoutQuotes()]
* $VBRJob.Info.VssOptions.GuestScriptsOptions.WinScriptFiles.GetPreScriptFilePathWithoutQuotes()  Def [string GetPreScriptFilePathWithoutQuotes()]
* $VBRJob.Info.VssOptions.GuestScriptsOptions.WinScriptFiles.SetInXmlNode()  Def [void SetInXmlNode(System.Xml.XmlNode parentNode, string nodeName)]
* $VBRJob.Info.VssOptions.GuestScriptsOptions.WinScriptFiles.IsAtLeastOneScriptSet \[System.Boolean\] \($null\)
* $VBRJob.Info.VssOptions.GuestScriptsOptions.WinScriptFiles.PostScriptFilePath \[System.String\] \($null\)
* $VBRJob.Info.VssOptions.GuestScriptsOptions.WinScriptFiles.PreScriptFilePath \[System.String\] \($null\)
* $VBRJob.Info.VssOptions.IgnoreErrors \[System.Boolean\] \($null\)
* $VBRJob.Info.VssOptions.IncludedIndexingFolders \[System.String[]\] \($null\)
* $VBRJob.Info.VssOptions.IsFirstUsage \[System.Boolean\]
* $VBRJob.Info.VssOptions.LinCredsId \[System.Guid\]
* $VBRJob.Info.VssOptions.LinExcludedIndexingFolders \[System.String[]\] \($null\)
* $VBRJob.Info.VssOptions.LinGuestFSIndexingOptions \[Veeam.Backup.Model.CGuestFSIndexingOptions\]
* $VBRJob.Info.VssOptions.LinGuestFSIndexingOptions.Apply()  Def [void Apply(Veeam.Backup.Model.CGuestFSIndexingOptions options)]
* $VBRJob.Info.VssOptions.LinGuestFSIndexingOptions.DisableIndexing()  Def [void DisableIndexing()]
* $VBRJob.Info.VssOptions.LinGuestFSIndexingOptions.Enabled \[System.Boolean\] \($null\)
* $VBRJob.Info.VssOptions.LinGuestFSIndexingOptions.ExcludedFolders \[System.String[]\] \($null\)
* $VBRJob.Info.VssOptions.LinGuestFSIndexingOptions.IncludedFolders \[System.String[]\] \($null\)
* $VBRJob.Info.VssOptions.LinGuestFSIndexingOptions.IsIndexingRequired \[System.Boolean\] \($null\)
* $VBRJob.Info.VssOptions.LinGuestFSIndexingOptions.Type \[Veeam.Backup.Model.EGuestFSIndexingType\] \($null\)
* $VBRJob.Info.VssOptions.LinGuestFSIndexingType \[Veeam.Backup.Model.EGuestFSIndexingType\] \($null\)
* $VBRJob.Info.VssOptions.LinIncludedIndexingFolders \[System.String[]\] \($null\)
* $VBRJob.Info.VssOptions.m_isFirstUsage \[System.Boolean\]
* $VBRJob.Info.VssOptions.OracleBackupOptions \[Veeam.Backup.Model.COracleBackupOptions\]
* $VBRJob.Info.VssOptions.OracleBackupOptions.Apply()  Def [void Apply(Veeam.Backup.Model.COracleBackupOptions options)]
* $VBRJob.Info.VssOptions.OracleBackupOptions.DisableBackupLogs()  Def [void DisableBackupLogs()]
* $VBRJob.Info.VssOptions.OracleBackupOptions.DisableProcessing()  Def [void DisableProcessing()]
* $VBRJob.Info.VssOptions.OracleBackupOptions.AccountType \[Veeam.Backup.Model.EOracleAccountType\] \($null\)
* $VBRJob.Info.VssOptions.OracleBackupOptions.ArchivedLogsMaxAgeHours \[System.Int32\]
* $VBRJob.Info.VssOptions.OracleBackupOptions.ArchivedLogsMaxSizeMb \[System.Int32\]
* $VBRJob.Info.VssOptions.OracleBackupOptions.ArchivedLogsTruncation \[Veeam.Backup.Model.EArchivedLogsTruncation\] \($null\)
* $VBRJob.Info.VssOptions.OracleBackupOptions.BackupLogsEnabled \[System.Boolean\] \($null\)
* $VBRJob.Info.VssOptions.OracleBackupOptions.BackupLogsFrequencyMin \[System.Int32\]
* $VBRJob.Info.VssOptions.OracleBackupOptions.ProxyAutoSelect \[System.Boolean\]
* $VBRJob.Info.VssOptions.OracleBackupOptions.RetainDays \[System.Int32\]
* $VBRJob.Info.VssOptions.OracleBackupOptions.SysdbaCredsId \[System.Guid\]
* $VBRJob.Info.VssOptions.OracleBackupOptions.TransactionLogsProcessing \[Veeam.Backup.Model.ETransactionLogsProcessing\] \($null\)
* $VBRJob.Info.VssOptions.OracleBackupOptions.UseDbBackupRetention \[System.Boolean\]
* $VBRJob.Info.VssOptions.SharePointBackupOptions \[Veeam.Backup.Model.CSharePointBackupOptions\]
* $VBRJob.Info.VssOptions.SharePointBackupOptions.Apply()  Def [void Apply(Veeam.Backup.Model.CSharePointBackupOptions options)]
* $VBRJob.Info.VssOptions.SharePointBackupOptions.BackupEnabled \[System.Boolean\]
* $VBRJob.Info.VssOptions.SharePointBackupOptions.CredsId \[System.Guid\]
* $VBRJob.Info.VssOptions.SqlBackupOptions \[Veeam.Backup.Model.CSqlBackupOptions\]
* $VBRJob.Info.VssOptions.SqlBackupOptions.Apply()  Def [void Apply(Veeam.Backup.Model.CSqlBackupOptions options)]
* $VBRJob.Info.VssOptions.SqlBackupOptions.BackupLogsEnabled \[System.Boolean\] \($null\)
* $VBRJob.Info.VssOptions.SqlBackupOptions.BackupLogsFrequencyMin \[System.Int32\]
* $VBRJob.Info.VssOptions.SqlBackupOptions.CredsId \[System.Guid\]
* $VBRJob.Info.VssOptions.SqlBackupOptions.NeverTruncateLogs \[System.Boolean\] \($null\)
* $VBRJob.Info.VssOptions.SqlBackupOptions.ProxyAutoSelect \[System.Boolean\]
* $VBRJob.Info.VssOptions.SqlBackupOptions.RetainDays \[System.Int32\]
* $VBRJob.Info.VssOptions.SqlBackupOptions.TransactionLogsProcessing \[Veeam.Backup.Model.ETransactionLogsProcessing\]
* $VBRJob.Info.VssOptions.SqlBackupOptions.TransactionLogsProcessing.value__ \[System.Int32\]
* $VBRJob.Info.VssOptions.SqlBackupOptions.UseDbBackupRetention \[System.Boolean\]
* $VBRJob.Info.VssOptions.VssSnapshotOptions \[Veeam.Backup.Model.CVssSnapshotOptions\]
* $VBRJob.Info.VssOptions.VssSnapshotOptions.Apply()  Def [void Apply(Veeam.Backup.Model.CVssSnapshotOptions options)]
* $VBRJob.Info.VssOptions.VssSnapshotOptions.ApplicationProcessingEnabled \[System.Boolean\]
* $VBRJob.Info.VssOptions.VssSnapshotOptions.Enabled \[System.Boolean\] \($null\)
* $VBRJob.Info.VssOptions.VssSnapshotOptions.IgnoreErrors \[System.Boolean\] \($null\)
* $VBRJob.Info.VssOptions.VssSnapshotOptions.IsCopyOnly \[System.Boolean\] \($null\)
* $VBRJob.Info.VssOptions.WinCredsId \[System.Guid\]
* $VBRJob.Info.VssOptions.WinGuestFSIndexingOptions \[Veeam.Backup.Model.CGuestFSIndexingOptions\]
* $VBRJob.Info.VssOptions.WinGuestFSIndexingOptions.Apply()  Def [void Apply(Veeam.Backup.Model.CGuestFSIndexingOptions options)]
* $VBRJob.Info.VssOptions.WinGuestFSIndexingOptions.DisableIndexing()  Def [void DisableIndexing()]
* $VBRJob.Info.VssOptions.WinGuestFSIndexingOptions.Enabled \[System.Boolean\] \($null\)
* $VBRJob.Info.VssOptions.WinGuestFSIndexingOptions.ExcludedFolders \[System.String[]\] \($null\)
* $VBRJob.Info.VssOptions.WinGuestFSIndexingOptions.IncludedFolders \[System.String[]\] \($null\)
* $VBRJob.Info.VssOptions.WinGuestFSIndexingOptions.IsIndexingRequired \[System.Boolean\] \($null\)
* $VBRJob.Info.VssOptions.WinGuestFSIndexingOptions.Type \[Veeam.Backup.Model.EGuestFSIndexingType\] \($null\)
* $VBRJob.IsAgentManagement \[System.Boolean\] \($null\)
* $VBRJob.IsBackup \[System.Boolean\]
* $VBRJob.IsBackupJob \[System.Boolean\]
* $VBRJob.IsBackupPolicy \[System.Boolean\] \($null\)
* $VBRJob.IsBackupSync \[System.Boolean\] \($null\)
* $VBRJob.IsChildJob \[System.Boolean\] \($null\)
* $VBRJob.IsCloudReplica \[System.Boolean\] \($null\)
* $VBRJob.IsContinuous \[System.Boolean\] \($null\)
* $VBRJob.IsEndpointJob \[System.Boolean\] \($null\)
* $VBRJob.IsEpPolicy \[System.Boolean\] \($null\)
* $VBRJob.IsFileTapeBackup \[System.Boolean\] \($null\)
* $VBRJob.IsForeverIncremental \[System.Boolean\]
* $VBRJob.IsFree \[System.Boolean\] \($null\)
* $VBRJob.IsIdle \[System.Boolean\] \($null\)
* $VBRJob.IsInitialReplica \[System.Boolean\] \($null\)
* $VBRJob.IsLegacyReplica \[System.Boolean\] \($null\)
* $VBRJob.IsMappingReplica \[System.Boolean\] \($null\)
* $VBRJob.IsReplica \[System.Boolean\] \($null\)
* $VBRJob.IsRequireRetry \[System.Boolean\] \($null\)
* $VBRJob.IsRunning \[System.Boolean\] \($null\)
* $VBRJob.IsScheduleEnabled \[System.Boolean\]
* $VBRJob.IsSnapshotReplica \[System.Boolean\] \($null\)
* $VBRJob.IsTapeBackup \[System.Boolean\] \($null\)
* $VBRJob.IsVmCopy \[System.Boolean\] \($null\)
* $VBRJob.IsVmTapeBackup \[System.Boolean\] \($null\)
* $VBRJob.JobScriptCommand \[Veeam.Backup.Model.CDomJobScriptCommand\]
* $VBRJob.JobScriptCommand.Serialize()  Def [string Serialize()]
* $VBRJob.JobScriptCommand.Days \[System.DayOfWeek[]\]
* $VBRJob.JobScriptCommand.Days.value__ \[System.Int32\]
* $VBRJob.JobScriptCommand.Frequency \[System.UInt32\]
* $VBRJob.JobScriptCommand.Periodicity \[Veeam.Backup.Model.CDomJobScriptCommand+PeriodicityType\] \($null\)
* $VBRJob.JobScriptCommand.PostCommand \[Veeam.Backup.Model.CCustomCommand\]
* $VBRJob.JobScriptCommand.PostCommand.Clone()  Def [Veeam.Backup.Model.CCustomCommand Clone(), Veeam.Backup.Model.CCustomCommand ICloneable[CCustomCommand].Clone(), System.Object ICloneable.Clone()]
* $VBRJob.JobScriptCommand.PostCommand.CommandLine \[System.String\] \($null\)
* $VBRJob.JobScriptCommand.PostCommand.Days \[System.DayOfWeek[]\]
* $VBRJob.JobScriptCommand.PostCommand.Days.value__ \[System.Int32\]
* $VBRJob.JobScriptCommand.PostCommand.Enabled \[System.Boolean\] \($null\)
* $VBRJob.JobScriptCommand.PostCommand.Frequency \[System.UInt32\]
* $VBRJob.JobScriptCommand.PostCommand.Periodicity \[Veeam.Backup.Model.CCustomCommand+PeriodicityType\] \($null\)
* $VBRJob.JobScriptCommand.PostScriptCommandLine \[System.String\] \($null\)
* $VBRJob.JobScriptCommand.PostScriptEnabled \[System.Boolean\] \($null\)
* $VBRJob.JobScriptCommand.PreCommand \[Veeam.Backup.Model.CCustomCommand\]
* $VBRJob.JobScriptCommand.PreCommand.Clone()  Def [Veeam.Backup.Model.CCustomCommand Clone(), Veeam.Backup.Model.CCustomCommand ICloneable[CCustomCommand].Clone(), System.Object ICloneable.Clone()]
* $VBRJob.JobScriptCommand.PreCommand.CommandLine \[System.String\] \($null\)
* $VBRJob.JobScriptCommand.PreCommand.Days \[System.DayOfWeek[]\]
* $VBRJob.JobScriptCommand.PreCommand.Days.value__ \[System.Int32\]
* $VBRJob.JobScriptCommand.PreCommand.Enabled \[System.Boolean\] \($null\)
* $VBRJob.JobScriptCommand.PreCommand.Frequency \[System.UInt32\]
* $VBRJob.JobScriptCommand.PreCommand.Periodicity \[Veeam.Backup.Model.CCustomCommand+PeriodicityType\] \($null\)
* $VBRJob.JobScriptCommand.PreScriptCommandLine \[System.String\] \($null\)
* $VBRJob.JobScriptCommand.PreScriptEnabled \[System.Boolean\] \($null\)
* $VBRJob.JobTargetType \[Veeam.Backup.Model.EDbJobType\] \($null\)
* $VBRJob.JobType \[Veeam.Backup.Model.EDbJobType\] \($null\)
* $VBRJob.LinkedBackups \[Veeam.Backup.Core.CLinkedBackup[]\] \($null\)
* $VBRJob.LinkedJobIds \[System.Linq.Enumerable+WhereSelectArrayIterator`2[[Veeam.Backup.Core.CLinkedJobs, Veeam.Backup.Core, Version=9.5.0.0, Culture=neutral, PublicKeyToken=bfd684de2276783a],[System.Guid, mscorlib, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089]]\] \($null\)
* $VBRJob.LinkedJobs \[Veeam.Backup.Core.CLinkedJobs[]\] \($null\)
* $VBRJob.LinkedRepositories \[Veeam.Backup.Core.CLinkedBackupRepository[]\] \($null\)
* $VBRJob.LinkedRepositoryIds \[System.Linq.Enumerable+WhereSelectArrayIterator`2[[Veeam.Backup.Core.CLinkedBackupRepository, Veeam.Backup.Core, Version=9.5.0.0, Culture=neutral, PublicKeyToken=bfd684de2276783a],[System.Guid, mscorlib, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089]]\] \($null\)
* $VBRJob.LogNameMainPart \[System.String\]
* $VBRJob.Name \[System.String\]
* $VBRJob.NameWithDescription \[System.String\]
* $VBRJob.NotificationOptions \[Veeam.Backup.Model.CDomNotificationOptions\]
* $VBRJob.NotificationOptions.IsResultMatchesJobOptions()  Def [bool IsResultMatchesJobOptions(Veeam.Backup.Model.CBaseSessionInfo+EResult sessResult), bool IJobNotificationOptions.IsResultMatchesJobOptions(Veeam.Backup.Model.CBaseSessionInfo+EResult sessionResult)]
* $VBRJob.NotificationOptions.Serialize()  Def [string Serialize()]
* $VBRJob.NotificationOptions.EmailNotificationAdditionalAddresses \[System.String\] \($null\)
* $VBRJob.NotificationOptions.EmailNotificationSubject \[System.String\]
* $VBRJob.NotificationOptions.EmailNotifyOnError \[System.Boolean\]
* $VBRJob.NotificationOptions.EmailNotifyOnLastRetryOnly \[System.Boolean\]
* $VBRJob.NotificationOptions.EmailNotifyOnSuccess \[System.Boolean\]
* $VBRJob.NotificationOptions.EmailNotifyOnWaitingTape \[System.Boolean\]
* $VBRJob.NotificationOptions.EmailNotifyOnWarning \[System.Boolean\]
* $VBRJob.NotificationOptions.EmailNotifyTime \[System.DateTime\]
* $VBRJob.NotificationOptions.SendEmailNotification2AdditionalAddresses \[System.Boolean\] \($null\)
* $VBRJob.NotificationOptions.SnmpNotification \[System.Boolean\] \($null\)
* $VBRJob.NotificationOptions.UseCustomEmailNotificationOptions \[System.Boolean\] \($null\)
* $VBRJob.Options \[Veeam.Backup.Model.CJobOptions\]
* $VBRJob.Options.GetAutoScheduleOptions()  Def [Veeam.Backup.Model.CAutoScheduleOptions GetAutoScheduleOptions(), Veeam.Backup.Model.CAutoScheduleOptions GetAutoScheduleOptions(Veeam.Backup.Model.EDbJobType jobType)]
* $VBRJob.Options.BackupStorageOptions \[Veeam.Backup.Model.CDomBackupStorageOptions\]
* $VBRJob.Options.BackupStorageOptions.TryGetRetainCycles()  Def [System.Nullable[int] TryGetRetainCycles()]
* $VBRJob.Options.BackupStorageOptions.BackupIsAttached \[System.Boolean\]
* $VBRJob.Options.BackupStorageOptions.CheckRetention \[System.Boolean\]
* $VBRJob.Options.BackupStorageOptions.CompressionLevel \[System.Int32\]
* $VBRJob.Options.BackupStorageOptions.EnableDeduplication \[System.Boolean\]
* $VBRJob.Options.BackupStorageOptions.EnableDeletedVmDataRetention \[System.Boolean\]
* $VBRJob.Options.BackupStorageOptions.EnableFullBackup \[System.Boolean\] \($null\)
* $VBRJob.Options.BackupStorageOptions.EnableIntegrityChecks \[System.Boolean\]
* $VBRJob.Options.BackupStorageOptions.KeepFirstFullBackup \[System.Boolean\] \($null\)
* $VBRJob.Options.BackupStorageOptions.RetainCycles \[System.Int32\]
* $VBRJob.Options.BackupStorageOptions.RetainDays \[System.Int32\]
* $VBRJob.Options.BackupStorageOptions.StgBlockSize \[Veeam.Backup.Common.EKbBlockSize\]
* $VBRJob.Options.BackupStorageOptions.StgBlockSize.value__ \[System.Int32\]
* $VBRJob.Options.BackupStorageOptions.StorageEncryptionEnabled \[System.Boolean\] \($null\)
* $VBRJob.Options.BackupTargetOptions \[Veeam.Backup.Model.CDomBackupTargetOptions\]
* $VBRJob.Options.BackupTargetOptions.SetTemporaryAlgorithm()  Def [void SetTemporaryAlgorithm(Veeam.Backup.Model.EAlgorithm algorithm)]
* $VBRJob.Options.BackupTargetOptions.Algorithm \[Veeam.Backup.Model.EAlgorithm\]
* $VBRJob.Options.BackupTargetOptions.Algorithm.value__ \[System.Int32\]
* $VBRJob.Options.BackupTargetOptions.FullBackupDays \[System.DayOfWeek[]\]
* $VBRJob.Options.BackupTargetOptions.FullBackupDays.value__ \[System.Int32\]
* $VBRJob.Options.BackupTargetOptions.FullBackupMonthlyScheduleOptions \[Veeam.Backup.Model.CDomFullBackupMonthlyScheduleOptions\]
* $VBRJob.Options.BackupTargetOptions.FullBackupMonthlyScheduleOptions.Serial()  Def [void Serial(System.Xml.XmlNode node)]
* $VBRJob.Options.BackupTargetOptions.FullBackupMonthlyScheduleOptions.DayNumberInMonth \[Veeam.Backup.Common.EDayNumberInMonth\]
* $VBRJob.Options.BackupTargetOptions.FullBackupMonthlyScheduleOptions.DayNumberInMonth.value__ \[System.Int32\]
* $VBRJob.Options.BackupTargetOptions.FullBackupMonthlyScheduleOptions.DayOfMonth \[Veeam.Backup.Model.CDayOfMonth\]
* $VBRJob.Options.BackupTargetOptions.FullBackupMonthlyScheduleOptions.DayOfMonth.Build()  Def [string Build()]
* $VBRJob.Options.BackupTargetOptions.FullBackupMonthlyScheduleOptions.DayOfMonth.MatchDate()  Def [bool MatchDate(datetime date)]
* $VBRJob.Options.BackupTargetOptions.FullBackupMonthlyScheduleOptions.DayOfMonth.Day \[System.Int32\]
* $VBRJob.Options.BackupTargetOptions.FullBackupMonthlyScheduleOptions.DayOfMonth.IsLast \[System.Boolean\] \($null\)
* $VBRJob.Options.BackupTargetOptions.FullBackupMonthlyScheduleOptions.DayOfMonth.Value \[System.Int32\]
* $VBRJob.Options.BackupTargetOptions.FullBackupMonthlyScheduleOptions.DayOfWeek \[System.DayOfWeek\]
* $VBRJob.Options.BackupTargetOptions.FullBackupMonthlyScheduleOptions.DayOfWeek.value__ \[System.Int32\]
* $VBRJob.Options.BackupTargetOptions.FullBackupMonthlyScheduleOptions.Months \[Veeam.Backup.Common.EMonth[]\]
* $VBRJob.Options.BackupTargetOptions.FullBackupMonthlyScheduleOptions.Months.value__ \[System.Object[]\]
* $VBRJob.Options.BackupTargetOptions.FullBackupScheduleKind \[Veeam.Backup.Model.EFullBackupScheduleKind\] \($null\)
* $VBRJob.Options.BackupTargetOptions.TransformFullToSyntethic \[System.Boolean\] \($null\)
* $VBRJob.Options.BackupTargetOptions.TransformIncrementsToSyntethic \[System.Boolean\] \($null\)
* $VBRJob.Options.BackupTargetOptions.TransformToSyntethicDays \[System.DayOfWeek[]\]
* $VBRJob.Options.BackupTargetOptions.TransformToSyntethicDays.value__ \[System.Int32\]
* $VBRJob.Options.CloudReplicaTargetOptions \[Veeam.Backup.Model.CDomCloudReplicaTargetOptions\]
* $VBRJob.Options.CloudReplicaTargetOptions.CloudConnectHost \[System.Guid\]
* $VBRJob.Options.CloudReplicaTargetOptions.CloudConnectStorage \[System.Guid\]
* $VBRJob.Options.CloudReplicaTargetOptions.ContainerReference \[System.String\] \($null\)
* $VBRJob.Options.EpPolicyOptions \[Veeam.Backup.Model.CDomEpPolicyOptions\]
* $VBRJob.Options.EpPolicyOptions.FindPolicyType()  Def [System.Nullable[Veeam.Backup.Model.EEpPolicyType] FindPolicyType()]
* $VBRJob.Options.EpPolicyOptions.BackupAllUsbDrives \[System.Boolean\] \($null\)
* $VBRJob.Options.EpPolicyOptions.BackupSpecifiedItems \[System.Boolean\] \($null\)
* $VBRJob.Options.EpPolicyOptions.BackupSystemState \[System.Boolean\] \($null\)
* $VBRJob.Options.EpPolicyOptions.BackupUserFolders \[System.Boolean\] \($null\)
* $VBRJob.Options.EpPolicyOptions.DisableBackupOverMeteredConnection \[System.Boolean\] \($null\)
* $VBRJob.Options.EpPolicyOptions.ExcludeMasks \[System.String[]\] \($null\)
* $VBRJob.Options.EpPolicyOptions.IncludeFsItems \[Veeam.Backup.Model.CEpFsItem[]\] \($null\)
* $VBRJob.Options.EpPolicyOptions.IncludeMasks \[System.String[]\] \($null\)
* $VBRJob.Options.EpPolicyOptions.IsSnapshotlessMode \[System.Boolean\] \($null\)
* $VBRJob.Options.EpPolicyOptions.LastReportTime \[$null\] \($null\)
* $VBRJob.Options.EpPolicyOptions.PolicyDestType \[Veeam.Backup.Model.EEpPolicyDestType\] \($null\)
* $VBRJob.Options.EpPolicyOptions.PolicySourceType \[Veeam.Backup.Model.EEpPolicySourceType\] \($null\)
* $VBRJob.Options.EpPolicyOptions.PolicyType \[Veeam.Backup.Model.EEpPolicyType\]
* $VBRJob.Options.EpPolicyOptions.PolicyType.value__ \[System.Int32\]
* $VBRJob.Options.EpPolicyOptions.TargetShareType \[Veeam.Backup.Model.EEpPolicyTargetShareType\] \($null\)
* $VBRJob.Options.EpPolicyOptions.VbrAddress \[System.String\] \($null\)
* $VBRJob.Options.EpPolicyOptions.VbrAuthenticationMode \[Veeam.Backup.Model.EVbrAuthenticationMode\] \($null\)
* $VBRJob.Options.EpPolicyOptions.VbrPort \[System.Int32\]
* $VBRJob.Options.EpPolicyOptions.VbrRetentionType \[System.Boolean\] \($null\)
* $VBRJob.Options.FailoverPlanOptions \[Veeam.Backup.Model.CDomFailoverPlanOptions\]
* $VBRJob.Options.FailoverPlanOptions.PostCommandLine \[System.String\] \($null\)
* $VBRJob.Options.FailoverPlanOptions.PostEnabled \[System.Boolean\] \($null\)
* $VBRJob.Options.FailoverPlanOptions.PreCommandLine \[System.String\] \($null\)
* $VBRJob.Options.FailoverPlanOptions.PreEnabled \[System.Boolean\] \($null\)
* $VBRJob.Options.GenerationPolicy \[Veeam.Backup.Model.CDomGenerationPolicy\]
* $VBRJob.Options.GenerationPolicy.CalcGfsPointDateTime()  Def [System.Nullable[datetime] CalcGfsPointDateTime(Veeam.Backup.Model.CStorageInfo+EStorageGFSPeriod period, Veeam.Backup.Common.CDateTimeInterval interval)]
* $VBRJob.Options.GenerationPolicy.GetGFSPointsInPeriod()  Def [Veeam.Backup.Model.CStorageInfo+EStorageGFSPeriod GetGFSPointsInPeriod(Veeam.Backup.Common.CDateTimeInterval interval)]
* $VBRJob.Options.GenerationPolicy.GetNumberOfGfsRetainIntervals()  Def [int GetNumberOfGfsRetainIntervals(Veeam.Backup.Model.CStorageInfo+EStorageGFSPeriod gfsPeriod)]
* $VBRJob.Options.GenerationPolicy.GetPredicateToFindExistedBackup()  Def [System.Func[datetime,bool] GetPredicateToFindExistedBackup(Veeam.Backup.Model.CStorageInfo+EStorageGFSPeriod period, datetime date)]
* $VBRJob.Options.GenerationPolicy.GetPredicateToFindExistedBackupByInterval()  Def [System.Func[Veeam.Backup.Common.CDateTimeInterval,bool] GetPredicateToFindExistedBackupByInterval(Veeam.Backup.Model.CStorageInfo+EStorageGFSPeriod period, datetime date)]
* $VBRJob.Options.GenerationPolicy.GetRpo()  Def [timespan GetRpo()]
* $VBRJob.Options.GenerationPolicy.IntervalAreEquls()  Def [bool IntervalAreEquls(Veeam.Backup.Model.CDateTimeIntervalGFS gfsInterval, Veeam.Backup.Common.CDateTimeInterval interval, Veeam.Backup.Model.CStorageInfo+EStorageGFSPeriod storgePeriods)]
* $VBRJob.Options.GenerationPolicy.IsBackupDate()  Def [bool IsBackupDate(Veeam.Backup.Model.CStorageInfo+EStorageGFSPeriod period, datetime date)]
* $VBRJob.Options.GenerationPolicy.IsFixedSyncIntervalStartTime()  Def [bool IsFixedSyncIntervalStartTime()]
* $VBRJob.Options.GenerationPolicy.IsMonthlyBackupDate()  Def [bool IsMonthlyBackupDate(datetime date)]
* $VBRJob.Options.GenerationPolicy.IsQuarterlyBackupDate()  Def [bool IsQuarterlyBackupDate(datetime date)]
* $VBRJob.Options.GenerationPolicy.IsWeeklyBackupDay()  Def [bool IsWeeklyBackupDay(datetime time)]
* $VBRJob.Options.GenerationPolicy.IsYearlyBackupDate()  Def [bool IsYearlyBackupDate(datetime date)]
* $VBRJob.Options.GenerationPolicy.PickGFSIntervalsByDateInterval()  Def [System.Collections.Generic.IEnumerable[Veeam.Backup.Model.CDateTimeIntervalGFS] PickGFSIntervalsByDateInterval(Veeam.Backup.Common.CDateTimeInterval interval)]
* $VBRJob.Options.GenerationPolicy.WeeklyBackupDateTime()  Def [System.Nullable[datetime] WeeklyBackupDateTime(datetime date), System.Nullable[datetime] WeeklyBackupDateTime(Veeam.Backup.Common.CDateTimeInterval interval)]
* $VBRJob.Options.GenerationPolicy.ActualRetentionRestorePoints \[System.Int32\]
* $VBRJob.Options.GenerationPolicy.CompactFullBackupDays \[System.DayOfWeek[]\]
* $VBRJob.Options.GenerationPolicy.CompactFullBackupDays.value__ \[System.Int32\]
* $VBRJob.Options.GenerationPolicy.CompactFullBackupMonthlyScheduleOptions \[Veeam.Backup.Model.CDomFullBackupMonthlyScheduleOptions\]
* $VBRJob.Options.GenerationPolicy.CompactFullBackupMonthlyScheduleOptions.Serial()  Def [void Serial(System.Xml.XmlNode node)]
* $VBRJob.Options.GenerationPolicy.CompactFullBackupMonthlyScheduleOptions.DayNumberInMonth \[Veeam.Backup.Common.EDayNumberInMonth\]
* $VBRJob.Options.GenerationPolicy.CompactFullBackupMonthlyScheduleOptions.DayNumberInMonth.value__ \[System.Int32\]
* $VBRJob.Options.GenerationPolicy.CompactFullBackupMonthlyScheduleOptions.DayOfMonth \[Veeam.Backup.Model.CDayOfMonth\]
* $VBRJob.Options.GenerationPolicy.CompactFullBackupMonthlyScheduleOptions.DayOfMonth.Build()  Def [string Build()]
* $VBRJob.Options.GenerationPolicy.CompactFullBackupMonthlyScheduleOptions.DayOfMonth.MatchDate()  Def [bool MatchDate(datetime date)]
* $VBRJob.Options.GenerationPolicy.CompactFullBackupMonthlyScheduleOptions.DayOfMonth.Day \[System.Int32\]
* $VBRJob.Options.GenerationPolicy.CompactFullBackupMonthlyScheduleOptions.DayOfMonth.IsLast \[System.Boolean\] \($null\)
* $VBRJob.Options.GenerationPolicy.CompactFullBackupMonthlyScheduleOptions.DayOfMonth.Value \[System.Int32\]
* $VBRJob.Options.GenerationPolicy.CompactFullBackupMonthlyScheduleOptions.DayOfWeek \[System.DayOfWeek\]
* $VBRJob.Options.GenerationPolicy.CompactFullBackupMonthlyScheduleOptions.DayOfWeek.value__ \[System.Int32\]
* $VBRJob.Options.GenerationPolicy.CompactFullBackupMonthlyScheduleOptions.Months \[Veeam.Backup.Common.EMonth[]\]
* $VBRJob.Options.GenerationPolicy.CompactFullBackupMonthlyScheduleOptions.Months.value__ \[System.Object[]\]
* $VBRJob.Options.GenerationPolicy.CompactFullBackupScheduleKind \[Veeam.Backup.Model.EFullBackupScheduleKind\]
* $VBRJob.Options.GenerationPolicy.CompactFullBackupScheduleKind.value__ \[System.Int32\]
* $VBRJob.Options.GenerationPolicy.DailyBackupTime \[System.TimeSpan\]
* $VBRJob.Options.GenerationPolicy.DeletedVmsDataRetentionPeriodDays \[System.Int32\]
* $VBRJob.Options.GenerationPolicy.EnableCompactFull \[System.Boolean\] \($null\)
* $VBRJob.Options.GenerationPolicy.EnableCompactFullLastTime \[$null\] \($null\)
* $VBRJob.Options.GenerationPolicy.EnableDeletedVmDataRetention \[System.Boolean\] \($null\)
* $VBRJob.Options.GenerationPolicy.EnableRechek \[System.Boolean\] \($null\)
* $VBRJob.Options.GenerationPolicy.GFSIsReadEntireRestorePoint \[System.Boolean\] \($null\)
* $VBRJob.Options.GenerationPolicy.GFSMonthlyBackups \[System.Int32\] \($null\)
* $VBRJob.Options.GenerationPolicy.GFSQuarterlyBackups \[System.Int32\] \($null\)
* $VBRJob.Options.GenerationPolicy.GFSRecentPoints \[System.Int32\]
* $VBRJob.Options.GenerationPolicy.GFSWeeklyBackups \[System.Int32\]
* $VBRJob.Options.GenerationPolicy.GFSYearlyBackups \[System.Int32\] \($null\)
* $VBRJob.Options.GenerationPolicy.IsGfsActiveFullEnabled \[System.Boolean\] \($null\)
* $VBRJob.Options.GenerationPolicy.KeepGfsBackup \[System.Boolean\] \($null\)
* $VBRJob.Options.GenerationPolicy.MonthlyBackup \[Veeam.Backup.Model.CDomMonthlyBackupCreationTime\]
* $VBRJob.Options.GenerationPolicy.MonthlyBackup.BackupDateTime()  Def [datetime BackupDateTime(datetime date)]
* $VBRJob.Options.GenerationPolicy.MonthlyBackup.MatchDate()  Def [bool MatchDate(datetime date)]
* $VBRJob.Options.GenerationPolicy.MonthlyBackup.DayOfMonth \[Veeam.Backup.Model.CDayOfMonth\]
* $VBRJob.Options.GenerationPolicy.MonthlyBackup.DayOfMonth.Build()  Def [string Build()]
* $VBRJob.Options.GenerationPolicy.MonthlyBackup.DayOfMonth.MatchDate()  Def [bool MatchDate(datetime date)]
* $VBRJob.Options.GenerationPolicy.MonthlyBackup.DayOfMonth.Day \[System.Int32\]
* $VBRJob.Options.GenerationPolicy.MonthlyBackup.DayOfMonth.IsLast \[System.Boolean\] \($null\)
* $VBRJob.Options.GenerationPolicy.MonthlyBackup.DayOfMonth.Value \[System.Int32\]
* $VBRJob.Options.GenerationPolicy.MonthlyBackup.DayOfWeek \[Veeam.Backup.Model.CDomDayWeek\]
* $VBRJob.Options.GenerationPolicy.MonthlyBackup.DayOfWeek.MatchDate()  Def [bool MatchDate(datetime date)]
* $VBRJob.Options.GenerationPolicy.MonthlyBackup.DayOfWeek.DayOfWeek \[System.DayOfWeek\] \($null\)
* $VBRJob.Options.GenerationPolicy.MonthlyBackup.DayOfWeek.DayOfWeekNumber \[System.Int32\]
* $VBRJob.Options.GenerationPolicy.MonthlyBackup.Kind \[Veeam.Backup.Model.CDomMonthlyBackupCreationTime+EKind\]
* $VBRJob.Options.GenerationPolicy.MonthlyBackup.Kind.value__ \[System.Int32\]
* $VBRJob.Options.GenerationPolicy.QuarterlyBackup \[Veeam.Backup.Model.CDomQuarterlyBackupCreationTime\]
* $VBRJob.Options.GenerationPolicy.QuarterlyBackup.MatchDate()  Def [bool MatchDate(datetime date)]
* $VBRJob.Options.GenerationPolicy.QuarterlyBackup.DayOfQuarter \[Veeam.Backup.Model.CDomDayMonth\]
* $VBRJob.Options.GenerationPolicy.QuarterlyBackup.DayOfQuarter.DayNumber \[Veeam.Backup.Model.CDayOfMonth\]
* $VBRJob.Options.GenerationPolicy.QuarterlyBackup.DayOfQuarter.DayNumber.Build()  Def [string Build()]
* $VBRJob.Options.GenerationPolicy.QuarterlyBackup.DayOfQuarter.DayNumber.MatchDate()  Def [bool MatchDate(datetime date)]
* $VBRJob.Options.GenerationPolicy.QuarterlyBackup.DayOfQuarter.DayNumber.Day \[System.Int32\]
* $VBRJob.Options.GenerationPolicy.QuarterlyBackup.DayOfQuarter.DayNumber.IsLast \[System.Boolean\] \($null\)
* $VBRJob.Options.GenerationPolicy.QuarterlyBackup.DayOfQuarter.DayNumber.Value \[System.Int32\]
* $VBRJob.Options.GenerationPolicy.QuarterlyBackup.DayOfQuarter.MonthNumber \[System.Int32\]
* $VBRJob.Options.GenerationPolicy.QuarterlyBackup.DayOfWeek \[Veeam.Backup.Model.CDomDayWeek\]
* $VBRJob.Options.GenerationPolicy.QuarterlyBackup.DayOfWeek.MatchDate()  Def [bool MatchDate(datetime date)]
* $VBRJob.Options.GenerationPolicy.QuarterlyBackup.DayOfWeek.DayOfWeek \[System.DayOfWeek\] \($null\)
* $VBRJob.Options.GenerationPolicy.QuarterlyBackup.DayOfWeek.DayOfWeekNumber \[System.Int32\]
* $VBRJob.Options.GenerationPolicy.QuarterlyBackup.Kind \[Veeam.Backup.Model.CDomQuarterlyBackupCreationTime+EKind\]
* $VBRJob.Options.GenerationPolicy.QuarterlyBackup.Kind.value__ \[System.Int32\]
* $VBRJob.Options.GenerationPolicy.RecheckBackupMonthlyScheduleOptions \[Veeam.Backup.Model.CDomFullBackupMonthlyScheduleOptions\]
* $VBRJob.Options.GenerationPolicy.RecheckBackupMonthlyScheduleOptions.Serial()  Def [void Serial(System.Xml.XmlNode node)]
* $VBRJob.Options.GenerationPolicy.RecheckBackupMonthlyScheduleOptions.DayNumberInMonth \[Veeam.Backup.Common.EDayNumberInMonth\]
* $VBRJob.Options.GenerationPolicy.RecheckBackupMonthlyScheduleOptions.DayNumberInMonth.value__ \[System.Int32\]
* $VBRJob.Options.GenerationPolicy.RecheckBackupMonthlyScheduleOptions.DayOfMonth \[Veeam.Backup.Model.CDayOfMonth\]
* $VBRJob.Options.GenerationPolicy.RecheckBackupMonthlyScheduleOptions.DayOfMonth.Build()  Def [string Build()]
* $VBRJob.Options.GenerationPolicy.RecheckBackupMonthlyScheduleOptions.DayOfMonth.MatchDate()  Def [bool MatchDate(datetime date)]
* $VBRJob.Options.GenerationPolicy.RecheckBackupMonthlyScheduleOptions.DayOfMonth.Day \[System.Int32\]
* $VBRJob.Options.GenerationPolicy.RecheckBackupMonthlyScheduleOptions.DayOfMonth.IsLast \[System.Boolean\] \($null\)
* $VBRJob.Options.GenerationPolicy.RecheckBackupMonthlyScheduleOptions.DayOfMonth.Value \[System.Int32\]
* $VBRJob.Options.GenerationPolicy.RecheckBackupMonthlyScheduleOptions.DayOfWeek \[System.DayOfWeek\]
* $VBRJob.Options.GenerationPolicy.RecheckBackupMonthlyScheduleOptions.DayOfWeek.value__ \[System.Int32\]
* $VBRJob.Options.GenerationPolicy.RecheckBackupMonthlyScheduleOptions.Months \[Veeam.Backup.Common.EMonth[]\]
* $VBRJob.Options.GenerationPolicy.RecheckBackupMonthlyScheduleOptions.Months.value__ \[System.Object[]\]
* $VBRJob.Options.GenerationPolicy.RecheckDays \[System.DayOfWeek[]\]
* $VBRJob.Options.GenerationPolicy.RecheckDays.value__ \[System.Int32\]
* $VBRJob.Options.GenerationPolicy.RecheckScheduleKind \[Veeam.Backup.Model.EFullBackupScheduleKind\]
* $VBRJob.Options.GenerationPolicy.RecheckScheduleKind.value__ \[System.Int32\]
* $VBRJob.Options.GenerationPolicy.RecoveryPointObjectiveUnit \[Veeam.Backup.Common.ETimeUnit\]
* $VBRJob.Options.GenerationPolicy.RecoveryPointObjectiveUnit.value__ \[System.Int32\]
* $VBRJob.Options.GenerationPolicy.RecoveryPointObjectiveValue \[System.Int32\]
* $VBRJob.Options.GenerationPolicy.RetentionPolicyType \[Veeam.Backup.Model.ERetentionPolicyType\]
* $VBRJob.Options.GenerationPolicy.RetentionPolicyType.value__ \[System.Int32\]
* $VBRJob.Options.GenerationPolicy.SimpleRetentionRestorePoints \[System.Int32\]
* $VBRJob.Options.GenerationPolicy.SyncIntervalStartTime \[System.TimeSpan\]
* $VBRJob.Options.GenerationPolicy.WeeklyBackupDayOfWeek \[System.DayOfWeek\] \($null\)
* $VBRJob.Options.GenerationPolicy.YearlyBackup \[Veeam.Backup.Model.CDomYearlyBackupCreationTime\]
* $VBRJob.Options.GenerationPolicy.YearlyBackup.MatchDate()  Def [bool MatchDate(datetime date)]
* $VBRJob.Options.GenerationPolicy.YearlyBackup.DayOfWeek \[Veeam.Backup.Model.CDomDayWeek\]
* $VBRJob.Options.GenerationPolicy.YearlyBackup.DayOfWeek.MatchDate()  Def [bool MatchDate(datetime date)]
* $VBRJob.Options.GenerationPolicy.YearlyBackup.DayOfWeek.DayOfWeek \[System.DayOfWeek\] \($null\)
* $VBRJob.Options.GenerationPolicy.YearlyBackup.DayOfWeek.DayOfWeekNumber \[System.Int32\]
* $VBRJob.Options.GenerationPolicy.YearlyBackup.DayOfYear \[Veeam.Backup.Model.CDomDayMonth\]
* $VBRJob.Options.GenerationPolicy.YearlyBackup.DayOfYear.DayNumber \[Veeam.Backup.Model.CDayOfMonth\]
* $VBRJob.Options.GenerationPolicy.YearlyBackup.DayOfYear.DayNumber.Build()  Def [string Build()]
* $VBRJob.Options.GenerationPolicy.YearlyBackup.DayOfYear.DayNumber.MatchDate()  Def [bool MatchDate(datetime date)]
* $VBRJob.Options.GenerationPolicy.YearlyBackup.DayOfYear.DayNumber.Day \[System.Int32\]
* $VBRJob.Options.GenerationPolicy.YearlyBackup.DayOfYear.DayNumber.IsLast \[System.Boolean\] \($null\)
* $VBRJob.Options.GenerationPolicy.YearlyBackup.DayOfYear.DayNumber.Value \[System.Int32\]
* $VBRJob.Options.GenerationPolicy.YearlyBackup.DayOfYear.MonthNumber \[System.Int32\]
* $VBRJob.Options.GenerationPolicy.YearlyBackup.Kind \[Veeam.Backup.Model.CDomYearlyBackupCreationTime+EKind\]
* $VBRJob.Options.GenerationPolicy.YearlyBackup.Kind.value__ \[System.Int32\]
* $VBRJob.Options.HvNetworkMappingOptions \[Veeam.Backup.Model.CDomHvNetworkMappingOptions\]
* $VBRJob.Options.HvNetworkMappingOptions.NetworkMapping \[Veeam.Backup.Model.CHvNetworkMappingSpec[]\] \($null\)
* $VBRJob.Options.HvReplicaTargetOptions \[Veeam.Backup.Model.CDomHvReplicaTargetOptions\]
* $VBRJob.Options.HvReplicaTargetOptions.EnableInitialPass \[System.Boolean\] \($null\)
* $VBRJob.Options.HvReplicaTargetOptions.InitialPassDir \[System.String\] \($null\)
* $VBRJob.Options.HvReplicaTargetOptions.InitialSeeding \[System.Boolean\] \($null\)
* $VBRJob.Options.HvReplicaTargetOptions.ReplicaNameSuffix \[System.String\] \($null\)
* $VBRJob.Options.HvReplicaTargetOptions.TargetFolder \[System.String\]
* $VBRJob.Options.HvReplicaTargetOptions.UseNetworkMapping \[System.Boolean\] \($null\)
* $VBRJob.Options.HvReplicaTargetOptions.UseReIP \[System.Boolean\] \($null\)
* $VBRJob.Options.HvReplicaTargetOptions.UseVmMapping \[System.Boolean\] \($null\)
* $VBRJob.Options.HvSourceOptions \[Veeam.Backup.Model.CDomHvSourceOptions\]
* $VBRJob.Options.HvSourceOptions.CanDoCrashConsistent \[System.Boolean\] \($null\)
* $VBRJob.Options.HvSourceOptions.DirtyBlocksNullingEnabled \[System.Boolean\]
* $VBRJob.Options.HvSourceOptions.EnableHvQuiescence \[System.Boolean\] \($null\)
* $VBRJob.Options.HvSourceOptions.ExcludeSwapFile \[System.Boolean\]
* $VBRJob.Options.HvSourceOptions.FailoverToOnHostBackup \[System.Boolean\]
* $VBRJob.Options.HvSourceOptions.GroupSnapshotProcessing \[System.Boolean\]
* $VBRJob.Options.HvSourceOptions.OffHostBackup \[System.Boolean\]
* $VBRJob.Options.HvSourceOptions.UseChangeTracking \[System.Boolean\]
* $VBRJob.Options.JobOptions \[Veeam.Backup.Model.CDomJobOptions\]
* $VBRJob.Options.JobOptions.BackupCopyJobCanRunAnyTime \[System.Boolean\]
* $VBRJob.Options.JobOptions.RunManually \[System.Boolean\] \($null\)
* $VBRJob.Options.JobOptions.SourceProxyAutoDetect \[System.Boolean\]
* $VBRJob.Options.JobOptions.TargetProxyAutoDetect \[System.Boolean\]
* $VBRJob.Options.JobOptions.ThrottleBackupAgent \[System.Boolean\] \($null\)
* $VBRJob.Options.JobOptions.UseWan \[System.Boolean\] \($null\)
* $VBRJob.Options.JobScriptCommand \[Veeam.Backup.Model.CDomJobScriptCommand\]
* $VBRJob.Options.JobScriptCommand.Serialize()  Def [string Serialize()]
* $VBRJob.Options.JobScriptCommand.Days \[System.DayOfWeek[]\]
* $VBRJob.Options.JobScriptCommand.Days.value__ \[System.Int32\]
* $VBRJob.Options.JobScriptCommand.Frequency \[System.UInt32\]
* $VBRJob.Options.JobScriptCommand.Periodicity \[Veeam.Backup.Model.CDomJobScriptCommand+PeriodicityType\] \($null\)
* $VBRJob.Options.JobScriptCommand.PostCommand \[Veeam.Backup.Model.CCustomCommand\]
* $VBRJob.Options.JobScriptCommand.PostCommand.Clone()  Def [Veeam.Backup.Model.CCustomCommand Clone(), Veeam.Backup.Model.CCustomCommand ICloneable[CCustomCommand].Clone(), System.Object ICloneable.Clone()]
* $VBRJob.Options.JobScriptCommand.PostCommand.CommandLine \[System.String\] \($null\)
* $VBRJob.Options.JobScriptCommand.PostCommand.Days \[System.DayOfWeek[]\]
* $VBRJob.Options.JobScriptCommand.PostCommand.Days.value__ \[System.Int32\]
* $VBRJob.Options.JobScriptCommand.PostCommand.Enabled \[System.Boolean\] \($null\)
* $VBRJob.Options.JobScriptCommand.PostCommand.Frequency \[System.UInt32\]
* $VBRJob.Options.JobScriptCommand.PostCommand.Periodicity \[Veeam.Backup.Model.CCustomCommand+PeriodicityType\] \($null\)
* $VBRJob.Options.JobScriptCommand.PostScriptCommandLine \[System.String\] \($null\)
* $VBRJob.Options.JobScriptCommand.PostScriptEnabled \[System.Boolean\] \($null\)
* $VBRJob.Options.JobScriptCommand.PreCommand \[Veeam.Backup.Model.CCustomCommand\]
* $VBRJob.Options.JobScriptCommand.PreCommand.Clone()  Def [Veeam.Backup.Model.CCustomCommand Clone(), Veeam.Backup.Model.CCustomCommand ICloneable[CCustomCommand].Clone(), System.Object ICloneable.Clone()]
* $VBRJob.Options.JobScriptCommand.PreCommand.CommandLine \[System.String\] \($null\)
* $VBRJob.Options.JobScriptCommand.PreCommand.Days \[System.DayOfWeek[]\]
* $VBRJob.Options.JobScriptCommand.PreCommand.Days.value__ \[System.Int32\]
* $VBRJob.Options.JobScriptCommand.PreCommand.Enabled \[System.Boolean\] \($null\)
* $VBRJob.Options.JobScriptCommand.PreCommand.Frequency \[System.UInt32\]
* $VBRJob.Options.JobScriptCommand.PreCommand.Periodicity \[Veeam.Backup.Model.CCustomCommand+PeriodicityType\] \($null\)
* $VBRJob.Options.JobScriptCommand.PreScriptCommandLine \[System.String\] \($null\)
* $VBRJob.Options.JobScriptCommand.PreScriptEnabled \[System.Boolean\] \($null\)
* $VBRJob.Options.NotificationOptions \[Veeam.Backup.Model.CDomNotificationOptions\]
* $VBRJob.Options.NotificationOptions.IsResultMatchesJobOptions()  Def [bool IsResultMatchesJobOptions(Veeam.Backup.Model.CBaseSessionInfo+EResult sessResult), bool IJobNotificationOptions.IsResultMatchesJobOptions(Veeam.Backup.Model.CBaseSessionInfo+EResult sessionResult)]
* $VBRJob.Options.NotificationOptions.Serialize()  Def [string Serialize()]
* $VBRJob.Options.NotificationOptions.EmailNotificationAdditionalAddresses \[System.String\] \($null\)
* $VBRJob.Options.NotificationOptions.EmailNotificationSubject \[System.String\]
* $VBRJob.Options.NotificationOptions.EmailNotifyOnError \[System.Boolean\]
* $VBRJob.Options.NotificationOptions.EmailNotifyOnLastRetryOnly \[System.Boolean\]
* $VBRJob.Options.NotificationOptions.EmailNotifyOnSuccess \[System.Boolean\]
* $VBRJob.Options.NotificationOptions.EmailNotifyOnWaitingTape \[System.Boolean\]
* $VBRJob.Options.NotificationOptions.EmailNotifyOnWarning \[System.Boolean\]
* $VBRJob.Options.NotificationOptions.EmailNotifyTime \[System.DateTime\]
* $VBRJob.Options.NotificationOptions.SendEmailNotification2AdditionalAddresses \[System.Boolean\] \($null\)
* $VBRJob.Options.NotificationOptions.SnmpNotification \[System.Boolean\] \($null\)
* $VBRJob.Options.NotificationOptions.UseCustomEmailNotificationOptions \[System.Boolean\] \($null\)
* $VBRJob.Options.Options \[Veeam.Backup.Common.CDomContainer\]
* $VBRJob.Options.Options.Clone()  Def [Veeam.Backup.Common.CDomContainer Clone()]
* $VBRJob.Options.Options.GetObjectData()  Def [void GetObjectData(System.Runtime.Serialization.SerializationInfo info, System.Runtime.Serialization.StreamingContext context), void ISerializable.GetObjectData(System.Runtime.Serialization.SerializationInfo info, System.Runtime.Serialization.StreamingContext context)]
* $VBRJob.Options.Options.Serial()  Def [void Serial(System.Xml.XmlNode node)]
* $VBRJob.Options.Options.Serialize()  Def [string Serialize()]
* $VBRJob.Options.Options.RootNode \[System.Xml.XmlElement\]
* $VBRJob.Options.PolicyOptions \[Veeam.Backup.Model.CDomPolicyOptions\]
* $VBRJob.Options.PolicyOptions.KvpIds \[System.Guid[]\] \($null\)
* $VBRJob.Options.ReIPRulesOptions \[Veeam.Backup.Model.CDomReIPRulesOptions\]
* $VBRJob.Options.ReIPRulesOptions.Add()  Def [Veeam.Backup.Model.CDomReIPRuleOptions Add()]
* $VBRJob.Options.ReIPRulesOptions.Remove()  Def [void Remove(Veeam.Backup.Model.CDomReIPRuleOptions rule)]
* $VBRJob.Options.ReIPRulesOptions.Rules \[Veeam.Backup.Model.CDomReIPRulesOptions+<get_Rules>d__0\] \($null\)
* $VBRJob.Options.ReplicaSourceOptions \[Veeam.Backup.Model.CDomReplicaSourceOptions\]
* $VBRJob.Options.ReplicaSourceOptions.Backup2Vi \[System.Boolean\] \($null\)
* $VBRJob.Options.SanIntegrationOptions \[Veeam.Backup.Model.CDomSanIntegrationOptions\]
* $VBRJob.Options.SanIntegrationOptions.DomSanStorageRepositoryOptions \[Veeam.Backup.Model.CDomSanStorageRepositoryOptions\]
* $VBRJob.Options.SanIntegrationOptions.DomSanStorageRepositoryOptions.AddOrUpdateRepository()  Def [void AddOrUpdateRepository(guid repoId, bool isNeedToUse, int retentionCount)]
* $VBRJob.Options.SanIntegrationOptions.DomSanStorageRepositoryOptions.GetRetentionCountByRepository()  Def [int GetRetentionCountByRepository(guid repoId)]
* $VBRJob.Options.SanIntegrationOptions.DomSanStorageRepositoryOptions.HasEnabledRepository()  Def [bool HasEnabledRepository()]
* $VBRJob.Options.SanIntegrationOptions.DomSanStorageRepositoryOptions.IsNeedUseSnapOnlyRepository()  Def [bool IsNeedUseSnapOnlyRepository(guid repoId)]
* $VBRJob.Options.SanIntegrationOptions.DomSanStorageRepositoryOptions.ResetPublicPluginRepositoryOptions()  Def [void ResetPublicPluginRepositoryOptions()]
* $VBRJob.Options.SanIntegrationOptions.Failover2StorageSnapshotBackup \[System.Boolean\] \($null\)
* $VBRJob.Options.SanIntegrationOptions.FailoverFromSan \[System.Boolean\] \($null\)
* $VBRJob.Options.SanIntegrationOptions.HpPersistentPeerBackupSource \[System.Boolean\] \($null\)
* $VBRJob.Options.SanIntegrationOptions.HpPersistentPeerEnabled \[System.Boolean\] \($null\)
* $VBRJob.Options.SanIntegrationOptions.MultipleStorageSnapshotEnabled \[System.Boolean\] \($null\)
* $VBRJob.Options.SanIntegrationOptions.MultipleStorageSnapshotVmsCount \[System.Int32\]
* $VBRJob.Options.SanIntegrationOptions.NimbleSnapshotSourceEnabled \[System.Boolean\] \($null\)
* $VBRJob.Options.SanIntegrationOptions.NimbleSnapshotSourceRetention \[System.Int32\]
* $VBRJob.Options.SanIntegrationOptions.NimbleSnapshotTransferAsBackupSource \[System.Boolean\] \($null\)
* $VBRJob.Options.SanIntegrationOptions.NimbleSnapshotTransferEnabled \[System.Boolean\] \($null\)
* $VBRJob.Options.SanIntegrationOptions.NimbleSnapshotTransferRetention \[System.Int32\]
* $VBRJob.Options.SanIntegrationOptions.PublicPluginSnapshotSourceEnabled \[System.Boolean\] \($null\)
* $VBRJob.Options.SanIntegrationOptions.PublicPluginSnapshotSourceRetention \[System.Int32\]
* $VBRJob.Options.SanIntegrationOptions.SanSnapshotBackupBackupSource \[System.Boolean\] \($null\)
* $VBRJob.Options.SanIntegrationOptions.SanSnapshotBackupTransferEnabled \[System.Boolean\] \($null\)
* $VBRJob.Options.SanIntegrationOptions.SanSnapshotBackupTransferRetention \[System.Int32\]
* $VBRJob.Options.SanIntegrationOptions.SanSnapshotReplicaBackupSource \[System.Boolean\] \($null\)
* $VBRJob.Options.SanIntegrationOptions.SanSnapshotReplicaTransferEnabled \[System.Boolean\] \($null\)
* $VBRJob.Options.SanIntegrationOptions.SanSnapshotReplicaTransferRetention \[System.Int32\]
* $VBRJob.Options.SanIntegrationOptions.SanSnapshotSourceEnabled \[System.Boolean\] \($null\)
* $VBRJob.Options.SanIntegrationOptions.SanSnapshotSourceRetention \[System.Int32\]
* $VBRJob.Options.SanIntegrationOptions.UseSanSnapshots \[System.Boolean\]
* $VBRJob.Options.SqlLogBackupOptions \[Veeam.Backup.Model.CDomSqlLogBackupOptions\]
* $VBRJob.Options.SqlLogBackupOptions.GetBackupInterval()  Def [timespan GetBackupInterval()]
* $VBRJob.Options.SqlLogBackupOptions.GetStorageInterval()  Def [timespan GetStorageInterval()]
* $VBRJob.Options.SqlLogBackupOptions.BackupIntervalUnit \[Veeam.Backup.Common.ETimeUnit\] \($null\)
* $VBRJob.Options.SqlLogBackupOptions.BackupIntervalValue \[System.Int32\]
* $VBRJob.Options.SqlLogBackupOptions.DailyRetentionDays \[System.Int32\]
* $VBRJob.Options.SqlLogBackupOptions.RetentionType \[Veeam.Backup.Model.ESqlLogBackupRetentionType\]
* $VBRJob.Options.SqlLogBackupOptions.RetentionType.value__ \[System.Int32\]
* $VBRJob.Options.SqlLogBackupOptions.StorageIntervalUnit \[Veeam.Backup.Common.ETimeUnit\]
* $VBRJob.Options.SqlLogBackupOptions.StorageIntervalUnit.value__ \[System.Int32\]
* $VBRJob.Options.SqlLogBackupOptions.StorageIntervalValue \[System.Int32\]
* $VBRJob.Options.ViCloudReplicaTargetOptions \[Veeam.Backup.Model.CDomViCloudReplicaTargetOptions\]
* $VBRJob.Options.ViCloudReplicaTargetOptions.CloudConnectDatastore \[System.Guid\]
* $VBRJob.Options.ViCloudReplicaTargetOptions.CloudConnectHost \[System.Guid\]
* $VBRJob.Options.ViCloudReplicaTargetOptions.Enabled \[System.Boolean\] \($null\)
* $VBRJob.Options.ViNetworkMappingOptions \[Veeam.Backup.Model.CDomViNetworkMappingOptions\]
* $VBRJob.Options.ViNetworkMappingOptions.NetworkMapping \[Veeam.Backup.Model.CViNetworkMappingSpec[]\] \($null\)
* $VBRJob.Options.ViReplicaTargetOptions \[Veeam.Backup.Model.CDomViReplicaTargetOptions\]
* $VBRJob.Options.ViReplicaTargetOptions.ClusterName \[System.String\] \($null\)
* $VBRJob.Options.ViReplicaTargetOptions.ClusterReference \[System.String\] \($null\)
* $VBRJob.Options.ViReplicaTargetOptions.DatastoreHDTargetType \[Veeam.Backup.Model.HDTargetType\] \($null\)
* $VBRJob.Options.ViReplicaTargetOptions.DatastoreName \[System.String\] \($null\)
* $VBRJob.Options.ViReplicaTargetOptions.DatastoreReference \[System.String\] \($null\)
* $VBRJob.Options.ViReplicaTargetOptions.DatastoreRootPath \[System.String\] \($null\)
* $VBRJob.Options.ViReplicaTargetOptions.DiskCreationMode \[Veeam.Backup.Model.EDiskCreationMode\] \($null\)
* $VBRJob.Options.ViReplicaTargetOptions.EnableDigests \[System.Boolean\]
* $VBRJob.Options.ViReplicaTargetOptions.EnableInitialPass \[System.Boolean\] \($null\)
* $VBRJob.Options.ViReplicaTargetOptions.HostReference \[System.String\] \($null\)
* $VBRJob.Options.ViReplicaTargetOptions.InitialPassDir \[System.String\] \($null\)
* $VBRJob.Options.ViReplicaTargetOptions.InitialSeeding \[System.Boolean\] \($null\)
* $VBRJob.Options.ViReplicaTargetOptions.PbmProfileId \[System.String\]
* $VBRJob.Options.ViReplicaTargetOptions.ReplicaNamePrefix \[System.String\] \($null\)
* $VBRJob.Options.ViReplicaTargetOptions.ReplicaNameSuffix \[System.String\] \($null\)
* $VBRJob.Options.ViReplicaTargetOptions.ReplicaTargetResourcePoolName \[System.String\] \($null\)
* $VBRJob.Options.ViReplicaTargetOptions.ReplicaTargetResourcePoolRef \[System.String\] \($null\)
* $VBRJob.Options.ViReplicaTargetOptions.ReplicaTargetVmFolderName \[System.String\] \($null\)
* $VBRJob.Options.ViReplicaTargetOptions.ReplicaTargetVmFolderRef \[System.String\] \($null\)
* $VBRJob.Options.ViReplicaTargetOptions.UseNetworkMapping \[System.Boolean\] \($null\)
* $VBRJob.Options.ViReplicaTargetOptions.UseReIP \[System.Boolean\] \($null\)
* $VBRJob.Options.ViReplicaTargetOptions.UseVmMapping \[System.Boolean\] \($null\)
* $VBRJob.Options.ViSourceOptions \[Veeam.Backup.Model.CDomViSourceOptions\]
* $VBRJob.Options.ViSourceOptions.GetVCBMode()  Def [Veeam.Backup.Model.VCBModes GetVCBMode()]
* $VBRJob.Options.ViSourceOptions.BackupTemplates \[System.Boolean\]
* $VBRJob.Options.ViSourceOptions.BackupTemplatesOnce \[System.Boolean\]
* $VBRJob.Options.ViSourceOptions.DirtyBlocksNullingEnabled \[System.Boolean\]
* $VBRJob.Options.ViSourceOptions.EnableChangeTracking \[System.Boolean\]
* $VBRJob.Options.ViSourceOptions.EncryptLanTraffic \[System.Boolean\] \($null\)
* $VBRJob.Options.ViSourceOptions.ExcludeSwapFile \[System.Boolean\]
* $VBRJob.Options.ViSourceOptions.FailoverToNetworkMode \[System.Boolean\] \($null\)
* $VBRJob.Options.ViSourceOptions.SetResultsToVmNotes \[System.Boolean\] \($null\)
* $VBRJob.Options.ViSourceOptions.UseChangeTracking \[System.Boolean\]
* $VBRJob.Options.ViSourceOptions.VCBMode \[System.String\]
* $VBRJob.Options.ViSourceOptions.VDDKMode \[System.String\]
* $VBRJob.Options.ViSourceOptions.VmAttributeName \[System.String\]
* $VBRJob.Options.ViSourceOptions.VmNotesAppend \[System.Boolean\]
* $VBRJob.Options.ViSourceOptions.VMToolsQuiesce \[System.Boolean\] \($null\)
* $VBRJob.OracleEnabled \[System.Boolean\] \($null\)
* $VBRJob.ParentJobId \[$null\] \($null\)
* $VBRJob.ParentScheduleId \[$null\] \($null\)
* $VBRJob.PreviousJobIdInScheduleChain \[$null\] \($null\)
* $VBRJob.ScheduleOptions \[Veeam.Backup.Model.ScheduleOptions\]
* $VBRJob.ScheduleOptions.Clone()  Def [Veeam.Backup.Model.ScheduleOptions Clone(), Veeam.Backup.Model.ScheduleOptions ICloneable[ScheduleOptions].Clone(), System.Object ICloneable.Clone()]
* $VBRJob.ScheduleOptions.DisableEverything()  Def [void DisableEverything()]
* $VBRJob.ScheduleOptions.FromXmlData()  Def [Veeam.Backup.Model.ScheduleOptions FromXmlData(Veeam.Backup.Common.COutputXmlData data)]
* $VBRJob.ScheduleOptions.GetDays()  Def [System.DayOfWeek[] GetDays()]
* $VBRJob.ScheduleOptions.Serial()  Def [void Serial(System.Xml.XmlNode node)]
* $VBRJob.ScheduleOptions.BackupAtLock \[System.Boolean\] \($null\)
* $VBRJob.ScheduleOptions.BackupAtLogoff \[System.Boolean\] \($null\)
* $VBRJob.ScheduleOptions.BackupAtStartup \[System.Boolean\] \($null\)
* $VBRJob.ScheduleOptions.BackupAtStorageAttach \[System.Boolean\] \($null\)
* $VBRJob.ScheduleOptions.BackupCompetitionWaitingPeriodMin \[System.Int32\]
* $VBRJob.ScheduleOptions.BackupCompetitionWaitingUnit \[Veeam.Backup.Model.ScheduleOptions+UnitOfTime\]
* $VBRJob.ScheduleOptions.BackupCompetitionWaitingUnit.value__ \[System.Int32\]
* $VBRJob.ScheduleOptions.EjectRemovableStorageOnBackupComplete \[System.Boolean\] \($null\)
* $VBRJob.ScheduleOptions.EndDateTimeLocal \[System.DateTime\]
* $VBRJob.ScheduleOptions.EndDateTimeSpecified \[System.Boolean\] \($null\)
* $VBRJob.ScheduleOptions.FrequencyTimeUnit \[Veeam.Backup.Common.ETimeUnit\]
* $VBRJob.ScheduleOptions.FrequencyTimeUnit.value__ \[System.Int32\]
* $VBRJob.ScheduleOptions.IsContinious \[System.Boolean\] \($null\)
* $VBRJob.ScheduleOptions.IsFakeSchedule \[System.Boolean\] \($null\)
* $VBRJob.ScheduleOptions.IsServerMode \[System.Boolean\] \($null\)
* $VBRJob.ScheduleOptions.LatestRecheckLocal \[System.DateTime\]
* $VBRJob.ScheduleOptions.LatestRunLocal \[System.DateTime\]
* $VBRJob.ScheduleOptions.LimitBackupsFrequency \[System.Boolean\] \($null\)
* $VBRJob.ScheduleOptions.MaxBackupsFrequency \[System.Int32\]
* $VBRJob.ScheduleOptions.NextRun \[System.String\]
* $VBRJob.ScheduleOptions.OptionsBackupWindow \[Veeam.Backup.Model.CBackupWindowOptions\]
* $VBRJob.ScheduleOptions.OptionsBackupWindow.Serial()  Def [void Serial(System.Xml.XmlNode node)]
* $VBRJob.ScheduleOptions.OptionsBackupWindow.BackupWindow \[System.String\]
* $VBRJob.ScheduleOptions.OptionsBackupWindow.IsEnabled \[System.Boolean\] \($null\)
* $VBRJob.ScheduleOptions.OptionsContinuous \[Veeam.Backup.Model.CContinuousOptions\]
* $VBRJob.ScheduleOptions.OptionsContinuous.GetDays()  Def [System.DayOfWeek[] GetDays()]
* $VBRJob.ScheduleOptions.OptionsContinuous.Serial()  Def [void Serial(System.Xml.XmlNode node)]
* $VBRJob.ScheduleOptions.OptionsContinuous.Enabled \[System.Boolean\] \($null\)
* $VBRJob.ScheduleOptions.OptionsContinuous.Schedule \[System.String\]
* $VBRJob.ScheduleOptions.OptionsDaily \[Veeam.Backup.Model.DailyOptions\]
* $VBRJob.ScheduleOptions.OptionsDaily.GetDays()  Def [System.DayOfWeek[] GetDays()]
* $VBRJob.ScheduleOptions.OptionsDaily.Serial()  Def [void Serial(System.Xml.XmlNode node)]
* $VBRJob.ScheduleOptions.OptionsDaily.CompMode \[Veeam.Backup.Model.ECompMode\] \($null\)
* $VBRJob.ScheduleOptions.OptionsDaily.DaysSrv \[System.DayOfWeek[]\]
* $VBRJob.ScheduleOptions.OptionsDaily.DaysSrv.value__ \[System.Object[]\]
* $VBRJob.ScheduleOptions.OptionsDaily.Enabled \[System.Boolean\]
* $VBRJob.ScheduleOptions.OptionsDaily.Kind \[Veeam.Backup.Model.DailyOptions+DailyKinds\] \($null\)
* $VBRJob.ScheduleOptions.OptionsDaily.TimeLocal \[System.DateTime\]
* $VBRJob.ScheduleOptions.OptionsMonthly \[Veeam.Backup.Model.CMonthlyOptions\]
* $VBRJob.ScheduleOptions.OptionsMonthly.Clone()  Def [Veeam.Backup.Model.CMonthlyOptions Clone(), Veeam.Backup.Model.CMonthlyOptions ICloneable[CMonthlyOptions].Clone(), System.Object ICloneable.Clone()]
* $VBRJob.ScheduleOptions.OptionsMonthly.GetDays()  Def [System.DayOfWeek[] GetDays()]
* $VBRJob.ScheduleOptions.OptionsMonthly.Serial()  Def [void Serial(System.Xml.XmlNode node)]
* $VBRJob.ScheduleOptions.OptionsMonthly.DayNumberInMonth \[Veeam.Backup.Common.EDayNumberInMonth\]
* $VBRJob.ScheduleOptions.OptionsMonthly.DayNumberInMonth.value__ \[System.Int32\]
* $VBRJob.ScheduleOptions.OptionsMonthly.DayOfMonth \[Veeam.Backup.Model.CDayOfMonth\]
* $VBRJob.ScheduleOptions.OptionsMonthly.DayOfMonth.Build()  Def [string Build()]
* $VBRJob.ScheduleOptions.OptionsMonthly.DayOfMonth.MatchDate()  Def [bool MatchDate(datetime date)]
* $VBRJob.ScheduleOptions.OptionsMonthly.DayOfMonth.Day \[System.Int32\]
* $VBRJob.ScheduleOptions.OptionsMonthly.DayOfMonth.IsLast \[System.Boolean\] \($null\)
* $VBRJob.ScheduleOptions.OptionsMonthly.DayOfMonth.Value \[System.Int32\]
* $VBRJob.ScheduleOptions.OptionsMonthly.DayOfWeek \[System.DayOfWeek\]
* $VBRJob.ScheduleOptions.OptionsMonthly.DayOfWeek.value__ \[System.Int32\]
* $VBRJob.ScheduleOptions.OptionsMonthly.Enabled \[System.Boolean\] \($null\)
* $VBRJob.ScheduleOptions.OptionsMonthly.Months \[Veeam.Backup.Common.EMonth[]\]
* $VBRJob.ScheduleOptions.OptionsMonthly.Months.value__ \[System.Object[]\]
* $VBRJob.ScheduleOptions.OptionsMonthly.TimeLocal \[System.DateTime\]
* $VBRJob.ScheduleOptions.OptionsPeriodically \[Veeam.Backup.Model.PeriodicallyOptions\]
* $VBRJob.ScheduleOptions.OptionsPeriodically.GetDays()  Def [System.DayOfWeek[] GetDays()]
* $VBRJob.ScheduleOptions.OptionsPeriodically.Serial()  Def [void Serial(System.Xml.XmlNode node)]
* $VBRJob.ScheduleOptions.OptionsPeriodically.Enabled \[System.Boolean\] \($null\)
* $VBRJob.ScheduleOptions.OptionsPeriodically.FullPeriod \[System.Int32\]
* $VBRJob.ScheduleOptions.OptionsPeriodically.HourlyOffset \[System.Int32\] \($null\)
* $VBRJob.ScheduleOptions.OptionsPeriodically.Kind \[Veeam.Backup.Model.PeriodicallyOptions+PeriodicallyKinds\] \($null\)
* $VBRJob.ScheduleOptions.OptionsPeriodically.Schedule \[System.String\]
* $VBRJob.ScheduleOptions.OptionsScheduleAfterJob \[Veeam.Backup.Model.CScheduleAfterJobOptions\]
* $VBRJob.ScheduleOptions.OptionsScheduleAfterJob.Serial()  Def [void Serial(System.Xml.XmlNode node)]
* $VBRJob.ScheduleOptions.OptionsScheduleAfterJob.IsEnabled \[System.Boolean\] \($null\)
* $VBRJob.ScheduleOptions.RepeatNumber \[System.Int32\]
* $VBRJob.ScheduleOptions.RepeatSpecified \[System.Boolean\] \($null\)
* $VBRJob.ScheduleOptions.RepeatTimeUnit \[System.String\]
* $VBRJob.ScheduleOptions.RepeatTimeUnitMs \[System.Int32\]
* $VBRJob.ScheduleOptions.ResumeMissedBackup \[System.Boolean\] \($null\)
* $VBRJob.ScheduleOptions.RetrySpecified \[System.Boolean\]
* $VBRJob.ScheduleOptions.RetryTimeout \[System.Int32\]
* $VBRJob.ScheduleOptions.RetryTimes \[System.Int32\]
* $VBRJob.ScheduleOptions.StartDateTimeLocal \[System.DateTime\]
* $VBRJob.ScheduleOptions.WaitForBackupCompletion \[System.Boolean\]
* $VBRJob.SheduleEnabledTime \[$null\] \($null\)
* $VBRJob.SourceProxyAutoDetect \[System.Boolean\]
* $VBRJob.SourceType \[Veeam.Backup.Model.CDbBackupJobInfo+ESourceType\]
* $VBRJob.SourceType.value__ \[System.Int32\]
* $VBRJob.SqlEnabled \[System.Boolean\] \($null\)
* $VBRJob.TargetDir \[Veeam.Backup.Common.CLegacyPath\]
* $VBRJob.TargetDir.AddDelimiterIfNeeded()  Def [Veeam.Backup.Common.CLegacyPath AddDelimiterIfNeeded(string delimiter)]
* $VBRJob.TargetDir.FilterInvalidCharacters()  Def [Veeam.Backup.Common.CLegacyPath FilterInvalidCharacters(Veeam.Backup.Common.EPathCommanderType pathCommanderType)]
* $VBRJob.TargetDir.GetSchema()  Def [System.Xml.Schema.XmlSchema GetSchema(), System.Xml.Schema.XmlSchema IXmlSerializable.GetSchema()]
* $VBRJob.TargetDir.ReadXml()  Def [void ReadXml(System.Xml.XmlReader reader), void IXmlSerializable.ReadXml(System.Xml.XmlReader reader)]
* $VBRJob.TargetDir.Trim()  Def [Veeam.Backup.Common.CLegacyPath Trim()]
* $VBRJob.TargetDir.TrimDelimiter()  Def [Veeam.Backup.Common.CLegacyPath TrimDelimiter(char delimiter)]
* $VBRJob.TargetDir.WriteXml()  Def [void WriteXml(System.Xml.XmlWriter writer), void IXmlSerializable.WriteXml(System.Xml.XmlWriter writer)]
* $VBRJob.TargetDir.IsVbm \[System.Boolean\] \($null\)
* $VBRJob.TargetFile \[System.String\]
* $VBRJob.TargetHostId \[System.Guid\]
* $VBRJob.TargetType \[Veeam.Backup.Model.CDbBackupJobInfo+ETargetType\] \($null\)
* $VBRJob.TypeToString \[System.String\]
* $VBRJob.UserCryptoKey \[$null\] \($null\)
* $VBRJob.Usn \[System.Int64\]
* $VBRJob.ViReplicaTargetOptions \[Veeam.Backup.Model.CDomViReplicaTargetOptions\]
* $VBRJob.ViReplicaTargetOptions.ClusterName \[System.String\] \($null\)
* $VBRJob.ViReplicaTargetOptions.ClusterReference \[System.String\] \($null\)
* $VBRJob.ViReplicaTargetOptions.DatastoreHDTargetType \[Veeam.Backup.Model.HDTargetType\] \($null\)
* $VBRJob.ViReplicaTargetOptions.DatastoreName \[System.String\] \($null\)
* $VBRJob.ViReplicaTargetOptions.DatastoreReference \[System.String\] \($null\)
* $VBRJob.ViReplicaTargetOptions.DatastoreRootPath \[System.String\] \($null\)
* $VBRJob.ViReplicaTargetOptions.DiskCreationMode \[Veeam.Backup.Model.EDiskCreationMode\] \($null\)
* $VBRJob.ViReplicaTargetOptions.EnableDigests \[System.Boolean\]
* $VBRJob.ViReplicaTargetOptions.EnableInitialPass \[System.Boolean\] \($null\)
* $VBRJob.ViReplicaTargetOptions.HostReference \[System.String\] \($null\)
* $VBRJob.ViReplicaTargetOptions.InitialPassDir \[System.String\] \($null\)
* $VBRJob.ViReplicaTargetOptions.InitialSeeding \[System.Boolean\] \($null\)
* $VBRJob.ViReplicaTargetOptions.PbmProfileId \[System.String\]
* $VBRJob.ViReplicaTargetOptions.ReplicaNamePrefix \[System.String\] \($null\)
* $VBRJob.ViReplicaTargetOptions.ReplicaNameSuffix \[System.String\] \($null\)
* $VBRJob.ViReplicaTargetOptions.ReplicaTargetResourcePoolName \[System.String\] \($null\)
* $VBRJob.ViReplicaTargetOptions.ReplicaTargetResourcePoolRef \[System.String\] \($null\)
* $VBRJob.ViReplicaTargetOptions.ReplicaTargetVmFolderName \[System.String\] \($null\)
* $VBRJob.ViReplicaTargetOptions.ReplicaTargetVmFolderRef \[System.String\] \($null\)
* $VBRJob.ViReplicaTargetOptions.UseNetworkMapping \[System.Boolean\] \($null\)
* $VBRJob.ViReplicaTargetOptions.UseReIP \[System.Boolean\] \($null\)
* $VBRJob.ViReplicaTargetOptions.UseVmMapping \[System.Boolean\] \($null\)
* $VBRJob.ViSourceOptions \[Veeam.Backup.Model.CDomViSourceOptions\]
* $VBRJob.ViSourceOptions.GetVCBMode()  Def [Veeam.Backup.Model.VCBModes GetVCBMode()]
* $VBRJob.ViSourceOptions.BackupTemplates \[System.Boolean\]
* $VBRJob.ViSourceOptions.BackupTemplatesOnce \[System.Boolean\]
* $VBRJob.ViSourceOptions.DirtyBlocksNullingEnabled \[System.Boolean\]
* $VBRJob.ViSourceOptions.EnableChangeTracking \[System.Boolean\]
* $VBRJob.ViSourceOptions.EncryptLanTraffic \[System.Boolean\] \($null\)
* $VBRJob.ViSourceOptions.ExcludeSwapFile \[System.Boolean\]
* $VBRJob.ViSourceOptions.FailoverToNetworkMode \[System.Boolean\] \($null\)
* $VBRJob.ViSourceOptions.SetResultsToVmNotes \[System.Boolean\] \($null\)
* $VBRJob.ViSourceOptions.UseChangeTracking \[System.Boolean\]
* $VBRJob.ViSourceOptions.VCBMode \[System.String\]
* $VBRJob.ViSourceOptions.VDDKMode \[System.String\]
* $VBRJob.ViSourceOptions.VmAttributeName \[System.String\]
* $VBRJob.ViSourceOptions.VmNotesAppend \[System.Boolean\]
* $VBRJob.ViSourceOptions.VMToolsQuiesce \[System.Boolean\] \($null\)
* $VBRJob.VssOptions \[Veeam.Backup.Model.CGuestProcessingOptions\]
* $VBRJob.VssOptions.ApplyAppProcOptions()  Def [void ApplyAppProcOptions(Veeam.Backup.Model.CVssSnapshotOptions vssSnapshotOptions, Veeam.Backup.Model.CSqlBackupOptions sqlBackupOptions, Veeam.Backup.Model.COracleBackupOptions oracleBackupOptions, Veeam.Backup.Model.CSharePointBackupOptions sharePointBackupOptions, Veeam.Backup.Model.CExchangeBackupOptions exchangeBackupOptions, Veeam.Backup.Model.CGuestScriptsOptions scriptsOptions, Veeam.Backup.Model.CGuestFSExcludeOptions guestFSExcludeOptions), void ApplyAppProcOptions(Veeam.Backup.Model.CVssSnapshotOptions vssSnapshotOptions, Veeam.Backup.Model.CSqlBackupOptions sqlBackupOptions, Veeam.Backup.Model.CExchangeBackupOptions exchangeBackupOptions), void ApplyAppProcOptions(Veeam.Backup.Model.CVssSnapshotOptions vssSnapshotOptions), void ApplyAppProcOptions(Veeam.Backup.Model.CVssSnapshotOptions vssSnapshotOptions, Veeam.Backup.Model.CSqlBackupOptions sqlBackupOptions), void ApplyAppProcOptions(Veeam.Backup.Model.CVssSnapshotOptions vssSnapshotOptions, Veeam.Backup.Model.COracleBackupOptions oracleBackupOptions), void ApplyAppProcOptions(Veeam.Backup.Model.CVssSnapshotOptions vssSnapshotOptions, Veeam.Backup.Model.CSharePointBackupOptions sharePointBackupOptions), void ApplyAppProcOptions(Veeam.Backup.Model.CVssSnapshotOptions vssSnapshotOptions, Veeam.Backup.Model.CExchangeBackupOptions exchangeBackupOptions), void ApplyAppProcOptions(Veeam.Backup.Model.CVssSnapshotOptions vssSnapshotOptions, Veeam.Backup.Model.CGuestScriptsOptions scriptsOptions), void ApplyAppProcOptions(Veeam.Backup.Model.CVssSnapshotOptions vssSnapshotOptions, Veeam.Backup.Model.CGuestFSExcludeOptions guestFSExcludeOptions)]
* $VBRJob.VssOptions.ApplyCreds()  Def [void ApplyCreds(guid winCredsId, guid linCredsId)]
* $VBRJob.VssOptions.ApplyGuestFSIndexingOptions()  Def [void ApplyGuestFSIndexingOptions(Veeam.Backup.Model.CGuestFSIndexingOptions winGuestFSIndexingOptions, Veeam.Backup.Model.CGuestFSIndexingOptions linGuestFSIndexingOptions)]
* $VBRJob.VssOptions.Clone()  Def [Veeam.Backup.Model.CGuestProcessingOptions Clone(), Veeam.Backup.Model.CGuestProcessingOptions ICloneable[CGuestProcessingOptions].Clone(), System.Object ICloneable.Clone()]
* $VBRJob.VssOptions.CorrectByPolicyType()  Def [void CorrectByPolicyType(Veeam.Backup.Common.CPlatform platform, Veeam.Backup.Model.EEpPolicyType policyType)]
* $VBRJob.VssOptions.IsBackupOracleRequired()  Def [bool IsBackupOracleRequired()]
* $VBRJob.VssOptions.IsBackupSqlRequired()  Def [bool IsBackupSqlRequired()]
* $VBRJob.VssOptions.IsCustomIndexing()  Def [bool IsCustomIndexing()]
* $VBRJob.VssOptions.IsDontTruncateEnabled()  Def [bool IsDontTruncateEnabled()]
* $VBRJob.VssOptions.IsGuestDbBackupEnabled()  Def [bool IsGuestDbBackupEnabled()]
* $VBRJob.VssOptions.IsGuestFsExcludeOptionsRequired()  Def [bool IsGuestFsExcludeOptionsRequired()]
* $VBRJob.VssOptions.IsIndexingRequired()  Def [bool IsIndexingRequired()]
* $VBRJob.VssOptions.IsLinIndexingRequired()  Def [bool IsLinIndexingRequired()]
* $VBRJob.VssOptions.IsScriptingAllowed()  Def [bool IsScriptingAllowed()]
* $VBRJob.VssOptions.IsScriptingTurnedOn()  Def [bool IsScriptingTurnedOn()]
* $VBRJob.VssOptions.IsSharePointProcessingAllowed()  Def [bool IsSharePointProcessingAllowed()]
* $VBRJob.VssOptions.IsTransactionLogsProcessingAllowed()  Def [bool IsTransactionLogsProcessingAllowed()]
* $VBRJob.VssOptions.IsTruncateSqlAllowed()  Def [bool IsTruncateSqlAllowed()]
* $VBRJob.VssOptions.IsWinIndexingRequired()  Def [bool IsWinIndexingRequired()]
* $VBRJob.VssOptions.ResetLinCreds()  Def [void ResetLinCreds()]
* $VBRJob.VssOptions.ResetLinuxGuestFSCustomIndexing()  Def [void ResetLinuxGuestFSCustomIndexing()]
* $VBRJob.VssOptions.ResetWinCreds()  Def [void ResetWinCreds()]
* $VBRJob.VssOptions.Serial()  Def [void Serial(System.Xml.XmlNode node)]
* $VBRJob.VssOptions.Serialize()  Def [string Serialize()]
* $VBRJob.VssOptions.SetScriptingAllowed()  Def [void SetScriptingAllowed()]
* $VBRJob.VssOptions.SetTransactionLogsProcessingAllowed()  Def [void SetTransactionLogsProcessingAllowed()]
* $VBRJob.VssOptions.AreLinCredsSet \[System.Boolean\] \($null\)
* $VBRJob.VssOptions.AreWinCredsSet \[System.Boolean\] \($null\)
* $VBRJob.VssOptions.Enabled \[System.Boolean\] \($null\)
* $VBRJob.VssOptions.ExchangeBackupOptions \[Veeam.Backup.Model.CExchangeBackupOptions\]
* $VBRJob.VssOptions.ExchangeBackupOptions.Apply()  Def [void Apply(Veeam.Backup.Model.CExchangeBackupOptions options)]
* $VBRJob.VssOptions.ExchangeBackupOptions.TransactionLogsProcessing \[Veeam.Backup.Model.ETransactionLogsProcessing\]
* $VBRJob.VssOptions.ExchangeBackupOptions.TransactionLogsProcessing.value__ \[System.Int32\]
* $VBRJob.VssOptions.ExcludedIndexingFolders \[System.String[]\] \($null\)
* $VBRJob.VssOptions.GuestFSExcludeOptions \[Veeam.Backup.Model.CGuestFSExcludeOptions\]
* $VBRJob.VssOptions.GuestFSExcludeOptions.Apply()  Def [void Apply(Veeam.Backup.Model.CGuestFSExcludeOptions options)]
* $VBRJob.VssOptions.GuestFSExcludeOptions.BackupScope \[Veeam.Backup.Model.EGuestFSBackupScope\] \($null\)
* $VBRJob.VssOptions.GuestFSExcludeOptions.ExcludeList \[System.String[]\] \($null\)
* $VBRJob.VssOptions.GuestFSExcludeOptions.FileExcludeEnabled \[System.Boolean\] \($null\)
* $VBRJob.VssOptions.GuestFSExcludeOptions.IncludeList \[System.String[]\] \($null\)
* $VBRJob.VssOptions.GuestFSIndexingType \[Veeam.Backup.Model.EGuestFSIndexingType\] \($null\)
* $VBRJob.VssOptions.GuestProxyAutoDetect \[System.Boolean\]
* $VBRJob.VssOptions.GuestScriptsOptions \[Veeam.Backup.Model.CGuestScriptsOptions\]
* $VBRJob.VssOptions.GuestScriptsOptions.Apply()  Def [void Apply(Veeam.Backup.Model.CGuestScriptsOptions options)]
* $VBRJob.VssOptions.GuestScriptsOptions.CredsId \[System.Guid\]
* $VBRJob.VssOptions.GuestScriptsOptions.IsAtLeastOneScriptSet \[System.Boolean\] \($null\)
* $VBRJob.VssOptions.GuestScriptsOptions.LinScriptFiles \[Veeam.Backup.Model.CScriptFiles\]
* $VBRJob.VssOptions.GuestScriptsOptions.LinScriptFiles.GetPostScriptFilePathWithoutQuotes()  Def [string GetPostScriptFilePathWithoutQuotes()]
* $VBRJob.VssOptions.GuestScriptsOptions.LinScriptFiles.GetPreScriptFilePathWithoutQuotes()  Def [string GetPreScriptFilePathWithoutQuotes()]
* $VBRJob.VssOptions.GuestScriptsOptions.LinScriptFiles.SetInXmlNode()  Def [void SetInXmlNode(System.Xml.XmlNode parentNode, string nodeName)]
* $VBRJob.VssOptions.GuestScriptsOptions.LinScriptFiles.IsAtLeastOneScriptSet \[System.Boolean\] \($null\)
* $VBRJob.VssOptions.GuestScriptsOptions.LinScriptFiles.PostScriptFilePath \[System.String\] \($null\)
* $VBRJob.VssOptions.GuestScriptsOptions.LinScriptFiles.PreScriptFilePath \[System.String\] \($null\)
* $VBRJob.VssOptions.GuestScriptsOptions.ScriptingMode \[Veeam.Backup.Model.EScriptingMode\] \($null\)
* $VBRJob.VssOptions.GuestScriptsOptions.WinScriptFiles \[Veeam.Backup.Model.CScriptFiles\]
* $VBRJob.VssOptions.GuestScriptsOptions.WinScriptFiles.GetPostScriptFilePathWithoutQuotes()  Def [string GetPostScriptFilePathWithoutQuotes()]
* $VBRJob.VssOptions.GuestScriptsOptions.WinScriptFiles.GetPreScriptFilePathWithoutQuotes()  Def [string GetPreScriptFilePathWithoutQuotes()]
* $VBRJob.VssOptions.GuestScriptsOptions.WinScriptFiles.SetInXmlNode()  Def [void SetInXmlNode(System.Xml.XmlNode parentNode, string nodeName)]
* $VBRJob.VssOptions.GuestScriptsOptions.WinScriptFiles.IsAtLeastOneScriptSet \[System.Boolean\] \($null\)
* $VBRJob.VssOptions.GuestScriptsOptions.WinScriptFiles.PostScriptFilePath \[System.String\] \($null\)
* $VBRJob.VssOptions.GuestScriptsOptions.WinScriptFiles.PreScriptFilePath \[System.String\] \($null\)
* $VBRJob.VssOptions.IgnoreErrors \[System.Boolean\] \($null\)
* $VBRJob.VssOptions.IncludedIndexingFolders \[System.String[]\] \($null\)
* $VBRJob.VssOptions.IsFirstUsage \[System.Boolean\]
* $VBRJob.VssOptions.LinCredsId \[System.Guid\]
* $VBRJob.VssOptions.LinExcludedIndexingFolders \[System.String[]\] \($null\)
* $VBRJob.VssOptions.LinGuestFSIndexingOptions \[Veeam.Backup.Model.CGuestFSIndexingOptions\]
* $VBRJob.VssOptions.LinGuestFSIndexingOptions.Apply()  Def [void Apply(Veeam.Backup.Model.CGuestFSIndexingOptions options)]
* $VBRJob.VssOptions.LinGuestFSIndexingOptions.DisableIndexing()  Def [void DisableIndexing()]
* $VBRJob.VssOptions.LinGuestFSIndexingOptions.Enabled \[System.Boolean\] \($null\)
* $VBRJob.VssOptions.LinGuestFSIndexingOptions.ExcludedFolders \[System.String[]\] \($null\)
* $VBRJob.VssOptions.LinGuestFSIndexingOptions.IncludedFolders \[System.String[]\] \($null\)
* $VBRJob.VssOptions.LinGuestFSIndexingOptions.IsIndexingRequired \[System.Boolean\] \($null\)
* $VBRJob.VssOptions.LinGuestFSIndexingOptions.Type \[Veeam.Backup.Model.EGuestFSIndexingType\] \($null\)
* $VBRJob.VssOptions.LinGuestFSIndexingType \[Veeam.Backup.Model.EGuestFSIndexingType\] \($null\)
* $VBRJob.VssOptions.LinIncludedIndexingFolders \[System.String[]\] \($null\)
* $VBRJob.VssOptions.m_isFirstUsage \[System.Boolean\]
* $VBRJob.VssOptions.OracleBackupOptions \[Veeam.Backup.Model.COracleBackupOptions\]
* $VBRJob.VssOptions.OracleBackupOptions.Apply()  Def [void Apply(Veeam.Backup.Model.COracleBackupOptions options)]
* $VBRJob.VssOptions.OracleBackupOptions.DisableBackupLogs()  Def [void DisableBackupLogs()]
* $VBRJob.VssOptions.OracleBackupOptions.DisableProcessing()  Def [void DisableProcessing()]
* $VBRJob.VssOptions.OracleBackupOptions.AccountType \[Veeam.Backup.Model.EOracleAccountType\] \($null\)
* $VBRJob.VssOptions.OracleBackupOptions.ArchivedLogsMaxAgeHours \[System.Int32\]
* $VBRJob.VssOptions.OracleBackupOptions.ArchivedLogsMaxSizeMb \[System.Int32\]
* $VBRJob.VssOptions.OracleBackupOptions.ArchivedLogsTruncation \[Veeam.Backup.Model.EArchivedLogsTruncation\] \($null\)
* $VBRJob.VssOptions.OracleBackupOptions.BackupLogsEnabled \[System.Boolean\] \($null\)
* $VBRJob.VssOptions.OracleBackupOptions.BackupLogsFrequencyMin \[System.Int32\]
* $VBRJob.VssOptions.OracleBackupOptions.ProxyAutoSelect \[System.Boolean\]
* $VBRJob.VssOptions.OracleBackupOptions.RetainDays \[System.Int32\]
* $VBRJob.VssOptions.OracleBackupOptions.SysdbaCredsId \[System.Guid\]
* $VBRJob.VssOptions.OracleBackupOptions.TransactionLogsProcessing \[Veeam.Backup.Model.ETransactionLogsProcessing\] \($null\)
* $VBRJob.VssOptions.OracleBackupOptions.UseDbBackupRetention \[System.Boolean\]
* $VBRJob.VssOptions.SharePointBackupOptions \[Veeam.Backup.Model.CSharePointBackupOptions\]
* $VBRJob.VssOptions.SharePointBackupOptions.Apply()  Def [void Apply(Veeam.Backup.Model.CSharePointBackupOptions options)]
* $VBRJob.VssOptions.SharePointBackupOptions.BackupEnabled \[System.Boolean\]
* $VBRJob.VssOptions.SharePointBackupOptions.CredsId \[System.Guid\]
* $VBRJob.VssOptions.SqlBackupOptions \[Veeam.Backup.Model.CSqlBackupOptions\]
* $VBRJob.VssOptions.SqlBackupOptions.Apply()  Def [void Apply(Veeam.Backup.Model.CSqlBackupOptions options)]
* $VBRJob.VssOptions.SqlBackupOptions.BackupLogsEnabled \[System.Boolean\] \($null\)
* $VBRJob.VssOptions.SqlBackupOptions.BackupLogsFrequencyMin \[System.Int32\]
* $VBRJob.VssOptions.SqlBackupOptions.CredsId \[System.Guid\]
* $VBRJob.VssOptions.SqlBackupOptions.NeverTruncateLogs \[System.Boolean\] \($null\)
* $VBRJob.VssOptions.SqlBackupOptions.ProxyAutoSelect \[System.Boolean\]
* $VBRJob.VssOptions.SqlBackupOptions.RetainDays \[System.Int32\]
* $VBRJob.VssOptions.SqlBackupOptions.TransactionLogsProcessing \[Veeam.Backup.Model.ETransactionLogsProcessing\]
* $VBRJob.VssOptions.SqlBackupOptions.TransactionLogsProcessing.value__ \[System.Int32\]
* $VBRJob.VssOptions.SqlBackupOptions.UseDbBackupRetention \[System.Boolean\]
* $VBRJob.VssOptions.VssSnapshotOptions \[Veeam.Backup.Model.CVssSnapshotOptions\]
* $VBRJob.VssOptions.VssSnapshotOptions.Apply()  Def [void Apply(Veeam.Backup.Model.CVssSnapshotOptions options)]
* $VBRJob.VssOptions.VssSnapshotOptions.ApplicationProcessingEnabled \[System.Boolean\]
* $VBRJob.VssOptions.VssSnapshotOptions.Enabled \[System.Boolean\] \($null\)
* $VBRJob.VssOptions.VssSnapshotOptions.IgnoreErrors \[System.Boolean\] \($null\)
* $VBRJob.VssOptions.VssSnapshotOptions.IsCopyOnly \[System.Boolean\] \($null\)
* $VBRJob.VssOptions.WinCredsId \[System.Guid\]
* $VBRJob.VssOptions.WinGuestFSIndexingOptions \[Veeam.Backup.Model.CGuestFSIndexingOptions\]
* $VBRJob.VssOptions.WinGuestFSIndexingOptions.Apply()  Def [void Apply(Veeam.Backup.Model.CGuestFSIndexingOptions options)]
* $VBRJob.VssOptions.WinGuestFSIndexingOptions.DisableIndexing()  Def [void DisableIndexing()]
* $VBRJob.VssOptions.WinGuestFSIndexingOptions.Enabled \[System.Boolean\] \($null\)
* $VBRJob.VssOptions.WinGuestFSIndexingOptions.ExcludedFolders \[System.String[]\] \($null\)
* $VBRJob.VssOptions.WinGuestFSIndexingOptions.IncludedFolders \[System.String[]\] \($null\)
* $VBRJob.VssOptions.WinGuestFSIndexingOptions.IsIndexingRequired \[System.Boolean\] \($null\)
* $VBRJob.VssOptions.WinGuestFSIndexingOptions.Type \[Veeam.Backup.Model.EGuestFSIndexingType\] \($null\)



