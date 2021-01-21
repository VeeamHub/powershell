<# 
   .SYNOPSIS
   Getting Shares behind Reparse Points and create own backup job
   .DESCRIPTION
   This script finds the shares behind an DFS namespace structure and adds it separate VBR File Backup Job.
   Because it should not ask for 60 options it will be cloned from a Template Job.
   .PARAMETER DfsRoot
   With this parameter you specify the UNC path to scan e.g. "\\fileserver\dfs".
   .PARAMETER ShareCredential
   Enter the Credentials which should be used. They must be from VBR credentials manager.
   .PARAMETER CacheRepository
   Enter the Repository which should be used for Cache Repository for the share
   .PARAMETER ExcludeSystems
   Enter list of excluded servername strings like "*server1*","*server2*,"*server3" to exclude reparse points which are
   pointing to this UNC paths.
   .PARAMETER ScanDepth
   How deep in the subfolder structure the script should scan for reparse points?
   .PARAMETER TemplateJob
   This is an existing job in VBR, which will be used for creating the jobs
   .PARAMETER LogFile
   You can set your own path for log file from this script. Default filename is "C:\ProgramData\Add-DFSTargetsAsJobs.log"

   .Example
   .\Add-DFSTargetsAsJobs.ps1 -DfsRoot "\\homelab\dfs" -ShareCredential "HOMELAB\Administrator" -CacheRepository "Default Backup Repository" -ScanDepth 2 -TemplateJob "Dummy NAS Job"

   .Notes 
   Version:        2.0
   Author:         Marco Horstmann (marco.horstmann@veeam.com)
   Creation Date:  21 Januar 2021
   Purpose/Change: Using template job
   
   .LINK https://github.com/veeamhub/powershell
   .LINK https://github.com/marcohorstmann/powershell
   .LINK https://horstmann.in
 #> 
[CmdletBinding(DefaultParameterSetName="__AllParameterSets")]
Param(

   [Parameter(Mandatory=$True)]
   [string]$DfsRoot,

   #[ValidateSet(“Direct”,”StorageSnapshot”,”VSSSnapshot”)]
   [ValidateSet(“Direct”,”VSSSnapshot”)]
   [Parameter(Mandatory=$False)]
   [string]$VolumeProcessingMode="Direct",

   [Parameter(Mandatory=$True)]
   [string]$ShareCredential,

   [Parameter(Mandatory=$True)]
   [string]$TemplateJob,

   [Parameter(Mandatory=$True)]
   [string]$CacheRepository,

   [Parameter(Mandatory=$False)]
   [string[]]$ExcludeSystems,

   [Parameter(Mandatory=$False)]
   [string]$LogFile="C:\ProgramData\Add-DFSTargetsAsJobs.log",

   [Parameter(Mandatory=$True)]
   [int]$ScanDepth
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

    # Validate parameters: TemplateJob
    Write-Log -Status Info -Info "Checking NAS Template Job Name"
    $templateJobObject = Get-VBRNASBackupJob -name $templateJob
    if($templateJobObject -eq $null) {
        Write-Log -Info "Failed to find job name" -Status Error
        exit 99
    } else { 
        Write-Log -Info "NASTemplate Job Name ... FOUND" -Status Info
    }

    # Check if Veeam Module can be loaded
    Write-Log -Status Info -Info "Trying to load Veeam PS Snapins ..."
    try {
        import-module Veeam.Backup.PowerShell -ErrorAction Stop
        Write-Log -Info "Loading Veeam Backup Powershell Module (V11+) ... SUCCESSFUL" -Status Info
    } catch  {
        Write-Log -Info "$_" -Status Warning
        Write-Log -Info "Loading Veeam Backup Powershell Module (V11+) ... FAILED" -Status Warning
        Write-Log -Info "This can happen if you are using an Veeam Backup & Replication earlier than V11." -Status Warning
        Write-Log -Info "You can savely ignore this warning." -Status Warning
        try {
            Write-Log -Info "Loading Veeam Backup Powershell Snapin (V10) ..." -Status Info
            Add-PSSnapin VeeamPSSnapin -ErrorAction Stop
            Write-Log -Info "Loading Veeam Backup Powershell Snapin (V10) ... SUCCESSFUL" -Status Info
        } catch  {
            Write-Log -Info "$_" -Status Error
            Write-Log -Info "Loading Veeam Backup Powershell Snapin (V10) ... FAILED" -Status Error
            Write-Log -Info "Was not able to load Veeam Backup Powershell Snapin (V10) or Module (V11)" -Status Error
            exit
        }
    }

    # Validate parameters: ShareCrendential
    Write-Log -Status Info -Info "Checking Share Credentials"
    if($ShareCredential = Get-VBRCredentials -Name $ShareCredential | Select -Last 1) {
        Write-Log -Info "Share Credentials ... FOUND" -Status Info
    } else  {
        Write-Log -Info "Failed to find share credentials" -Status Error
        exit 99
    }

    # Validate parameters: Cache Repository
    Write-Log -Status Info -Info "Checking Share Credentials"
    if(Get-VBRBackupRepository -name $CacheRepository)  {
        Write-Log -Info "Cache Repository ... EXISTS" -Status Info
    } else {
        Write-Log -Info "Cache Repository ... NOT FOUND" -Status Error
        exit 50
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
        $allshares = Get-SourceShare -reparsepoints $allreparsepoints
        Write-Log -Info "Shares ... FOUND" -Status Info
    } catch  {
        Write-Log -Info "$_" -Status Error
        Write-Log -Info "Failed to find shares" -Status Error
        exit 99
    }
    

    ForEach ($share in $allshares) {

        $currentPath = $share.TargetPath
        
        # Test all ExcludedSystems and if one matches set $isexcluded to true        
        $isexcluded = $false
        ForEach ($ExcludedSystem in $ExcludeSystems) {
            if ($currentPath -like $ExcludedSystem) {
                $isexcluded = $true
            }
        }
        
        # Gets the info for NAS Server Name
        #Check if share is already added to VBR. If not create share in VBR, else just skip
        if($isexcluded) {
            Write-Log -Info "Share $currentPath is excluded by ExcludedSystems Parameter... SKIPPING" -Status Info
        } else {
            if(!(Get-VBRNASServer -Name $currentPath)) {
                try {
                    #Add share to VBR
                    $VBRNASServer = Add-VBRNASSMBServer -Path $currentPath -AccessCredentials $ShareCredential -ProcessingMode $VolumeProcessingMode -ProxyMode Automatic -CacheRepository $CacheRepository
                    
                    #Generate Job Object which will used to add share to the backup job
                    $VBRNASBackupJobObject = New-VBRNASBackupJobObject -Server $VBRNASServer -Path $currentPath
                    
                    #Create a new backup job with default settings (maybe use when no templateJob was added?)
                    #$nasJobObject = Add-VBRNASBackupJob -Name $currentPath -Description "Auto-Created via Script" -ShortTermBackupRepository $shortTermRepo -BackupObject $VBRNASBackupJobObject
                    
                    #Clone TemplateJob into a new Job
                    $cloneResult = $templateJobObject | Copy-VBRJob -Name $currentPath
                    #Get the object for the newly created backup job
                    $nasJobObject = Get-VBRNASBackupJob -name $currentPath

                    #Modify the job to replace the backup objects in the new job.
                    $modifyResult = Set-VBRNASBackupJob -Job $nasJobObject -BackupObject $VBRNASBackupJobObject -EnableSchedule
                    Write-Log -Info "Adding $currentPath to VBR... DONE" -Status Info
                } catch {
                    Write-Log -Info "$_" -Status Error
                    Write-Log -Info "Adding $currentPath to VBR... FAILED" -Status Error
                    $isexcluded = $true
                }
            } else  {
                Write-Log -Info "Share $currentPath is already added... SKIPPING" -Status Info
            }
        }
    }
       
} # END PROCESS