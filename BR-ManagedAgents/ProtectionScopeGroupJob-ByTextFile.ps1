#Options & credentials to be modified per scope/backup job
$MasterWindowsCredentialUsername = 'FSGLAB\svc_veeam_bkup'
$MasterWindowsCredentialDescription = 'Veeam Backup Access to member servers'
$VeeamMasterWindowsCredential = Get-VBRCredentials -Name $MasterWindowsCredentialUsername | Where-Object Description -eq $MasterWindowsCredentialDescription

$FilePath = '\\fileserver\share\servers.txt'
$ServerList = Get-Content $FilePath

$Repository = Get-VBRBackupRepository -Name 'ReFS-PerVM' #-Scaleout  #uncomment this parameter if scale-out repository
$DailyBackup = New-VBRDailyOptions -DayOfWeek Friday -Period 21:00
$BackupSchedule = New-VBRServerScheduleOptions -Type 'Daily' -DailyOptions $DailyBackup

#Create schedule for 1-hour discovery cycle
$Periodically = New-VBRPeriodicallyOptions -FullPeriod 1 -PeriodicallyKind Hours
$Schedule = New-VBRProtectionGroupScheduleOptions -PolicyType Periodically -PeriodicallyOptions $Periodically

#Create server list for hosts using the bulk credential
$Servers = $ServerList | ForEach-Object { New-VBRIndividualComputerCustomCredentials -HostName $PSItem -Credentials $VeeamMasterWindowsCredential }

<#
#Block section to additional show the handling of Custom Credentials for some hosts
$CustomWindowsCredentialUsername = 'FSGLAB\svc_veeam_bkup'
$CustomWindowsCredentialDescription = 'Veeam Backup Access to member servers'
$VeeamCustomWindowsCredential = Get-VBRCredentials -Name $CustomWindowsCredentialUsername | Where-Object Description -eq $CustomWindowsCredentialDescription

$FilePathCustom = '\\fileserver\share\servers-customcreds.txt'
$CustomHosts = Get-Content $FilePathCustom   
$CredentialsArray = $CustomHosts | ForEach-Object { New-VBRIndividualComputerCustomCredentials -HostName $PSItem -Credentials $VeeamCustomWindowsCredential }
$Servers = [array]$Servers + $CredentialsArray
#>

#Create IndividualComputerContainer container with hosts using both bulk & custom credentials
$ServerScope = New-VBRIndividualComputerContainer -CustomCredentials $Servers

#Create the protection groups of individual computer objects
$ProtGroup = Add-VBRProtectionGroup -Name "ServersfromTextFile" -Container $ServerScope -ScheduleOptions $Schedule

<#Use this block for SQL options
#$SQLCred = Get-Credential -Message "Credential for SQL interaction"
#Set SQL options - assuming log truncation every 60 minutes, keeping log backups until image backs are deleted
$SQLOptions = New-VBRSQLProcessingOptions -TransactionAction 'Truncate' -Credentials $SQLCred -LogBackupPeriod '60' -LogRetainAction 'WaitForBackupDeletion'
$AppProcessOptions = New-VBRApplicationProcessingOptions -BackupObject $ProtGroup -OSPlatform 'Windows' -Enable -GeneralTransactionLogAction 'ProcessLogsWithJob' -IgnoreErrors -SQLProcessingOptions $SQLOptions
#>

#Create agent backup job for scope targeting text file, enable scheduling, 14 restore points, and set target backup repository
#Assuming no options selected for SQL, indexing, deleted computer retention, notification, compact of full backup, health check, active/synthetic full, storage (compression & dedupe), nor custom scripts during job
$AppProcessOptions = New-VBRApplicationProcessingOptions -BackupObject $ProtGroup -OSPlatform 'Windows' -Enable -GeneralTransactionLogAction 'ProcessLogsWithJob'
$AgentBackupJob = Add-VBRComputerBackupJob -OSPlatform 'Windows' -Type 'Server' -Mode 'ManagedByBackupServer' -BackupObject $ProtGroup -BackupType 'EntireComputer' -EnableSchedule -ApplicationProcessingOptions $AppProcessOptions -EnableApplicationProcessing -ScheduleOptions $BackupSchedule -RetentionPolicy '14' -BackupRepository $Repository -Description 'Backup of CSV protection group' -Name 'ScriptBackup-TextProtectionGroup'

#Output newly built agent job
Write-Output $AgentBackupJob