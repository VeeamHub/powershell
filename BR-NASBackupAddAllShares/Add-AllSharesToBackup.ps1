<# 
   .SYNOPSIS
   Adding all shares of a given server to VBR and (optional) update a job
   .DESCRIPTION
   This script is grabbing the output of net view command and adds all shares found VBR, if they are not created yet.
   Optional: It updates the existing VBR file backup job with the new shares.
   
   .PARAMETER Server
   This parameter is the NAS server name which should be scanned and added to VBR

   .PARAMETER VolumeProcessingMode
   (optional) This parameter is used to specify which kind of storage snapshot is used. 
              Please choose between VSSSnapshot and StorageSnapshot

   .PARAMETER SnapshotFolder 
   (optional) Specify the name of the snapshotfolder within the share e.g. \\server\share\SNAPFOLDER\snapshotXYZ
              Default is "~snapshot", if nothing else is specifed.

   .PARAMETER Snapshotname
   (optional) Specify the snapshot name within the share e.g. \\server\share\snapfolder\SNAPSHOTXYZ
              Default is "VeeamNASBackup", if nothing else is specified, because I used it in other scripts.

   .PARAMETER Job
   (optional) This is an existing VBR job. All shares created by this script execution will be added to this job.

   .PARAMETER ShareCredential
   Enter the Credential which should be used to access the SMB shares. They must be from VBR credentials manager.

   .PARAMETER CacheRepository
   Enter the Repository which should be used for Cache Repository

   .PARAMETER LogFile
   (optional) You can set your own path for log file from this script. Default filename is "C:\ProgramData\Add-AllSharesToBackup.log"

   .Example
   With this command you can add all shares of a server or nas system with VSS snapshot, but don't update any file backup job.

   .\Add-AllSharesToBackup.ps1 -Server fileserver -VolumeProcessingMode VSSSnapshot -CacheRepository "Default Backup Repository" -ShareCredential "HOMELAB\Administrator"

   .Example
   With this command you can add all shares of a server or nas system with storage snapshot processing and automatically update a file backup job.

   .\Add-AllSharesToBackup.ps1 -Server fileserver -VolumeProcessingMode StorageSnapshot -CacheRepository "Default Backup Repository" -ShareCredential "HOMELAB\Administrator" -Job "NAS Test"
   
   .Notes 
   Version:        2.0
   Author:         Marco Horstmann (marco.horstmann@veeam.com)
   Creation Date:  14 September 2020
   Purpose/Change: Complete Rewrite
   
   .LINK
   My current version: https://github.com/marcohorstmann/powershell
   .LINK
   My blog: https://horstmann.in
 #> 
[CmdletBinding(DefaultParameterSetName="__AllParameterSets")]
Param(

   [Parameter(Mandatory=$True)]
   [string]$Server,

   [ValidateSet(“Direct”,”StorageSnapshot”,”VSSSnapshot”)]
   [Parameter(Mandatory=$False)]
   [string]$VolumeProcessingMode="Direct",

   [Parameter(Mandatory=$False)]
   [string]$SnapshotFolder="~snapshot",
   
   [Parameter(Mandatory=$False)]
   [string]$Snapshotname="VeeamNASBackup",

   [Parameter(Mandatory=$False)]
   [string]$Job,

   [Parameter(Mandatory=$True)]
   [string]$ShareCredential, 

   [Parameter(Mandatory=$True)]
   [string]$CacheRepository,

   [Parameter(Mandatory=$False)]
   [string[]]$ExcludeShares=@("c$","ADMIN$","SYSVOL","NETLOGON"),

   [Parameter(Mandatory=$False)]
   [string]$LogFile="C:\ProgramData\Add-AllSharesToBackup.log"

)

PROCESS {

  # Get timestamp for log
  function Get-TimeStamp
  {    
    return "[{0:dd.MM.yyyy} {0:HH:mm:ss}]" -f (Get-Date)
  }

  # This function is used to log status to console and also the given logfilename.
  # Usage: Write-Log -Status [Info, Status, Warning, Error] -Info "This is the text which will be logged"
  function Write-Log($Info, $Status)
  {
    $Info = "$(Get-TimeStamp) $Info"
    switch($Status)
    {
        NewLog  {Write-Host $Info -ForegroundColor Green  ; $Info | Out-File -FilePath $LogFile}
        Info    {Write-Host $Info -ForegroundColor Green  ; $Info | Out-File -FilePath $LogFile -Append}
        LogOnly {$Info | Out-File -FilePath $LogFile -Append}
        Status  {Write-Host $Info -ForegroundColor Yellow ; $Info | Out-File -FilePath $LogFile -Append}
        Warning {Write-Host $Info -ForegroundColor Yellow ; $Info | Out-File -FilePath $LogFile -Append}
        Error   {Write-Host $Info -ForegroundColor Red -BackgroundColor White; $Info | Out-File -FilePath $LogFile -Append}
        default {Write-Host $Info -ForegroundColor white $Info | Out-File -FilePath $LogFile -Append}
    }
  } #end function

    # Main Code starts
    #
    Write-Log -Status NewLog -Info "Starting new log file"
  
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


    # Validate parameters: Job
    Write-Log -Status Info -Info "Checking job name in VBR ..."
    try {
        #Only validate if VBRJobName was provided
        if($Job) {
            $nasBackupJob = Get-VBRNASBackupJob -name $Job
            if(!$nasBackupJob) {
                Write-Log -Info "VBR job name... NOT FOUND" -Status Error
                exit 99
            } else {
                Write-Log -Info "VBR job name ... FOUND" -Status Info
            }
        } else {
            Write-Log -Info "No VBR job name provided ... CHECK SKIPPED" -Status Info
        }
    } catch  {
        Write-Log -Info "$_" -Status Error
        Write-Log -Info "Failed to find VBR job name" -Status Error
        exit 99
    }

    # Validate parameters: ShareCrendential (only if provided)
    Write-Log -Status Info -Info "Checking Share Credentials"
    try {
        if($ShareCredential) {
            if($ShareCredential = Get-VBRCredentials -Name $ShareCredential | Select -Last 1) {
                Write-Log -Info "Share Credentials ... FOUND" -Status Info
                } else  {
                    Write-Log -Info "Failed to find share credentials" -Status Error
                    exit 99
                }
        }
        
    } catch {
            Write-Log -Info "Find share credentials... FAILED" -Status Error
            exit 99
    }
 

    # Validate parameters: Cache Repository
    Write-Log -Status Info -Info "Checking Cache Repository..."
    if(Get-VBRBackupRepository -name $CacheRepository)  {
        Write-Log -Info "Cache Repository ... EXISTS" -Status Info
        $repository=Get-VBRBackupRepository -name $CacheRepository
    } else {
        Write-Log -Info "Cache Repository ... NOT FOUND" -Status Error
        exit 50
    }

    # Getting all Shares via net view
    Write-Log -Status Info -Info "Trying to get list of shares..."
    try {
        $allshares = net view \\$($Server) /all | select -Skip 7 | ?{$_ -match 'disk*'} | %{$_ -match '^(.+?)\s+Disk*'|out-null;$matches[1]}
        # Check if the $allshares is empty
        if(!$allshares) {
            Write-Log -Info "Failed to get shares" -Status Error
            exit 99
        }
        Write-Log -Info "File shares ... FOUND" -Status Info
    } catch  {
        Write-Log -Info "$_" -Status Error
        Write-Log -Info "Failed to load file shares" -Status Error
        exit 99
    }
  
    
    ##################################################
    # Creates an empty VBRNASBackupJobObject where we need to add the 
    if($Job) {
        $VBRNASBackupJobObject = @()
        # Adding all backup objects from existing job
        $VBRNASBackupJobObject += $nasBackupJob.BackupObject
    }

    # For each detected shares check if it is excluded
    ForEach($share in $allshares) {    
        $isexcluded = $false
        $ExcludeShares = $ExcludeShares
        ForEach ($ExcludeShare in $ExcludeShares) {
            if ($share -ilike $ExcludeShare) {
                $isexcluded = $true
            }
        }

        #Build UNC path from servername + sharename
        $uncpath = $("\\" + $Server + "\" + $share)
        if(!(Get-VBRNASServer -Name $uncpath) -and !($isexcluded)) {
            try {
                    # IF we use Storage Snapshot Mode
                    if($VolumeProcessingMode -like "StorageSnapshot") {
                        $sharesnapshot = $uncpath + "\" + $SnapshotFolder + "\" + $Snapshotname
                        $output = Add-VBRNASSMBServer -Path $uncpath -CacheRepository $repository -ProcessingMode StorageSnapshot -StorageSnapshotPath $sharesnapshot -AccessCredentials $ShareCredential
                        Write-Log -Info $output -Status LogOnly
                    # IF we use VSS Snapshot Mode
                    } elseif($VolumeProcessingMode -like "VSSSnapshot") {
                        $output = Add-VBRNASSMBServer -Path $uncpath -CacheRepository $repository -ProcessingMode VSSSnapshot -AccessCredentials $ShareCredential
                        Write-Log -Info $output -Status LogOnly
                    # Otherwise we use Direct Mode
                    } else {
                        $output = Add-VBRNASSMBServer -Path $uncpath -CacheRepository $repository -ProcessingMode Direct -AccessCredentials $ShareCredential
                        Write-Log -Info $output -Status LogOnly
                    }
    
                Write-Log -Info "Adding $uncpath to VBR... DONE" -Status Info
                # Now get the share/export object from VBR to add it later to the job
                # This only needs to be done if a job name was provided
                if($Job) {
                    $VBRNASServer = Get-VBRNASServer | Where-Object { $_.Path -eq $uncpath}           
                    # Add this share to the list of NASBackupJobObjects
                    # Here is the right point to add e.g. exclusion and inclusion masks
                    $VBRNASBackupJobObject += New-VBRNASBackupJobObject -Server $VBRNASServer -Path $uncpath
                }
            } catch {
                Write-Log -Info "$_" -Status Error
                Write-Log -Info "Adding $uncpath to VBR... FAILED" -Status Error
                exit 1000
            }
        } else  {
           if($isexcluded) {
                Write-Log -Info "Share $uncpath is excluded... SKIPPING" -Status Info
           } else {
                Write-Log -Info "Share $uncpath is already added... SKIPPING" -Status Info
           }
        }
    }

 

    # Updating existing job with this NASBackupJobObjects
    Write-Log -Info "Checking if VBR job needs to be updated ..." -Status Info
    if($Job) {
        try {
            Set-VBRNASBackupJob -Job $nasBackupJob -BackupObject $VBRNASBackupJobObject
            Write-Log -Info "Updating $Job ... DONE" -Status Info
            
        } catch {
            Write-Log -Info "$_" -Status Error
            Write-Log -Info "Updating $Job ... FAILED" -Status Error
            
        }
    } else {
        Write-Log -Info "No VBR Job Name was provided ... SKIPPED" -Status Info
    }
    
       
} # END PROCESS
