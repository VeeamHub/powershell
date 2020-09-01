<# 
   .SYNOPSIS
   Start Instant Recovery for all shares and switch DFS paths
   .DESCRIPTION
   This script finds the shares behind an DFS namespace structure and starts for all
   shares of a job an Instant NAS Recovery session and changes the DFS path to the path
   on the mount server. 
   .PARAMETER DfsRoot
   With this parameter you specify the UNC path to scan e.g. "\\fileserver\dfs".
   .PARAMETER VBRJobName
   Name of the NAS backup job. which should be recovered
   .PARAMETER ScanDepth
   How deep in the subfolder structure the script should scan for reparse points?
   .PARAMETER LogFile
   You can set your own path for log file from this script. Default filename is "C:\ProgramData\dfsrecovery.log"

   .Example
   .\Involve-NASInstantDFSRecovery.ps1 -DfsRoot "\\homelab\dfs" -ScanDepth 3 -VBRJobName "DFS NAS Test" -Owner "HOMELAB\Administrator"


   .Notes 
   Version:        1.3
   Author:         Marco Horstmann (marco.horstmann@veeam.com)
   Creation Date:  20 August 2020
   Purpose/Change: Initial Release
   
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

    # Get timestamp for log
    function Get-TimeStamp
    {    
        return "[{0:dd.MM.yyyy} {0:HH:mm:ss}]" -f (Get-Date)
    }

    # This function is used to log status to console and also the given logfilename.
    # Usage: Write-Log -Status [Info, Status, Warning, Error] -Info "This is the text which will be logged
    function Write-Log($Info, $Status)
    {
        $Info = "$(Get-TimeStamp) $Info"
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
        
        
        

        #Set the original DFS target link to Offline to prevent user access
        try {
            $DisableOriginalPath = Set-DfsnFolderTarget -Path $Path -TargetPath $originalPath -State Offline
            Write-Log -Info "Set Target Path $originalPath to Offline... DONE" -Status Info
        } catch  {
            Write-Log -Info "$_" -Status Error
            Write-Log -Info "Set Target Path $originalPath to Offline... FAILED" -Status Error
        }

        #Set the original DFS target link back to Online
        try {
            $EnableRecoveryPath = New-DfsnFolderTarget -Path $Path -TargetPath $NASRecoverySession.SharePath -State Online
            Write-Log -Info "Add Recovery Path $($NASRecoverySession.SharePath) to DFS... DONE" -Status Info
        } catch  {
            Write-Log -Info "$_" -Status Error
            Write-Log -Info "Add Recovery Path $($NASRecoverySession.SharePath) to DFS... FAILED" -Status Error
        }

        $recoveryPath = $NASRecoverySession.SharePath

        #[hashtable]
        $recoveredShareProperty = @{}
        $recoveredShareProperty.Add('Path',$Path)
        $recoveredShareProperty.Add('originalPath',$originalPath)
        $recoveredShareProperty.Add('recoveryPath',$recoveryPath)
        return $recoveredShareProperty
    }

    # End of Functions

    # Main Code starts
    
    # Start a new log file
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
            Write-Log -Info "DFS Management Tools installation... FAILED" -Status Error
            exit 99
        }
    }

    # Check if AD Management Tools are installed
    #ToDo: Use it for Checking username of permissionSet
    Write-Log -Status Info -Info "Checking if Active Directory Powershell modules are installed ..."
    if(get-windowsFeature -Name "RSAT-AD-PowerShell" | Where-Object -Property "InstallState" -EQ "Installed") {
        Write-Log -Status Info -Info "Active Directory Powershell modules are already installed... SKIPPED"
    } else {
        Write-Log -Status Status -Info "Active Directory Powershell modules are not installed... INSTALLING..."
        try {
            Install-WindowsFeature -Name "RSAT-AD-PowerShell" –IncludeAllSubFeature -Confirm:$false
            Write-Log -Info "Active Directory Powershell modules was installed... DONE" -Status Info
        } catch  {
            Write-Log -Info "$_" -Status Error
            Write-Log -Info "Active Directory Powershell modules installation... FAILED" -Status Error
            exit 99
        }
    }

    # Check if Veeam Module can be loaded
    Write-Log -Status Info -Info "Trying to load Veeam PS Snapins ..."
    try {
        Add-PSSnapin VeeamPSSnapin
        Write-Log -Info "Loading Veeam PS Snapin ... SUCCESSS" -Status Info
    } catch  {
        Write-Log -Info "$_" -Status Error
        Write-Log -Info "Loading Veeam PS Snapin ... FAILED" -Status Error
        exit 99
    }

    # Validate parameters: VBRJobName
    Write-Log -Status Info -Info "Validating VBR Job Name ..."
    $nasBackupJob = Get-VBRNASBackupJob -name $VBRJobName
    if($nasBackupJob -eq $null) {
        Write-Log -Info "Validating VBR Job Name ... FAILED" -Status Error
        exit 99
    } else { 
        Write-Log -Info "Validating VBR Job Name ... SUCCESSS" -Status Info
    }

    # Validate parameter: Owner
    Import-Module ActiveDirectory

    # Split user name and domain to check them
    $OwnerDetails = $Owner.Split('\\').Split("@")

    # Put the right stuff into the variable by determing which notation was used:
    # DOMAIN\user or user@domain.int
    if($Owner -like "*\*")
    {
        $usercheckDomain = $Ownerdetails[0].ToString()
        $usercheckUser = $Ownerdetails[1].ToString()
    } elseif($Owner -like "*@*")
    {
        $usercheckDomain = $Ownerdetails[1].ToString()
        $usercheckUser = $Ownerdetails[0].ToString()
    } else {
        Write-Log -Info "$_" -Status Error
        Write-Log -Info "Was not able to validate user name!" -Status Error
        exit 99
    }

    # Check if domain name is valid
    try {
        $Null = Get-ADDomain -Identity $usercheckDomain
        Write-Log -Info "Checking Owner Domain ... DONE" -Status Info
    } catch {
        Write-Log -Info "$_" -Status Error
        Write-Log -Info "Checking Owner Domain ... FAILED" -Status Error
        exit 99
    }

    # Check if domain user is valid
    if((Get-ADUser -Filter {sAMAccountName -eq $usercheckUser}) -eq $Null)
    {
        Write-Log -Info "Checking Owner Username ... FAILED" -Status Error
        exit 99
    } else {
        Write-Log -Info "Checking Owner Username ... DONE" -Status Info
    }

    # Scan for Reparse Points
    Write-Log -Status Info -Info "Scanning for Reparse Points ..."
    try {
        $allreparsepoints = Scan-Folder -path $DfsRoot -currentdepth 1 -maxdepth $ScanDepth
        if( $allreparsepoints.Count -eq 0 ) {
            Write-Log -Info "Scanning for Reparse Points ... NOT FOUND" -Status Error
            exit 99
        } else {
            Write-Log -Info "Scanning for Reparse Points ... FOUND" -Status Info
        }
    } catch  {
        Write-Log -Info "$_" -Status Error
        Write-Log -Info "Scanning for Reparse Points ... FAILED" -Status Error
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
    
    #Get all restore points of this NASBackup to reduce VBR calls
    $nasBackupRestorePoints = Get-VBRNASBackup -Name $VBRJobName | Get-VBRNASBackupRestorePoint
    
    # Get all shares from this object and write it to a new variable sharesInBackup
    $sharesInBackup = $nasBackupRestorePoints | Select-Object -Property NASServerName -Unique

    #Array for storing the Instant Recovery sessions
    $NASRecoverySessions = @()

    #Array for storing the recovered NAS shares
    $recoveredNASShares = @()

    ForEach($shareInBackup IN $sharesInBackup) {
        
        Write-Log -Info "Getting latest restorepoint for share $($shareInBackup.NASServerName.ToString()) ..." -Status Info
        #Getting the last restorepoint for this share
        #$nasBackupRestorePoints | Where-Object -Property NASServerName -eq $shareInBackup.NASServerName | Select-Object -First 1 -OutVariable latestRestorePoint
        $latestRestorePoint = $nasBackupRestorePoints | Where-Object -Property NASServerName -eq $shareInBackup.NASServerName | Select-Object -First 1

        #Create a PermissionSet to give access to the owner if some folders have no permissions to inherit from
        $nasInstantRecoveryPermissionSet = New-VBRNASPermissionSet -RestorePoint $latestRestorePoint -Owner $Owner -AllowEveryone

        #Start the NAS Instant Recovery session fort he current share
        try {
            $NASRecoverySessions += Start-VBRNASInstantRecovery -RestorePoint $latestRestorePoint -Permissions $nasInstantRecoveryPermissionSet
            Write-Log -Info "Mounting of share $($shareInBackup.NASServerName.ToString()) ... DONE" -Status Info
        } catch  {
            Write-Log -Info "$_" -Status Error
            Write-Log -Info "Mounting of share $($shareInBackup.NASServerName.ToString())... FAILED" -Status Error
            Write-Log -Info "Most likely the provided Owner was not found and error handling" -Status Error
            Write-Log -Info "is not able to validate this." -Status Error
            exit 99
}
        #Get the currentFolderTarget of DFS where the TargetPath is the current share
        $currentFolderTarget = $allTargetPaths | Where-Object -Property TargetPath -eq $($shareInBackup.NASServerName.ToString())
        
        #Add the information to this variable to failback the DFS targets
        $recoveredNASShares += Switch-DfsTarget -Path $currentFolderTarget.Path -originalPath $currentFolderTarget.TargetPath -NASRecoverySession $NASRecoverySessions[$NASRecoverySessions.Count – 1]
    }
   
    #Use this to pause the script, show how nice it works and after this we can cleanup the instant recovery
    $confirmation = Read-Host "Please confirm, if Recovery sessions should be stopped and DFS links failback to original links?:"
    if ($confirmation -eq 'y') {
        ForEach($recoveredNASShare IN $recoveredNASShares) {
            Write-Log -Info "Failback of $($recoveredNASShare.Path) started" -Status Info
            
            #Delete the DFS target link to the Instant Recovery Share
            try {
                $null = Remove-DfsnFolderTarget -Path $recoveredNASShare.Path -TargetPath $recoveredNASShare.recoveryPath -Force:$true
                Write-Log -Info "Removing Recovery Target $($recoveredNASShare.recoveryPath)... DONE" -Status Info
            } catch  {
                Write-Log -Info "$_" -Status Error
                Write-Log -Info "Removing Recovery Target $($recoveredNASShare.recoveryPath)... FAILED" -Status Error
            }
            
            #Set the original DFS target link back to Online
            try {
                $null = Set-DfsnFolderTarget -Path $recoveredNASShare.Path -TargetPath $recoveredNASShare.originalPath -State Online
                Write-Log -Info "Activating previous Target Path $($recoveredNASShare.originalPath)... DONE" -Status Info
            } catch  {
                Write-Log -Info "$_" -Status Error
                Write-Log -Info "Activating previous Target Path $($recoveredNASShare.originalPath)... FAILED" -Status Error
            }
            
            
        }
        
        #Stop all running Instant Recoveries started by this script
        ForEach($NASRecoverySession IN $NASRecoverySessions) {
            try {
                Stop-VBRNASInstantRecovery -InstantRecovery $NASRecoverySession
                Write-Log -Info "Stopping recovery of $($NASRecoverySession.SessionName)... DONE" -Status Info
            } catch  {
                Write-Log -Info "$_" -Status Error
                Write-Log -Info "Stopping recovery of $($NASRecoverySession.SessionName)... FAILED" -Status Error
            }
            
        }
    
} # END PROCESS