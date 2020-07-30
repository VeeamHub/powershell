<# 
   .SYNOPSIS
   Adding SMB shares and NFS exports from CSV file to VBR
   .DESCRIPTION
   This script is reading from a CSV file a mixture of SMB shares and NFS exports
   and add them to VBR, if they are not created yet.
   Optional: It updates the existing VBR file job.
   the folder scan depth 
   .PARAMETER CSVfile
   With this parameter you specify the path to a CSV file.
   .PARAMETER VBRJobName
   This is the existing Job where shares/exports should be added.
   .PARAMETER ShareCredential
   Enter the Credentials which should be used to access the SMB shares. They must be from VBR credentials manager.
   .PARAMETER CacheRepository
   Enter the Repository which should be used for Cache.
   .PARAMETER LogFile
   You can set your own path for log file from this script. Default filename is "C:\ProgramData\nasbackupfromCSV.log"

   .Example
   With this command you can add all missing shares/exports 
   .\Invoke-NASBackupFromCSV.ps1 -CSVfile shares.csv -VolumeProcessingMode StorageSnapshot -CacheRepository "Default Backup Repository" -ShareCredential "HOMELAB\Administrator"

   .Example
   If you want to add the missing shares/exports and automatically update a file backup job add the VBRJobName Parameter
   .\Invoke-NASBackupFromCSV.ps1 -CSVfile shares.csv -VolumeProcessingMode StorageSnapshot -CacheRepository "Default Backup Repository" -ShareCredential "HOMELAB\Administrator" -VBRJobName "NAS Backup Job"
    .Notes 
   Version:        4.0
   Author:         Marco Horstmann (marco.horstmann@veeam.com)
   Creation Date:  30 July 2020
   Purpose/Change: Complete Rewrite
   
   .LINK
   My current version: https://github.com/marcohorstmann/powershell
   .LINK
   My blog: https://horstmann.in
 #> 
[CmdletBinding(DefaultParameterSetName="__AllParameterSets")]
Param(

 

   [Parameter(Mandatory=$True)]
   [string]$CSVfile,

   [ValidateSet(“Direct”,”StorageSnapshot”,”VSSSnapshot”)]
   [Parameter(Mandatory=$False)]
   [string]$VolumeProcessingMode="Direct",

   [Parameter(Mandatory=$False)]
   [string]$VBRJobName,

   [Parameter(Mandatory=$False)]
   [string]$ShareCredential, 

   [Parameter(Mandatory=$True)]
   [string]$CacheRepository,

   [Parameter(Mandatory=$False)]
   [string]$LogFile="C:\ProgramData\nasbackupfromCSV.log"

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
        NewLog {Write-Host $Info -ForegroundColor Green  ; $Info | Out-File -FilePath $LogFile}
        Info    {Write-Host $Info -ForegroundColor Green  ; $Info | Out-File -FilePath $LogFile -Append}
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

 

    # Validate parameters: VBRJobName
    Write-Log -Status Info -Info "Checking VBR Job Name"
    try {
        #Only validate if VBRJobName was provided
        if($VBRJobName) {
            $nasBackupJob = Get-VBRNASBackupJob -name $VBRJobName
            Write-Log -Info "VBR Job Name ... FOUND" -Status Info
        } else {
            Write-Log -Info "No VBR Job Name provided ... CHECK SKIPPED" -Status Info
        }
    } catch  {
        Write-Log -Info "$_" -Status Error
        Write-Log -Info "Failed to find job name" -Status Error
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
            Write-Log -Info "Failed to find share credentials" -Status Error
            exit 99
    }
 

    # Validate parameters: Cache Repository
    Write-Log -Status Info -Info "Checking Share Credentials"
    if(Get-VBRBackupRepository -name $CacheRepository)  {
        Write-Log -Info "Cache Repository ... EXISTS" -Status Info
        $repository=Get-VBRBackupRepository -name $CacheRepository
    } else {
        Write-Log -Info "Cache Repository ... NOT FOUND" -Status Error
        exit 50
    }
     
    # Getting all Shares/exports from CSV
    Write-Log -Status Info -Info "Readin CSV to Shares"
    try {
        [string[]]$allshares = Get-Content -Path $CSVfile
        # Check if the $allshares is empty
        if(!$allshares) {
            Write-Log -Info "Failed to load CSV file" -Status Error
            Write-Log -Info "File not found or empty" -Status Error
            exit 99
        }
        Write-Log -Info "CSV File ... FOUND" -Status Info
    } catch  {
        Write-Log -Info "$_" -Status Error
        Write-Log -Info "Failed to load CSV file" -Status Error
        exit 99
    }
    
    ##################################################
    # Creates an empty VBRNASBackupJobObject where we need to add the 
    $VBRNASBackupJobObject = @()
    # For each detected share to this 
    #$allshares
    ForEach($share in $allshares) {
        if(!(Get-VBRNASServer -Name $share)) {

        #### TODO: Add here options for Remote VSS Direct and Storage Snapshot
            try {
                #If the line contains a ":" this must be a NFS export so we go into the nfs part
                if($share.contains(":")) {
                    if($VolumeProcessingMode -like "StorageSnapshot") {
                        $sharesnapshot = $share + "/.snapshot/VeeamNASBackup"
                        Add-VBRNASNFSServer -Path $share -CacheRepository $repository -ProcessingMode StorageSnapshot -StorageSnapshotPath $sharesnapshot
                    } else {
                        Add-VBRNASNFSServer -Path $share -CacheRepository $repository -ProcessingMode Direct
                    }
                #If the line starts with "\\" this must be a SMB share so we go into the SMB part
                } elseif($share.startswith("\\")) {
                    # Check if the share credentials was provided, otherwise we stop here. Because this script is build
                    # for both worlds this needs to be checked here first. 
                    if(!$ShareCredential) {
                        Write-Log -Info "Share Credentials was provided for SMB ... FAILED" -Status Error
                        exit 80
                    }
                    # IF we use Storage Snapshot Mode
                    if($VolumeProcessingMode -like "StorageSnapshot") {
                        $sharesnapshot = $share + "\~snapshot\VeeamNASBackup"
                        Add-VBRNASSMBServer -Path $share -CacheRepository $repository -ProcessingMode StorageSnapshot -StorageSnapshotPath $sharesnapshot -AccessCredentials $ShareCredential
                    # IF we use VSS Snapshot Mode
                    } elseif($VolumeProcessingMode -like "VSSSnapshot") {
                        Add-VBRNASSMBServer -Path $share -CacheRepository $repository -ProcessingMode VSSSnapshot -AccessCredentials $ShareCredential
                    # Otherwise we use Direct Mode
                    } else {
                        Add-VBRNASSMBServer -Path $share -CacheRepository $repository -ProcessingMode Direct -AccessCredentials $ShareCredential
                    }
                }
                Write-Log -Info "Adding $share to VBR... DONE" -Status Info
            } catch {
                Write-Log -Info "$_" -Status Error
                Write-Log -Info "Adding $share to VBR... FAILED" -Status Error
                exit 1000
            }
        } else  {
           Write-Log -Info "Share/Export $share is already added... SKIPPING" -Status Info
        }
        # Now get the share/export object from VBR to add it later to the job
        # This only needs to be done if a job name was provided
        if($VBRJobName) {
            $VBRNASServer = Get-VBRNASServer | Where-Object { $_.Path -eq $share}           
            # Add this share to the list of NASBackupJobObjects
            # Here is the right point to add e.g. exclusion and inclusion masks
            $VBRNASBackupJobObject += New-VBRNASBackupJobObject -Server $VBRNASServer -Path $share
        }
    }

 

    # Updating existing job with this NASBackupJobObjects
    Write-Log -Info "Checking if VBR job needs to be updated ..." -Status Info
    if($VBRJobName) {
        try {
            Set-VBRNASBackupJob -Job $nasBackupJob -BackupObject $VBRNASBackupJobObject
            Write-Log -Info "Updating $VBRJobName ... DONE" -Status Info
            
        } catch {
            Write-Log -Info "$_" -Status Error
            Write-Log -Info "Updating $VBRJobName ... FAILED" -Status Error
            
        }
    } else {
        Write-Log -Info "No VBR Job Name was provided ... SKIPPED" -Status Info
    }
    
       
} # END PROCESS