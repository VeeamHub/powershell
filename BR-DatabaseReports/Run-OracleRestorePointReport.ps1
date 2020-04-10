<#
.Synopsis
  This cmdlet will return an object with details based on Oracle restore points.  It is suggested to export results to CSV file.
.DESCRIPTION
  This cmdlet utilizes the Veeam Explorer for Oracle to launch restore sessions and gather details of the restore points, databases, and database files which match the specified parameters.
  This cmdlet will require the Veeam PSSnapin and the Veeam Explorer for Oracle module to exist on the system, and will require the appropriate access to Veeam B&R.
.EXAMPLE
  Run-OracleRestorePointReport -VBRServer 'ausveeambr' -VMName 'atloraclelnxvm1'
.EXAMPLE
  Run-OracleRestorePointReport -VBRServer 'ausveeambr' -VMName 'atloraclelnxvm1', 'atloraclelnxvm2', 'atloraclelnxvm3' | Export-Csv 'D:\Temp\OracleMultiJobNameReport.csv' -NoTypeInformation
.EXAMPLE
  Run-OracleRestorePointReport -VBRServer 'ausveeambr' -VMName 'atloraclelnxvm1', 'atloraclelnxvm2', 'atloraclelnxvm3' -FilterHours 24 | Export-Csv 'D:\Temp\OracleMultiJobNameFilterHoursReport.csv' -NoTypeInformation
.INPUTS
  None. You cannot pipe objects to Run-OracleRestorePointReport.
.OUTPUTS
  PSCustomObject
.FUNCTIONALITY
  This cmdlet utilizes the Veeam Explorer for Oracle to find application restore points for Oracle.
  For each restore point meeting the criteria for VM name(s) within the specified 'Filter Hours' period, it will launch a restore session for each restore point.
  Details of the restore points, databases, and database files will be gathered, and the arraylist of the results will be output.
#>

function Run-OracleRestorePointReport {
  [CmdletBinding()]
  param (

    [string]$VBRServer = 'localhost',
    [string[]]$VMName,
    [int]$FilterHours

  )

  begin {

    Add-PSSnapin -Name VeeamPSSnapIn
    Import-Module Veeam.Oracle.PowerShell
    Disconnect-VBRServer
    Connect-VBRServer -Server $VBRServer

  } #end begin block

  process {

    if ($VMName -AND $FilterHours) {
      $OracleRPs = Get-VBRApplicationRestorePoint -Name $VMName -Oracle | Where-Object { $_.CreationTime -ge ((Get-Date).AddHours(-$FilterHours)) }
    }
    elseif ($VMName) {
      $OracleRPs = Get-VBRApplicationRestorePoint -Name $VMName -Oracle
    }
    elseif ($FilterHours) {
      $OracleRPs = Get-VBRApplicationRestorePoint -Oracle | Where-Object { $_.CreationTime -ge ((Get-Date).AddHours(-$FilterHours)) }
    }
    else {
      $OracleRPs = Get-VBRApplicationRestorePoint -Oracle
    }

    $OracleDetails = [System.Collections.ArrayList]@()

    foreach ($RestorePoint in $OracleRPs) {

      $OracleSession = Start-VEORRestoreSession -RestorePoint $RestorePoint
      $OracleDBs = Get-VEORDatabase -Session $OracleSession

      foreach ($Database in $OracleDBs) {

        $RestoreInterval = Get-VEORDatabaseRestoreInterval -Database $Database
        $DatabaseFiles = Get-VEORDatabaseFile -Database $Database

        foreach ($File in $DatabaseFiles) {

          $RestorePointOracleDetail = [PSCustomObject][ordered]@{

            'VMName'                   = $RestorePoint.Name
            'RestorePointCreationTime' = $RestorePoint.CreationTime
            'BackupType'               = $RestorePoint.Type
            'BackupCorrupted'          = $RestorePoint.IsCorrupted
            'RestorePointId'           = $RestorePoint.Id
            'DatabaseGlobalName'       = $Database.GlobalName
            'DatabaseHome'             = $Database.Home
            'RestoreIntervalStart'     = $RestoreInterval.From
            'RestoreIntervalEnd'       = $RestoreInterval.To
            'DatabaseFilePath'         = $File.Path
            'DatabaseFileType'         = $File.Type

          } #endPSCustomObject

          $null = $OracleDetails.Add($RestorePointOracleDetail)

        } #end foreach File

      } #end foreach Database

      Stop-VEORRestoreSession -Session $OracleSession

    } #end foreach RestorePoint

  } #end process block

  end {

    Write-Output $OracleDetails

  } #end end block

}
