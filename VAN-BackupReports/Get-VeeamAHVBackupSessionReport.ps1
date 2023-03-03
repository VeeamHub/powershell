#Requires -Version 4
#Requires -RunAsAdministrator
<#
.Synopsis
  Simple Veeam report to give details of task sessions for current Nutanix backup jobs
.Notes
  Version: 1.0
  Author: Joe Houghes
  Modified Date: 9-24-20
.EXAMPLE
  Get-VeeamAHVBackupSessionReport -LastDays 10
.EXAMPLE
  Get-VeeamAHVBackupSessionReport -VBRServer ausveeambr -LastDays 10 | Format-Table -Autosize
.EXAMPLE
  Get-VeeamAHVBackupSessionReport -VBRServer ausveeambr -LastDays 10 | Export-Csv C:\Temp\VeeamAHVBackupSessionReport.csv -NoTypeInformation

#>

function Get-VeeamAHVBackupSessionReport {
  [CmdletBinding()]
  param (
    [Parameter(Position = 0)]
    [string]$VBRServer = 'localhost',

    [Parameter(Mandatory = $true,
      Position = 1)]
    [int]$LastDays
  )
  begin {

    #Load the Veeam PSSnapin
    if (!(Get-PSSnapin -Name VeeamPSSnapIn -ErrorAction SilentlyContinue)) {
      Add-PSSnapin -Name VeeamPSSnapIn
      Disconnect-VBRServer
      Connect-VBRServer -Server $VBRServer
    }

    $ReportDate = Get-Date

    $Nutanix_Backups = Get-VBRBackup | Where-Object { $_.TypeToString -like "Nutanix*" -AND $_.JobType -ne "VmbApiPolicyTempJob" }

  }

  process {

    $AllJobResults = foreach ($EachBackup in $Nutanix_Backups) {
      try {
        $EachJob = $EachBackup.GetJob()
      } catch {
        $EachJob = $null
      }

      if ($EachJob) {
        $JobSessions = [Veeam.Backup.Core.CBackupSession]::GetByJob($EachJob.Id) | Where-Object { $_.CreationTime -ge ($ReportDate.AddDays(-$LastDays)) }

        $JobResult = if ([bool]$JobSessions) {

          $SessionOutputResult = foreach ($CurrentSession in $JobSessions) {

            $TaskSession = $CurrentSession.GetTaskSessions()

            if ($CurrentSession.IsFullMode) {
              $BackupType = 'Full'
            } else {
              $BackupType = 'Incremental'
            }

            $TotalSize = $CurrentSession.Progress.TotalSize
            $DataRead = $CurrentSession.Progress.ReadSize
            $Transferred = $CurrentSession.Progress.TransferedSize
            $BackupSize = $CurrentSession.BackupStats.BackupSize

            switch ($TotalSize) {
              { $_ -gt 1073741824 } { $TotalSizeOutput = "$([math]::round($TotalSize / 1GB, 2)) GB"; break }
              { $_ -gt 1048576 } { $TotalSizeOutput = "$([math]::round($TotalSize / 1MB, 2)) MB"; break }
              { $_ -gt 1024 } { $TotalSizeOutput = "$([math]::round($TotalSize / 1KB, 2)) KB"; break }
              default { $TotalSizeOutput = "$TotalSize B"; break }
            }

            switch ($DataRead) {
              { $_ -gt 1073741824 } { $DataReadOutput = "$([math]::round($DataRead / 1GB, 2)) GB"; break }
              { $_ -gt 1048576 } { $DataReadOutput = "$([math]::round($DataRead / 1MB, 2)) MB"; break }
              { $_ -gt 1024 } { $DataReadOutput = "$([math]::round($DataRead / 1KB, 2)) KB"; break }
              default { $DataReadOutput = "$DataRead B"; break }
            }

            switch ($Transferred) {
              { $_ -gt 1073741824 } { $TransferredOutput = "$([math]::round($Transferred / 1GB, 2)) GB"; break }
              { $_ -gt 1048576 } { $TransferredOutput = "$([math]::round($Transferred / 1MB, 2)) MB"; break }
              { $_ -gt 1024 } { $TransferredOutput = "$([math]::round($Transferred / 1KB, 2)) KB"; break }
              default { $TransferredOutput = "$Transferred B"; break }
            }

            switch ($BackupSize) {
              { $_ -gt 1073741824 } { $BackupSizeOutput = "$([math]::round($BackupSize / 1GB, 2)) GB"; break }
              { $_ -gt 1048576 } { $BackupSizeOutput = "$([math]::round($BackupSize / 1MB, 2)) MB"; break }
              { $_ -gt 1024 } { $BackupSizeOutput = "$([math]::round($BackupSize / 1KB, 2)) KB"; break }
              default { $BackupSizeOutput = "$BackupSize B"; break }
            }

            $Dedupe = [string]$([math]::round($CurrentSession.BackupStats.GetDedupeX(), 2)) + 'x'
            $Compression = [string]$([math]::round($CurrentSession.BackupStats.GetCompressX(), 2)) + 'x'

            [pscustomobject][ordered] @{

              'JobName'     = $EachJob.Name
              'VM'          = $TaskSession.Name
              'Date'        = $CurrentSession.CreationTime
              'BackupType'  = $BackupType
              'Status'      = $CurrentSession.Result
              'StartTime'   = $CurrentSession.CreationTime
              'EndTime'     = $CurrentSession.EndTime
              'Duration'    = $CurrentSession.Progress.Duration.ToString()
              'TotalSize'   = $TotalSizeOutput
              'DataRead'    = $DataReadOutput
              'Transferred' = $TransferredOutput
              'BackupSize'  = $BackupSizeOutput
              'Dedupe'      = $Dedupe
              'Compression' = $Compression

            } #end TaskOutputResult object

          } #end foreach JobSession

          $SessionOutputResult

          Remove-Variable CurrentSession, TaskSession, BackupType, TotalSize, DataRead, Transferred, BackupSize, TotalSizeOutput, DataReadOutput, TransferredOutput, BackupSizeOutput, Dedupe, Compression -ErrorAction SilentlyContinue
        } #end if JobSessions

        $JobResult
      } #end if EachJob

      Remove-Variable EachJob, EachJobName, JobSessions -ErrorAction SilentlyContinue
    }

  }

  end {

    #Write results object out to pipeline
    $AllJobResults

  }

}
