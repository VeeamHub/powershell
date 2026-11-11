Import-Module Veeam.Backup.PowerShell

$AgentBackups = Get-VBRBackup | Where-Object { $_.JobType -eq 'EpAgentManagement' }

[System.Collections.ArrayList]$AllBackupFilesOutput = foreach ($AgentBackup in $AgentBackups) {

  $BackupFiles = Get-VBRBackupFile -Backup $AgentBackup

  $JobName = $($AgentBackup.GetParent().JobName)
  $BackupName = $AgentBackup.Name

  foreach ($File in $BackupFiles) {
    $StoragePoint = $AgentBackup.GetStorage($File.Id)

    $reportFileOutputObject = [pscustomobject][ordered] @{

      'JobName'        = $JobName
      'BackupName'     = $BackupName
      'FilePath'       = $StoragePoint.FilePath;
      'PartialPath'    = $StoragePoint.PartialPath;
      'CreationTime'   = $StoragePoint.CreationTime
      'IsFull'         = $StoragePoint.IsFull
      'IsAvailable'    = $StoragePoint.IsAvailable
      'BackupSize(GB)' = ($StoragePoint.Stats.BackupSize / 1GB)
      'DataSize(GB)'   = ($StoragePoint.Stats.DataSize / 1GB)
      'DedupRatio%'    = $StoragePoint.Stats.DedupRatio
      'CompressRatio%' = $StoragePoint.Stats.CompressRatio
    } #end reportFileOutputObject

    $reportFileOutputObject

  }

}

$AllBackupFilesOutput | Export-Csv .\EPPointsReport.csv -NoTypeInformation