#Requires -Version 4
#Requires -RunAsAdministrator
<#
.Synopsis
  Simple Veeam report to give details of task sessions for VMware backup jobs
.Notes
  Version: 1.0
  Author: Joe Houghes
  Modified Date: 7-30-20
.EXAMPLE
  Get-VeeamBackupSessionReport | Format-Table -Autosize
.EXAMPLE
  Get-VeeamBackupSessionReport -VBRServer ausveeambr | Format-Table -Autosize
.EXAMPLE
  Get-VeeamBackupSessionReport -VBRServer ausveeambr | Export-Csv C:\Temp\VeeamBackupSessionReport.csv -NoTypeInformation

#>

function Get-VeeamBackupSessionReport {
  [CmdletBinding()]
  param (
    [string]$VBRServer = 'localhost'
  )
  begin {

    #Load the Veeam PSSnapin
    if (!(Get-PSSnapin -Name VeeamPSSnapIn -ErrorAction SilentlyContinue)) {
      Add-PSSnapin -Name VeeamPSSnapIn
      Disconnect-VBRServer
      Connect-VBRServer -Server $VBRServer
    }

    $AllJobs = Get-VBRJob -WarningAction SilentlyContinue | Where-Object { ($_.JobType -eq 'Backup') -AND ($_.BackupPlatform.Platform -eq 'EVmware') }

    [System.Collections.ArrayList]$AllTasksOutput = @()

  }

  process {

    foreach ($EachJob in $AllJobs) {

      $JobSessions = [Veeam.Backup.Core.CBackupSession]::GetByJob($EachJob.Id)

      if ([bool]$JobSessions) {

        foreach ($CurrentSession in $JobSessions) {

          $Dedupe = [string]$([math]::round($CurrentSession.BackupStats.GetDedupeX(), 1)) + 'x'
          $Compression = [string]$([math]::round($CurrentSession.BackupStats.GetCompressX(), 1)) + 'x'

          $TaskOutputResult = [pscustomobject][ordered] @{

            'JobName'        = $CurrentSession.JobName;
            'Result'         = $CurrentSession.Result;
            'DataSize(GB)'   = [math]::round($CurrentSession.BackupStats.DataSize / 1GB, 2);
            'BackupSize(GB)' = [math]::round($CurrentSession.BackupStats.BackupSize / 1GB, 2);
            'DedupRatio'     = $Dedupe;
            'CompressRatio'  = $Compression;
            'Date'           = $CurrentSession.CreationTime;

          } #end TaskOutputResult object

          $null = $AllTasksOutput.Add($TaskOutputResult)

        } #end foreach JobSession

      } #end if JobSessions

    } #end foreach Job

  }

  end {

    Write-Output $AllTasksOutput

  }

}