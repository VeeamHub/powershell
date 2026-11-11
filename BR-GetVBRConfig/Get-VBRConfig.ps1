#Requires -Version 4
#Requires -RunAsAdministrator
<#
.Synopsis
    Simple Veeam report to dump server & job configurations
.Notes
    Version: 0.2
    Author: Joe Houghes
    Modified Date: 4-24-2020
.EXAMPLE
    Get-VBRConfig -VBRServer ausveeambr -ReportPath C:\Temp\VBROutput
#>

function Get-VBRConfig {
  param(
    # VBRServer
    [Parameter(Mandatory)]
    [string]$VBRServer,
    [Parameter(Mandatory)]
    [string]$ReportPath
  )

  begin {

    #Load the Veeam PSSnapin
    if (!(Get-PSSnapin -Name VeeamPSSnapIn -ErrorAction SilentlyContinue)) {
      Add-PSSnapin -Name VeeamPSSnapIn
      Connect-VBRServer -Server $VBRServer
    }

    else {
      Disconnect-VBRServer
      Connect-VBRServer -Server $VBRServer
    }

    if (!(Test-Path $ReportPath)) {
      New-Item -Path $ReportPath -ItemType Directory | Out-Null
    }

    Push-Location -Path $ReportPath
    Write-Verbose ("Changing directory to '$ReportPath'")

  }

  process {

    $Servers = Get-VBRServer
    $Jobs = Get-VBRJob -WarningAction SilentlyContinue | Where-Object { $_.JobType -eq 'Backup' -OR $_.JobType -eq 'BackupSync' }
    $Proxies = Get-VBRViProxy
    $Repositories = Get-VBRBackupRepository
    $SOBRs = Get-VBRBackupRepository -ScaleOut

    [System.Collections.ArrayList]$RepositoryDetails = @()

    foreach ($Repo in $Repositories) {
      $RepoOutput = [pscustomobject][ordered] @{
        'ID'   = $Repo.ID
        'Name' = $Repo.Name
      }
      $null = $RepositoryDetails.Add($RepoOutput)
      Remove-Variable RepoOutput
    }

    foreach ($Repo in $SOBRs) {
      $RepoOutput = [pscustomobject][ordered] @{
        'ID'   = $Repo.ID
        'Name' = $Repo.Name
      }
      $null = $RepositoryDetails.Add($RepoOutput)
      Remove-Variable RepoOutput
    }

    [System.Collections.ArrayList]$AllJobs = @()

    foreach ($Job in $Jobs) {
      $JobDetails = $Job | Select-Object -Property 'Name', 'JobType', 'SheduleEnabledTime', 'ScheduleOptions', @{n = 'RestorePoints'; e = { $Job.Options.BackupStorageOptions.RetainCycles } }, @{n = 'RepoName'; e = { $RepositoryDetails | Where-Object { $_.Id -eq $job.Info.TargetRepositoryId.Guid } | Select-Object -ExpandProperty Name } }, @{n = 'Algorithm'; e = { $Job.Options.BackupTargetOptions.Algorithm } }, @{n = 'FullBackupScheduleKind'; e = { $Job.Options.BackupTargetOptions.FullBackupScheduleKind } }, @{n = 'FullBackupDays'; e = { $Job.Options.BackupTargetOptions.FullBackupDays } }, @{n = 'TransformFullToSyntethic'; e = { $Job.Options.BackupTargetOptions.TransformFullToSyntethic } }, @{n = 'TransformIncrementsToSyntethic'; e = { $Job.Options.BackupTargetOptions.TransformIncrementsToSyntethic } }, @{n = 'TransformToSyntethicDays'; e = { $Job.Options.BackupTargetOptions.TransformToSyntethicDays } }
      $AllJobs.Add($JobDetails) | Out-Null
    }

    [System.Collections.ArrayList]$AllSOBRExtents = @()

    foreach ($SOBR in $SOBRs) {
      $Extents = Get-VBRRepositoryExtent -Repository $SOBR

      foreach ($Extent in $Extents) {
        $ExtentDetails = $Extent.Repository | Select-Object *, @{n = 'SOBR_Name'; e = { $SOBR.Name } }
        $AllSOBRExtents.Add($ExtentDetails) | Out-Null
      }
    }

  }

  end {

    $Servers | Export-Csv -Path $("$ReportPath\$VBRServer" + '_Servers.csv') -NoTypeInformation
    $AllJobs | Export-Csv -Path $("$ReportPath\$VBRServer" + '_Jobs.csv') -NoTypeInformation
    $Proxies | Export-Csv -Path $("$ReportPath\$VBRServer" + '_Proxies.csv') -NoTypeInformation
    $Repositories | Export-Csv -Path $("$ReportPath\$VBRServer" + '_Repositories.csv') -NoTypeInformation
    $SOBRs | Export-Csv -Path $("$ReportPath\$VBRServer" + '_SOBRs.csv') -NoTypeInformation
    $AllSOBRExtents | Export-Csv -Path $("$ReportPath\$VBRServer" + '_SOBRExtents.csv') -NoTypeInformation

    Disconnect-VBRServer
    Pop-Location
  }
}
