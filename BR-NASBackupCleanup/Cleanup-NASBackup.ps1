<#
.SYNOPSIS
   Getting Shares behind Reparse Points and add them to a NAS Backup Job
   .DESCRIPTION
   This script finds the shares behind an DFS namespace structure and adds it to VBR NAS Backup Job. You can configure
   the folder scan depth 
   .PARAMETER DfsRoot
   With this parameter you specify the UNC path to scan e.g. "\\fileserver\dfs".
   .PARAMETER VBRJobName
   This is the existing Job where the detected shares should be added.
   .PARAMETER ShareCredential
   Enter the Credentials which should be used. They must be from VBR credentials manager.
   .PARAMETER CacheRepository
   Enter the Repository which should be used for Cache.
   .PARAMETER ExcludeSystems
   Enter list of excluded servername strings like "*server1*","*server2*,"*server3" to exclude reparse points which are
   pointing to this UNC paths.
   .PARAMETER ScanDepth
   How deep in the subfolder structure the script should scan for reparse points?
   .PARAMETER LogFile
   You can set your own path for log file from this script. Default filename is "C:\ProgramData\dfsresolver4nasbackup.log"

   .Example
   .\Add-DFSTargetToNASBackupJob.ps1 -DfsRoot "\\homelab\dfs" -VBRJobName "NAS DFS Test" -ShareCredential "HOMELAB\Administrator" -CacheRepository "Default Backup Repository" -ScanDepth 2

   .Example
   .\Add-DFSTargetToNASBackupJob.ps1 -DfsRoot "\\homelab\dfs" -VBRJobName "NAS DFS Test" -ShareCredential "HOMELAB\Administrator" -CacheRepository "Default Backup Repository" -ScanDepth 2 -VolumeProcessingMode VSSSnapshot

   .Example
   .\Add-DFSTargetToNASBackupJob.ps1 -DfsRoot "\\homelab\dfs" -VBRJobName "NAS DFS Test" -ShareCredential "HOMELAB\Administrator" -CacheRepository "Default Backup Repository" -ScanDepth 2 -VolumeProcessingMode VSSSnapshot -ExcludeSystems "*lab-dc01*","*lab-nacifs01*" 

   .Notes 
   Version:        1.7
   Author:         Marco Horstmann (marco.horstmann@veeam.com)
   Creation Date:  09 April 2020
   Purpose/Change: Bugfix: Error Handling if Job doesn't exists
   
   .LINK https://github.com/veeamhub/powershell
   .LINK https://github.com/marcohorstmann/powershell
   .LINK https://horstmann.in
 #>

 [CmdletBinding(DefaultParameterSetName="__AllParameterSets")]
Param(

<#
   [Parameter(Mandatory=$True)]
   [string]$DfsRoot,

   [ValidateSet(“Direct”,”StorageSnapshot”,”VSSSnapshot”)]
   [Parameter(Mandatory=$False)]
   [string]$VolumeProcessingMode="Direct",

   [Parameter(Mandatory=$True)]
   [string]$VBRJobName,

   [Parameter(Mandatory=$True)]
   [string]$ShareCredential,

   [Parameter(Mandatory=$True)]
   [string]$CacheRepository,

   [Parameter(Mandatory=$False)]
   [string[]]$ExcludeSystems,
#>
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