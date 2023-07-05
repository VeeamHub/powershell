#Requires -Version 4
#Requires -RunAsAdministrator
<#
.Synopsis
   Simple Veeam report to expand on information from 'Veeam Backup Billing' report in VeeamOne
.Notes
    Version: 0.1
    Author: Joe Houghes
    Modified Date: 11-28-2018
.EXAMPLE
   Get-VeeamBackupSize | Format-Table
.EXAMPLE
   Get-VeeamBackupSize | Export-Csv VeeamBackupSize.csv -NoTypeInformation
#>


#Load the Veeam Module
Import-Module Veeam.Backup.PowerShell

#Price per GB for storage calculations in cents
$PriceGB = 0.15

#Determine which backup repositories are configured for per-VM backups and add to array
$repositories += Get-VBRBackupRepository | Select-Object Name, Id, @{n = 'PerVM'; e = { $PSItem.Options.OneBackupFilePerVm } }

#Determine which scale-out repositories are configured for per-VM backups
$sobr = Get-VBRBackupRepository -ScaleOut
foreach ($sobrrepo in $sobr) {
  $repositories += $sobrrepo | Select-Object Name, Id, @{n = 'PerVM'; e = { [bool]($PSItem | Get-VBRRepositoryExtent | Select-Object $PSItem.Repository.Options.OneBackupFilePerVm) } }
}

function Get-VeeamBackupSize {
  $reportJobOutput = @()

  $reportJobs = Get-VBRJob | Where-Object { $PSItem.JobType -eq 'Backup' -OR $PSItem.JobType -eq 'BackupSync' -AND $PSItem.BackupPlatform.Platform -eq 'EVmware' }

  foreach ($reportJob in $reportJobs) {

    $currentBackup = Get-VBRBackup -Name $reportJob.Name
    $currentJobVMs = $reportJob.GetViOijs() | Select-Object Name, ObjectId

    #Get all backup files associated with backup job
    $currentJobStorage = $currentBackup.GetAllStorages() | Select-Object Id, CreationTime, @{n = 'BackupSize'; e = { $PSItem.Stats.BackupSize } }

    #Check if backup is on a per-VM repository, if so calculate files as per VM backup sizes
    if ([bool]($repositories | Where-Object -Property Id -EQ -Value $currentBackup.RepositoryId | Select-Object -ExpandProperty PerVM)) {

      $currentRestorePoints = $currentBackup | Get-VBRRestorePoint | Select-Object VMName, StorageId

      foreach ($currentJobStorageFile in $currentJobStorage) {
        $backupSizeGB = [math]::round(($currentJobStorageFile.BackupSize / 1GB), 2)

        $reportJobOutputObject = New-Object -TypeName PSCustomObject -Property @{
          'BackupJob'      = $reportJob.Name
          'VMName'         = $($currentRestorePoints | Where-Object Storageid -EQ $currentJobStorageFile.id | Select-Object -ExpandProperty VMName)
          'BackupSize(GB)' = $backupSizeGB
          'BackupCost($)'  = [math]::round(($backupSizeGB * $PriceGB), 2)
        }

        $reportJobOutput += $reportJobOutputObject

      }

    }

    else {
      foreach ($currentJobStorageFile in $currentJobStorage) {
        $backupSizeGB = [math]::round(($currentJobStorageFile.BackupSize / 1GB), 2)
        $numVMs = @($currentJobVMs).count

        if ($numVMs -eq '1') {
          $VMName = $currentJobVMs | Select-Object -ExpandProperty Name
        }

        else { $VMName = "$numVMs VM(s)" }

        $reportJobOutputObject = New-Object -TypeName PSCustomObject -Property @{
          'BackupJob'      = $reportJob.Name
          'VMName'         = $VMName
          'BackupSize(GB)' = $backupSizeGB
          'BackupCost($)'  = [math]::round(($backupSizeGB * $PriceGB), 2)
        }

        $reportJobOutput += $reportJobOutputObject

      }

    }

  }

  Write-Output $reportJobOutput | Select-Object 'BackupJob', 'VMName', 'BackupSize(GB)', 'BackupCost($)'

}