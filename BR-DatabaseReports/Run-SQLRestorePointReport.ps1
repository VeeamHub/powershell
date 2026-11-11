<#
.Synopsis
  This cmdlet will return an object with details based on SQL restore points.  It is suggested to export results to CSV file.
.DESCRIPTION
  This cmdlet utilizes the Veeam Explorer for SQL to launch restore sessions and gather details of the restore points, databases, and database files which match the specified parameters.
  This cmdlet will require the Veeam PSSnapin and the Veeam Explorer for SQL module to exist on the system, and will require the appropriate access to Veeam B&R.
.EXAMPLE
  Run-SQLRestorePointReport -VBRServer 'ausveeambr' -VMName 'aussql2k14'
.EXAMPLE
  Run-SQLRestorePointReport -VBRServer 'ausveeambr' -VMName 'aussql2k14', 'ausveeamone', 'ausveeambr' | Export-Csv 'D:\Temp\SQLMultiJobNameReport.csv' -NoTypeInformation
.EXAMPLE
  Run-SQLRestorePointReport -VBRServer 'ausveeambr' -VMName 'aussql2k14', 'ausveeamone', 'ausveeambr' -FilterHours 24 | Export-Csv 'D:\Temp\SQLMultiJobNameFilterHoursReport.csv' -NoTypeInformation
.INPUTS
  None. You cannot pipe objects to Run-SQLRestorePointReport.
.OUTPUTS
  PSCustomObject
.FUNCTIONALITY
  This cmdlet utilizes the Veeam Explorer for SQL to find application restore points for SQL.
  For each restore point meeting the criteria for VM name(s) within the specified 'Filter Hours' period, it will launch a restore session for each restore point.
  Details of the restore points, databases, and database files will be gathered, and the arraylist of the results will be output.
#>

function Run-SQLRestorePointReport {
  [CmdletBinding()]
  param (

    [string]$VBRServer = 'localhost',
    [string[]]$VMName,
    [int]$FilterHours

  )

  begin {

    Add-PSSnapin -Name VeeamPSSnapIn
    Import-Module Veeam.SQL.PowerShell
    Disconnect-VBRServer
    Connect-VBRServer -Server $VBRServer

  } #end begin block

  process {

    if ($VMName -AND $FilterHours) {
      $SQLRPs = Get-VBRApplicationRestorePoint -Name $VMName -SQL | Where-Object { $_.CreationTime -ge ((Get-Date).AddHours(-$FilterHours)) }
    }
    elseif ($VMName) {
      $SQLRPs = Get-VBRApplicationRestorePoint -Name $VMName -SQL
    }
    elseif ($FilterHours) {
      $SQLRPs = Get-VBRApplicationRestorePoint -SQL | Where-Object { $_.CreationTime -ge ((Get-Date).AddHours(-$FilterHours)) }
    }
    else {
      $SQLRPs = Get-VBRApplicationRestorePoint -SQL
    }

    $SQLDetails = [System.Collections.ArrayList]@()

    foreach ($RestorePoint in $SQLRPs) {

      $SQLSession = Start-VESQLRestoreSession -RestorePoint $RestorePoint
      $SQLDBs = Get-VESQLDatabase -Session $SQLSession

      foreach ($Database in $SQLDBs) {

        try {
          $RestoreInterval = Get-VESQLDatabaseRestoreInterval -Database $Database
        }
        catch {

          $Properties = @{
            FromUtc = 'No Restore Interval'
            ToUtc   = 'No Restore Interval'
          }

          $RestoreInterval = New-Object psobject -Property $Properties

        }

        $DatabaseFiles = Get-VESQLDatabaseFile -Database $Database

        foreach ($File in $DatabaseFiles) {

          $RestorePointSQLDetail = [PSCustomObject][ordered]@{

            'VMName'                   = $RestorePoint.Name
            'RestorePointCreationTime' = $RestorePoint.CreationTime
            'BackupType'               = $RestorePoint.Type
            'BackupCorrupted'          = $RestorePoint.IsCorrupted
            'RestorePointId'           = $RestorePoint.Id
            'DatabaseName'             = $Database.Name
            'DatabaseServerName'       = $Database.ServerName
            'DatabaseInstanceName'     = $Database.InstanceName
            'SystemDB'                 = $Database.IsSystem
            'ReadOnly'                 = $Database.IsReadonly
            'BackedUp'                 = $Database.IsBackedUp
            'Heuristic'                = $Database.IsHeuristic
            'AvailabilityGroupName'    = $Database.AvailabilityGroupName
            'RecoveryModel'            = $Database.RecoveryModel
            'DatabaseID'               = $Database.Id
            'RestoreIntervalStart'     = $RestoreInterval.FromUtc
            'RestoreIntervalEnd'       = $RestoreInterval.ToUtc
            'DatabaseFilePath'         = $File.Path
            'DatabaseFileType'         = $File.Type

          } #endPSCustomObject

          $null = $SQLDetails.Add($RestorePointSQLDetail)

          Remove-Variable File -ErrorAction SilentlyContinue

        } #end foreach File

        Remove-Variable RestoreInterval -ErrorAction SilentlyContinue

      } #end foreach Database

      Stop-VESQLRestoreSession -Session $SQLSession

    } #end foreach RestorePoint

  } #end process block

  end {

    Write-Output $SQLDetails

  } #end end block

}
