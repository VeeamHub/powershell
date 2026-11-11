#Requires -Version 4
#Requires -RunAsAdministrator
<#
.Synopsis
  Simple Veeam report to give details of AHV VMs protected by backup or snapshot
.Notes
  Version: 1.0
  Author: Joe Houghes
  Modified Date: 9-24-20
.EXAMPLE
  Get-VeeamAHVProtectedVMsReport
.EXAMPLE
  Get-VeeamAHVProtectedVMsReport -VBRServer ausveeambr | Format-Table -Autosize
.EXAMPLE
  Get-VeeamAHVProtectedVMsReport -VBRServer ausveeambr | Export-Csv C:\Temp\VeeamBackupSessionReport.csv -NoTypeInformation

#>

function Get-VeeamAHVProtectedVMsReport {
    [CmdletBinding()]
    param (
      [Parameter(Position = 0)]
      [string]$VBRServer = 'localhost'
    )
  
    begin {
    
      #Load the Veeam PSSnapin
      if (!(Get-PSSnapin -Name VeeamPSSnapIn -ErrorAction SilentlyContinue)) {
        Add-PSSnapin -Name VeeamPSSnapIn
        Disconnect-VBRServer
        Connect-VBRServer -Server $VBRServer
      }
  
      $AllJobs = [Veeam.Backup.Core.CBackupJob]::GetAll()
      #$Nutanix_VM_Jobs = $AllJobs | Where-Object { $_.TypeToString -like "Nutanix*" -AND $_.JobType -ne "VmbApiPolicyTempJob" }
      $Nutanix_Policy_Jobs = $AllJobs | Where-Object { $_.TypeToString -like "Nutanix*" -AND $_.JobType -eq "VmbApiPolicyTempJob" }
      $Nutanix_VM_Jobs = $Nutanix_Policy_Jobs | Where-Object { $_.FindChildJobs().JobType -eq 'EndpointBackup' }

      $Nutanix_Meta_Jobs = $Nutanix_Policy_Jobs | Where-Object { !($_.FindChildJobs()) }
      $Nutanix_Snapshot_Jobs = $Nutanix_Meta_Jobs | Where-Object { $_.GetViOijs().TypeDisplayName -eq 'Virtual Machine' }
      $Nutanix_PD_Jobs = $Nutanix_Meta_Jobs | Where-Object { $null -eq $_.GetViOijs().TypeDisplayName }
  
    }
      
    process {
  
      #region Snapshot jobs
      $AllSnapshotJobResults = foreach ($EachSnapshotJob in $Nutanix_Snapshot_Jobs) {
              
        $SnapshotJobSessions = [Veeam.Backup.Core.CBackupSession]::GetByJob($EachSnapshotJob.Id)
  
        $ClusterName = ($EachSnapshotJob.GetSourceHosts()).Name
              
        $SnapJobResult = if ([bool]$SnapshotJobSessions) {
          
          $SnapshotProtectedVMs = $EachSnapshotJob.GetViOijs()
          $MostRecentSnapshot = $SnapshotJobSessions | Where-Object { $_.Result -eq 'Success' } | Sort-Object EndTime -Descending | Select-Object -First 1
          $SnapshotTime = $MostRecentSnapshot.CreationTime.ToString()
                
          $SnapshotVMResult = foreach ($EachVM in $SnapshotProtectedVMs) {
                
            [pscustomobject][ordered] @{
            
              'VM Name'                   = $EachVM.Name
              'Cluster Name'              = $ClusterName
              'Protection Domain'         = $null
              'Job Name'                  = $EachSnapshotJob.Name
              'Backup Target'             = $null
              'Available Restore Points'  = $null
              'Last Backup/Snapshot Date' = $SnapshotTime
            
            } #end EachVM PSCustomObject
  
          } #end foreach VM
          
          $SnapshotVMResult
  
          Remove-Variable EachVM, SnapshotVMResult -ErrorAction SilentlyContinue
  
        } #end if JobSession
          
        $SnapJobResult
  
        Remove-Variable MostRecentSnapshot, SnapshotTime, SnapshotProtectedVMs, SnapJobResult -ErrorAction SilentlyContinue
              
      }
  
      Remove-Variable ClusterName -ErrorAction SilentlyContinue
      #endregion Snapshot jobs
  
      #region PD jobs
      $AllPDJobResults = foreach ($EachPDJob in $Nutanix_PD_Jobs) {
              
        $PDJobSessions = [Veeam.Backup.Core.CBackupSession]::GetByJob($EachPDJob.Id)
  
        $ClusterName = ($EachPDJob.GetSourceHosts()).Name
            
        $PDJobResult = if ([bool]$PDJobSessions) {
        
          $VMName = $(($EachPDJob.Name -replace '^AHV Backup Proxy ') -replace ' Protection$')
          $SnapshotProtectedDomain = $EachPDJob.GetViOijs().Name
          $MostRecentSnapshot = $PDJobSessions | Where-Object { $_.Result -eq 'Success' } | Sort-Object EndTime -Descending | Select-Object -First 1
          $SnapshotTime = $MostRecentSnapshot.CreationTime.ToString()
              
          $SnapshotPDResult = [pscustomobject][ordered] @{
          
            'VM Name'                   = $VMName
            'Cluster Name'              = $ClusterName
            'Protection Domain'         = $SnapshotProtectedDomain
            'Job Name'                  = $null
            'Backup Target'             = $null
            'Available Restore Points'  = $null
            'Last Backup/Snapshot Date' = $SnapshotTime
          
          } #end EachVM PSCustomObject
  
          $SnapshotPDResult
  
          Remove-Variable SnapshotPDResult -ErrorAction SilentlyContinue
  
        } #end if JobSession
        
        $PDJobResult
  
        Remove-Variable MostRecentSnapshot, SnapshotProtectedDomain, PDJobResult -ErrorAction SilentlyContinue
            
      }
  
      Remove-Variable ClusterName -ErrorAction SilentlyContinue
  
      #endregion PD jobs
  
      #region VM jobs
      $Nutanix_VM_Endpoint_Jobs = $Nutanix_VM_Jobs.FindChildJobs()
      
      $AllVMJobResults = foreach ($EachVMJob in $Nutanix_VM_Endpoint_Jobs) {
                
        $VMJobSessions = [Veeam.Backup.Core.CBackupSession]::GetByJob($EachVMJob.Id)
  
        $ClusterName = ($EachVMJob.GetSourceHosts()).Name
          
        $BackupJobResult = if ([bool]$VMJobSessions) {
      
          $VMBackup = [Veeam.Backup.Core.CBackup]::GetAllByJob($EachVMJob.Id)
          $VMRestorePoints = Get-VBRRestorePoint -Backup $VMBackup | Group-Object -Property Name
  
          $BackupTarget = ($EachVMJob.FindParentJob()).FindTargetRepository().Name
          
          $BackupVMResult = foreach ($EachGroup in $VMRestorePoints) {
            $MostRecentBackup = $EachGroup.Group | Sort-Object EndTime -Descending | Select-Object -First 1
            $BackupTime = $MostRecentBackup.CreationTime.ToString()
    
            [pscustomobject][ordered] @{
        
              'VM Name'                   = $EachGroup.Name
              'Cluster Name'              = $ClusterName
              'Protection Domain'         = $null
              'Job Name'                  = $EachVMJob.Name
              'Backup Target'             = $BackupTarget
              'Available Restore Points'  = $VMRestorePoints.Count
              'Last Backup/Snapshot Date' = $BackupTime
        
            } #end BackupVM PSCustomObject
  
          } #end BackupJobResult
      
          $BackupVMResult
  
          Remove-Variable EachGroup, BackupTime, MostRecentBackup, BackupVMResult -ErrorAction SilentlyContinue
  
        } #end if JobSession
      
        $BackupJobResult
  
        Remove-Variable VMRestorePoints, VMBackup, BackupJobResult -ErrorAction SilentlyContinue
            
      }
      
      #endregion VM jobs
  
      <#
      [System.Collections.ArrayList]$AllJobResults = @()
  
      $null = $AllJobResults.Add($AllSnapshotJobResults)
      $null = $AllJobResults.Add($AllPDJobResults)
      $null = $AllJobResults.Add($AllVMJobResults)
      #>

      $AllJobResults = @()
      $AllJobResults += $AllSnapshotJobResults
      $AllJobResults += $AllPDJobResults
      $AllJobResults += $AllVMJobResults
  
    }
      
    end {
  
      #Write results object out to pipeline
      $AllJobResults
  
    }
  
  }
  