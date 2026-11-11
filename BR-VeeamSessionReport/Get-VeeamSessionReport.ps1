#Requires -Version 4
#Requires -RunAsAdministrator
<#
.Synopsis
  Simple Veeam report to give details of task sessions for VMware backup jobs
.Notes
  Version: 1.0
  Author: Joe Houghes
  Modified Date: 4-21-20
.EXAMPLE
  Get-VeeamSessionReport | Format-Table
.EXAMPLE
  Get-VeeamSessionReport -VBRServer ausveeambr | Export-Csv D:\Temp\VeeamSessionReport.csv -NoTypeInformation
.EXAMPLE
  Get-VeeamSessionReport -VBRServer ausveeambr -RemoveDuplicates | Export-Csv D:\Temp\VeeamSessionReport_NoDupes.csv -NoTypeInformation

#>

function Get-VeeamSessionReport {
  [CmdletBinding()]
  param (
    [string]$VBRServer = 'localhost',
    [string[]]$JobName,
    [ValidateSet("Backup", "BackupCopy", "VBRServerInstall", "VBRConsoleInstall", "VBRExplorersInstall", "VEMPrereqCheck", "VEMPrereqInstall", "VEMServerInstall", "VCCPortal", "All")]
    [string]$JobType,
    [switch]$RemoveDuplicates
  )
  begin {

    #Load the Veeam PSSnapin
    if (!(Get-PSSnapin -Name VeeamPSSnapIn -ErrorAction SilentlyContinue)) {
      Add-PSSnapin -Name VeeamPSSnapIn
      Connect-VBRServer -Server $VBRServer
    }

    Disconnect-VBRServer
    Connect-VBRServer -Server $VBRServer

  } #end Begin block

  process {

    $AllJobs = Get-VBRJob -WarningAction SilentlyContinue

    $VMwareBackupJobIDs = $AllJobs | Where-Object { ($_.JobType -eq 'Backup') -AND ($_.BackupPlatform.Platform -eq 'EVmware') } | Select-Object -ExpandProperty ID

    $AllBackupSessions = [Veeam.Backup.Core.CBackupSession]::GetAll()
    $SelectBackupSessions = $AllBackupSessions | Where-Object { $_.JobId -in $VMwareBackupJobIDs }

    $SelectTaskSessions = $SelectBackupSessions.GetTaskSessions()

    $SelectTaskSessions = $SelectTaskSessions | Select-Object -First 50

    [System.Collections.ArrayList]$AllTasksOutput = @()

    foreach ($TaskSession in $SelectTaskSessions) {

      $LogRegex = [regex]'\bUsing \b.+\s(\[[^\]]*\])'
      $BottleneckRegex = [regex]'^Busy: (\S+ \d+% > \S+ \d+% > \S+ \d+% > \S+ \d+%)'
      $PrimaryBottleneckRegex = [regex]'^Primary bottleneck: (\S+)'

      $ProcessingLogMatches = $TaskSession.Logger.GetLog().UpdatedRecords | Where-Object Title -match $LogRegex
      $ProcessingLogMatchTitles = $(($ProcessingLogMatches.Title -replace '\bUsing \b.+\s\[', '') -replace ']', '')
      $ProcessingMode = $($ProcessingLogMatchTitles | Select-Object -Unique) -join ';'

      $BottleneckLogMatch = $TaskSession.Logger.GetLog().UpdatedRecords | Where-Object Title -match $BottleneckRegex
      $BottleneckDetails = $BottleneckLogMatch.Title -replace 'Busy: ', ''

      $PrimaryBottleneckLogMatch = $TaskSession.Logger.GetLog().UpdatedRecords | Where-Object Title -match $PrimaryBottleneckRegex
      $PrimaryBottleneckDetails = $PrimaryBottleneckLogMatch.Title -replace 'Primary bottleneck: '

      try {
        $JobSessionDuration = $TaskSession.JobSess.SessionInfo.Progress.Duration.ToString()
      }
      catch {
        $JobSessionDuration = ''
      }

      try {
        $TaskSessionDuration = $TaskSession.WorkDetails.WorkDuration.ToString()
      }
      catch {
        $TaskSessionDuration = ''
      }

      $TaskOutputResult = [pscustomobject][ordered] @{

        'JobName'           = $TaskSession.JobName
        'VMName'            = $TaskSession.Name
        'Status'            = $TaskSession.Status
        'IsRetry'           = $TaskSession.JobSess.IsRetryMode
        'ProcessingMode'    = $ProcessingMode
        'JobDuration'       = $($JobSessionDuration)
        'TaskDuration'      = $($TaskSessionDuration)
        'TaskAlgorithm'     = $TaskSession.WorkDetails.TaskAlgorithm
        'CreationTime'      = $TaskSession.JobSess.CreationTime
        'BackupSize(GB)'    = [math]::Round(($TaskSession.JobSess.BackupStats.BackupSize / 1GB), 4)
        'DataSize(GB)'      = [math]::Round(($TaskSession.JobSess.BackupStats.DataSize / 1GB), 4)
        'DedupRatio'        = $TaskSession.JobSess.BackupStats.DedupRatio
        'CompressRatio'     = $TaskSession.JobSess.BackupStats.CompressRatio
        'BottleneckDetails' = $BottleneckDetails
        'PrimaryBottleneck' = $PrimaryBottleneckDetails

      } #end TaskOutputResult object

      if ($TaskOutputResult) {
        $null = $AllTasksOutput.Add($TaskOutputResult)
        Remove-Variable TaskOutputResult -ErrorAction SilentlyContinue
      }#end if

    } #end foreach TaskSession

  } #end Process block

  end {

    if ($RemoveDuplicates) {

      $UniqueTaskOutput = $AllTasksOutput | Select-Object JobName, VMName, Status, IsRetry, ProcessingMode, WorkDuration, TaskAlgorithm, CreationTime, BackupSize, DataSize, DedupRatio, CompressRatio -Unique
      Write-Output $UniqueTaskOutput

    }

    else {
      Write-Output $AllTasksOutput
    }

  } #end End block

} #enf function



