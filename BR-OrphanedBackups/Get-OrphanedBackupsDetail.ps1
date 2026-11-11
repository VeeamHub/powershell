#Requires -Version 4
#Requires -RunAsAdministrator
<#
.Synopsis
  Simple report to give details of restore points within backups which no longs have existing Veeam jobs
.Notes
  Version: 1.0
  Author: Joe Houghes
  Modified Date: 8-27-20
.EXAMPLE
  Get-OrphanedBackupsDetail | Format-Table -Autosize
.EXAMPLE
  Get-VeeamSessionReport -VBRServer ausveeambr | Export-Csv D:\Temp\VeeamSessionReport.csv -NoTypeInformation

#>

function Get-OrphanedBackupsDetail {
  [CmdletBinding()]
  param (
    [string]$VBRServer = 'localhost'
  )

  begin {

    #Load the Veeam PSSnapin
    if (!(Get-PSSnapin -Name VeeamPSSnapIn -ErrorAction SilentlyContinue)) {
      Add-PSSnapin -Name VeeamPSSnapIn
      Connect-VBRServer -Server $VBRServer
    }

    Disconnect-VBRServer
    Connect-VBRServer -Server $VBRServer

  }

  process {

    $OrphanedBackups = Get-VBRBackup | Where-Object { $_.IsJobExists() -eq $False -AND $_.IsEmpty() -eq $False }

    $Repos = Get-VBRBackupRepository
    $SOBRs = Get-VBRBackupRepository -ScaleOut

    $RepoDetail = foreach ($Repo in $Repos) {
      [PSCustomObject] @{
        'Name' = $Repo.Name
        'ID'   = $Repo.ID
      }
    } #end foreach Repositories

    $SOBRDetail = foreach ($Repo in $SOBRs) {
      [PSCustomObject] @{
        'Name' = $Repo.Name
        'ID'   = $Repo.ID
      }
    }

    $AllRepos = $RepoDetail + $SOBRDetail

    $OrphanedRestorePoints = foreach ($CurrentBackup in $OrphanedBackups) {

      $RestorePoints = $CurrentBackup | Get-VBRRestorePoint
      $StorageFiles = $CurrentBackup.GetAllStorages()
      $Repo = $AllRepos | Where-Object Id -eq $CurrentBackup.RepositoryId

      $OrphanedRestorePointsObject = foreach ($CurrentRestorePoint in $RestorePoints) {

        $EachFile = $StorageFiles | Where-Object { $_.Id -eq $CurrentRestorePoint.StorageId }
        $FileName = ($EachFile.PartialPath.Elements[0])

        [pscustomobject] @{

          'Hostname'     = $CurrentRestorePoint.Name
          'CreationTime' = $CurrentRestorePoint.CreationTime
          'Job Name'     = $CurrentBackup.JobName
          'FileSize(GB)' = [math]::Round(($EachFile.Stats.BackupSize / 1GB), 4)
          'Full/Inc'     = $CurrentRestorePoint.Algorithm
          'Job Type'     = $CurrentBackup.TypeToString
          'FileName'     = $FileName
          'IsAvailable'  = $EachFile.IsAvailable
          'FilePath'     = $EachFile.FilePath
          'RepoName'     = $Repo.Name
          'RepoID'       = $Repo.ID

        }

      } #end foreach CurrentRestorePoint

      $OrphanedRestorePointsObject
    
    } #end foreach CurrentBackup

  }

  end {

    Disconnect-VBRServer

    $OrphanedRestorePoints

  }

}