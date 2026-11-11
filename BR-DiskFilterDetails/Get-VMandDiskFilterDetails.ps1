#Requires -Version 4
#Requires -RunAsAdministrator
<#
.Synopsis
    Simple Veeam report to export details about VM job objects and their disk mode & filters
.Notes
    Version: 0.2
    Author: Joe Houghes
    Modified Date: 3-5-2021
.EXAMPLE
    Get-VMandDiskFilterDetails | Format-Table
.EXAMPLE
    Get-VMandDiskFilterDetails | Export-Csv VM_DiskFilterDetails.csv -NoTypeInformation
#>

function Get-VMandDiskFilterDetails {
  [CmdletBinding()]
  param ()

  begin {}

  process {

    $ReportJobs = Get-VBRJob | Where-Object { $PSItem.JobType -eq 'Backup' -OR $PSItem.JobType -eq 'BackupSync' -AND $PSItem.BackupPlatform.Platform -eq 'EVmware' }
    $Repositories = Get-VBRBackupRepository | Select-Object Name, Id

    $reportJobOutput = foreach ($CurrentJob in $ReportJobs) {

      $CurrentBackup = Get-VBRBackup -Name $CurrentJob.Name
      $CurrentRepo = $Repositories | Where-Object -Property Id -EQ -Value $CurrentBackup.RepositoryId
      $CurrentJobVMs = $CurrentJob.GetViOijs()

      $reportVMOutput = foreach ($CurrentVM in $CurrentJobVMs) {

        $DiskMode = $CurrentVM.DiskFilterInfo.Mode
        $DisksSpecific = switch ($DiskMode) {
          AllDisks { 'AllDisks' }
          default { ($CurrentVM.DiskFilter.Disks | Select-Object -ExpandProperty DisplayName) -join '; ' }
        }

        [pscustomobject] @{
          'BackupJob'     = $CurrentJob.Name
          'VMName'        = $CurrentVM.Name
          'Location'      = $CurrentRepo.Name
          'DiskMode'      = $DiskMode
          'DisksSpecific' = $DisksSpecific
        }

      } #end foreach CurrentVM

      $reportVMOutput

    } #end foreach CurrentJob

  }

  end {

    if ($Disconnect) { Disconnect-VBRServer }
    $reportJobOutput

  }

}