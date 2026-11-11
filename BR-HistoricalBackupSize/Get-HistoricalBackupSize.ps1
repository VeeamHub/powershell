#Requires -Version 4
#Requires -RunAsAdministrator
<#
.Synopsis
  Simple Veeam report to give details of source data & backup size per backup file/repository
.Notes
  Version: 0.1
  Author: Joe Houghes
  Modified Date: 9-6-2019
.EXAMPLE
  Get-VeeamHistoricalBackupSize | Format-Table
.EXAMPLE
  Get-VeeamHistoricalBackupSize | Export-Csv VeeamHistoricalBackupSize.csv -NoTypeInformation
#>


#Load the Veeam module
Import-Module Veeam.Backup.PowerShell

$repositories = @()

#Determine which backup repositories are configured for per-VM backups and add to array
$repositories += Get-VBRBackupRepository | Select-Object Name, Id, @{n = 'PerVM'; e = { $PSItem.Options.OneBackupFilePerVm } }

#Determine which scale-out repositories are configured for per-VM backups
$sobr = Get-VBRBackupRepository -ScaleOut

if ($sobr) {

  foreach ($sobrrepo in $sobr) {
    $repositories += $sobrrepo | Select-Object Name, Id, @{n = 'PerVM'; e = { [bool]($PSItem | Get-VBRRepositoryExtent | Select-Object $PSItem.Repository.Options.OneBackupFilePerVm) } }
  }

}


function Get-VeeamHistoricalBackupSize {
  $reportJobOutput = @()

  $reportJobs = Get-VBRJob | Where-Object { $PSItem.JobType -eq 'Backup' -AND $PSItem.BackupPlatform.Platform -eq 'EVmware' }

  foreach ($reportJob in $reportJobs) {

    $currentBackup = Get-VBRBackup -Name $reportJob.Name
    $currentJobVMs = $reportJob.GetViOijs() | Select-Object Name, ObjectId

    #Get all backup files associated with backup job
    $currentJobStorage = $currentBackup.GetAllStorages() | Select-Object Id, CreationTime, @{n = 'BackupSize'; e = { $PSItem.Stats.BackupSize } }, @{n = 'DataSize'; e = { $PSItem.Stats.DataSize } }

    #Check if backup is on a per-VM repository, if so calculate files as per VM backup sizes
    if ([bool]($repositories | Where-Object -Property Id -eq -Value $currentBackup.RepositoryId | Select-Object -ExpandProperty PerVM)) {

      $currentRestorePoints = $currentBackup | Get-VBRRestorePoint | Select-Object VMName, StorageId

      foreach ($currentJobStorageFile in $currentJobStorage) {
        $backupSizeGB = [math]::round(($currentJobStorageFile.BackupSize / 1GB), 2)
        $dataSizeGB = [math]::round(($currentJobStorageFile.DataSize / 1GB), 2)

        $reportJobOutputObject = New-Object -TypeName PSCustomObject -Property @{
          'BackupJob'      = $reportJob.Name
          'VMName'         = $($currentRestorePoints | Where-Object Storageid -EQ $currentJobStorageFile.id | Select-Object -ExpandProperty VMName)
          'Timestamp'      = $currentJobStorageFile.CreationTime
          'BackupSize(GB)' = $backupSizeGB
          'DataSize(GB)'   = $dataSizeGB
        }

        $reportJobOutput += $reportJobOutputObject

      }

    }
    else {
      foreach ($currentJobStorageFile in $currentJobStorage) {
        $backupSizeGB = [math]::round(($currentJobStorageFile.BackupSize / 1GB), 2)
        $dataSizeGB = [math]::round(($currentJobStorageFile.DataSize / 1GB), 2)
        $numVMs = @($currentJobVMs).count

        if ($numVMs -eq '1') {
          $VMName = $currentJobVMs | Select-Object -ExpandProperty Name
        }

        else { $VMName = ($currentJobVMs | Select-Object -ExpandProperty Name) -join '; ' }

        $reportJobOutputObject = New-Object -TypeName PSCustomObject -Property @{
          'BackupJob'      = $reportJob.Name
          'VMName'         = $VMName
          'Timestamp'      = $currentJobStorageFile.CreationTime
          'BackupSize(GB)' = $backupSizeGB
          'DataSize(GB)'   = $dataSizeGB
        }

        $reportJobOutput += $reportJobOutputObject

      }

    }

  }

  Write-Output $reportJobOutput | Select-Object 'BackupJob', 'VMName', 'Timestamp', 'BackupSize(GB)', 'DataSize(GB)'

}