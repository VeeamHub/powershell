<#
.SYNOPSIS
   Find shares in VBR, which are not used by any backup job and remove them
   .DESCRIPTION
   This script finds the shares, which are not used by any NAS backup job. All shares will automatically removed from VBR configuration. 
   .PARAMETER LogFile
   You can set your own path for log file from this script. Default filename is "C:\ProgramData\nasBackupCleanup.log"

   .Example
   .\Add-DFSTargetToNASBackupJob.ps1

   .Notes 
   Version:        1.0
   Author:         Marco Horstmann (marco.horstmann@veeam.com)
   Creation Date:  09 April 2020
   Purpose/Change: New script
   
   .LINK https://github.com/veeamhub/powershell
   .LINK https://github.com/marcohorstmann/powershell
   .LINK https://horstmann.in
 #>

 [CmdletBinding(DefaultParameterSetName="__AllParameterSets")]
Param(

   [Parameter(Mandatory=$False)]
   [switch]$Automatic=$false,

   [Parameter(Mandatory=$False)]
   [string]$LogFile="C:\ProgramData\nasBackupCleanup.log"

)
PROCESS {

    # This function is used to log status to console and also the given logfilename.
    # Usage: Write-Log -Status [Info, Status, Warning, Error] -Info "This is the text which will be logged
    function Write-Log($Info, $Status)
    {
        switch($Status)
        {
            NewLog {Write-Host $Info -ForegroundColor Green  ; $Info | Out-File -FilePath $LogFile}
            Info    {Write-Host $Info -ForegroundColor Green  ; $Info | Out-File -FilePath $LogFile -Append}
            Status  {Write-Host $Info -ForegroundColor Yellow ; $Info | Out-File -FilePath $LogFile -Append}
            Warning {Write-Host $Info -ForegroundColor Yellow ; $Info | Out-File -FilePath $LogFile -Append}
            Error   {Write-Host $Info -ForegroundColor Red -BackgroundColor White; $Info | Out-File -FilePath $LogFile -Append}
            default {Write-Host $Info -ForegroundColor white $Info | Out-File -FilePath $LogFile -Append}
        }
    } #end function 

    # Get all in VBR existing shares
    $allNasShares = Get-VBRNASServer

    # Get all VBR NAS Backup Jobs to get used shares in backup jobs
    $nasBackupJobs = get-vbrnasbackupjob

    # Get from all jobs the added BackupJobObjects
    $VBRNASBackupJobObjectsInExistingJobs = @()
    ForEach ($nasBackJob in $nasBackupJobs) {
        $VBRNASBackupJobObjectsInExistingJobs += $nasBackJob.BackupObject
    }

    #Check for every share of it used in a job    
    ForEach ($NasShare in $allNasShares) {
        if (!($NasShare.Path -in $VBRNASBackupJobObjectsInExistingJobs.Path)) {
            try {
                Write-Log -Info "Share $($NasShare.Path) is not used by a NAS Backup Job..." -Status Info
                Remove-VBRNASServer -Server $NasShare -Confirm:$false
                Write-Log -Info "REMOVE share $($NasShare.Path) from VBR... DONE" -Status Info
            } catch {
                        Write-Log -Info "$_" -Status Error
                        Write-Log -Info "Remove share $($NasShare.Path) from VBR... FAILED" -Status Error
            }
        } else {
            Write-Log -Info "Share $($NasShare.Path) is used by a NAS Backup Job... SKIPPING" -Status Info
        }
    }
    
       
} # END PROCESS