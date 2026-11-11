#Requires -Version 4
#Requires -RunAsAdministrator
<#
.Synopsis
   Simple Veeam report to expand on information from 'Veeam Backup Billing' report in VeeamOne
.Notes
    Version: 0.2
    Author: Joe Houghes
    Modified Date: 3-1-2019
.EXAMPLE
   Get-VMandDiskFilterDetails | Format-Table
.EXAMPLE
   Get-VMandDiskFilterDetails | Export-Csv VM_DiskFilterDetails.csv -NoTypeInformation
#>


#Load the Veeam PSSnapin
if (!(Get-PSSnapin -Name VeeamPSSnapIn -ErrorAction SilentlyContinue)) {
    Add-PsSnapin -Name VeeamPSSnapIn
    Connect-VBRServer
  }
  
  function Get-VMandDiskFilterDetails{
    $reportJobOutput = @()
  
    $reportJobs = Get-VBRJob | Where-Object {$PSItem.JobType -eq 'Backup' -OR $PSItem.JobType -eq 'BackupSync' -AND $PSItem.BackupPlatform.Platform -eq 'EVmware'}
    $repositories = Get-VBRBackupRepository | Select-Object Name,Id
  
    foreach ($reportJob in $reportJobs) {
  
      $currentBackup = Get-VBRBackup -Name $reportJob.Name
      $currentRepo = $repositories | Where-Object -Property Id -eq -Value $currentBackup.RepositoryId
      $currentJobVMs = $reportJob.GetViOijs()
  
        foreach ($currentVM in $currentJobVMs) {
            $Mode = $currentVM.DiskFilterInfo.Mode

            if (!($Mode -eq 'AllDisks')){
                $Disks = ($currentVM.DiskFilter.Disks | Select-Object -ExpandProperty DisplayName) -join ';'
            }
            else {
                $Disks = 'All'
            }

          $reportJobOutputObject = New-Object -TypeName PSCustomObject -Property @{
            'BackupJob' = $reportJob.Name
            'VMName' =  $currentVM.Name
            'Location' = $currentRepo.Name
            'DiskMode' = $Mode
            'SpecificDisks' = $Disks
          }
  
          $reportJobOutput += $reportJobOutputObject
        }
      }
      
      Write-Output $reportJobOutput | Select-Object 'BackupJob','VMName','Location','DiskMode','SpecificDisks'
      
  }  
  