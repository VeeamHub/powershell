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


   .Example
   .\Involve-NASInstantDFSRecovery.ps1 -DfsRoot "\\homelab\dfs" -ScanDepth 3 -VBRJobName "DFS NAS Test" -Owner "HOMELAB\Administrator"


   .Notes 
   Version:        1.8
   Author:         Marco Horstmann (marco.horstmann@veeam.com)
   Creation Date:  16 April 2020
   Purpose/Change: Bugfix: Disallow ProcessingMode StorageSnapshot because it will not work.
   
   .LINK https://github.com/veeamhub/powershell
   .LINK https://github.com/marcohorstmann/powershell
   .LINK https://horstmann.in
 #> 
[CmdletBinding(DefaultParameterSetName="__AllParameterSets")]
Param(

   [Parameter(Mandatory=$True)]
   [string]$DfsRoot,
   
   [Parameter(Mandatory=$True)]
   [string]$VBRJobName,

   [Parameter(Mandatory=$True)]
   [string]$Owner,

   [Parameter(Mandatory=$False)]
   [string]$LogFile="C:\ProgramData\dfsrecovery.log",

   [Parameter(Mandatory=$True)]
   [int]$ScanDepth
)


#PROCESS {

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

    # This function will scan a folder for subfolders and if it finds a reparse point it returns the reparsepoints up.
    function Scan-Folder($path, $currentdepth, $maxdepth) {
        #Increment the currentdepth parameter to end nesting of this fuction within itself.
        $currentdepth++
        #create a folderarray which is used locally for each call of this function (works even in function call in a function call)
        $folderarray = @()
        #Gets all folders of the given path  and for each object it checks its attributes for reparse points. If one folder is also a reparse point it will added to the folderarray
        Get-ChildItem -Path $path -Directory | ForEach-Object {
            if($_.Attributes -like "*ReparsePoint*") {
                $folderarray += $_.FullName
                Write-Log "Found Reparse Point $_ ... ADD TO REPARSE POINT LIST" -Status Info
            }
            # If the currentdepth e.g.2. is less or equal to maxdepth e.g. 3 it will make a nested function call for the current folder
            if($currentdepth -le $maxdepth) {
                # Because a reparse Point below Reparse Point in DFS is not possible. If folder is a reparse point
                # we do not need to dive deeper because we will not found anymore in this folder.
                if(!($_.Attributes -like "*ReparsePoint*")) {
                    $folderarray += Scan-Folder -path $_.FullName -currentdepth $currentdepth -maxdepth $maxdepth
                }
            }
        }
        return $folderarray
    }

    # This function will get an array of reparse points and will locate the target paths and return them
    function Get-SourceShare($reparsepoints) {
        $sharearray = @()
        $reparsepoints | ForEach-Object {
            $sharearray  += Get-DfsnFolderTarget $_
        }
        return $sharearray
    }

    #This function will create a 
    function Switch-DfsTarget {
        param (
        [Parameter(Mandatory=$true)]$Path,
        [Parameter(Mandatory=$true)]$originalPath,
        [Parameter(Mandatory=$true)]$NASRecoverySession
        )
        
        Set-DfsnFolderTarget -Path $Path -TargetPath $originalPath -State Offline
        New-DfsnFolderTarget -Path $Path -TargetPath $NASRecoverySession.SharePath -State Online

        [hashtable]$recoveredShareProperty = @{}
        $recoveredShareProperty.Add('Path',$Path)
        $recoveredShareProperty.Add('originalPath',$originalPath)
        $recoveredShareProperty.Add('recoveryPath',$NASRecoverySession.SharePath)
        #$recoveredShare = New-Object -TypeName psobject -Property $recoveredShareProperty
        return $recoveredShareProperty
    }

<# Not used because done in main code
    function Failback-DfsTarget {
        param (
        [Parameter(Mandatory=$true)]$Path,
        [Parameter(Mandatory=$true)]$originalPath,
        [Parameter(Mandatory=$true)]$recoveryPath
        )
        Set-DfsnFolderTarget -Path $Path -TargetPath $originalPath -State Online
        Remove-DfsnFolderTarget -Path $Path -TargetPath $recoveryPath -Force:$true
    }
#>

    # End of Functions

    # Main Code starts
    #
    Write-Log -Status NewLog -Info "Starting new log file"
  
    # Check if DFS Management Tools are installed
    Write-Log -Status Info -Info "Checking if DFS Management Tools are installed ..."
    if(get-windowsFeature -Name "RSAT-DFS-Mgmt-Con" | Where-Object -Property "InstallState" -EQ "Installed") {
        Write-Log -Status Info -Info "DFS Management Tools are already installed... SKIPPED"
    } else {
        Write-Log -Status Status -Info "DFS Management Tools are not installed... INSTALLING..."
        try {
            Install-WindowsFeature -Name "RSAT-DFS-Mgmt-Con" -Confirm:$false
            Write-Log -Info "DFS Management Tools was installed... DONE" -Status Info
        } catch  {
            Write-Log -Info "$_" -Status Error
            Write-Log -Info "Installing DFS Management Tools... FAILED" -Status Error
            exit 99
        }
    }
    # Check if Veeam Module can be loaded
    Write-Log -Status Info -Info "Trying to load Veeam PS Snapins ..."
    try {
        Add-PSSnapin VeeamPSSnapin
        Write-Log -Info "Veeam PS Snapin loaded" -Status Info
    } catch  {
        Write-Log -Info "$_" -Status Error
        Write-Log -Info "Failed to load Veeam PS Snapin" -Status Error
        exit 99
    }

    # Validate parameters: VBRJobName
    Write-Log -Status Info -Info "Checking VBR Job Name"
    $nasBackupJob = Get-VBRNASBackupJob -name $VBRJobName
    if($nasBackupJob -eq $null) {
        Write-Log -Info "Failed to find job name" -Status Error
        exit 99
    } else { 
        Write-Log -Info "VBR Job Name ... FOUND" -Status Info
    }


    # Scan for Reparse Points
    Write-Log -Status Info -Info "Scanning for Reparse Points"
    try {
        $allreparsepoints = Scan-Folder -path $DfsRoot -currentdepth 1 -maxdepth $ScanDepth
        if( $allreparsepoints.Count -eq 0 ) {
            Write-Log -Info "Reparse Points ... NOT FOUND" -Status Error
            exit 
        } else {
            Write-Log -Info "Reparse Points ... FOUND" -Status Info
        }
    } catch  {
        Write-Log -Info "$_" -Status Error
        Write-Log -Info "Failed to find reparse points" -Status Error
        exit 99
    }

    # Getting all Shares
    Write-Log -Status Info -Info "Resolving Reparse Points to Shares"
    try {
        $allTargetPaths = Get-SourceShare -reparsepoints $allreparsepoints
        Write-Log -Info "Folder Target Paths ... RESOLVED" -Status Info
    } catch  {
        Write-Log -Info "$_" -Status Error
        Write-Log -Info "Failed to find Folder Target Paths" -Status Error
        exit 99
    }

    #show all targetpaths
    #$allTargetPaths
    
    #Get NAS Backup Job for resolving the restore points
    $nasBackup = Get-VBRNASBackup -Name $VBRJobName
    #$nasBackup
    #Get all restore points of this NASBackup to reduce VBR calls
    $nasBackupRestorePoints = Get-VBRNASBackupRestorePoint -NASBackup $nasBackup
    #$nasBackupRestorePoints
    # Get all shares from this object and write it to a new variable sharesInBackup
    $sharesInBackup = $nasBackupRestorePoints | Select-Object -Property NASServerName -Unique

    <#Write-Log -Info "Before show sharesInBackup"
    $sharesInBackup
    Write-log -Info "after show sharesInBackup" #>

    #Array for storing the recovery session
    $NASRecoverySessions = @()

    #Array and Objects for reverting this NAS recovery
    #Create the array we'll add the objects to
    $recoveredNASShares = @()
    #$recoveredNASShares.Add(Get-ComputerInformation -computerName $computer)) | Out-Null

    ForEach($shareInBackup IN $sharesInBackup) {
        #$shareInBackup
        Write-Log -Info "Getting latest restorepoint for share $($shareInBackup.NASServerName.ToString()) ..." -Status Info
        $nasBackupRestorePoints | Where-Object -Property NASServerName -eq $shareInBackup.NASServerName | Select-Object -First 1 -OutVariable latestRestorePoint
        $nasInstantRecoveryPermissionSet = New-VBRNASPermissionSet -RestorePoint $latestRestorePoint -Owner $Owner -AllowEveryone
        #$NASInstantRecoveryMountOptions = New-VBRNASInstantRecoveryMountOptions -MountServerSelectionType Automatic -RestorePoint $latestRestorePoint
        $NASRecoverySessions += Start-VBRNASInstantRecovery -RestorePoint $latestRestorePoint -Permissions $nasInstantRecoveryPermissionSet
        $currentFolderTarget = $allTargetPaths | Where-Object -Property TargetPath -eq $shareInBackup.NASServerName
        #Set-DfsnFolderTarget -Path $currentFolderTarget.Path -TargetPath $currentFolderTarget.TargetPath -State Offline
        #New-DfsnFolderTarget -Path $currentFolderTarget.Path -TargetPath $NASRecoverySessions[$NASRecoverySessions.Count – 1].SharePath -State Online
        $currentPath = $currentFolderTarget.Path
        $currentTargetPath = $currentFolderTarget.TargetPath
        $currentNASRecoverySession = $NASRecoverySessions[$NASRecoverySessions.Count – 1]
        #, is importent that the array will not extended, with "," the array will be added to the array
        #$temporaryNASShare = 
        $recoveredNASShares += (Switch-DfsTarget -Path $currentFolderTarget.Path -originalPath $currentFolderTarget.TargetPath -NASRecoverySession $NASRecoverySessions[$NASRecoverySessions.Count – 1])
        #$recoveredNASShares += Switch-DfsTarget -Path $currentPath -originalPath $currentTargetPath -NASRecoverySession $currentNASRecoverySession
        #Write-Log -Status Info -Info "Loopende"
    }
    #$NASRecoverySessions | FT
    
    $confirmation = Read-Host "Are you Sure You Want To Proceed and Clean up what you did?:"
    if ($confirmation -eq 'y') {
        ForEach($recoveredNASShare IN $recoveredNASShares) {
            #Write-Host "---"
            #$recoveredNASShare
            Write-Log -Info "Das Target ist $($recoveredNASShare.Path)" -Status Info
            #Write-Host "---"
        #    Switch-DfsTarget -Path $recoveredNASShare.Path -originalPath $recoveredNASShare.TargetPath -NASRecoverySession $recoveredNASShare.NASRecoverySession -Failback
            Remove-DfsnFolderTarget -Path $recoveredNASShare.Path -TargetPath $recoveredNASShare.recoveryPath -Force:$true
            Set-DfsnFolderTarget -Path $recoveredNASShare.Path -TargetPath $recoveredNASShare.originalPath -State Online
        }
        
        <#
        #Debug Removal
        Remove-DfsnFolderTarget -Path "\\homelab\dfs\Orga\IT" -TargetPath "\\lab-vbr11\it" -Force:$true
        Set-DfsnFolderTarget -Path "\\homelab\dfs\Orga\IT" -TargetPath "\\lab-nacifs01\it" -State Online
        Remove-DfsnFolderTarget -Path "\\homelab\dfs\Field\Sales" -TargetPath "\\lab-vbr11\sales" -Force:$true
        Set-DfsnFolderTarget -Path "\\homelab\dfs\Field\Sales" -TargetPath "\\lab-nacifs01\sales" -State Online
        Remove-DfsnFolderTarget -Path "\\homelab\dfs\Field\Marketing" -TargetPath "\\lab-vbr11\marketing" -Force:$true
        Set-DfsnFolderTarget -Path "\\homelab\dfs\Field\Marketing" -TargetPath "\\lab-nacifs01\marketing" -State Online
        #>

        ForEach($NASRecoverySession IN $NASRecoverySessions) {
            Stop-VBRNASInstantRecovery -InstantRecovery $NASRecoverySession
        }
    }
    
    # .\Involve-NASInstantDFSRecovery.ps1 -DfsRoot "\\homelab\dfs" -ScanDepth 3 -VBRJobName "DFS NAS Test" -Owner "HOMELAB\Administrator"
#Stop-VBRNASInstantRecovery -InstantRecovery $NASRecoverySessions
#} # END PROCESS