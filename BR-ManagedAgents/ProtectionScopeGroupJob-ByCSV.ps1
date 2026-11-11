#Options & credentials to be modified per scope/backup job
$FilePath = '\\fileserver\share\file.csv'
$Repository = Get-VBRBackupRepository -Name 'RepositoryName' #-Scaleout  #uncomment this parameter if scale-out repository
$DailyBackup = New-VBRDailyOptions -DayOfWeek Friday -Period 21:00
$BackupSchedule = New-VBRServerScheduleOptions -Type 'Daily' -DailyOptions $DailyBackup

#Get existing Master Windows credential
$MasterWindowsCredentialUsername = 'FSGLAB\svc_veeam_bkup'
$MasterWindowsCredentialDescription = 'Veeam Backup Access to member servers'
$VeeamMasterWindowsCredential = Get-VBRCredentials -Name $MasterWindowsCredentialUsername | Where-Object Description -eq $MasterWindowsCredentialDescription

#Get existing Windows credential for custom hosts
$CustomWindowsCredentialUsername = 'FSGLAB\svc_veeam_bkup'
$CustomWindowsCredentialDescription = 'Veeam Backup Access to member servers'
$VeeamCustomWindowsCredential = Get-VBRCredentials -Name $CustomWindowsCredentialUsername | Where-Object Description -eq $CustomWindowsCredentialDescription

#Get existing SQL credential
$SQLCredentialUsername = 'FSGLAB\svc_veeam_bkup'
$SQLCredentialDescription = 'Veeam Backup Access to member servers'
$VeeamSQLCredential = Get-VBRCredentials -Name $SQLCredentialUsername | Where-Object Description -eq $SQLCredentialDescription

#Get existing credential for fileshare access
$FileshareCredentialUsername = 'FSGLAB\svc_veeam_bkup'
$FileshareCredentialDescription = 'Veeam Backup Access to member servers'
$VeeamFileshareCredential = Get-VBRCredentials -Name $FileshareCredentialUsername | Where-Object Description -eq $FileshareCredentialDescription

#Create schedule for 1-hour discovery cycle
$Periodically = New-VBRPeriodicallyOptions -FullPeriod 1 -PeriodicallyKind Hours
$Schedule = New-VBRProtectionGroupScheduleOptions -PolicyType Periodically -PeriodicallyOptions $Periodically

#Create CSV container when all hosts using master credential
$CSVScope = New-VBRCSVContainer -Path $FilePath -MasterCredentials $VeeamMasterWindowsCredential -NetworkCredentials $VeeamFileshareCredential

#Create CSV container when using Custom Credentials for some hosts
#$CustomHosts = 'host1.domain', 'host2.domain', 'host3.domain'
#$CredentialsArray = $CustomHosts | ForEach-Object { New-VBRCSVCustomCredentials -HostName $PSItem -Credentials $VeeamCustomWindowsCredential }
#$CSVScope = New-VBRCSVContainer -Path $FilePath -MasterCredentials $VeeamMasterWindowsCredential -NetworkCredentials $VeeamFileshareCredential -UseCustomCredentials -CustomCredentials $CredentialsArray

#Create protection group from CSV container, set discovery cycle:
$ProtGroup = Add-VBRProtectionGroup -Name 'CSV' -Container $CSVScope -ScheduleOptions $Schedule

#Set SQL options - assuming log truncation every 60 minutes, keeping log backups until image backs are deleted
$SQLOptions = New-VBRSQLProcessingOptions -TransactionAction 'Truncate' -Credentials $VeeamSQLCredential -LogBackupPeriod '60' -LogRetainAction 'WaitForBackupDeletion'
$AppProcessOptions = New-VBRApplicationProcessingOptions -BackupObject $ProtGroup -OSPlatform 'Windows' -Enable -GeneralTransactionLogAction 'ProcessLogsWithJob' -IgnoreErrors -SQLProcessingOptions $SQLOptions

#Create agent backup job for scope trageting CSV file, enable scheduling, enable SQL application processing, 14 restore points, and set target backup repository
#Assuming no options selected for indexing, deleted computer retention, notification, compact of full backup, health check, active/synthetic full, storage (compression & dedupe), custom scripts during job
Add-VBRComputerBackupJob -OSPlatform 'Windows' -Type 'Server' -Mode 'ManagedByBackupServer' -BackupObject $ProtGroup -BackupType 'EntireComputer' -EnableSchedule -ApplicationProcessingOptions $AppProcessOptions -EnableApplicationProcessing -ScheduleOptions $BackupSchedule -RetentionPolicy '14' -BackupRepository $Repository -Description 'Backup of CSV protection group' -Name 'ScriptBackup-CSVProtectionGroup'
